part of 'drift_mission_repository.dart';

/// 同一连接与事务中的任务持久化职责。
class _MissionExecution {
  _MissionExecution(this._repository);
  final DriftMissionRepository _repository;

  /// 改为今天自选并开始，同一事务保留旧排期，避免过期固定任务立刻再次STOP。
  Future<ExecutionEvent> startMakeup(
    MissionDetail original,
    String commandId, {
    DateTime? evidenceDeadlineAt,
  }) => _repository.database.transaction(() async {
    await _repository._acquireWrite(original.mission.id);
    final current = (await _repository.findDetail(original.mission.id))!;
    final saved = current.events.where((e) => e.id == commandId).firstOrNull;
    if (saved != null) return saved;
    if (current.phase != MissionPhase.notStarted ||
        current.lastSequence != original.lastSequence ||
        current.schedule.id != original.schedule.id) {
      throw const ExecutionConflict('任务已变化，请刷新后再补做');
    }
    final now = _repository._now();
    final local = tz.TZDateTime.from(
      now,
      tz.getLocation(current.schedule.timeZone),
    );
    final deadline = evidenceDeadlineAt ?? current.schedule.evidenceDeadlineAt;
    if (current.mission.verificationPolicy ==
            VerificationPolicy.requiredEvidence &&
        (deadline == null || !deadline.isAfter(now))) {
      throw ArgumentError('现在补做需要确认新的材料截止时间');
    }
    final schedule = MissionScheduleRevision(
      id: const Uuid().v5(Namespace.url.value, 'makeup:$commandId'),
      missionId: current.mission.id,
      revisionNumber: current.schedule.revisionNumber + 1,
      scheduledDate:
          '${local.year.toString().padLeft(4, '0')}-${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')}',
      timeZone: current.schedule.timeZone,
      plannedDurationMinutes: current.schedule.plannedDurationMinutes,
      evidenceDeadlineAt: deadline,
      changedAt: now,
      changeReason: '用户现在补做；保留原排期 ${current.schedule.id}',
    );
    await _repository.edit(
      original: current,
      title: current.mission.title,
      objective: current.executionPlan.objective,
      schedule: schedule,
      verificationPolicy: current.mission.verificationPolicy,
      verificationCriteria: current.executionPlan.verificationCriteria,
    );
    return execute(
      ExecutionCommand(
        id: commandId,
        missionId: current.mission.id,
        expectedSequence: 0,
        type: ExecutionEventType.start,
        scheduleRevisionId: schedule.id,
      ),
    );
  });
  Future<ExecutionEvent> execute(ExecutionCommand command) async {
    if (command.type == ExecutionEventType.stop) {
      throw const ExecutionConflict('到点停止只能由计划调度执行');
    }
    return _execute(command);
  }

  Future<OperationReceiptInfo> completeHistory(HistoricalCompletion request) =>
      _repository.database.transaction(() async {
        if (request.id.trim().isEmpty ||
            request.statement.trim().isEmpty ||
            request.originals.length + request.excluded.length > 10000 ||
            [
                  ...request.originals,
                  ...request.excluded,
                ].map((d) => d.mission.id).toSet().length !=
                request.originals.length + request.excluded.length) {
          throw ArgumentError('请先预览要补记的任务，并提供完成依据');
        }
        validateScheduledDate(request.beforeDate);
        await _repository._acquireGlobalWrite();
        List<Object?> version(MissionDetail d) => [
          d.mission.id,
          d.mission.title,
          d.mission.goalId,
          d.mission.goalNodeId,
          d.mission.verificationPolicy.name,
          d.mission.cancelledAt?.toUtc().millisecondsSinceEpoch,
          d.mission.updatedAt.toUtc().millisecondsSinceEpoch,
          d.schedule.id,
          d.schedule.scheduledDate,
          d.lastSequence,
          d.phase.name,
          historicalCompletionSkipReason(d),
        ];
        final fingerprint = sha256
            .convert(
              utf8.encode(
                jsonEncode({
                  'goalId': request.goalId,
                  'beforeDate': request.beforeDate,
                  'statement': request.statement.trim(),
                  'missions': [for (final d in request.originals) version(d)],
                  'excluded': [for (final d in request.excluded) version(d)],
                }),
              ),
            )
            .toString();
        final previous = await _repository.findOperationReceipt(request.id);
        if (previous != null) {
          if (previous.kind != 'completeHistory' ||
              previous.fingerprint != fingerprint) {
            throw const ExecutionConflict('同一次补记的内容已变化，请重新预览');
          }
          return previous;
        }
        final now = _repository._now();
        final goal = await (_repository.database.select(
          _repository.database.goals,
        )..where((row) => row.id.equals(request.goalId))).getSingleOrNull();
        if (goal == null) throw ArgumentError('目标不存在');
        final scope = await _repository.findHistoryScope(
          request.goalId,
          request.beforeDate,
        );
        final originals = {
          for (final d in [...request.originals, ...request.excluded])
            d.mission.id: d,
        };
        if (scope.length != originals.length) {
          throw const ExecutionConflict('日期范围内任务已变化，本批未保存，请重新预览');
        }
        for (final current in scope) {
          final original = originals[current.mission.id];
          if (original == null ||
              jsonEncode(version(current)) != jsonEncode(version(original))) {
            throw const ExecutionConflict('预览中的任务已变化，本批未保存，请重新预览');
          }
        }
        if (request.originals.any(
              (d) => !isHistoricalCompletionCandidate(
                d,
                beforeDate: request.beforeDate,
                goalId: request.goalId,
              ),
            ) ||
            request.excluded.any(
              (d) => isHistoricalCompletionCandidate(
                d,
                beforeDate: request.beforeDate,
                goalId: request.goalId,
              ),
            )) {
          throw ArgumentError('预览中的候选与跳过任务不一致');
        }
        final scopeById = {
          for (final detail in scope) detail.mission.id: detail,
        };
        for (final original in request.originals) {
          final current = scopeById[original.mission.id];
          if (current == null) {
            throw const ExecutionConflict('预览中的任务已变化，本批未保存，请重新预览');
          }
          await _execute(
            ExecutionCommand(
              id: '${request.id}:${current.mission.id}',
              missionId: current.mission.id,
              expectedSequence: current.lastSequence,
              type: ExecutionEventType.end,
              scheduleRevisionId: current.events.isEmpty
                  ? current.schedule.id
                  : null,
              userReportedResult: UserReportedResult.completed,
              reason: current.events.isEmpty ? request.statement.trim() : null,
              isRetrospective: current.events.isEmpty,
            ),
            occurredAt: now,
          );
        }
        final result = jsonEncode({
          'status': 'success',
          'operationId': request.id,
          'asOf': now.toIso8601String(),
          'counts': {
            'matched': scope.length,
            'eligible': request.originals.length,
            'changed': request.originals.length,
            'skipped': request.excluded.length,
          },
          'issues': [
            for (final d in request.excluded)
              {
                'code': historicalCompletionSkipReason(d),
                'id': d.mission.id,
                'title': d.mission.title,
                'scheduledDate': d.schedule.scheduledDate,
              },
          ],
          'ok': true,
          'operation': 'completeHistory',
          'goalId': request.goalId,
          'completedCount': request.originals.length,
          'beforeDate': request.beforeDate,
          'recordedAt': now.toIso8601String(),
          'retrospectiveCount': request.originals
              .where((d) => d.events.isEmpty)
              .length,
          'statement': request.statement.trim(),
          'references': [
            {'type': 'goal', 'id': request.goalId, 'title': '查看目标'},
          ],
        });
        await _repository.database
            .into(_repository.database.operationReceipts)
            .insert(
              OperationReceiptsCompanion.insert(
                id: request.id,
                kind: 'completeHistory',
                fingerprint: fingerprint,
                entityId: request.goalId,
                resultJson: result,
                createdAt: now.millisecondsSinceEpoch,
              ),
            );
        return (await _repository.findOperationReceipt(request.id))!;
      });
  // 调度提供固定时段生效时刻；普通动作从事务时钟取得时刻。
  Future<ExecutionEvent> _execute(
    ExecutionCommand command, {
    DateTime? occurredAt,
  }) async {
    String? clean(String? text) {
      final value = text?.trim();
      return value == null || value.isEmpty ? null : value;
    }

    if (command.id.trim().isEmpty ||
        command.missionId.trim().isEmpty ||
        command.expectedSequence < 0) {
      throw ArgumentError('操作编号、任务编号和预期序号无效');
    }
    final reason = clean(command.reason);
    final category = command.userReasonCategory;
    final reasonText = clean(command.userReasonText);
    if (category != null && !failureReasonLabels.containsKey(category)) {
      throw ArgumentError('未完成原因类别无效');
    }
    if ((category != null || reasonText != null) &&
        (command.type != ExecutionEventType.end ||
            command.userReportedResult != UserReportedResult.notCompleted)) {
      throw ArgumentError('只有报告未完成时可以填写未完成原因');
    }
    return _repository.database.transaction(() async {
      await _repository._acquireWrite(command.missionId);
      // 先查身份，再检查当前序号；成功后丢失响应的重试不会再次执行。
      final existingQuery = _repository.database.select(
        _repository.database.executionEvents,
      )..where((table) => table.id.equals(command.id));
      final existing = await existingQuery.getSingleOrNull();
      if (existing != null) {
        final event = eventFromRow(existing);
        final failures =
            await (_repository.database.select(
                  _repository.database.failureRecords,
                )..where(
                  (table) =>
                      table.missionId.equals(event.missionId) &
                      table.trigger.equals(userMarkedNotCompletedTrigger),
                ))
                .get();
        final oldFailure = failures.isEmpty ? null : failures.single;
        final needsFailure =
            event.type == ExecutionEventType.end &&
            event.userReportedResult == UserReportedResult.notCompleted;
        if (event.missionId != command.missionId ||
            event.type != command.type ||
            event.sequence != command.expectedSequence + 1 ||
            event.scheduleRevisionId != command.scheduleRevisionId ||
            event.grantedDurationMinutes != command.grantedDurationMinutes ||
            event.reason != reason ||
            event.userReportedResult != command.userReportedResult ||
            event.submitOptionalEvidence != command.submitOptionalEvidence ||
            event.isRetrospective != command.isRetrospective ||
            (needsFailure &&
                (oldFailure == null ||
                    oldFailure.userReasonCategory != category ||
                    oldFailure.userReasonText != reasonText))) {
          throw const ExecutionConflict('同一操作编号对应的输入不同，请刷新后重新操作');
        }
        return event;
      }
      // 这里读取的是一整份任务详情：既要检查旧序号/阶段，也要核对开始绑定的排期。
      // 排期描述“打算什么时候做、做多久”；事件描述“实际开始/暂停过什么”。
      final detail = await _repository.findDetail(command.missionId);
      if (detail == null) throw const ExecutionConflict('任务已不存在，请刷新');
      if (detail.lastSequence != command.expectedSequence) {
        throw const ExecutionConflict('执行记录已变化，请刷新后重新操作');
      }
      if (command.type == ExecutionEventType.start &&
          command.scheduleRevisionId != detail.schedule.id) {
        // 页面若看的是旧排期，不能悄悄换成新排期替用户开始，必须刷新后再确认。
        throw const ExecutionConflict('排期已变化，请刷新并确认新计划后开始');
      }
      if (command.type == ExecutionEventType.start ||
          command.type == ExecutionEventType.resume) {
        final running = await _repository.findActive();
        for (final other in running) {
          if (other.mission.id != command.missionId &&
              other.phase == MissionPhase.running) {
            throw ExecutionConflict('“${other.mission.title}”正在执行，请先暂停或结束它');
          }
        }
      }
      // 固定 START 在事务中确认当前仍处于计划窗口，生效时刻绑定计划起点。
      final checkedAt = _repository._now();
      var now = occurredAt ?? checkedAt;
      if (command.type == ExecutionEventType.start &&
          detail.schedule.timePolicy == TimePolicy.fixed) {
        final start = detail.schedule.fixedStartAt!;
        final end = fixedTimeSlotEnd(
          start,
          detail.schedule.plannedDurationMinutes,
          const [],
        );
        if (checkedAt.isBefore(start)) {
          throw const ExecutionConflict('计划任务尚未到开始时间，可以先修改排期');
        }
        if (!checkedAt.isBefore(end)) {
          throw const ExecutionConflict('计划时段已结束，请改期或使用现在补做');
        }
        now = start;
      }
      final scheduledEnd = scheduledExecutionEnd(
        detail.schedule,
        detail.events,
      );
      if (occurredAt == null &&
          scheduledEnd != null &&
          !now.isBefore(scheduledEnd)) {
        throw const ExecutionConflict('计划时间已到，请刷新后确认完成情况');
      }
      if (command.isRetrospective) {
        final local = tz.TZDateTime.from(
          now,
          tz.getLocation(detail.schedule.timeZone),
        );
        final today =
            '${local.year.toString().padLeft(4, '0')}-${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')}';
        if (command.scheduleRevisionId != detail.schedule.id ||
            detail.schedule.scheduledDate.compareTo(today) > 0) {
          throw const ExecutionConflict('补记不能处理未来排期');
        }
      }
      if (detail.events.isNotEmpty &&
          now.isBefore(detail.events.last.occurredAt)) {
        throw const ExecutionConflict('系统时间早于上一条记录，请校正系统时间后重试');
      }
      final event = ExecutionEvent(
        id: command.id,
        missionId: command.missionId,
        sequence: command.expectedSequence + 1,
        type: command.type,
        occurredAt: now,
        scheduleRevisionId: command.scheduleRevisionId,
        grantedDurationMinutes: command.grantedDurationMinutes,
        reason: reason,
        userReportedResult: command.userReportedResult,
        submitOptionalEvidence: command.submitOptionalEvidence,
        isRetrospective: command.isRetrospective,
      );
      // 复用已有唯一推演核心；非法 START/END、取消后开始等均不能写入。
      validateExecutionHistory(detail.mission, [...detail.events, event]);
      await _repository.database
          .into(_repository.database.executionEvents)
          .insert(eventToCompanion(event));
      if (event.type == ExecutionEventType.end &&
          event.userReportedResult == UserReportedResult.notCompleted) {
        await _repository.database
            .into(_repository.database.failureRecords)
            .insert(
              FailureRecordsCompanion.insert(
                id: userMarkedFailureId(event.id),
                missionId: event.missionId,
                trigger: userMarkedNotCompletedTrigger,
                occurredAt: now.millisecondsSinceEpoch,
                createdAt: now.millisecondsSinceEpoch,
                userReasonCategory: Value(category),
                userReasonText: Value(reasonText),
              ),
            );
      }
      // 晚于截止才报告完成：END 和超时一起提交，保留用户的完成报告。
      if (event.type == ExecutionEventType.end &&
          event.userReportedResult == UserReportedResult.completed &&
          detail.mission.verificationPolicy ==
              VerificationPolicy.requiredEvidence &&
          !now.isBefore(detail.schedule.evidenceDeadlineAt!) &&
          !detail.evidence.any(
            (e) =>
                e.supersedesEvidenceId == null &&
                e.submittedAt.isBefore(detail.schedule.evidenceDeadlineAt!),
          )) {
        await _repository._insertEvidenceDeadline(detail, event, now);
      }
      return event;
    });
  }

  Future<void> reportExecution(
    UserExecutionReport report, {
    required int expectedSequence,
    required String scheduleId,
    UserReportedResult? result,
    bool? submitOptionalEvidence,
  }) => _repository._support.command(
    report.id,
    'execution_report',
    report.missionId,
    {
      'date': report.occurrenceDate,
      'zone': report.timeZoneId,
      'basis': report.basis,
      'start': report.actualStart?.millisecondsSinceEpoch,
      'end': report.actualEnd?.millisecondsSinceEpoch,
      'supersedesId': report.supersedesId,
      'result': result?.name,
      'optional': submitOptionalEvidence,
    },
    {'saved': true, 'reportId': report.id},
    () => _reportExecution(
      report,
      expectedSequence: expectedSequence,
      scheduleId: scheduleId,
      result: result,
      submitOptionalEvidence: submitOptionalEvidence,
    ),
  );

  Future<void> _reportExecution(
    UserExecutionReport report, {
    required int expectedSequence,
    required String scheduleId,
    UserReportedResult? result,
    bool? submitOptionalEvidence,
  }) => _repository.database.transaction(() async {
    await _repository._acquireGlobalWrite();
    final previous = await _repository._support.rows(
      'SELECT * FROM user_execution_reports WHERE id=?',
      [report.id],
    );
    if (previous.isNotEmpty) {
      final p = previous.single;
      if (p['mission_id'] != report.missionId ||
          p['occurrence_date'] != report.occurrenceDate ||
          p['time_zone_id'] != report.timeZoneId ||
          p['actual_start'] != report.actualStart?.millisecondsSinceEpoch ||
          p['actual_end'] != report.actualEnd?.millisecondsSinceEpoch ||
          p['basis'] != report.basis ||
          p['supersedes_id'] != report.supersedesId) {
        throw const EvidenceConflict('补记编号已用于不同内容');
      }
      return;
    }
    report.validate(_repository.clock().toUtc());
    final missions = _repository;
    final detail = await missions.findDetail(report.missionId);
    if (detail == null ||
        detail.lastSequence != expectedSequence ||
        detail.schedule.id != scheduleId) {
      throw const EvidenceConflict('任务已变化，请刷新后重试');
    }
    if (detail.phase == MissionPhase.cancelled) {
      throw ArgumentError('已取消任务不改写执行结果');
    }
    final latest = await _repository._support.rows(
      'SELECT id FROM user_execution_reports WHERE mission_id=? ORDER BY reported_at DESC,rowid DESC LIMIT 1',
      [report.missionId],
    );
    if (report.supersedesId != (latest.isEmpty ? null : latest.single['id'])) {
      throw const EvidenceConflict('时间声明已被更正，请刷新');
    }
    final ended = detail.events.any((e) => e.type == ExecutionEventType.end);
    if (!ended) {
      if (result == null) throw ArgumentError('请明确完成或未执行的结果');
      await missions.execute(
        ExecutionCommand(
          id: 'report:${report.id}',
          missionId: report.missionId,
          expectedSequence: expectedSequence,
          type: ExecutionEventType.end,
          scheduleRevisionId: detail.events.isEmpty ? scheduleId : null,
          isRetrospective: detail.events.isEmpty,
          reason: detail.events.isEmpty ? report.basis : null,
          userReportedResult: result,
          submitOptionalEvidence: submitOptionalEvidence,
          userReasonText: result == UserReportedResult.notCompleted
              ? report.basis
              : null,
        ),
      );
    } else if (result != null &&
        result != detail.events.last.userReportedResult) {
      throw ArgumentError('时间更正不改写原完成报告');
    }
    await _repository.database
        .into(_repository.database.userExecutionReports)
        .insert(
          UserExecutionReportsCompanion.insert(
            id: report.id,
            missionId: report.missionId,
            occurrenceDate: report.occurrenceDate,
            timeZoneId: report.timeZoneId,
            actualStart: Value(report.actualStart?.millisecondsSinceEpoch),
            actualEnd: Value(report.actualEnd?.millisecondsSinceEpoch),
            reportedAt: _repository.clock().toUtc().millisecondsSinceEpoch,
            basis: report.basis,
            supersedesId: Value(report.supersedesId),
          ),
        );
  });
}

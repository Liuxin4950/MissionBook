part of 'drift_mission_repository.dart';

/// 同一连接与事务中的任务持久化职责。
class _MissionQueries {
  _MissionQueries(this._repository);
  final DriftMissionRepository _repository;

  /// 在一个一致快照内分块读取关联事实；归属按目标复用，避免逐任务查库。
  Future<List<MissionDetail>> _detailsForRows(List<MissionRow> rows) async {
    final result = <MissionDetail>[];
    final ownership = <String, MissionGoalChoices>{};
    final paths = <MissionOwnership, MissionOwnershipInfo>{};
    final goals = DriftGoalRepository(_repository.database);
    for (var offset = 0; offset < rows.length; offset += 200) {
      final page = rows.sublist(offset, (offset + 200).clamp(0, rows.length));
      final ids = page.map((row) => row.id).toList();
      final schedules = _repository.database.missionScheduleRevisions;
      final history = _repository.database.alias(
        schedules,
        'batch_schedule_history',
      );
      final latest = _repository.database.selectOnly(history)
        ..addColumns([history.revisionNumber.max()])
        ..where(history.missionId.equalsExp(schedules.missionId));
      final scheduleRows =
          await (_repository.database.select(schedules)..where(
                (row) =>
                    row.missionId.isIn(ids) &
                    row.revisionNumber.equalsExp(
                      subqueryExpression<int>(latest),
                    ),
              ))
              .get();
      final planRows = await (_repository.database.select(
        _repository.database.executionPlans,
      )..where((row) => row.missionId.isIn(ids))).get();
      final eventRows =
          await (_repository.database.select(
                  _repository.database.executionEvents,
                )
                ..where((row) => row.missionId.isIn(ids))
                ..orderBy([(row) => OrderingTerm.asc(row.sequence)]))
              .get();
      final failureRows = await (_repository.database.select(
        _repository.database.failureRecords,
      )..where((row) => row.missionId.isIn(ids))).get();
      final evidenceRows =
          await (_repository.database.select(
                  _repository.database.evidenceRecords,
                )
                ..where((row) => row.missionId.isIn(ids))
                ..orderBy([
                  (row) => OrderingTerm.asc(row.submittedAt),
                  (row) => OrderingTerm.asc(row.id),
                ]))
              .get();
      final userRows = await (_repository.database.select(
        _repository.database.userExecutionReports,
      )..where((t) => t.missionId.isIn(ids))).get();
      final userByMission = <String, List<UserExecutionReport>>{};
      for (final r in userRows) {
        (userByMission[r.missionId] ??= []).add(userReportFromRow(r));
      }
      final scheduleByMission = {
        for (final row in scheduleRows) row.missionId: row,
      };
      final planByMission = {for (final row in planRows) row.missionId: row};
      final events = <String, List<ExecutionEvent>>{};
      final failures = <String, List<FailureRecord>>{};
      final evidence = <String, List<Evidence>>{};
      for (final row in eventRows) {
        (events[row.missionId] ??= []).add(eventFromRow(row));
      }
      for (final row in failureRows) {
        (failures[row.missionId] ??= []).add(failureFromRow(row));
      }
      for (final row in await hydrateEvidenceRows(
        _repository.database,
        evidenceRows,
      )) {
        (evidence[row.missionId] ??= []).add(evidenceFromRow(row));
      }
      for (final row in page) {
        final goalId = row.goalId;
        if (goalId != null && !ownership.containsKey(goalId)) {
          final goal = await goals.findById(goalId);
          if (goal == null) throw const FormatException('任务所属目标缺失');
          ownership[goalId] = MissionGoalChoices(
            goal: goal,
            nodes: await goals.findNodes(goalId),
          );
        }
        final scheduleRow = scheduleByMission[row.id];
        final planRow = planByMission[row.id];
        if (scheduleRow == null || planRow == null) {
          throw const FormatException('任务缺少排期或执行方案');
        }
        final mission = missionFromRow(row);
        final schedule = scheduleFromRow(scheduleRow);
        final plan = executionPlanFromRow(planRow);
        final eventList = events[row.id] ?? const <ExecutionEvent>[];
        final failureList = failures[row.id] ?? const <FailureRecord>[];
        final evidenceList = evidence[row.id] ?? const <Evidence>[];
        validateEvidenceRequirement(
          policy: mission.verificationPolicy,
          criteria: plan.verificationCriteria,
          schedule: schedule,
        );
        deriveMissionPhase(
          mission,
          eventList,
          failureList,
          evidenceList,
          schedule,
        );
        result.add(
          MissionDetail(
            userReports: userByMission[row.id] ?? const [],
            mission: mission,
            schedule: schedule,
            executionPlan: plan,
            events: List.unmodifiable(eventList),
            failures: List.unmodifiable(failureList),
            evidence: List.unmodifiable(evidenceList),
            ownershipInfo: goalId == null
                ? null
                : paths.putIfAbsent(
                    mission.ownership,
                    () => ownership[goalId]!.resolve(mission.ownership),
                  ),
          ),
        );
      }
    }
    return result;
  }

  Future<PlannedMissionSnapshot> findPlannedSnapshot() =>
      _repository.database.transaction(() async {
        final checkedAt = _repository._now().millisecondsSinceEpoch;
        final active = await findActive();
        final hasRunning = active.any(
          (detail) => detail.phase == MissionPhase.running,
        );
        final row = await _repository.database
            .customSelect(
              '''
SELECT r.fixed_start_at, r.planned_duration_minutes
${DriftMissionRepository._unstartedFixed}
 AND (r.fixed_start_at > ? OR r.fixed_start_at + r.planned_duration_minutes*60000 > ?)
ORDER BY r.fixed_start_at,m.id LIMIT 1
''',
              variables: [Variable<int>(checkedAt), Variable<int>(checkedAt)],
            )
            .getSingleOrNull();
        return PlannedMissionSnapshot(
          hasRunning: hasRunning,
          nextEndAt: _nextScheduledEnd(active),
          refreshAfterExpiredCandidate: true,
          candidates: row == null
              ? []
              : [
                  PlannedMissionPoint(
                    start: DateTime.fromMillisecondsSinceEpoch(
                      row.read<int>('fixed_start_at'),
                      isUtc: true,
                    ),
                    end: DateTime.fromMillisecondsSinceEpoch(
                      row.read<int>('fixed_start_at') +
                          row.read<int>('planned_duration_minutes') * 60000,
                      isUtc: true,
                    ),
                  ),
                ],
        );
      });
  DateTime? _nextScheduledEnd(List<MissionDetail> active) {
    DateTime? next;
    for (final detail in active) {
      final end = scheduledExecutionEnd(detail.schedule, detail.events);
      if (end != null && (next == null || end.isBefore(next))) next = end;
    }
    return next;
  }

  Future<List<MissionDetail>> findReminderCandidates() =>
      _repository.database.transaction(() async {
        final checkedAt = _repository._now().millisecondsSinceEpoch;
        final active = await findActive();
        final rows = await _repository.database
            .customSelect(
              '''
SELECT m.* ${DriftMissionRepository._unstartedFixed}
ORDER BY CASE WHEN r.fixed_start_at+r.planned_duration_minutes*60000 > ? THEN 0 ELSE 1 END,
 CASE WHEN r.fixed_start_at+r.planned_duration_minutes*60000 > ?
   THEN r.fixed_start_at ELSE -r.fixed_start_at END, m.id
LIMIT 64
''',
              variables: [Variable<int>(checkedAt), Variable<int>(checkedAt)],
            )
            .get();
        return [
          ...active,
          ...await _detailsForRows([
            for (final row in rows) _repository.database.missions.map(row.data),
          ]),
        ];
      });
  Future<Set<String>> findCompletedGoalNodeIds(String goalId) async {
    final rows = await _repository.database
        .customSelect(
          '''
SELECT DISTINCT m.goal_node_id FROM missions m
JOIN execution_events e ON e.mission_id=m.id AND e.type='END' AND e.user_reported_result='COMPLETED'
WHERE m.goal_id=? AND m.goal_node_id IS NOT NULL
''',
          variables: [Variable<String>(goalId)],
        )
        .get();
    return {for (final row in rows) row.read<String>('goal_node_id')};
  }

  Future<List<MissionGoalChoices>> findGoalChoices() =>
      _repository.database.transaction(() async {
        final rows =
            await (_repository.database.select(_repository.database.goals)
                  ..where((table) => table.status.equals('ACTIVE'))
                  ..orderBy([
                    (table) => OrderingTerm.desc(table.createdAt),
                    (table) => OrderingTerm.asc(table.id),
                  ]))
                .get();
        final goals = DriftGoalRepository(
          _repository.database,
        ); // 复用已有的目标转换和节点树完整性检查。
        final result = <MissionGoalChoices>[];
        for (final row in rows) {
          result.add(
            MissionGoalChoices(
              goal: (await goals.findById(row.id))!,
              nodes: await goals.findNodes(row.id),
            ),
          );
        }
        return result;
      });
  Future<MissionOwnershipInfo?> findOwnershipInfo(MissionOwnership ownership) =>
      _repository.database.transaction(() async {
        ownership.validate();
        if (ownership.goalId == null) return null; // 独立任务不需要目标或节点也能保存和执行。
        final goals = DriftGoalRepository(_repository.database);
        final goal = await goals.findById(ownership.goalId!);
        if (goal == null) throw StateError('关联的目标不存在，请重新选择归属');
        final choices = MissionGoalChoices(
          goal: goal,
          nodes: await goals.findNodes(goal.id),
        );
        return choices.resolve(ownership);
      });
  Future<List<MissionDetail>> findForGoal(String goalId) =>
      _repository.database.transaction(() async {
        final rows =
            await (_repository.database.select(_repository.database.missions)
                  ..where((table) => table.goalId.equals(goalId))
                  ..orderBy([
                    (table) => OrderingTerm.desc(table.createdAt),
                    (table) => OrderingTerm.asc(table.id),
                  ]))
                .get();
        return _detailsForRows(rows);
      });
  Future<List<MissionDetail>> findActive() => _findByExecution(ended: false);
  Future<List<MissionDetail>> findFinished() => _findByExecution(ended: true);
  Future<List<MissionDetail>> findCancelled() =>
      _repository.database.transaction(() async {
        final rows =
            await (_repository.database.select(_repository.database.missions)
                  ..where((row) => row.cancelledAt.isNotNull())
                  ..orderBy([
                    (row) => OrderingTerm.desc(row.cancelledAt),
                    (row) => OrderingTerm.asc(row.id),
                  ]))
                .get();
        return _detailsForRows(rows);
      });
  Future<List<MissionDetail>> findAllDetails() =>
      _repository.database.transaction(() async {
        final rows =
            await (_repository.database.select(_repository.database.missions)
                  ..orderBy([
                    (row) => OrderingTerm.desc(row.createdAt),
                    (row) => OrderingTerm.asc(row.id),
                  ]))
                .get();
        return _detailsForRows(rows);
      });
  Future<List<MissionDetail>> _findByExecution({required bool ended}) {
    return _repository.database.transaction(() async {
      final rows = await _repository.database
          .customSelect(
            ended
                ? "SELECT DISTINCT mission_id FROM execution_events WHERE type = 'END'"
                : "SELECT DISTINCT mission_id FROM execution_events WHERE type = 'START' AND mission_id NOT IN (SELECT mission_id FROM execution_events WHERE type = 'END')",
            readsFrom: {_repository.database.executionEvents},
          )
          .get();
      final missionRows = <MissionRow>[];
      final ids = rows.map((row) => row.read<String>('mission_id')).toList();
      for (var offset = 0; offset < ids.length; offset += 200) {
        final page = ids.sublist(offset, (offset + 200).clamp(0, ids.length));
        missionRows.addAll(
          await (_repository.database.select(
            _repository.database.missions,
          )..where((row) => row.id.isIn(page))).get(),
        );
      }
      if (missionRows.length != ids.length) {
        throw const FormatException('执行事件所属任务缺失');
      }
      final details = await _detailsForRows(missionRows);
      details.sort((a, b) {
        if (!ended && a.phase != b.phase) {
          int priority(MissionPhase phase) => switch (phase) {
            MissionPhase.running => 0,
            MissionPhase.paused => 1,
            _ => 2,
          };
          return priority(a.phase).compareTo(priority(b.phase));
        }
        if (ended) {
          final dateOrder = (b.effectiveOccurrenceDate ?? '').compareTo(
            a.effectiveOccurrenceDate ?? '',
          );
          if (dateOrder != 0) return dateOrder;
        }
        final timeOrder = b.events.last.occurredAt.compareTo(
          a.events.last.occurredAt,
        );
        return timeOrder != 0
            ? timeOrder
            : a.mission.id.compareTo(b.mission.id);
      });
      return details;
    });
  }

  Future<OperationReceiptInfo?> findOperationReceipt(String operationId) async {
    final query = _repository.database.select(
      _repository.database.operationReceipts,
    )..where((table) => table.id.equals(operationId));
    final row = await query.getSingleOrNull();
    if (row == null) return null;
    return OperationReceiptInfo(
      id: row.id,
      kind: row.kind,
      fingerprint: row.fingerprint,
      entityId: row.entityId,
      resultJson: row.resultJson,
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        row.createdAt,
        isUtc: true,
      ),
    );
  }

  Future<MissionDetail?> findDetail(String missionId) async {
    return _repository.database.transaction(() async {
      // 以下变量是表的引用，用于组织查询；此时还没有读出某个任务的数据。
      final missions = _repository.database.missions;
      final schedules = _repository.database.missionScheduleRevisions;
      final plans = _repository.database.executionPlans;
      // ① 按同一个 missionId 关联“任务本身＋排期＋行动方案”。
      // 查排期是为了详情展示和 START 的计划绑定，不是用计划日期判断执行中。
      // 一个任务可以有多个排期版本，所以按版本倒序，只取最新的一条。
      // leftOuterJoin 会保留任务本身，即使它缺少排期/方案，也能与“任务不存在”区分。
      final query = _repository.database.select(missions).join([
        leftOuterJoin(schedules, schedules.missionId.equalsExp(missions.id)),
        leftOuterJoin(plans, plans.missionId.equalsExp(missions.id)),
      ]);
      query.where(missions.id.equals(missionId));
      query.orderBy([OrderingTerm.desc(schedules.revisionNumber)]);
      query.limit(1);
      // 到这里才执行 SQL；同一条语句读取三表，避免分开读时混入不同次修改的结果。
      final joinedRow = await query.getSingleOrNull();
      if (joinedRow == null) return null;
      final scheduleRow = joinedRow.readTableOrNull(schedules);
      final planRow = joinedRow.readTableOrNull(plans);
      if (scheduleRow == null || planRow == null) {
        throw const FormatException('任务缺少排期或执行方案');
      }
      // ② 查这个任务的全部执行事件，按 sequence 从1向后读，不按计划日期截断。
      // eventRows 是数据库行；下面转换得到的 events 才是业务对象列表。
      final eventRows =
          await (_repository.database.select(
                  _repository.database.executionEvents,
                )
                ..where((table) => table.missionId.equals(missionId))
                ..orderBy([(table) => OrderingTerm.asc(table.sequence)]))
              .get();
      // ③ 失败事实供已结束任务校验报告；刚创建或刚开始时通常为空。
      final failureRows = await (_repository.database.select(
        _repository.database.failureRecords,
      )..where((table) => table.missionId.equals(missionId))).get();
      final evidenceRows =
          await (_repository.database.select(
                  _repository.database.evidenceRecords,
                )
                ..where((table) => table.missionId.equals(missionId))
                ..orderBy([
                  (table) => OrderingTerm.asc(table.submittedAt),
                  (table) => OrderingTerm.asc(table.id),
                ]))
              .get();
      // ④ 行对象 → 业务对象。下面五个变量正好对应 MissionDetail 的五个成员。
      final mission = missionFromRow(joinedRow.readTable(missions));
      final schedule = scheduleFromRow(scheduleRow);
      final executionPlan = executionPlanFromRow(planRow);
      final events = List<ExecutionEvent>.unmodifiable(
        eventRows.map(eventFromRow),
      );
      final failures = List<FailureRecord>.unmodifiable(
        failureRows.map(failureFromRow),
      );
      // 查询中的坏历史在 Future 内报错，由页面显示读取失败，不等到排版时崩溃。
      final evidence = List<Evidence>.unmodifiable(
        (await hydrateEvidenceRows(
          _repository.database,
          evidenceRows,
        )).map(evidenceFromRow),
      );
      // 读取时同步复查材料配置口径；数据被外部损坏时明确报错，不默默显示。
      validateEvidenceRequirement(
        policy: mission.verificationPolicy,
        criteria: executionPlan.verificationCriteria,
        schedule: schedule,
      );
      deriveMissionPhase(mission, events, failures, evidence, schedule);
      // ⑤ 打包成一次查询结果，不新增一张详情表，也不向数据库写入阶段。
      final reportRows =
          await (_repository.database.select(
                  _repository.database.userExecutionReports,
                )
                ..where((t) => t.missionId.equals(missionId))
                ..orderBy([(t) => OrderingTerm.asc(t.reportedAt)]))
              .get();
      return MissionDetail(
        userReports: reportRows.map(userReportFromRow).toList(),
        mission: mission,
        schedule: schedule,
        executionPlan: executionPlan,
        events: events,
        failures: failures,
        evidence: evidence,
        ownershipInfo: await findOwnershipInfo(mission.ownership),
      );
    });
  }

  // 调用者：MissionService.findScheduledOn。
  // 输入：计划日期。过程：关联 → 筛选 → 排序 → 执行 → 转换。输出：业务列表。
  Future<List<ScheduledMission>> findScheduledOn(String scheduledDate) async {
    return _repository.database.transaction(() async {
      // 1. 指定要读取的两张表，并说明它们通过任务编号关联。
      // 这一步构造查询对象，尚未执行 SQL。
      final missions = _repository.database.missions;
      final schedules = _repository.database.missionScheduleRevisions;
      final query = _repository.database.select(missions).join([
        innerJoin(schedules, schedules.missionId.equalsExp(missions.id)),
      ]);
      // 2. 筛选当前排期与所选日期。比如A/1排在周一、A/2改到周二：
      // 先确定最新是A/2，再比较周二，不能因A/1曾排在周一就仍显示在周一。
      // history 是排期表的别名；子查询针对当前任务找最大版本，不限制日期。
      final history = _repository.database.alias(schedules, 'schedule_history');
      final latestVersionForMission = _repository.database.selectOnly(history)
        ..addColumns([history.revisionNumber.max()])
        ..where(history.missionId.equalsExp(missions.id));
      final isLatestSchedule = schedules.revisionNumber.equalsExp(
        subqueryExpression<int>(latestVersionForMission),
      );
      final isSelectedDate = schedules.scheduledDate.equals(scheduledDate);
      query.where(isLatestSchedule & isSelectedDate);
      // 3. 固定任务先排，自选随后；两类分别使用各自的时间字段，再按 id 稳定排序。
      // caseMatch 将这条条件表达成 SQL 的 CASE；此时仍在描述查询规则。
      final fixedBeforeFlexible = schedules.timePolicy.caseMatch<int>(
        when: {const Constant('FIXED'): const Constant(0)},
        orElse: const Constant(1),
      );
      final timeWithinGroup = schedules.timePolicy.caseMatch<int>(
        when: {const Constant('FIXED'): schedules.fixedStartAt},
        orElse: missions.createdAt,
      );
      query.orderBy([
        OrderingTerm.asc(fixedBeforeFlexible),
        OrderingTerm.asc(timeWithinGroup),
        OrderingTerm.asc(missions.id),
      ]);
      // 4. get() 才真正执行一次 SQL。await 完成后，rows 是 List<TypedResult>。
      // 每个 TypedResult 同时带着关联到的任务行和排期行。
      final rows = await query.get();
      // 5. 逐条转换：关联结果 → 两张表的行对象 → 两个业务对象 → 一项列表数据。
      final details = await _detailsForRows([
        for (final row in rows) row.readTable(missions),
      ]);
      final result = [
        for (final detail in details)
          ScheduledMission(
            mission: detail.mission,
            schedule: detail.schedule,
            phase: detail.phase,
            events: detail.events,
          ),
      ];
      // 6. 交回查询业务入口，再由它把同一份列表交给今天页。
      return result;
    });
  }
}

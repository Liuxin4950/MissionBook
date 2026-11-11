part of 'drift_mission_repository.dart';

/// 同一连接与事务中的任务持久化职责。
class _MissionScheduling {
  _MissionScheduling(this._repository);
  final DriftMissionRepository _repository;
  Future<List<ScheduleConflict>> checkPlan(ScheduleProposal plan) =>
      _repository.database.transaction(() => _planConflicts(plan));
  Future<List<ScheduleConflict>> _planConflicts(ScheduleProposal plan) async {
    final occupied = <ExistingScheduleSlot>[];
    final replacedIds = plan.items.map((item) => item.missionId).toList();
    final placeholders = List.filled(replacedIds.length, '?').join(',');
    final fixed = plan.items
        .where((item) => item.schedule.fixedStartAt != null)
        .toList();
    if (fixed.isEmpty) return scheduleProposalConflicts(plan, occupied);
    // 一次读取与任一提案时段相交的当前安排；不能静默隐藏第四项及后续冲突。
    final windows = List.filled(
      fixed.length,
      '(s.fixed_start_at < ? AND s.fixed_start_at + s.planned_duration_minutes * 60000 > ?)',
    ).join(' OR ');
    final rows = await _repository.database
        .customSelect(
          '''
        SELECT m.id, substr(m.title, 1, 120) AS title, s.fixed_start_at AS conflict_start, s.planned_duration_minutes AS conflict_minutes
        FROM missions m JOIN mission_schedule_revisions s ON s.mission_id = m.id
        WHERE m.cancelled_at IS NULL AND s.fixed_start_at IS NOT NULL
          AND NOT EXISTS (SELECT 1 FROM mission_schedule_revisions newer
            WHERE newer.mission_id = m.id AND newer.revision_number > s.revision_number)
          AND NOT EXISTS (SELECT 1 FROM execution_events e
            WHERE e.mission_id = m.id AND e.type = 'END')
          AND m.id NOT IN ($placeholders)
          AND ($windows)
        ORDER BY s.fixed_start_at, m.id
      ''',
          variables: [
            for (final id in replacedIds) Variable<String>(id),
            for (final item in fixed) ...[
              Variable<int>(
                item.schedule.fixedStartAt!
                    .add(
                      Duration(minutes: item.schedule.plannedDurationMinutes),
                    )
                    .millisecondsSinceEpoch,
              ),
              Variable<int>(item.schedule.fixedStartAt!.millisecondsSinceEpoch),
            ],
          ],
        )
        .get();
    for (final row in rows) {
      occupied.add(
        ExistingScheduleSlot(
          missionId: row.read<String>('id'),
          title: row.read<String>('title'),
          start: DateTime.fromMillisecondsSinceEpoch(
            row.read<int>('conflict_start'),
            isUtc: true,
          ),
          minutes: row.read<int>('conflict_minutes'),
        ),
      );
    }
    return scheduleProposalConflicts(plan, occupied);
  }

  Future<OperationReceiptInfo> applyPlan(ScheduleProposal plan) =>
      _repository.database.transaction(() async {
        await _repository._acquireGlobalWrite();
        final fingerprint = _planFingerprint(plan);
        final previous = await _repository.findOperationReceipt(plan.id);
        if (previous != null) {
          if (previous.kind != 'planMissions' ||
              previous.fingerprint != fingerprint) {
            throw StateError('这份计划已经保存为其他内容，请核对结果后重新提出');
          }
          return previous;
        }
        final conflicts = await _planConflicts(plan);
        if (conflicts.isNotEmpty) {
          final result = jsonEncode({
            'status': 'blocked',
            'operationId': plan.id,
            'planId': plan.id,
            'counts': {
              'requested': plan.items.length,
              'changed': 0,
              'rejected': plan.items.length,
            },
            'issues': [
              for (final conflict in conflicts)
                {
                  'code': conflict.otherItemId == null
                      ? 'existing_overlap'
                      : 'plan_overlap',
                  'itemId': conflict.itemId,
                  'otherMissionId': conflict.otherMissionId,
                  'otherItemId': ?conflict.otherItemId,
                  'message': conflict.message,
                },
            ],
          });
          await _repository.database
              .into(_repository.database.operationReceipts)
              .insert(
                OperationReceiptsCompanion.insert(
                  id: plan.id,
                  kind: 'planMissions',
                  fingerprint: fingerprint,
                  entityId: plan.id,
                  resultJson: result,
                  createdAt: _repository._now().millisecondsSinceEpoch,
                ),
              );
          return (await _repository.findOperationReceipt(plan.id))!;
        }
        for (final item in plan.items) {
          final creation = item.creation;
          if (creation != null) {
            // 复用创建和编辑的业务校验；嵌套事务处于本次外层事务中。
            await _repository.create(
              mission: creation.mission,
              initialSchedule: creation.schedule,
              executionPlan: creation.plan,
            );
          } else {
            final original = item.original!;
            await _repository.edit(
              original: original,
              title: original.mission.title,
              objective: original.executionPlan.objective,
              schedule: item.schedule,
            );
          }
        }
        final now = _repository._now();
        final result = jsonEncode({
          'ok': true,
          'operation': 'planMissions',
          'planId': plan.id,
          'savedCount': plan.items.length,
          'items': [
            for (final item in plan.items)
              {
                'itemId': item.id,
                'kind': item.isCreation ? 'CREATE' : 'RESCHEDULE',
                'missionId': item.missionId,
                'title': item.title,
                'scheduledDate': item.schedule.scheduledDate,
                'plannedMinutes': item.schedule.plannedDurationMinutes,
                'fixedStartAt': item.schedule.fixedStartAt
                    ?.toUtc()
                    .toIso8601String(),
              },
          ],
          'references': [
            for (final item in plan.items)
              {'type': 'mission', 'id': item.missionId, 'title': item.title},
          ],
        });
        await _repository.database
            .into(_repository.database.operationReceipts)
            .insert(
              OperationReceiptsCompanion.insert(
                id: plan.id,
                kind: 'planMissions',
                fingerprint: fingerprint,
                entityId: plan.id,
                resultJson: result,
                createdAt: now.millisecondsSinceEpoch,
              ),
            );
        return (await _repository.findOperationReceipt(plan.id))!;
      });
  Future<List<String>> reconcileScheduledMissions() async {
    // 到期事实先独立提交；后面的自动开始失败不能撤销已完成的停止。
    final stopped = await reconcileScheduledEnds();
    final started = await _repository.database.transaction(() async {
      await _repository._acquireGlobalWrite();
      final changed = <String>[];
      if ((await _repository.findActive()).any(
        (detail) => detail.phase == MissionPhase.running,
      )) {
        return changed;
      }
      final skipped = <String>{};
      for (var attempt = 0; attempt < 64; attempt++) {
        final checkedAt = _repository._now().millisecondsSinceEpoch;
        final row = await _repository.database
            .customSelect(
              '''
SELECT m.id ${DriftMissionRepository._unstartedFixed}
 AND r.fixed_start_at <= ? AND r.fixed_start_at+r.planned_duration_minutes*60000 > ?
 ${skipped.isEmpty ? '' : 'AND m.id NOT IN (${List.filled(skipped.length, '?').join(',')})'}
ORDER BY r.fixed_start_at,m.id LIMIT 1
''',
              variables: [
                Variable<int>(checkedAt),
                Variable<int>(checkedAt),
                for (final id in skipped) Variable<String>(id),
              ],
            )
            .getSingleOrNull();
        if (row == null) return changed;
        final detail = await _repository.findDetail(row.read<String>('id'));
        if (detail == null) throw const FormatException('到点任务缺失');
        if (detail.phase != MissionPhase.notStarted) {
          skipped.add(detail.mission.id);
          continue;
        }
        final startedAt = _repository._now();
        final end = detail.schedule.fixedStartAt!.add(
          Duration(minutes: detail.schedule.plannedDurationMinutes),
        );
        if (startedAt.isBefore(detail.schedule.fixedStartAt!) ||
            !startedAt.isBefore(end)) {
          skipped.add(detail.mission.id);
          continue;
        }
        try {
          await _repository._execute(
            ExecutionCommand(
              id: 'scheduled-start-${detail.schedule.id}',
              missionId: detail.mission.id,
              expectedSequence: 0,
              type: ExecutionEventType.start,
              scheduleRevisionId: detail.schedule.id,
            ),
            occurredAt: detail.schedule.fixedStartAt,
          );
        } on ExecutionConflict {
          // 异步重读期间可能刚好跨过结束时刻；跳过该候选，保留前面已到期的 STOP。
          if (!_repository._now().isBefore(end)) continue;
          rethrow;
        }
        return [...changed, detail.mission.id];
      }
      return changed;
    });
    return [...stopped, ...started];
  }

  /// 调度唤醒和普通动作共用：先停止过期执行，再接受新的用户操作。
  /// 调度延迟不延长计时；只追加 STOP，不虚构用户完成报告。
  Future<List<String>> _stopDueScheduledMissions() async {
    final changed = <String>[];
    for (final detail in await _repository.findActive()) {
      final end = scheduledExecutionEnd(detail.schedule, detail.events);
      if (end == null || end.isAfter(_repository._now())) continue;
      // 旧版本可能在整个时段之后才写 START；保留日志顺序，计时仍由计划边界封顶。
      final stopAt = end.isBefore(detail.events.last.occurredAt)
          ? detail.events.last.occurredAt
          : end;
      await _repository._execute(
        ExecutionCommand(
          id: 'scheduled-stop-${detail.events.first.id}',
          missionId: detail.mission.id,
          expectedSequence: detail.lastSequence,
          type: ExecutionEventType.stop,
        ),
        occurredAt: stopAt,
      );
      changed.add(detail.mission.id);
    }
    return changed;
  }

  Future<List<String>> reconcileScheduledEnds() =>
      _repository.database.transaction(() async {
        await _repository._acquireGlobalWrite();
        return _stopDueScheduledMissions();
      });
}

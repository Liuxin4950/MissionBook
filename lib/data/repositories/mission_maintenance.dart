part of 'drift_mission_repository.dart';

/// 写锁内核对范围及全部事实，整批提交；已撤销执行留在独立历史回执中。
class _MissionMaintenance {
  _MissionMaintenance(this.owner);
  final DriftMissionRepository owner;
  AppDatabase get db => owner.database;

  static const facts = [
    'execution_events',
    'failure_records',
    'user_execution_reports',
    'evidence_records',
  ];

  Future<List<Map<String, Object?>>> rows(
    String table,
    String id, {
    String column = 'mission_id',
  }) async =>
      (await db
              .customSelect(
                'SELECT * FROM $table WHERE $column=? ORDER BY id',
                variables: [Variable(id)],
              )
              .get())
          .map((r) => Map<String, Object?>.from(r.data))
          .toList();

  Future<Map<String, Object?>> snapshot(String id) async => {
    'mission': await rows('missions', id, column: 'id'),
    'plans': await rows('execution_plans', id),
    'schedules': await rows('mission_schedule_revisions', id),
    for (final table in facts) table: await rows(table, id),
  };

  Future<MissionMaintenanceProposal> prepare({
    required MissionMaintenanceAction action,
    List<String>? ids,
    String? goalId,
    String? beforeDate,
    String? phase,
  }) => db.transaction(() async {
    if (ids != null &&
        (ids.isEmpty ||
            ids.length > 10000 ||
            ids.toSet().length != ids.length)) {
      throw ArgumentError('任务编号需为 1–10000 个且不能重复');
    }
    if (beforeDate != null) validateScheduledDate(beforeDate);
    if (phase != null && !MissionPhase.values.any((p) => p.name == phase)) {
      throw ArgumentError('无效任务阶段');
    }
    final all = ids == null
        ? await owner.findAllDetails()
        : await owner.findDetailsByIds(ids);
    if (ids != null && all.length != ids.length) {
      final found = {for (final d in all) d.mission.id};
      final missing = ids.where((id) => !found.contains(id)).toList();
      throw MissionEditConflict(
        '有任务不存在或已删除：${missing.take(20).join('、')}${missing.length > 20 ? ' 等' : ''}，请刷新',
      );
    }
    final items =
        all
            .where(
              (d) =>
                  (goalId == null || d.mission.goalId == goalId) &&
                  (beforeDate == null ||
                      d.schedule.scheduledDate.compareTo(beforeDate) < 0) &&
                  (phase == null || d.phase.name == phase),
            )
            .toList()
          ..sort((a, b) => a.mission.id.compareTo(b.mission.id));
    if (items.length > 10000) throw ArgumentError('单次操作最多 10000 项，请缩小范围');
    if (action == MissionMaintenanceAction.reset) {
      final unfinished = items
          .where((d) => !d.events.any((e) => e.type == ExecutionEventType.end))
          .toList();
      if (unfinished.isNotEmpty) {
        throw ArgumentError(
          '只有已结束任务可以撤销执行；以下任务尚未结束：${unfinished.take(20).map((d) => '${d.mission.id}（${d.mission.title}）').join('、')}${unfinished.length > 20 ? ' 等' : ''}',
        );
      }
    }
    final state = [for (final item in items) await snapshot(item.mission.id)];
    final fingerprint = sha256
        .convert(
          utf8.encode(
            jsonEncode({
              'action': action.name,
              'ids': ids,
              'goalId': goalId,
              'beforeDate': beforeDate,
              'phase': phase,
              'state': state,
            }),
          ),
        )
        .toString();
    return MissionMaintenanceProposal(
      action: action,
      items: items,
      fingerprint: fingerprint,
      ids: ids,
      goalId: goalId,
      beforeDate: beforeDate,
      phase: phase,
    );
  });

  Future<List<Map<String, Object?>>> archives(String id) async {
    final records =
        await (db.select(db.operationReceipts)
              ..where(
                (t) =>
                    t.kind.equals('missionExecutionArchive') &
                    t.entityId.equals(id),
              )
              ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
            .get();
    return [
      for (final r in records)
        Map<String, Object?>.from(jsonDecode(r.resultJson) as Map),
    ];
  }

  Future<Map<String, Object?>> apply(
    MissionMaintenanceProposal proposal,
    String operationId,
  ) => db.transaction(() async {
    if (operationId.trim().isEmpty) throw ArgumentError('缺少操作编号');
    await owner._acquireGlobalWrite();
    final kind = 'missions_${proposal.action.name}';
    final receipt = await owner.findOperationReceipt(operationId);
    if (receipt != null) {
      if (receipt.kind != kind || receipt.fingerprint != proposal.fingerprint) {
        throw const MissionEditConflict('操作编号已用于其他请求');
      }
      return Map<String, Object?>.from(jsonDecode(receipt.resultJson) as Map);
    }
    final current = await prepare(
      action: proposal.action,
      ids: proposal.ids,
      goalId: proposal.goalId,
      beforeDate: proposal.beforeDate,
      phase: proposal.phase,
    );
    if (current.fingerprint != proposal.fingerprint) {
      throw const MissionEditConflict('任务范围或内容已变化，本批次未执行，请重新预览');
    }
    final changed = <String>[];
    final skipped = <String>[];
    final now = owner._now().millisecondsSinceEpoch;
    for (final d in current.items) {
      final id = d.mission.id;
      if (proposal.action == MissionMaintenanceAction.cancel) {
        if (d.phase != MissionPhase.notStarted) {
          skipped.add(id);
          continue;
        }
        await owner.cancel(id);
      } else {
        if (proposal.action == MissionMaintenanceAction.reset) {
          final original = await snapshot(id);
          for (final submissionId
              in d.evidence.map((e) => e.submissionId).toSet()) {
            await db
                .into(db.operationReceipts)
                .insert(
                  OperationReceiptsCompanion.insert(
                    id: 'revoked-evidence:$submissionId',
                    kind: 'revokedEvidence',
                    fingerprint: proposal.fingerprint,
                    entityId: id,
                    resultJson: '{}',
                    createdAt: now,
                  ),
                );
          }
          for (final event in d.events) {
            await db
                .into(db.operationReceipts)
                .insert(
                  OperationReceiptsCompanion.insert(
                    id: 'revoked:${event.id}',
                    kind: 'revokedExecution',
                    fingerprint: proposal.fingerprint,
                    entityId: id,
                    resultJson: '{}',
                    createdAt: now,
                  ),
                );
          }
          await db
              .into(db.operationReceipts)
              .insert(
                OperationReceiptsCompanion.insert(
                  id: '$operationId:archive:$id',
                  kind: 'missionExecutionArchive',
                  fingerprint: proposal.fingerprint,
                  entityId: id,
                  resultJson: jsonEncode({'archivedAt': now, ...original}),
                  createdAt: now,
                ),
              );
        }
        // 同批删除自引用链；其他任务的再次尝试保留，只解除来源外键。
        for (final table in facts) {
          await db.customStatement('DELETE FROM $table WHERE mission_id=?', [
            id,
          ]);
        }
        if (proposal.action == MissionMaintenanceAction.delete) {
          // 复用任务更新触发器使目标/祖先摘要失效；随后清理被删除任务自身的队列。
          await db.customStatement(
            'UPDATE missions SET updated_at=updated_at WHERE id=?',
            [id],
          );
          await db.customStatement(
            'UPDATE missions SET source_mission_id=NULL, relation_type=NULL WHERE source_mission_id=?',
            [id],
          );
          await db.customStatement(
            'DELETE FROM execution_plans WHERE mission_id=?',
            [id],
          );
          await db.customStatement(
            'DELETE FROM mission_schedule_revisions WHERE mission_id=?',
            [id],
          );
          await db.customStatement(
            'DELETE FROM operation_receipts WHERE entity_id=?',
            [id],
          );
          await db.customStatement(
            'UPDATE assistant_sessions SET mission_id=NULL WHERE mission_id=?',
            [id],
          );
          await db.customStatement('DELETE FROM missions WHERE id=?', [id]);
        } else {
          // 追加自选排期，原固定窗口保留在历史里，避免撤销后被定时器立即开始。
          await db.customStatement(
            '''INSERT INTO mission_schedule_revisions
            (id,mission_id,revision_number,scheduled_date,time_zone,time_policy,fixed_start_at,planned_duration_minutes,evidence_deadline_at,change_reason,changed_at)
            VALUES (?,?,?,?,?,'FLEXIBLE',NULL,?,?,?,?)''',
            [
              '$operationId:schedule:$id',
              id,
              d.schedule.revisionNumber + 1,
              d.schedule.scheduledDate,
              d.schedule.timeZone,
              d.schedule.plannedDurationMinutes,
              d.schedule.evidenceDeadlineAt?.millisecondsSinceEpoch,
              '撤销误标执行，待重新安排',
              now,
            ],
          );
          await db.customStatement(
            'UPDATE missions SET cancelled_at=NULL, evidence_waived_at=NULL, updated_at=? WHERE id=?',
            [now, id],
          );
        }
        for (final table in ['analysis_jobs', 'analysis_versions']) {
          await db.customStatement(
            "DELETE FROM $table WHERE scope='mission' AND target_id=?",
            [id],
          );
        }
      }
      changed.add(id);
    }
    final result = <String, Object?>{
      'status': 'succeeded',
      'action': proposal.action.name,
      'count': changed.length,
      'missionIds': changed,
      'skippedIds': skipped,
      'operationId': operationId,
    };
    await db
        .into(db.operationReceipts)
        .insert(
          OperationReceiptsCompanion.insert(
            id: operationId,
            kind: kind,
            fingerprint: proposal.fingerprint,
            entityId: operationId,
            resultJson: jsonEncode(result),
            createdAt: now,
          ),
        );
    return result;
  });
}

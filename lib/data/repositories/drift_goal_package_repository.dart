import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:timezone/timezone.dart' as tz;

import '../../domain/entities/goal.dart';
import '../../domain/entities/goal_package_import.dart';
import '../../domain/repositories/goal_package_repository.dart';
import '../../domain/rules/goal_package_rules.dart';
import '../local/app_database.dart';
import 'drift_mission_repository.dart';

/// 取得业务库写权限后重查回执与排期；全部目标、任务和回执只有一次提交。
class DriftGoalPackageRepository implements GoalPackageRepository {
  DriftGoalPackageRepository(
    this.database, {
    DateTime Function() clock = DateTime.now,
  }) : _clock = clock;
  final AppDatabase database;
  final DateTime Function() _clock;
  DateTime _now() => DateTime.fromMillisecondsSinceEpoch(
    _clock().toUtc().millisecondsSinceEpoch,
    isUtc: true,
  );

  @override
  Future<GoalImportResult?> receipt(
    String schema,
    String packageId,
    String hash,
  ) async {
    final row =
        await (database.select(database.importReceipts)..where(
              (row) =>
                  row.schemaName.equals(schema) &
                  row.packageId.equals(packageId),
            ))
            .getSingleOrNull();
    if (row == null) return null;
    if (row.payloadSha256 != hash) {
      throw const GoalImportException(
        'PACKAGE_ID_CONFLICT',
        '/packageId',
        '此包编号已用于不同内容，请修改原计划或明确另建副本',
      );
    }
    return GoalImportResult(
      goalId: row.goalId,
      nodeCount: row.nodeCount,
      missionCount: row.missionCount,
      alreadyImported: true,
    );
  }

  @override
  Future<String?> duplicateContent(String schema, String hash) async {
    final row =
        await (database.select(database.importReceipts)
              ..where(
                (row) =>
                    row.schemaName.equals(schema) &
                    row.contentSha256.equals(hash),
              )
              ..limit(1))
            .getSingleOrNull();
    return row?.goalId;
  }

  @override
  Future<void> review(
    GoalImportStage stage,
    GoalImportPreview preview,
    GoalImportOptions options,
  ) async {
    if (await receipt(preview.schema, preview.packageId, preview.payloadHash) !=
        null) {
      return;
    }
    await stage.assertReady(preview.jobId, preview.payloadHash);
    await _review(stage, preview, options, _now());
  }

  Future<void> _review(
    GoalImportStage stage,
    GoalImportPreview preview,
    GoalImportOptions options,
    DateTime now, {
    bool checkConflicts = true,
    GoalImportCancellation? cancellation,
  }) async {
    final windows = <GoalImportWindow>[];
    var offset = 0;
    while (true) {
      cancellation?.check();
      final page = await stage.entries(
        preview.jobId,
        'MISSION',
        offset: offset,
        limit: 100,
      );
      if (page.isEmpty) break;
      for (final entry in page) {
        final value = entry.resolved!;
        final path = '/missions/${entry.sourceIndex}/schedule';
        final deadline = value['evidenceDeadlineAt'] as String?;
        if (deadline != null && !DateTime.parse(deadline).isAfter(now)) {
          throw GoalImportException(
            'INVALID_DEADLINE',
            '$path/evidenceDeadlineAt',
            '强制材料截止已过，请调整后重新预览',
          );
        }
        final at = value['fixedStartAt'] as String?;
        if (at != null) {
          final start = DateTime.parse(at).toUtc();
          final end = start.add(
            Duration(minutes: value['plannedDurationMinutes']! as int),
          );
          if (!now.isBefore(start) &&
              now.isBefore(end) &&
              !options.allowDueAutoStart) {
            throw GoalImportException(
              'DUE_AUTO_START',
              path,
              '任务已在计划时段内，确认允许导入后自动开始，或重新排期',
            );
          }
          if (!now.isBefore(end) && !options.keepPastSchedules) {
            throw GoalImportException(
              'PAST_SCHEDULE',
              path,
              '已错过计划时段，请重新排期或明确保留过期计划',
            );
          }
          windows.add(
            GoalImportWindow(entry.id, value['title']! as String, start, end),
          );
        } else if (!options.keepPastSchedules) {
          final zone = tz.getLocation(value['timeZone']! as String);
          final local = tz.TZDateTime.from(now, zone);
          final today =
              '${local.year.toString().padLeft(4, '0')}-${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')}';
          if ((value['scheduledDate']! as String).compareTo(today) < 0) {
            throw GoalImportException(
              'PAST_SCHEDULE',
              path,
              '自选计划日期已过，请调整或明确保留',
            );
          }
        }
      }
      offset += page.length;
    }
    if (!checkConflicts || options.allowOverlaps || windows.isEmpty) return;
    windows.sort((a, b) => a.start.compareTo(b.start));
    GoalImportWindow? previous;
    for (final window in windows) {
      if (previous != null && window.start.isBefore(previous.end)) {
        throw GoalImportException(
          'SCHEDULE_CONFLICT',
          '/missions',
          '固定计划重叠：「${previous.title}」与「${window.title}」；请调整或明确允许重叠',
        );
      }
      if (previous == null || window.end.isAfter(previous.end)) {
        previous = window;
      }
    }
    // 每批最多 100 个窗口，使用索引与最新排期谓词查已有冲突，不逐任务装配材料。
    for (var index = 0; index < windows.length; index += 100) {
      cancellation?.check();
      final page = windows.sublist(
        index,
        (index + 100).clamp(0, windows.length),
      );
      final args = <Variable>[];
      for (final window in page) {
        args.add(Variable<int>(window.start.millisecondsSinceEpoch));
        args.add(Variable<int>(window.end.millisecondsSinceEpoch));
      }
      args.add(Variable<String>(preview.goalId));
      final values = List.filled(page.length, '(?,?)').join(',');
      final row = await database.customSelect('''
WITH incoming(starts,ends) AS (VALUES $values)
SELECT m.title FROM incoming i
JOIN mission_schedule_revisions r
 ON r.time_policy='FIXED' AND r.fixed_start_at < i.ends
 AND r.fixed_start_at + r.planned_duration_minutes * 60000 > i.starts
JOIN missions m ON m.id=r.mission_id
WHERE m.cancelled_at IS NULL AND (m.goal_id IS NULL OR m.goal_id <> ?)
 AND NOT EXISTS(SELECT 1 FROM execution_events e WHERE e.mission_id=m.id AND e.type IN ('START','END'))
 AND NOT EXISTS(SELECT 1 FROM mission_schedule_revisions newer
   WHERE newer.mission_id=m.id AND newer.revision_number>r.revision_number)
LIMIT 1''', variables: args).getSingleOrNull();
      if (row != null) {
        throw GoalImportException(
          'SCHEDULE_CONFLICT',
          '/missions',
          '与已有固定计划「${row.read<String>('title')}」重叠；请调整或明确允许重叠',
        );
      }
    }
  }

  @override
  Future<GoalImportResult> importPackage(
    GoalImportStage stage,
    GoalImportPreview preview,
    GoalImportOptions options,
    GoalImportCancellation cancellation,
  ) async {
    for (var attempt = 0; ; attempt++) {
      cancellation.check();
      try {
        return await _importOnce(stage, preview, options, cancellation);
      } catch (error) {
        final message = error.toString();
        if (attempt >= 5 ||
            (!message.contains('database is locked') &&
                !message.contains('SQLITE_BUSY'))) {
          rethrow;
        }
        await Future<void>.delayed(Duration(milliseconds: 25 * (1 << attempt)));
      }
    }
  }

  Future<GoalImportResult> _importOnce(
    GoalImportStage stage,
    GoalImportPreview preview,
    GoalImportOptions options,
    GoalImportCancellation cancellation,
  ) => database.transaction(() async {
    // 与目标编辑和执行入口一样，先取得 SQLite 写权限，再读取事实。
    await database.customStatement('UPDATE missions SET id=id WHERE 0');
    final existing = await receipt(
      preview.schema,
      preview.packageId,
      preview.payloadHash,
    );
    if (existing != null) return existing;
    cancellation.check();
    await stage.assertReady(preview.jobId, preview.payloadHash);
    final job = (await stage.pending())!;
    if (job['goalId'] != preview.goalId ||
        jsonEncode(job['root']) != jsonEncode(preview.root)) {
      throw const GoalImportException('PREVIEW_STALE', '/', '目标内容已变化，请重新预览');
    }
    GoalPackageRules.validateRoot(preview.root);
    final now = _now();
    await _review(stage, preview, options, now, cancellation: cancellation);
    final goal = Goal(
      id: preview.goalId,
      title: preview.title,
      description: GoalPackageRules.optional(
        preview.goal,
        'description',
        '/goal',
      ),
      why: GoalPackageRules.optional(preview.goal, 'why', '/goal'),
      status: GoalStatus.active,
      createdAt: now,
      updatedAt: now,
    )..validateForCreation();
    await database
        .into(database.goals)
        .insert(
          GoalsCompanion.insert(
            id: goal.id,
            title: goal.title,
            status: const Value('ACTIVE'),
            description: Value(goal.description),
            why: Value(goal.why),
            createdAt: now.millisecondsSinceEpoch,
            updatedAt: now.millisecondsSinceEpoch,
          ),
        );
    final nodeIds = <int, String>{};
    final nodeKeys = <String, String>{};
    final siblingOrder = <int?, int>{};
    var offset = 0;
    while (true) {
      cancellation.check();
      final page = await stage.entries(
        preview.jobId,
        'NODE',
        offset: offset,
        limit: 100,
      );
      if (page.isEmpty) break;
      final rows = <GoalNodesCompanion>[];
      for (final entry in page) {
        final key = GoalPackageRules.validateNode(
          entry,
          outline: preview.isOutline,
        );
        if (entry.sourceIndex != nodeIds.length ||
            nodeKeys.containsKey(key) ||
            entry.orderIndex != (siblingOrder[entry.parentIndex] ?? 0) ||
            entry.parentIndex != null &&
                !nodeIds.containsKey(entry.parentIndex)) {
          throw const FormatException('暂存节点关系、身份或顺序无效');
        }
        final parentId = nodeIds[entry.parentIndex];
        nodeIds[entry.sourceIndex] = entry.id;
        nodeKeys[key] = entry.id;
        siblingOrder[entry.parentIndex] = entry.orderIndex + 1;
        rows.add(
          GoalNodesCompanion.insert(
            id: entry.id,
            goalId: goal.id,
            parentNodeId: Value(parentId),
            title: (entry.raw['title']! as String).trim(),
            description: Value(
              GoalPackageRules.optional(entry.raw, 'description', '/nodes'),
            ),
            orderIndex: entry.orderIndex,
            createdAt: now.millisecondsSinceEpoch,
            updatedAt: now.millisecondsSinceEpoch,
          ),
        );
      }
      await database.batch(
        (batch) => batch.insertAll(database.goalNodes, rows),
      );
      offset += page.length;
    }
    if (offset != preview.nodeCount) throw const FormatException('节点总数与预览不符');
    offset = 0;
    while (true) {
      cancellation.check();
      await stage.assertReady(preview.jobId, preview.payloadHash);
      final page = await stage.entries(
        preview.jobId,
        'MISSION',
        offset: offset,
        limit: 100,
      );
      if (page.isEmpty) break;
      for (final entry in page) {
        final resolved = GoalPackageRules.resolveMission(
          entry,
          GoalPackageRules.object(preview.root['defaults'], '/defaults'),
          nodeKeys,
        );
        if (jsonEncode(resolved) != jsonEncode(entry.resolved)) {
          throw const GoalImportException(
            'PREVIEW_STALE',
            '/',
            '暂存任务内容已变化，请重新预览',
          );
        }
      }
      final requests = [
        for (final entry in page)
          GoalPackageRules.creation(entry, goal.id, now),
      ];
      await database.batch((batch) {
        batch.insertAll(
          database.missions,
          requests.map((r) => missionToCompanion(r.mission)),
        );
        batch.insertAll(
          database.executionPlans,
          requests.map((r) => executionPlanToCompanion(r.plan)),
        );
        batch.insertAll(
          database.missionScheduleRevisions,
          requests.map((r) => scheduleToCompanion(r.schedule)),
        );
      });
      offset += page.length;
    }
    if (offset != preview.missionCount) {
      throw const FormatException('任务总数与预览不符');
    }
    cancellation.check();
    await stage.assertReady(preview.jobId, preview.payloadHash);
    // 时间仍在走；最终提交前重新检查截止和立即开始门槛，创建时间保持同一值。
    await _review(
      stage,
      preview,
      options,
      _now(),
      checkConflicts: false,
      cancellation: cancellation,
    );
    await database
        .into(database.importReceipts)
        .insert(
          ImportReceiptsCompanion.insert(
            schemaName: preview.schema,
            packageId: preview.packageId,
            schemaVersion: 1,
            payloadSha256: preview.payloadHash,
            contentSha256: preview.contentHash,
            goalId: goal.id,
            importedAt: now.millisecondsSinceEpoch,
            nodeCount: preview.nodeCount,
            missionCount: preview.missionCount,
          ),
        );
    return GoalImportResult(
      goalId: goal.id,
      nodeCount: preview.nodeCount,
      missionCount: preview.missionCount,
    );
  });
}

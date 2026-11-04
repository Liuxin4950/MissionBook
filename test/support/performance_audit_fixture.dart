import 'dart:convert';

import 'package:agent_core/agent_core.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter/foundation.dart';
import 'package:mission_book/application/assistant/assistant_controller.dart';
import 'package:mission_book/application/goals/goal_service.dart';
import 'package:mission_book/application/missions/mission_service.dart';
import 'package:mission_book/data/assistant/drift_session_store.dart';
import 'package:mission_book/data/assistant/drift_unified_reader.dart';
import 'package:mission_book/data/local/app_database.dart';
import 'package:mission_book/data/repositories/drift_goal_repository.dart';
import 'package:mission_book/data/repositories/drift_mission_repository.dart';

import 'assistant_fakes.dart';

/// 性能审查专用隔离数据；不打开应用文件、不读取凭据、不调用真实模型。
class PerformanceAuditFixture {
  PerformanceAuditFixture() {
    database = AppDatabase(
      executor: NativeDatabase.memory().interceptWith(queries),
    );
    missions = MissionService(DriftMissionRepository(database));
    goals = GoalService(DriftGoalRepository(database));
    sessions = AuditSessionStore(database);
  }

  final queries = AuditQueryCounter();
  late final AppDatabase database;
  late final MissionService missions;
  late final GoalService goals;
  late final AuditSessionStore sessions;
  AssistantController? assistant;
  static final epoch = DateTime.utc(2026, 1, 1);
  static const goalId = 'performance-audit-goal';

  AssistantController createAssistant() => assistant = AssistantController(
    sessionStore: sessions,
    settingsStore: MemoryAssistantSettingsStore(),
    unifiedReader: DriftUnifiedReader(database),
    missions: missions,
    goals: goals,
  );

  Future<void> seedSession(
    String id, {
    required int turns,
    required String reply,
    String? lastReply,
    bool referenced = false,
    String? imageUrl,
  }) async {
    final records = <SessionRecord>[];
    final start = referenced ? epoch.add(const Duration(days: 1)) : epoch;
    void add(String type, Map<String, Object?> data) {
      records.add(
        SessionRecord(
          sequence: records.length,
          timestamp: start.add(Duration(milliseconds: records.length)),
          type: type,
          data: data,
        ),
      );
    }

    add('session_created', {
      'id': id,
      'title': '性能审查样本 $id',
      'createdAt': start.toIso8601String(),
      'systemPrompt': '本地性能测试',
      'modelProfileId': 'deepseek-chat',
      'summaryProfileId': 'deepseek-chat',
    });
    for (var i = 0; i < turns; i++) {
      add('turn_started', {'turnId': '$id-turn-$i'});
      add('message_added', {
        'message': {
          'id': '$id-user-$i',
          'role': 'user',
          'content': [
            {'type': 'text', 'text': '请解释第 $i 个问题'},
            if (imageUrl != null) {'type': 'image', 'url': imageUrl},
          ],
        },
      });
      add('message_added', {
        'message': {
          'id': '$id-assistant-$i',
          'role': 'assistant',
          'provider': 'deepseek',
          'model': 'deepseek-chat',
          'content': [
            {
              'type': 'text',
              'text': i == turns - 1 ? lastReply ?? reply : reply,
            },
          ],
        },
      });
      add('turn_ended', {'turnId': '$id-turn-$i', 'reason': 'completed'});
    }
    final handle = await sessions.create(id, initialRecords: records);
    await handle.close();
    if (referenced) await sessions.attachReference(id, goalId: goalId);
  }

  Future<void> seedGoalNodes(int count) async {
    final at = epoch.millisecondsSinceEpoch;
    await database
        .into(database.goals)
        .insert(
          GoalsCompanion.insert(
            id: goalId,
            title: '性能审查目标',
            createdAt: at,
            updatedAt: at,
          ),
        );
    await database.batch((batch) {
      batch.insertAll(database.goalNodes, [
        for (var i = 0; i < count; i++)
          GoalNodesCompanion.insert(
            id: 'audit-node-$i',
            goalId: goalId,
            title: '节点 $i',
            orderIndex: i,
            createdAt: at,
            updatedAt: at,
          ),
      ]);
    });
  }

  /// 各表先后插入合法的完整事实，供历史页规模测量；不修改生产数据。
  Future<void> seedFinishedMissions(int count) async {
    final start = DateTime.utc(2023, 1, 1, 8);
    int time(int i) => start.add(Duration(days: i)).millisecondsSinceEpoch;
    await database.batch((batch) {
      batch.insertAll(database.missions, [
        for (var i = 0; i < count; i++)
          MissionsCompanion.insert(
            id: 'audit-mission-$i',
            title: '历史任务 $i',
            createdAt: time(i) - 86400000,
            updatedAt: time(i),
          ),
      ]);
      batch.insertAll(database.missionScheduleRevisions, [
        for (var i = 0; i < count; i++)
          MissionScheduleRevisionsCompanion.insert(
            id: 'audit-schedule-$i',
            missionId: 'audit-mission-$i',
            revisionNumber: 1,
            scheduledDate: start
                .add(Duration(days: i))
                .toIso8601String()
                .substring(0, 10),
            timeZone: 'UTC',
            plannedDurationMinutes: 30,
            changedAt: time(i) - 86400000,
          ),
      ]);
      batch.insertAll(database.executionPlans, [
        for (var i = 0; i < count; i++)
          ExecutionPlansCompanion.insert(
            id: 'audit-plan-$i',
            missionId: 'audit-mission-$i',
            objective: '历史任务 $i',
            createdAt: time(i) - 86400000,
            updatedAt: time(i) - 86400000,
          ),
      ]);
      batch.insertAll(database.executionEvents, [
        for (var i = 0; i < count; i++) ...[
          ExecutionEventsCompanion.insert(
            id: 'audit-start-$i',
            missionId: 'audit-mission-$i',
            sequence: 1,
            type: 'START',
            occurredAt: time(i),
            scheduleRevisionId: Value('audit-schedule-$i'),
          ),
          ExecutionEventsCompanion.insert(
            id: 'audit-end-$i',
            missionId: 'audit-mission-$i',
            sequence: 2,
            type: 'END',
            occurredAt: time(i) + 1800000,
            userReportedResult: const Value('COMPLETED'),
          ),
        ],
      ]);
    });
  }

  Future<void> dispose() async {
    await assistant?.close();
    assistant?.dispose();
    await missions.dispose();
    await goals.dispose();
    await database.close();
  }
}

/// 只统计真实查询和返回行数；不计入未发生的预期查询。
class AuditQueryCounter extends QueryInterceptor {
  final statements = <String>[];
  int returnedRows = 0;
  void reset() {
    statements.clear();
    returnedRows = 0;
  }

  @override
  Future<List<Map<String, Object?>>> runSelect(
    QueryExecutor executor,
    String statement,
    List<Object?> args,
  ) async {
    statements.add(statement);
    final rows = await executor.runSelect(statement, args);
    returnedRows += rows.length;
    return rows;
  }
}

class AuditSessionStore extends DriftSessionStore {
  AuditSessionStore(super.database);
  final opened = <String>[];
  int readPages = 0;
  int readRows = 0;

  @override
  Future<SessionHandle> open(String id, {bool readOnly = false}) async {
    opened.add(id);
    return _AuditSessionHandle(await super.open(id, readOnly: readOnly), this);
  }
}

class _AuditSessionHandle implements SessionHandle {
  _AuditSessionHandle(this.inner, this.audit);
  final SessionHandle inner;
  final AuditSessionStore audit;
  @override
  String get id => inner.id;
  @override
  int get recordCount => inner.recordCount;
  @override
  bool get readOnly => inner.readOnly;
  @override
  Future<List<SessionRecord>> readRecords({int start = 0, int? limit}) async {
    final rows = await inner.readRecords(start: start, limit: limit);
    audit.readPages++;
    audit.readRows += rows.length;
    return rows;
  }

  @override
  Future<SessionRecord> append(String type, Map<String, Object?> data) =>
      inner.append(type, data);
  @override
  Future<void> close() => inner.close();
}

void emitPerformanceSample(String scenario, Map<String, Object?> values) {
  debugPrint('PERF_AUDIT ${jsonEncode({'scenario': scenario, ...values})}');
}

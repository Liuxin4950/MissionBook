import 'dart:convert';

import 'package:agent_core/agent_core.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mission_book/application/assistant/assistant_tools.dart';
import 'package:mission_book/application/assistant/unified_reader.dart';
import 'package:mission_book/application/goals/goal_service.dart';
import 'package:mission_book/application/missions/mission_service.dart';
import 'package:mission_book/data/local/app_database.dart';
import 'package:mission_book/data/repositories/drift_goal_repository.dart';
import 'package:mission_book/data/repositories/drift_mission_repository.dart';

class _PagedReader implements UnifiedReader {
  @override
  Future<Map<String, Object?>> getMission({
    String? mission,
    String? search,
    String? goalId,
    String? nodeId,
    String? date,
    String? beforeDate,
    String? phase,
    bool summaryOnly = false,
    int offset = 0,
  }) async => {
    'total': 1000,
    'offset': offset,
    'nextOffset': offset + 20,
    'items': [
      for (var i = 0; i < 20; i++)
        {'id': 'm${offset + i}', 'title': 'x' * 2500, 'phase': 'notStarted'},
    ],
    'hint': '仅本页',
  };

  @override
  Future<Map<String, Object?>> content(
    String missionId,
    String field, {
    int offset = 0,
  }) async => throw UnimplementedError();

  @override
  Future<Map<String, Object?>> evidenceContent(
    String evidenceId, {
    int offset = 0,
  }) async => throw UnimplementedError();

  @override
  Future<Map<String, Object?>> getGoal({
    String? goal,
    String? node,
    String? mission,
    int offset = 0,
  }) async => throw UnimplementedError();

  @override
  Future<Map<String, Object?>> getSchedule({
    String? date,
    int offset = 0,
  }) async => throw UnimplementedError();

  @override
  Future<Map<String, Object?>> records(
    String missionId,
    String section, {
    int offset = 0,
  }) async => throw UnimplementedError();
}

void main() {
  test('读取预算失败返回机器可读的已读页和本次尝试范围', () async {
    final db = AppDatabase(executor: NativeDatabase.memory());
    final missions = MissionService(DriftMissionRepository(db));
    final goals = GoalService(DriftGoalRepository(db));
    final tools = AssistantTools(
      unifiedReader: _PagedReader(),
      missions: missions,
      goals: goals,
      resolveCall: (_) => throw StateError('本测试不准备写操作'),
    );
    tools.beginTurn();
    final query = tools.tools.firstWhere(
      (tool) => tool.definition.name == 'getMission',
    );
    final context = ToolContext(
      callId: 'read-call',
      sessionId: 'session',
      cancellation: CancellationToken(),
    );
    ToolOutput? failure;
    for (var offset = 0; offset < 1000; offset += 20) {
      final output = await query.execute({'offset': offset}, context);
      if (output.isError) {
        failure = output;
        break;
      }
      expect(output.text.length, lessThanOrEqualTo(64000));
    }
    expect(failure, isNotNull);
    final result = jsonDecode(failure!.text) as Map<String, dynamic>;
    expect(result['code'], 'read_budget_exceeded');
    expect(result['read'], [
      {
        'tool': 'getMission',
        'offset': 0,
        'limit': 20,
        'total': 1000,
        'nextOffset': 20,
      },
    ]);
    expect(result['attempt'], {'offset': 20, 'total': 1000});
    await missions.dispose();
    await goals.dispose();
    await db.close();
  });
}

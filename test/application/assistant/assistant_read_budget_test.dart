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
  test('按需继续分页，累计字符量不会阻止正式或扩展查询', () async {
    final db = AppDatabase(executor: NativeDatabase.memory());
    final missions = MissionService(DriftMissionRepository(db));
    final goals = GoalService(DriftGoalRepository(db));
    final tools = AssistantTools(
      unifiedReader: _PagedReader(),
      missions: missions,
      goals: goals,
      resolveCall: (_) => throw StateError('本测试不准备写操作'),
      extraTools: [
        AgentTool(
          definition: ToolDefinition(
            name: 'extraRead',
            description: '隔离查询',
            inputSchema: {'type': 'object'},
          ),
          readOnly: true,
          execute: (_, _) async => ToolOutput.success('{"found":true}'),
        ),
      ],
    );
    final query = tools.tools.firstWhere(
      (tool) => tool.definition.name == 'getMission',
    );
    final context = ToolContext(
      callId: 'read-call',
      sessionId: 'session',
      cancellation: CancellationToken(),
    );
    var characters = 0;
    for (var offset = 0; offset < 60; offset += 20) {
      final output = await query.execute({'offset': offset}, context);
      expect(output.isError, false);
      final page = jsonDecode(output.text) as Map;
      expect(page['offset'], offset);
      expect(page['nextOffset'], offset + 20);
      characters += output.text.length;
    }
    expect(characters, greaterThan(64000));
    final extra = await tools.tools
        .firstWhere((t) => t.definition.name == 'extraRead')
        .execute({}, context);
    expect(extra.isError, false);
    expect(jsonDecode(extra.text)['found'], true);
    await missions.dispose();
    await goals.dispose();
    await db.close();
  });
}

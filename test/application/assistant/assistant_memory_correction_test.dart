import 'dart:convert';

import 'package:agent_core/agent_core.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mission_book/application/assistant/assistant_tools.dart';
import 'package:mission_book/application/assistant/context_tools.dart';
import 'package:mission_book/application/goals/goal_service.dart';
import 'package:mission_book/application/memory/memory_service.dart';
import 'package:mission_book/application/missions/mission_service.dart';
import 'package:mission_book/application/records/record_service.dart';
import 'package:mission_book/application/web/web_service.dart';
import 'package:mission_book/data/analysis/drift_analysis_store.dart';
import 'package:mission_book/data/assistant/drift_unified_reader.dart';
import 'package:mission_book/data/local/app_database.dart';
import 'package:mission_book/data/repositories/drift_goal_repository.dart';
import 'package:mission_book/data/repositories/drift_memory_repository.dart';
import 'package:mission_book/data/repositories/drift_mission_repository.dart';
import 'package:mission_book/data/repositories/drift_record_repository.dart';
import 'package:mission_book/data/web/web_settings_store.dart';

/// 记忆更正必须绑定模型实际读到的清单版本，而不是准备时的最新版本。
void main() {
  late AppDatabase db;
  late MemoryService memory;
  late MissionService missions;
  late GoalService goals;
  late AssistantTools tools;
  final prepared = <String, PreparedToolCall>{};
  const statement = '我改到早上跑步了';
  setUp(() {
    prepared.clear();
    db = AppDatabase(executor: NativeDatabase.memory());
    memory = MemoryService(DriftMemoryRepository(db));
    missions = MissionService(DriftMissionRepository(db));
    goals = GoalService(DriftGoalRepository(db));
    final records = RecordService(
      DriftRecordRepository(db),
      missions,
      missions.attachments,
    );
    tools = AssistantTools(
      unifiedReader: DriftUnifiedReader(db),
      missions: missions,
      goals: goals,
      resolveCall: (callId) => prepared[callId]!,
      memory: memory,
      userStatement: () => statement,
      extraTools: contextTools(
        records: records,
        missions: missions,
        memory: memory,
        analysis: DriftAnalysisStore(db),
        analyze: (p, {imageKey, mime, json = true}) async => '',
        web: WebService(
          settings: const SecureWebSettings(),
          quota: DriftSearchQuota(db),
          fetchClient: () => throw StateError('本测试不出网'),
        ),
        userStatement: () => statement,
        snapshot: (callId) => prepared[callId]?.snapshot ?? const {},
      ),
    );
  });
  tearDown(() async {
    await missions.dispose();
    await goals.dispose();
    await db.close();
  });

  Future<void> seed() async {
    await memory.save({
      'id': 'mem-1',
      'content': '我习惯晚上跑步',
      'layer': 'semantic',
      'certainty': 'stated',
      'topic': '跑步时间',
      'sourceKind': 'user',
      'sourceRef': 'test',
    }, userEdited: true);
    await memory.save({
      'id': 'mem-2',
      'content': '我喜欢喝咖啡',
      'layer': 'semantic',
      'certainty': 'stated',
      'topic': '饮品',
      'sourceKind': 'user',
      'sourceRef': 'test',
    }, userEdited: true);
  }

  Future<String> selection(String selectionId) async {
    final page = await memory.select(
      sessionId: 'session',
      selectionId: selectionId,
      search: '跑步',
    );
    final item = (page['items'] as List)
        .cast<Map<String, Object?>>()
        .firstWhere((item) => item['id'] == 'mem-1');
    return item['itemId'] as String;
  }

  Future<Map<String, Object?>> correct(
    String callId,
    String selectionId,
    String itemId, {
    String id = 'mem-1',
  }) async {
    final input = <String, Object?>{
      'id': id,
      'selectionId': selectionId,
      'itemId': itemId,
      'content': '我习惯早上跑步',
      'layer': 'semantic',
      'certainty': 'stated',
      'topic': '跑步时间',
      'basis': statement,
    };
    prepared[callId] = await tools.prepare(
      'saveMemory',
      input,
      sessionId: 'session',
    );
    final output = await tools.tools
        .singleWhere((t) => t.definition.name == 'saveMemory')
        .execute(
          input,
          ToolContext(
            callId: callId,
            sessionId: 'session',
            cancellation: CancellationToken(),
          ),
        );
    return jsonDecode(output.text) as Map<String, Object?>;
  }

  test('更正固定读取时版本并成功写入', () async {
    await seed();
    final itemId = await selection('memory-selection:sel-1');
    final input = <String, Object?>{
      'id': 'mem-1',
      'selectionId': 'memory-selection:sel-1',
      'itemId': itemId,
      'content': '我习惯早上跑步',
      'layer': 'semantic',
      'certainty': 'stated',
      'basis': statement,
    };
    final proposal = await tools.prepare(
      'saveMemory',
      input,
      sessionId: 'session',
    );
    expect(
      (proposal.snapshot['memoryVersion'] as Map)['content'],
      '我习惯晚上跑步',
    );
    prepared['corr-1'] = proposal;
    final output = await tools.tools
        .singleWhere((t) => t.definition.name == 'saveMemory')
        .execute(
          input,
          ToolContext(
            callId: 'corr-1',
            sessionId: 'session',
            cancellation: CancellationToken(),
          ),
        );
    expect((jsonDecode(output.text) as Map)['status'], 'updated');
    final page = await memory.query(search: '跑步');
    expect(
      (page['items'] as List)
          .cast<Map<String, Object?>>()
          .firstWhere((item) => item['id'] == 'mem-1')['content'],
      '我习惯早上跑步',
    );
  });

  test('读取后条目被其他入口修改时按原版本冲突拒绝', () async {
    await seed();
    final itemId = await selection('memory-selection:sel-2');
    await memory.save({
      'id': 'mem-1',
      'content': '用户自己在页面改成的内容',
      'layer': 'semantic',
      'certainty': 'stated',
      'topic': '跑步时间',
      'sourceKind': 'user',
      'sourceRef': 'test',
    }, userEdited: true);
    final result = await correct('corr-2', 'memory-selection:sel-2', itemId);
    expect(result['status'], 'blocked');
    expect(result['reason'], 'changed');
    final page = await memory.query(search: '页面');
    expect(
      (page['items'] as List)
          .cast<Map<String, Object?>>()
          .firstWhere((item) => item['id'] == 'mem-1')['content'],
      '用户自己在页面改成的内容',
    );
  });

  test('更正缺少读取清单或清单引用缺少id时拒绝', () async {
    await seed();
    await expectLater(
      tools.prepare(
        'saveMemory',
        {
          'id': 'mem-1',
          'content': '我习惯早上跑步',
          'layer': 'semantic',
          'certainty': 'stated',
          'basis': statement,
        },
        sessionId: 'session',
      ),
      throwsA(isA<ToolRejected>().having((e) => e.code, 'code', 'stale_proposal')),
    );
    await expectLater(
      tools.prepare(
        'saveMemory',
        {
          'selectionId': 'memory-selection:sel-no-id',
          'itemId': '1',
          'content': '我习惯早上跑步',
          'layer': 'semantic',
          'certainty': 'stated',
          'basis': statement,
        },
        sessionId: 'session',
      ),
      throwsA(isA<ToolRejected>().having((e) => e.code, 'code', 'invalid_selection')),
    );
  });

  test('无效清单、跨会话清单与条目不一致都明确拒绝', () async {
    await seed();
    final itemId = await selection('memory-selection:sel-3');
    await expectLater(
      tools.prepare(
        'saveMemory',
        {
          'id': 'mem-1',
          'selectionId': 'memory-selection:missing',
          'itemId': itemId,
          'content': '我习惯早上跑步',
          'layer': 'semantic',
          'certainty': 'stated',
          'basis': statement,
        },
        sessionId: 'session',
      ),
      throwsA(
        isA<ToolRejected>().having((e) => e.code, 'code', 'invalid_selection'),
      ),
    );
    await expectLater(
      tools.prepare(
        'saveMemory',
        {
          'id': 'mem-1',
          'selectionId': 'memory-selection:sel-3',
          'itemId': itemId,
          'content': '我习惯早上跑步',
          'layer': 'semantic',
          'certainty': 'stated',
          'basis': statement,
        },
        sessionId: 'other-session',
      ),
      throwsA(
        isA<ToolRejected>().having((e) => e.code, 'code', 'invalid_selection'),
      ),
    );
    final otherPage = await memory.select(
      sessionId: 'session',
      selectionId: 'memory-selection:sel-4',
      search: '咖啡',
    );
    final otherItemId =
        (otherPage['items'] as List).cast<Map<String, Object?>>().single['itemId']
            as String;
    await expectLater(
      tools.prepare(
        'saveMemory',
        {
          'id': 'mem-1',
          'selectionId': 'memory-selection:sel-4',
          'itemId': otherItemId,
          'content': '我习惯早上跑步',
          'layer': 'semantic',
          'certainty': 'stated',
          'basis': statement,
        },
        sessionId: 'session',
      ),
      throwsA(
        isA<ToolRejected>().having((e) => e.code, 'code', 'invalid_selection'),
      ),
    );
  });
}
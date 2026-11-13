import 'dart:convert';
import 'dart:io';

import 'package:agent_core/agent_core.dart';
import 'package:drift/drift.dart' show Variable;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mission_book/application/goals/goal_service.dart';
import 'package:mission_book/application/memory/memory_context.dart';
import 'package:mission_book/application/memory/memory_service.dart';
import 'package:mission_book/application/missions/mission_service.dart';
import 'package:mission_book/data/local/app_database.dart';
import 'package:mission_book/data/repositories/drift_goal_repository.dart';
import 'package:mission_book/data/repositories/drift_memory_repository.dart';
import 'package:mission_book/data/repositories/drift_mission_repository.dart';
import 'package:mission_book/domain/entities/mission_ownership.dart';

class _ReplyModel implements AgentModel {
  _ReplyModel(this.requests);
  final List<ModelRequest> requests;

  @override
  Future<ModelResponse> complete(
    ModelRequest request,
    CancellationToken cancellation,
  ) async {
    requests.add(request);
    return ModelResponse(
      message: AssistantMessage(
        provider: 'test',
        model: 'test-model',
        content: [TextBlock(text: '收到')],
      ),
      stopReason: ModelStopReason.completed,
      usage: const TokenUsage(inputTokens: 10, outputTokens: 5),
    );
  }
}

class _MeasuredMemory extends MemoryService {
  _MeasuredMemory(super.repository);
  final queries = <Map<String, Object?>>[];
  final timings = <String, List<int>>{};

  @override
  Future<Map<String, Object?>> query({
    String? goalId,
    String? search,
    int offset = 0,
    int limit = 20,
    bool includeExpired = false,
    String? layer,
    String? certainty,
    int? candidateLimit,
  }) async {
    final watch = Stopwatch()..start();
    queries.add({
      'goalId': goalId,
      'search': search,
      'layer': layer,
      'limit': limit,
      'candidateLimit': candidateLimit,
    });
    final result = await super.query(
      goalId: goalId,
      search: search,
      offset: offset,
      limit: limit,
      includeExpired: includeExpired,
      layer: layer,
      certainty: certainty,
      candidateLimit: candidateLimit,
    );
    watch.stop();
    (timings[layer ?? certainty ?? 'topic'] ??= []).add(
      watch.elapsedMicroseconds,
    );
    return result;
  }
}

void main() {
  final now = DateTime.utc(2030, 1, 1);
  late AppDatabase db;
  late _MeasuredMemory memory;
  late MissionService missions;
  late GoalService goals;
  late MemoryContextAssembler assembler;

  setUp(() {
    db = AppDatabase(executor: NativeDatabase.memory());
    memory = _MeasuredMemory(DriftMemoryRepository(db, clock: () => now));
    missions = MissionService(DriftMissionRepository(db, clock: () => now));
    goals = GoalService(DriftGoalRepository(db));
    assembler = MemoryContextAssembler(memory: memory, missions: missions);
  });
  tearDown(() async {
    await missions.dispose();
    await goals.dispose();
    await db.close();
  });

  Future<void> save(
    String id, {
    String layer = 'semantic',
    String? goalId,
    String certainty = 'stated',
    String? content,
    String? topic,
    int importance = 50,
  }) async {
    await memory.save({
      'id': id,
      'content': content ?? '记忆$id',
      'topic': topic ?? id,
      'layer': layer,
      'certainty': certainty,
      'importance': importance,
      'goalId': goalId,
      'sourceKind': 'manual',
    }, userEdited: true);
  }

  Map<String, dynamic> verify(MemoryContextResult result) {
    expect(result.isEmpty, isFalse);
    expect(
      MemoryContextAssembler.estimateTokens(result.text),
      lessThanOrEqualTo(MemoryContextAssembler.tokenBudget),
    );
    final blocks = jsonDecode(result.text) as Map<String, dynamic>;
    final retained = <String>{};
    for (final block in blocks.entries) {
      if (block.key == 'goalBrief' || block.value is! List) continue;
      for (final entry in block.value as List) {
        expect(retained.add(entry['id'] as String), isTrue);
        final reason = result.injected.singleWhere(
          (injection) => injection['id'] == entry['id'],
        );
        expect(reason['block'], block.key);
        expect(reason['layer'], entry['layer']);
        expect(reason['certainty'], entry['certainty']);
      }
    }
    expect(result.injected.map((entry) => entry['id']).toSet(), retained);
    return blocks;
  }

  test('无话题和无关话题每轮均供给全局 semantic，命中优先且候选有界', () async {
    await save('identity', layer: 'identity', content: '我喜欢简洁回答');
    await save('semantic', content: '我不吃花生', topic: '饮食');
    for (final topic in [null, '完全无关的话题']) {
      final result = await assembler.assemble(topic: topic);
      final blocks = verify(result);
      expect(
        (blocks['stable'] as List).map((entry) => entry['id']),
        containsAll(['identity', 'semantic']),
      );
    }
    final matched = await assembler.assemble(topic: '饮食');
    verify(matched);
    expect(
      matched.injected.singleWhere((entry) => entry['id'] == 'semantic'),
      containsPair('reason', 'topic_match'),
    );
    expect(
      memory.queries,
      everyElement(containsPair('candidateLimit', isNotNull)),
    );
    expect(
      memory.queries.map((query) => query['limit'] as int),
      everyElement(lessThanOrEqualTo(MemoryContextAssembler.candidateLimit)),
    );
  });

  test('身份候选较多时全局 semantic 仍获得稳定预算', () async {
    for (var index = 0; index < 12; index++) {
      await save('identity-$index', layer: 'identity', content: '身份偏好$index');
    }
    await save('semantic', content: '不能吃花生');
    final result = await assembler.assemble();
    final blocks = verify(result);
    expect(
      (blocks['stable'] as List).map((entry) => entry['id']),
      contains('semantic'),
    );
  });

  test('所有块在无目标时只含全局，有目标时只含全局和当前目标', () async {
    final a = goals.prepareCreation(title: '目标a');
    final b = goals.prepareCreation(title: '目标b');
    await goals.create(a);
    await goals.create(b);
    for (final scope in [null, a.id, b.id]) {
      for (final layer in [
        'identity',
        'semantic',
        'episodic',
        'procedural',
        'observation',
      ]) {
        final id = '${scope ?? 'global'}-$layer';
        await save(
          id,
          layer: layer,
          goalId: scope,
          certainty: layer == 'observation' ? 'unverified' : 'stated',
          content: '线索$id',
        );
        // 直接写入真实派生数据，使本测试独立于另一成员的通用保存改动。
        if (layer == 'episodic') {
          await db.customStatement(
            'INSERT OR REPLACE INTO memory_episodes(item_id,source_refs_json) VALUES (?,?)',
            [id, '[]'],
          );
        }
        if (layer == 'procedural') {
          await db.customStatement(
            'INSERT OR REPLACE INTO memory_procedures(item_id,steps_json,source_refs_json) VALUES (?,?,?)',
            [id, '["检查"]', '[]'],
          );
        }
      }
    }
    for (final scope in [null, a.id]) {
      for (final topic in [null, '线索']) {
        final result = await assembler.assemble(goalId: scope, topic: topic);
        final blocks = verify(result);
        for (final block in blocks.values.whereType<List<dynamic>>()) {
          for (final entry in block) {
            expect(entry['goalId'], anyOf(isNull, scope));
            expect(entry['id'], isNot(startsWith('${b.id}-')));
          }
        }
        expect(
          result.injected.map((entry) => entry['block']),
          containsAll(
            topic == null
                ? ['episode', 'procedure', 'unverified']
                : ['topic', 'unverified'],
          ),
        );
      }
    }
    final topicQuery = memory.queries.lastWhere(
      (query) => query['search'] == '线索',
    );
    expect(topicQuery['goalId'], a.id);
  });

  test('最终 JSON 含长 brief 仍在预算内，超额 brief 标 omitted 并继续短条目', () async {
    final goal = goals.prepareCreation(title: '测试预算');
    await goals.create(goal);
    for (var index = 0; index < 9; index++) {
      await missions.create(
        title: index == 8 ? '短任务' : List.filled(250, '长标题😀').join(),
        scheduledDate: '2030-01-${index + 10}',
        timeZone: 'Asia/Shanghai',
        plannedDurationMinutes: 20,
        ownership: MissionOwnership(goalId: goal.id),
      );
    }
    for (var index = 0; index < 16; index++) {
      await save('s$index', content: List.filled(60, '中文😀').join());
      await save('g$index', goalId: goal.id, content: '目标事实$index');
      await save('o$index', layer: 'observation', certainty: 'unverified');
    }
    final blocks = verify(await assembler.assemble(goalId: goal.id));
    expect(blocks['omitted'], isTrue);
    expect((blocks['goalBrief'] as List).single['title'], '短任务');
    expect(
      MemoryContextAssembler.estimateTokens(jsonEncode(blocks['goalBrief'])),
      lessThanOrEqualTo(MemoryContextAssembler.goalBriefTokenBudget),
    );
  });

  test('单条过大不会丢弃后续候选，流程输出实际 steps 与 trigger', () async {
    await save(
      'a-too-large',
      importance: 100,
      content: List.filled(160, '😀').join(),
    );
    await save('b-fits', content: '短事实');
    await save('procedure', layer: 'procedural', content: '复盘流程');
    await db.customStatement(
      'INSERT OR REPLACE INTO memory_procedures(item_id,steps_json,trigger_context,source_refs_json) VALUES (?,?,?,?)',
      ['procedure', '["检查结果","记录原因"]', '结束后', '[]'],
    );
    final result = await assembler.assemble();
    final blocks = verify(result);
    expect(result.injected.map((entry) => entry['id']), contains('b-fits'));
    expect(
      result.injected.map((entry) => entry['id']),
      isNot(contains('a-too-large')),
    );
    expect(blocks['omitted'], isTrue);
    final procedure = (blocks['procedure'] as List).single;
    expect(procedure['steps'], ['检查结果', '记录原因']);
    expect(procedure['trigger'], '结束后');
    expect(
      result.injected.singleWhere(
        (entry) => entry['id'] == 'procedure',
      )['reason'],
      'procedure_steps',
    );
  });

  test('话题命中的流程携带派生步骤，不因提前去重只剩正文', () async {
    await save('topic-procedure', layer: 'procedural', content: '晚间复盘');
    await db.customStatement(
      'INSERT OR REPLACE INTO memory_procedures(item_id,steps_json,trigger_context,source_refs_json) VALUES (?,?,?,?)',
      ['topic-procedure', '["检查结果","记录原因"]', '结束后', '[]'],
    );
    final result = await assembler.assemble(topic: '晚间复盘');
    final blocks = verify(result);
    final procedure = (blocks['topic'] as List).single;
    expect(procedure['steps'], ['检查结果', '记录原因']);
    expect(procedure['trigger'], '结束后');
    expect(result.injected.single['reason'], 'topic_match');
  });

  test('多块填满时计入所有 JSON 键、数组与省略标记且 reasons 精确对应', () async {
    final goal = goals.prepareCreation(title: '多块预算');
    await goals.create(goal);
    for (var index = 0; index < 12; index++) {
      await save('stable-$index', content: '全局事实$index');
      await save('goal-$index', goalId: goal.id, content: '目标事实$index');
      await save('topic-$index', content: '共同线索$index');
      await save(
        'observation-$index',
        layer: 'observation',
        certainty: 'unverified',
      );
      await save('episode-$index', layer: 'episodic');
      await db.customStatement(
        'INSERT OR REPLACE INTO memory_episodes(item_id,source_refs_json) VALUES (?,?)',
        ['episode-$index', '[]'],
      );
      await save('procedure-$index', layer: 'procedural');
      await db.customStatement(
        'INSERT OR REPLACE INTO memory_procedures(item_id,steps_json,source_refs_json) VALUES (?,?,?)',
        ['procedure-$index', '["检查"]', '[]'],
      );
    }
    final result = await assembler.assemble(goalId: goal.id);
    final blocks = verify(result);
    expect(
      blocks.keys,
      containsAll(['stable', 'goal', 'episode', 'procedure', 'unverified']),
    );
    expect(blocks['omitted'], isTrue);
    expect(
      MemoryContextAssembler.estimateTokens(result.text),
      greaterThan(600),
    );
  });

  test('无话题 semantic 实际成为供给块，真实 runtime 压缩后仍送达下一轮', () async {
    await save('commute', content: '上班坐42路换7号线');
    final assembled = await assembler.assemble();
    verify(assembled);
    final requests = <ModelRequest>[];
    final summaries = <ModelRequest>[];
    ModelProfile profile(String id) => ModelProfile(
      id: id,
      provider: 'test',
      model: 'test-model',
      endpoint: Uri.parse('https://example.invalid/$id'),
      protocol: ModelProtocol.messages,
      credentialKey: 'TEST_API_KEY',
      contextWindowTokens: 24000,
      maxOutputTokens: 256,
      streamResponses: false,
    );
    final runtime = AgentRuntime(
      configuration: AgentConfiguration(
        profiles: [profile('main'), profile('summary')],
        defaultModelProfile: 'main',
        summaryModelProfile: 'summary',
        context: ContextPolicy(
          enabled: false,
          headroomTokens: 64,
          summaryMaxTokens: 128,
          keepRecentMessages: 1,
        ),
      ),
      store: MemorySessionStore(),
      credentials: (_) => null,
      tools: const [],
      authorize: (tool, call, token) => const ToolDecision.allow(),
      modelOverrides: {
        'main': _ReplyModel(requests),
        'summary': _ReplyModel(summaries),
      },
    );
    addTearDown(runtime.close);
    final session = await runtime.createSession();
    await session.replaceContext(
      source: 'mission_book_memory',
      text: assembled.text,
    );
    await session.send('背景资料${'背景' * 480}');
    await session.send('继续');
    final compaction = await session.compact();
    expect(compaction, isNotNull);
    final remembered = compaction!.contextMessages
        .whereType<ContextMessage>()
        .where((message) => message.source == 'mission_book_memory');
    expect(remembered, hasLength(1));
    expect(remembered.single.text, contains('上班坐42路换7号线'));
    expect(summaries, isNotEmpty);
    expect(summaries.last.messages.whereType<ContextMessage>(), isEmpty);
    await session.send('我如何通勤');
    expect(
      requests.last.messages
          .whereType<ContextMessage>()
          .where((message) => message.source == 'mission_book_memory')
          .single
          .text,
      contains('上班坐42路换7号线'),
    );
  });

  test('估算按既有权重处理中文与非 BMP，不以字符数充当 token', () {
    expect(MemoryContextAssembler.estimateTokens('abcdefghij'), 4);
    expect(MemoryContextAssembler.estimateTokens('中文中文中文中文中文'), 8);
    expect(MemoryContextAssembler.estimateTokens('😀😀'), 6);
  });

  test('5k 条真实 SQLite 有界装配 p95 < 5ms', () async {
    await db.transaction(() async {
      for (var index = 0; index < 5000; index++) {
        await db.customInsert(
          'INSERT INTO memory_items(id,layer,content,certainty,importance,created_at,updated_at,source_kind) '
          'VALUES (?, ?, ?, ?, ?, ?, ?, ?)',
          variables: [
            Variable.withString('bench-$index'),
            Variable.withString(index % 5 == 0 ? 'identity' : 'semantic'),
            Variable.withString('记忆$index'),
            const Variable<String>('stated'),
            const Variable<int>(50),
            Variable.withInt(now.millisecondsSinceEpoch),
            Variable.withInt(now.millisecondsSinceEpoch),
            const Variable<String>('manual'),
          ],
        );
      }
    });
    for (var index = 0; index < 20; index++) {
      verify(await assembler.assemble(topic: '记忆4999'));
    }
    final samples = <int>[];
    for (var index = 0; index < 100; index++) {
      final watch = Stopwatch()..start();
      final result = await assembler.assemble(topic: '记忆4999');
      watch.stop();
      samples.add(watch.elapsedMicroseconds);
      expect(
        result.injected.map((entry) => entry['id']),
        contains('bench-4999'),
      );
    }
    samples.sort();
    final p95 = samples[94] / 1000;
    // ignore: avoid_print
    print(
      '5k memory assembly p95: $p95 ms; query means (us): '
      '${memory.timings.map((key, values) => MapEntry(key, values.reduce((a, b) => a + b) ~/ values.length))}',
    );
    expect(p95, lessThan(5));
  }, skip: Platform.environment['MEMORY_BENCH'] != '1');
}

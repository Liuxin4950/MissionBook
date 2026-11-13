import 'dart:convert';
import 'dart:io';

import 'package:agent_core/agent_core.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mission_book/application/assistant/context_tools.dart';
import 'package:mission_book/application/goals/goal_service.dart';
import 'package:mission_book/application/memory/memory_context.dart';
import 'package:mission_book/application/memory/memory_service.dart';
import 'package:mission_book/application/missions/mission_service.dart';
import 'package:mission_book/domain/entities/mission_ownership.dart';
import 'package:mission_book/application/records/record_service.dart';
import 'package:mission_book/application/web/web_service.dart';
import 'package:mission_book/application/analysis/analysis_service.dart';
import 'package:mission_book/data/analysis/drift_analysis_store.dart';
import 'package:mission_book/domain/entities/analysis_scope.dart';
import 'package:mission_book/data/local/app_database.dart';
import 'package:mission_book/data/repositories/drift_goal_repository.dart';
import 'package:mission_book/data/repositories/drift_memory_repository.dart';
import 'package:mission_book/data/repositories/drift_mission_repository.dart';
import 'package:mission_book/data/repositories/drift_record_repository.dart';
import 'package:mission_book/data/web/web_settings_store.dart';

class _FailingMemory extends MemoryService {
  _FailingMemory(super.repository);

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
  }) async => throw StateError('记忆读取失败');
}

void main() {
  late AppDatabase db;
  late DateTime now;
  late DriftMemoryRepository repository;
  late MemoryService memory;
  late MissionService missions;
  late GoalService goals;

  setUp(() {
    now = DateTime.utc(2030, 1, 1, 8);
    db = AppDatabase(executor: NativeDatabase.memory());
    repository = DriftMemoryRepository(db, clock: () => now);
    memory = MemoryService(repository);
    missions = MissionService(DriftMissionRepository(db, clock: () => now));
    goals = GoalService(DriftGoalRepository(db));
  });

  tearDown(() async {
    await missions.dispose();
    await goals.dispose();
    await db.close();
  });

  Map<String, Object?> entry(
    String id,
    String content, {
    String layer = 'semantic',
    String certainty = 'stated',
    String topic = '主题',
    List<String> aliases = const [],
    String? goalId,
    int importance = 50,
    int? expiresAt,
    String sourceKind = 'user',
  }) => {
    'id': id,
    'content': content,
    'layer': layer,
    'certainty': certainty,
    'topic': topic,
    'aliases': aliases,
    'importance': importance,
    'goalId': goalId,
    'expiresAt': expiresAt,
    'sourceKind': sourceKind,
  };

  Future<List<Map<String, Object?>>> items() async => [
    for (final row in await db.select(db.memoryItems).get()) row.toJson(),
  ];

  Future<List<MemoryVersionRow>> versions() =>
      db.select(db.memoryVersions).get();

  test('四态写入保留原事实、记录版本并可幂等重试', () async {
    final created = await repository.saveMemory(
      entry('old', '我晚上学习效率更高', topic: '学习时段'),
      operationId: 'op-add',
    );
    expect(created['status'], 'created');
    expect(created['reason'], 'added');
    expect(created['topicId'], isNotNull);

    final duplicate = await repository.saveMemory(
      entry('same', '我晚上学习效率更高', topic: '学习时段'),
      operationId: 'op-same',
    );
    expect(duplicate, {
      'status': 'unchanged',
      'id': 'old',
      'reason': 'identical',
      'resultId': 'old',
    });

    final conflict = await repository.saveMemory(
      entry('new', '我早上学习效率更高', topic: '学习时段'),
      operationId: 'op-conflict',
    );
    expect(conflict['status'], 'created');
    expect(conflict['reason'], 'topic_conflict_kept');
    expect(conflict['keptId'], 'old');
    final rows = await items();
    final kept = rows.singleWhere((row) => row['id'] == 'old');
    final added = rows.singleWhere((row) => row['id'] == 'new');
    expect(kept['content'], '我晚上学习效率更高');
    expect(added['certainty'], 'unverified');
    expect(added['topic_id'], kept['topic_id']);

    final manual = await repository.saveMemory({
      ...entry('old', '我晚上学习效率更高', topic: '学习时段'),
      'certainty': 'stated',
    }, userEdited: true);
    expect(manual['status'], 'unchanged');

    final corrected = await repository.saveMemory({
      ...entry('old', '我夜里学习效率更高', topic: '学习时段'),
      'expectedVersion': null,
    }, userEdited: true);
    expect(corrected['status'], 'updated');
    expect(corrected['id'], 'old');
    expect(corrected['previousContent'], '我晚上学习效率更高');
    expect((await versions()).last.actor, 'user');

    final explicit = await repository.saveMemory(
      entry('old', '我夜里学习效率更高，更适合专注', topic: '学习时段'),
      userEdited: true,
      explicitCorrection: true,
    );
    expect(explicit['resultId'], 'old');
    expect((await versions()).last.actor, 'assistant');

    final history = await versions();
    expect(
      history.map((row) => row.changeKind),
      containsAll(['add', 'update']),
    );
    expect(
      history
          .where((row) => row.changeKind == 'update')
          .map((row) => row.beforeJson),
      anyElement(contains('我晚上学习效率更高')),
    );

    final retried = await repository.saveMemory(
      entry('old', '我晚上学习效率更高', topic: '学习时段'),
      operationId: 'op-add',
    );
    expect(retried, created);
    expect(await db.select(db.memoryItems).get(), hasLength(2));
    expect(await db.select(db.operationReceipts).get(), hasLength(3));
  });

  test('乐观锁不一致返回 blocked changed 且零写入', () async {
    await repository.saveMemory(entry('lock', '原始事实', topic: '锁'));
    final row = (await items()).single;
    final stale = {for (final field in row.keys) field: row[field]};
    await repository.saveMemory({
      ...entry('lock', '其他入口的新事实', topic: '锁'),
    }, userEdited: true);
    final versionsBefore = (await versions()).length;
    final blocked = await repository.saveMemory(
      {...entry('lock', '旧提案', topic: '锁'), 'expectedVersion': stale},
      userEdited: true,
      operationId: 'stale',
    );
    expect(blocked, {
      'status': 'blocked',
      'id': 'lock',
      'resultId': 'lock',
      'reason': 'changed',
    });
    expect((await items()).single['content'], '其他入口的新事实');
    expect((await versions()).length, versionsBefore);
  });

  test('凭据拦截覆盖正文、主题、别名与来源', () async {
    for (final value in [
      entry('c1', '我的密钥是 sk-abcdefghijklmnop'),
      entry('c2', '正常正文', topic: 'api_key: 1234567890abcdef'),
      entry('c3', '正常正文', aliases: ['token: 1234567890']),
      entry('c4', '正常正文', sourceKind: 'user')..['sourceRef'] = '密码: 1234567890',
    ]) {
      await expectLater(repository.saveMemory(value), throwsArgumentError);
    }
    expect(await db.select(db.memoryItems).get(), isEmpty);
  });

  test('墓碑阻止同范围同内容恢复，忘记写入版本', () async {
    await repository.saveMemory(entry('tomb', '已经忘记的事实', topic: '旧主题'));
    await repository.forgetMemory('tomb');
    final blocked = await repository.saveMemory(
      entry('again', '已经忘记的事实', topic: '旧主题'),
    );
    expect(blocked['status'], 'blocked');
    expect(blocked['id'], 'tomb');
    expect(blocked['reason'], 'protected_memory');
    final history = await versions();
    expect(history.map((row) => row.changeKind), contains('forget'));
    expect((await db.select(db.memoryItems).get()).single.forgotten, true);
  });

  test('时间衰减单位正确：365 天前的偏好让位于 1 天内的事实', () async {
    await repository.saveMemory(
      entry('old', '一年前的偏好', layer: 'identity', topic: '旧偏好'),
    );
    await repository.saveMemory(
      entry('fresh', '刚记录的事实', layer: 'semantic', topic: '新事实'),
    );
    await (db.update(db.memoryItems)..where((t) => t.id.equals('old'))).write(
      MemoryItemsCompanion(
        updatedAt: Value(
          now.subtract(const Duration(days: 365)).millisecondsSinceEpoch,
        ),
      ),
    );
    final rows = (await repository.queryMemory())['items'] as List;
    expect((rows.first as Map)['id'], 'fresh');
    expect((rows.last as Map)['id'], 'old');
  });

  test('空主题回退正文且不触发主题约束异常', () async {
    final result = await repository.saveMemory(
      entry('empty-topic', '正文就是有效主题', topic: '   '),
    );
    expect(result['status'], 'created');
    final topics = await db.select(db.memoryTopics).get();
    expect(topics.single.canonicalName, '正文就是有效主题');
    final second = await repository.saveMemory(
      entry('empty-topic-2', '另一条正文', topic: ''),
    );
    expect(second['status'], 'created');
  });

  test('记忆抽取批次跳过空主题候选但保留有效候选', () async {
    const work = AnalysisWork(AnalysisScope.memory, 'session:1', 1, false);
    await db
        .into(db.analysisJobs)
        .insert(
          AnalysisJobsCompanion.insert(
            scope: 'memory',
            targetId: 'session:1',
            sourceVersion: const Value(1),
            status: const Value('running'),
          ),
        );
    await db
        .into(db.assistantSessions)
        .insert(
          AssistantSessionsCompanion.insert(
            id: 'session',
            title: '测试',
            createdAt: now.millisecondsSinceEpoch,
            updatedAt: now.millisecondsSinceEpoch,
          ),
        );
    await db
        .into(db.assistantSessionRecords)
        .insert(
          AssistantSessionRecordsCompanion.insert(
            sessionId: 'session',
            sequence: 1,
            timestamp: now.millisecondsSinceEpoch,
            type: 'message_added',
            data: jsonEncode({
              'message': {
                'role': 'user',
                'content': [
                  {'type': 'text', 'text': '我习惯早上跑步'},
                ],
              },
            }),
          ),
        );

    await DriftAnalysisStore(db).saveMemoryCandidates(
      work,
      jsonEncode({
        'entries': [
          {
            'content': '空主题候选',
            'topic': ' ',
            'quote': '我习惯早上跑步',
            'certainty': 'stated',
            'layer': 'semantic',
          },
          {
            'content': '我习惯早上跑步',
            'topic': '运动习惯',
            'quote': '我习惯早上跑步',
            'certainty': 'stated',
            'layer': 'semantic',
          },
        ],
      }),
    );

    final rows = await db.select(db.memoryItems).get();
    expect(rows, hasLength(1));
    expect(rows.single.content, '我习惯早上跑步');
    expect(rows.single.sourceKind, 'extraction');
  });

  test('反思批次跳过畸形动作且不提升受保护记忆的 certainty', () async {
    await repository.saveMemory(
      entry('stated', '用户明确喜欢晨跑', topic: '运动', sourceKind: 'user'),
    );
    final result = await repository.applyReflection([
      {'action': 'adjust_item', 'id': 'missing', 'certainty': 'stated'},
      {'action': 'adjust_item', 'id': 'stated', 'certainty': 'inferred'},
      {'action': 'add_episode', 'content': '用户完成晨跑', 'topic': '运动'},
    ]);

    expect(result['applied'], hasLength(1));
    expect(result['skipped'], hasLength(2));
    final row = (await db.select(db.memoryItems).get()).singleWhere(
      (item) => item.id == 'stated',
    );
    expect(row.certainty, 'stated');
    expect(
      (await db.select(db.memoryItems).get()).any(
        (item) => item.layer == 'episodic',
      ),
      isTrue,
    );
  });

  test('仅主题别名命中时装配器仍自动注入', () async {
    await repository.saveMemory(
      entry('alias-only', '我习惯早上跑步', topic: '运动习惯', aliases: ['晨跑']),
    );
    final assembled = await MemoryContextAssembler(
      memory: memory,
    ).assemble(topic: '晨跑');
    expect(assembled.text, contains('我习惯早上跑步'));
    expect(
      assembled.injected,
      contains(
        predicate<Map<String, Object?>>(
          (item) => item['id'] == 'alias-only' && item['block'] == 'topic',
        ),
      ),
    );
  });

  test('主题别名让无共同字面的同义查询召回', () async {
    await repository.saveMemory(
      entry('run', '我习惯早上跑步', topic: '运动习惯', aliases: ['晨跑', '早上跑步']),
    );
    final exact =
        (await repository.queryMemory(search: '早上跑步'))['items'] as List;
    expect(exact, hasLength(1));
    final synonym =
        (await repository.queryMemory(search: '晨跑'))['items'] as List;
    expect((synonym.single as Map)['content'], '我习惯早上跑步');
    final topics = await db.select(db.memoryTopics).get();
    expect(topics, hasLength(1));
    final aliases = await db.select(db.memoryTopicAliases).get();
    expect(
      aliases.map((row) => row.normalizedAlias),
      containsAll(['晨跑', '早上跑步']),
    );
  });

  test('三态确认程度与观察层约束', () async {
    await repository.saveMemory(
      entry('inferred', '可能喜欢上午', certainty: 'inferred'),
    );
    await repository.saveMemory(
      entry(
        'observed',
        '用户可能更喜欢早晨',
        layer: 'observation',
        certainty: 'unverified',
        topic: '作息观察',
      ),
    );
    await expectLater(
      repository.saveMemory(
        entry('bad', '用户喜欢早晨', layer: 'observation', certainty: 'stated'),
      ),
      throwsArgumentError,
    );
    final rows = await items();
    expect(
      rows.map((row) => row['certainty']),
      containsAll(['inferred', 'unverified']),
    );
  });

  test('观察与带 id 的未验证改写必须拒绝且零写入', () async {
    final tools = contextTools(
      records: RecordService(
        DriftRecordRepository(db),
        missions,
        missions.attachments,
      ),
      missions: missions,
      memory: memory,
      analysis: DriftAnalysisStore(db),
      analyze: (p, {imageKey, mime, json = false}) async => '',
      web: WebService(
        settings: const SecureWebSettings(),
        quota: DriftSearchQuota(db),
        fetchClient: () => throw StateError('不出网'),
      ),
      userStatement: () => '我早上学习更专注，但还不确定',
    );
    final save = tools.firstWhere(
      (tool) => tool.definition.name == 'saveMemory',
    );
    Future<ToolOutput> call(Map<String, Object?> input, String callId) async =>
        save.execute(
          input,
          ToolContext(
            callId: callId,
            sessionId: 'session',
            cancellation: CancellationToken(),
          ),
        );

    await expectLater(
      call({'content': '用户可能更喜欢早晨', 'layer': 'observation'}, 'no-basis'),
      throwsA(
        isA<ToolRejected>().having(
          (e) => e.code,
          'code',
          'memory_basis_invalid',
        ),
      ),
    );
    final observed =
        jsonDecode(
              (await call({
                'content': '用户可能更喜欢早晨',
                'layer': 'observation',
                'basis': '我早上学习更专注',
              }, 'observe')).text,
            )
            as Map;
    expect(observed['status'], 'created');
    final item = (await items()).single;
    expect(item['layer'], 'observation');
    expect(item['certainty'], 'unverified');

    await expectLater(
      call({
        'id': item['id'] as String,
        'content': '用户每天早上学习',
        'layer': 'semantic',
        'certainty': 'unverified',
      }, 'rewrite-unverified'),
      throwsA(isA<ToolRejected>()),
    );
    expect((await items()).single['content'], '用户可能更喜欢早晨');
    expect(await versions(), hasLength(1));
  });

  test('装配器输出稳定、目标、话题与观察块，并给出注入原因', () async {
    final goal = goals.prepareCreation(title: '三个月通过考试');
    await goals.create(goal);
    await missions.create(
      title: '完成第一轮复习',
      scheduledDate: '2030-01-02',
      timeZone: 'Asia/Shanghai',
      plannedDurationMinutes: 30,
      ownership: MissionOwnership(goalId: goal.id),
    );
    await repository.saveMemory(
      entry('stable', '每天上午学习', layer: 'identity', topic: '学习时间'),
    );
    await repository.saveMemory(
      entry('unrelated-stable', '我喜欢简洁回答', layer: 'identity', topic: '表达偏好'),
    );
    await repository.saveMemory(
      entry('goal', '这个目标是为了三个月后通过考试', topic: '目标动机', goalId: goal.id),
    );
    await repository.saveMemory(
      entry('topic', '上午学习需要安静环境', layer: 'procedural', topic: '学习环境'),
    );
    await repository.saveMemory(
      entry(
        'observed',
        '用户可能更喜欢早晨',
        layer: 'observation',
        certainty: 'unverified',
        topic: '作息观察',
      ),
    );
    final assembler = MemoryContextAssembler(
      memory: memory,
      missions: missions,
    );
    final result = await assembler.assemble(goalId: goal.id, topic: '上午学习');
    expect(result.isEmpty, false);
    final blocks = jsonDecode(result.text) as Map<String, Object?>;
    List<String> contents(String key) => [
      for (final item in blocks[key] as List? ?? const [])
        (item as Map)['content'] as String,
    ];
    expect([...contents('stable'), ...contents('topic')], contains('每天上午学习'));
    expect(contents('goal'), contains('这个目标是为了三个月后通过考试'));
    expect(contents('topic'), contains('上午学习需要安静环境'));
    expect(contents('unverified'), contains('用户可能更喜欢早晨'));
    for (final key in ['stable', 'goal', 'topic']) {
      expect(contents(key), isNot(contains('用户可能更喜欢早晨')));
    }
    expect(
      (blocks['goalBrief'] as List).single,
      containsPair('title', '完成第一轮复习'),
    );
    expect(
      result.injected.map((item) => item['reason']),
      containsAll([
        'stable_core',
        'goal_scope',
        'topic_match',
        'unverified_observation',
      ]),
    );
  });

  test('登记别名后装配器自动注入命中', () async {
    await repository.saveMemory({
      ...entry(
        'run',
        '我习惯早上跑步',
        layer: 'procedural',
        topic: '运动习惯',
        aliases: ['晨跑'],
      ),
    });
    final assembler = MemoryContextAssembler(memory: memory);
    final result = await assembler.assemble(topic: '晨跑');
    final blocks = jsonDecode(result.text) as Map<String, Object?>;
    expect(blocks.containsKey('stable'), false);
    final topic = (blocks['topic'] as List).single as Map;
    expect(topic['content'], '我习惯早上跑步');
    expect(topic['topic'], '运动习惯');
    expect(result.injected.single['reason'], 'topic_match');
  });

  test('装配器按 token 预算截断，读取失败降级为空块', () async {
    for (var index = 0; index < 40; index++) {
      await repository.saveMemory(
        entry(
          'long$index',
          '${List.filled(200, '有').join()}$index',
          layer: 'identity',
          topic: '长主题$index',
        ),
      );
    }
    final assembler = MemoryContextAssembler(memory: memory);
    final result = await assembler.assemble();
    final blocks = jsonDecode(result.text) as Map<String, Object?>;
    final stable = blocks['stable'] as List;
    expect(stable, isNotEmpty);
    expect(stable.length, lessThan(40));
    expect(blocks['omitted'], true);
    for (final item in stable) {
      expect(((item as Map)['content'] as String).endsWith('…'), true);
    }

    final failing = MemoryContextAssembler(memory: _FailingMemory(repository));
    final empty = await failing.assemble();
    expect(empty.isEmpty, true);
    expect(empty.injected, isEmpty);
    expect(empty.warning, MemoryContextAssembler.readWarning);
  });

  test('固定清单清理按需分页并逐条写版本', () async {
    await db
        .into(db.assistantSessions)
        .insert(
          AssistantSessionsCompanion.insert(
            id: 'session-a',
            title: '测试',
            createdAt: now.millisecondsSinceEpoch,
            updatedAt: now.millisecondsSinceEpoch,
          ),
        );
    await db
        .into(db.assistantSessionRecords)
        .insert(
          AssistantSessionRecordsCompanion.insert(
            sessionId: 'session-a',
            sequence: 0,
            timestamp: now.millisecondsSinceEpoch,
            type: 'message_added',
            data: jsonEncode({
              'message': {
                'id': 'user-a',
                'role': 'user',
                'content': [
                  {'type': 'text', 'text': '删除第1条'},
                ],
              },
            }),
          ),
        );
    for (var index = 1; index <= 5; index++) {
      await repository.saveMemory(
        entry('memory-$index', '偏好$index', topic: 'key-$index'),
      );
    }
    final selection = await repository.selectMemory(
      sessionId: 'session-a',
      selectionId: 'selection-a',
    );
    final selected = (selection['items'] as List).cast<Map<String, Object?>>();
    expect(selected.map((item) => item['itemId']), ['1', '2', '3', '4', '5']);
    final first = selected.first;
    expect(first['layer'], 'semantic');
    expect(first['topic'], 'key-1');
    final result = await repository.forgetSelection(
      sessionId: 'session-a',
      sourceMessageId: 'user-a',
      selectionId: 'selection-a',
      itemIds: ['1'],
      operationId: 'forget-one',
    );
    expect(result['status'], 'success');
    expect(
      (await versions()).where((row) => row.changeKind == 'forget'),
      hasLength(1),
    );
  });

  test('选择清单按实际变化统计 changed', () async {
    await repository.saveMemory(entry('a', '第一条', topic: '主题A'));
    await repository.saveMemory(entry('b', '第二条', topic: '主题B'));
    await repository.selectMemory(
      sessionId: 'session',
      selectionId: 'selection',
    );
    await repository.saveMemory({
      ...entry('a', '第一条已更正', topic: '主题A'),
    }, userEdited: true);
    final preview = await repository.previewForget(
      sessionId: 'session',
      selectionId: 'selection',
      itemIds: ['1', '2'],
    );
    expect(preview['status'], 'blocked');
    expect((preview['counts'] as Map)['changed'], 1);
    expect((preview['issues'] as List).single['code'], 'changed');
    final clean = await repository.previewForget(
      sessionId: 'session',
      selectionId: 'selection',
      itemIds: ['2'],
    );
    expect(clean['status'], 'ready');
    expect((clean['counts'] as Map)['changed'], 0);
  });

  test('当前版本重开保留记忆行与版本历史', () async {
    final directory = await Directory.systemTemp.createTemp(
      'missionbook-memory-reopen-',
    );
    final file = File('${directory.path}/test.sqlite');
    var database = AppDatabase(executor: NativeDatabase(file));
    try {
      final repo = DriftMemoryRepository(database, clock: () => now);
      await repo.saveMemory(entry('reopen', '重开后仍然存在', topic: '重开主题'));
      await repo.saveMemory({
        ...entry('reopen', '重开后的更正', topic: '重开主题'),
      }, userEdited: true);
      await database.close();

      database = AppDatabase(executor: NativeDatabase(file));
      final rows = await database.select(database.memoryItems).get();
      expect(rows.single.content, '重开后的更正');
      expect(rows.single.topicId, isNotNull);
      final versions = await database.select(database.memoryVersions).get();
      expect(versions.map((row) => row.changeKind), ['add', 'update']);
      expect(versions.last.beforeJson, contains('重开后仍然存在'));
      expect(
        (await database.customSelect('PRAGMA user_version').getSingle())
            .read<int>('user_version'),
        database.schemaVersion,
      );
    } finally {
      await database.close();
      await directory.delete(recursive: true);
    }
  });

  test('长正文索引截断且可按需读取完整内容', () async {
    final content = List.filled(300, '测').join();
    await repository.saveMemory(entry('long', content, topic: '长正文'));
    final index = await repository.selectMemory(
      sessionId: 'session',
      selectionId: 'index',
    );
    final item = (index['items'] as List).single as Map;
    expect(item['contentTruncated'], true);
    expect((item['content'] as String).runes.length, 200);
    expect(item['contentLength'], 300);
    final detail = await repository.selectMemory(
      sessionId: 'session',
      selectionId: 'detail',
      search: 'long',
      limit: 1,
      fullContent: true,
    );
    expect(((detail['items'] as List).single as Map)['content'], content);
  });
}

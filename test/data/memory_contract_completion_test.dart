import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mission_book/application/memory/memory_context.dart';
import 'package:mission_book/application/memory/memory_service.dart';
import 'package:mission_book/data/local/app_database.dart';
import 'package:mission_book/data/repositories/drift_memory_repository.dart';

// 记录真实 SQL 返回量，防止候选截断被挪到全表装载之后。
class _MeasuredRepository extends DriftMemoryRepository {
  _MeasuredRepository(super.db, {super.clock});

  final candidateRows = <int>[];

  @override
  Future<List<Map<String, Object?>>> rows(
    String sql, [
    List<Object?> args = const [],
  ]) async {
    final result = await super.rows(sql, args);
    if (sql.startsWith('SELECT ranked.*')) candidateRows.add(result.length);
    return result;
  }
}

void main() {
  late AppDatabase db;
  late DateTime now;
  late _MeasuredRepository repository;

  setUp(() {
    now = DateTime.utc(2030, 1, 1, 8);
    db = AppDatabase(executor: NativeDatabase.memory());
    repository = _MeasuredRepository(db, clock: () => now);
  });

  tearDown(() => db.close());

  Map<String, Object?> entry(
    String id, {
    String? content,
    String layer = 'semantic',
    String certainty = 'stated',
    String? topic,
    String? goalId,
    List<String> aliases = const [],
  }) => {
    'id': id,
    'content': content ?? '事实 $id',
    'layer': layer,
    'certainty': certainty,
    'topic': topic ?? '主题 $id',
    'goalId': goalId,
    'aliases': aliases,
    'sourceKind': 'assistant',
  };

  Future<Map<String, Object?>> item(String id) async => (await repository.rows(
    'SELECT * FROM memory_items WHERE id=?',
    [id],
  )).single;

  Future<List<String>> ranked({
    String? search,
    int? candidateLimit,
    String? goalId,
    bool includeExpired = false,
  }) async =>
      ((await repository.queryMemory(
                search: search,
                goalId: goalId,
                limit: 300,
                candidateLimit: candidateLimit,
                includeExpired: includeExpired,
                includeSourceText: false,
              ))['items']
              as List)
          .map((row) => (row as Map)['id'] as String)
          .toList();

  Future<void> goal(String id) => db
      .into(db.goals)
      .insert(
        GoalsCompanion.insert(id: id, title: id, createdAt: 1, updatedAt: 1),
      );

  Future<void> createSession() async {
    await db
        .into(db.assistantSessions)
        .insert(
          AssistantSessionsCompanion.insert(
            id: 'session',
            title: '测试会话',
            createdAt: 1,
            updatedAt: 1,
          ),
        );
    await db
        .into(db.assistantSessionRecords)
        .insert(
          AssistantSessionRecordsCompanion.insert(
            sessionId: 'session',
            sequence: 0,
            timestamp: 1,
            type: 'message_added',
            data: jsonEncode({
              'message': {
                'id': 'user-message',
                'role': 'user',
                'content': [
                  {'type': 'text', 'text': '忘记选中的记忆'},
                ],
              },
            }),
          ),
        );
  }

  test('AI 更正新增/更新不冒充人工编辑，已有人工保护与 actor 保留', () async {
    final added = await repository.saveMemory(
      entry('ai'),
      explicitCorrection: true,
      userEdited: true,
      operationId: 'ai-add',
    );
    expect(added['resultId'], 'ai');
    expect((await item('ai'))['user_edited'], 0);
    await repository.saveMemory(
      entry('ai', content: '更正后的事实'),
      explicitCorrection: true,
    );
    expect((await item('ai'))['user_edited'], 0);
    final aiVersions = await repository.rows(
      'SELECT actor,reason FROM memory_versions WHERE item_id=?',
      ['ai'],
    );
    expect(aiVersions.map((row) => row['actor']), everyElement('assistant'));
    expect(
      aiVersions.map((row) => row['reason']),
      everyElement('explicit_correction'),
    );

    await repository.saveMemory(entry('manual'), userEdited: true);
    await repository.saveMemory(
      entry('manual', content: '助手更正人工条目'),
      explicitCorrection: true,
    );
    expect((await item('manual'))['user_edited'], 1);
    final manualVersions = await repository.rows(
      'SELECT actor FROM memory_versions WHERE item_id=? ORDER BY rowid',
      ['manual'],
    );
    expect(manualVersions.map((row) => row['actor']), ['user', 'assistant']);
    await repository.saveMemory(
      entry('ai', content: '用户实际编辑'),
      userEdited: true,
    );
    expect((await item('ai'))['user_edited'], 1);
  });

  test('usage 次数及注入双权重改变同条件排名，旧高价值候选不被新条目截掉', () async {
    for (final id in ['old', 'recall', 'inject', 'unused']) {
      await repository.saveMemory(entry(id));
    }
    await db.customStatement(
      'UPDATE memory_items SET updated_at=? WHERE id=?',
      [now.subtract(const Duration(days: 365)).millisecondsSinceEpoch, 'old'],
    );
    await repository.recordUsage(ids: ['recall'], injected: false);
    await repository.recordUsage(ids: ['inject'], injected: true);
    expect(await ranked(), ['inject', 'recall', 'unused', 'old']);
    await db.customStatement(
      'INSERT INTO memory_usage(item_id,recall_count,inject_count) VALUES(?,?,?)',
      ['old', 4095, 0],
    );
    expect((await ranked()).first, 'old');
    expect(await ranked(candidateLimit: 1), ['old']);
    expect(repository.candidateRows.last, 2); // 前一名加一条排名边界。
  });

  test('candidateLimit 前完整评分覆盖相关度、别名、目标、期限及稳定平局', () async {
    await goal('goal');
    await goal('other');
    await repository.saveMemory(entry('exact', content: 'alpha beta'));
    await repository.saveMemory(entry('partial', content: 'alpha only'));
    await repository.saveMemory(
      entry('alias', content: '其他正文', aliases: ['ALPHA BETA']),
    );
    await repository.saveMemory(entry('topic', topic: 'ALPHA BETA'));
    await repository.saveMemory(
      entry('scoped', content: 'alpha beta', goalId: 'goal'),
    );
    await repository.saveMemory(
      entry('excluded', content: 'alpha beta', goalId: 'other'),
    );
    await repository.saveMemory(entry('id-only', content: '无关正文'));
    for (final id in ['old', 'future', 'expired', 'manual', 'tie-a', 'tie-b']) {
      await repository.saveMemory(
        entry(id, content: 'alpha beta $id'),
        userEdited: id == 'manual',
      );
    }
    await db.customStatement(
      'UPDATE memory_items SET updated_at=? WHERE id=?',
      [now.subtract(const Duration(days: 100)).millisecondsSinceEpoch, 'old'],
    );
    await db.customStatement(
      'UPDATE memory_items SET updated_at=? WHERE id=?',
      [now.add(const Duration(days: 100)).millisecondsSinceEpoch, 'future'],
    );
    await db.customStatement(
      'UPDATE memory_items SET expires_at=? WHERE id=?',
      [now.millisecondsSinceEpoch, 'expired'],
    );
    for (final search in <String?>[
      null,
      'alpha beta',
      'ALPHA BETA',
      'id-only',
      'alpha %',
    ]) {
      final all = await ranked(
        search: search,
        goalId: 'goal',
        includeExpired: true,
      );
      for (var count = 1; count <= all.length; count++) {
        expect(
          await ranked(
            search: search,
            goalId: 'goal',
            includeExpired: true,
            candidateLimit: count,
          ),
          all.take(count).toList(),
          reason: '$search / $count',
        );
      }
    }
    final all = await ranked(
      search: 'alpha beta',
      goalId: 'goal',
      includeExpired: true,
    );
    expect(all, isNot(contains('excluded')));
    expect(all.indexOf('exact'), lessThan(all.indexOf('partial')));
    expect(all.indexOf('alias'), lessThan(all.indexOf('partial')));
    expect(all.indexOf('tie-a'), lessThan(all.indexOf('tie-b')));
    expect(await ranked(candidateLimit: 300), isNot(contains('expired')));
  });

  test('手工和自动保存均同步派生表，改层清理旧行，省略字段保留步骤与来源', () async {
    await repository.saveMemory({
      ...entry('procedure', layer: 'procedural'),
      'steps': ['先核对', '再执行'],
      'trigger': '开始前',
      'sourceRefs': ['record:1'],
    }, userEdited: true);
    var procedures = await repository.memoryProcedures();
    expect(procedures, hasLength(1));
    expect(jsonDecode(procedures.single['steps_json'] as String), [
      '先核对',
      '再执行',
    ]);
    expect(procedures.single['trigger_context'], '开始前');
    await repository.saveMemory(
      entry('procedure', layer: 'procedural', content: '更新标题'),
      userEdited: true,
    );
    procedures = await repository.memoryProcedures();
    expect(jsonDecode(procedures.single['source_refs_json'] as String), [
      'record:1',
    ]);
    expect(jsonDecode(procedures.single['steps_json'] as String), [
      '先核对',
      '再执行',
    ]);

    await repository.saveMemory({
      ...entry('procedure', layer: 'episodic', content: '变为情节'),
      'sourceRef': 'conversation:s:1|record:2',
    }, userEdited: true);
    expect(await repository.memoryProcedures(), isEmpty);
    expect(await db.select(db.memoryProcedures).get(), isEmpty);
    expect(
      jsonDecode(
        (await repository.memoryEpisodes()).single['source_refs_json']
            as String,
      ),
      ['conversation:s:1', 'record:2'],
    );
    await repository.saveMemory(
      entry('procedure', content: '变为事实'),
      userEdited: true,
    );
    expect(await db.select(db.memoryEpisodes).get(), isEmpty);
    await repository.saveMemory(entry('automatic', layer: 'episodic'));
    expect((await repository.memoryEpisodes()).single['id'], 'automatic');
    await repository.saveMemory(
      entry('manual-empty', layer: 'procedural'),
      userEdited: true,
    );
    expect(
      jsonDecode(
        (await repository.memoryProcedures()).single['steps_json'] as String,
      ),
      <Object?>[],
    );
  });

  test('同正文旧条目缺失派生行时保存修复，blocked 条目不能篡改派生数据', () async {
    final value = entry('legacy', layer: 'procedural');
    await repository.saveMemory(value, userEdited: true);
    await db.delete(db.memoryProcedures).go();
    expect(
      (await repository.saveMemory(value, userEdited: true))['status'],
      'unchanged',
    );
    expect(await repository.memoryProcedures(), hasLength(1));
    final blocked = await repository.saveMemory({
      ...value,
      'steps': ['不允许的覆盖'],
    });
    expect(blocked['status'], 'blocked');
    expect(
      jsonDecode(
        (await repository.memoryProcedures()).single['steps_json'] as String,
      ),
      <Object?>[],
    );
  });

  test('reflection 结构错误在写入前拒绝，不留下主行、主题、版本或派生行', () async {
    var index = 0;
    for (final malformed in <Map<String, Object?>>[
      {
        'steps': ['正确', 2],
      },
      {
        'source_refs': ['正确', false],
      },
      {
        'trigger': {'bad': true},
      },
      {
        'aliases': ['正确', 2],
      },
    ]) {
      final result = await repository.applyReflection([
        {
          'action': 'add_procedure',
          'id': 'invalid',
          'content': '坏动作',
          'topic': '不应留下的主题',
          ...malformed,
        },
        {
          'action': 'add_episode',
          'id': 'good-${index++}',
          'content': '安全动作 $index',
          'topic': '安全主题 $index',
        },
      ]);
      expect(result['skipped'], hasLength(1));
      expect(
        await repository.rows('SELECT id FROM memory_items WHERE id=?', [
          'invalid',
        ]),
        isEmpty,
      );
      expect(
        await repository.rows(
          'SELECT id FROM memory_topics WHERE canonical_name=?',
          ['不应留下的主题'],
        ),
        isEmpty,
      );
      expect(
        await repository.rows(
          'SELECT id FROM memory_versions WHERE item_id=?',
          ['invalid'],
        ),
        isEmpty,
      );
      expect(
        await repository.rows(
          'SELECT item_id FROM memory_procedures WHERE item_id=?',
          ['invalid'],
        ),
        isEmpty,
      );
    }
    expect(
      (await repository.memoryEpisodes()).map((row) => row['id']).toSet(),
      {'good-0', 'good-1', 'good-2', 'good-3'},
    );
  });

  test('reflection 每动作 savepoint 回滚派生落库失败，保留同批前后成功动作', () async {
    await db.customStatement('''
      CREATE TEMP TRIGGER reject_derived BEFORE INSERT ON memory_procedures
      WHEN NEW.item_id='failed'
      BEGIN SELECT RAISE(ABORT, 'forced derived failure'); END
    ''');
    final result = await repository.applyReflection([
      {'action': 'add_episode', 'id': 'before', 'content': '前动作'},
      {
        'action': 'add_procedure',
        'id': 'failed',
        'content': '失败动作',
        'steps': ['有效步骤'],
        'source_refs': ['record:1'],
      },
      {
        'action': 'add_procedure',
        'id': 'after',
        'content': '后动作',
        'steps': ['执行'],
      },
    ], operationId: 'reflection-batch');
    expect(result['applied'], hasLength(2));
    expect(result['skipped'], [
      {'action': 'add_procedure', 'reason': 'constraint_failed'},
    ]);
    expect(
      await repository.rows('SELECT id FROM memory_items WHERE id=?', [
        'failed',
      ]),
      isEmpty,
    );
    expect(
      await repository.rows(
        'SELECT id FROM memory_topics WHERE canonical_name=?',
        ['失败动作'],
      ),
      isEmpty,
    );
    expect(
      await repository.rows('SELECT id FROM memory_versions WHERE item_id=?', [
        'failed',
      ]),
      isEmpty,
    );
    expect((await repository.memoryEpisodes()).single['id'], 'before');
    final procedure = (await repository.memoryProcedures()).single;
    expect(procedure['id'], 'after');
    expect(jsonDecode(procedure['steps_json'] as String), ['执行']);
  });

  test('reflection 拒绝不同目标与全局/目标间主题合并', () async {
    await goal('g1');
    await goal('g2');
    final values = <String, Map<String, Object?>>{};
    for (final id in ['global', 'g1', 'g2']) {
      values[id] = await repository.saveMemory(
        entry(id, goalId: id == 'global' ? null : id),
      );
    }
    final before = await repository.rows(
      'SELECT * FROM memory_topics ORDER BY id',
    );
    final result = await repository.applyReflection([
      for (final target in ['global', 'g2'])
        {
          'action': 'merge_topics',
          'from_topic_id': values['g1']!['topicId'],
          'into_topic_id': values[target]!['topicId'],
        },
    ]);
    expect(result['applied'], isEmpty);
    expect(result['skipped'], hasLength(2));
    expect(
      await repository.rows('SELECT * FROM memory_topics ORDER BY id'),
      before,
    );
    expect(await db.select(db.memoryVersions).get(), hasLength(3));
  });

  test('同目标合并只移动活跃条目，forgotten/expired 原行与版本不变', () async {
    await goal('g1');
    final source = await repository.saveMemory(
      entry('live', topic: '来源', goalId: 'g1'),
    );
    for (final id in ['forgotten', 'expired']) {
      await repository.saveMemory(
        entry(id, topic: '来源', goalId: 'g1'),
        userEdited: true,
      );
    }
    await repository.forgetMemory('forgotten');
    await db.customStatement(
      'UPDATE memory_items SET expires_at=? WHERE id=?',
      [now.millisecondsSinceEpoch, 'expired'],
    );
    final forgotten = await item('forgotten');
    final expired = await item('expired');
    final target = await repository.saveMemory(
      entry('target', topic: '目标', goalId: 'g1'),
    );
    final historyBefore = await repository.rows(
      "SELECT * FROM memory_versions WHERE item_id IN ('forgotten','expired') ORDER BY id",
    );
    final result = await repository.applyReflection([
      {
        'action': 'merge_topics',
        'from_topic_id': source['topicId'],
        'into_topic_id': target['topicId'],
      },
    ]);
    expect((result['applied'] as List).single, containsPair('moved', 1));
    expect((await item('live'))['topic_id'], target['topicId']);
    expect(await item('forgotten'), forgotten);
    expect(await item('expired'), expired);
    expect(
      await repository.rows(
        "SELECT * FROM memory_versions WHERE item_id IN ('forgotten','expired') ORDER BY id",
      ),
      historyBefore,
    );
    expect(
      await repository.rows('SELECT id FROM memory_topics WHERE id=?', [
        source['topicId'],
      ]),
      hasLength(1),
    );
  });

  test('无历史引用的同范围合并迁移别名并删除来源主题', () async {
    final from = await repository.saveMemory(entry('from', aliases: ['来源别名']));
    final into = await repository.saveMemory(entry('into'));
    await repository.applyReflection([
      {
        'action': 'merge_topics',
        'from_topic_id': from['topicId'],
        'into_topic_id': into['topicId'],
      },
    ]);
    expect(
      await repository.rows('SELECT id FROM memory_topics WHERE id=?', [
        from['topicId'],
      ]),
      isEmpty,
    );
    expect((await item('from'))['topic_id'], into['topicId']);
    expect(await ranked(search: '来源别名'), containsAll(['from', 'into']));
  });

  test('reflectionInput 与派生读取过滤 forgotten/expired，并拒绝重新使用失效来源', () async {
    for (final layer in ['episodic', 'procedural']) {
      for (final state in ['live', 'forgotten', 'expired']) {
        final id = '$layer-$state';
        await repository.saveMemory(entry(id, layer: layer));
        if (state == 'forgotten') await repository.forgetMemory(id);
        if (state == 'expired') {
          await db.customStatement(
            'UPDATE memory_items SET expires_at=? WHERE id=?',
            [now.millisecondsSinceEpoch, id],
          );
        }
      }
    }
    final input = await repository.reflectionInput();
    expect((input['items'] as List).map((row) => (row as Map)['id']).toSet(), {
      'episodic-live',
      'procedural-live',
    });
    expect((input['episodes'] as List).map((row) => (row as Map)['item_id']), [
      'episodic-live',
    ]);
    expect(
      (input['procedures'] as List).map((row) => (row as Map)['item_id']),
      ['procedural-live'],
    );
    expect((await repository.memoryEpisodes()).map((row) => row['id']), [
      'episodic-live',
    ]);
    expect((await repository.memoryProcedures()).map((row) => row['id']), [
      'procedural-live',
    ]);
    final result = await repository.applyReflection([
      {
        'action': 'add_episode',
        'id': 'reuse-forgotten',
        'content': '不能复活',
        'source_refs': ['episodic-forgotten'],
      },
      {
        'action': 'add_procedure',
        'id': 'reuse-expired',
        'content': '不能再用',
        'source_refs': ['procedural-expired'],
        'steps': ['执行'],
      },
    ]);
    expect(result['applied'], isEmpty);
    expect(result['skipped'], hasLength(2));
  });

  test('observation 不能升为 inferred，人工/已陈述/到期条目不被 reflection 修改', () async {
    await repository.saveMemory(
      entry('observation', layer: 'observation', certainty: 'unverified'),
    );
    await repository.saveMemory(
      entry('manual', certainty: 'inferred'),
      userEdited: true,
    );
    await repository.saveMemory(entry('stated'));
    await repository.saveMemory(entry('expired', certainty: 'inferred'));
    await db.customStatement(
      'UPDATE memory_items SET expires_at=? WHERE id=?',
      [now.millisecondsSinceEpoch, 'expired'],
    );
    final before = await repository.rows(
      'SELECT * FROM memory_items ORDER BY id',
    );
    final result = await repository.applyReflection([
      for (final id in ['observation', 'manual', 'stated', 'expired'])
        {
          'action': 'adjust_item',
          'id': id,
          'certainty': 'inferred',
          'importance': 90,
        },
    ]);
    expect(result['applied'], isEmpty);
    expect(
      await repository.rows('SELECT * FROM memory_items ORDER BY id'),
      before,
    );
    expect(await db.select(db.memoryVersions).get(), hasLength(4));
    final allowed = await repository.applyReflection([
      {'action': 'adjust_item', 'id': 'observation', 'importance': 60},
    ]);
    expect(allowed['applied'], hasLength(1));
    expect((await item('observation'))['certainty'], 'unverified');
    expect((await item('observation'))['importance'], 60);
  });

  test('save resultId 指向实际条目；整批 forget resultId 指向可重读与分页的回执', () async {
    await createSession();
    final saved = await repository.saveMemory(
      entry('one'),
      operationId: 'save-op',
    );
    expect(saved['resultId'], 'one');
    expect(
      await repository.saveMemory(entry('one'), operationId: 'save-op'),
      saved,
    );
    final duplicate = await repository.saveMemory(
      entry('duplicate', content: '事实 one', topic: '主题 one'),
    );
    expect(duplicate['resultId'], 'one');
    for (var index = 0; index < 21; index++) {
      await repository.saveMemory(entry('batch-$index'));
    }
    final selection = await repository.selectMemory(
      sessionId: 'session',
      selectionId: 'selection',
      limit: 30,
    );
    final ids = (selection['items'] as List)
        .map((row) => (row as Map)['itemId'] as String)
        .toList();
    Future<Map<String, Object?>> forget() => repository.forgetSelection(
      sessionId: 'session',
      sourceMessageId: 'user-message',
      selectionId: 'selection',
      itemIds: ids,
      operationId: 'forget-batch',
    );
    final result = await forget();
    expect(result['resultId'], 'forget-batch');
    expect(result['operationId'], 'forget-batch');
    expect(result['counts'], {'requested': 22, 'changed': 22});
    expect(result['items'], hasLength(20));
    expect(await forget(), result);
    final second = await repository.memoryOperation(
      sessionId: 'session',
      operationId: result['resultId'] as String,
      offset: 20,
    );
    expect(second['resultId'], 'forget-batch');
    expect(second['items'], hasLength(2));
    expect(second['page'], {'offset': 20, 'complete': true});
  });

  test('blocked bulk forget 仍返回整批回执编号且不更改其他选中条目', () async {
    await createSession();
    await repository.saveMemory(entry('changed'));
    await repository.saveMemory(entry('untouched'));
    final selection = await repository.selectMemory(
      sessionId: 'session',
      selectionId: 'stale',
    );
    await repository.saveMemory(
      entry('changed', content: '用户更新'),
      userEdited: true,
    );
    final result = await repository.forgetSelection(
      sessionId: 'session',
      sourceMessageId: 'user-message',
      selectionId: 'stale',
      itemIds: (selection['items'] as List)
          .map((row) => (row as Map)['itemId'] as String)
          .toList(),
      operationId: 'blocked-batch',
    );
    expect(result['status'], 'blocked');
    expect(result['resultId'], 'blocked-batch');
    expect((await item('untouched'))['forgotten'], 0);
    expect(
      await repository.memoryOperation(
        sessionId: 'session',
        operationId: 'blocked-batch',
      ),
      result,
    );
  });

  test('候选缓存对 usage/人工改动失效，返回值隔离且回滚后不保留脏快照', () async {
    await repository.saveMemory(entry('a'));
    await repository.saveMemory(entry('b'));
    expect(await ranked(candidateLimit: 1), ['a']);
    final reads = repository.candidateRows.length;
    final page = await repository.queryMemory(candidateLimit: 1);
    ((page['items'] as List).single as Map)['content'] = '调用方修改';
    expect(await ranked(candidateLimit: 1), ['a']);
    expect(repository.candidateRows.length, reads);
    await repository.recordUsage(ids: ['b'], injected: true);
    expect(await ranked(candidateLimit: 1), ['b']);
    expect(repository.candidateRows.length, greaterThan(reads));
    await repository.saveMemory(entry('a', content: '人工变更'), userEdited: true);
    expect(await ranked(candidateLimit: 1), ['a']);
    final current = await repository.queryMemory(candidateLimit: 1);
    expect(((current['items'] as List).single as Map)['content'], '人工变更');
    await expectLater(
      db.transaction(() async {
        await db.customStatement(
          'UPDATE memory_items SET importance=100, user_edited=1 WHERE id=?',
          ['b'],
        );
        await repository.queryMemory(candidateLimit: 1);
        throw StateError('rollback');
      }),
      throwsStateError,
    );
    expect((await ranked(candidateLimit: 1)).first, 'a');
  });

  test('时钟前进可复用有充分边界的候选，过期与时间回退强制重查', () async {
    await repository.saveMemory({
      ...entry('a'),
      'importance': 100,
      'expiresAt': now.add(const Duration(seconds: 2)).millisecondsSinceEpoch,
    });
    await repository.saveMemory({...entry('b'), 'importance': 1});
    expect(await ranked(candidateLimit: 1), ['a']);
    final reads = repository.candidateRows.length;
    now = now.add(const Duration(milliseconds: 100));
    expect(await ranked(candidateLimit: 1), ['a']);
    expect(repository.candidateRows.length, reads);
    now = now.add(const Duration(seconds: 2));
    expect(await ranked(candidateLimit: 1), ['b']);
    expect(repository.candidateRows.length, greaterThan(reads));
    now = now.subtract(const Duration(seconds: 2));
    expect(await ranked(candidateLimit: 1), ['a']);
  });

  test('缓存的排名边界不足时重查，时间衰减可以改变候选集合', () async {
    await repository.saveMemory({...entry('a-old'), 'importance': 100});
    await db.customStatement(
      'UPDATE memory_items SET updated_at=? WHERE id=?',
      [now.subtract(const Duration(days: 60)).millisecondsSinceEpoch, 'a-old'],
    );
    await repository.saveMemory({...entry('b-new'), 'importance': 1});
    expect(await ranked(candidateLimit: 1), ['b-new']);
    final reads = repository.candidateRows.length;
    now = now.add(const Duration(days: 365));
    expect(await ranked(candidateLimit: 1), ['a-old']);
    expect(repository.candidateRows.length, greaterThan(reads));
  });

  test('5k 真实注入 SQL 候选有界且预热后 p95 小于 5ms', () async {
    final timestamp = now.millisecondsSinceEpoch;
    await db.customStatement('''
      WITH RECURSIVE n(x) AS (SELECT 1 UNION ALL SELECT x+1 FROM n WHERE x<100)
      INSERT INTO memory_topics(id,canonical_name,kind,created_at)
      SELECT 'topic-'||x, '主题 '||x, 'fact', $timestamp FROM n
    ''');
    await db.customStatement('''
      INSERT INTO memory_topic_aliases(topic_id,alias,normalized_alias)
      SELECT id, canonical_name, canonical_name FROM memory_topics
    ''');
    await db.customStatement('''
      WITH RECURSIVE n(x) AS (SELECT 1 UNION ALL SELECT x+1 FROM n WHERE x<5000)
      INSERT INTO memory_items(id,layer,topic_id,content,certainty,importance,
        created_at,updated_at,source_kind)
      SELECT 'item-'||x,
        CASE x%5 WHEN 0 THEN 'identity' WHEN 1 THEN 'semantic'
          WHEN 2 THEN 'episodic' WHEN 3 THEN 'procedural' ELSE 'observation' END,
        'topic-'||(x%100+1), '长期记忆 alpha '||x,
        CASE WHEN x%5=4 THEN 'unverified' ELSE 'stated' END,
        x%100+1, $timestamp, $timestamp-x*8640000, 'extraction' FROM n
    ''');
    await db.customStatement('''
      INSERT INTO memory_usage(item_id,recall_count,inject_count)
      SELECT id, rowid%10, rowid%7 FROM memory_items
    ''');
    await db.customStatement('''
      INSERT INTO memory_episodes(item_id,source_refs_json)
      SELECT id, '[]' FROM memory_items WHERE layer='episodic'
    ''');
    await db.customStatement('''
      INSERT INTO memory_procedures(item_id,steps_json,source_refs_json)
      SELECT id, '["核对","执行"]', '[]' FROM memory_items WHERE layer='procedural'
    ''');
    final assembler = MemoryContextAssembler(memory: MemoryService(repository));
    for (var index = 0; index < 10; index++) {
      expect((await assembler.assemble(topic: 'alpha')).isEmpty, isFalse);
    }
    expect(repository.candidateRows, isNotEmpty);
    expect(repository.candidateRows, everyElement(lessThanOrEqualTo(25)));
    repository.candidateRows.clear();
    final samples = <int>[];
    final watch = Stopwatch();
    for (var index = 0; index < 100; index++) {
      now = now.add(const Duration(milliseconds: 1));
      watch.reset();
      watch.start();
      final result = await assembler.assemble(topic: 'alpha');
      watch.stop();
      samples.add(watch.elapsedMicroseconds);
      expect(result.isEmpty, isFalse);
    }
    samples.sort();
    final p95 = samples[94];
    // 实测输出保留单位与样本口径，不能用单次耗时替代 p95。
    // ignore: avoid_print
    print(
      'memory injection: 5000 rows, topic=alpha, warmup=10, samples=100, '
      'p50=${samples[49]}us, p95=${p95}us, max=${samples.last}us',
    );
    expect(repository.candidateRows, everyElement(lessThanOrEqualTo(25)));
    expect(repository.candidateRows.length, lessThanOrEqualTo(400));
    expect(p95, lessThan(5000));
  });
}

import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mission_book/application/goals/goal_service.dart';
import 'package:mission_book/data/assistant/drift_unified_reader.dart';
import 'package:mission_book/data/local/app_database.dart';
import 'package:mission_book/data/repositories/drift_goal_repository.dart';
import 'package:mission_book/data/repositories/drift_memory_repository.dart';

void main() {
  test('另一个连接更正后候选缓存和事实版本同时失效', () async {
    final directory = await Directory.systemTemp.createTemp(
      'memory-connections-',
    );
    final file = File('${directory.path}/memory.sqlite');
    final firstDb = AppDatabase(executor: NativeDatabase(file));
    final secondDb = AppDatabase(executor: NativeDatabase(file));
    final first = DriftMemoryRepository(firstDb);
    final second = DriftMemoryRepository(secondDb);
    try {
      final entry = <String, Object?>{
        'id': 'same',
        'content': '原始偏好',
        'topic': '偏好主题',
        'layer': 'identity',
        'certainty': 'stated',
        'sourceKind': 'user',
      };
      await first.saveMemory(entry);
      expect(
        (await first.queryMemory(search: '原始', candidateLimit: 2))['items']
            as List,
        hasLength(1),
      );
      final revision = await first.contextRevision();
      await second.saveMemory({...entry, 'content': '更正偏好'}, userEdited: true);
      expect(await first.contextRevision(), isNot(revision));
      expect(
        (await first.queryMemory(search: '原始', candidateLimit: 2))['items']
            as List,
        isEmpty,
      );
      expect(
        (await first.queryMemory(search: '更正', candidateLimit: 2))['items']
            as List,
        hasLength(1),
      );
    } finally {
      await secondDb.close();
      await firstDb.close();
      await directory.delete(recursive: true);
    }
  });

  test('统计与新增不使原回答失效，到期和遗忘改变事实版本', () async {
    var now = DateTime.utc(2030);
    final db = AppDatabase(executor: NativeDatabase.memory());
    final repository = DriftMemoryRepository(db, clock: () => now);
    try {
      final initial = await repository.contextRevision();
      await repository.saveMemory({
        'id': 'expires',
        'content': '有期限的偏好',
        'topic': '期限',
        'layer': 'semantic',
        'certainty': 'stated',
        'sourceKind': 'user',
        'expiresAt': now.add(const Duration(minutes: 1)).millisecondsSinceEpoch,
      });
      await repository.recordUsage(ids: ['expires'], injected: true);
      expect(await repository.contextRevision(), initial);
      now = now.add(const Duration(minutes: 2));
      final expired = await repository.contextRevision();
      expect(expired, isNot(initial));
      await repository.forgetMemory('expires');
      expect(await repository.contextRevision(), isNot(expired));
    } finally {
      await db.close();
    }
  });

  test('单节点超长标题在目标与歧义候选中有界，编号保持原值', () async {
    final db = AppDatabase(executor: NativeDatabase.memory());
    final goals = GoalService(DriftGoalRepository(db));
    try {
      final goal = goals.prepareCreation(title: '有界目标');
      await goals.create(goal);
      final title = '长😀' * 10000;
      final node = goals.prepareNodeCreation(goalId: goal.id, title: title);
      await goals.createNode(node);
      final reader = DriftUnifiedReader(db);
      final result = await reader.getGoal(goal: goal.id);
      final item = ((result['nodes'] as Map)['items'] as List).single as Map;
      expect(item['id'], node.id);
      expect((item['title'] as String).runes.length, 200);
      expect(item['titleLength'], title.runes.length);
      expect((await reader.resolve('goal_nodes', node.id))['id'], node.id);
    } finally {
      await goals.dispose();
      await db.close();
    }
  });
}

import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mission_book/data/local/app_database.dart';
import 'package:mission_book/data/repositories/drift_memory_repository.dart';

void main() {
  test('关闭并重开数据库后仍使用原清单和原用户消息完成清理', () async {
    final directory = await Directory.systemTemp.createTemp(
      'missionbook-memory-',
    );
    final file = File('${directory.path}/test.sqlite');
    var database = AppDatabase(executor: NativeDatabase(file));
    try {
      var repository = DriftMemoryRepository(database);
      await database
          .into(database.assistantSessions)
          .insert(
            AssistantSessionsCompanion.insert(
              id: 'session',
              title: '测试',
              createdAt: 1,
              updatedAt: 1,
            ),
          );
      await database
          .into(database.assistantSessionRecords)
          .insert(
            AssistantSessionRecordsCompanion.insert(
              sessionId: 'session',
              sequence: 0,
              timestamp: 1,
              type: 'message_added',
              data: jsonEncode({
                'message': {
                  'id': 'user',
                  'role': 'user',
                  'content': [
                    {'type': 'text', 'text': '删除第1条'},
                  ],
                },
              }),
            ),
          );
      await repository.saveMemory({
        'id': 'memory',
        'content': '测试事实',
        'kind': 'fact',
        'certainty': 'stated',
        'source': '用户',
        'conflictKey': '主题',
      });
      await repository.selectMemory(
        sessionId: 'session',
        selectionId: 'selection',
      );
      await database.close();

      database = AppDatabase(executor: NativeDatabase(file));
      repository = DriftMemoryRepository(database);
      final result = await repository.forgetSelection(
        sessionId: 'session',
        sourceMessageId: 'user',
        selectionId: 'selection',
        itemIds: ['1'],
        operationId: 'operation',
      );
      expect(result['status'], 'success');
      expect(
        (await database.select(database.memoryEntries).get()).single.forgotten,
        isTrue,
      );
      await database.close();

      database = AppDatabase(executor: NativeDatabase(file));
      repository = DriftMemoryRepository(database);
      expect(
        await repository.forgetSelection(
          sessionId: 'session',
          sourceMessageId: 'user',
          selectionId: 'selection',
          itemIds: ['1'],
          operationId: 'operation',
        ),
        result,
      );
    } finally {
      await database.close();
      await directory.delete(recursive: true);
    }
  });
}

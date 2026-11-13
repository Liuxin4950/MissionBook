import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mission_book/application/analysis/analysis_service.dart';
import 'package:mission_book/application/memory/memory_context.dart';
import 'package:mission_book/application/memory/memory_service.dart';
import 'package:mission_book/application/memory/memory_settings.dart';
import 'package:mission_book/data/analysis/drift_analysis_store.dart';
import 'package:mission_book/data/assistant/drift_session_store.dart';
import 'package:mission_book/data/local/app_database.dart';
import 'package:mission_book/data/memory/drift_memory_settings_store.dart';
import 'package:mission_book/data/repositories/drift_memory_repository.dart';

class _FailingSettings implements MemorySettingsStore {
  @override
  Future<bool> extractionEnabled() async => throw StateError('读取失败');
  @override
  Future<void> saveExtractionEnabled(bool enabled) async =>
      throw StateError('写入失败');
}

void main() {
  late AppDatabase db;
  late DriftMemoryRepository repository;
  late MemoryService memory;
  late DriftMemorySettingsStore settings;

  setUp(() {
    db = AppDatabase(executor: NativeDatabase.memory());
    repository = DriftMemoryRepository(db);
    memory = MemoryService(repository);
    settings = DriftMemorySettingsStore(db);
  });

  tearDown(() async => db.close());

  Future<void> appendUserMessage(String sessionId, int sequence) async {
    final handle = await DriftSessionStore(db).create(sessionId);
    try {
      await handle.append('session_created', {
        'id': sessionId,
        'title': '记忆开关',
      });
      await handle.append('message_added', {
        'message': {
          'id': 'user-$sequence',
          'role': 'user',
          'content': [
            {'type': 'text', 'text': '我喜欢上午学习'},
          ],
        },
      });
    } finally {
      await handle.close();
    }
  }

  Future<int> memoryJobs() async =>
      (await db
              .customSelect(
                "SELECT COUNT(*) n FROM analysis_jobs WHERE scope='memory'",
              )
              .getSingle())
          .read<int>('n');

  test('默认开启时新用户消息排记忆任务，关闭后不再排且已有记忆仍可注入', () async {
    expect(await settings.extractionEnabled(), true);
    await appendUserMessage('session-on', 1);
    expect(await memoryJobs(), 1);

    await repository.saveMemory({
      'id': 'existing',
      'content': '已有偏好仍然可用',
      'layer': 'identity',
      'certainty': 'stated',
      'topic': '已有主题',
      'sourceKind': 'user',
    });
    await settings.saveExtractionEnabled(false);
    expect(await settings.extractionEnabled(), false);
    await appendUserMessage('session-off', 1);
    expect(await memoryJobs(), 1);

    final assembler = MemoryContextAssembler(memory: memory);
    final context = await assembler.assemble();
    expect(context.text, contains('已有偏好仍然可用'));
  });

  test('关闭状态随备份导出恢复，读取失败回退默认开启', () async {
    await settings.saveExtractionEnabled(false);
    final row = await db.select(db.appSettings).getSingle();
    expect(row.key, DriftMemorySettingsStore.extractionKey);
    expect(row.value, '0');

    final failing = AnalysisService(
      store: DriftAnalysisStore(db),
      model: (p, {imageKey, mime, json = false}) async => '{}',
      mainBusy: () => true,
      memorySettings: _FailingSettings(),
    );
    try {
      await failing.loadPreferences();
      expect(failing.memoryExtractionEnabled, true);
    } finally {
      await failing.dispose();
    }
    expect(jsonEncode({'value': row.value}), contains('0'));
  });
}

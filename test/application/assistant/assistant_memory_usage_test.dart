import 'dart:async';

import 'package:agent_core/agent_core.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mission_book/application/assistant/assistant_controller.dart';
import 'package:mission_book/application/goals/goal_service.dart';
import 'package:mission_book/application/memory/memory_service.dart';
import 'package:mission_book/application/missions/mission_service.dart';
import 'package:mission_book/data/assistant/drift_session_store.dart';
import 'package:mission_book/data/assistant/drift_unified_reader.dart';
import 'package:mission_book/data/local/app_database.dart';
import 'package:mission_book/data/repositories/drift_goal_repository.dart';
import 'package:mission_book/data/repositories/drift_memory_repository.dart';
import 'package:mission_book/data/repositories/drift_mission_repository.dart';

import '../../support/assistant_fakes.dart';

class _PausedMemoryStore extends DriftSessionStore {
  _PausedMemoryStore(super.database);
  final entered = Completer<void>();
  final release = Completer<void>();
  bool fail = false;

  @override
  Future<SessionHandle> create(
    String id, {
    List<SessionRecord> initialRecords = const [],
  }) async => _PausedMemoryHandle(
    await super.create(id, initialRecords: initialRecords),
    this,
  );
}

class _PausedMemoryHandle implements SessionHandle {
  _PausedMemoryHandle(this.inner, this.store);
  final SessionHandle inner;
  final _PausedMemoryStore store;
  @override
  String get id => inner.id;
  @override
  int get recordCount => inner.recordCount;
  @override
  bool get readOnly => inner.readOnly;
  @override
  Future<List<SessionRecord>> readRecords({int start = 0, int? limit}) =>
      inner.readRecords(start: start, limit: limit);
  @override
  Future<void> close() => inner.close();
  @override
  Future<SessionRecord> append(String type, Map<String, Object?> data) async {
    if (type == 'context_message_replaced' &&
        data['source'] == 'mission_book_memory') {
      store.entered.complete();
      await store.release.future;
      if (store.fail) throw StateError('模拟记忆上下文写入失败');
    }
    return inner.append(type, data);
  }
}

class _UsageMemory extends MemoryService {
  _UsageMemory(super.repository);
  final started = Completer<void>();
  Completer<void>? writeGate;
  final writes = <List<String>>[];
  @override
  Future<void> recordUsage({
    required List<String> ids,
    required bool injected,
  }) async {
    expect(injected, true);
    writes.add(List.of(ids));
    if (!started.isCompleted) started.complete();
    await writeGate?.future;
    await super.recordUsage(ids: ids, injected: injected);
  }
}

void main() {
  late AppDatabase db;
  late MissionService missions;
  late GoalService goals;
  late _PausedMemoryStore store;
  late _UsageMemory memory;
  late ScriptedModel model;
  late AssistantController controller;
  setUp(() async {
    db = AppDatabase(executor: NativeDatabase.memory());
    missions = MissionService(DriftMissionRepository(db));
    goals = GoalService(DriftGoalRepository(db));
    store = _PausedMemoryStore(db);
    memory = _UsageMemory(DriftMemoryRepository(db));
    await memory.save({
      'id': 'memory',
      'content': '喜欢上午学习',
      'layer': 'identity',
      'certainty': 'stated',
      'topic': '学习时间',
      'sourceKind': 'user',
    });
    model = ScriptedModel([(_) => textResponse('已回答')]);
    controller = AssistantController(
      sessionStore: store,
      settingsStore: MemoryAssistantSettingsStore(),
      missions: missions,
      goals: goals,
      memory: memory,
      unifiedReader: DriftUnifiedReader(db),
      modelOverrides: {'deepseek-chat': model},
    );
    await controller.initialize();
  });
  tearDown(() async {
    if (!store.release.isCompleted) store.release.complete();
    if (memory.writeGate?.isCompleted == false) memory.writeGate!.complete();
    await controller.close();
    await missions.dispose();
    await goals.dispose();
    await db.close();
  });

  test('replaceContext失败不记录注入统计，也不调用模型', () async {
    store.fail = true;
    final send = controller.send('开始讨论');
    await store.entered.future;
    expect(memory.writes, isEmpty);
    store.release.complete();
    expect(await send, isNull);
    await controller.close();
    expect(memory.writes, isEmpty);
    expect(model.requests, isEmpty);
    expect(controller.lastMemoryInjection, isEmpty);
  });

  test('replaceContext期间取消，成功写入后仍不记录注入', () async {
    final send = controller.send('开始讨论');
    await store.entered.future;
    controller.stop();
    store.release.complete();
    expect(await send, isNull);
    await controller.close();
    expect(memory.writes, isEmpty);
    expect(model.requests, isEmpty);
    expect(controller.lastMemoryInjection, isEmpty);
  });

  test('成功注入才计数，统计阻塞不阻塞发送，close等待drain后落库', () async {
    memory.writeGate = Completer<void>();
    final send = controller.send('开始讨论');
    await store.entered.future;
    expect(memory.writes, isEmpty);
    store.release.complete();
    expect(await send, isNotNull);
    await memory.started.future;
    expect(memory.writes, [
      ['memory'],
    ]);
    expect(controller.lastMemoryInjection.single['id'], 'memory');
    expect(
      model.requests.single.messages.whereType<ContextMessage>().any(
        (m) => m.source == 'mission_book_memory' && m.text.contains('喜欢上午学习'),
      ),
      true,
    );
    var closed = false;
    final closing = controller.close().then((_) => closed = true);
    await Future<void>.delayed(Duration.zero);
    expect(closed, false);
    memory.writeGate!.complete();
    await closing;
    final usage = await db.select(db.memoryUsage).get();
    expect(usage.single.itemId, 'memory');
    expect(usage.single.injectCount, 1);
    expect(usage.single.recallCount, 0);
  });
}

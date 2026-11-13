import 'dart:async';

import 'package:agent_core/agent_core.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mission_book/application/assistant/assistant_controller.dart';
import 'package:mission_book/application/goals/goal_service.dart';
import 'package:mission_book/application/missions/mission_service.dart';
import 'package:mission_book/core/theme/app_theme.dart';
import 'package:mission_book/data/assistant/drift_session_store.dart';
import 'package:mission_book/data/assistant/drift_unified_reader.dart';
import 'package:mission_book/data/local/app_database.dart';
import 'package:mission_book/data/repositories/drift_goal_repository.dart';
import 'package:mission_book/data/repositories/drift_mission_repository.dart';
import 'package:mission_book/presentation/assistant/chat/assistant_page.dart';
import 'package:mission_book/presentation/assistant/shared/assistant_thinking.dart';

import '../../support/assistant_fakes.dart';

/// 持续按小段输出，便于观察流式期间的整页通知次数。
class SlowStreamingModel implements StreamingAgentModel {
  static const chunkCount = 30;

  static ModelResponse _response(String text) => ModelResponse(
    message: AssistantMessage(
      content: [TextBlock(text: text)],
      provider: 'test',
      model: 'scripted',
    ),
    stopReason: ModelStopReason.completed,
  );

  @override
  Future<ModelResponse> complete(
    ModelRequest request,
    CancellationToken cancellation,
  ) async => _response(List.generate(chunkCount, (i) => '片$i').join());

  @override
  Stream<ModelStreamEvent> stream(
    ModelRequest request,
    CancellationToken cancellation,
  ) async* {
    final text = StringBuffer();
    for (var i = 0; i < chunkCount; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
      text.write('片$i');
      yield ModelTextDelta(0, '片$i');
    }
    yield ModelCompleted(_response(text.toString()));
  }
}

class GatedMarkdownModel implements StreamingAgentModel {
  GatedMarkdownModel({this.fail = false});
  final bool fail;
  final gate = Completer<void>();
  static const thought = '**检查依据**\n\n需要保留用户展开的内容。';
  static const reply =
      '# 当前进度\n\n**已经渲染**\n\n- 第一项\n- 第二项\n\n```dart\nfinal value = 1;\n```';
  ModelResponse get response => ModelResponse(
    message: AssistantMessage(
      content: const [
        ThinkingBlock(text: thought),
        TextBlock(text: reply),
      ],
      provider: 'test',
      model: 'gated',
    ),
    stopReason: ModelStopReason.completed,
  );
  @override
  Future<ModelResponse> complete(
    ModelRequest request,
    CancellationToken token,
  ) async => response;
  @override
  Stream<ModelStreamEvent> stream(
    ModelRequest request,
    CancellationToken token,
  ) async* {
    yield const ModelThinkingDelta(0, thought);
    yield const ModelTextDelta(1, reply);
    await token.wait(gate.future);
    if (fail) throw const ModelException('test_failure', '测试中断');
    yield ModelCompleted(response);
  }
}

class FailedReferenceStore extends DriftSessionStore {
  FailedReferenceStore(super.database);
  final entered = Completer<void>();
  final gate = Completer<void>();
  @override
  Future<void> attachReference(
    String id, {
    String? missionId,
    String? goalId,
    String? nodeId,
  }) async {
    entered.complete();
    await gate.future;
    throw StateError('关联失败');
  }
}

class FailedContextStore extends DriftSessionStore {
  FailedContextStore(super.database);
  final entered = Completer<void>();
  final gate = Completer<void>();
  @override
  Future<SessionHandle> create(
    String id, {
    List<SessionRecord> initialRecords = const [],
  }) async => _FailedContextHandle(
    await super.create(id, initialRecords: initialRecords),
    this,
  );
}

class _FailedContextHandle implements SessionHandle {
  _FailedContextHandle(this.inner, this.store);
  final SessionHandle inner;
  final FailedContextStore store;
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
    if (type == 'context_message_replaced' ||
        (type == 'message_added' &&
            data['message'] is Map &&
            (data['message'] as Map)['role'] == 'context')) {
      store.entered.complete();
      await store.gate.future;
      throw StateError('上下文保存失败');
    }
    return inner.append(type, data);
  }
}

void main() {
  late AppDatabase database;
  late MissionService missions;
  late GoalService goals;
  AssistantController? controller;
  final now = DateTime.utc(2026, 10, 29, 4);

  setUp(() {
    database = AppDatabase(executor: NativeDatabase.memory());
    missions = MissionService(
      DriftMissionRepository(database),
      clock: () => now,
    );
    goals = GoalService(DriftGoalRepository(database));
  });

  tearDown(() async {
    await controller?.close();
    controller?.dispose();
    await missions.dispose();
    await goals.dispose();
    await database.close();
  });

  Future<AssistantController> makeController(
    AgentModel model, {
    DriftSessionStore? store,
  }) async {
    final result = AssistantController(
      unifiedReader: DriftUnifiedReader(database),
      sessionStore: store ?? DriftSessionStore(database),
      settingsStore: MemoryAssistantSettingsStore(),
      missions: missions,
      goals: goals,
      modelOverrides: {'deepseek-chat': model},
      clock: () => now,
    );
    controller = result;
    await result.initialize();
    await result.saveCredential('test-key');
    return result;
  }

  Future<void> waitFor(bool Function() condition) async {
    for (var attempt = 0; attempt < 200; attempt++) {
      if (condition()) return;
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
    throw StateError('等待流式状态超时');
  }

  test('流式增量只更新活动快照，不触发整页逐帧通知', () async {
    final assistant = await makeController(SlowStreamingModel());
    var notifications = 0;
    assistant.addListener(() => notifications++);

    final run = assistant.send('流式测试');
    await waitFor(() => assistant.liveActivity.value.text.isNotEmpty);
    final settled = notifications;
    final received = assistant.activity.text.length;
    final settledTranscript = assistant.transcript;
    expect(assistant.isRunning, isTrue);

    await Future<void>.delayed(const Duration(milliseconds: 200));
    expect(
      assistant.activity.text.length,
      greaterThan(received),
      reason: '模型仍在持续输出',
    );
    expect(notifications, settled, reason: '流式增量不应让整页跟随重建');
    expect(
      assistant.transcript,
      same(settledTranscript),
      reason: '纯文本增量不应重复复制整条消息历史',
    );

    await run;
    expect(assistant.transcript, isNot(same(settledTranscript)));
    final reply = assistant.transcript.whereType<AssistantMessage>().last;
    expect(
      reply.text,
      List.generate(SlowStreamingModel.chunkCount, (i) => '片$i').join(),
    );
    expect(assistant.liveActivity.value.modelRequestRunning, isFalse);
    expect(notifications, greaterThan(settled));
  });

  testWidgets('流式正文在生成区域逐步出现，完成后显示正式消息', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final assistant = await makeController(SlowStreamingModel());
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: AssistantPage(controller: assistant, showBack: true),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('assistant-input')), '流式测试');
    await tester.pump();
    await tester.tap(find.byKey(const Key('assistant-send')));

    Future<void> tick() async {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 1)),
      );
      await tester.pump(const Duration(milliseconds: 20));
    }

    var sawLive = false;
    for (var i = 0; i < 60 && !sawLive; i++) {
      await tick();
      sawLive =
          assistant.activity.text.isNotEmpty &&
          find.textContaining('片').evaluate().isNotEmpty;
    }
    expect(sawLive, isTrue, reason: '流式正文需要出现在生成区域');
    expect(assistant.isRunning, isTrue);
    final streamingBubble = find
        .ancestor(
          of: find.textContaining('片').first,
          matching: find.byType(Material),
        )
        .first;
    expect(
      tester.getSize(streamingBubble).width,
      342,
      reason: '生成中的短回复也应铺开手机的正文区，和完成后的回答保持一致',
    );

    for (var i = 0; i < 100 && assistant.isRunning; i++) {
      await tick();
    }
    await tester.pumpAndSettle();
    expect(assistant.isRunning, isFalse);
    expect(find.textContaining('片29'), findsWidgets);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.runAsync(() => assistant.close());
  });
  testWidgets('生成期间已渲染 Markdown，展开的思考在结束后保留', (tester) async {
    final model = GatedMarkdownModel();
    final assistant = await makeController(model);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: AssistantPage(controller: assistant, showBack: true),
      ),
    );
    await tester.pumpAndSettle();
    final run = assistant.send('请输出 Markdown');
    for (var i = 0; i < 60 && assistant.activity.text.isEmpty; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 5)),
      );
      await tester.pump(const Duration(milliseconds: 20));
    }
    expect(assistant.isRunning, isTrue);
    expect(find.text('当前进度'), findsOneWidget);
    expect(find.textContaining('# 当前进度'), findsNothing);
    expect(find.text('已经渲染'), findsOneWidget);
    await tester.tap(find.byType(AssistantThinking));
    await tester.pump();
    expect(find.text('检查依据'), findsOneWidget);
    final process = find.byType(AssistantProcess);
    // 显式收起再展开，验证结束时遵守用户选择。
    final processHeader = find
        .descendant(of: process, matching: find.byType(TextButton))
        .first;
    await tester.tap(processHeader);
    await tester.pump();
    await tester.tap(processHeader);
    await tester.pump();
    final thoughtState = tester.state(find.byType(AssistantThinking));
    model.gate.complete();
    await tester.runAsync(() => run);
    await tester.pumpAndSettle();
    expect(tester.state(find.byType(AssistantThinking)), same(thoughtState));
    expect(find.text('检查依据'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.runAsync(() => assistant.close());
  });

  test('中断正文和思考可回放但不进入后续模型上下文', () async {
    final model = GatedMarkdownModel(fail: true);
    final assistant = await makeController(model);
    final run = assistant.send('中断测试');
    await waitFor(() => assistant.activity.text.isNotEmpty);
    model.gate.complete();
    await run;
    final id = assistant.currentSessionId!;
    expect(assistant.interruptedAttempts.single.text, GatedMarkdownModel.reply);
    expect(
      assistant.interruptedAttempts.single.thinking,
      GatedMarkdownModel.thought,
    );
    expect(assistant.transcript.whereType<AssistantMessage>(), isEmpty);
    await assistant.startNewSession();
    await assistant.openConversation(id);
    expect(assistant.interruptedAttempts.single.text, GatedMarkdownModel.reply);
    expect(assistant.transcript.whereType<AssistantMessage>(), isEmpty);
  });
  testWidgets('发送准备失败时保留原内容和用户新草稿并释放空会话', (tester) async {
    final store = FailedReferenceStore(database);
    final assistant = await makeController(ScriptedModel([]), store: store);
    await missions.create(
      title: '草稿任务',
      scheduledDate: '2026-10-29',
      timeZone: 'Asia/Shanghai',
      plannedDurationMinutes: 30,
    );
    await assistant.openMissionReference(
      (await missions.findAllDetails()).single.mission.id,
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: AssistantPage(controller: assistant, showBack: true),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('assistant-input')), '原始待发送内容');
    await tester.pump();
    await tester.tap(find.byKey(const Key('assistant-send')));
    for (var i = 0; i < 50 && !store.entered.isCompleted; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 2)),
      );
      await tester.pump();
    }
    expect(store.entered.isCompleted, isTrue);
    await tester.enterText(find.byKey(const Key('assistant-input')), '用户新写的草稿');
    store.gate.complete();
    for (var i = 0; i < 50 && assistant.isRunning; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 2)),
      );
      await tester.pump();
    }
    await tester.pumpAndSettle();
    expect(find.text('用户新写的草稿'), findsOneWidget);
    expect(assistant.unsentDrafts.single.text, '原始待发送内容');
    expect(await store.listConversations(), isEmpty);
    await tester.enterText(find.byKey(const Key('assistant-input')), '');
    await tester.tap(find.text('恢复'));
    await tester.pumpAndSettle();
    expect(find.text('原始待发送内容'), findsOneWidget);
    expect(assistant.unsentDrafts, isEmpty);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.runAsync(() => assistant.close());
  });
  testWidgets('空壳会话清理时把期间新写的草稿带回原身份', (tester) async {
    final store = FailedContextStore(database);
    final assistant = await makeController(ScriptedModel([]), store: store);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: AssistantPage(controller: assistant, showBack: true),
      ),
    );
    await tester.pumpAndSettle();
    final original = assistant.draftKey;
    await tester.enterText(find.byKey(const Key('assistant-input')), '原发送内容');
    await tester.pump();
    await tester.tap(find.byKey(const Key('assistant-send')));
    for (var i = 0; i < 100 && !store.entered.isCompleted; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 2)),
      );
      await tester.pump();
    }
    expect(store.entered.isCompleted, isTrue);
    expect(assistant.draftKey, isNot(original));
    await tester.enterText(
      find.byKey(const Key('assistant-input')),
      '空壳期间的新草稿',
    );
    store.gate.complete();
    for (var i = 0; i < 100 && assistant.isRunning; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 2)),
      );
      await tester.pump();
    }
    await tester.pumpAndSettle();
    expect(assistant.draftKey, original);
    expect(find.text('空壳期间的新草稿'), findsOneWidget);
    expect(assistant.unsentDrafts.single.text, '原发送内容');
    expect(await store.listConversations(), isEmpty);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.runAsync(() => assistant.close());
  });
}

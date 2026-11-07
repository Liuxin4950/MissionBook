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
import 'package:mission_book/presentation/assistant/assistant_page.dart';

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

  Future<AssistantController> makeController(AgentModel model) async {
    final result = AssistantController(
      unifiedReader: DriftUnifiedReader(database),
      sessionStore: DriftSessionStore(database),
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
}

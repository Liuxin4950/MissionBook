import 'dart:async';
import 'dart:convert';
import 'dart:ui' show Tristate;

import 'package:agent_core/agent_core.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mission_book/application/assistant/assistant_attachment.dart';
import 'package:mission_book/application/assistant/assistant_controller.dart';
import 'package:mission_book/application/assistant/assistant_speech.dart';
import 'package:mission_book/application/goals/goal_service.dart';
import 'package:mission_book/application/missions/mission_service.dart';
import 'package:mission_book/core/theme/app_layout.dart';
import 'package:mission_book/core/theme/app_theme.dart';
import 'package:mission_book/core/theme/colors.dart';
import 'package:mission_book/data/assistant/drift_session_store.dart';
import 'package:mission_book/data/assistant/drift_unified_reader.dart';
import 'package:mission_book/data/local/app_database.dart';
import 'package:mission_book/data/repositories/drift_goal_repository.dart';
import 'package:mission_book/data/repositories/drift_mission_repository.dart';
import 'package:mission_book/presentation/assistant/chat/assistant_page.dart';
import 'package:mission_book/presentation/assistant/entry/assistant_scope.dart';

import '../../support/assistant_fakes.dart';

/// 语音服务替身：本文件只关心麦克风入口占位，不触发真实识别。
class _TestSpeech implements AssistantSpeech {
  @override
  Future<bool> start({
    required void Function(String) onText,
    required VoidCallback onDone,
    VoidCallback? onProcessing,
    required void Function(String) onError,
  }) async => true;
  @override
  Future<void> stop() async {}
  @override
  Future<void> cancel() async {}
}

/// 持续生成直到被取消的模型：用来稳定停在「正在生成」三态上。
class _HangingModel implements StreamingAgentModel {
  static ModelResponse get _response => ModelResponse(
    message: AssistantMessage(
      content: const [TextBlock(text: '完成')],
      provider: 'test',
      model: 'gated',
    ),
    stopReason: ModelStopReason.completed,
  );

  @override
  Future<ModelResponse> complete(
    ModelRequest request,
    CancellationToken cancellation,
  ) async {
    await cancellation.wait(Completer<void>().future);
    return _response;
  }

  @override
  Stream<ModelStreamEvent> stream(
    ModelRequest request,
    CancellationToken cancellation,
  ) async* {
    yield const ModelTextDelta(0, '生成中');
    await cancellation.wait(Completer<void>().future);
    yield ModelCompleted(_response);
  }
}

void main() {
  late AppDatabase database;
  late MissionService missions;
  late GoalService goals;
  late AssistantController assistant;
  late AssistantVoiceController voice;

  setUp(() {
    database = AppDatabase(executor: NativeDatabase.memory());
    missions = MissionService(
      DriftMissionRepository(database),
      clock: () => DateTime.utc(2026, 11, 23),
    );
    goals = GoalService(DriftGoalRepository(database));
    voice = AssistantVoiceController(_TestSpeech());
  });

  void assistantTest(
    String description,
    Future<void> Function(WidgetTester) body,
  ) {
    testWidgets(description, (tester) async {
      try {
        await body(tester);
      } finally {
        // 页面与控制器在真实异步区域收尾，避免挂起的会话让测试超时。
        assistant.stop();
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.runAsync(() => assistant.close());
        assistant.dispose();
        voice.dispose();
        await tester.runAsync(() async {
          await missions.dispose();
          await goals.dispose();
          await database.close();
        });
      }
    });
  }

  final send = find.byKey(const Key('assistant-send'));
  final sendSurface = find.byKey(const Key('assistant-send-surface'));
  final input = find.byKey(const Key('assistant-input'));

  Future<void> mount(
    WidgetTester tester,
    AgentModel model, {
    double width = 390,
    double height = 844,
    List<AssistantAttachment> attachments = const [],
  }) async {
    tester.view.physicalSize = Size(width, height);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetViewInsets);
    assistant = AssistantController(
      unifiedReader: DriftUnifiedReader(database),
      sessionStore: DriftSessionStore(database),
      settingsStore: MemoryAssistantSettingsStore(),
      missions: missions,
      goals: goals,
      modelOverrides: {'deepseek-chat': model},
      clock: () => DateTime.utc(2026, 11, 23, 9),
    );
    await assistant.initialize();
    await assistant.saveCredentialForProvider('deepseek-api', 'test-key');
    if (attachments.isNotEmpty) {
      assistant.saveAttachments(assistant.draftKey, attachments);
    }
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: AssistantScope(
          controller: assistant,
          voice: voice,
          missions: missions,
          goals: goals,
          child: AssistantPage(controller: assistant, showBack: true),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> pumpUntil(
    WidgetTester tester,
    bool Function() condition, {
    String reason = '等待助手状态超时',
  }) async {
    for (var i = 0; i < 200 && !condition(); i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 2)),
      );
      await tester.pump(const Duration(milliseconds: 20));
    }
    expect(condition(), isTrue, reason: reason);
  }

  Color surfaceColor(WidgetTester tester) {
    final box = tester.widget<DecoratedBox>(sendSurface);
    return (box.decoration as BoxDecoration).color!;
  }

  Icon sendIcon(WidgetTester tester) =>
      tester.widget<IconButton>(send).icon as Icon;

  /// 发送按钮只保留一个语义节点：从根节点收集带指定 tooltip 的按钮节点。
  List<SemanticsNode> sendNodes(WidgetTester tester, String tooltip) {
    final root = tester
        .binding
        .renderViews
        .first
        .owner!
        .semanticsOwner!
        .rootSemanticsNode!;
    return collectAllSemanticsNodesFrom(root).where((node) {
      final data = node.getSemanticsData();
      return data.flagsCollection.isButton && data.tooltip == tooltip;
    }).toList();
  }

  assistantTest('空输入或纯空白时发送为 48dp 槽内 36dp 浅中性圆面，不可发且只剩一个语义节点', (tester) async {
    await mount(tester, ScriptedModel([]));

    // 触控 48dp、可见圆面 36dp、中心同心：圆面只绘制，不缩触控区。
    expect(send, findsOneWidget);
    expect(tester.getSize(send), const Size(48, 48));
    expect(tester.getSize(sendSurface), const Size(36, 36));
    expect(tester.getCenter(sendSurface), tester.getCenter(send));
    expect(surfaceColor(tester), AppColors.surfaceMuted);

    final icon = sendIcon(tester);
    expect(icon.icon, Icons.arrow_upward_rounded);
    expect(icon.size, AppLayout.iconMd);
    expect(icon.color, AppColors.textSecondary);

    // 不可发：没有动作，读屏报告禁用按钮。
    expect(tester.widget<IconButton>(send).onPressed, isNull);
    expect(find.byTooltip('发送'), findsOneWidget);
    final disabledNode = sendNodes(tester, '发送');
    expect(disabledNode, hasLength(1));
    final disabledData = disabledNode.single.getSemanticsData();
    expect(disabledData.flagsCollection.isButton, isTrue);
    expect(disabledData.flagsCollection.isEnabled, Tristate.isFalse);
    expect(disabledData.hasAction(SemanticsAction.tap), isFalse);
    expect(disabledNode.single.childrenCount, 0);

    // 附件、麦克风、思考、上下文环与发送触控槽等高且中心同线。
    final toolKeys = [
      'assistant-add-attachment',
      'assistant-composer-voice',
      'assistant-reasoning',
      'assistant-context-usage',
    ];
    for (final key in toolKeys) {
      final tool = find.byKey(Key(key));
      expect(tool, findsOneWidget, reason: '$key 应留在工具行');
      expect(tester.getSize(tool).height, AppLayout.touchTargetMin);
      expect(tester.getCenter(tool).dy, tester.getCenter(send).dy);
    }

    await tester.tap(send);
    await tester.pump();
    expect(assistant.transcript, isEmpty, reason: '禁用状态点击不能发送');

    // 纯空白同样不能发送，外观仍是浅中性圆面。
    await tester.enterText(input, '   ');
    await tester.pump();
    expect(tester.widget<IconButton>(send).onPressed, isNull);
    expect(surfaceColor(tester), AppColors.surfaceMuted);
    expect(sendIcon(tester).icon, Icons.arrow_upward_rounded);
  });

  assistantTest('内容可发时同一末端槽换成森林绿 36dp 圆面与白色上箭头，48dp 边缘也能发送', (tester) async {
    final model = ScriptedModel([(_) => textResponse('收到')]);
    await mount(tester, model);
    await tester.enterText(input, '整理今天的安排');
    await tester.pump();

    expect(surfaceColor(tester), AppColors.primary);
    final icon = sendIcon(tester);
    expect(icon.icon, Icons.arrow_upward_rounded);
    expect(icon.size, AppLayout.iconMd);
    expect(icon.color, AppTheme.light.colorScheme.onPrimary);
    expect(tester.getSize(sendSurface), const Size(36, 36));
    expect(tester.getSize(send), const Size(48, 48));
    expect(tester.widget<IconButton>(send).onPressed, isNotNull);
    // 按压/焦点反馈仍在：可发状态保留主色上的白色状态层。
    expect(
      tester.widget<IconButton>(send).style?.overlayColor?.resolve({
        WidgetState.focused,
      }),
      isNotNull,
    );

    final enabledNode = sendNodes(tester, '发送');
    expect(enabledNode, hasLength(1));
    expect(
      enabledNode.single.getSemanticsData().flagsCollection.isEnabled,
      Tristate.isTrue,
    );
    expect(
      enabledNode.single.getSemanticsData().hasAction(SemanticsAction.tap),
      isTrue,
    );

    // 点在 48dp 槽内、36dp 圆面之外，仍应发送：证明触控没有跟着圆面缩小。
    await tester.tapAt(tester.getCenter(send) + const Offset(20, 20));
    await tester.pump();
    await pumpUntil(tester, () => model.requests.isNotEmpty);
    expect(
      assistant.transcript.whereType<UserMessage>().single.text,
      '整理今天的安排',
    );
  });

  assistantTest('正在生成时原位切换为浅绿 36dp 圆面与深绿停止图标，读屏停止本轮且可停止', (tester) async {
    final model = _HangingModel();
    await mount(tester, model);
    await tester.enterText(input, '写一段总结');
    await tester.pump();
    await tester.tap(send);
    await tester.pump();
    await pumpUntil(tester, () => assistant.isRunning);

    expect(surfaceColor(tester), AppColors.primarySoft);
    final icon = sendIcon(tester);
    expect(icon.icon, Icons.stop_rounded);
    expect(icon.size, AppLayout.iconMd);
    expect(icon.color, AppColors.primary);
    expect(tester.getSize(sendSurface), const Size(36, 36));
    expect(tester.getSize(send), const Size(48, 48));

    // 停止不另做一处按钮：同一个末端槽，读屏名称换成「停止本轮」。
    expect(send, findsOneWidget);
    expect(find.byTooltip('停止本轮'), findsOneWidget);
    expect(find.byTooltip('发送'), findsNothing);
    final stopNodes = sendNodes(tester, '停止本轮');
    expect(stopNodes, hasLength(1));
    expect(
      stopNodes.single.getSemanticsData().flagsCollection.isButton,
      isTrue,
    );
    expect(stopNodes.single.childrenCount, 0);

    await tester.tap(send);
    await pumpUntil(tester, () => !assistant.isRunning);
    expect(sendIcon(tester).icon, Icons.arrow_upward_rounded);
    expect(find.byTooltip('发送'), findsOneWidget);
  });

  assistantTest('只有附件也能发送：附件与发送同排，发送保留在原末端槽', (tester) async {
    final file = AssistantAttachment.fromBytes(
      '笔记.txt',
      utf8.encode('今天先复盘再安排'),
    );
    final model = ScriptedModel([(_) => textResponse('收到附件')]);
    await mount(tester, model, attachments: [file]);

    expect(find.text('笔记.txt'), findsOneWidget);
    expect(find.text('1/12 个附件'), findsOneWidget);
    // 附件菜单与发送在同一行、等高，发送在最右端。
    final attachment = find.byKey(const Key('assistant-add-attachment'));
    expect(tester.getCenter(attachment).dy, tester.getCenter(send).dy);
    expect(tester.getSize(attachment).height, AppLayout.touchTargetMin);
    expect(
      tester.getBottomRight(send).dx,
      greaterThan(tester.getBottomRight(attachment).dx),
    );
    expect(surfaceColor(tester), AppColors.primary);
    expect(tester.widget<IconButton>(send).onPressed, isNotNull);

    await tester.tap(send);
    await tester.pump();
    await pumpUntil(tester, () => model.requests.isNotEmpty);
    final user = assistant.transcript.whereType<UserMessage>().single;
    expect(user.content.whereType<TextBlock>().single.text, contains('笔记.txt'));
    expect(assistant.attachmentsFor(assistant.draftKey), isEmpty);
  });

  assistantTest('极窄宽度下思考与上下文换到上一行，发送仍在主行末端且中心同线', (tester) async {
    await mount(tester, ScriptedModel([]), width: 320, height: 700);

    final attachment = find.byKey(const Key('assistant-add-attachment'));
    final mic = find.byKey(const Key('assistant-composer-voice'));
    final reasoning = find.byKey(const Key('assistant-reasoning'));
    final context = find.byKey(const Key('assistant-context-usage'));

    // 320 宽：五个 48dp 槽加最小文字槽刚好放得下，仍是单行同线。
    expect(tester.getCenter(reasoning).dy, tester.getCenter(send).dy);
    expect(tester.getCenter(context).dy, tester.getCenter(send).dy);

    // 300 宽：实际可用宽度不足，次要工具换行，主行仍保留附件、麦克风与发送。
    tester.view.physicalSize = const Size(300, 700);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(tester.getCenter(attachment).dy, tester.getCenter(send).dy);
    expect(tester.getCenter(mic).dy, tester.getCenter(send).dy);
    expect(tester.getSize(attachment).height, AppLayout.touchTargetMin);
    expect(tester.getSize(mic).height, AppLayout.touchTargetMin);
    expect(tester.getCenter(reasoning).dy, tester.getCenter(context).dy);
    expect(
      tester.getCenter(reasoning).dy,
      lessThan(tester.getCenter(send).dy),
      reason: '次要工具应换到主行上方',
    );
    // 发送始终在主行末端：比换行的次要工具更靠右，且是主行最右的控件。
    expect(
      tester.getBottomRight(send).dx,
      greaterThan(tester.getBottomRight(reasoning).dx),
    );
    expect(
      tester.getBottomRight(send).dx,
      greaterThan(tester.getBottomRight(context).dx),
    );
    expect(
      tester.getBottomRight(mic).dx,
      lessThan(tester.getBottomRight(send).dx),
    );
    expect(
      tester.getSize(send),
      const Size(AppLayout.touchTargetMin, AppLayout.touchTargetMin),
    );
    expect(send.hitTestable(), findsOneWidget);

    // 键盘避让：底部被键盘占用时发送仍在可用区域内且能点中，不被裁掉。
    tester.view.viewInsets = const FakeViewPadding(bottom: 200);
    await tester.pumpAndSettle();
    expect(send.hitTestable(), findsOneWidget);
    expect(tester.getBottomRight(send).dy, lessThanOrEqualTo(500));
    expect(tester.takeException(), isNull);
  });

  assistantTest('发送按钮可键盘聚焦并用 Enter 激活，三态共用一个按钮语义节点', (tester) async {
    final model = ScriptedModel([(_) => textResponse('已发送')]);
    await mount(tester, model);
    await tester.enterText(input, '用键盘发送');
    await tester.pump();

    final focusNode = Focus.of(
      tester.element(find.descendant(of: send, matching: find.byType(Icon))),
    );
    expect(focusNode.canRequestFocus, isTrue);
    focusNode.requestFocus();
    await tester.pump();
    expect(focusNode.hasFocus, isTrue);

    final nodes = sendNodes(tester, '发送');
    expect(nodes, hasLength(1));
    expect(nodes.single.childrenCount, 0, reason: '三态只用一个按钮承载，不叠加语义节点');

    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    await pumpUntil(tester, () => model.requests.isNotEmpty);
    expect(assistant.transcript.whereType<UserMessage>().single.text, '用键盘发送');
  });
}

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mission_book/core/theme/app_layout.dart';
import 'package:mission_book/presentation/widgets/detail_pane.dart';

void main() {
  group('助手分屏控制器', () {
    test('初始按 50:50 计算，且只把助手会话识别为可调范围', () {
      final controller = DetailPaneController();
      addTearDown(controller.dispose);
      controller.entries.add(
        DetailPaneEntry(
          '助手会话',
          (_) => const SizedBox.shrink(),
          identity: assistantConversationPaneIdentity,
          maxWidth: AppLayout.assistantPaneMaxWidth,
        ),
      );

      expect(controller.isAssistantConversationActive, isTrue);
      expect(controller.assistantSplitRatio, 0.5);
      expect(controller.assistantWidthFor(1200), 600);

      controller.entries
        ..clear()
        ..add(DetailPaneEntry('普通任务详情', (_) => const SizedBox.shrink()));
      expect(controller.isAssistantConversationActive, isFalse);
      expect(controller.assistantWidthFor(1200), 600);
    });

    DetailPaneController assistantController() {
      final controller = DetailPaneController();
      controller.entries.add(
        DetailPaneEntry(
          '助手会话',
          (_) => const SizedBox.shrink(),
          identity: assistantConversationPaneIdentity,
          maxWidth: AppLayout.assistantPaneMaxWidth,
        ),
      );
      return controller;
    }

    test('拖动可实时改比例，最小栏宽受限，旋转宽度只重算显示值', () {
      final controller = assistantController();
      addTearDown(controller.dispose);
      controller.entries.add(
        DetailPaneEntry(
          '助手会话',
          (_) => const SizedBox.shrink(),
          identity: assistantConversationPaneIdentity,
          maxWidth: AppLayout.assistantPaneMaxWidth,
        ),
      );

      controller.beginAssistantResize(800);
      controller.updateAssistantResize(
        physicalDelta: -200,
        availableWidth: 1600,
        textDirection: TextDirection.ltr,
      );
      expect(controller.assistantWidthFor(1600), 1000);
      controller.endAssistantResize(availableWidth: 1600);
      expect(controller.assistantSplitRatio, closeTo(0.625, 0.001));
      expect(controller.assistantWidthFor(1200), 720);
    });

    test('接近任一边缘释放时吸附单栏，恢复保留上次比例', () {
      final controller = assistantController();
      addTearDown(controller.dispose);
      controller.entries.add(
        DetailPaneEntry(
          '助手会话',
          (_) => const SizedBox.shrink(),
          identity: assistantConversationPaneIdentity,
          maxWidth: AppLayout.assistantPaneMaxWidth,
        ),
      );

      controller.beginAssistantResize(600);
      controller.updateAssistantResize(
        physicalDelta: 520,
        availableWidth: 1200,
        textDirection: TextDirection.ltr,
      );
      controller.endAssistantResize(availableWidth: 1200);
      expect(controller.assistantPaneMode, AssistantPaneMode.workspaceExpanded);
      expect(controller.assistantWidthFor(1200), 0);

      controller.restoreAssistantSplit();
      expect(controller.assistantPaneMode, AssistantPaneMode.split);
      expect(controller.assistantSplitRatio, 0.5);

      controller.beginAssistantResize(600);
      controller.updateAssistantResize(
        physicalDelta: -520,
        availableWidth: 1200,
        textDirection: TextDirection.ltr,
      );
      controller.endAssistantResize(availableWidth: 1200);
      expect(controller.assistantPaneMode, AssistantPaneMode.assistantExpanded);
      expect(controller.assistantWidthFor(1200), 1200);
      controller.restoreAssistantSplit();
      expect(controller.assistantSplitRatio, 0.5);
    });

    test('RTL 下物理拖动按阅读方向镜像，且屏幕阅读器调整可恢复分屏', () {
      final controller = assistantController();
      addTearDown(controller.dispose);
      controller.entries.add(
        DetailPaneEntry(
          '助手会话',
          (_) => const SizedBox.shrink(),
          identity: assistantConversationPaneIdentity,
          maxWidth: AppLayout.assistantPaneMaxWidth,
        ),
      );

      controller.beginAssistantResize(700);
      controller.updateAssistantResize(
        physicalDelta: 200,
        availableWidth: 1400,
        textDirection: TextDirection.rtl,
      );
      expect(controller.assistantWidthFor(1400), 900);
      controller.endAssistantResize(availableWidth: 1400);
      controller.adjustAssistantSplit(widthDelta: 40, availableWidth: 1400);
      expect(controller.assistantWidthFor(1400), 920);
    });
  });

  testWidgets('助手分隔线支持拖动、键盘调节、边缘吸附与点击恢复', (tester) async {
    const width = 1400.0;
    final controller = DetailPaneController();
    addTearDown(controller.dispose);
    controller.entries.add(
      DetailPaneEntry(
        '助手会话',
        (_) => const SizedBox.shrink(),
        identity: assistantConversationPaneIdentity,
        maxWidth: AppLayout.assistantPaneMaxWidth,
      ),
    );
    tester.view.physicalSize = const Size(1500, 600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    Widget layout() => MaterialApp(
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: width,
            height: 400,
            child: AnimatedBuilder(
              animation: controller,
              builder: (context, _) {
                final assistantWidth = controller.assistantWidthFor(width);
                final mode = controller.assistantPaneMode;
                return Stack(
                  children: [
                    PositionedDirectional(
                      start: 0,
                      top: 0,
                      bottom: 0,
                      width: mode == AssistantPaneMode.assistantExpanded
                          ? 0
                          : mode == AssistantPaneMode.workspaceExpanded
                          ? width
                          : width - assistantWidth - AppLayout.paneGap,
                      child: const ColoredBox(color: Colors.transparent),
                    ),
                    PositionedDirectional(
                      end: 0,
                      top: 0,
                      bottom: 0,
                      width: assistantWidth,
                      child: const ColoredBox(color: Colors.transparent),
                    ),
                    if (mode == AssistantPaneMode.split)
                      PositionedDirectional(
                        end:
                            assistantWidth -
                            (AppLayout.touchTargetMin - AppLayout.paneGap) / 2,
                        top: 0,
                        bottom: 0,
                        width: AppLayout.touchTargetMin,
                        child: AssistantSplitHandle(
                          controller: controller,
                          availableWidth: width,
                          assistantWidth: assistantWidth,
                          textDirection: TextDirection.ltr,
                        ),
                      )
                    else
                      PositionedDirectional(
                        end: mode == AssistantPaneMode.workspaceExpanded
                            ? AppLayout.spaceLg
                            : null,
                        start: mode == AssistantPaneMode.assistantExpanded
                            ? AppLayout.spaceLg
                            : null,
                        top: 0,
                        bottom: 0,
                        width: AppLayout.touchTargetMin,
                        child: Center(
                          child: IconButton(
                            key: const Key('assistant-split-restore'),
                            tooltip: '恢复分屏',
                            onPressed: controller.restoreAssistantSplit,
                            icon: const Icon(Icons.splitscreen_rounded),
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );

    await tester.pumpWidget(layout());
    expect(controller.isAssistantConversationActive, isTrue);
    expect(controller.assistantWidthFor(width), 700);
    expect(find.byKey(const Key('assistant-split-handle')), findsOneWidget);

    await tester.drag(
      find.byKey(const Key('assistant-split-handle')),
      const Offset(-160, 0),
    );
    await tester.pumpAndSettle();
    expect(controller.assistantWidthFor(width), 860);
    final ratioBeforeCollapse = controller.assistantSplitRatio;

    await tester.drag(
      find.byKey(const Key('assistant-split-handle')),
      const Offset(900, 0),
    );
    await tester.pumpAndSettle();
    expect(controller.assistantPaneMode, AssistantPaneMode.workspaceExpanded);
    expect(find.byKey(const Key('assistant-split-restore')), findsOneWidget);
    await tester.tap(find.byKey(const Key('assistant-split-restore')));
    await tester.pumpAndSettle();
    expect(controller.assistantPaneMode, AssistantPaneMode.split);
    expect(controller.assistantSplitRatio, closeTo(ratioBeforeCollapse, 0.001));

    final handle = find.byKey(const Key('assistant-split-handle'));
    await tester.tap(handle);
    await tester.pumpAndSettle();
    final semantics = tester.getSemantics(handle).getSemanticsData();
    expect(semantics.label, '调整助手分屏');
    expect(semantics.flagsCollection.isSlider, isTrue);
    expect(semantics.hasAction(SemanticsAction.increase), isTrue);
    expect(semantics.hasAction(SemanticsAction.decrease), isTrue);
    expect(tester.takeException(), isNull);
  });
}

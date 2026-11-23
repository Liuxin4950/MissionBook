import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mission_book/core/theme/app_layout.dart';
import 'package:mission_book/presentation/widgets/detail_pane.dart';

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

AssistantSplitGeometry geometryAt(
  double windowWidth, {
  double? railWidth,
  AssistantPaneMode mode = AssistantPaneMode.split,
  double ratio = 0.5,
  double maxAssistantWidth = AppLayout.assistantPaneMaxWidth,
  double? previewWidth,
}) => resolveAssistantSplitGeometry(
  windowWidth: windowWidth,
  railWidth: railWidth ?? AppLayout.railWidthForWindow(windowWidth),
  mode: mode,
  ratio: ratio,
  maxAssistantWidth: maxAssistantWidth,
  previewWidth: previewWidth,
);

void main() {
  group('橱窗门常量与断点', () {
    test('并排时门槽总占 24、中间门轨 8；普通详情仍用 16 栏间距', () {
      expect(AppLayout.splitDoorWidth, 24);
      expect(AppLayout.splitDoorTrackWidth, 8);
      expect(AppLayout.paneGap, 16);
      expect(AppLayout.paneMinContentWidth, 856);
      expect(AppLayout.paneEdgeSnap, 96);
    });

    test('助手门槛 480+24+360=864，常规侧栏窗口最早 953 进入分屏', () {
      expect(AppLayout.assistantPaneMinContentWidth, 864);
      expect(AppLayout.canSplitAssistantPane(863.9), isFalse);
      expect(AppLayout.canSplitAssistantPane(864), isTrue);
      // 945–952 比旧实现（856 门槛）晚 8dp：仍单栏；953 起分屏。
      expect(AppLayout.railWidthForWindow(952), 89);
      expect(AppLayout.canShowAssistantDoorForWindow(952), isFalse);
      expect(AppLayout.canShowAssistantDoorForWindow(953), isTrue);
      // 手机不出现门。
      expect(AppLayout.canShowAssistantDoorForWindow(390), isFalse);
      expect(AppLayout.canShowAssistantDoorForWindow(768), isFalse);
    });

    test('1200 侧栏加宽后按新正文宽度重算，仍能分屏', () {
      expect(AppLayout.railWidthForWindow(1199), 89);
      expect(AppLayout.railWidthForWindow(1200), 193);
      expect(AppLayout.canShowAssistantDoorForWindow(1200), isTrue);
      final wide = geometryAt(1200);
      expect(wide.contentWidth, 1007);
      expect(wide.availableWidth, 983);
      expect(wide.assistantWidth, 491.5);
    });
  });

  group('助手分屏纯几何', () {
    test('默认 50:50，两栏与门槽拼满窗口', () {
      final split = geometryAt(1280);
      expect(split.contentWidth, 1087);
      expect(split.availableWidth, 1063);
      expect(split.assistantWidth, 531.5);
      expect(split.workspaceWidth, 1280 - 24 - 531.5);
      expect(
        split.workspaceWidth + AppLayout.splitDoorWidth + split.assistantWidth,
        1280,
      );
      expect(split.doorAtEnd, isTrue);
      expect(split.doorOffset, split.assistantWidth);
      expect(split.dragStartWidth, split.assistantWidth);
      expect(split.previewOverflow, 0);
    });

    test('按两侧最小与右栏上限夹取，不重写提交比例', () {
      final narrowest = geometryAt(953);
      expect(narrowest.availableWidth, 840);
      expect(narrowest.assistantWidth, 360);
      expect(narrowest.workspaceWidth, 953 - 24 - 360);

      final widest = geometryAt(2600, ratio: 0.8);
      expect(widest.assistantWidth, 1180);
      expect(widest.workspaceWidth, 2600 - 24 - 1180);

      // 普通详情右栏上限 640 也参与夹取。
      final detail = geometryAt(2000, maxAssistantWidth: 640);
      expect(detail.assistantWidth, 640);
    });

    test('拖动预览到达可读下限后槽留在夹取位置，超出的量单独报告', () {
      final pulledToNone = geometryAt(1280, previewWidth: 120);
      expect(pulledToNone.assistantWidth, 360);
      expect(pulledToNone.doorOffset, 360);
      expect(pulledToNone.previewOverflow, lessThan(0));
      expect(pulledToNone.previewOverflow, closeTo(120 - 360, 0.001));

      final pulledToAll = geometryAt(1280, previewWidth: 2000);
      expect(pulledToAll.assistantWidth, 1087 - 24 - 480);
      expect(pulledToAll.previewOverflow, greaterThan(0));
    });

    test('折叠态：助手隐藏贴末端、工作区隐藏贴起点，隐藏子树仍拿到合法宽度', () {
      final workspaceOnly = geometryAt(
        1280,
        mode: AssistantPaneMode.workspaceExpanded,
      );
      expect(workspaceOnly.workspaceWidth, 1280 - 24);
      expect(workspaceOnly.doorAtEnd, isTrue);
      expect(workspaceOnly.doorOffset, 0);
      expect(workspaceOnly.assistantWidth, 531.5);
      expect(workspaceOnly.dragStartWidth, 0);

      final assistantOnly = geometryAt(
        1280,
        mode: AssistantPaneMode.assistantExpanded,
      );
      expect(assistantOnly.assistantWidth, 1280 - 24);
      expect(assistantOnly.doorAtEnd, isFalse);
      expect(assistantOnly.doorOffset, 0);
      expect(assistantOnly.dragStartWidth, assistantOnly.availableWidth);
      expect(
        assistantOnly.workspaceWidth,
        1280 - 24 - assistantOnly.committedAssistantWidth,
      );
    });

    test('折叠态向内拉出时先按分屏几何预览，松手才提交模式', () {
      final pulled = geometryAt(
        1280,
        mode: AssistantPaneMode.workspaceExpanded,
        previewWidth: 600,
      );
      // 600 超过「工作区至少 480」的上限，预览已按夹取后的 583 摆放。
      expect(pulled.assistantWidth, 583);
      expect(pulled.doorOffset, 583);
      expect(pulled.dragStartWidth, 0);
      expect(pulled.mode, AssistantPaneMode.workspaceExpanded);
    });
  });

  group('助手分屏控制器', () {
    test('初始 50:50，只把助手会话识别为可调范围，默认可见栈顶', () {
      final controller = assistantController();
      addTearDown(controller.dispose);
      expect(controller.isAssistantConversationActive, isTrue);
      expect(controller.isAssistantConversationVisibleTop, isTrue);
      expect(controller.assistantSplitRatio, 0.5);
      expect(controller.assistantSlotWidthFor(1000), 500);

      controller.entries
        ..clear()
        ..add(DetailPaneEntry('普通任务详情', (_) => const SizedBox.shrink()));
      expect(controller.isAssistantConversationActive, isFalse);
      expect(controller.isAssistantConversationVisibleTop, isFalse);
      expect(controller.assistantSlotWidthFor(1000), 500);
    });

    test('拖动实时改预览，松手提交比例；取消保留上次提交比例', () {
      final controller = assistantController();
      addTearDown(controller.dispose);
      controller.beginAssistantResize(800);
      controller.updateAssistantResize(
        physicalDelta: -200,
        availableWidth: 1600,
        textDirection: TextDirection.ltr,
      );
      expect(controller.assistantSlotWidthFor(1600), 1000);
      expect(controller.assistantPreviewOverflowFor(1600), 0);
      expect(controller.assistantSplitRatio, 0.5);
      controller.endAssistantResize(availableWidth: 1600);
      expect(controller.assistantSplitRatio, closeTo(0.625, 0.0001));
      // 1200 宽时按同一比例重算，再被「工作区至少 480」的上限夹到 720。
      expect(controller.assistantSlotWidthFor(1200), 720);

      // 窗口宽度变化只重算显示值，不改写用户比例。
      expect(controller.assistantSplitRatio, closeTo(0.625, 0.0001));

      controller.beginAssistantResize(720);
      controller.updateAssistantResize(
        physicalDelta: 500,
        availableWidth: 1200,
        textDirection: TextDirection.ltr,
      );
      // 预览跨过可读下限：交互槽停在 360，超出量用边缘提示表达。
      expect(controller.assistantSlotWidthFor(1200), 360);
      expect(controller.assistantPreviewOverflowFor(1200), lessThan(0));
      controller.cancelAssistantResize();
      expect(controller.assistantSlotWidthFor(1200), 720);
      expect(controller.assistantSplitRatio, closeTo(0.625, 0.0001));
    });

    test('96dp 吸附区分别收向助手与工作区，恢复后保留比例', () {
      final controller = assistantController();
      addTearDown(controller.dispose);
      controller.beginAssistantResize(600);
      controller.updateAssistantResize(
        physicalDelta: 520,
        availableWidth: 1200,
        textDirection: TextDirection.ltr,
      );
      controller.endAssistantResize(availableWidth: 1200);
      expect(controller.assistantPaneMode, AssistantPaneMode.workspaceExpanded);
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
      controller.restoreAssistantSplit();
      expect(controller.assistantSplitRatio, 0.5);
    });

    test('RTL 下物理拖动按阅读方向镜像，键盘与读屏加减按 40dp', () {
      final controller = assistantController();
      addTearDown(controller.dispose);
      controller.beginAssistantResize(700);
      controller.updateAssistantResize(
        physicalDelta: 200,
        availableWidth: 1400,
        textDirection: TextDirection.rtl,
      );
      expect(controller.assistantSlotWidthFor(1400), 900);
      controller.endAssistantResize(availableWidth: 1400);
      // 助手栏上限 = min(1180, 可分配宽 - 480) = 920。
      controller.adjustAssistantSplit(widthDelta: 40, availableWidth: 1400);
      expect(controller.assistantSlotWidthFor(1400), 920);
      controller.adjustAssistantSplit(widthDelta: -80, availableWidth: 1400);
      expect(controller.assistantSlotWidthFor(1400), 840);
    });

    test('显式模式：Home/End 切单栏，恢复回到两栏并丢弃预览', () {
      final controller = assistantController();
      addTearDown(controller.dispose);
      controller.beginAssistantResize(500);
      controller.setAssistantPaneMode(AssistantPaneMode.workspaceExpanded);
      expect(controller.assistantPaneMode, AssistantPaneMode.workspaceExpanded);
      expect(controller.assistantPreviewWidth, isNull);
      expect(controller.assistantSplitRatio, 0.5);
      controller.setAssistantPaneMode(AssistantPaneMode.assistantExpanded);
      expect(controller.assistantPaneMode, AssistantPaneMode.assistantExpanded);
      controller.restoreAssistantSplit();
      expect(controller.assistantPaneMode, AssistantPaneMode.split);
    });
  });

  group('橱窗门控件', () {
    Widget harness(
      DetailPaneController controller, {
      double availableWidth = 1600,
      TextDirection direction = TextDirection.ltr,
    }) => MaterialApp(
      home: Directionality(
        textDirection: direction,
        child: Scaffold(
          body: AnimatedBuilder(
            animation: controller,
            builder: (context, _) => Row(
              children: [
                const Expanded(child: SizedBox.expand()),
                SizedBox(
                  width: AppLayout.splitDoorWidth,
                  height: double.infinity,
                  child: AssistantSplitDoor(
                    controller: controller,
                    availableWidth: availableWidth,
                    assistantWidth: controller.assistantSlotWidthFor(
                      availableWidth,
                    ),
                    textDirection: direction,
                  ),
                ),
                const Expanded(child: SizedBox.expand()),
              ],
            ),
          ),
        ),
      ),
    );

    testWidgets('整条 24dp 门槽都能起拖，门轨宽 8dp', (tester) async {
      final controller = assistantController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(harness(controller));
      await tester.pumpAndSettle();

      final door = find.byKey(const Key('assistant-split-door'));
      expect(tester.getSize(door), const Size(AppLayout.splitDoorWidth, 600));
      expect(
        tester
            .getSize(find.byKey(const Key('assistant-split-door-track')))
            .width,
        AppLayout.splitDoorTrackWidth,
      );

      // 10% / 50% / 90% 高度都能起拖，每次向左拖动都加宽助手。
      var previous = controller.assistantSplitRatio;
      for (final fraction in [0.1, 0.5, 0.9]) {
        final rect = tester.getRect(door);
        final gesture = await tester.startGesture(
          Offset(rect.center.dx, rect.top + rect.height * fraction),
        );
        await gesture.moveBy(const Offset(-80, 0));
        await tester.pump();
        await gesture.up();
        await tester.pumpAndSettle();
        expect(controller.assistantSplitRatio, greaterThan(previous));
        previous = controller.assistantSplitRatio;
      }
      expect(tester.takeException(), isNull);
    });

    testWidgets('方向键按 40dp 调整，Home/End 切单栏，Enter 恢复', (tester) async {
      final controller = assistantController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(harness(controller));
      await tester.pumpAndSettle();

      final door = find.byKey(const Key('assistant-split-door'));
      await tester.tap(door);
      await tester.pumpAndSettle();
      expect(controller.assistantSplitRatio, 0.5);

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pumpAndSettle();
      expect(controller.assistantSlotWidthFor(1600), 760);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pumpAndSettle();
      expect(controller.assistantSlotWidthFor(1600), 840);

      await tester.sendKeyEvent(LogicalKeyboardKey.home);
      await tester.pumpAndSettle();
      expect(controller.assistantPaneMode, AssistantPaneMode.workspaceExpanded);
      expect(
        find.byKey(const Key('assistant-split-door-grip')),
        findsOneWidget,
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.end);
      await tester.pumpAndSettle();
      expect(controller.assistantPaneMode, AssistantPaneMode.assistantExpanded);

      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(controller.assistantPaneMode, AssistantPaneMode.split);
      // 恢复保留上次比例：840/1600。
      expect(controller.assistantSlotWidthFor(1600), 840);
      expect(tester.takeException(), isNull);
    });

    testWidgets('读屏提供比例与增减、单栏同名动作，折叠态是按钮', (tester) async {
      final controller = assistantController();
      addTearDown(controller.dispose);
      final semantics = tester.ensureSemantics();
      try {
        await tester.pumpWidget(harness(controller));
        await tester.pumpAndSettle();
        final node = find.byKey(const Key('assistant-split-door-semantics'));
        var data = tester.getSemantics(node).getSemanticsData();
        expect(data.label, '调整助手分屏');
        expect(data.value, '助手栏 50%');
        expect(data.flagsCollection.isSlider, isTrue);
        expect(data.hasAction(SemanticsAction.increase), isTrue);
        expect(data.hasAction(SemanticsAction.decrease), isTrue);
        expect(
          data.customSemanticsActionIds?.length ?? 0,
          greaterThanOrEqualTo(2),
        );

        controller.setAssistantPaneMode(AssistantPaneMode.workspaceExpanded);
        await tester.pumpAndSettle();
        data = tester.getSemantics(node).getSemanticsData();
        expect(data.label, '恢复助手分屏');
        expect(data.flagsCollection.isButton, isTrue);
        expect(data.hasAction(SemanticsAction.tap), isTrue);
      } finally {
        semantics.dispose();
      }
    });

    testWidgets('预览超出可读下限时只画不接收命中的边缘提示', (tester) async {
      final controller = assistantController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(harness(controller));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('assistant-split-door-edge-hint')),
        findsNothing,
      );

      controller.beginAssistantResize(800);
      controller.updateAssistantResize(
        physicalDelta: 700,
        availableWidth: 1600,
        textDirection: TextDirection.ltr,
      );
      await tester.pump();
      final hint = find.byKey(const Key('assistant-split-door-edge-hint'));
      expect(hint, findsOneWidget);
      expect(
        find.ancestor(of: hint, matching: find.byType(IgnorePointer)),
        findsWidgets,
      );
      expect(
        find.ancestor(of: hint, matching: find.byType(ExcludeSemantics)),
        findsOneWidget,
      );
      // 交互槽留在可读下限，提示不改变命中区域。
      expect(controller.assistantSlotWidthFor(1600), 360);
      controller.cancelAssistantResize();
      await tester.pumpAndSettle();
      expect(hint, findsNothing);
      expect(tester.takeException(), isNull);
    });
  });
}

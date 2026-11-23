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

PaneSplitGeometry geometryAt(
  double windowWidth, {
  double? railWidth,
  double ratio = 0.5,
  double maxPaneWidth = AppLayout.assistantPaneMaxWidth,
  double? previewWidth,
}) => resolvePaneSplitGeometry(
  windowWidth: windowWidth,
  railWidth: railWidth ?? AppLayout.railWidthForWindow(windowWidth),
  ratio: ratio,
  maxPaneWidth: maxPaneWidth,
  previewWidth: previewWidth,
);

void main() {
  group('橱窗门常量与断点', () {
    test('统一分页门槽总占 24、中间门轨 8，最小正文宽为 864', () {
      expect(AppLayout.splitDoorWidth, 24);
      expect(AppLayout.splitDoorTrackWidth, 8);
      expect(AppLayout.paneGap, 24);
      expect(AppLayout.paneMinContentWidth, 864);
    });

    test('助手门槛 480+24+360=864，常规侧栏窗口最早 953 进入分屏', () {
      expect(AppLayout.paneMinContentWidth, 864);
      expect(AppLayout.canSplitPane(863.9), isFalse);
      expect(AppLayout.canSplitPane(864), isTrue);
      // 945–952 比旧实现（856 门槛）晚 8dp：仍单栏；953 起分屏。
      expect(AppLayout.railWidthForWindow(952), 89);
      expect(AppLayout.canShowSplitPaneForWindow(952), isFalse);
      expect(AppLayout.canShowSplitPaneForWindow(953), isTrue);
      // 手机不出现门。
      expect(AppLayout.canShowSplitPaneForWindow(390), isFalse);
      expect(AppLayout.canShowSplitPaneForWindow(768), isFalse);
    });

    test('1200 侧栏加宽后按新正文宽度重算，仍能分屏', () {
      expect(AppLayout.railWidthForWindow(1199), 89);
      expect(AppLayout.railWidthForWindow(1200), 193);
      expect(AppLayout.canShowSplitPaneForWindow(1200), isTrue);
      final wide = geometryAt(1200);
      expect(wide.contentWidth, 1007);
      expect(wide.availableWidth, 983);
      expect(wide.rightPaneWidth, 491.5);
    });
  });

  group('助手分屏纯几何', () {
    test('默认 50:50，两栏与门槽拼满窗口', () {
      final split = geometryAt(1280);
      expect(split.contentWidth, 1087);
      expect(split.availableWidth, 1063);
      expect(split.rightPaneWidth, 531.5);
      expect(split.workspaceWidth, 1280 - 24 - 531.5);
      expect(
        split.workspaceWidth + AppLayout.splitDoorWidth + split.rightPaneWidth,
        1280,
      );
      expect(split.doorOffset, split.rightPaneWidth);
      expect(split.dragStartWidth, split.rightPaneWidth);
      expect(split.previewOverflow, 0);
    });

    test('按两侧最小与右栏上限夹取，不重写提交比例', () {
      final narrowest = geometryAt(953);
      expect(narrowest.availableWidth, 840);
      expect(narrowest.rightPaneWidth, 360);
      expect(narrowest.workspaceWidth, 953 - 24 - 360);

      final widest = geometryAt(2600, ratio: 0.8);
      expect(widest.rightPaneWidth, 1180);
      expect(widest.workspaceWidth, 2600 - 24 - 1180);

      // 普通详情右栏上限 640 也参与夹取。
      final detail = geometryAt(2000, maxPaneWidth: 640);
      expect(detail.rightPaneWidth, 640);
    });

    test('拖动预览到达可读下限后槽留在夹取位置，超出的量单独报告', () {
      final pulledToNone = geometryAt(1280, previewWidth: 120);
      expect(pulledToNone.rightPaneWidth, 360);
      expect(pulledToNone.doorOffset, 360);
      expect(pulledToNone.previewOverflow, lessThan(0));
      expect(pulledToNone.previewOverflow, closeTo(120 - 360, 0.001));

      final pulledToAll = geometryAt(1280, previewWidth: 2000);
      expect(pulledToAll.rightPaneWidth, 1087 - 24 - 480);
      expect(pulledToAll.previewOverflow, greaterThan(0));
    });
  });

  group('助手分屏控制器', () {
    test('初始 50:50，只把助手会话识别为可调范围，默认可见栈顶', () {
      final controller = assistantController();
      addTearDown(controller.dispose);
      expect(controller.isAssistantConversationActive, isTrue);
      expect(controller.isAssistantConversationVisibleTop, isTrue);
      expect(controller.paneSplitRatio, 0.5);
      expect(controller.paneWidthFor(1000), 500);

      controller.entries
        ..clear()
        ..add(DetailPaneEntry('普通任务详情', (_) => const SizedBox.shrink()));
      expect(controller.isAssistantConversationActive, isFalse);
      expect(controller.isAssistantConversationVisibleTop, isFalse);
      expect(controller.paneWidthFor(1000), 500);
    });

    test('拖动实时改预览，松手提交比例；取消保留上次提交比例', () {
      final controller = assistantController();
      addTearDown(controller.dispose);
      controller.beginPaneResize(800);
      controller.updatePaneResize(
        physicalDelta: -200,
        availableWidth: 1600,
        textDirection: TextDirection.ltr,
      );
      expect(controller.paneWidthFor(1600), 1000);
      expect(controller.panePreviewOverflowFor(1600), 0);
      expect(controller.paneSplitRatio, 0.5);
      controller.endPaneResize(availableWidth: 1600);
      expect(controller.paneSplitRatio, closeTo(0.625, 0.0001));
      // 1200 宽时按同一比例重算，再被「工作区至少 480」的上限夹到 720。
      expect(controller.paneWidthFor(1200), 720);

      // 窗口宽度变化只重算显示值，不改写用户比例。
      expect(controller.paneSplitRatio, closeTo(0.625, 0.0001));

      controller.beginPaneResize(720);
      controller.updatePaneResize(
        physicalDelta: 500,
        availableWidth: 1200,
        textDirection: TextDirection.ltr,
      );
      // 预览跨过可读下限：交互槽停在 360，超出量用边缘提示表达。
      expect(controller.paneWidthFor(1200), 360);
      expect(controller.panePreviewOverflowFor(1200), lessThan(0));
      controller.cancelPaneResize();
      expect(controller.paneWidthFor(1200), 720);
      expect(controller.paneSplitRatio, closeTo(0.625, 0.0001));
    });

    test('拖动到可读边界只夹取栏宽，不吸附为单栏', () {
      final controller = assistantController();
      addTearDown(controller.dispose);
      controller.beginPaneResize(600);
      controller.updatePaneResize(
        physicalDelta: 520,
        availableWidth: 1200,
        textDirection: TextDirection.ltr,
      );
      controller.endPaneResize(availableWidth: 1200);
      expect(controller.paneDisplayMode, PaneDisplayMode.split);
      expect(controller.paneWidthFor(1200), 360);

      controller.beginPaneResize(600);
      controller.updatePaneResize(
        physicalDelta: -520,
        availableWidth: 1200,
        textDirection: TextDirection.ltr,
      );
      controller.endPaneResize(availableWidth: 1200);
      expect(controller.paneDisplayMode, PaneDisplayMode.split);
      expect(controller.paneWidthFor(1200), 720);
    });

    test('RTL 下物理拖动按阅读方向镜像，键盘与读屏加减按 40dp', () {
      final controller = assistantController();
      addTearDown(controller.dispose);
      controller.beginPaneResize(700);
      controller.updatePaneResize(
        physicalDelta: 200,
        availableWidth: 1400,
        textDirection: TextDirection.rtl,
      );
      expect(controller.paneWidthFor(1400), 900);
      controller.endPaneResize(availableWidth: 1400);
      // 助手栏上限 = min(1180, 可分配宽 - 480) = 920。
      controller.adjustPaneWidth(widthDelta: 40, availableWidth: 1400);
      expect(controller.paneWidthFor(1400), 920);
      controller.adjustPaneWidth(widthDelta: -80, availableWidth: 1400);
      expect(controller.paneWidthFor(1400), 840);
    });

    test('显式模式：切换全屏，恢复回到两栏并丢弃预览', () {
      final controller = assistantController();
      addTearDown(controller.dispose);
      controller.beginPaneResize(500);
      controller.togglePaneFullScreen();
      expect(controller.isPaneFullScreen, isTrue);
      expect(controller.panePreviewWidth, isNull);
      expect(controller.paneSplitRatio, 0.5);
      controller.restorePaneSplit();
      expect(controller.paneDisplayMode, PaneDisplayMode.split);
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
                  child: PaneSplitDoor(
                    controller: controller,
                    availableWidth: availableWidth,
                    rightPaneWidth: controller.paneWidthFor(availableWidth),
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

      final door = find.byKey(const Key('pane-split-door'));
      expect(tester.getSize(door), const Size(AppLayout.splitDoorWidth, 600));
      expect(
        tester.getSize(find.byKey(const Key('pane-split-door-track'))).width,
        AppLayout.splitDoorTrackWidth,
      );

      // 10% / 50% / 90% 高度都能起拖，每次向左拖动都加宽助手。
      var previous = controller.paneSplitRatio;
      for (final fraction in [0.1, 0.5, 0.9]) {
        final rect = tester.getRect(door);
        final gesture = await tester.startGesture(
          Offset(rect.center.dx, rect.top + rect.height * fraction),
        );
        await gesture.moveBy(const Offset(-80, 0));
        await tester.pump();
        await gesture.up();
        await tester.pumpAndSettle();
        expect(controller.paneSplitRatio, greaterThan(previous));
        previous = controller.paneSplitRatio;
      }
      expect(tester.takeException(), isNull);
    });

    testWidgets('点击后 Enter 显式还原分栏', (tester) async {
      final controller = assistantController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(harness(controller));
      await tester.pumpAndSettle();

      final door = find.byKey(const Key('pane-split-door'));
      await tester.tap(door);
      await tester.pumpAndSettle();
      expect(controller.isPaneFullScreen, isTrue);

      await tester.tap(door);
      await tester.pumpAndSettle();
      expect(controller.isPaneFullScreen, isFalse);
      await tester.tap(door);
      await tester.pumpAndSettle();
      expect(controller.isPaneFullScreen, isTrue);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(controller.isPaneFullScreen, isFalse);
      expect(tester.takeException(), isNull);
    });

    testWidgets('读屏提供比例与增减、单栏同名动作，折叠态是按钮', (tester) async {
      final controller = assistantController();
      addTearDown(controller.dispose);
      final semantics = tester.ensureSemantics();
      try {
        await tester.pumpWidget(harness(controller));
        await tester.pumpAndSettle();
        final node = find.byKey(const Key('pane-split-door-semantics'));
        var data = tester.getSemantics(node).getSemanticsData();
        expect(data.label, '调整分页宽度');
        expect(data.value, '右侧页面占宽 50%');
        expect(data.flagsCollection.isSlider, isTrue);
        expect(data.hasAction(SemanticsAction.increase), isTrue);
        expect(data.hasAction(SemanticsAction.decrease), isTrue);
        expect(
          data.customSemanticsActionIds?.length ?? 0,
          greaterThanOrEqualTo(1),
        );

        controller.togglePaneFullScreen();
        await tester.pumpAndSettle();
        data = tester.getSemantics(node).getSemanticsData();
        expect(data.label, '恢复并排分页');
        expect(data.flagsCollection.isButton, isTrue);
        expect(data.hasAction(SemanticsAction.tap), isTrue);
      } finally {
        semantics.dispose();
      }
    });

    testWidgets('预览超出可读下限时只夹取交互槽，不显示边缘吸附提示', (tester) async {
      final controller = assistantController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(harness(controller));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('pane-split-door-edge-hint')), findsNothing);

      controller.beginPaneResize(800);
      controller.updatePaneResize(
        physicalDelta: 700,
        availableWidth: 1600,
        textDirection: TextDirection.ltr,
      );
      await tester.pump();
      // 交互槽留在可读下限，不再绘制边缘吸附提示。
      expect(find.byKey(const Key('pane-split-door-edge-hint')), findsNothing);
      expect(controller.paneWidthFor(1600), 360);
      controller.cancelPaneResize();
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('pane-split-door-edge-hint')), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });
}

import 'package:flutter/material.dart';

/// 窗口宽度分档：只决定导航形态与弹层样式。
/// 是否双栏与表单是否两列由内容区/面板自身宽度决定，不与档位绑死。
enum WindowClass {
  /// 手机形态：底部胶囊导航、单列、底部弹层。
  compact,

  /// 平板竖屏/小窗：侧栏导航、单列居中、弹层居中对话框。
  medium,

  /// 平板横屏/桌面：侧栏导航；内容区够宽时启用双栏。
  expanded,
}

/// 全局窗口分档、内容区宽度约束和响应式布局规则。
abstract final class AppLayout {
  static const maxPageWidth = 792.0; // 详情与阅读表面的限宽。
  static const dashboardMaxWidth = 1920.0;
  static const assistantPaneMaxWidth = 1180.0;
  static const formMaxWidth = 1080.0;
  static const dashboardSplitWidth = 840.0; // 已扣除侧栏和页面边距。

  // 断点（语义化常量）：compact < mediumBreakpoint ≤ medium < expandedBreakpoint。
  static const mediumBreakpoint = 600.0;
  static const expandedBreakpoint = 840.0;
  static const extendedRailBreakpoint = 1200.0; // 平板优先把空间留给正文。

  static bool useExtendedRail(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= extendedRailBreakpoint;

  // 统一分页宽度：工作区最小宽 + 分隔槽 + 右栏最小宽。
  // 只有内容区凑齐三者才并排，否则右栏占满窗口。
  static const paneLeftMin = 480.0;
  static const paneGap = 24.0;
  static const paneRightMin = 360.0;
  static const paneMinContentWidth = paneLeftMin + paneGap + paneRightMin;

  // 分隔槽总占宽 24，中间 8 宽门轨；详情与助手共用相同几何。
  static const splitDoorWidth = paneGap;
  static const splitDoorTrackWidth = 8.0;

  // 侧栏实际占位（含 1dp 边线）：常规 88+1、扩展 192+1。
  // 外壳与助手顶栏共用同一换算，窗口宽度决定助手分屏是否可用。
  static const railWidthCompact = 89.0;
  static const railWidthExtended = 193.0;

  static double railWidthForWindow(double windowWidth) =>
      windowWidth >= extendedRailBreakpoint
      ? railWidthExtended
      : railWidthCompact;

  /// 按窗口宽度推断是否能显示共用分页门；手机宽度恒为 false。
  static bool canShowSplitPaneForWindow(double windowWidth) =>
      canSplitPane(windowWidth - railWidthForWindow(windowWidth));

  // 表单字段并排成两列所需的面板宽度；表单在哪个面板就按哪个面板的宽度判定。
  static const formTwoColumnMinWidth = 560.0;

  // 右栏/对话框弹层的阅读限宽。
  static const detailPaneMaxWidth = 640.0;

  // 助手在宽屏右栏中容纳会话侧栏和正文；宽度不足时页面自行收起侧栏。
  static const assistantSidebarBreakpoint = 1000.0;

  static WindowClass windowClassOf(BuildContext context) =>
      windowClassForWidth(MediaQuery.sizeOf(context).width);

  /// 纯函数分档：布局测试直接按宽度断言，不必构造 BuildContext。
  static WindowClass windowClassForWidth(double width) {
    if (width < mediumBreakpoint) return WindowClass.compact;
    if (width < expandedBreakpoint) return WindowClass.medium;
    return WindowClass.expanded;
  }

  /// 内容区（已扣除侧栏）能否容纳左右两栏的最小宽度。
  static bool canSplitPane(double contentWidth) =>
      contentWidth >= paneMinContentWidth;

  static double horizontalPadding(BuildContext context) =>
      MediaQuery.sizeOf(context).width < 360 ? 16 : 24;

  static EdgeInsets pagePadding(BuildContext context) =>
      EdgeInsets.all(horizontalPadding(context));
}

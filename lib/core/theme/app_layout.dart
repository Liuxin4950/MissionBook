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

/// 全站页面共用阅读宽度和留白，窄屏按实际可用宽度计算。
abstract final class AppLayout {
  static const maxPageWidth = 792.0;
  static const sectionGap = 24.0;

  // 断点（语义化常量）：compact < mediumBreakpoint ≤ medium < expandedBreakpoint。
  static const mediumBreakpoint = 600.0;
  static const expandedBreakpoint = 840.0;

  // 双栏三要素：左栏最小宽 + 栏间距 + 右栏最小宽。
  // 只有内容区宽度凑齐三者才分栏，否则自动落回单列（宽窗口也可能因侧栏落回）。
  static const paneLeftMin = 480.0;
  static const paneGap = 24.0;
  static const paneRightMin = 360.0;
  static const paneMinContentWidth = paneLeftMin + paneGap + paneRightMin;

  // 表单字段并排成两列所需的面板宽度；表单在哪个面板就按哪个面板的宽度判定。
  static const formTwoColumnMinWidth = 560.0;

  // 右栏/对话框弹层的阅读限宽。
  static const detailPaneMaxWidth = 640.0;

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

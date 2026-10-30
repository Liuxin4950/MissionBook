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
  static const maxPageWidth = 792.0; // 详情与阅读表面的限宽。
  static const dashboardMaxWidth = 1440.0;
  static const formMaxWidth = 1080.0;
  static const dashboardSplitWidth = 840.0; // 已扣除侧栏和页面边距。

  static const sectionGap = spaceXxl;

  // 断点（语义化常量）：compact < mediumBreakpoint ≤ medium < expandedBreakpoint。
  static const mediumBreakpoint = 600.0;
  static const expandedBreakpoint = 840.0;
  static const extendedRailBreakpoint = 1200.0; // 平板优先把空间留给正文。

  static bool useExtendedRail(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= extendedRailBreakpoint;

  // 双栏三要素：左栏最小宽 + 栏间距 + 右栏最小宽。
  // 只有内容区宽度凑齐三者才分栏，否则自动落回单列（宽窗口也可能因侧栏落回）。
  static const paneLeftMin = 480.0;
  static const paneGap = 24.0;
  static const paneRightMin = 360.0;
  static const paneMinContentWidth = paneLeftMin + paneGap + paneRightMin;

  // 形状 token：按用途分层，页面不再直接写圆角数字。
  static const radiusXs = 4.0; // 进度端点、微型装饰。
  static const radiusSm = 8.0; // 标签、内部小块。
  static const radiusMd = 12.0; // 输入框、代码块、小图标底。
  static const radiusLg = 16.0; // 按钮、分段选中、聊天气泡。
  static const radiusXl = 20.0; // 内容卡、操作卡。
  static const radiusXxl = 24.0; // 品牌卡、确认框、底部弹层。
  static const radiusPill = 999.0; // 胶囊，视觉上与 StadiumBorder 等价。

  // 间距 token：4 的倍数；页面局部微调仍可保留，但新结构优先使用这组。
  static const spaceXs = 4.0;
  static const spaceSm = 8.0;
  static const spaceMd = 12.0;
  static const spaceLg = 16.0;
  static const spaceXl = 20.0;
  static const spaceXxl = 24.0;
  static const space3Xl = 32.0;

  /// 最小触控高度，沿用项目 48dp 约定。
  static const touchTargetMin = 48.0;

  // 主操作与顶栏高度；页面不得再用裸 52/64 表示同类尺寸。
  static const actionMinHeight = 52.0;
  static const topBarHeight = 64.0;

  // 描边和阴影 token：1px 常规分隔，1.5px 聚焦/选中；阴影保持轻量。
  static const strokeThin = 1.0;
  static const strokeFocus = 1.5;
  static const shadowBlur = 24.0;
  static const shadowOffsetY = 4.0;

  // 图标 token：行内 18、常规 20、导航/操作 24、大图标 40。
  // 品牌标识、头像等图形尺寸属于组件自身，不强行套用图标 token。
  static const iconSm = 18.0;
  static const iconMd = 20.0;
  static const iconLg = 24.0;
  static const iconXl = 40.0;
  static const iconDisplay = 32.0; // 空态/引导区的装饰图标。

  /// 执行页圆环到主按钮的最小呼吸空间；小于该值会挤压触控操作。
  static const executionRingGap = 40.0;

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

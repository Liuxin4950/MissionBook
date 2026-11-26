/// 主题和组件共用的视觉尺寸。
abstract final class AppMetrics {
  static const sectionGap = spaceLg;

  // 形状 token：按用途分层，页面不再直接写圆角数字。
  static const radiusXxs = 2.0; // 细条端点等极小装饰。
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
}

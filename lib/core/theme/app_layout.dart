import 'package:flutter/material.dart';

/// 三个任务页面共用阅读宽度和留白，窄屏按实际可用宽度计算。
abstract final class AppLayout {
  static const maxPageWidth = 792.0;
  static const sectionGap = 24.0;
  static double horizontalPadding(BuildContext context) =>
      MediaQuery.sizeOf(context).width < 360 ? 16 : 24;

  static EdgeInsets pagePadding(BuildContext context) =>
      EdgeInsets.all(horizontalPadding(context));
}

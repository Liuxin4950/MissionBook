import 'package:flutter/material.dart';

/// 全站动效节奏：时长、曲线和减少动效处理集中在这里。
///
/// 页面只选择语义时长，不再各自写毫秒数；系统要求减少动效时统一归零。
abstract final class AppMotion {
  /// 轻量反馈和展开，如分类切换、列表展开箭头。
  static const quick = Duration(milliseconds: 180);

  /// 常规状态过渡，如高度、底色和计划进度。
  static const standard = Duration(milliseconds: 240);

  /// 空态插画首次进入。
  static const entrance = Duration(milliseconds: 420);

  /// 品牌启动页到主界面的过渡。
  static const launch = Duration(milliseconds: 450);

  /// 手册定义的统一缓动曲线。
  static const curve = Cubic(0.22, 0.8, 0.24, 1);

  /// 读取当前系统设置；减少动效时返回零时长，调用方无需重复判断。
  static Duration resolve(BuildContext context, Duration duration) =>
      (MediaQuery.maybeOf(context)?.disableAnimations ?? false)
      ? Duration.zero
      : duration;
}

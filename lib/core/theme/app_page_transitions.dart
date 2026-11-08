import 'package:flutter/material.dart';

import '../../application/settings/motion_settings.dart';
import 'app_motion.dart';

/// 页面风格统一作用于普通路由和详情栏内的 MaterialPageRoute。
class AppPageTransitionsBuilder extends PageTransitionsBuilder {
  const AppPageTransitionsBuilder({
    required this.platformBuilder,
    required this.style,
    required this.reduced,
  });

  final PageTransitionsBuilder platformBuilder;
  final PageMotionStyle style;
  final bool reduced;

  @override
  Duration get transitionDuration => reduced
      ? Duration.zero
      : style == PageMotionStyle.platform
      ? platformBuilder.transitionDuration
      : AppMotion.navigation;

  @override
  Duration get reverseTransitionDuration => reduced
      ? Duration.zero
      : style == PageMotionStyle.platform
      ? platformBuilder.reverseTransitionDuration
      : AppMotion.exit;

  @override
  DelegatedTransitionBuilder? get delegatedTransition =>
      !reduced && style == PageMotionStyle.platform
      ? platformBuilder.delegatedTransition
      : null;

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    if (reduced) return child;
    if (style == PageMotionStyle.platform) {
      return platformBuilder.buildTransitions(
        route,
        context,
        animation,
        secondaryAnimation,
        child,
      );
    }
    // 平台组件继续持有返回手势检测器。普通导航由应用风格绘制，
    // 交互返回期间把真实进度交给平台，保留预览、取消与完成返回。
    return platformBuilder.buildTransitions(
      route,
      context,
      _GestureAnimation(animation, route: route, restingValue: 1),
      _GestureAnimation(secondaryAnimation, route: route, restingValue: 0),
      AnimatedBuilder(
        animation: animation,
        child: child,
        builder: (context, child) {
          if (route.popGestureInProgress) return child!;
          final progress = animation.drive(CurveTween(curve: AppMotion.curve));
          return FadeTransition(
            opacity: progress,
            child: style == PageMotionStyle.slide
                ? SlideTransition(
                    position: progress.drive(
                      Tween(
                        begin: Offset(
                          Directionality.of(context) == TextDirection.rtl
                              ? -.06
                              : .06,
                          0,
                        ),
                        end: Offset.zero,
                      ),
                    ),
                    child: child,
                  )
                : child,
          );
        },
      ),
    );
  }
}

/// 保留动画通知，只在平台交互返回时暴露实际的路由进度。
class _GestureAnimation extends Animation<double>
    with AnimationWithParentMixin<double> {
  _GestureAnimation(
    this.parent, {
    required this.route,
    required this.restingValue,
  });
  @override
  final Animation<double> parent;
  final PageRoute<dynamic> route;
  final double restingValue;

  @override
  double get value => route.popGestureInProgress ? parent.value : restingValue;
}

import 'package:flutter/material.dart';

import '../../application/settings/motion_settings.dart';
import 'app_motion.dart';

/// 路由、主导航和预览共用的转场绘制；切换风格时保留内容子树。
class AppPageMotion extends StatelessWidget {
  const AppPageMotion({
    super.key,
    required this.style,
    required this.animation,
    required this.child,
    this.secondaryAnimation = const AlwaysStoppedAnimation(0),
    this.horizontalDirection = 1,
  });

  final PageMotionStyle style;
  final Animation<double> animation;
  final Animation<double> secondaryAnimation;
  final double horizontalDirection;
  final Widget child;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: Listenable.merge([animation, secondaryAnimation]),
    child: child,
    builder: (context, child) {
      final entering = AppMotion.curve.transform(animation.value.clamp(0, 1));
      final leaving = AppMotion.curve.transform(
        secondaryAnimation.value.clamp(0, 1),
      );
      final throughIn = const Interval(
        .3,
        1,
        curve: AppMotion.curve,
      ).transform(animation.value.clamp(0, 1));
      final throughOut = const Interval(
        0,
        .3,
        curve: Curves.easeOut,
      ).transform(secondaryAnimation.value.clamp(0, 1));
      final (offset, scale, opacity) = switch (style) {
        PageMotionStyle.platform ||
        PageMotionStyle.fade => (Offset.zero, 1.0, entering),
        PageMotionStyle.slide => (
          Offset(.06 * (1 - entering) * horizontalDirection, 0),
          1.0,
          entering,
        ),
        PageMotionStyle.zoom => (Offset.zero, .94 + .06 * entering, entering),
        PageMotionStyle.lift => (
          Offset(0, .08 * (1 - entering)),
          1.0,
          entering,
        ),
        PageMotionStyle.push => (
          Offset((1 - entering - .25 * leaving) * horizontalDirection, 0),
          1.0,
          1.0,
        ),
        PageMotionStyle.fadeThrough => (
          Offset.zero,
          .96 + .04 * throughIn,
          throughIn * (1 - throughOut),
        ),
      };
      return FractionalTranslation(
        translation: offset,
        child: Transform.scale(
          scale: scale,
          child: Opacity(opacity: opacity, child: child),
        ),
      );
    },
  );
}

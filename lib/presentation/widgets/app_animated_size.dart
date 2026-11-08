import 'package:flutter/material.dart';

import '../../core/theme/app_motion.dart';

/// 减少动效时直接布局，切换策略时用同一子树保留输入和组件状态。
class AppAnimatedSize extends StatefulWidget {
  const AppAnimatedSize({
    super.key,
    required this.child,
    this.duration = AppMotion.standard,
    this.alignment = Alignment.topCenter,
    this.curve = AppMotion.curve,
  });
  final Widget child;
  final Duration duration;
  final AlignmentGeometry alignment;
  final Curve curve;

  @override
  State<AppAnimatedSize> createState() => _AppAnimatedSizeState();
}

class _AppAnimatedSizeState extends State<AppAnimatedSize> {
  final _content = GlobalKey();

  @override
  Widget build(BuildContext context) {
    final child = KeyedSubtree(key: _content, child: widget.child);
    final duration = AppMotion.resolve(context, widget.duration);
    if (duration == Duration.zero) return child;
    return AnimatedSize(
      duration: duration,
      alignment: widget.alignment,
      curve: widget.curve,
      child: child,
    );
  }
}

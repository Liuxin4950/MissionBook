import 'package:flutter/material.dart';

import '../../application/settings/motion_settings.dart';
import '../../core/theme/app_motion.dart';
import 'app_page_motion.dart';
import 'motion_settings_scope.dart';

/// 内容身份变化时短暂进入，保留子树 State；连续切换以最后一次内容为准。
class AppContentTransition extends StatefulWidget {
  const AppContentTransition({
    super.key,
    required this.identity,
    required this.child,
  });
  final Object identity;
  final Widget child;

  @override
  State<AppContentTransition> createState() => _AppContentTransitionState();
}

class _AppContentTransitionState extends State<AppContentTransition>
    with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(vsync: this, value: 1);
  double _direction = 1;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _controller.duration = AppMotion.resolve(context, AppMotion.standard);
    if (_controller.duration == Duration.zero) _controller.value = 1;
  }

  @override
  void didUpdateWidget(covariant AppContentTransition oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.identity != widget.identity &&
        _controller.duration != Duration.zero) {
      if ((oldWidget.identity, widget.identity) case (int before, int after)) {
        _direction = after < before ? -1 : 1;
      }
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ClipRect(
    child: AppPageMotion(
      style:
          MotionSettingsScope.maybeOf(context)?.settings.pageStyle ??
          PageMotionStyle.fade,
      animation: _controller,
      horizontalDirection:
          _direction *
          (Directionality.of(context) == TextDirection.rtl ? -1 : 1),
      child: widget.child,
    ),
  );
}

import 'package:flutter/material.dart';

/// 空态插画在首次可见时轻轻进入；不循环，也不代表正在保存或执行。
class AppIllustration extends StatefulWidget {
  const AppIllustration({
    super.key,
    required this.asset,
    required this.width,
    required this.height,
  });

  final String asset;
  final double width;
  final double height;

  @override
  State<AppIllustration> createState() => _AppIllustrationState();
}

class _AppIllustrationState extends State<AppIllustration>
    with SingleTickerProviderStateMixin {
  late final _entrance = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 420),
  );
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _started = true;
      _entrance.value = 1; // 系统要求减少动态效果时，直接展示最终状态。
    } else if (!_started && TickerMode.valuesOf(context).enabled) {
      _started = true;
      _entrance.forward(); // IndexedStack 中隐藏的页面不提前播放入场。
    }
  }

  @override
  void dispose() {
    _entrance.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _entrance,
    child: Image.asset(
      widget.asset,
      width: widget.width,
      height: widget.height,
      cacheWidth: (widget.width * 3).round(),
      fit: BoxFit.contain,
      excludeFromSemantics: true,
    ),
    builder: (context, child) {
      final progress = Curves.easeOutCubic.transform(_entrance.value);
      return Opacity(
        opacity: progress,
        child: Transform.translate(
          offset: Offset(0, 10 * (1 - progress)),
          child: child,
        ),
      );
    },
  );
}

import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../core/theme/colors.dart';
import '../shared/mission_execution_display.dart';

/// 空间足够时并排，窄屏或大字体时纵向；按钮按内容增高，不截断中文。
class MissionActionPair extends StatelessWidget {
  const MissionActionPair({
    super.key,
    required this.primary,
    required this.secondary,
  });
  final Widget primary;
  final Widget secondary;
  @override
  Widget build(BuildContext context) {
    final style = ButtonStyle(
      minimumSize: const WidgetStatePropertyAll(Size(0, 52)),
      shape: const WidgetStatePropertyAll(StadiumBorder()),
      padding: const WidgetStatePropertyAll(
        EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
    );
    return FilledButtonTheme(
      data: FilledButtonThemeData(style: style),
      child: OutlinedButtonTheme(
        data: OutlinedButtonThemeData(style: style),
        child: LayoutBuilder(
          builder: (context, box) {
            final scale = MediaQuery.textScalerOf(context).scale(16) / 16;
            if (box.maxWidth < 300 * scale) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [primary, const SizedBox(height: 8), secondary],
              );
            }
            return Row(
              children: [
                Expanded(child: primary),
                const SizedBox(width: 12),
                Expanded(child: secondary),
              ],
            );
          },
        ),
      ),
    );
  }
}

class ExecutionFocusRing extends StatelessWidget {
  const ExecutionFocusRing({
    super.key,
    required this.focus,
    required this.budgetMinutes,
  });
  final Duration focus;
  final int budgetMinutes;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      final size = math.min(box.maxWidth, 300.0);
      final progress =
          (focus.inMilliseconds /
                  Duration(minutes: budgetMinutes).inMilliseconds)
              .clamp(0.0, 1.0);
      return Center(
        child: Semantics(
          label: '专注时长 ${executionDuration(focus)}',
          child: SizedBox(
            width: size,
            height: size,
            child: CustomPaint(
              key: const Key('execution-ring'),
              painter: _FocusPainter(progress),
              child: Center(
                child: SizedBox(
                  width: size * .72,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('专注时长'),
                      const SizedBox(height: 8),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          focusDuration(focus),
                          key: const Key('execution-focus'),
                          style: Theme.of(context).textTheme.displaySmall
                              ?.copyWith(
                                fontSize: 48,
                                height: 56 / 48,
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '当前额度 $budgetMinutes 分',
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    },
  );
}

class _FocusPainter extends CustomPainter {
  const _FocusPainter(this.progress);
  final double progress;
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.shortestSide / 2 - 8;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, radius, paint..color = AppColors.hairline);
    if (progress <= 0) return;
    final end = -math.pi / 2 + math.pi * 2 * progress;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      math.pi * 2 * progress,
      false,
      paint..color = AppColors.primary,
    );
    canvas.drawCircle(
      center + Offset(math.cos(end) * radius, math.sin(end) * radius),
      8,
      Paint()..color = AppColors.accent,
    );
  }

  @override
  bool shouldRepaint(_FocusPainter oldDelegate) =>
      oldDelegate.progress != progress;
}

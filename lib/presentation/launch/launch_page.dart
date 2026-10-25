import 'package:flutter/material.dart';

import '../../core/theme/colors.dart';

/// 冷启动时短暂显示的品牌过渡页。
class LaunchPage extends StatelessWidget {
  const LaunchPage({super.key});

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final height = constraints.maxHeight;
            final width = constraints.maxWidth;
            final compact = height < 600;
            return Stack(
              children: [
                Positioned.fill(child: CustomPaint(painter: _JourneyPainter())),
                Positioned(
                  top: height * (compact ? .11 : .16),
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Image.asset(
                      'assets/branding/mission_book_logo_v4.png',
                      width: compact ? 44 : 56,
                      height: compact ? 44 : 56,
                      semanticLabel: 'Mission Book 标识',
                    ),
                  ),
                ),
                Positioned(
                  top: height * (compact ? .39 : .45),
                  left: 24,
                  right: 24,
                  child: Column(
                    children: [
                      Text(
                        'Mission Book',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(
                              fontSize: compact ? 30 : 34,
                              height: 1.2,
                              letterSpacing: -.8,
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '让方向，成为今天的行动。',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                Positioned(
                  bottom: compact ? 24 : 34,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: width - 48),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '正在准备今天的旅程…',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: 172,
                            height: 3,
                            child: TweenAnimationBuilder<double>(
                              tween: Tween(
                                begin: 0,
                                end: reduceMotion ? 1 : .8,
                              ),
                              duration: reduceMotion
                                  ? Duration.zero
                                  : const Duration(milliseconds: 450),
                              builder: (context, progress, _) =>
                                  LinearProgressIndicator(
                                    value: progress,
                                    minHeight: 3,
                                    borderRadius: BorderRadius.circular(3),
                                    backgroundColor: AppColors.hairline,
                                    color: AppColors.primary,
                                  ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

// 山形、路径和节点只承担品牌氛围，不编码任务完成状态。
class _JourneyPainter extends CustomPainter {
  static const _far = Color(0xFFE9EDE5);
  static const _mid = Color(0xFFDDE5DA);
  static const _near = Color(0xFFD0DCCF);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final mountainTop = h * .68;

    final far = Path()
      ..moveTo(0, h * .77)
      ..lineTo(w * .13, h * .70)
      ..lineTo(w * .21, h * .74)
      ..lineTo(w * .39, h * .64)
      ..lineTo(w * .55, h * .73)
      ..lineTo(w * .73, mountainTop)
      ..lineTo(w, h * .79)
      ..lineTo(w, h)
      ..lineTo(0, h)
      ..close();
    canvas.drawPath(far, Paint()..color = _far);

    final middle = Path()
      ..moveTo(0, h * .84)
      ..lineTo(w * .18, h * .76)
      ..lineTo(w * .32, h * .81)
      ..lineTo(w * .56, h * .69)
      ..lineTo(w * .75, h * .80)
      ..lineTo(w, h * .72)
      ..lineTo(w, h)
      ..lineTo(0, h)
      ..close();
    canvas.drawPath(middle, Paint()..color = _mid);

    final foreground = Path()
      ..moveTo(0, h * .92)
      ..lineTo(w * .19, h * .85)
      ..lineTo(w * .43, h * .91)
      ..lineTo(w * .71, h * .79)
      ..lineTo(w, h * .89)
      ..lineTo(w, h)
      ..lineTo(0, h)
      ..close();
    canvas.drawPath(foreground, Paint()..color = _near);

    final windingRoad = Path()
      ..moveTo(w * .58, h)
      ..cubicTo(w * .21, h * .91, w * .77, h * .88, w * .48, h * .82)
      ..cubicTo(w * .31, h * .78, w * .54, h * .75, w * .57, h * .72);
    canvas.drawPath(
      windingRoad,
      Paint()
        ..color = AppColors.background.withValues(alpha: .92)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 12
        ..strokeCap = StrokeCap.round,
    );

    final route = Path()
      ..moveTo(w * .5, h * .245)
      ..cubicTo(w * .55, h * .27, w * .43, h * .31, w * .5, h * .355);
    canvas.drawPath(
      route,
      Paint()
        ..color = AppColors.textSecondary.withValues(alpha: .52)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.3,
    );
    canvas.drawCircle(
      Offset(w * .5, h * .355),
      7,
      Paint()..color = AppColors.primary,
    );
    canvas.drawCircle(
      Offset(w * .49, h * .286),
      2.5,
      Paint()..color = AppColors.textSecondary,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

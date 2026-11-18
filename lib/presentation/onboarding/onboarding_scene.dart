import 'package:flutter/material.dart';

import '../../core/theme/app_layout.dart';
import '../../core/theme/app_typography.dart';
import '../../core/theme/colors.dart';

/// 引导中的界面示意。三个步骤保留同一张任务卡，沿操作关系平滑接续。
/// 插图没有业务按钮；实际导航与完成由 OnboardingPage 负责。
class OnboardingScene extends StatelessWidget {
  const OnboardingScene({
    super.key,
    required this.progress,
    this.expanded = false,
  });

  final double progress;

  /// 平板画布横向展开归属关系，手机保留已确认的紧凑纵向示意。
  final bool expanded;

  double _weight(int page) => (1 - (progress - page).abs()).clamp(0, 1);

  Rect _rect(Rect first, Rect second, Rect third) => progress <= 1
      ? Rect.lerp(first, second, progress)!
      : Rect.lerp(second, third, progress - 1)!;

  @override
  Widget build(BuildContext context) {
    final today = _weight(0);
    final goal = _weight(1);
    final assistant = _weight(2);
    final paper = _rect(
      expanded
          ? const Rect.fromLTWH(110, 128, 340, 142)
          : const Rect.fromLTWH(40, 139, 340, 142),
      expanded
          ? const Rect.fromLTWH(260, 224, 280, 106)
          : const Rect.fromLTWH(68, 224, 312, 106),
      expanded
          ? const Rect.fromLTWH(140, 164, 370, 166)
          : const Rect.fromLTWH(40, 166, 340, 166),
    );
    return Center(
      child: FittedBox(
        fit: BoxFit.contain,
        child: MediaQuery.withNoTextScaling(
          // 图中文字与图形共同缩放，读屏通过外层完整的示意描述读取。
          child: SizedBox(
            width: expanded ? 560 : 420,
            height: expanded ? 360 : 400,
            child: Stack(
              children: [
                Positioned.fill(
                  child: CustomPaint(
                    painter: _Connections(goal: goal, expanded: expanded),
                  ),
                ),
                _layer(
                  expanded
                      ? const Rect.fromLTWH(114, 80, 332, 32)
                      : const Rect.fromLTWH(44, 92, 332, 32),
                  opacity: today,
                  child: const Row(
                    children: [
                      Text('今天', style: AppTypography.dialogTitle),
                      Spacer(),
                      Icon(
                        Icons.add_rounded,
                        size: 20,
                        color: AppColors.textSecondary,
                      ),
                    ],
                  ),
                ),
                _layer(
                  Rect.fromLTWH(
                    expanded ? 24 : 40,
                    66 + 12 * (1 - goal),
                    expanded ? 236 : 288,
                    66,
                  ),
                  opacity: goal,
                  child: const _Sheet(
                    child: Row(
                      children: [
                        Icon(
                          Icons.flag_outlined,
                          size: 21,
                          color: AppColors.primary,
                        ),
                        SizedBox(width: 12),
                        Text('读完一本书', style: AppTypography.readingBody),
                      ],
                    ),
                  ),
                ),
                _layer(
                  expanded
                      ? const Rect.fromLTWH(92, 152, 200, 40)
                      : const Rect.fromLTWH(77, 152, 250, 40),
                  opacity: goal,
                  child: const Row(
                    children: [
                      Icon(
                        Icons.subdirectory_arrow_right_rounded,
                        size: 18,
                        color: AppColors.textSecondary,
                      ),
                      SizedBox(width: 10),
                      Text('第一章', style: AppTypography.metadata),
                    ],
                  ),
                ),
                _layer(
                  Rect.fromLTWH(40, 72 + 12 * (1 - assistant), 40, 40),
                  opacity: assistant,
                  child: ClipOval(
                    child: Image.asset(
                      'assets/branding/shuqi-avatar.png',
                      fit: BoxFit.cover,
                      cacheWidth: 120,
                    ),
                  ),
                ),
                _layer(
                  Rect.fromLTWH(
                    (expanded ? 230 : 143) + 12 * (1 - assistant),
                    105,
                    237,
                    42,
                  ),
                  opacity: assistant,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    alignment: Alignment.centerLeft,
                    decoration: BoxDecoration(
                      color: AppColors.primarySoft,
                      borderRadius: BorderRadius.circular(AppLayout.radiusMd),
                    ),
                    child: const Text(
                      '想每天读一会儿书',
                      style: AppTypography.readingBody,
                    ),
                  ),
                ),
                // 页面切换时这张纸保持同一个 Element，位置和尺寸连续插值。
                Positioned.fromRect(
                  key: const Key('onboarding-shared-paper'),
                  rect: paper,
                  child: _Sheet(
                    child: Stack(
                      alignment: Alignment.centerLeft,
                      children: [
                        _content(
                          today,
                          const Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              _TaskRow(),
                              SizedBox(height: 20),
                              Divider(height: 1, color: AppColors.hairline),
                              SizedBox(height: 12),
                              Text('留一点时间，专注眼前', style: AppTypography.metadata),
                            ],
                          ),
                        ),
                        _content(goal, const _TaskRow(), height: 52),
                        _content(
                          assistant,
                          const Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                '从今天的 20 分钟开始',
                                style: AppTypography.readingBody,
                              ),
                              SizedBox(height: 18),
                              _TaskRow(),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _layer(Rect rect, {required double opacity, required Widget child}) =>
      Positioned.fromRect(
        rect: rect,
        child: Opacity(opacity: opacity, child: child),
      );

  Widget _content(double weight, Widget child, {double height = 100}) =>
      Opacity(
        opacity: (weight * 2 - 1).clamp(0, 1),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: SizedBox(width: 300, height: height, child: child),
        ),
      );
}

class _Sheet extends StatelessWidget {
  const _Sheet({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: AppColors.card,
      borderRadius: BorderRadius.circular(AppLayout.radiusLg),
      border: Border.all(color: AppColors.hairline),
    ),
    child: Padding(padding: const EdgeInsets.all(20), child: child),
  );
}

class _TaskRow extends StatelessWidget {
  const _TaskRow();

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Container(
        width: 3,
        height: 32,
        decoration: BoxDecoration(
          color: AppColors.primary,
          borderRadius: BorderRadius.circular(AppLayout.radiusXxs),
        ),
      ),
      const SizedBox(width: 12),
      const Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('阅读', style: AppTypography.dialogTitle),
            SizedBox(height: 4),
            Text('20 分钟', style: AppTypography.metadata),
          ],
        ),
      ),
      const Icon(
        Icons.play_circle_outline_rounded,
        color: AppColors.primary,
        size: 30,
      ),
    ],
  );
}

class _Connections extends CustomPainter {
  const _Connections({required this.goal, required this.expanded});
  final double goal;
  final bool expanded;

  @override
  void paint(Canvas canvas, Size size) {
    final path = expanded
        ? (Path()
            ..moveTo(56, 132)
            ..lineTo(56, 194)
            ..quadraticBezierTo(56, 212, 76, 212)
            ..lineTo(240, 212)
            ..quadraticBezierTo(260, 212, 260, 224))
        : (Path()
            ..moveTo(56, 132)
            ..lineTo(56, 202)
            ..quadraticBezierTo(56, 212, 68, 212)
            ..lineTo(86, 212)
            ..quadraticBezierTo(96, 212, 96, 224));
    final metric = path.computeMetrics().first;
    canvas.drawPath(
      metric.extractPath(0, metric.length * goal),
      Paint()
        ..color = AppColors.primary.withValues(alpha: .3 * goal)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_Connections oldDelegate) =>
      goal != oldDelegate.goal || expanded != oldDelegate.expanded;
}

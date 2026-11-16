import 'package:flutter/material.dart';

import '../../core/theme/app_motion.dart';
import '../../core/theme/app_typography.dart';
import '../../core/theme/colors.dart';

/// 完整品牌封面。停留由 App 管理，用户可提前进入，不显示虚构加载进度。
class LaunchPage extends StatelessWidget {
  const LaunchPage({super.key, this.onContinue});

  final VoidCallback? onContinue;

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.background,
    body: SafeArea(
      child: Column(
        children: [
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) => SingleChildScrollView(
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 32,
                      ),
                      child: TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0, end: 1),
                        duration: AppMotion.resolve(context, AppMotion.launch),
                        curve: AppMotion.curve,
                        builder: (context, value, child) => Opacity(
                          opacity: value,
                          child: Transform.translate(
                            offset: Offset(0, 6 * (1 - value)),
                            child: child,
                          ),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Image.asset(
                              'assets/branding/mission_book_logo_v4.png',
                              width: 64,
                              height: 64,
                              semanticLabel: 'MissionBook 标识',
                            ),
                            const SizedBox(height: 24),
                            const Text(
                              'MissionBook',
                              style: AppTypography.brandTitleCompact,
                            ),
                            const SizedBox(height: 12),
                            const Text(
                              '让方向，成为今天的行动。',
                              textAlign: TextAlign.center,
                              style: AppTypography.readingBody,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: TextButton.icon(
              key: const Key('launch-continue'),
              onPressed: onContinue,
              label: const Text('进入'),
              icon: const Icon(Icons.arrow_forward_rounded, size: 18),
              iconAlignment: IconAlignment.end,
            ),
          ),
        ],
      ),
    ),
  );
}

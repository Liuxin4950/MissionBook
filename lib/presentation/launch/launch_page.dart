import 'package:flutter/material.dart';

import '../../core/theme/app_layout.dart';
import '../../core/theme/app_motion.dart';
import '../../core/theme/app_typography.dart';
import '../../core/theme/colors.dart';

/// 冷启动时短暂显示的品牌过渡页。
///
/// 这里不展示业务加载百分比：启动页只负责品牌识别和等待工作区装配，
/// 因此使用不承诺进度的线性指示器，避免把“已完成 80%”误解成业务事实。
class LaunchPage extends StatelessWidget {
  const LaunchPage({super.key});

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final duration = AppMotion.resolve(context, AppMotion.launch);
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxHeight < 600;
            final width = constraints.maxWidth;
            final artworkHeight = (constraints.maxHeight * .43).clamp(
              220.0,
              420.0,
            );
            return Stack(
              children: [
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  height: artworkHeight,
                  child: IgnorePointer(
                    child: TweenAnimationBuilder<double>(
                      tween: Tween(begin: reduceMotion ? 1 : .96, end: 1),
                      duration: duration,
                      curve: AppMotion.curve,
                      builder: (context, scale, child) => Transform.scale(
                        alignment: Alignment.bottomCenter,
                        scale: scale,
                        child: child,
                      ),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          Image.asset(
                            'assets/illustrations/journey-garden-v2.png',
                            fit: BoxFit.cover,
                            alignment: Alignment.centerRight,
                            cacheWidth: (width * 2).round(),
                            excludeFromSemantics: true,
                          ),
                          const DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  AppColors.background,
                                  Color(0x00F7F8F5),
                                ],
                                stops: [0, .42],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Positioned.fill(
                  child: Column(
                    children: [
                      SizedBox(height: compact ? 36 : 64),
                      TweenAnimationBuilder<double>(
                        tween: Tween(begin: reduceMotion ? 1 : .82, end: 1),
                        duration: duration,
                        curve: AppMotion.curve,
                        builder: (context, scale, child) => Opacity(
                          opacity: reduceMotion ? 1 : scale,
                          child: Transform.scale(scale: scale, child: child),
                        ),
                        child: Image.asset(
                          'assets/branding/mission_book_logo_v4.png',
                          width: compact ? 52 : 68,
                          height: compact ? 52 : 68,
                          semanticLabel: 'MissionBook 标识',
                        ),
                      ),
                      SizedBox(height: compact ? 34 : 56),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Column(
                          children: [
                            Text(
                              'MissionBook',
                              textAlign: TextAlign.center,
                              style: compact
                                  ? AppTypography.brandTitleCompact
                                  : AppTypography.brandTitle,
                            ),
                            const SizedBox(height: AppLayout.spaceSm),
                            Text(
                              '让方向，成为今天的行动。',
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(color: AppColors.textSecondary),
                            ),
                          ],
                        ),
                      ),
                      const Spacer(),
                      Padding(
                        padding: EdgeInsets.fromLTRB(
                          AppLayout.spaceXl,
                          AppLayout.spaceMd,
                          AppLayout.spaceXl,
                          compact ? AppLayout.spaceXl : AppLayout.space3Xl,
                        ),
                        child: ConstrainedBox(
                          constraints: BoxConstraints(maxWidth: width - 48),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '正在准备今天的旅程…',
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                              const SizedBox(height: AppLayout.spaceMd),
                              SizedBox(
                                width: 172,
                                height: 3,
                                child: LinearProgressIndicator(
                                  minHeight: 3,
                                  borderRadius: BorderRadius.circular(
                                    AppLayout.radiusXs,
                                  ),
                                  backgroundColor: AppColors.hairline,
                                  color: AppColors.primary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
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

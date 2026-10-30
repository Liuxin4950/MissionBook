import 'package:flutter/material.dart';

import '../../core/theme/colors.dart';
import '../../core/theme/app_layout.dart';

const journeyArtwork = 'assets/illustrations/journey-garden-v2.png';

/// 目标引导使用品牌场景图，窄屏先看图再操作，宽屏图文并排。
class AppJourneyHero extends StatelessWidget {
  const AppJourneyHero({
    super.key,
    required this.title,
    required this.actions,
    this.illustrationKey,
  });
  final String title;
  final Widget actions;
  final Key? illustrationKey;

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(AppLayout.radiusXxl),
    child: ColoredBox(
      color: AppColors.card,
      child: LayoutBuilder(
        builder: (context, box) {
          final wide =
              box.maxWidth >= 680 * MediaQuery.textScalerOf(context).scale(1);
          final picture = Image.asset(
            journeyArtwork,
            key: illustrationKey,
            width: double.infinity,
            height: wide ? 280 : 170,
            fit: BoxFit.cover,
            alignment: Alignment.centerRight,
            cacheWidth: 1280,
            excludeFromSemantics: true,
          );
          final words = Padding(
            padding: EdgeInsets.all(
              wide ? AppLayout.space3Xl : AppLayout.spaceXl,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.flag_outlined,
                  color: AppColors.primary,
                  size: AppLayout.iconLg,
                ),
                const SizedBox(height: AppLayout.spaceMd),
                Text(title, style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: AppLayout.spaceSm),
                Text(
                  '让想做的事，有一条清晰的路。',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: AppLayout.spaceXl),
                actions,
              ],
            ),
          );
          return wide
              ? Row(
                  children: [
                    Expanded(flex: 5, child: words),
                    Expanded(flex: 6, child: picture),
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [picture, words],
                );
        },
      ),
    ),
  );
}

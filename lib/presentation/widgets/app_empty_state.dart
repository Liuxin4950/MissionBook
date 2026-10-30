import '../../core/theme/app_layout.dart';
import 'package:flutter/material.dart';

import 'app_illustration.dart';

/// 空态共用插画尺寸、文字层级与间距；各页提供自己的真实说明和操作。
class AppEmptyState extends StatelessWidget {
  const AppEmptyState({
    super.key,
    required this.title,
    this.asset,
    this.illustrationKey,
    this.details,
    this.actions,
    this.horizontalWhenWide = false,
  });

  final String title;
  final String? asset;
  final Key? illustrationKey;
  final Widget? details;
  final Widget? actions;
  final bool horizontalWhenWide;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      final wide =
          horizontalWhenWide &&
          box.maxWidth >= 640 * MediaQuery.textScalerOf(context).scale(1);
      final words = Column(
        crossAxisAlignment: wide
            ? CrossAxisAlignment.start
            : CrossAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleLarge,
            textAlign: wide ? TextAlign.start : TextAlign.center,
          ),
          if (details != null) ...[
            const SizedBox(height: AppLayout.spaceMd),
            DefaultTextStyle.merge(
              textAlign: wide ? TextAlign.start : TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
              child: details!,
            ),
          ],
          if (actions != null) ...[
            const SizedBox(height: AppLayout.spaceLg),
            actions!,
          ],
        ],
      );
      final picture = asset == null
          ? null
          : AppIllustration(
              key: illustrationKey,
              asset: asset!,
              width: wide ? 240 : 192,
              height: wide ? 160 : 128,
            );
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: AppLayout.spaceXxl),
        child: wide
            ? Row(
                children: [
                  if (picture != null) ...[
                    picture,
                    const SizedBox(width: AppLayout.space3Xl),
                  ],
                  Expanded(child: words),
                ],
              )
            : Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (picture != null) ...[
                        picture,
                        const SizedBox(height: AppLayout.spaceLg),
                      ],
                      words,
                    ],
                  ),
                ),
              ),
      );
    },
  );
}

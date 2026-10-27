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
  });

  final String title;
  final String? asset;
  final Key? illustrationKey;
  final Widget? details;
  final Widget? actions;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 24),
    child: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (asset != null) ...[
              AppIllustration(
                key: illustrationKey,
                asset: asset!,
                width: 192,
                height: 128,
              ),
              const SizedBox(height: 16),
            ],
            Text(
              title,
              style: Theme.of(context).textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            if (details != null) ...[
              const SizedBox(height: 12),
              DefaultTextStyle.merge(
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
                child: details!,
              ),
            ],
            if (actions != null) ...[const SizedBox(height: 16), actions!],
          ],
        ),
      ),
    ),
  );
}

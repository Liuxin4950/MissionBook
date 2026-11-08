import 'package:flutter/material.dart';

import '../../core/theme/app_layout.dart';

/// 动效强度和页面风格共用的预览、选择与错误反馈布局。
class MotionSettingsPanel extends StatelessWidget {
  const MotionSettingsPanel({
    super.key,
    required this.title,
    required this.onReplay,
    required this.replayKey,
    required this.preview,
    required this.options,
    this.error,
  });

  final String title;
  final VoidCallback onReplay;
  final Key replayKey;
  final Widget preview;
  final List<Widget> options;
  final String? error;

  @override
  Widget build(BuildContext context) => SafeArea(
    child: SingleChildScrollView(
      padding: const EdgeInsets.symmetric(vertical: AppLayout.spaceSm),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppLayout.spaceLg),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                TextButton.icon(
                  key: replayKey,
                  onPressed: onReplay,
                  icon: const Icon(Icons.replay),
                  label: const Text('重播'),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppLayout.spaceLg),
            child: Material(
              color: Theme.of(context).colorScheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(AppLayout.radiusMd),
              clipBehavior: Clip.antiAlias,
              child: preview,
            ),
          ),
          if (MediaQuery.disableAnimationsOf(context))
            const Padding(
              padding: EdgeInsets.all(AppLayout.spaceSm),
              child: Text('减少动效已生效'),
            ),
          ...options,
          if (error != null)
            Padding(
              padding: const EdgeInsets.all(AppLayout.spaceMd),
              child: Text(
                error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
        ],
      ),
    ),
  );
}

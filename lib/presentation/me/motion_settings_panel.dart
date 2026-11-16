import 'package:flutter/material.dart';

import '../../core/theme/app_layout.dart';
import '../../core/theme/app_motion.dart';
import '../widgets/adaptive_columns.dart';

/// 动效强度和页面风格共用的预览、选择与错误反馈布局。
class MotionSettingsPanel extends StatelessWidget {
  const MotionSettingsPanel({
    super.key,
    required this.title,
    required this.onReplay,
    required this.replayKey,
    required this.preview,
    required this.options,
    this.maxOptionColumns = 1,
    this.error,
  });

  final String title;
  final VoidCallback onReplay;
  final Key replayKey;
  final Widget preview;
  final List<Widget> options;
  final int maxOptionColumns;
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
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppLayout.spaceLg),
            child: AdaptiveColumns(
              minColumnWidth: 156,
              maxColumns: maxOptionColumns,
              spacing: AppLayout.spaceXs,
              children: options,
            ),
          ),
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

/// 动效设置选项共用圆角底色、图标和勾选过渡。
class MotionSettingsOption extends StatelessWidget {
  const MotionSettingsOption({
    super.key,
    required this.label,
    required this.icon,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final duration = AppMotion.resolve(context, AppMotion.quick);
    return Material(
      animationDuration: duration,
      color: selected ? colors.primaryContainer : colors.surface,
      borderRadius: BorderRadius.circular(AppLayout.radiusMd),
      child: ListTile(
        minTileHeight: AppLayout.actionMinHeight,
        minLeadingWidth: AppLayout.iconMd,
        horizontalTitleGap: AppLayout.spaceSm,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppLayout.spaceMd,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppLayout.radiusMd),
        ),
        leading: Icon(icon, size: AppLayout.iconMd),
        title: Text(label),
        selected: selected,
        enabled: enabled,
        trailing: AnimatedScale(
          scale: selected ? 1 : .6,
          duration: duration,
          curve: AppMotion.curve,
          child: AnimatedOpacity(
            opacity: selected ? 1 : 0,
            duration: duration,
            child: const ExcludeSemantics(
              child: Icon(Icons.check, size: AppLayout.iconSm),
            ),
          ),
        ),
        onTap: enabled ? onTap : null,
      ),
    );
  }
}

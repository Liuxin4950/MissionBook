import 'package:flutter/material.dart';
import '../../core/theme/app_layout.dart';
import '../../core/theme/app_motion.dart';

/// 等分可用宽度的分类栏。标签允许换行，不把最后一项藏到横向滚动区。
class AppSegmentedControl<T> extends StatelessWidget {
  const AppSegmentedControl({
    super.key,
    required this.options,
    required this.selected,
    required this.onSelected,
    this.optionKey,
  });
  final Map<T, String> options;
  final T selected;
  final ValueChanged<T> onSelected;
  final Key Function(T)? optionKey;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(AppLayout.radiusLg),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppLayout.spaceXs),
        child: Stack(
          children: [
            if (options.keys.contains(selected))
              Positioned.fill(
                child: AnimatedAlign(
                  alignment: Alignment(
                    options.length <= 1
                        ? 0
                        : -1 +
                              2 *
                                  options.keys.toList().indexOf(selected) /
                                  (options.length - 1),
                    0,
                  ),
                  duration: AppMotion.resolve(context, AppMotion.standard),
                  curve: AppMotion.curve,
                  child: FractionallySizedBox(
                    widthFactor: 1 / options.length,
                    child: DecoratedBox(
                      key: const Key('segmented-selection-surface'),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(AppLayout.radiusMd),
                      ),
                      child: const SizedBox.expand(),
                    ),
                  ),
                ),
              ),
            Row(
              children: [
                for (final entry in options.entries)
                  Expanded(
                    child: Semantics(
                      selected: selected == entry.key,
                      child: TextButton(
                        key: optionKey?.call(entry.key),
                        onPressed: () => onSelected(entry.key),
                        style:
                            TextButton.styleFrom(
                              foregroundColor: selected == entry.key
                                  ? theme.colorScheme.primary
                                  : theme.colorScheme.onSurfaceVariant,
                              backgroundColor: Colors.transparent,
                              minimumSize: const Size(
                                0,
                                AppLayout.touchTargetMin,
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppLayout.spaceSm,
                                vertical: AppLayout.spaceSm,
                              ),
                              textStyle: theme.textTheme.labelMedium,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(
                                  AppLayout.radiusMd,
                                ),
                              ),
                            ).copyWith(
                              animationDuration: AppMotion.resolve(
                                context,
                                AppMotion.quick,
                              ),
                            ),
                        child: Text(entry.value, textAlign: TextAlign.center),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

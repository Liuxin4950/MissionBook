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
        child: Row(
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
                          backgroundColor: selected == entry.key
                              ? theme.colorScheme.surfaceContainerLow
                              : Colors.transparent,
                          minimumSize: const Size(0, AppLayout.touchTargetMin),
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppLayout.spaceSm,
                            vertical: AppLayout.spaceSm,
                          ),
                          textStyle: theme.textTheme.labelMedium,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(
                              AppLayout.radiusMd,
                            ),
                            side: BorderSide(
                              color: selected == entry.key
                                  ? theme.colorScheme.primary
                                  : Colors.transparent,
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
      ),
    );
  }
}

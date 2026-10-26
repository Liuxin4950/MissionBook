import 'package:flutter/material.dart';

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
        color: theme.colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Row(
          children: [
            for (final entry in options.entries)
              Expanded(
                child: Semantics(
                  selected: selected == entry.key,
                  child: TextButton(
                    key: optionKey?.call(entry.key),
                    onPressed: () => onSelected(entry.key),
                    style: TextButton.styleFrom(
                      foregroundColor: theme.colorScheme.onSurface,
                      backgroundColor: selected == entry.key
                          ? theme.colorScheme.secondaryContainer
                          : Colors.transparent,
                      minimumSize: const Size(0, 48),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 10,
                      ),
                      textStyle: theme.textTheme.labelMedium,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
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

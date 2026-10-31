import 'package:flutter/material.dart';

/// 分区标题统一提供读屏标题语义；设置页可选择更轻的标签层级。
class AppSectionHeader extends StatelessWidget {
  const AppSectionHeader(this.title, {super.key, this.subtle = false});

  final String title;
  final bool subtle; // 设置分组用轻标签，正文区块仍使用 titleMedium。

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      container: true,
      header: true,
      child: Text(
        title,
        style: subtle
            ? theme.textTheme.titleSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              )
            : theme.textTheme.titleMedium,
      ),
    );
  }
}

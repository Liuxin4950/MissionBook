import 'package:flutter/material.dart';

import 'today_display.dart';

// 固定、自选和取消行共用的文字排版。文字已经由 TodayDisplay 准备好。
// 这是布局复用，不做类型转换、分组或查询。
Widget buildMissionDetails(BuildContext context, TodayMissionItem item) {
  final theme = Theme.of(context);
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        item.title,
        style: theme.textTheme.titleMedium?.copyWith(
          decoration: item.isCancelled ? TextDecoration.lineThrough : null,
        ),
      ),
      const SizedBox(height: 4),
      Text(item.durationLabel, style: theme.textTheme.bodyMedium),
      if (item.timeZoneLabel != null)
        Text(item.timeZoneLabel!, style: theme.textTheme.bodySmall),
    ],
  );
}

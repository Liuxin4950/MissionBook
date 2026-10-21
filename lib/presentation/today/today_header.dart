import 'package:flutter/material.dart';

// 页面顶部。TodayPage 提供已准备好的日期文字和回调；这里只负责排版。
class TodayHeader extends StatelessWidget {
  const TodayHeader({
    super.key,
    required this.dateLabel,
    required this.isToday,
    required this.onPickDate,
    required this.onCreate,
    required this.onReturnToday,
  });

  final String dateLabel;
  final bool isToday;
  final VoidCallback onPickDate;
  final VoidCallback onCreate;
  final VoidCallback onReturnToday;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('今天', style: theme.textTheme.headlineSmall),
                  TextButton.icon(
                    key: const Key('today-date-picker'),
                    onPressed: onPickDate,
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      foregroundColor: theme.colorScheme.onSurfaceVariant,
                      alignment: Alignment.centerLeft,
                      textStyle: theme.textTheme.bodyMedium,
                    ),
                    label: Text(dateLabel),
                    icon: const Icon(Icons.expand_more, size: 20),
                    iconAlignment: IconAlignment.end,
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: IconButton.filled(
                onPressed: onCreate,
                icon: const Icon(Icons.add),
                tooltip: '创建任务',
                style: IconButton.styleFrom(
                  fixedSize: const Size(48, 48),
                  shape: const CircleBorder(),
                ),
              ),
            ),
          ],
        ),
        if (!isToday)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: onReturnToday,
              child: const Text('回到今天'),
            ),
          ),
      ],
    );
  }
}

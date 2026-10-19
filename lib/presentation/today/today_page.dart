import 'package:flutter/material.dart';

class TodayPage extends StatelessWidget {
  const TodayPage({super.key});

  @override
  Widget build(BuildContext context) {
    //运行查找主题
    final theme = Theme.of(context);
    // weekday 组合日期，因为更新频率低所有没有用StatefulWidget
    final today = DateTime.now();
    const weekdays = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];
    final dateText =
        '${today.month}月${today.day}日 · ${weekdays[today.weekday - 1]}';

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // header
              Row(
                children: [
                  // 自适应占据
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '今天',
                          style: theme.textTheme.headlineSmall?.copyWith(
                            // 设计规范：页面标题字号 28，行高 36。
                            fontSize: 28,
                            height: 36 / 28,
                            fontWeight: FontWeight.w600,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          dateText,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontSize: 14,
                            height: 20 / 14,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton.filled(
                    onPressed: null,
                    icon: const Icon(Icons.add),
                    tooltip: "创建任务",
                    style: IconButton.styleFrom(
                      fixedSize: const Size(48, 48),
                      shape: const CircleBorder(),
                    ),
                  ),
                ],
              ),

              // plan

              // time
            ],
          ),
        ],
      ),
    );
  }
}

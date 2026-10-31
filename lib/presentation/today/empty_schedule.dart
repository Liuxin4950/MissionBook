import 'package:flutter/material.dart';

import '../widgets/app_empty_state.dart';

/// 紧凑日程和宽屏时间轴共用同一空态与创建入口。
class EmptySchedule extends StatelessWidget {
  const EmptySchedule({super.key, this.illustrate = false, this.onCreate});

  final bool illustrate;
  final VoidCallback? onCreate;

  @override
  Widget build(BuildContext context) => AppEmptyState(
    title: '这一天还没有固定任务',
    asset: illustrate ? 'assets/illustrations/day-plan.png' : null,
    actions: onCreate == null
        ? null
        : FilledButton.icon(
            onPressed: onCreate,
            icon: const Icon(Icons.add),
            label: const Text('新建任务'),
          ),
  );
}

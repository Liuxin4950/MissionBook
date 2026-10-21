import 'package:flutter/material.dart';

/// An action button whose accessible label matches the actual command.
class AccessibleMissionButton extends StatelessWidget {
  const AccessibleMissionButton({
    required this.isRunning,
    required this.onPressed,
    this.isBusy = false,
    super.key,
  });

  final bool isRunning;                                               // 已保存事实投影为运行状态。
  final bool isBusy;                                                  // UI 临时提交中状态。
  final VoidCallback onPressed;                                       // 注入命令；Widget 不直接写 SQLite。

  @override
  Widget build(BuildContext context) {                               // 此方法可以重复执行。
    final String label = isRunning ? '暂停任务' : '开始任务';              // 文案表示真实操作，而非笼统“确定”。
    return FilledButton.icon(                                        // 标准按钮已有可访问性信息。
      onPressed: isBusy ? null : onPressed,                           // 禁用提高体验，但非数据库互斥。
      icon: Icon(isRunning ? Icons.pause : Icons.play_arrow),        // 视觉图标跟随用户可用操作。
      label: Text(label),                                            // 屏幕阅读器可朗读的操作名称。
    );
  }
}

/// An icon-only control requires a text alternative.
class AccessiblePauseIcon extends StatelessWidget {
  const AccessiblePauseIcon({required this.onPressed, super.key});

  final VoidCallback onPressed;                                      // 由外层 ViewModel/Workflow 提供。

  @override
  Widget build(BuildContext context) {                               // 控件本身不推断持久化状态。
    return IconButton(                                               // 优先官方内置控件而非自绘手势区。
      tooltip: '暂停任务',                                              // 图标独立出现时提供语义标签。
      onPressed: onPressed,                                          // 可点动作应真实执行命令。
      icon: const Icon(Icons.pause),                                 // 与 tooltip 的动作含义一致。
    );
  }
}

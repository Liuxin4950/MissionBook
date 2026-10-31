import 'package:flutter/material.dart';

import '../../../core/theme/app_layout.dart';

/// 读取或解码失败只影响图片展示，保留材料说明与独立的操作入口。
class EvidenceImageStatus extends StatelessWidget {
  const EvidenceImageStatus({
    super.key,
    required this.name,
    required this.height,
    this.failed = false,
    this.onRetry,
    this.compact = false,
  });

  final String name;
  final double height;
  final bool failed;
  final VoidCallback? onRetry;
  final bool compact;

  @override
  Widget build(BuildContext context) => ConstrainedBox(
    constraints: BoxConstraints(minHeight: height),
    child: Center(
      child: Padding(
        padding: EdgeInsets.all(compact ? 0 : AppLayout.spaceMd),
        child: compact && failed
            ? onRetry == null
                  ? Tooltip(
                      message: '图片无法显示：$name',
                      child: const Icon(Icons.broken_image_outlined),
                    )
                  : IconButton(
                      tooltip: '重新读取图片：$name',
                      onPressed: onRetry,
                      icon: const Icon(Icons.broken_image_outlined),
                    )
            : failed
            ? Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.broken_image_outlined,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(height: AppLayout.spaceSm),
                  Text(
                    '图片无法显示：$name。材料记录仍然保留。',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  if (onRetry != null)
                    TextButton.icon(
                      onPressed: onRetry,
                      icon: const Icon(Icons.refresh),
                      label: const Text('重新读取图片'),
                    ),
                ],
              )
            : CircularProgressIndicator(semanticsLabel: '正在读取图片：$name'),
      ),
    ),
  );
}

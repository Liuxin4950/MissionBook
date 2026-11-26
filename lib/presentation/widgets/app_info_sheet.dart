import 'package:flutter/material.dart';
import '../../core/theme/app_metrics.dart';
import 'adaptive_sheet.dart';

/// 设置说明共用自适应弹层与次级关闭按钮。
Future<void> showAppInfoSheet(
  BuildContext context,
  String title,
  String message,
) => showAdaptiveSheet<void>(
  context: context,
  builder: (context) => SafeArea(
    top: false,
    child: SingleChildScrollView(
      padding: const EdgeInsets.all(AppMetrics.spaceXxl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: AppMetrics.spaceMd),
          Text(message),
          const SizedBox(height: AppMetrics.spaceLg),
          OutlinedButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('知道了'),
          ),
        ],
      ),
    ),
  ),
);

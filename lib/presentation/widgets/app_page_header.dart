import '../../core/theme/app_layout.dart';
import 'package:flutter/material.dart';

/// 主页面共用说明与操作位置；导航已标明页面时可隐藏重复标题。
class AppPageHeader extends StatelessWidget {
  const AppPageHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.action,
    this.showTitle = true,
  });

  final String title;
  final Widget? subtitle;
  final Widget? action;
  final bool showTitle; // 主导航已标明页面时，使用说明与操作组成紧凑工具栏。

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      ConstrainedBox(
        constraints: const BoxConstraints(minHeight: AppLayout.touchTargetMin),
        child: Row(
          children: [
            Expanded(
              child: !showTitle
                  ? subtitle ?? const SizedBox.shrink()
                  : Semantics(
                      container: true,
                      header: true,
                      child: Text(
                        title,
                        key: ValueKey('page-heading-$title'),
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                    ),
            ),
            if (action != null) ...[
              const SizedBox(width: AppLayout.spaceMd),
              IconButtonTheme(
                data: IconButtonThemeData(
                  style: IconButton.styleFrom(
                    fixedSize: const Size(
                      AppLayout.touchTargetMin,
                      AppLayout.touchTargetMin,
                    ),
                    shape: const CircleBorder(),
                  ),
                ),
                child: action!,
              ),
            ],
          ],
        ),
      ),
      // 有标题时，说明另起一行；紧凑工具栏中说明与操作共用一行。
      if (showTitle && subtitle != null)
        ConstrainedBox(
          key: ValueKey('page-subtitle-$title'),
          constraints: const BoxConstraints(
            minHeight: AppLayout.touchTargetMin,
          ),
          child: Align(alignment: Alignment.centerLeft, child: subtitle),
        ),
    ],
  );
}

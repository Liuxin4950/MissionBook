import '../../core/theme/app_layout.dart';
import 'package:flutter/material.dart';

/// 四个主页面共用标题基线、说明行和主操作位置，外层使用 AppLayout.pagePadding。
class AppPageHeader extends StatelessWidget {
  const AppPageHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.action,
  });

  final String title;
  final Widget? subtitle;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      ConstrainedBox(
        constraints: const BoxConstraints(minHeight: AppLayout.touchTargetMin),
        child: Row(
          children: [
            Expanded(
              child: Semantics(
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
      // 说明行使用完整宽度，窄屏日期不会被右侧操作挤成多行。
      if (subtitle != null)
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

import 'package:flutter/material.dart';

/// 四个主页面共用标题基线、说明行和主操作位置，外层使用 AppLayout.pagePadding。
class AppPageHeader extends StatelessWidget {
  const AppPageHeader({
    super.key,
    required this.title,
    required this.subtitle,
    this.action,
  });

  final String title;
  final Widget subtitle;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Semantics(
              header: true,
              child: Text(
                title,
                key: ValueKey('page-heading-$title'),
                style: Theme.of(context).textTheme.headlineSmall,
              ),
            ),
            ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 40),
              child: Align(alignment: Alignment.centerLeft, child: subtitle),
            ),
          ],
        ),
      ),
      if (action != null) ...[
        const SizedBox(width: 16),
        Padding(padding: const EdgeInsets.only(top: 4), child: action),
      ],
    ],
  );
}

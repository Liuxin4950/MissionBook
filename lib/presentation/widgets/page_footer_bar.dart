import 'package:flutter/material.dart';

import '../../core/theme/app_layout.dart';

/// 主操作固定在滚动区外：统一左右边距、限宽居中、主按钮占满可用宽。
/// 页面底部与宽屏右栏共用同一形态；键盘避让由调用方按所在容器处理
/// （表单页需要跟随键盘时把避让高度算进 bottomPadding）。
class PageFooterBar extends StatelessWidget {
  const PageFooterBar({
    super.key,
    required this.child,
    this.topPadding = 8,
    this.bottomPadding = 16,
  });

  /// 页面传入的主操作区（单按钮、双按钮行或按钮+提示列）。
  final Widget child;

  // 上下留白可按容器微调；默认值与既有页面 footer 一致。
  final double topPadding;
  final double bottomPadding;

  @override
  Widget build(BuildContext context) {
    return Center(
      // 高度按内容收缩：footer 既可放在 Column 末尾，也可放进底部操作条。
      heightFactor: 1,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: AppLayout.maxPageWidth),
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            AppLayout.horizontalPadding(context),
            topPadding,
            AppLayout.horizontalPadding(context),
            bottomPadding,
          ),
          child: SizedBox(width: double.infinity, child: child),
        ),
      ),
    );
  }
}

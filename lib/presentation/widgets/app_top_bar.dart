import 'package:flutter/material.dart';

import '../../core/theme/app_layout.dart';

/// 二级页面共用的顶栏：浅绿圆形返回、森林绿箭头和靠左标题。
///
/// 这里只统一外观。表单丢弃确认等业务由页面提供的 onBack 处理；
/// 没有自定义处理时，使用 Navigator.maybePop 返回上一页。
class AppTopBar extends StatelessWidget implements PreferredSizeWidget {
  const AppTopBar({
    super.key,
    required this.title,
    this.onBack,
    this.canGoBack = true,
    this.actions,
    this.maxContentWidth = AppLayout.maxPageWidth,
  });

  /// 页面提供的标题，例如“新建任务”或“任务详情”。
  final String title;

  /// 点击返回时调用的方法；为空时采用普通路由返回。
  final VoidCallback? onBack;

  /// 保存期间可设为 false，按钮保留位置但不能触发返回。
  final bool canGoBack;
  // 详情页可提供“更多”菜单；未提供时保持原有顶栏。
  final List<Widget>? actions;
  final double maxContentWidth; // 与所在页面的正文外框限宽一致。

  // Scaffold.appBar 要求 PreferredSizeWidget，以便在布局前取得顶栏高度。
  // 64 只包含工具栏，系统状态栏的安全区域仍由内部 AppBar 处理。
  @override
  Size get preferredSize => const Size.fromHeight(64);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final handleBack =
        onBack ??
        () {
          // maybePop 会尊重所在页面的 PopScope，不直接绕过页面的返回保护。
          Navigator.of(context).maybePop();
        };

    return LayoutBuilder(
      builder: (context, box) {
        final inset =
            AppLayout.horizontalPadding(context) +
            ((box.maxWidth - maxContentWidth) / 2).clamp(0.0, double.infinity);
        return AppBar(
          toolbarHeight: preferredSize.height,
          centerTitle: false,
          titleSpacing: 12,
          title: Text(title),
          titleTextStyle: theme.textTheme.titleMedium,
          actions: actions,
          actionsPadding: EdgeInsets.only(right: inset),
          // 返回按钮与正文共用左右边距；标准24、窄屏16，加上48触控宽度。
          leadingWidth: inset + 48,
          leading: Padding(
            padding: EdgeInsets.only(left: inset),
            child: Center(
              child: IconButton(
                onPressed: canGoBack ? handleBack : null,
                tooltip: '返回',
                style: IconButton.styleFrom(
                  fixedSize: const Size(48, 48),
                  padding: EdgeInsets.zero,
                  shape: const CircleBorder(),
                  backgroundColor: colors.primaryContainer,
                  disabledBackgroundColor: colors.primaryContainer,
                ),
                // 浅色返回面使用深色图标，与正文标题保持同一颜色层级。
                icon: Icon(
                  Icons.arrow_back,
                  size: 24,
                  color: canGoBack ? colors.primary : colors.onSurfaceVariant,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

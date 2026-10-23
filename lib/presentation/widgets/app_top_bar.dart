import 'package:flutter/material.dart';

import '../../core/theme/app_layout.dart';

/// 二级页面共用的顶栏：森林绿圆形返回、白色箭头和居中标题。
///
/// 这里只统一外观。表单丢弃确认等业务由页面提供的 onBack 处理；
/// 没有自定义处理时，使用 Navigator.maybePop 返回上一页。
class AppTopBar extends StatelessWidget implements PreferredSizeWidget {
  const AppTopBar({
    super.key,
    required this.title,
    this.onBack,
    this.canGoBack = true,
  });

  /// 页面提供的标题，例如“新建任务”或“任务详情”。
  final String title;

  /// 点击返回时调用的方法；为空时采用普通路由返回。
  final VoidCallback? onBack;

  /// 保存期间可设为 false，按钮保留位置但不能触发返回。
  final bool canGoBack;

  // Scaffold.appBar 要求 PreferredSizeWidget，以便在布局前取得顶栏高度。
  // 80 只包含工具栏，系统状态栏的安全区域仍由内部 AppBar 处理。
  @override
  Size get preferredSize => const Size.fromHeight(80);

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

    return AppBar(
      toolbarHeight: preferredSize.height,
      centerTitle: true,
      title: Text(title),
      titleTextStyle: theme.textTheme.titleMedium,
      // 返回按钮与正文共用左右边距；标准24、窄屏16，加上48触控宽度。
      leadingWidth: AppLayout.horizontalPadding(context) + 48,
      leading: Padding(
        padding: EdgeInsets.only(left: AppLayout.horizontalPadding(context)),
        child: Center(
          child: IconButton.filled(
            onPressed: canGoBack ? handleBack : null,
            tooltip: '返回',
            style: IconButton.styleFrom(
              fixedSize: const Size(48, 48),
              padding: EdgeInsets.zero,
              shape: const CircleBorder(),
              backgroundColor: colors.primary,
              disabledBackgroundColor: colors.primaryContainer,
            ),
            // AppBar 的图标主题是深色；圆形主色面上的箭头要明确指定对比色。
            icon: Icon(
              Icons.arrow_back,
              size: 24,
              color: canGoBack ? colors.onPrimary : colors.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';

/// 应用共用的双按钮确认框。这里只展示文案并返回选择，业务仍由页面处理。
class AppConfirmDialog extends StatelessWidget {
  const AppConfirmDialog({
    super.key,
    required this.title,
    required this.message,
    this.cancelText = '取消',
    this.confirmText = '确定',
  });

  final String title;
  final String message;
  final String cancelText;
  final String confirmText;

  /// 页面 await 此方法取得选择：确认返回 true，其余关闭方式统一返回 false。
  static Future<bool> show({
    required BuildContext context,
    required String title,
    required String message,
    String cancelText = '取消',
    String confirmText = '确定',
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AppConfirmDialog(
        title: title,
        message: message,
        cancelText: cancelText,
        confirmText: confirmText,
      ),
    );
    // 点击遮罩或按系统返回可能没有结果，不能当作已经确认。
    return result == true;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final buttonStyle = TextStyle(
      fontSize: 16,
      height: 24 / 16,
      fontWeight: FontWeight.w600,
    );
    final buttonShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
    );

    return Dialog(
      backgroundColor: colors.surfaceContainerLow,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.all(24),
      constraints: const BoxConstraints(maxWidth: 360),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      // 高度由内容决定；横屏或大字体时整个内容可以滚动。
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Semantics(
              namesRoute: true,
              child: Text(
                title,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontSize: 20,
                  height: 28 / 20,
                  fontWeight: FontWeight.w600,
                  color: colors.onSurface,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              message,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 24),
            LayoutBuilder(
              builder: (context, constraints) {
                // 窄屏或放大字号时改成纵排，给按钮文字留出完整空间。
                final stackButtons =
                    constraints.maxWidth < 280 ||
                    MediaQuery.textScalerOf(context).scale(16) > 20;
                final cancelButton = FilledButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  style: FilledButton.styleFrom(
                    backgroundColor: colors.primary,
                    foregroundColor: colors.onPrimary,
                    minimumSize: const Size(0, 48),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    textStyle: buttonStyle,
                    shape: buttonShape,
                  ),
                  child: Text(cancelText, textAlign: TextAlign.center),
                );
                final confirmButton = OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: colors.primary,
                    side: BorderSide(color: colors.outline),
                    minimumSize: const Size(0, 48),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    textStyle: buttonStyle,
                    shape: buttonShape,
                  ),
                  child: Text(confirmText, textAlign: TextAlign.center),
                );
                if (stackButtons) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      cancelButton,
                      const SizedBox(height: 12),
                      confirmButton,
                    ],
                  );
                }
                return Row(
                  children: [
                    Expanded(child: cancelButton),
                    const SizedBox(width: 12),
                    Expanded(child: confirmButton),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

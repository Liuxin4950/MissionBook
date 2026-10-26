import 'package:flutter/material.dart'; // 引入 Flutter 主题组件

import 'app_typography.dart';
import 'colors.dart'; // 引入全局颜色令牌

abstract final class AppTheme {
  // 按下、悬停、键盘聚焦只显示轻微底色，不使用扩散的大水波纹。
  static WidgetStateProperty<Color?> _feedback(Color color) =>
      WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.disabled)) return null;
        if (states.contains(WidgetState.pressed)) {
          return color.withValues(alpha: .06);
        }
        if (states.contains(WidgetState.focused)) {
          return color.withValues(alpha: .08);
        }
        if (states.contains(WidgetState.hovered)) {
          return color.withValues(alpha: .03);
        }
        return null;
      });
  // 全局主题配置
  static final ThemeData light = ThemeData(
    // 浅色主题
    useMaterial3: true, // 使用 Material 3 设计规范
    splashFactory: NoSplash.splashFactory,
    highlightColor: AppColors.primary.withValues(alpha: .04),
    hoverColor: AppColors.primary.withValues(alpha: .03),
    focusColor: AppColors.primary.withValues(alpha: .08),
    scaffoldBackgroundColor: AppColors.background, // 页面背景
    textTheme: AppTypography.textTheme,
    iconTheme: const IconThemeData(color: AppColors.textSecondary),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: AppColors.textPrimary,
      contentTextStyle: AppTypography.textTheme.bodyMedium?.copyWith(
        color: AppColors.onPrimary,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
    ),
    cardTheme: CardThemeData(
      color: AppColors.card,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      clipBehavior: Clip.antiAlias,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.card,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      floatingLabelBehavior: FloatingLabelBehavior.always,
      alignLabelWithHint: true,
      labelStyle: AppTypography.textTheme.titleSmall,
      hintStyle: AppTypography.textTheme.bodyLarge?.copyWith(
        color: AppColors.textSecondary,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.hairline),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.hairline),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.error),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.error, width: 1.5),
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: AppColors.card,
      selectedColor: AppColors.primarySoft,
      labelStyle: AppTypography.textTheme.labelMedium?.copyWith(
        color: AppColors.textPrimary,
      ),
      checkmarkColor: AppColors.primary,
      side: const BorderSide(color: AppColors.hairline),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: AppColors.background,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: AppColors.card,
      textStyle: AppTypography.textTheme.bodyMedium?.copyWith(
        color: AppColors.textPrimary,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style:
          FilledButton.styleFrom(
            textStyle: AppTypography.textTheme.labelLarge,
            minimumSize: const Size(48, 48),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ).copyWith(
            splashFactory: NoSplash.splashFactory,
            overlayColor: _feedback(AppColors.onPrimary),
          ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style:
          OutlinedButton.styleFrom(
            textStyle: AppTypography.textTheme.labelLarge,
            minimumSize: const Size(48, 48),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ).copyWith(
            splashFactory: NoSplash.splashFactory,
            overlayColor: _feedback(AppColors.primary),
          ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(textStyle: AppTypography.textTheme.labelLarge)
          .copyWith(
            splashFactory: NoSplash.splashFactory,
            overlayColor: _feedback(AppColors.primary),
          ),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: ButtonStyle(
        splashFactory: NoSplash.splashFactory,
        overlayColor: _feedback(AppColors.primary),
      ),
    ),
    appBarTheme: const AppBarThemeData(
      // 顶部导航栏主题
      backgroundColor: AppColors.background, // 顶栏背景
      foregroundColor: AppColors.textPrimary, // 顶栏文字和图标
      elevation: 0, // 移除阴影
      scrolledUnderElevation: 0, // 滚动时不增加阴影
    ),
    colorScheme:
        ColorScheme.fromSeed(
          // 生成基础配色方案
          seedColor: AppColors.primary, // 品牌主色
          brightness: Brightness.light, // 浅色模式
        ).copyWith(
          // 覆盖需要固定的设计颜色
          primary: AppColors.primary, // 主色
          onPrimary: AppColors.onPrimary, // 主色上的内容
          primaryContainer: AppColors.primarySoft, // 主色容器
          onPrimaryContainer: AppColors.textPrimary, // 主色容器上的内容
          secondary: AppColors.primary, // 普通辅助控件不自动获得柑橘强调色
          onSecondary: AppColors.onPrimary,
          secondaryContainer: AppColors.surfaceMuted,
          onSecondaryContainer: AppColors.textPrimary,
          tertiary: AppColors.accent, // 明确需要小面积强调时才选用
          onTertiary: AppColors.textPrimary,
          tertiaryContainer: AppColors.accentSoft,
          onTertiaryContainer: AppColors.textPrimary,
          surface: AppColors.background, // 基础表面
          surfaceDim: AppColors.surfaceMuted,
          surfaceBright: AppColors.card,
          surfaceContainerLowest: AppColors.card,
          surfaceContainerLow: AppColors.card, // 白色卡片表面
          surfaceContainer: AppColors.surfaceMuted,
          surfaceContainerHigh: AppColors.surfaceMuted,
          surfaceContainerHighest: AppColors.hairline,
          surfaceTint: Colors.transparent, // 普通容器不额外叠一层品牌染色
          onSurface: AppColors.textPrimary, // 主要文字
          onSurfaceVariant: AppColors.textSecondary, // 次级文字
          outline: AppColors.outline, // 控件边界
          outlineVariant: AppColors.hairline, // 弱分隔线
          error: AppColors.error, // 错误颜色
          onError: AppColors.onPrimary, // 错误色上的内容
          errorContainer: AppColors.errorSoft, // 错误提示背景
          onErrorContainer: AppColors.error, // 错误提示文字
        ),
    navigationBarTheme: const NavigationBarThemeData(
      // 底部导航主题
      backgroundColor: AppColors.card, // 导航栏背景
      indicatorColor: AppColors.primarySoft, // 导航是位置提示，低于主操作的强调级别
      elevation: 0, // 移除阴影
    ),
    dividerTheme: const DividerThemeData(
      // 分隔线主题
      color: AppColors.hairline, // 分隔线颜色
      thickness: 1, // 分隔线粗细
    ),
  );
}

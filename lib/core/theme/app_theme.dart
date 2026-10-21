import 'package:flutter/material.dart'; // 引入 Flutter 主题组件

import 'colors.dart'; // 引入全局颜色令牌

abstract final class AppTheme {
  // 全局主题配置
  static final ThemeData light = ThemeData(
    // 浅色主题
    useMaterial3: true, // 使用 Material 3 设计规范
    scaffoldBackgroundColor: AppColors.background, // 页面背景
    textTheme: const TextTheme(
      headlineSmall: TextStyle(
        fontSize: 28,
        height: 36 / 28,
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
      ),
      titleLarge: TextStyle(
        fontSize: 16,
        height: 24 / 16,
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
      ),
      titleMedium: TextStyle(
        fontSize: 18,
        height: 24 / 18,
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
      ),
      bodyMedium: TextStyle(
        fontSize: 14,
        height: 20 / 14,
        color: AppColors.textSecondary,
      ),
      bodySmall: TextStyle(
        fontSize: 12,
        height: 16 / 12,
        color: AppColors.textSecondary,
      ),
    ), // 字体角色与当前设计令牌一致
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
          secondary: AppColors.accent, // 强调色
          onSecondary: AppColors.textPrimary, // 柑橘面使用深色文字
          secondaryContainer: AppColors.accent, // 强调色容器
          onSecondaryContainer: AppColors.textPrimary, // 强调容器上的内容
          surface: AppColors.background, // 基础表面
          surfaceContainerLow: AppColors.card, // 白色卡片表面
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
      indicatorColor: AppColors.primary, // 选中项背景
      elevation: 0, // 移除阴影
    ),
    dividerTheme: const DividerThemeData(
      // 分隔线主题
      color: AppColors.hairline, // 分隔线颜色
      thickness: 1, // 分隔线粗细
    ),
  );
}

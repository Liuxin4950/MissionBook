import 'package:flutter/material.dart';

import 'colors.dart';

/// 全站字号按用途集中定义；页面只选择角色，不再自行填写字号和行高。
abstract final class AppTypography {
  static const textTheme = TextTheme(
    displaySmall: TextStyle(
      fontSize: 48,
      height: 56 / 48,
      fontWeight: FontWeight.w700,
      color: AppColors.textPrimary,
    ), // 执行页专注时长，其余页面不使用这个大数字角色。
    headlineSmall: TextStyle(
      fontSize: 28,
      height: 36 / 28,
      fontWeight: FontWeight.w600,
      color: AppColors.textPrimary,
    ), // 页面主体标题，例如“今天”和详情中的完整任务名。
    titleLarge: TextStyle(
      fontSize: 20,
      height: 28 / 20,
      fontWeight: FontWeight.w600,
      color: AppColors.textPrimary,
    ), // 弹框标题。
    titleMedium: TextStyle(
      fontSize: 16,
      height: 24 / 16,
      fontWeight: FontWeight.w600,
      color: AppColors.textPrimary,
    ), // 区块、顶栏和列表任务名使用同一层级。
    titleSmall: TextStyle(
      fontSize: 14,
      height: 20 / 14,
      fontWeight: FontWeight.w500,
      color: AppColors.textPrimary,
    ), // 表单外置标签。
    bodyLarge: TextStyle(
      fontSize: 18,
      height: 24 / 18,
      fontWeight: FontWeight.w500,
      color: AppColors.textPrimary,
    ), // 输入值和详情计划主值。
    bodyMedium: TextStyle(
      fontSize: 14,
      height: 20 / 14,
      fontWeight: FontWeight.w400,
      color: AppColors.textSecondary,
    ), // 正文、日期、时间和状态。
    bodySmall: TextStyle(
      fontSize: 12,
      height: 16 / 12,
      fontWeight: FontWeight.w400,
      color: AppColors.textSecondary,
    ), // 年份、时区等短辅助标识。
    labelLarge: TextStyle(
      fontSize: 16,
      height: 24 / 16,
      fontWeight: FontWeight.w600,
    ), // 主操作和整页次级操作；颜色由按钮的状态主题处理。
    labelMedium: TextStyle(
      fontSize: 14,
      height: 20 / 14,
      fontWeight: FontWeight.w600,
    ), // 分段选项和列表内快捷动作。
    labelSmall: TextStyle(
      fontSize: 12,
      height: 16 / 12,
      fontWeight: FontWeight.w500,
    ), // 数量徽标、底部导航。
  );
}

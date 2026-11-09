import 'package:flutter/material.dart';

import 'colors.dart';

/// 全站字号按用途集中定义；页面选择文字角色，不自行设置字号或行高。
abstract final class AppTypography {
  // 品牌和执行计时是明确的展示场景，不用于普通标题或统计数字。
  static const brandTitle = TextStyle(
    fontSize: 34,
    height: 1.2,
    letterSpacing: -.8,
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimary,
  );
  static const brandTitleCompact = TextStyle(
    fontSize: 30,
    height: 1.2,
    letterSpacing: -.8,
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimary,
  );
  static const executionTimer = TextStyle(
    fontSize: 48,
    height: 56 / 48,
    fontWeight: FontWeight.w500,
    color: AppColors.textPrimary,
  );
  static const pageTitle = TextStyle(
    fontSize: 20,
    height: 28 / 20,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
  );
  static const dialogTitle = TextStyle(
    fontSize: 16,
    height: 24 / 16,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
  );
  static const sectionTitle = TextStyle(
    fontSize: 14,
    height: 20 / 14,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
  );
  static const itemTitle = TextStyle(
    fontSize: 12,
    height: 16 / 12,
    fontWeight: FontWeight.w500,
    color: AppColors.textPrimary,
  );
  static const readingBody = TextStyle(
    fontSize: 14,
    height: 20 / 14,
    fontWeight: FontWeight.w400,
    color: AppColors.textPrimary,
  );
  static const metadata = TextStyle(
    fontSize: 12,
    height: 16 / 12,
    fontWeight: FontWeight.w400,
    color: AppColors.textSecondary,
  );

  /// 密集周表的星期和日期；保留系统缩放，完整信息由日期入口提供。
  static const calendarLabel = TextStyle(
    fontSize: 11,
    height: 14 / 11,
    fontWeight: FontWeight.w500,
    color: AppColors.textSecondary,
  );
  // 操作文字继承按钮前景色，不在文字角色中固定品牌色。
  static const primaryAction = TextStyle(
    fontSize: 14,
    height: 20 / 14,
    fontWeight: FontWeight.w600,
  );
  static const secondaryAction = TextStyle(
    fontSize: 12,
    height: 16 / 12,
    fontWeight: FontWeight.w500,
  );

  /// 补齐 Material 所有文字档位，避免未指定的档位回落到系统的大字号。
  /// 正文阅读及输入用 bodyLarge；普通说明、日期和状态用 bodyMedium/Small。
  static const textTheme = TextTheme(
    displayLarge: executionTimer,
    displayMedium: executionTimer,
    displaySmall: executionTimer,
    headlineLarge: pageTitle,
    headlineMedium: pageTitle,
    headlineSmall: pageTitle,
    titleLarge: dialogTitle,
    titleMedium: sectionTitle,
    titleSmall: itemTitle,
    bodyLarge: readingBody,
    bodyMedium: metadata,
    bodySmall: metadata,
    labelLarge: primaryAction,
    labelMedium: secondaryAction,
    labelSmall: secondaryAction,
  );
}

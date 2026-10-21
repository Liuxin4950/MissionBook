import 'package:flutter/material.dart'; // 引入 Flutter 颜色类型

// 设计页面的全局统一颜色来源 设计令牌
// 禁止其他页面单独设计颜色，必须从这里引用
abstract final class AppColors {
  // 全局颜色设计令牌
  static const Color background = Color(0xFFF7F8F2); // 当前正稿的暖白背景
  static const Color card = Color(0xFFFFFFFF); // 导航与卡片的白色表面
  static const Color onPrimary = Color(0xFFFFFFFF); // 主色上的内容
  static const Color primary = Color(0xFF244D3D); // 森林绿主色
  static const Color primarySoft = Color(0xFFE8EDE4); // 图标与徽标的柔和底
  static const Color accent = Color(0xFFD7F57B); // 柑橘强调面与选中导航内容
  static const Color textPrimary = Color(0xFF233B30); // 主文字
  static const Color textSecondary = Color(0xFF617067); // 次级文字
  static const Color hairline = Color(0xFFDCE3D8); // 时间轴连线与装饰分隔线
  static const Color primaryPressed = Color(0xFF1B3B2F); // 按下的森林绿
  static const Color outline = Color(0xFF617067); // 控件边界
  static const Color disabled = Color(0xFFE4E7DF); // 禁用底色
  static const Color onDisabled = Color(0xFF5E675F); // 禁用文字
  static const Color error = Color(0xFFA35448); // 错误红棕
  static const Color errorSoft = Color(0xFFF8EAE6); // 错误浅底
  static const Color warning = Color(0xFF805D28); // 提醒棕
  static const Color warningSoft = Color(0xFFF4EBDD); // 提醒浅底
}

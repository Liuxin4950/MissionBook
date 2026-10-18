import 'package:flutter/material.dart'; // 引入 Flutter 颜色类型

// 设计页面的全局统一颜色来源 设计令牌
// 禁止其他页面单独设计颜色，必须从这里引用
abstract final class AppColors { // 全局颜色设计令牌
  static const Color background = Color(0xFFF7F5ED); // 暖白背景
  static const Color card = Color(0xFFF6F3EB); // 浅米卡片
  static const Color onPrimary = Color(0xFFFFFFFF); // 主色上的内容
  static const Color primary = Color(0xFF4A6A57); // 墨绿主色
  static const Color primarySoft = Color(0xFFE8EEE5); // 浅绿选中底
  static const Color accent = Color(0xFF4F8768); // 装饰强调绿
  static const Color textPrimary = Color(0xFF242B26); // 深墨文字
  static const Color textSecondary = Color(0xFF626B63); // 次级灰绿
  static const Color hairline = Color(0xFFE3E2D8); // 装饰分隔线
  static const Color primaryPressed = Color(0xFF3D5948); // 按下墨绿
  static const Color outline = Color(0xFF858D83); // 控件边界
  static const Color disabled = Color(0xFFE4E7DF); // 禁用底色
  static const Color onDisabled = Color(0xFF5E675F); // 禁用文字
  static const Color error = Color(0xFFA35448); // 错误红棕
  static const Color errorSoft = Color(0xFFF8EAE6); // 错误浅底
  static const Color warning = Color(0xFF805D28); // 提醒棕
  static const Color warningSoft = Color(0xFFF4EBDD); // 提醒浅底
}

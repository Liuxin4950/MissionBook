import 'package:flutter/material.dart'; // 引入 Flutter 颜色类型

// 设计页面的全局统一颜色来源 设计令牌
// 禁止其他页面单独设计颜色，必须从这里引用
abstract final class AppColors {
  // 全局颜色设计令牌
  static const Color background = Color(0xFFF7F8F5); // 中性暖白页面底，不用品牌色铺满页面
  static const Color card = Color(0xFFFFFFFF); // 导航与卡片的白色表面
  static const Color surfaceMuted = Color(0xFFF0F2EE); // 分类轨道、普通控件与低强调容器
  static const Color onPrimary = Color(0xFFFFFFFF); // 主色上的内容
  static const Color primary = Color(0xFF244D3D); // 森林绿品牌与主操作，小面积使用
  static const Color primarySoft = Color(0xFFEEF2EC); // 品牌相关图标、导航选中项的浅底
  static const Color accent = Color(0xFFD9F28B); // 柑橘强调色，仅用于小面积当前状态
  static const Color accentSoft = Color(0xFFF1F6E6); // 需要上下文提示时使用的低强调面
  static const Color textPrimary = Color(0xFF282E2A); // 中性深灰文字，内容不全部染成绿色
  static const Color textSecondary = Color(0xFF626A64); // 次级文字
  static const Color hairline = Color(0xFFE0E5DD); // 时间轴连线与装饰分隔线
  static const Color primaryPressed = Color(0xFF1B3B2F); // 按下的森林绿
  static const Color outline = Color(0xFF626A64); // 控件边界
  static const Color disabled = Color(0xFFE4E7DF); // 禁用底色
  static const Color onDisabled = Color(0xFF5E675F); // 禁用文字
  static const Color error = Color(0xFFA35448); // 错误红棕
  static const Color errorSoft = Color(0xFFF8EAE6); // 错误浅底
  static const Color warning = Color(0xFF805D28); // 提醒棕
  static const Color warningSoft = Color(0xFFF4EBDD); // 提醒浅底
}

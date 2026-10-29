import 'package:flutter/material.dart';

import '../../application/assistant/assistant_settings.dart';

/// 助手身份复用应用现有线性图标体系，尺寸由所在控件决定。
IconData assistantAvatarIcon(AssistantAvatar avatar) => switch (avatar) {
  AssistantAvatar.spark => Icons.auto_awesome_outlined,
  AssistantAvatar.book => Icons.menu_book_outlined,
  AssistantAvatar.compass => Icons.explore_outlined,
};

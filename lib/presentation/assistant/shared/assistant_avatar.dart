import 'dart:convert';

import 'package:flutter/material.dart';

import '../../../application/assistant/assistant_settings.dart';

/// 按角色选择显示书祺头像或线性图标，尺寸由所在控件决定。
class AssistantPersonaAvatar extends StatefulWidget {
  const AssistantPersonaAvatar({
    super.key,
    required this.avatar,
    required this.size,
    this.color,
    this.customAvatarBase64,
  });

  final AssistantAvatar avatar;
  final double size;
  final Color? color;
  final String? customAvatarBase64;

  @override
  State<AssistantPersonaAvatar> createState() => _AssistantPersonaAvatarState();
}

class _AssistantPersonaAvatarState extends State<AssistantPersonaAvatar> {
  MemoryImage? _customImage;

  @override
  void initState() {
    super.initState();
    _readImage();
  }

  @override
  void didUpdateWidget(AssistantPersonaAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.customAvatarBase64 != widget.customAvatarBase64) _readImage();
  }

  void _readImage() {
    final value = widget.customAvatarBase64;
    try {
      _customImage = value == null ? null : MemoryImage(base64Decode(value));
    } on FormatException {
      _customImage = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_customImage case final image?) {
      return ClipOval(
        child: Image(
          image: image,
          width: widget.size,
          height: widget.size,
          fit: BoxFit.cover,
          excludeFromSemantics: true,
          errorBuilder: (_, _, _) => _builtInAvatar(context),
        ),
      );
    }
    return _builtInAvatar(context);
  }

  Widget _builtInAvatar(BuildContext context) {
    if (widget.avatar == AssistantAvatar.spark) {
      return ClipOval(
        child: Image.asset(
          'assets/branding/shuqi-avatar.png',
          width: widget.size,
          height: widget.size,
          fit: BoxFit.contain,
          cacheWidth: (widget.size * MediaQuery.devicePixelRatioOf(context))
              .ceil(),
          excludeFromSemantics: true,
        ),
      );
    }
    return Icon(
      widget.avatar == AssistantAvatar.book
          ? Icons.menu_book_outlined
          : Icons.explore_outlined,
      size: widget.size,
      color: widget.color,
    );
  }
}

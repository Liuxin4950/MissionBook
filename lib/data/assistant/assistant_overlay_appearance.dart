import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../../application/assistant/assistant_settings.dart';

/// 将已保存角色的展示字段同步给 Android 系统气泡。
Future<void> syncAssistantOverlayPersona(AssistantPersona persona) async {
  if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
  try {
    await const MethodChannel(
      'mission_book/device',
    ).invokeMethod<void>('syncAssistantOverlayPersona', {
      'name': persona.name,
      'avatar': persona.avatar.name,
      'customAvatarBase64': persona.customAvatarBase64,
    });
  } on MissingPluginException {
    // 测试环境未装配 Android 系统桥。
  } on PlatformException {
    // 展示同步失败不使已保存的角色设置失效，下次读取时重试。
  }
}

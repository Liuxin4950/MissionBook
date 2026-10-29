import 'dart:convert';
import 'package:agent_core/agent_core.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../application/assistant/assistant_settings.dart';
export '../../application/assistant/assistant_settings.dart';

/// API Key 与操作偏好只进设备安全存储，不进入 Drift、会话或备份。
class SecureAssistantSettingsStore implements AssistantSettingsStore {
  const SecureAssistantSettingsStore({
    FlutterSecureStorage storage = const FlutterSecureStorage(
      aOptions: AndroidOptions(encryptedSharedPreferences: true),
    ),
  }) : _storage = storage;

  static const _apiKeyPrefix = 'assistant_credential_';
  static const _customProfileKey = 'assistant_custom_profile';
  static const _modelProfileKey = 'assistant_model_profile';
  static const _autoApproveKey = 'assistant_auto_approve_writes';
  final FlutterSecureStorage _storage;

  @override
  Future<AssistantSettings> load() async {
    final apiKey = await resolveCredential('DEEPSEEK_API_KEY');
    final profile = await _storage.read(key: _modelProfileKey);
    final customJson = await _storage.read(key: _customProfileKey);
    final custom = customJson == null
        ? null
        : ModelProfile.fromJson(
            Map<String, Object?>.from(jsonDecode(customJson) as Map),
          );
    final customKey = await resolveCredential('MISSIONBOOK_CUSTOM_API_KEY');
    final autoApprove = await _storage.read(key: _autoApproveKey);
    return AssistantSettings(
      hasCredential: profile == 'custom' ? customKey != null : apiKey != null,
      hasDeepSeekCredential: apiKey != null,
      hasCustomCredential: customKey != null,
      customProfile: custom,
      modelProfileId: profile == 'custom' && custom != null
          ? 'custom'
          : profile == 'deepseek'
          ? 'deepseek'
          : 'deepseek-chat',
      autoApproveWrites: autoApprove == 'true',
    );
  }

  @override
  Future<String?> resolveCredential(String credentialKey) async {
    if (![
      'DEEPSEEK_API_KEY',
      'MISSIONBOOK_CUSTOM_API_KEY',
    ].contains(credentialKey)) {
      return null;
    }
    final value = await _storage.read(key: '$_apiKeyPrefix$credentialKey');
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }

  @override
  Future<void> saveCredential(String credentialKey, String value) async {
    if (![
      'DEEPSEEK_API_KEY',
      'MISSIONBOOK_CUSTOM_API_KEY',
    ].contains(credentialKey)) {
      throw ArgumentError('未知凭据标识：$credentialKey');
    }
    final key = '$_apiKeyPrefix$credentialKey';
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      await _storage.delete(key: key);
    } else {
      await _storage.write(key: key, value: trimmed);
    }
  }

  @override
  Future<void> saveModelProfile(String profileId) async {
    if (!['deepseek-chat', 'deepseek', 'custom'].contains(profileId)) {
      throw ArgumentError('不支持的模型配置：$profileId');
    }
    await _storage.write(key: _modelProfileKey, value: profileId);
  }

  @override
  Future<void> saveCustomProfile(ModelProfile profile) async {
    if (profile.id != 'custom' ||
        profile.credentialKey != 'MISSIONBOOK_CUSTOM_API_KEY') {
      throw ArgumentError('自定义模型必须使用独立的固定配置与凭据标识');
    }
    await _storage.write(
      key: _customProfileKey,
      value: jsonEncode(profile.toJson()),
    );
  }

  @override
  Future<void> saveAutoApproveWrites(bool value) async {
    await _storage.write(key: _autoApproveKey, value: '$value');
  }
}

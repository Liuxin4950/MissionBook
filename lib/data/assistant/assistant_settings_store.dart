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
  static const _permissionKey = 'assistant_permission_mode';
  static const _speechKey = 'assistant_speech_settings';
  static const _personaKey = 'assistant_persona';
  final FlutterSecureStorage _storage;

  @override
  Future<AssistantSettings> load() async {
    final apiKey = await resolveCredential('DEEPSEEK_API_KEY');
    final profile = await _storage.read(key: _modelProfileKey);
    final customJson = await _storage.read(key: _customProfileKey);
    final custom = customJson == null
        ? null
        : ModelProfile.fromJson(
            Map<String, Object?>.from(
              jsonDecode(customJson) as Map<String, dynamic>,
            ),
          );
    final customKey = await resolveCredential('MISSIONBOOK_CUSTOM_API_KEY');
    final autoApprove = await _storage.read(key: _autoApproveKey);
    final permission = await _storage.read(key: _permissionKey);
    final speechJson = await _storage.read(key: _speechKey);
    final speech = speechJson == null
        ? <String, dynamic>{}
        : jsonDecode(speechJson) as Map<String, dynamic>;
    final personaJson = await _storage.read(key: _personaKey);
    return AssistantSettings(
      hasCredential: profile == 'custom' ? customKey != null : apiKey != null,
      hasDeepSeekCredential: apiKey != null,
      hasCustomCredential: customKey != null,
      customProfile: custom,
      persona: personaJson == null
          ? const AssistantPersona()
          : AssistantPersona.fromJson(
              Map<String, Object?>.from(
                jsonDecode(personaJson) as Map<String, dynamic>,
              ),
            ),
      hasTranscriptionCredential:
          await resolveCredential('MISSIONBOOK_TRANSCRIPTION_API_KEY') != null,
      speech: AssistantSpeechSettings(
        useTranscription: speech['useTranscription'] == true,
        endpoint: speech['endpoint'] as String? ?? '',
        model: speech['model'] as String? ?? '',
      ),
      modelProfileId: profile == 'custom' && custom != null
          ? 'custom'
          : profile == 'deepseek'
          ? 'deepseek'
          : 'deepseek-chat',
      permissionMode:
          AssistantPermissionMode.values
              .where((mode) => mode.name == permission)
              .firstOrNull ??
          (autoApprove == 'true'
              ? AssistantPermissionMode.full
              : autoApprove == 'false'
              ? AssistantPermissionMode.relaxed
              : AssistantPermissionMode.full),
    );
  }

  @override
  Future<String?> resolveCredential(String credentialKey) async {
    if (![
      'DEEPSEEK_API_KEY',
      'MISSIONBOOK_CUSTOM_API_KEY',
      'MISSIONBOOK_TRANSCRIPTION_API_KEY',
      'MISSIONBOOK_TAVILY_API_KEY',
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
      'MISSIONBOOK_TRANSCRIPTION_API_KEY',
      'MISSIONBOOK_TAVILY_API_KEY',
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
    await savePermissionMode(
      value ? AssistantPermissionMode.full : AssistantPermissionMode.relaxed,
    );
  }

  @override
  Future<void> savePermissionMode(AssistantPermissionMode mode) async {
    await _storage.write(key: _permissionKey, value: mode.name);
  }

  @override
  Future<void> saveSpeechSettings(AssistantSpeechSettings settings) async {
    settings.validate();
    await _storage.write(
      key: _speechKey,
      value: jsonEncode({
        'useTranscription': settings.useTranscription,
        'endpoint': settings.endpoint,
        'model': settings.model,
      }),
    );
  }

  @override
  Future<void> savePersona(AssistantPersona persona) async {
    persona.validate();
    await _storage.write(key: _personaKey, value: jsonEncode(persona.toJson()));
  }
}

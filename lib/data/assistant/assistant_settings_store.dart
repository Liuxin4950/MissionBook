import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class AssistantSettings {
  const AssistantSettings({
    required this.hasCredential,
    required this.modelProfileId,
    required this.autoApproveWrites,
  });

  final bool hasCredential;
  final String modelProfileId;
  final bool autoApproveWrites;
}

abstract interface class AssistantSettingsStore {
  Future<AssistantSettings> load();
  Future<String?> resolveCredential(String credentialKey);
  Future<void> saveCredential(String credentialKey, String value);
  Future<void> saveModelProfile(String profileId);
  Future<void> saveAutoApproveWrites(bool value);
}

/// API Key 与操作偏好只进设备安全存储，不进入 Drift、会话或备份。
class SecureAssistantSettingsStore implements AssistantSettingsStore {
  const SecureAssistantSettingsStore({
    FlutterSecureStorage storage = const FlutterSecureStorage(
      aOptions: AndroidOptions(encryptedSharedPreferences: true),
    ),
  }) : _storage = storage;

  static const _apiKeyPrefix = 'assistant_credential_';
  static const _modelProfileKey = 'assistant_model_profile';
  static const _autoApproveKey = 'assistant_auto_approve_writes';
  final FlutterSecureStorage _storage;

  @override
  Future<AssistantSettings> load() async {
    final apiKey = await resolveCredential('DEEPSEEK_API_KEY');
    final profile = await _storage.read(key: _modelProfileKey);
    final autoApprove = await _storage.read(key: _autoApproveKey);
    return AssistantSettings(
      hasCredential: apiKey != null && apiKey.isNotEmpty,
      modelProfileId: profile == 'deepseek' ? 'deepseek' : 'deepseek-chat',
      autoApproveWrites: autoApprove == 'true',
    );
  }

  @override
  Future<String?> resolveCredential(String credentialKey) async {
    if (credentialKey != 'DEEPSEEK_API_KEY') return null;
    final value = await _storage.read(key: '$_apiKeyPrefix$credentialKey');
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }

  @override
  Future<void> saveCredential(String credentialKey, String value) async {
    if (credentialKey != 'DEEPSEEK_API_KEY') {
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
    if (profileId != 'deepseek-chat' && profileId != 'deepseek') {
      throw ArgumentError('不支持的模型配置：$profileId');
    }
    await _storage.write(key: _modelProfileKey, value: profileId);
  }

  @override
  Future<void> saveAutoApproveWrites(bool value) async {
    await _storage.write(key: _autoApproveKey, value: '$value');
  }
}

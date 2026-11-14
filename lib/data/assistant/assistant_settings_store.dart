import 'dart:convert';

import 'assistant_overlay_appearance.dart';
import 'package:agent_core/agent_core.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../application/assistant/assistant_provider_catalog.dart';
import '../../application/assistant/assistant_settings.dart';

export '../../application/assistant/assistant_provider_catalog.dart';
export '../../application/assistant/assistant_settings.dart';

/// 模型目录、凭据与操作偏好只进设备安全存储。
///
/// 目录本身是一个带版本的 JSON 文档；API Key 按独立 `credentialRef` 保存，
/// 不进入目录、Drift、会话或日志。旧固定配置仅在目录缺失时作为迁移输入读取。
class SecureAssistantSettingsStore implements AssistantSettingsStore {
  const SecureAssistantSettingsStore({
    FlutterSecureStorage storage = const FlutterSecureStorage(
      aOptions: AndroidOptions(encryptedSharedPreferences: true),
    ),
  }) : _storage = storage;

  static const _apiKeyPrefix = 'assistant_credential_';
  static const _catalogKey = 'assistant_provider_catalog';
  static const _catalogBackupKey = 'assistant_provider_catalog_corrupt_backup';
  // 迁移输入；成功写入目录后不再读写。
  static const _legacyModelProfileKey = 'assistant_model_profile';
  static const _legacyCustomProfileKey = 'assistant_custom_profile';
  static const _permissionKey = 'assistant_permission_mode';
  static const _speechKey = 'assistant_speech_settings';
  static const _personaKey = 'assistant_persona';
  static const _reasoningKey = 'assistant_reasoning_efforts';
  final FlutterSecureStorage _storage;

  @override
  Future<AssistantSettings> load() async {
    final catalogJson = await _storage.read(key: _catalogKey);
    ProviderCatalog? catalog;
    String? warning;

    if (catalogJson != null) {
      try {
        catalog = ProviderCatalog.fromJson(
          Map<String, Object?>.from(jsonDecode(catalogJson) as Map),
        );
      } on Object {
        // 目录损坏不能拖垮助手初始化：先留备份，再用旧配置或默认值恢复。
        warning = '模型配置已损坏，已恢复为可用配置，请重新检查服务与凭据';
        try {
          await _storage.write(key: _catalogBackupKey, value: catalogJson);
        } on Object {
          // 备份失败不影响恢复流程。
        }
      }
    }

    catalog ??= await _migrateLegacy(persist: true);

    final configured = <String>{};
    for (final ref in {
      for (final provider in catalog.providers) provider.credentialRef,
    }) {
      if (await resolveCredential(ref) != null) configured.add(ref);
    }

    final speechJson = await _storage.read(key: _speechKey);
    final speech = speechJson == null
        ? <String, dynamic>{}
        : jsonDecode(speechJson) as Map<String, dynamic>;
    final personaJson = await _storage.read(key: _personaKey);
    final reasoningJson = await _storage.read(key: _reasoningKey);
    final reasoning = reasoningJson == null
        ? <String, Object?>{}
        : Map<String, Object?>.from(jsonDecode(reasoningJson) as Map);
    final persona = personaJson == null
        ? const AssistantPersona()
        : AssistantPersona.fromJson(
            Map<String, Object?>.from(jsonDecode(personaJson) as Map),
          );
    await syncAssistantOverlayPersona(persona);
    final permission = await _storage.read(key: _permissionKey);
    final reasoningEfforts = <String, ReasoningEffort>{};
    for (final entry in reasoning.entries) {
      final effort = ReasoningEffort.values.asNameMap()[entry.value];
      if (effort != null) reasoningEfforts[entry.key] = effort;
    }
    return AssistantSettings(
      catalog: catalog,
      configuredCredentials: configured,
      reasoningEfforts: reasoningEfforts,
      persona: persona,
      hasTranscriptionCredential:
          await resolveCredential('MISSIONBOOK_TRANSCRIPTION_API_KEY') != null,
      speech: AssistantSpeechSettings(
        useTranscription: speech['useTranscription'] == true,
        endpoint: speech['endpoint'] as String? ?? '',
        model: speech['model'] as String? ?? '',
      ),
      permissionMode: switch (permission) {
        // 首装没有配置时沿用当前完整权限策略；已保存的损坏值不得静默变成完整权限。
        null => AssistantPermissionMode.full,
        'standard' => AssistantPermissionMode.standard,
        'relaxed' => AssistantPermissionMode.relaxed,
        'full' => AssistantPermissionMode.full,
        _ => throw FormatException('助手权限配置无效，请重新选择权限模式'),
      },
      catalogWarning: warning,
    );
  }

  /// 只在目录缺失（或损坏）时读取旧固定配置；成功后写回目录并清理旧键。
  Future<ProviderCatalog> _migrateLegacy({required bool persist}) async {
    ModelProfile? custom;
    final customJson = await _storage.read(key: _legacyCustomProfileKey);
    if (customJson != null) {
      try {
        custom = ModelProfile.fromJson(
          Map<String, Object?>.from(jsonDecode(customJson) as Map),
        );
      } on Object {
        custom = null;
      }
    }
    final legacyProfileId = await _storage.read(key: _legacyModelProfileKey);
    final catalog = ProviderCatalog.migrateFromLegacy(
      legacyProfileId: legacyProfileId,
      legacyCustomProfile: custom,
    );
    if (!persist) return catalog;
    try {
      await saveCatalog(catalog);
      // 目录成为唯一运行来源后再移除旧键，避免迁移失败时丢失用户配置。
      await _storage.delete(key: _legacyModelProfileKey);
      await _storage.delete(key: _legacyCustomProfileKey);
    } on Object {
      // 写入失败时保留旧键，下次启动可以重试；本次仍以内存目录运行。
    }
    return catalog;
  }

  @override
  Future<String?> resolveCredential(String credentialKey) async {
    if (!isAssistantCredentialRef(credentialKey)) return null;
    final value = await _storage.read(key: '$_apiKeyPrefix$credentialKey');
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }

  @override
  Future<void> saveCredential(String credentialKey, String value) async {
    if (!isAssistantCredentialRef(credentialKey)) {
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
  Future<void> saveCatalog(ProviderCatalog catalog) async {
    // 整份目录一次写入，不产生服务已建、模型未写的半状态。
    await _storage.write(key: _catalogKey, value: jsonEncode(catalog.toJson()));
  }

  @override
  Future<void> saveSelection(ModelSelection selection) async {
    final current = await load();
    final catalog = current.catalog.copyWith(selection: selection);
    await saveCatalog(catalog);
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
    await syncAssistantOverlayPersona(persona);
  }

  @override
  Future<void> saveReasoningEffort(
    String profileId,
    ReasoningEffort effort,
  ) async {
    final saved = await load();
    await _storage.write(
      key: _reasoningKey,
      value: jsonEncode({
        for (final entry in saved.reasoningEfforts.entries)
          entry.key: entry.value.name,
        profileId: effort.name,
      }),
    );
  }
}

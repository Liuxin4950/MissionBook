import 'dart:collection';

import 'package:agent_core/agent_core.dart';
import 'package:mission_book/data/assistant/assistant_settings_store.dart';

class MemoryAssistantSettingsStore implements AssistantSettingsStore {
  ProviderCatalog catalog = ProviderCatalog.defaults();
  final credentials = <String, String>{'DEEPSEEK_API_KEY': 'test-credential'};
  AssistantPermissionMode permissionMode = AssistantPermissionMode.relaxed;
  AssistantSpeechSettings speech = const AssistantSpeechSettings();
  String? transcriptionCredential;
  AssistantPersona persona = const AssistantPersona();
  final reasoningEfforts = <String, ReasoningEffort>{};
  String? warning;
  bool failNextCatalogSave = false;

  String? _pendingDefault;

  String get profileId => catalog.selection.defaultProfileId;

  /// 测试可在构建目录前声明默认模型；目录出现后再真正生效。
  set profileId(String value) {
    _pendingDefault = value;
    if (catalog.models.any((model) => model.profileId == value)) {
      catalog = catalog.copyWith(
        selection: ModelSelection(defaultProfileId: value),
      );
      _pendingDefault = null;
    }
  }

  String? get credential => credentials['DEEPSEEK_API_KEY'];
  set credential(String? value) => _set('DEEPSEEK_API_KEY', value);

  String? get customCredential => credentials['MISSIONBOOK_CUSTOM_API_KEY'];
  set customCredential(String? value) =>
      _set('MISSIONBOOK_CUSTOM_API_KEY', value);

  void _set(String key, String? value) {
    if (value == null || value.trim().isEmpty) {
      credentials.remove(key);
    } else {
      credentials[key] = value.trim();
    }
  }

  @override
  Future<AssistantSettings> load() async {
    final pending = _pendingDefault;
    if (pending != null &&
        catalog.models.any((model) => model.profileId == pending)) {
      catalog = catalog.copyWith(
        selection: catalog.selection.copyWith(defaultProfileId: pending),
      );
      _pendingDefault = null;
    }
    return AssistantSettings(
      catalog: catalog,
      configuredCredentials: {
        for (final entry in credentials.entries)
          if (entry.value.trim().isNotEmpty) entry.key,
      },
      permissionMode: permissionMode,
      speech: speech,
      hasTranscriptionCredential: transcriptionCredential != null,
      persona: persona,
      reasoningEfforts: Map.unmodifiable(reasoningEfforts),
      catalogWarning: warning,
    );
  }

  @override
  Future<String?> resolveCredential(String credentialKey) async =>
      credentialKey == 'MISSIONBOOK_TRANSCRIPTION_API_KEY'
      ? transcriptionCredential
      : credentials[credentialKey];

  @override
  Future<void> savePermissionMode(AssistantPermissionMode mode) async =>
      permissionMode = mode;

  @override
  Future<void> saveSpeechSettings(AssistantSpeechSettings settings) async =>
      speech = settings;

  @override
  Future<void> savePersona(AssistantPersona value) async {
    value.validate();
    persona = value;
  }

  @override
  Future<void> saveCredential(String credentialKey, String value) async {
    if (credentialKey == 'MISSIONBOOK_TRANSCRIPTION_API_KEY') {
      transcriptionCredential = value.trim().isEmpty ? null : value.trim();
    } else {
      _set(credentialKey, value);
    }
  }

  @override
  Future<void> saveCatalog(ProviderCatalog value) async {
    if (failNextCatalogSave) {
      failNextCatalogSave = false;
      throw StateError('模拟目录保存失败');
    }
    catalog = value;
  }

  @override
  Future<void> saveSelection(ModelSelection selection) async =>
      catalog = catalog.copyWith(selection: selection);

  @override
  Future<void> saveReasoningEffort(
    String profileId,
    ReasoningEffort effort,
  ) async => reasoningEfforts[profileId] = effort;
}

class ScriptedModel implements AgentModel {
  ScriptedModel(Iterable<ModelResponse Function(ModelRequest)> responses)
    : _responses = Queue.of(responses);

  final Queue<ModelResponse Function(ModelRequest)> _responses;
  final requests = <ModelRequest>[];

  @override
  Future<ModelResponse> complete(
    ModelRequest request,
    CancellationToken cancellation,
  ) async {
    requests.add(request);
    if (_responses.isEmpty) throw StateError('脚本模型没有更多响应');
    return _responses.removeFirst()(request);
  }
}

ModelResponse textResponse(
  String text, {
  TokenUsage usage = const TokenUsage(),
}) => ModelResponse(
  message: AssistantMessage(
    content: [TextBlock(text: text)],
    provider: 'test',
    model: 'scripted',
  ),
  stopReason: ModelStopReason.completed,
  usage: usage,
);

ModelResponse toolResponse(
  String callId,
  String toolName,
  Map<String, Object?> input,
) => ModelResponse(
  message: AssistantMessage(
    content: [ToolCallBlock(id: callId, name: toolName, input: input)],
    provider: 'test',
    model: 'scripted',
  ),
  stopReason: ModelStopReason.toolUse,
);

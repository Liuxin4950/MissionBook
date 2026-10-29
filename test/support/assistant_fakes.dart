import 'dart:collection';

import 'package:agent_core/agent_core.dart';
import 'package:mission_book/data/assistant/assistant_settings_store.dart';

class MemoryAssistantSettingsStore implements AssistantSettingsStore {
  String? credential = 'test-credential';
  String profileId = 'deepseek-chat';
  bool autoApprove = false;

  @override
  Future<AssistantSettings> load() async => AssistantSettings(
    hasCredential: credential != null && credential!.isNotEmpty,
    modelProfileId: profileId,
    autoApproveWrites: autoApprove,
  );

  @override
  Future<String?> resolveCredential(String credentialKey) async => credential;

  @override
  Future<void> saveAutoApproveWrites(bool value) async => autoApprove = value;

  @override
  Future<void> saveCredential(String credentialKey, String value) async {
    credential = value.trim().isEmpty ? null : value.trim();
  }

  @override
  Future<void> saveModelProfile(String profileId) async =>
      profileId = profileId;
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

ModelResponse textResponse(String text) => ModelResponse(
  message: AssistantMessage(
    content: [TextBlock(text: text)],
    provider: 'test',
    model: 'scripted',
  ),
  stopReason: ModelStopReason.completed,
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

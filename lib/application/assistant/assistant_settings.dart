import 'package:agent_core/agent_core.dart';

class AssistantSettings {
  const AssistantSettings({
    required this.hasCredential,
    required this.modelProfileId,
    required this.autoApproveWrites,
    this.customProfile,
    this.hasDeepSeekCredential,
    this.hasCustomCredential = false,
  });

  final bool hasCredential;
  final bool? hasDeepSeekCredential;
  final bool hasCustomCredential;
  final ModelProfile? customProfile;
  final String modelProfileId;
  final bool autoApproveWrites;
}

abstract interface class AssistantSettingsStore {
  Future<AssistantSettings> load();
  Future<String?> resolveCredential(String credentialKey);
  Future<void> saveCredential(String credentialKey, String value);
  Future<void> saveModelProfile(String profileId);
  Future<void> saveCustomProfile(ModelProfile profile);
  Future<void> saveAutoApproveWrites(bool value);
}

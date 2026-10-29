import 'dart:convert';
import 'package:agent_core/agent_core.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mission_book/data/assistant/assistant_settings_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('自定义服务与DeepSeek凭据独立保存，配置JSON不含Key', () async {
    FlutterSecureStorage.setMockInitialValues({});
    const store = SecureAssistantSettingsStore();
    final profile = ModelProfile(
      id: 'custom',
      provider: 'custom',
      model: 'test-model',
      endpoint: Uri.parse('https://example.invalid/v1/chat/completions'),
      protocol: ModelProtocol.chatCompletions,
      credentialKey: 'MISSIONBOOK_CUSTOM_API_KEY',
      supportsImages: false,
    );
    await store.saveCredential('DEEPSEEK_API_KEY', 'fake-deepseek-credential');
    await store.saveCustomProfile(profile);
    await store.saveCredential(
      'MISSIONBOOK_CUSTOM_API_KEY',
      'fake-custom-credential',
    );
    await store.saveModelProfile('custom');
    var loaded = await store.load();
    expect(loaded.hasCredential, isTrue);
    expect(loaded.customProfile?.model, 'test-model');
    expect(loaded.hasCustomCredential, isTrue);
    expect(loaded.hasDeepSeekCredential, isTrue);
    expect(
      jsonEncode(loaded.customProfile!.toJson()),
      isNot(contains('fake-custom-credential')),
    );
    await store.saveCredential('MISSIONBOOK_CUSTOM_API_KEY', '');
    loaded = await store.load();
    expect(loaded.hasCustomCredential, isFalse);
    expect(loaded.hasCredential, isFalse);
    expect(
      await store.resolveCredential('DEEPSEEK_API_KEY'),
      'fake-deepseek-credential',
    );
    await expectLater(
      store.saveCredential('arbitrary-key', 'fake'),
      throwsArgumentError,
    );
    FlutterSecureStorage.setMockInitialValues({});
  });
}

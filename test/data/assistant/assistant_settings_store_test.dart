import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:agent_core/agent_core.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mission_book/data/assistant/assistant_settings_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('保存和重读角色同步系统悬浮头像，恢复内置头像清除自定义内容', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    const channel = MethodChannel('mission_book/device');
    final calls = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          return null;
        });
    addTearDown(() {
      debugDefaultTargetPlatformOverride = null;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });
    FlutterSecureStorage.setMockInitialValues({});
    const store = SecureAssistantSettingsStore();
    final custom = base64Encode(
      img.encodePng(img.Image(width: 192, height: 192)),
    );
    await store.savePersona(
      AssistantPersona(name: '测试助手', customAvatarBase64: custom),
    );
    expect(calls.last.method, 'syncAssistantOverlayPersona');
    expect(calls.last.arguments['customAvatarBase64'], custom);
    await store.load();
    expect(calls.last.arguments['name'], '测试助手');
    await store.savePersona(
      const AssistantPersona(avatar: AssistantAvatar.compass),
    );
    expect(calls.last.arguments['avatar'], 'compass');
    expect(calls.last.arguments['customAvatarBase64'], isNull);
  });

  test('自定义头像随角色持久化，缺失或损坏头像不影响其他角色字段', () async {
    FlutterSecureStorage.setMockInitialValues({});
    const store = SecureAssistantSettingsStore();
    final avatar = base64Encode(
      img.encodePng(img.Image(width: 192, height: 192)),
    );
    await store.savePersona(
      AssistantPersona(name: '小书', customAvatarBase64: avatar),
    );
    expect((await store.load()).persona.customAvatarBase64, avatar);
    final legacy = AssistantPersona.fromJson({'name': '小书'});
    expect(legacy.customAvatarBase64, isNull);
    final broken = AssistantPersona.fromJson({
      'name': '小书',
      'customAvatarBase64': 'broken',
    });
    expect(broken.name, '小书');
    expect(broken.customAvatarBase64, isNull);
    await expectLater(
      store.savePersona(const AssistantPersona(customAvatarBase64: 'broken')),
      throwsArgumentError,
    );
    expect((await store.load()).persona.customAvatarBase64, avatar);
    await store.savePersona(const AssistantPersona(name: '小书'));
    expect((await store.load()).persona.customAvatarBase64, isNull);
  });
  test('角色名称、定位、回答风格和图标持久化，非法名称不覆盖原配置', () async {
    FlutterSecureStorage.setMockInitialValues({});
    const store = SecureAssistantSettingsStore();
    expect((await store.load()).persona.name, '书祺');
    await store.savePersona(
      const AssistantPersona(
        name: '小书',
        userAddress: '小刘',
        role: AssistantRole.coach,
        replyStyle: AssistantReplyStyle.explanatory,
        avatar: AssistantAvatar.book,
      ),
    );
    final restored = (await store.load()).persona;
    expect(restored.name, '小书');
    expect(restored.userAddress, '小刘');
    expect(AssistantPersona.fromJson({'name': '旧配置'}).userAddress, isEmpty);
    expect(AssistantPersona.fromJson({'role': 'coach'}).name, '书祺');
    await expectLater(
      store.savePersona(const AssistantPersona(userAddress: '含有\n换行')),
      throwsArgumentError,
    );
    expect(restored.role, AssistantRole.coach);
    expect(restored.replyStyle, AssistantReplyStyle.explanatory);
    expect(restored.avatar, AssistantAvatar.book);
    await expectLater(
      store.savePersona(const AssistantPersona(name: '   ')),
      throwsArgumentError,
    );
    expect((await store.load()).persona.name, '小书');
    expect(
      AssistantPersona.fromJson({'name': '阿青', 'role': 'future-value'}).role,
      AssistantRole.assistant,
    );
  });
  test('三档权限持久化，转写凭据独立', () async {
    FlutterSecureStorage.setMockInitialValues({});
    const store = SecureAssistantSettingsStore();
    expect((await store.load()).permissionMode, AssistantPermissionMode.full);
    for (final mode in AssistantPermissionMode.values) {
      await store.savePermissionMode(mode);
      expect((await store.load()).permissionMode, mode);
    }
    FlutterSecureStorage.setMockInitialValues({
      'assistant_permission_mode': 'corrupted',
    });
    await expectLater(store.load(), throwsA(isA<FormatException>()));
    FlutterSecureStorage.setMockInitialValues({});
    await store.saveSpeechSettings(
      const AssistantSpeechSettings(
        useTranscription: true,
        endpoint: 'https://speech.example.invalid/v1/audio/transcriptions',
        model: 'speech-test',
      ),
    );
    await store.saveCredential(
      'MISSIONBOOK_TRANSCRIPTION_API_KEY',
      'fake-voice-key',
    );
    final saved = await store.load();
    expect(saved.speech.useTranscription, isTrue);
    expect(saved.speech.model, 'speech-test');
    expect(saved.hasTranscriptionCredential, isTrue);
    expect(saved.hasCredential, isFalse);
    expect(await store.resolveCredential('DEEPSEEK_API_KEY'), isNull);
  });
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

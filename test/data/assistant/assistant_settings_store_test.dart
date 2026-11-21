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
  test('删除整项服务后读回空目录，不恢复默认服务', () async {
    FlutterSecureStorage.setMockInitialValues({});
    const store = SecureAssistantSettingsStore();
    await store.saveCatalog(
      ProviderCatalog(
        providers: [],
        models: [],
        selection: const ModelSelection(defaultProfileId: null),
      ),
    );
    final loaded = await store.load();
    expect(loaded.catalog.providers, isEmpty);
    expect(loaded.catalog.models, isEmpty);
    expect(loaded.defaultProfileId, isNull);
    final config = loaded.catalog.compileConfiguration(
      base: AgentConfiguration.deepSeek(),
    );
    expect(config.defaultModelProfile, ProviderCatalog.unconfiguredProfileId);
    expect(
      config.profiles.any((profile) => profile.provider == 'deepseek'),
      isFalse,
    );
  });
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
  test('自定义定位和风格独立持久化，旧配置与损坏字段可恢复', () async {
    FlutterSecureStorage.setMockInitialValues({});
    const store = SecureAssistantSettingsStore();
    const persona = AssistantPersona(
      name: '小书',
      customRole: '帮助我练习写作。\n先讨论提纲，再逐段修改。',
      customReplyStyle: '回答先给三个要点，再举一个例子。',
    );
    await store.savePersona(persona);
    final restored = (await store.load()).persona;
    expect(restored.customRole, persona.customRole);
    expect(restored.customReplyStyle, persona.customReplyStyle);
    expect(restored.roleInstruction, persona.customRole);
    expect(restored.roleLabel, '自定义定位');
    final legacy = AssistantPersona.fromJson({'name': '旧配置', 'role': 'coach'});
    expect(legacy.customRole, isNull);
    expect(legacy.roleInstruction, AssistantRole.coach.instruction);
    final partial = AssistantPersona.fromJson({
      'name': '小书',
      'customRole': '无效\u0000内容',
      'customReplyStyle': '只列要点',
    });
    expect(partial.name, '小书');
    expect(partial.customRole, isNull);
    expect(partial.customReplyStyle, '只列要点');
    await expectLater(
      store.savePersona(AssistantPersona(customRole: '长' * 2001)),
      throwsArgumentError,
    );
    expect((await store.load()).persona.customRole, persona.customRole);
    await store.savePersona(
      const AssistantPersona(role: AssistantRole.writing),
    );
    expect((await store.load()).persona.customRole, isNull);
    expect(
      (await store.load()).persona.roleInstruction,
      AssistantRole.writing.instruction,
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
    expect(saved.profileHasCredential(saved.defaultProfileId), isFalse);
    expect(await store.resolveCredential('DEEPSEEK_API_KEY'), isNull);
  });
  test('服务目录、凭据引用与选择持久化，配置 JSON 不含 Key', () async {
    FlutterSecureStorage.setMockInitialValues({});
    const store = SecureAssistantSettingsStore();
    final base = ProviderCatalog.defaults();
    final custom = ProviderConfig(
      providerId: 'custom',
      displayName: '自定义服务',
      baseAddress: 'https://example.invalid/v1',
      protocol: ModelProtocol.chatCompletions,
      credentialRef: 'MISSIONBOOK_CUSTOM_API_KEY',
    );
    final catalog = ProviderCatalog(
      providers: [...base.providers, custom],
      models: [
        ...base.models,
        ProviderModel(
          profileId: 'custom',
          providerId: 'custom',
          modelId: 'test-model',
          supportsImages: false,
        ),
      ],
      selection: const ModelSelection(defaultProfileId: 'custom'),
    );
    await store.saveCredential('DEEPSEEK_API_KEY', 'fake-deepseek-credential');
    await store.saveCatalog(catalog);
    await store.saveCredential(
      'MISSIONBOOK_CUSTOM_API_KEY',
      'fake-custom-credential',
    );
    var loaded = await store.load();
    expect(loaded.defaultProfileId, 'custom');
    expect(loaded.catalog.modelOfProfile('custom')?.modelId, 'test-model');
    expect(loaded.profileHasCredential('custom'), isTrue);
    expect(loaded.profileHasCredential('deepseek-chat'), isTrue);
    expect(
      jsonEncode(loaded.catalog.toJson()),
      isNot(contains('fake-custom-credential')),
    );
    await store.saveCredential('MISSIONBOOK_CUSTOM_API_KEY', '');
    loaded = await store.load();
    expect(loaded.profileHasCredential('custom'), isFalse);
    expect(loaded.profileHasCredential('deepseek-chat'), isTrue);
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

  test('旧固定配置迁移为目录，成功迁移后不再读取旧键', () async {
    final legacyProfile = ModelProfile(
      id: 'custom',
      provider: 'custom',
      model: 'legacy-model',
      endpoint: Uri.parse('https://legacy.invalid/v1/chat/completions'),
      protocol: ModelProtocol.chatCompletions,
      credentialKey: 'MISSIONBOOK_CUSTOM_API_KEY',
      supportsImages: false,
    );
    FlutterSecureStorage.setMockInitialValues({
      'assistant_model_profile': 'custom',
      'assistant_custom_profile': jsonEncode(legacyProfile.toJson()),
      'assistant_credential_MISSIONBOOK_CUSTOM_API_KEY': 'legacy-key',
    });
    const store = SecureAssistantSettingsStore();
    final loaded = await store.load();
    expect(loaded.defaultProfileId, 'custom');
    expect(loaded.catalog.modelOfProfile('custom')?.modelId, 'legacy-model');
    expect(loaded.profileHasCredential('custom'), isTrue);
    // 迁移成功后以目录为唯一来源：再次读取不应重新读取旧键。
    FlutterSecureStorage.setMockInitialValues({
      'assistant_provider_catalog': jsonEncode(
        ProviderCatalog.defaults().toJson(),
      ),
      'assistant_model_profile': 'custom',
      'assistant_custom_profile': jsonEncode(legacyProfile.toJson()),
    });
    final again = await store.load();
    expect(again.defaultProfileId, 'deepseek-chat');
    expect(again.catalog.modelOfProfile('custom'), isNull);
    FlutterSecureStorage.setMockInitialValues({});
  });

  test('目录损坏时回退为可用配置并保留提示，不抛异常', () async {
    FlutterSecureStorage.setMockInitialValues({
      'assistant_provider_catalog': '{not json',
    });
    const store = SecureAssistantSettingsStore();
    final loaded = await store.load();
    expect(loaded.catalog.providers, isNotEmpty);
    expect(loaded.catalog.models, isNotEmpty);
    expect(loaded.catalogWarning, isNotNull);
    FlutterSecureStorage.setMockInitialValues({});
  });

  test('无需凭据的服务在未保存 Key 时也视为可用', () async {
    FlutterSecureStorage.setMockInitialValues({});
    const store = SecureAssistantSettingsStore();
    final base = ProviderCatalog.defaults();
    final local = ProviderConfig(
      providerId: 'local',
      displayName: '本机服务',
      baseAddress: 'http://localhost:11434/v1',
      protocol: ModelProtocol.chatCompletions,
      credentialRef: ProviderCatalog.credentialRefFor('local'),
      requiresCredential: false,
    );
    await store.saveCatalog(
      ProviderCatalog(
        providers: [...base.providers, local],
        models: [
          ...base.models,
          ProviderModel(
            profileId: 'local-model',
            providerId: 'local',
            modelId: 'qwen',
          ),
        ],
        selection: const ModelSelection(defaultProfileId: 'local-model'),
      ),
    );
    final loaded = await store.load();
    expect(loaded.profileHasCredential('local-model'), isTrue);
    expect(loaded.profileHasCredential('deepseek-chat'), isFalse);
    FlutterSecureStorage.setMockInitialValues({});
  });
}

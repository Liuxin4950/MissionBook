import 'package:agent_core/agent_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mission_book/application/assistant/assistant_provider_catalog.dart';

ProviderConfig _provider(
  String id, {
  String baseAddress = 'https://example.invalid/v1',
  ModelProtocol protocol = ModelProtocol.chatCompletions,
  bool requiresCredential = true,
  bool archived = false,
}) => ProviderConfig(
  providerId: id,
  displayName: id,
  baseAddress: baseAddress,
  protocol: protocol,
  credentialRef: ProviderCatalog.credentialRefFor(id),
  requiresCredential: requiresCredential,
  archived: archived,
);

ProviderModel _model(
  String profileId,
  String providerId, {
  String modelId = 'same-model',
  bool archived = false,
}) => ProviderModel(
  profileId: profileId,
  providerId: providerId,
  modelId: modelId,
  archived: archived,
);

void main() {
  test('不同服务可配置相同 modelId，编译后的来源与凭据互不混用', () {
    final catalog = ProviderCatalog(
      providers: [
        _provider('alpha'),
        _provider(
          'beta',
          baseAddress: 'https://beta.invalid/v1',
          protocol: ModelProtocol.messages,
        ),
      ],
      models: [_model('alpha-model', 'alpha'), _model('beta-model', 'beta')],
      selection: const ModelSelection(defaultProfileId: 'alpha-model'),
    );

    final profiles = catalog.compileProfiles();
    final alpha = profiles.singleWhere((item) => item.id == 'alpha-model');
    final beta = profiles.singleWhere((item) => item.id == 'beta-model');
    expect(alpha.model, 'same-model');
    expect(beta.model, 'same-model');
    expect(
      alpha.endpoint.toString(),
      'https://example.invalid/v1/chat/completions',
    );
    expect(beta.endpoint.toString(), 'https://beta.invalid/v1/messages');
    expect(beta.protocol, ModelProtocol.messages);
    expect(alpha.credentialKey, isNot(beta.credentialKey));
    expect(alpha.requiresCredential, isTrue);
  });

  test('无 Key 服务编译为不需要凭据，停用条目仍可回放但不参与选择', () {
    final catalog = ProviderCatalog(
      providers: [
        _provider('local', requiresCredential: false),
        _provider('cloud'),
      ],
      models: [
        _model('local-model', 'local'),
        _model('cloud-model', 'cloud', modelId: 'cloud-model'),
        _model('old-model', 'cloud', modelId: 'old', archived: true),
      ],
      selection: const ModelSelection(defaultProfileId: 'local-model'),
    );

    final local = catalog.compileProfiles().singleWhere(
      (item) => item.id == 'local-model',
    );
    expect(local.requiresCredential, isFalse);
    expect(catalog.isSelectable('local-model'), isTrue);
    expect(catalog.isSelectable('old-model'), isFalse);
    // 停用条目仍编译，历史会话才能找到原配置。
    expect(
      catalog.compileProfiles().any((item) => item.id == 'old-model'),
      isTrue,
    );
    expect(
      catalog.selectableModels.map((model) => model.profileId),
      isNot(contains('old-model')),
    );
  });

  test('摘要模型停用时编译回退到主模型，不静默使用停用配置', () {
    final catalog = ProviderCatalog(
      providers: [_provider('alpha')],
      models: [_model('main-model', 'alpha'), _model('summary-model', 'alpha')],
      selection: const ModelSelection(
        defaultProfileId: 'main-model',
        summaryProfileId: 'summary-model',
      ),
    );
    final archived = catalog.copyWith(
      models: [
        for (final model in catalog.models)
          model.profileId == 'summary-model'
              ? model.copyWith(archived: true)
              : model,
      ],
    );
    final configuration = archived.compileConfiguration(
      base: AgentConfiguration.deepSeek(),
    );
    expect(configuration.defaultModelProfile, 'main-model');
    expect(configuration.summaryModelProfile, 'main-model');
  });

  test('旧固定配置迁移保持原 profileId，选择回退到存在的条目', () {
    final legacy = ModelProfile(
      id: 'custom',
      provider: 'custom',
      model: 'legacy-model',
      endpoint: Uri.parse('https://legacy.invalid/v1/chat/completions'),
      protocol: ModelProtocol.chatCompletions,
      credentialKey: 'MISSIONBOOK_CUSTOM_API_KEY',
      supportsImages: false,
    );
    final migrated = ProviderCatalog.migrateFromLegacy(
      legacyProfileId: 'custom',
      legacyCustomProfile: legacy,
    );
    expect(migrated.selection.defaultProfileId, 'custom');
    expect(migrated.modelOfProfile('custom')?.modelId, 'legacy-model');
    expect(migrated.modelOfProfile('deepseek-chat'), isNotNull);
    expect(migrated.modelOfProfile('deepseek'), isNotNull);

    final fallback = ProviderCatalog.migrateFromLegacy(
      legacyProfileId: 'missing',
    );
    expect(fallback.selection.defaultProfileId, 'deepseek-chat');
  });

  test('无效服务与模型配置在构造时被拒绝', () {
    expect(
      () => ProviderConfig(
        providerId: 'bad id',
        displayName: 'bad',
        baseAddress: 'https://example.invalid',
        protocol: ModelProtocol.chatCompletions,
        credentialRef: 'DEEPSEEK_API_KEY',
      ),
      throwsArgumentError,
    );
    expect(
      () => ProviderConfig(
        providerId: 'ok',
        displayName: 'ok',
        baseAddress: 'ftp://example.invalid',
        protocol: ModelProtocol.chatCompletions,
        credentialRef: 'DEEPSEEK_API_KEY',
      ),
      throwsArgumentError,
    );
    expect(
      () => ProviderModel(profileId: 'model', providerId: 'ok', modelId: ''),
      throwsArgumentError,
    );
    expect(
      () => ProviderModel(
        profileId: 'model',
        providerId: 'ok',
        modelId: 'm',
        contextWindowTokens: 100,
        maxOutputTokens: 200,
      ),
      throwsArgumentError,
    );
    expect(
      () => ProviderCatalog(
        providers: [_provider('ok')],
        models: [_model('a', 'ok'), _model('a', 'ok')],
        selection: const ModelSelection(defaultProfileId: 'a'),
      ),
      throwsArgumentError,
    );
    expect(
      () => ProviderCatalog(
        providers: [_provider('ok')],
        models: [_model('a', 'ok')],
        selection: const ModelSelection(defaultProfileId: 'missing'),
      ),
      throwsArgumentError,
    );
  });
}

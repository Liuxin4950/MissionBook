import 'package:agent_core/agent_core.dart';

import 'assistant_model_catalog.dart';

/// 受控的凭据标识：本应用只允许读取自己写入的安全存储键，拒绝任意键名。
const _legacyCredentialRefs = {
  'DEEPSEEK_API_KEY',
  'MISSIONBOOK_CUSTOM_API_KEY',
  'MISSIONBOOK_TRANSCRIPTION_API_KEY',
  'MISSIONBOOK_TAVILY_API_KEY',
};

final _providerCredentialRef = RegExp(
  r'^MISSIONBOOK_PROVIDER_[A-Z0-9_]{1,64}$',
);

bool isAssistantCredentialRef(String value) =>
    _legacyCredentialRefs.contains(value) ||
    _providerCredentialRef.hasMatch(value);

/// 服务级配置：同一服务下的模型共享地址、协议与凭据引用。
///
/// `providerId` 是应用层稳定身份，不随显示名或模型编号变化。
class ProviderConfig {
  ProviderConfig({
    required this.providerId,
    required this.displayName,
    required this.baseAddress,
    required this.protocol,
    required this.credentialRef,
    this.modelProvider = 'custom',
    this.requiresCredential = true,
    this.archived = false,
  }) {
    if (!RegExp(r'^[A-Za-z0-9_.:-]{1,64}$').hasMatch(providerId)) {
      throw ArgumentError('服务编号只能是字母、数字或 _ . : -');
    }
    if (displayName.trim().isEmpty || displayName.trim().runes.length > 40) {
      throw ArgumentError('服务名称请填写 1–40 个字符');
    }
    final uri = Uri.tryParse(baseAddress.trim());
    if (uri == null ||
        !['http', 'https'].contains(uri.scheme) ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        uri.hasQuery ||
        uri.hasFragment) {
      throw ArgumentError('服务地址需为完整 HTTP 地址，且不包含账号、查询参数或片段');
    }
    if (!isAssistantCredentialRef(credentialRef)) {
      throw ArgumentError('凭据引用不在本应用允许的范围内');
    }
  }

  final String providerId;
  final String displayName;
  final String baseAddress;
  final ModelProtocol protocol;
  final String credentialRef;
  // 模型协议适配身份与目录中的服务编号分开，多个网关可使用同一种适配。
  final String modelProvider;

  /// 本机或内网兼容服务可以不需要 Key；关闭后请求不发送鉴权头。
  final bool requiresCredential;

  /// 停用后从新建会话的模型列表移除，但保留身份供历史会话解析。
  final bool archived;

  ProviderConfig copyWith({
    String? displayName,
    String? baseAddress,
    ModelProtocol? protocol,
    String? credentialRef,
    String? modelProvider,
    bool? requiresCredential,
    bool? archived,
  }) => ProviderConfig(
    providerId: providerId,
    displayName: displayName ?? this.displayName,
    baseAddress: baseAddress ?? this.baseAddress,
    protocol: protocol ?? this.protocol,
    credentialRef: credentialRef ?? this.credentialRef,
    modelProvider: modelProvider ?? this.modelProvider,
    requiresCredential: requiresCredential ?? this.requiresCredential,
    archived: archived ?? this.archived,
  );

  Map<String, Object?> toJson() => {
    'providerId': providerId,
    'displayName': displayName,
    'baseAddress': baseAddress,
    'protocol': protocol.name,
    'credentialRef': credentialRef,
    'modelProvider': modelProvider,
    'requiresCredential': requiresCredential,
    'archived': archived,
  };

  factory ProviderConfig.fromJson(Map<String, Object?> json) => ProviderConfig(
    providerId: _readString(json, 'providerId'),
    displayName: _readString(json, 'displayName'),
    baseAddress: _readString(json, 'baseAddress'),
    protocol: _readEnum(json, 'protocol', ModelProtocol.values),
    credentialRef: _readString(json, 'credentialRef'),
    modelProvider: json['modelProvider'] is String
        ? _readString(json, 'modelProvider')
        : switch (json['providerId']) {
            'deepseek-api' || 'deepseek-anthropic' => 'deepseek',
            _ => 'custom',
          },
    requiresCredential: json['requiresCredential'] != false,
    archived: json['archived'] == true,
  );
}

/// 模型条目：`profileId` 是历史身份，`modelId` 才是发给供应商的编号。
class ProviderModel {
  ProviderModel({
    required this.profileId,
    required this.providerId,
    required this.modelId,
    this.displayName,
    this.contextWindowTokens = 64000,
    this.maxOutputTokens = 4096,
    this.outputTokenLimit,
    this.supportsImages = true,
    this.reasoningEffort = ReasoningEffort.off,
    this.archived = false,
  }) {
    if (!RegExp(r'^[A-Za-z0-9_.:-]{1,64}$').hasMatch(profileId)) {
      throw ArgumentError('模型编号只能是字母、数字或 _ . : -');
    }
    if (modelId.trim().isEmpty) throw ArgumentError('请填写模型编号');
    if (contextWindowTokens <= maxOutputTokens) {
      throw ArgumentError('上下文窗口必须大于日常输出预算');
    }
    if (maxOutputTokens < 1) throw ArgumentError('日常输出预算必须大于零');
    if (outputTokenLimit != null &&
        (outputTokenLimit! < 1 || maxOutputTokens > outputTokenLimit!)) {
      throw ArgumentError('日常输出预算不能超过模型输出上限');
    }
  }

  final String profileId;
  final String providerId;
  final String modelId;
  final String? displayName;
  final int contextWindowTokens;
  final int maxOutputTokens;
  final int? outputTokenLimit;
  final bool supportsImages;
  final ReasoningEffort reasoningEffort;
  final bool archived;

  /// 选择列表与历史标签使用的名称；未设置显示名时退回供应商编号。
  String get label =>
      displayName?.trim().isNotEmpty == true ? displayName!.trim() : modelId;

  ProviderModel copyWith({
    String? modelId,
    String? displayName,
    int? contextWindowTokens,
    int? maxOutputTokens,
    int? outputTokenLimit,
    bool? supportsImages,
    ReasoningEffort? reasoningEffort,
    bool? archived,
  }) => ProviderModel(
    profileId: profileId,
    providerId: providerId,
    modelId: modelId ?? this.modelId,
    displayName: displayName ?? this.displayName,
    contextWindowTokens: contextWindowTokens ?? this.contextWindowTokens,
    maxOutputTokens: maxOutputTokens ?? this.maxOutputTokens,
    outputTokenLimit: outputTokenLimit ?? this.outputTokenLimit,
    supportsImages: supportsImages ?? this.supportsImages,
    reasoningEffort: reasoningEffort ?? this.reasoningEffort,
    archived: archived ?? this.archived,
  );

  Map<String, Object?> toJson() => {
    'profileId': profileId,
    'providerId': providerId,
    'modelId': modelId,
    if (displayName != null) 'displayName': displayName,
    'contextWindowTokens': contextWindowTokens,
    'maxOutputTokens': maxOutputTokens,
    if (outputTokenLimit != null) 'outputTokenLimit': outputTokenLimit,
    'supportsImages': supportsImages,
    'reasoningEffort': reasoningEffort.name,
    'archived': archived,
  };

  factory ProviderModel.fromJson(Map<String, Object?> json) => ProviderModel(
    profileId: _readString(json, 'profileId'),
    providerId: _readString(json, 'providerId'),
    modelId: _readString(json, 'modelId'),
    displayName: json['displayName'] is String
        ? json['displayName'] as String
        : null,
    contextWindowTokens: _readInt(json, 'contextWindowTokens', fallback: 64000),
    maxOutputTokens: _readInt(json, 'maxOutputTokens', fallback: 4096),
    outputTokenLimit: json['outputTokenLimit'] == null
        ? null
        : _readInt(json, 'outputTokenLimit'),
    supportsImages: json['supportsImages'] != false,
    reasoningEffort: json['reasoningEffort'] == null
        ? ReasoningEffort.off
        : _readEnum(json, 'reasoningEffort', ReasoningEffort.values),
    archived: json['archived'] == true,
  );
}

/// 新会话默认模型、摘要模型与会话内选择分开保存，避免一次修改连带旧会话。
class ModelSelection {
  const ModelSelection({required this.defaultProfileId, this.summaryProfileId});

  final String defaultProfileId;

  /// 为 null 表示跟随默认模型；摘要模型首期全局唯一。
  final String? summaryProfileId;

  String get effectiveSummaryProfileId => summaryProfileId ?? defaultProfileId;

  ModelSelection copyWith({
    String? defaultProfileId,
    String? summaryProfileId,
    bool clearSummary = false,
  }) => ModelSelection(
    defaultProfileId: defaultProfileId ?? this.defaultProfileId,
    summaryProfileId: clearSummary
        ? null
        : (summaryProfileId ?? this.summaryProfileId),
  );

  Map<String, Object?> toJson() => {
    'defaultProfileId': defaultProfileId,
    if (summaryProfileId != null) 'summaryProfileId': summaryProfileId,
  };

  factory ModelSelection.fromJson(Map<String, Object?> json) => ModelSelection(
    defaultProfileId: _readString(json, 'defaultProfileId'),
    summaryProfileId: json['summaryProfileId'] is String
        ? json['summaryProfileId'] as String
        : null,
  );
}

/// 服务、模型与选择的唯一运行来源；整体保存为一个带版本的 JSON 文档。
class ProviderCatalog {
  ProviderCatalog({
    required List<ProviderConfig> providers,
    required List<ProviderModel> models,
    required this.selection,
    this.version = currentVersion,
  }) : providers = List.unmodifiable(providers),
       models = List.unmodifiable(models) {
    final providerIds = <String>{};
    for (final provider in providers) {
      if (!providerIds.add(provider.providerId)) {
        throw ArgumentError('服务编号重复：${provider.providerId}');
      }
    }
    final profileIds = <String>{};
    for (final model in models) {
      if (!profileIds.add(model.profileId)) {
        throw ArgumentError('模型编号重复：${model.profileId}');
      }
      if (!providerIds.contains(model.providerId)) {
        throw ArgumentError('模型 ${model.profileId} 引用了不存在的服务');
      }
    }
    if (!profileIds.contains(selection.defaultProfileId)) {
      throw ArgumentError('默认模型引用了不存在的配置');
    }
    if (selection.summaryProfileId != null &&
        !profileIds.contains(selection.summaryProfileId)) {
      throw ArgumentError('摘要模型引用了不存在的配置');
    }
  }

  static const currentVersion = 1;
  final int version;
  final List<ProviderConfig> providers;
  final List<ProviderModel> models;
  final ModelSelection selection;

  ProviderConfig providerOf(String providerId) => providers.firstWhere(
    (provider) => provider.providerId == providerId,
    orElse: () => throw ArgumentError('不存在服务：$providerId'),
  );

  ProviderModel? modelOfProfile(String profileId) =>
      models.where((model) => model.profileId == profileId).firstOrNull;

  ProviderConfig? providerForProfile(String profileId) {
    final model = modelOfProfile(profileId);
    if (model == null) return null;
    return providers
        .where((provider) => provider.providerId == model.providerId)
        .firstOrNull;
  }

  /// 一个模型能否被新会话或当前会话选用：自身与服务都未停用。
  bool isSelectable(String profileId) {
    final model = modelOfProfile(profileId);
    if (model == null || model.archived) return false;
    final provider = providerForProfile(profileId);
    return provider != null && !provider.archived;
  }

  List<ProviderModel> get selectableModels =>
      models.where((model) => isSelectable(model.profileId)).toList();

  List<ProviderModel> modelsOfProvider(
    String providerId, {
    bool includeArchived = true,
  }) => models
      .where(
        (model) =>
            model.providerId == providerId &&
            (includeArchived || !model.archived),
      )
      .toList();

  /// 编译为 Agent 核心配置。
  ///
  /// 停用的服务与模型仍保留在配置里，让历史会话可以打开；是否允许发送由
  /// 应用层根据 [isSelectable] 判断，而不是让运行时找不到配置直接抛错。
  List<ModelProfile> compileProfiles() {
    final providerById = {
      for (final provider in providers) provider.providerId: provider,
    };
    return [
      for (final model in models)
        if (providerById[model.providerId] case final provider?)
          ModelProfile(
            id: model.profileId,
            provider: provider.modelProvider,
            model: model.modelId,
            endpoint: AssistantModelCatalog.requestEndpoint(
              provider.baseAddress,
              provider.protocol,
            ),
            protocol: provider.protocol,
            credentialKey: provider.credentialRef,
            contextWindowTokens: model.contextWindowTokens,
            maxOutputTokens: model.maxOutputTokens,
            outputTokenLimit: model.outputTokenLimit,
            supportsImages: model.supportsImages,
            requiresCredential: provider.requiresCredential,
            reasoningEffort: model.reasoningEffort,
          ),
    ];
  }

  AgentConfiguration compileConfiguration({
    required AgentConfiguration base,
    Map<String, ReasoningEffort> reasoningEfforts = const {},
  }) {
    final compiled = compileProfiles();
    if (compiled.isEmpty) return base;
    final profiles = [
      for (final profile in compiled)
        if (reasoningEfforts[profile.id] case final effort?)
          ModelProfile.fromJson({
            ...profile.toJson(),
            'reasoningEffort': effort.name,
          })
        else
          profile,
    ];
    final selected =
        profiles.any((profile) => profile.id == selection.defaultProfileId)
        ? selection.defaultProfileId
        : profiles.first.id;
    final summaryCandidate = selection.effectiveSummaryProfileId;
    // 摘要模型停用或所属服务停用时回退到主模型，避免后台总结静默失败。
    final summary =
        profiles.any((profile) => profile.id == summaryCandidate) &&
            isSelectable(summaryCandidate)
        ? summaryCandidate
        : selected;
    return AgentConfiguration(
      profiles: profiles,
      defaultModelProfile: selected,
      summaryModelProfile: summary,
      maxSteps: base.maxSteps,
      maxRunDuration: base.maxRunDuration,
      context: base.context,
    );
  }

  ProviderCatalog copyWith({
    List<ProviderConfig>? providers,
    List<ProviderModel>? models,
    ModelSelection? selection,
  }) => ProviderCatalog(
    providers: providers ?? this.providers,
    models: models ?? this.models,
    selection: selection ?? this.selection,
  );

  Map<String, Object?> toJson() => {
    'version': version,
    'providers': providers.map((provider) => provider.toJson()).toList(),
    'models': models.map((model) => model.toJson()).toList(),
    'selection': selection.toJson(),
  };

  factory ProviderCatalog.fromJson(Map<String, Object?> json) {
    final version = json['version'];
    if (version is! int || version > currentVersion) {
      throw const FormatException('模型目录版本不受支持');
    }
    final providers = json['providers'];
    final models = json['models'];
    final selection = json['selection'];
    if (providers is! List || models is! List || selection is! Map) {
      throw const FormatException('模型目录结构无效');
    }
    return ProviderCatalog(
      version: version,
      providers: [
        for (final item in providers)
          if (item is Map)
            ProviderConfig.fromJson(Map<String, Object?>.from(item)),
      ],
      models: [
        for (final item in models)
          if (item is Map)
            ProviderModel.fromJson(Map<String, Object?>.from(item)),
      ],
      selection: ModelSelection.fromJson(Map<String, Object?>.from(selection)),
    );
  }

  /// 内置服务与模型的首次运行基线；迁移和空目录都从这里开始。
  static ProviderCatalog defaults() => ProviderCatalog(
    providers: [
      ProviderConfig(
        providerId: 'deepseek-api',
        displayName: 'DeepSeek',
        baseAddress: 'https://api.deepseek.com',
        protocol: ModelProtocol.chatCompletions,
        credentialRef: 'DEEPSEEK_API_KEY',
        modelProvider: 'deepseek',
      ),
      ProviderConfig(
        providerId: 'deepseek-anthropic',
        displayName: 'DeepSeek Messages',
        baseAddress: 'https://api.deepseek.com/anthropic/v1',
        protocol: ModelProtocol.messages,
        credentialRef: 'DEEPSEEK_API_KEY',
        modelProvider: 'deepseek',
      ),
    ],
    models: [
      ProviderModel(
        profileId: 'deepseek-chat',
        providerId: 'deepseek-api',
        modelId: 'deepseek-flash',
        displayName: 'DeepSeek Flash',
        contextWindowTokens: DeepSeekFlash.contextWindowTokens,
        maxOutputTokens: DeepSeekFlash.defaultOutputTokens,
        outputTokenLimit: DeepSeekFlash.outputTokenLimit,
      ),
      ProviderModel(
        profileId: 'deepseek',
        providerId: 'deepseek-anthropic',
        modelId: 'deepseek-flash',
        displayName: 'DeepSeek Flash (Messages)',
        contextWindowTokens: DeepSeekFlash.contextWindowTokens,
        maxOutputTokens: DeepSeekFlash.defaultOutputTokens,
        outputTokenLimit: DeepSeekFlash.outputTokenLimit,
      ),
    ],
    selection: const ModelSelection(defaultProfileId: 'deepseek-chat'),
  );

  /// 把旧固定三档与自定义配置归并为目录。
  ///
  /// 幂等性由调用方保证：只有目录不存在时才调用。迁移只做归并，不清空旧键，
  /// 因此失败后可以重试，也不会丢失用户已有会话引用的 profileId。
  static ProviderCatalog migrateFromLegacy({
    String? legacyProfileId,
    ModelProfile? legacyCustomProfile,
    Iterator<String> Function()? newProviderId,
  }) {
    final defaults = ProviderCatalog.defaults();
    var providers = [...defaults.providers];
    var models = [...defaults.models];

    final custom = legacyCustomProfile;
    if (custom != null) {
      final address = custom.endpoint.toString();
      providers = [
        ...providers,
        ProviderConfig(
          providerId: 'custom',
          displayName: '自定义服务',
          baseAddress: address,
          protocol: custom.protocol,
          credentialRef: 'MISSIONBOOK_CUSTOM_API_KEY',
          modelProvider: custom.provider,
        ),
      ];
      models = [
        ...models,
        ProviderModel(
          profileId: 'custom',
          providerId: 'custom',
          modelId: custom.model,
          contextWindowTokens: custom.contextWindowTokens,
          maxOutputTokens: custom.maxOutputTokens,
          outputTokenLimit: custom.outputTokenLimit,
          supportsImages: custom.supportsImages,
          reasoningEffort: custom.reasoningEffort,
        ),
      ];
    }

    final requested = legacyProfileId;
    final defaultId =
        requested != null && models.any((model) => model.profileId == requested)
        ? requested
        : defaults.selection.defaultProfileId;
    return ProviderCatalog(
      providers: providers,
      models: models,
      selection: ModelSelection(defaultProfileId: defaultId),
    );
  }

  /// 为新服务生成受控凭据引用；同一 providerId 始终得到同一引用。
  static String credentialRefFor(String providerId) {
    final normalized = providerId.toUpperCase().replaceAll(
      RegExp(r'[^A-Z0-9]'),
      '_',
    );
    return 'MISSIONBOOK_PROVIDER_${normalized}_KEY';
  }

  /// 生成不与现有条目冲突的稳定编号。
  static String nextId(String prefix, Iterable<String> existing) {
    final used = existing.toSet();
    var index = 1;
    while (used.contains('$prefix-$index')) {
      index++;
    }
    return '$prefix-$index';
  }
}

String _readString(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is! String || value.trim().isEmpty) {
    throw FormatException('字段 $key 缺失');
  }
  return value.trim();
}

int _readInt(Map<String, Object?> json, String key, {int? fallback}) {
  final value = json[key];
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (fallback != null) return fallback;
  throw FormatException('字段 $key 必须是整数');
}

T _readEnum<T extends Enum>(
  Map<String, Object?> json,
  String key,
  List<T> values,
) {
  final name = _readString(json, key);
  for (final value in values) {
    if (value.name == name) return value;
  }
  throw FormatException('字段 $key 的值无效');
}

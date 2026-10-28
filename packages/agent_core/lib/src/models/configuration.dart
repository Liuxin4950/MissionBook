/// 可选择的服务端协议；供应商名称与协议分开配置。
enum ModelProtocol { messages, chatCompletions }

enum ReasoningEffort { off, low, high, max }

/// 纯模型请求的有限重试；不会自动重试工具写入。
final class RetryPolicy {
  RetryPolicy({
    this.maxRetries = 2,
    this.initialDelay = const Duration(milliseconds: 500),
    this.maxDelay = const Duration(seconds: 10),
  }) {
    if (maxRetries < 0 ||
        maxRetries > 10 ||
        initialDelay < Duration.zero ||
        maxDelay < initialDelay) {
      throw ArgumentError('重试次数应在 0 到 10 之间，延迟必须非负且上限不小于初始值');
    }
  }

  final int maxRetries; // 第一次请求之外，最多再试几次。
  final Duration initialDelay;
  final Duration maxDelay;

  Duration delayFor(int retryNumber) {
    final milliseconds = initialDelay.inMilliseconds * (1 << (retryNumber - 1));
    return Duration(
      milliseconds: milliseconds.clamp(0, maxDelay.inMilliseconds),
    );
  }

  Map<String, Object?> toJson() => {
    'maxRetries': maxRetries,
    'initialDelayMs': initialDelay.inMilliseconds,
    'maxDelayMs': maxDelay.inMilliseconds,
  };

  factory RetryPolicy.fromJson(Map<String, Object?> json) {
    _knownKeys(json, {'maxRetries', 'initialDelayMs', 'maxDelayMs'});
    return RetryPolicy(
      maxRetries: _integer(json, 'maxRetries', fallback: 2),
      initialDelay: Duration(
        milliseconds: _integer(json, 'initialDelayMs', fallback: 500),
      ),
      maxDelay: Duration(
        milliseconds: _integer(json, 'maxDelayMs', fallback: 10000),
      ),
    );
  }
}

/// 一个可命名、保存和切换的模型配置；不持有 API Key 明文。
final class ModelProfile {
  ModelProfile({
    required this.id,
    required this.provider,
    required this.model,
    required this.endpoint,
    required this.protocol,
    required this.credentialEnvironment,
    this.contextWindowTokens = 64000,
    this.maxOutputTokens = 2048,
    this.streamResponses = true,
    this.reasoningEffort = ReasoningEffort.off,
    this.temperature,
    this.requestTimeout = const Duration(seconds: 120),
    RetryPolicy? retry,
  }) : retry = retry ?? RetryPolicy() {
    if (!RegExp(r'^[A-Za-z_][A-Za-z0-9_]*$').hasMatch(credentialEnvironment)) {
      throw ArgumentError('凭据配置需要环境变量名称，请勿在此填写 Key 明文');
    }
    if (id.trim().isEmpty ||
        provider.trim().isEmpty ||
        model.trim().isEmpty ||
        credentialEnvironment.trim().isEmpty) {
      throw ArgumentError('模型配置的 id、provider、model 和凭据变量名不能为空');
    }
    if (!['http', 'https'].contains(endpoint.scheme) ||
        endpoint.host.isEmpty ||
        endpoint.userInfo.isNotEmpty ||
        endpoint.hasQuery ||
        endpoint.hasFragment) {
      throw ArgumentError('模型地址必须是完整 HTTP 地址，不包含凭据、查询参数或片段');
    }
    if (maxOutputTokens < 1 || contextWindowTokens <= maxOutputTokens) {
      throw ArgumentError('上下文预算必须大于正数的输出上限');
    }
    if (temperature != null &&
        (!temperature!.isFinite || temperature! < 0 || temperature! > 2)) {
      throw ArgumentError('temperature 必须在 0 到 2 之间');
    }
    if (requestTimeout <= Duration.zero) throw ArgumentError('请求超时必须大于零');
  }

  final String id;
  final String provider;
  final String model;
  final Uri endpoint; // 完整请求地址，不在适配器里猜测路径。
  final ModelProtocol protocol;
  final String credentialEnvironment; // 例如 DEEPSEEK_API_KEY，由宿主解析。
  final int contextWindowTokens; // 本地采用的上下文预算，可小于供应商真实窗口。
  final int maxOutputTokens;
  final bool streamResponses;
  final ReasoningEffort reasoningEffort;
  final double? temperature;
  final Duration requestTimeout;
  final RetryPolicy retry;

  Map<String, Object?> toJson() => {
    'id': id,
    'provider': provider,
    'model': model,
    'endpoint': endpoint.toString(),
    'protocol': protocol.name,
    'credentialEnvironment': credentialEnvironment,
    'contextWindowTokens': contextWindowTokens,
    'maxOutputTokens': maxOutputTokens,
    'streamResponses': streamResponses,
    'reasoningEffort': reasoningEffort.name,
    if (temperature != null) 'temperature': temperature,
    'requestTimeoutMs': requestTimeout.inMilliseconds,
    'retry': retry.toJson(),
  };

  factory ModelProfile.fromJson(Map<String, Object?> json) {
    _knownKeys(json, {
      'id',
      'provider',
      'model',
      'endpoint',
      'protocol',
      'credentialEnvironment',
      'contextWindowTokens',
      'maxOutputTokens',
      'streamResponses',
      'reasoningEffort',
      'temperature',
      'requestTimeoutMs',
      'retry',
    });
    return ModelProfile(
      id: readString(json, 'id'),
      provider: readString(json, 'provider'),
      model: readString(json, 'model'),
      endpoint: Uri.parse(readString(json, 'endpoint')),
      protocol: _enumValue(ModelProtocol.values, readString(json, 'protocol')),
      credentialEnvironment: readString(json, 'credentialEnvironment'),
      contextWindowTokens: _integer(
        json,
        'contextWindowTokens',
        fallback: 64000,
      ),
      maxOutputTokens: _integer(json, 'maxOutputTokens', fallback: 2048),
      streamResponses: _boolean(json, 'streamResponses', fallback: true),
      reasoningEffort: _enumValue(
        ReasoningEffort.values,
        json['reasoningEffort'] == null
            ? 'off'
            : readString(json, 'reasoningEffort'),
      ),
      temperature: json['temperature'] == null
          ? null
          : _number(json, 'temperature'),
      requestTimeout: Duration(
        milliseconds: _integer(json, 'requestTimeoutMs', fallback: 120000),
      ),
      retry: json['retry'] == null
          ? null
          : RetryPolicy.fromJson(readObject(json['retry'])),
    );
  }
}

/// 自动压缩的预算与保留策略；系统提示和工具说明也会占用预算。
final class ContextPolicy {
  ContextPolicy({
    this.enabled = true,
    this.triggerRatio = 0.8,
    this.targetRatio = 0.5,
    this.headroomTokens = 512,
    this.keepRecentMessages = 6,
    this.summaryMaxTokens = 1024,
    this.maxSummaryCalls = 8,
  }) {
    if (!triggerRatio.isFinite ||
        !targetRatio.isFinite ||
        targetRatio <= 0 ||
        targetRatio >= triggerRatio ||
        triggerRatio > 1 ||
        headroomTokens < 0 ||
        keepRecentMessages < 1 ||
        summaryMaxTokens < 1 ||
        maxSummaryCalls < 1) {
      throw ArgumentError('上下文压缩比例、保留数量或摘要预算无效');
    }
  }

  final bool enabled;
  final double triggerRatio;
  final double targetRatio;
  final int headroomTokens;
  final int keepRecentMessages; // 实际保留会扩展到完整工具调用组。
  final int summaryMaxTokens;
  final int maxSummaryCalls;

  Map<String, Object?> toJson() => {
    'enabled': enabled,
    'triggerRatio': triggerRatio,
    'targetRatio': targetRatio,
    'headroomTokens': headroomTokens,
    'keepRecentMessages': keepRecentMessages,
    'summaryMaxTokens': summaryMaxTokens,
    'maxSummaryCalls': maxSummaryCalls,
  };

  factory ContextPolicy.fromJson(Map<String, Object?> json) {
    _knownKeys(json, {
      'enabled',
      'triggerRatio',
      'targetRatio',
      'headroomTokens',
      'keepRecentMessages',
      'summaryMaxTokens',
      'maxSummaryCalls',
    });
    return ContextPolicy(
      enabled: _boolean(json, 'enabled', fallback: true),
      triggerRatio: _number(json, 'triggerRatio', fallback: 0.8),
      targetRatio: _number(json, 'targetRatio', fallback: 0.5),
      headroomTokens: _integer(json, 'headroomTokens', fallback: 512),
      keepRecentMessages: _integer(json, 'keepRecentMessages', fallback: 6),
      summaryMaxTokens: _integer(json, 'summaryMaxTokens', fallback: 1024),
      maxSummaryCalls: _integer(json, 'maxSummaryCalls', fallback: 8),
    );
  }
}

/// 基座启动配置；主模型和摘要模型可以选择不同的命名配置。
final class AgentConfiguration {
  factory AgentConfiguration.deepSeek() => AgentConfiguration(
    defaultModelProfile: 'deepseek',
    profiles: [
      ModelProfile(
        id: 'deepseek',
        provider: 'deepseek',
        model: 'deepseek-flash',
        endpoint: Uri.parse('https://api.deepseek.com/anthropic/v1/messages'),
        protocol: ModelProtocol.messages,
        credentialEnvironment: 'DEEPSEEK_API_KEY',
      ),
      ModelProfile(
        id: 'deepseek-chat',
        provider: 'deepseek',
        model: 'deepseek-flash',
        endpoint: Uri.parse('https://api.deepseek.com/chat/completions'),
        protocol: ModelProtocol.chatCompletions,
        credentialEnvironment: 'DEEPSEEK_API_KEY',
      ),
    ],
  );
  AgentConfiguration({
    required List<ModelProfile> profiles,
    required this.defaultModelProfile,
    String? summaryModelProfile,
    this.maxSteps = 16,
    ContextPolicy? context,
  }) : profiles = List.unmodifiable(profiles),
       summaryModelProfile = summaryModelProfile ?? defaultModelProfile,
       context = context ?? ContextPolicy() {
    final ids = <String>{};
    for (final profile in profiles) {
      if (!ids.add(profile.id)) throw ArgumentError('模型配置编号重复：${profile.id}');
    }
    if (!ids.contains(defaultModelProfile) ||
        !ids.contains(this.summaryModelProfile)) {
      throw ArgumentError('默认模型或摘要模型引用了不存在的配置');
    }
    if (maxSteps < 1) throw ArgumentError('maxSteps 必须大于零');
  }

  final List<ModelProfile> profiles;
  final String defaultModelProfile;
  final String summaryModelProfile;
  final int maxSteps;
  final ContextPolicy context;

  ModelProfile profile(String id) => profiles.firstWhere(
    (profile) => profile.id == id,
    orElse: () => throw ArgumentError('不存在模型配置：$id'),
  );

  Map<String, Object?> toJson() => {
    'version': 1,
    'profiles': profiles.map((profile) => profile.toJson()).toList(),
    'defaultModelProfile': defaultModelProfile,
    'summaryModelProfile': summaryModelProfile,
    'maxSteps': maxSteps,
    'context': context.toJson(),
  };

  factory AgentConfiguration.fromJson(Map<String, Object?> json) {
    _knownKeys(json, {
      'version',
      'profiles',
      'defaultModelProfile',
      'summaryModelProfile',
      'maxSteps',
      'context',
    });
    if (_integer(json, 'version') != 1) {
      throw const FormatException('不支持的模型配置版本');
    }
    final profiles = json['profiles'];
    if (profiles is! List<Object?>) {
      throw const FormatException('profiles 必须是列表');
    }
    return AgentConfiguration(
      profiles: profiles
          .map((item) => ModelProfile.fromJson(readObject(item)))
          .toList(),
      defaultModelProfile: readString(json, 'defaultModelProfile'),
      summaryModelProfile: json['summaryModelProfile'] == null
          ? null
          : readString(json, 'summaryModelProfile'),
      maxSteps: _integer(json, 'maxSteps', fallback: 16),
      context: json['context'] == null
          ? null
          : ContextPolicy.fromJson(readObject(json['context'])),
    );
  }
}

Map<String, Object?> readObject(Object? value) {
  if (value is! Map<String, Object?>) throw const FormatException('需要 JSON 对象');
  return value;
}

String readString(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is! String) throw FormatException('$key 必须是字符串');
  return value;
}

int _integer(Map<String, Object?> json, String key, {int? fallback}) {
  final value = json[key] ?? fallback;
  if (value is! int) throw FormatException('$key 必须是整数');
  return value;
}

double _number(Map<String, Object?> json, String key, {double? fallback}) {
  final value = json[key] ?? fallback;
  if (value is! num || !value.isFinite) throw FormatException('$key 必须是有限数值');
  return value.toDouble();
}

bool _boolean(Map<String, Object?> json, String key, {required bool fallback}) {
  final value = json[key] ?? fallback;
  if (value is! bool) throw FormatException('$key 必须是布尔值');
  return value;
}

T _enumValue<T extends Enum>(List<T> values, String name) => values.firstWhere(
  (value) => value.name == name,
  orElse: () => throw FormatException('未知配置值：$name'),
);

void _knownKeys(Map<String, Object?> json, Set<String> keys) {
  final unknown = json.keys.where((key) => !keys.contains(key));
  if (unknown.isNotEmpty) throw FormatException('未知配置字段：${unknown.join(', ')}');
}

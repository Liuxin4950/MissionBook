import 'models/configuration.dart';
import 'models/http_agent_model.dart';

/// DeepSeek 的快捷入口；完整基座也可用 ModelProfile 配置多个模型。
final class DeepSeekMessagesModel extends HttpAgentModel {
  DeepSeekMessagesModel({
    required String apiKey,
    String model = 'deepseek-flash',
    int maxTokens = 2048,
    Duration requestTimeout = const Duration(seconds: 60),
    Uri? endpoint,
    super.client,
    bool streamResponses = false,
  }) : super(
         profile: ModelProfile(
           id: 'deepseek',
           provider: 'deepseek',
           model: model,
           endpoint:
               endpoint ??
               Uri.parse('https://api.deepseek.com/anthropic/v1/messages'),
           protocol: ModelProtocol.messages,
           credentialEnvironment: 'DEEPSEEK_API_KEY',
           maxOutputTokens: maxTokens,
           contextWindowTokens: maxTokens >= 64000 ? maxTokens + 1 : 64000,
           requestTimeout: requestTimeout,
           streamResponses: streamResponses,
         ),
         credentials: (_) => apiKey,
       ) {
    if (apiKey.trim().isEmpty) throw ArgumentError('DeepSeek API Key 不能为空');
  }

  String get model => profile.model;
  int get maxTokens => profile.maxOutputTokens;
  Duration get requestTimeout => profile.requestTimeout;
  Uri get endpoint => profile.endpoint;
}

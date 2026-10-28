import 'dart:async';

import 'package:agent_core/agent_core.dart';

typedef ModelCallback =
    FutureOr<ModelResponse> Function(
      ModelRequest request,
      CancellationToken token,
    );

final class CallbackModel implements AgentModel {
  CallbackModel(this.callback);
  final ModelCallback callback;
  @override
  Future<ModelResponse> complete(
    ModelRequest request,
    CancellationToken cancellation,
  ) async => callback(request, cancellation);
}

ModelResponse textReply(String text) => ModelResponse(
  message: AssistantMessage(
    provider: 'test',
    model: 'test-model',
    content: [TextBlock(text: text)],
  ),
  stopReason: ModelStopReason.completed,
  usage: const TokenUsage(inputTokens: 10, outputTokens: 5),
);

ModelResponse toolReply(
  String id, {
  String name = 'read',
  Map<String, Object?> input = const {},
}) => ModelResponse(
  message: AssistantMessage(
    provider: 'test',
    model: 'test-model',
    content: [ToolCallBlock(id: id, name: name, input: input)],
  ),
  stopReason: ModelStopReason.toolUse,
);

ModelProfile testProfile(
  String id, {
  int window = 24000,
  int output = 256,
  bool stream = true,
  ModelProtocol protocol = ModelProtocol.messages,
  RetryPolicy? retry,
}) => ModelProfile(
  id: id,
  provider: 'test',
  model: 'test-model',
  endpoint: Uri.parse('https://example.invalid/$id'),
  protocol: protocol,
  credentialEnvironment: 'TEST_API_KEY',
  contextWindowTokens: window,
  maxOutputTokens: output,
  streamResponses: stream,
  retry:
      retry ??
      RetryPolicy(
        maxRetries: 1,
        initialDelay: Duration.zero,
        maxDelay: Duration.zero,
      ),
);

AgentConfiguration testConfiguration({
  int window = 24000,
  ContextPolicy? context,
}) => AgentConfiguration(
  profiles: [
    testProfile('main', window: window),
    testProfile('summary', window: 24000),
  ],
  defaultModelProfile: 'main',
  summaryModelProfile: 'summary',
  context: context ?? ContextPolicy(headroomTokens: 64),
);

AgentRuntime testRuntime({
  SessionStore? store,
  AgentConfiguration? configuration,
  ModelCallback? main,
  ModelCallback? summary,
  List<AgentTool> tools = const [],
}) => AgentRuntime(
  configuration: configuration ?? testConfiguration(),
  store: store ?? MemorySessionStore(),
  credentials: (_) => null,
  tools: tools,
  authorize: (tool, call, token) => const ToolDecision.allow(),
  modelOverrides: {
    'main': CallbackModel(main ?? (request, token) => textReply('已回答')),
    'summary': CallbackModel(
      summary ?? (request, token) => textReply('用户的约束：保留原始事实，继续完成当前要求。'),
    ),
  },
);

AgentTool readTool(ToolHandler handler) => AgentTool(
  definition: ToolDefinition(
    name: 'read',
    description: '测试读取工具',
    inputSchema: {'type': 'object', 'additionalProperties': false},
  ),
  execute: handler,
);

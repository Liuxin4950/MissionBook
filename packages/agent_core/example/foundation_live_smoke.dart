import 'dart:io';

import 'package:agent_core/agent_core_io.dart';

import 'demo_tools.dart';

/// 真实 API 验证：两种协议分别自动摘要旧背景，再流式调用时间工具并回答。
/// Key 只从环境读取；测试背景是本文件的合成资料，不读取 App 数据。
Future<void> main(List<String> arguments) async {
  if ((Platform.environment['DEEPSEEK_API_KEY'] ?? '').trim().isEmpty) {
    stderr.writeln('请先设置 DEEPSEEK_API_KEY 环境变量。');
    exitCode = 2;
    return;
  }
  final thinking = arguments.contains('--thinking');
  for (final protocol in ModelProtocol.values) {
    await _verify(protocol, thinking: thinking);
  }
}

Future<void> _verify(ModelProtocol protocol, {required bool thinking}) async {
  final endpoint = Uri.parse(
    protocol == ModelProtocol.messages
        ? 'https://api.deepseek.com/anthropic/v1/messages'
        : 'https://api.deepseek.com/chat/completions',
  );
  ModelProfile profile(String id, int window, ReasoningEffort effort) =>
      ModelProfile(
        id: id,
        provider: 'deepseek',
        model: Platform.environment['DEEPSEEK_MODEL'] ?? 'deepseek-flash',
        endpoint: endpoint,
        protocol: protocol,
        credentialEnvironment: 'DEEPSEEK_API_KEY',
        contextWindowTokens: window,
        maxOutputTokens: 2048,
        reasoningEffort: effort,
        retry: RetryPolicy(maxRetries: 1),
      );
  final runtime = AgentRuntime(
    configuration: AgentConfiguration(
      profiles: [
        profile(
          'main',
          8500,
          thinking ? ReasoningEffort.low : ReasoningEffort.off,
        ),
        profile('summary', 24000, ReasoningEffort.off),
      ],
      defaultModelProfile: 'main',
      summaryModelProfile: 'summary',
      maxSteps: 4,
      context: ContextPolicy(
        keepRecentMessages: 1,
        headroomTokens: 256,
        summaryMaxTokens: 768,
        maxSummaryCalls: 3,
      ),
    ),
    store: MemorySessionStore(),
    credentials: (name) => Platform.environment[name],
    tools: [currentTimeTool()],
    authorize: authorizeDemoTool,
  );
  try {
    final session = await runtime.createSession(
      systemPrompt:
          '请用中文简洁回答，项目代号必须根据已提供背景准确引用。'
          '查询当前时间必须调用 get_current_time 一次，然后依据工具真实结果回答。',
    );
    var textDeltas = 0;
    var thinkingDeltas = 0;
    var executed = 0;
    final events = session.events.listen((event) {
      if (event is ModelStreamUpdated &&
          event.purpose == ModelRequestPurpose.conversation) {
        if (event.update is ModelTextDelta) textDeltas++;
        if (event.update is ModelThinkingDelta) thinkingDeltas++;
      } else if (event is ToolExecutionStarted) {
        executed++;
      } else if (event is ContextCompacted) {
        print(
          '[${protocol.name}] 自动压缩 ${event.compaction.beforeTokens} → '
          '${event.compaction.afterTokens}，摘要请求 ${event.compaction.summaryRequests} 次',
        );
      }
    });
    for (var index = 0; index < 12; index++) {
      await session.injectContext(
        source: '合成测试背景 $index',
        text:
            '项目代号为杉木-42。用户有两小时，先做基座验证。'
            '${'历史记录只用于验证压缩，尚未对接任何业务应用，不代表工作已经完成。' * 6}',
      );
    }
    final originalFirst = session.transcript.first;
    const input = '请先查现在几点，再用一句话说出项目代号和时间。';
    final result = await session.send(input);
    await session.close(); // 排空事件再核对计数。
    await events.cancel();
    if (result.reason != AgentStopReason.completed ||
        result.compactions < 1 ||
        executed != 1 ||
        textDeltas == 0 ||
        (thinking && thinkingDeltas == 0) ||
        !(result.answer ?? '').contains('杉木-42') ||
        session.messageById(originalFirst.id)?.text != originalFirst.text ||
        !session.contextMessages.whereType<UserMessage>().any(
          (m) => m.text == input,
        )) {
      throw StateError(
        '${protocol.name} 验证未满足：${result.reason.name}；'
        '${result.failure}；工具 $executed；压缩 ${result.compactions}；回答 ${result.answer}',
      );
    }
    print(
      '[${protocol.name}] PASS；主请求 ${result.modelSteps} 步，工具 $executed 次，'
      '文字增量 $textDeltas，思考增量 $thinkingDeltas，'
      '报告用量 ${result.usage.inputTokens}/${result.usage.outputTokens}',
    );
    print('回答：${result.answer}');
    print(
      '模型标识：${session.transcript.whereType<AssistantMessage>().last.model}',
    );
  } finally {
    await runtime.close();
  }
}

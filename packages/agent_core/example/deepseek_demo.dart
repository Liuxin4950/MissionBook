import 'dart:io';

import 'package:agent_core/agent_core.dart';

import 'demo_tools.dart';

/// 使用环境变量提供 Key，运行真实的 DeepSeek 模型与本机工具循环。
Future<void> main(List<String> arguments) async {
  final apiKey = Platform.environment['DEEPSEEK_API_KEY'];
  if (apiKey == null || apiKey.trim().isEmpty) {
    stderr.writeln('请在本机设置 DEEPSEEK_API_KEY 环境变量后再运行，无需把 Key 发到聊天。');
    exitCode = 2;
    return;
  }
  final model = DeepSeekMessagesModel(
    apiKey: apiKey,
    model: Platform.environment['DEEPSEEK_MODEL'] ?? 'deepseek-flash',
  );
  final agent = AgentLoop(
    model: model,
    systemPrompt:
        '你是 MissionBook 助理。涉及当前时间时必须调用 get_current_time，'
        '根据真实结果用中文回答，不编造工具执行结果。',
    tools: [currentTimeTool()],
    authorize: authorizeDemoTool,
  );
  final subscription = agent.events.listen(printAgentEvent);
  try {
    final input = arguments.isEmpty
        ? '请先调用 get_current_time，再告诉我现在的本地时间。'
        : arguments.join(' ');
    final result = await agent.run(input: input);
    await agent.close();
    print('回答：${result.answer ?? result.failure ?? result.reason.name}');
    if (result.reason != AgentStopReason.completed) exitCode = 1;
  } finally {
    await agent.close();
    await subscription.cancel();
    model.close();
  }
}

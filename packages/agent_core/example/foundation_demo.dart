import 'package:agent_core/agent_core.dart';

import 'demo_tools.dart';

/// 离线演示完整基座：注入背景 → 自动压缩 → 工具循环 → 重开会话 → 分支。
/// 故意使用脚本模型，帮助观察调用顺序；只有时间工具读取真实设备信息。
Future<void> main() async {
  print('离线基座演示：主模型和摘要模型均为脚本，不请求 API。');
  final mainProfile = _profile('main', 3500);
  final summaryProfile = _profile('summary', 16000);
  final store = MemorySessionStore();
  final runtime = AgentRuntime(
    configuration: AgentConfiguration(
      profiles: [mainProfile, summaryProfile],
      defaultModelProfile: 'main',
      summaryModelProfile: 'summary',
      context: ContextPolicy(
        keepRecentMessages: 1,
        headroomTokens: 64,
        summaryMaxTokens: 256,
      ),
    ),
    store: store,
    credentials: (_) => null, // 脚本覆盖 HTTP 模型，因此不需要凭据。
    tools: [currentTimeTool()],
    authorize: authorizeDemoTool,
    modelOverrides: {'main': _DemoModel(), 'summary': _DemoModel()},
  );
  try {
    final session = await runtime.createSession(id: 'offline-demo');
    final events = session.events.listen(printAgentEvent);
    // 提供足够长的旧背景，故意越过演示用的小预算。
    for (var index = 0; index < 8; index++) {
      await session.injectContext(
        source: '离线演示背景 $index',
        text: '用户计划在两小时内完成 Agent 基座。${'需要先实现完整循环，解释每个输入和结果。' * 20}',
      );
    }
    final result = await session.send('请查当前时间，然后说明接下来做什么。');
    if (result.reason != AgentStopReason.completed || result.compactions != 1) {
      throw StateError('演示未完成：${result.failure ?? result.reason}');
    }
    print('回答：${result.answer}');
    print(
      '原始消息 ${session.transcript.length}；当前上下文 ${session.contextMessages.length}。',
    );
    await session.close();
    await events.cancel();

    // 同一个存储重开后恢复原文和压缩投影；下轮只需发送新输入。
    final reopened = await runtime.openSession('offline-demo');
    final continued = await reopened.send('保留原安排，继续。');
    if (continued.reason != AgentStopReason.completed) {
      throw StateError('重开后继续失败：${continued.failure}');
    }
    final branch = await reopened.fork(title: '演示分支');
    print('重开后回答：${continued.answer}');
    print('分支复制 ${branch.transcript.length} 条消息，源会话仍为 ${reopened.id}。');
    print('离线基座演示完成。');
  } finally {
    await runtime.close();
  }
}

ModelProfile _profile(String id, int window) => ModelProfile(
  id: id,
  provider: 'demo',
  model: 'scripted',
  endpoint: Uri.parse('https://example.invalid/$id'),
  protocol: ModelProtocol.messages,
  credentialEnvironment: 'UNUSED_DEMO_KEY',
  contextWindowTokens: window,
  maxOutputTokens: 256,
);

final class _DemoModel implements AgentModel {
  @override
  Future<ModelResponse> complete(
    ModelRequest request,
    CancellationToken cancellation,
  ) async {
    cancellation.throwIfCancelled();
    if (request.purpose == ModelRequestPurpose.summary) {
      return _reply('用户有两小时；先完成 Agent 基座，再解释输入、处理和结果。');
    }
    final last = request.messages.last;
    if (last is ToolResultMessage) {
      return _reply('本机时间：${last.text}。接着完成基座验证与说明。');
    }
    if (last.text.contains('查当前时间')) {
      return ModelResponse(
        message: AssistantMessage(
          provider: 'demo',
          model: 'scripted',
          content: [
            ToolCallBlock(
              id: 'time-${last.id}',
              name: 'get_current_time',
              input: {},
            ),
          ],
        ),
        stopReason: ModelStopReason.toolUse,
      );
    }
    return _reply('已保留两小时约束，继续完成基座验证。');
  }

  ModelResponse _reply(String text) => ModelResponse(
    message: AssistantMessage(
      provider: 'demo',
      model: 'scripted',
      content: [TextBlock(text: text)],
    ),
    stopReason: ModelStopReason.completed,
  );
}

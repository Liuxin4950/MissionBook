import 'package:agent_core/agent_core.dart';

import 'demo_tools.dart';

/// 不需要 Key 的完整循环演示：模型用脚本替代，工具真的读取本机时间。
Future<void> main() async {
  print('离线演示：使用脚本模型观察循环，不会请求 DeepSeek。');
  final agent = AgentLoop(
    model: _ScriptedModel(),
    systemPrompt: '先读取本机时间，再回答用户。',
    tools: [currentTimeTool()],
    authorize: authorizeDemoTool,
  );
  final subscription = agent.events.listen(printAgentEvent);
  try {
    final result = await agent.run(input: '先读取本机时间，再告诉我结果。');
    await agent.close(); // 等订阅者收到全部过程事件，再打印最终回答。
    print('回答：${result.answer ?? result.failure ?? result.reason.name}');
    print('共 ${result.modelSteps} 次模型请求，保留 ${result.messages.length} 条消息。');
  } finally {
    await agent.close();
    await subscription.cancel();
  }
}

final class _ScriptedModel implements AgentModel {
  @override
  Future<ModelResponse> complete(
    ModelRequest request,
    CancellationToken cancellation,
  ) async {
    final last = request.messages.last;
    if (last is ToolResultMessage) {
      return ModelResponse(
        message: AssistantMessage(
          content: [TextBlock(text: '设备时间工具返回：${last.text}')],
          provider: 'demo',
          model: 'scripted',
        ),
        stopReason: ModelStopReason.completed,
      );
    }
    return ModelResponse(
      message: AssistantMessage(
        content: [
          ToolCallBlock(id: 'demo-time-1', name: 'get_current_time', input: {}),
        ],
        provider: 'demo',
        model: 'scripted',
      ),
      stopReason: ModelStopReason.toolUse,
    );
  }
}

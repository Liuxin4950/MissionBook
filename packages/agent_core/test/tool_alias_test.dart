import 'package:agent_core/agent_core.dart';
import 'package:test/test.dart';

class _AliasModel implements AgentModel {
  final requests = <ModelRequest>[];
  @override
  Future<ModelResponse> complete(
    ModelRequest request,
    CancellationToken cancellation,
  ) async {
    requests.add(request);
    return ModelResponse(
      message: AssistantMessage(
        provider: 'test',
        model: 'test',
        content: requests.length == 1
            ? [
                ToolCallBlock(
                  id: 'old-call',
                  name: 'old_query',
                  input: const {},
                ),
              ]
            : [const TextBlock(text: '已读取')],
      ),
      stopReason: requests.length == 1
          ? ModelStopReason.toolUse
          : ModelStopReason.completed,
    );
  }
}

void main() {
  test('隐藏兼容别名不占新请求目录，旧调用仍可执行', () async {
    final model = _AliasModel();
    var calls = 0;
    AgentTool tool(String name, {bool exposed = true}) => AgentTool(
      definition: ToolDefinition(
        name: name,
        description: '查询',
        inputSchema: const {
          'type': 'object',
          'properties': <String, Object?>{},
          'additionalProperties': false,
        },
      ),
      readOnly: true,
      exposed: exposed,
      execute: (i, c) {
        calls++;
        return const ToolOutput.success('真实结果');
      },
    );
    final agent = AgentLoop(
      model: model,
      systemPrompt: '测试',
      tools: [tool('getData'), tool('old_query', exposed: false)],
      authorize: (t, c, k) => const ToolDecision.allow(),
    );
    try {
      final result = await agent.run(input: '读取');
      expect(result.answer, '已读取');
      expect(calls, 1);
      for (final request in model.requests) {
        expect(request.tools.map((t) => t.name), ['getData']);
      }
    } finally {
      await agent.close();
    }
  });
}

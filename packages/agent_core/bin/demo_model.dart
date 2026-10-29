import 'dart:convert';

import 'package:agent_core/agent_core.dart';
import 'package:uuid/uuid.dart';

/// 只用于 --demo 的脚本模型：展示同一个流式循环，时间仍由真实工具读取。
final class DemoModel implements StreamingAgentModel {
  @override
  Future<ModelResponse> complete(
    ModelRequest request,
    CancellationToken cancellation,
  ) async {
    return (await stream(request, cancellation).last as ModelCompleted)
        .response;
  }

  @override
  Stream<ModelStreamEvent> stream(
    ModelRequest request,
    CancellationToken cancellation,
  ) async* {
    cancellation.throwIfCancelled();
    final last = request.messages.last;
    if (request.purpose == ModelRequestPurpose.summary) {
      yield ModelCompleted(_text('用户正在体验 MissionBook 助理，之前的原始记录保留；继续完成最新要求。'));
      return;
    }
    if (last is UserMessage &&
        (last.text.contains('时间') || last.text.contains('time'))) {
      yield ModelCompleted(
        ModelResponse(
          message: AssistantMessage(
            provider: 'demo',
            model: 'offline',
            content: [
              ToolCallBlock(
                id: const Uuid().v4(),
                name: 'get_current_time',
                input: {},
              ),
            ],
          ),
          stopReason: ModelStopReason.toolUse,
        ),
      );
      return;
    }
    String answer;
    if (last is ToolResultMessage) {
      final json = jsonDecode(last.text) as Map<String, Object?>;
      answer = '设备时间：${json['local_time'] ?? json['localTime'] ?? last.text}。';
    } else {
      answer =
          '这是 MissionBook 助理的离线演示。\n\n你可以继续对话、查询设备时间，或用 /help 查看命令。退出演示后，正常启动即可连接配置中的真实模型。';
    }
    for (var start = 0; start < answer.length; start += 8) {
      cancellation.throwIfCancelled();
      await cancellation.delay(const Duration(milliseconds: 12));
      yield ModelTextDelta(
        0,
        answer.substring(start, (start + 8).clamp(0, answer.length)),
      );
    }
    yield ModelCompleted(_text(answer));
  }

  ModelResponse _text(String text) => ModelResponse(
    message: AssistantMessage(
      provider: 'demo',
      model: 'offline',
      content: [TextBlock(text: text)],
    ),
    stopReason: ModelStopReason.completed,
    usage: const TokenUsage(inputTokens: 40, outputTokens: 30),
  );
}

import 'dart:convert';

import 'package:agent_core/agent_core.dart';

/// 演示中实际执行的只读工具；时间来自当前设备，不来自模型猜测。
AgentTool currentTimeTool() {
  return AgentTool(
    definition: ToolDefinition(
      name: 'get_current_time',
      description: '读取用户设备的当前本地时间及 UTC 偏移。',
      inputSchema: {
        'type': 'object',
        'properties': <String, Object?>{},
        'additionalProperties': false,
      },
    ),
    execute: (input, context) {
      context.cancellation.throwIfCancelled();
      final now = DateTime.now();
      return ToolOutput.success(
        jsonEncode({
          'local_time': now.toIso8601String(),
          'utc_offset_minutes': now.timeZoneOffset.inMinutes,
        }),
      );
    },
  );
}

/// 示例只允许一个本机只读工具；App 的三档权限需由实际权限策略替换。
ToolDecision authorizeDemoTool(
  ToolDefinition tool,
  ToolCallBlock call,
  CancellationToken cancellation,
) {
  if (tool.name == 'get_current_time') return const ToolDecision.allow();
  return const ToolDecision.deny('示例没有开放这个工具');
}

void printAgentEvent(AgentEvent event) {
  switch (event) {
    case ModelRequestStarted():
      print('[第 ${event.step} 次请求] 请求模型');
    case AssistantReceived():
      final calls = event.message.toolCalls;
      if (calls.isNotEmpty) print('[模型] 提出 ${calls.length} 次工具调用');
    case ToolCallStarted():
      print('[工具] ${event.call.name}，参数：${jsonEncode(event.call.input)}');
    case ToolCallFinished():
      print('[工具结果] ${event.result.text}');
    case AgentRunFinished():
      print('[结束] ${event.result.reason.name}');
    case ModelAttemptStarted():
      if (event.attempt > 1) print('[重试] 第 ${event.attempt} 次尝试');
    case ModelAttemptFailed():
      print('[请求失败] ${event.failure.message}，继续重试：${event.willRetry}');
    case ContextCompacted():
      print(
        '[压缩] ${event.compaction.beforeTokens} → ${event.compaction.afterTokens} 估算 tokens',
      );
    case UserMessageAccepted() ||
        ModelStreamUpdated() ||
        ToolExecutionStarted():
      break;
  }
}

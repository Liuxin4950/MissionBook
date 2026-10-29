import 'agent_result.dart';
import 'content_block.dart';
import 'message.dart';
import 'model.dart';
import 'context/context_compactor.dart';

/// UI 或示例可以订阅运行过程；这些事件不充当业务数据库事实。
sealed class AgentEvent {
  const AgentEvent(this.step);

  final int step;
}

final class ModelRequestStarted extends AgentEvent {
  const ModelRequestStarted(super.step);
}

final class UserMessageAccepted extends AgentEvent {
  const UserMessageAccepted(super.step, this.message);
  final UserMessage message;
}

final class ModelAttemptStarted extends AgentEvent {
  const ModelAttemptStarted(super.step, this.attempt, this.request);
  final int attempt;
  final ModelRequest request;
}

final class ModelStreamUpdated extends AgentEvent {
  const ModelStreamUpdated(
    super.step,
    this.attempt,
    this.update, {
    this.purpose = ModelRequestPurpose.conversation,
  });
  final int attempt;
  final ModelStreamEvent update;
  final ModelRequestPurpose purpose; // 摘要增量不应显示成助理的正式回答。
}

final class ModelAttemptFailed extends AgentEvent {
  const ModelAttemptFailed(
    super.step,
    this.attempt,
    this.failure, {
    required this.willRetry,
    required this.partialText,
    required this.delay,
  });
  final int attempt;
  final AgentFailure failure;
  final bool willRetry;
  final String partialText; // 仅供显示中断的尝试，不加入模型消息历史。
  final Duration delay;
}

final class ModelUsageReported extends AgentEvent {
  const ModelUsageReported(
    super.step,
    this.attempt,
    this.usage,
    this.purpose, {
    required this.complete,
  });
  final int attempt;
  final TokenUsage usage;
  final ModelRequestPurpose purpose;
  final bool complete; // false 表示本次尝试未完整结束，账单可能还包含未报告部分。
}

/// 此事件在授权后、工具执行前发布，是重启后判断结果是否未知的依据。
final class ToolExecutionStarted extends AgentEvent {
  const ToolExecutionStarted(super.step, this.call, {this.readOnly = false});
  final ToolCallBlock call;
  final bool readOnly;
}

final class AssistantReceived extends AgentEvent {
  const AssistantReceived(
    super.step,
    this.message, {
    this.usage = const TokenUsage(),
  });

  final AssistantMessage message;
  final TokenUsage usage;
}

final class ContextCompacted extends AgentEvent {
  const ContextCompacted(super.step, this.compaction);
  final ContextCompaction compaction;
}

final class ToolCallStarted extends AgentEvent {
  const ToolCallStarted(super.step, this.call);

  final ToolCallBlock call;
}

final class ToolCallFinished extends AgentEvent {
  const ToolCallFinished(super.step, this.call, this.result);

  final ToolCallBlock call;
  final ToolResultMessage result;
}

final class AgentRunFinished extends AgentEvent {
  const AgentRunFinished(super.step, this.result);

  final AgentRunResult result;
}

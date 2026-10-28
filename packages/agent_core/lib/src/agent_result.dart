import 'message.dart';
import 'model.dart';

enum AgentStopReason {
  completed,
  maxSteps,
  maxTokens,
  cancelled,
  refused,
  interrupted,
  failed,
}

/// 关键记录无法保存时必须停止；写入结果可能仍存在于本次进程快照。
final class AgentPersistenceException implements Exception {
  const AgentPersistenceException(this.message, {this.cause});
  final String message;
  final Object? cause;
  @override
  String toString() => message;
}

/// 一轮运行无法继续的原因；cause 供开发时排错，不发给模型。
final class AgentFailure {
  const AgentFailure(this.code, this.message, {this.cause});

  final String code;
  final String message;
  final Object? cause;

  @override
  String toString() => '$code: $message';
}

/// 一轮运行的事实快照，可把 messages 传回下一轮继续对话。
final class AgentRunResult {
  AgentRunResult({
    required this.reason,
    required List<AgentMessage> messages,
    required this.modelSteps,
    this.failure,
    List<AgentMessage>? contextMessages,
    this.usage = const TokenUsage(),
    this.modelAttempts = 0,
    this.compactions = 0,
  }) : messages = List.unmodifiable(messages),
       contextMessages = List.unmodifiable(contextMessages ?? messages);

  final AgentStopReason reason;
  final List<AgentMessage> messages;
  final int modelSteps; // 实际开始了几次模型请求，不是工具调用次数。
  final AgentFailure? failure;
  final List<AgentMessage> contextMessages; // 发给下一次模型的投影，可能包含摘要。
  final TokenUsage usage;
  final int modelAttempts;
  final int compactions;

  /// 只有完整结束时才把最后一条模型消息当成最终回答。
  String? get answer {
    if (reason != AgentStopReason.completed) return null;
    return messages.whereType<AssistantMessage>().last.text;
  }
}

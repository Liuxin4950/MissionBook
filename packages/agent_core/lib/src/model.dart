import 'cancellation.dart';
import 'message.dart';
import 'tool.dart';
import 'models/configuration.dart';

enum ModelRequestPurpose { conversation, summary }

/// 循环交给模型的完整输入；具体 HTTP 格式由适配器转换。
final class ModelRequest {
  ModelRequest({
    required this.systemPrompt,
    required List<AgentMessage> messages,
    required List<ToolDefinition> tools,
    this.maxOutputTokens,
    this.reasoningEffort,
    this.jsonOutput = false,
    this.purpose = ModelRequestPurpose.conversation,
  }) : messages = List.unmodifiable(messages),
       tools = List.unmodifiable(tools);

  final String systemPrompt;
  final List<AgentMessage> messages;
  final List<ToolDefinition> tools;
  final int? maxOutputTokens; // 摘要请求可采用比普通回答更小的输出上限。
  final ReasoningEffort? reasoningEffort; // 会话的选择；不传时采用模型配置。
  final bool jsonOutput; // 仅 Chat Completions 的 JSON 对象模式。
  final ModelRequestPurpose purpose;
}

enum ModelStopReason { completed, toolUse, maxTokens, refused }

/// 供应商报告的实际使用量；与本地上下文估算分开保存。
final class TokenUsage {
  const TokenUsage({
    this.inputTokens = 0,
    this.outputTokens = 0,
    this.cachedInputTokens = 0,
    this.cacheWriteTokens = 0,
    this.reasoningTokens = 0,
    this.cacheReported,
    this.reasoningReported,
  });
  final int inputTokens; // 全部输入，包含缓存命中和写入；协议差异在适配器内归一化。
  final int outputTokens; // 全部输出，包含推理 token。
  final int cachedInputTokens; // inputTokens 中命中缓存的部分，不应再次累加。
  final int cacheWriteTokens; // inputTokens 中写入缓存的部分；DeepSeek 自动缓存通常为 0。
  final int reasoningTokens; // outputTokens 中推理 token 的子集。

  /// null 表示还没有样本；false 表示供应商本次没有报告该桶，不能当作 0。
  final bool? cacheReported;
  final bool? reasoningReported;

  int get totalTokens => inputTokens + outputTokens;

  double? get cacheHitRate => cacheReported == true && inputTokens > 0
      ? cachedInputTokens / inputTokens
      : null;

  TokenUsage operator +(TokenUsage other) => TokenUsage(
    inputTokens: inputTokens + other.inputTokens,
    outputTokens: outputTokens + other.outputTokens,
    cachedInputTokens: cachedInputTokens + other.cachedInputTokens,
    cacheWriteTokens: cacheWriteTokens + other.cacheWriteTokens,
    reasoningTokens: reasoningTokens + other.reasoningTokens,
    cacheReported: _mergeReported(cacheReported, other.cacheReported),
    reasoningReported: _mergeReported(
      reasoningReported,
      other.reasoningReported,
    ),
  );

  static bool? _mergeReported(bool? left, bool? right) {
    if (left == null) return right;
    if (right == null) return left;
    return left && right;
  }

  Map<String, Object?> toJson() => {
    'inputTokens': inputTokens,
    'outputTokens': outputTokens,
    'cachedInputTokens': cachedInputTokens,
    if (cacheWriteTokens > 0) 'cacheWriteTokens': cacheWriteTokens,
    if (reasoningTokens > 0) 'reasoningTokens': reasoningTokens,
    if (cacheReported != null) 'cacheReported': cacheReported,
    if (reasoningReported != null) 'reasoningReported': reasoningReported,
  };

  factory TokenUsage.fromJson(Map<String, Object?> json) {
    int count(String key) {
      final value = json[key] ?? 0;
      if (value is! int || value < 0) {
        throw const FormatException('无效 token 使用量');
      }
      return value;
    }

    final input = count('inputTokens');
    final output = count('outputTokens');
    final cached = count('cachedInputTokens');
    final cacheWrite = count('cacheWriteTokens');
    final reasoning = count('reasoningTokens');
    if (cached > input || cacheWrite > input || reasoning > output) {
      throw const FormatException('token 用量分桶超过总量');
    }
    final cacheReported = json['cacheReported'];
    final reasoningReported = json['reasoningReported'];
    if (cacheReported != null && cacheReported is! bool ||
        reasoningReported != null && reasoningReported is! bool) {
      throw const FormatException('无效 token 用量标记');
    }
    return TokenUsage(
      inputTokens: input,
      outputTokens: output,
      cachedInputTokens: cached,
      cacheWriteTokens: cacheWrite,
      reasoningTokens: reasoning,
      // 旧日志只有缓存数；正数能证明供应商报告过，0 则保持不确定。
      cacheReported: cacheReported as bool? ?? (cached > 0 ? true : null),
      reasoningReported:
          reasoningReported as bool? ?? (reasoning > 0 ? true : null),
    );
  }
}

/// 一次模型请求的完整结果，还没有执行其中的工具。
final class ModelResponse {
  const ModelResponse({
    required this.message,
    required this.stopReason,
    this.usage = const TokenUsage(),
  });

  final AssistantMessage message;
  final ModelStopReason stopReason;
  final TokenUsage usage;
}

/// 循环实际使用的模型能力，DeepSeek 和离线示例都实现这个接口。
abstract interface class AgentModel {
  Future<ModelResponse> complete(
    ModelRequest request,
    CancellationToken cancellation,
  );
}

/// 提供增量输出的模型；完整消息仍由最后的 ModelCompleted 交付。
abstract interface class StreamingAgentModel implements AgentModel {
  Stream<ModelStreamEvent> stream(
    ModelRequest request,
    CancellationToken cancellation,
  );
}

sealed class ModelStreamEvent {
  const ModelStreamEvent();
}

final class ModelTextDelta extends ModelStreamEvent {
  const ModelTextDelta(this.index, this.text);
  final int index;
  final String text;
}

final class ModelThinkingDelta extends ModelStreamEvent {
  const ModelThinkingDelta(this.index, this.text);
  final int index;
  final String text;
}

/// 供应商在结束前报告的累计用量；即使随后断流，也能保留已经收到的计数。
final class ModelUsageSnapshot extends ModelStreamEvent {
  const ModelUsageSnapshot(this.usage);
  final TokenUsage usage;
}

final class ModelToolCallDelta extends ModelStreamEvent {
  const ModelToolCallDelta(
    this.index, {
    this.id,
    this.name,
    this.argumentsDelta = '',
  });
  final int index;
  final String? id;
  final String? name;
  final String argumentsDelta;
}

final class ModelCompleted extends ModelStreamEvent {
  const ModelCompleted(this.response);
  final ModelResponse response;
}

/// 可向调用者展示的模型失败，不包含请求头或 API Key。
final class ModelException implements Exception {
  const ModelException(
    this.code,
    this.message, {
    this.statusCode,
    this.retryable = false,
    this.retryAfter,
  });

  final String code;
  final String message;
  final int? statusCode;
  final bool retryable;
  final Duration? retryAfter;

  @override
  String toString() => '$code: $message';
}

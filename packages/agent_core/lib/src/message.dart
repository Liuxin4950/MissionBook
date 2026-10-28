import 'package:uuid/uuid.dart';

import 'content_block.dart';

/// 一条带稳定编号的消息；列表复制后只读，原列表的修改不会污染历史。
sealed class AgentMessage {
  AgentMessage({required List<ContentBlock> content, String? id})
    : id = id ?? const Uuid().v4(),
      content = List.unmodifiable(content) {
    if (this.id.trim().isEmpty) throw ArgumentError('消息编号不能为空');
  }

  final String id; // 由包生成，供页面追踪同一条消息。
  final List<ContentBlock> content;

  String get text => content.whereType<TextBlock>().map((b) => b.text).join();
}

/// 用户真实输入的一条消息。
final class UserMessage extends AgentMessage {
  UserMessage({required String text, super.id})
    : super(content: [TextBlock(text: text)]);

  UserMessage.withContent({required super.content, super.id}) {
    if (content.isEmpty ||
        content.any((block) => block is! TextBlock && block is! ImageBlock)) {
      throw ArgumentError('用户消息需要文字或图片内容');
    }
  }
}

/// 由宿主提供的背景资料，来源不会伪装成用户亲口说的话。
final class ContextMessage extends AgentMessage {
  ContextMessage({required this.source, required String text, super.id})
    : super(content: [TextBlock(text: text)]) {
    if (source.trim().isEmpty) throw ArgumentError('上下文必须标明来源');
  }

  final String source;
}

/// 旧历史的模型摘要；保留被概括的消息编号，原始消息仍在会话日志。
final class ContextSummaryMessage extends AgentMessage {
  ContextSummaryMessage({
    required String text,
    required List<String> summarizedMessageIds,
    super.id,
  }) : summarizedMessageIds = List.unmodifiable(summarizedMessageIds),
       super(content: [TextBlock(text: text)]);

  final List<String> summarizedMessageIds;
}

/// 模型返回的消息，可以同时包含文字、思考和多次工具调用。
final class AssistantMessage extends AgentMessage {
  AssistantMessage({
    required super.content,
    required this.provider,
    required this.model,
    super.id,
  }) {
    if (content.any((block) => block is ImageBlock)) {
      throw ArgumentError('当前模型响应只支持文字、思考和工具调用');
    }
  }

  final String provider; // 产生本条消息的供应商。
  final String model; // 产生本条消息的模型，不从当前配置反推历史。

  List<ToolCallBlock> get toolCalls =>
      content.whereType<ToolCallBlock>().toList();
}

/// Dart 工具执行后产生的真实结果，与模型自己说的话分开。
final class ToolResultMessage extends AgentMessage {
  ToolResultMessage({
    required this.toolCallId,
    required this.toolName,
    required String text,
    this.isError = false,
    this.errorCode,
    super.id,
  }) : super(content: [TextBlock(text: text)]);

  final String toolCallId; // 必须对应前一条模型消息中的一个调用编号。
  final String toolName;
  final bool isError;
  final String? errorCode; // 稳定错误种类，恢复时不用解析显示文字。
}

/// 检查调用与结果一一对应，返回已用过的调用编号。
Set<String> validateConversation(List<AgentMessage> messages) {
  final messageIds = <String>{};
  final usedCallIds = <String>{};
  final pending = <String, String>{};
  for (final message in messages) {
    if (message.id.isEmpty || !messageIds.add(message.id)) {
      throw const FormatException('消息编号为空或重复');
    }
    if (message is ToolResultMessage) {
      if (pending[message.toolCallId] != message.toolName) {
        throw const FormatException('工具结果没有对应的调用，或工具名称不一致');
      }
      pending.remove(message.toolCallId);
      continue;
    }
    if (pending.isNotEmpty) {
      throw const FormatException('工具调用必须先收到全部结果，才能追加下一条消息');
    }
    if (message is AssistantMessage) {
      for (final call in message.toolCalls) {
        if (!usedCallIds.add(call.id)) {
          throw const FormatException('工具调用编号重复');
        }
        pending[call.id] = call.name;
      }
    }
  }
  if (pending.isNotEmpty) {
    throw const FormatException('历史中还有未结束的工具调用');
  }
  return usedCallIds;
}

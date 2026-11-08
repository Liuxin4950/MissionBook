import 'package:agent_core/agent_core.dart';

/// 展示位置引用原消息和内容块，不拼接跨请求的思考，也不改写会话。
class AssistantTurnPart {
  const AssistantTurnPart(this.message, this.block, this.index);
  final AssistantMessage message;
  final ContentBlock block;
  final int index;
  String get key => '${message.id}:$index';
  bool get isReply => message.toolCalls.isEmpty && block is! ThinkingBlock;
}

List<AssistantTurnPart> assistantTurnParts(
  Iterable<AssistantMessage> messages,
) => [
  for (final message in messages)
    for (var index = 0; index < message.content.length; index++)
      AssistantTurnPart(message, message.content[index], index),
];

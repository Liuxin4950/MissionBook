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

/// 连续的过程块才合并；不同请求和回答之间保持原始顺序。
class AssistantTurnSection {
  const AssistantTurnSection(this.key, this.process, this.parts);
  final String key;
  final bool process;
  final List<AssistantTurnPart> parts;
}

List<AssistantTurnSection> assistantTurnSections(
  AssistantMessage message,
  String requestKey,
) {
  final sections = <AssistantTurnSection>[];
  for (final part in assistantTurnParts([message])) {
    final process = !part.isReply;
    if (sections.isEmpty || sections.last.process != process) {
      sections.add(
        AssistantTurnSection(
          '$requestKey:section:${sections.length}',
          process,
          [],
        ),
      );
    }
    sections.last.parts.add(part);
  }
  return sections;
}

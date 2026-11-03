part of 'assistant_page.dart';

class _AssistantTurn extends StatelessWidget {
  const _AssistantTurn({
    super.key,
    required this.messages,
    required this.operations,
    required this.controller,
    required this.onOpenReference,
    this.running = false,
    this.focusOperationCallId,
  });
  final List<AssistantMessage> messages;
  final Map<String, AssistantOperation> operations;
  final AssistantController controller;
  final void Function(String, String) onOpenReference;
  final bool running;
  final String? focusOperationCallId;

  @override
  Widget build(BuildContext context) {
    final process = <Widget>[];
    final replies = <Widget>[];
    final calls = <String>{};
    var needsAttention = false;
    for (final part in assistantTurnParts(messages)) {
      final block = part.block;
      if (block is ThinkingBlock && block.text.trim().isNotEmpty) {
        process.add(
          AssistantThinking(key: ValueKey(part.key), text: block.text),
        );
      } else if (block is ToolCallBlock) {
        calls.add(block.id);
        final operation = operations[block.id];
        if (operation == null) continue;
        needsAttention =
            needsAttention ||
            const [
              AssistantOperationStatus.waitingConfirmation,
              AssistantOperationStatus.failed,
              AssistantOperationStatus.unknown,
            ].contains(operation.status);
        process.add(
          AssistantOperationCard(
            key: ValueKey(block.id),
            controller: controller,
            operation: operation,
            initiallyExpanded: block.id == focusOperationCallId,
            onOpenReference: onOpenReference,
          ),
        );
      } else if (part.isReply &&
          (block is! TextBlock || block.text.trim().isNotEmpty)) {
        replies.add(
          _MessageBubble(
            key: ValueKey(part.key),
            message: part.message,
            visibleContent: [block],
            isUser: false,
          ),
        );
      } else if (block is TextBlock && block.text.trim().isNotEmpty) {
        process.add(
          Padding(
            key: ValueKey(part.key),
            padding: const EdgeInsets.symmetric(vertical: AppLayout.spaceSm),
            child: AssistantMarkdown(text: block.text, compact: true),
          ),
        );
      }
    }
    final activity = controller.activity;
    final live = running && activity.modelRequestRunning;
    if (live && activity.thinking.isNotEmpty) {
      process.add(
        AssistantThinking(
          key: ValueKey('live-thinking-${activity.requestSerial}'),
          text: activity.thinking,
          streaming: true,
        ),
      );
    }
    if (live && activity.text.isNotEmpty) {
      replies.add(
        _StreamingBubble(
          key: ValueKey('live-reply-${activity.requestSerial}'),
          text: activity.text,
        ),
      );
    }
    final label = needsAttention
        ? operations.values.any(
                (operation) =>
                    calls.contains(operation.callId) &&
                    operation.status ==
                        AssistantOperationStatus.waitingConfirmation,
              )
              ? '等待确认操作'
              : '操作需要处理'
        : !running
        ? '处理过程'
        : activity.toolName != null
        ? '正在执行操作'
        : live && activity.thinking.isNotEmpty && activity.text.isEmpty
        ? '正在思考'
        : live
        ? '正在生成回复'
        : '正在处理';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (process.isNotEmpty || live)
          AssistantProcess(
            running: running,
            initiallyExpanded: calls.contains(focusOperationCallId),
            needsAttention: needsAttention,
            label: label,
            operationCount: calls.length,
            children: process,
          ),
        for (var index = 0; index < replies.length; index++) ...[
          if (index > 0) const SizedBox(height: AppLayout.spaceSm),
          replies[index],
        ],
      ],
    );
  }
}

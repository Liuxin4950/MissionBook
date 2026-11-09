part of 'assistant_page.dart';

class _AssistantTurn extends StatelessWidget {
  const _AssistantTurn({
    super.key,
    required this.messages,
    required this.operations,
    required this.controller,
    required this.onOpenReference,
    required this.userMessageId,
    this.running = false,
    this.focusOperationCallId,
  });
  final List<AssistantMessage> messages;
  final Map<String, AssistantOperation> operations;
  final AssistantController controller;
  final void Function(String, String) onOpenReference;
  final String userMessageId;
  final bool running;
  final String? focusOperationCallId;

  @override
  Widget build(BuildContext context) {
    // 始终保留同一层级；实时请求完成后不会卸载用户展开的过程子树。
    final attempts = controller.interruptedAttempts
        .where((attempt) => attempt.userMessageId == userMessageId)
        .toList();
    Widget content(SessionActivity? activity) => AssistantTurnContent(
      identity: userMessageId,
      messages: messages,
      attempts: attempts,
      operations: operations,
      controller: controller,
      activity: activity,
      running: running,
      focusOperationCallId: focusOperationCallId,
      onOpenReference: onOpenReference,
      replyBuilder: (message, block, key, streaming, slice, first, last) =>
          _MessageBubble(
            key: ValueKey(key),
            message: message,
            visibleContent: [block],
            isUser: false,
            streaming: streaming,
            markdownSlice: slice,
            firstSlice: first,
            lastSlice: last,
          ),
    );
    return ValueListenableBuilder<SessionActivity>(
      valueListenable: controller.liveActivity,
      child: running ? null : content(null),
      builder: (context, activity, child) =>
          running ? content(activity) : child!,
    );
  }
}

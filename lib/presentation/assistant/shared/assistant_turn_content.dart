import 'package:agent_core/agent_core.dart';
import 'package:flutter/material.dart';

import '../../../application/assistant/assistant_controller.dart';
import '../../../core/theme/app_layout.dart';
import '../operations/assistant_operation_card.dart';
import 'assistant_markdown.dart';
import 'assistant_thinking.dart';
import 'assistant_turn_display.dart';

typedef AssistantReplyBuilder =
    Widget Function(
      AssistantMessage message,
      ContentBlock block,
      String key,
      bool streaming,
      AssistantMarkdownSlice? slice,
      bool first,
      bool last,
    );

/// 主聊天与浮窗共同使用的时间线，展示内容始终保持请求和块的原始顺序。
class AssistantTurnContent extends StatelessWidget {
  const AssistantTurnContent({
    super.key,
    required this.identity,
    required this.messages,
    required this.attempts,
    required this.operations,
    required this.controller,
    required this.onOpenReference,
    this.activity,
    this.running = false,
    this.focusOperationCallId,
    this.replyBuilder,
    this.onOpenOperation,
  });
  final String identity;
  final List<AssistantMessage> messages;
  final List<InterruptedModelAttempt> attempts;
  final Map<String, AssistantOperation> operations;
  final AssistantController controller;
  final SessionActivity? activity;
  final bool running;
  final String? focusOperationCallId;
  final void Function(String, String) onOpenReference;
  final AssistantReplyBuilder? replyBuilder;
  final ValueChanged<String>? onOpenOperation;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: buildEntries(context),
  );

  List<Widget> buildEntries(BuildContext context, {bool splitReplies = false}) {
    final children = <Widget>[];
    var requestIndex = 0;
    for (var index = 0; index <= messages.length; index++) {
      for (final attempt in attempts.where(
        (item) => item.messageIndex == index,
      )) {
        final key = '$identity:request:${requestIndex++}';
        children.addAll(
          _request(
            context,
            AssistantMessage(
              content: [
                if (attempt.thinking.isNotEmpty)
                  ThinkingBlock(text: attempt.thinking),
                if (attempt.text.isNotEmpty) TextBlock(text: attempt.text),
              ],
              provider: 'interrupted',
              model: 'interrupted',
            ),
            key,
            interrupted: attempt,
            splitReplies: splitReplies,
          ),
        );
      }
      if (index < messages.length) {
        children.addAll(
          _request(
            context,
            messages[index],
            '$identity:request:${requestIndex++}',
            splitReplies: splitReplies,
          ),
        );
      }
    }
    final live = running && (activity?.modelRequestRunning ?? false);
    if (live) {
      children.addAll(
        _request(
          context,
          AssistantMessage(
            content: [
              if (activity!.thinking.isNotEmpty)
                ThinkingBlock(text: activity!.thinking),
              if (activity!.text.isNotEmpty) TextBlock(text: activity!.text),
            ],
            provider: 'streaming',
            model: 'streaming',
          ),
          '$identity:request:$requestIndex',
          streaming: true,
        ),
      );
    } else if (running && messages.isEmpty) {
      children.add(
        const Padding(
          padding: EdgeInsets.all(AppLayout.spaceSm),
          child: Text('正在准备请求…'),
        ),
      );
    }
    return children;
  }

  List<Widget> _request(
    BuildContext context,
    AssistantMessage message,
    String key, {
    bool streaming = false,
    InterruptedModelAttempt? interrupted,
    bool splitReplies = false,
  }) {
    final children = <Widget>[];
    if (streaming && message.content.isEmpty) {
      children.add(
        const Padding(
          padding: EdgeInsets.all(AppLayout.spaceSm),
          child: Row(
            children: [
              SizedBox.square(
                dimension: AppLayout.iconSm,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              SizedBox(width: AppLayout.spaceSm),
              Text('正在等待模型响应…'),
            ],
          ),
        ),
      );
    }
    final sections = assistantTurnSections(message, key);
    for (final section in sections) {
      final content = <Widget>[];
      final calls = <String>[];
      var needsAttention = false;
      for (final part in section.parts) {
        final block = part.block;
        final blockKey = '${section.key}:block:${part.index}';
        if (block is ThinkingBlock && block.text.trim().isNotEmpty) {
          content.add(
            AssistantThinking(
              key: ValueKey(blockKey),
              text: block.text,
              streaming: streaming && (activity?.text.isEmpty ?? true),
            ),
          );
        } else if (block is ToolCallBlock) {
          calls.add(block.id);
          final operation = operations[block.id];
          if (operation == null) {
            content.add(Text('${assistantToolLabel(block.name)} · 状态暂不可用'));
            continue;
          }
          needsAttention |= const [
            AssistantOperationStatus.waitingConfirmation,
            AssistantOperationStatus.failed,
            AssistantOperationStatus.unknown,
          ].contains(operation.status);
          content.add(
            onOpenOperation == null
                ? AssistantOperationCard(
                    key: ValueKey(block.id),
                    controller: controller,
                    operation: operation,
                    initiallyExpanded: block.id == focusOperationCallId,
                    onOpenReference: onOpenReference,
                  )
                : TextButton.icon(
                    key: ValueKey(block.id),
                    onPressed: () => onOpenOperation!(block.id),
                    icon: Icon(
                      operation.status == AssistantOperationStatus.succeeded
                          ? Icons.check_circle_outline
                          : Icons.receipt_long_outlined,
                      size: AppLayout.iconSm,
                    ),
                    label: Text(
                      '${assistantToolLabel(block.name)} · ${assistantOperationStatusLabel(operation.status, compact: true)}',
                    ),
                  ),
          );
        } else if (block is TextBlock && block.text.trim().isNotEmpty) {
          if (!section.process &&
              splitReplies &&
              block.text.length >= 4000 &&
              replyBuilder != null) {
            final slices = AssistantMarkdown.slices(block.text);
            for (var index = 0; index < slices.length; index++) {
              content.add(
                replyBuilder!(
                  message,
                  block,
                  '$blockKey:slice:$index',
                  streaming,
                  slices[index],
                  index == 0,
                  index == slices.length - 1,
                ),
              );
            }
          } else {
            content.add(
              section.process
                  ? AssistantMarkdown(
                      key: ValueKey(blockKey),
                      text: block.text,
                      compact: true,
                      streaming: streaming,
                    )
                  : replyBuilder?.call(
                          message,
                          block,
                          blockKey,
                          streaming,
                          null,
                          true,
                          true,
                        ) ??
                        AssistantMarkdown(
                          key: ValueKey(blockKey),
                          text: block.text,
                          streaming: streaming,
                        ),
            );
          }
        } else if (!section.process && replyBuilder != null) {
          content.add(
            replyBuilder!(
              message,
              block,
              blockKey,
              streaming,
              null,
              true,
              true,
            ),
          );
        }
      }
      if (section.process) {
        final waiting = calls.any(
          (id) =>
              operations[id]?.status ==
              AssistantOperationStatus.waitingConfirmation,
        );
        children.add(
          AssistantProcess(
            key: ValueKey(section.key),
            running:
                streaming ||
                (running &&
                    calls.any(
                      (id) =>
                          operations[id]?.status ==
                          AssistantOperationStatus.running,
                    )),
            needsAttention: needsAttention,
            initiallyExpanded: calls.contains(focusOperationCallId),
            label: waiting
                ? '等待确认操作'
                : needsAttention
                ? '操作需要处理'
                : streaming
                ? '正在思考'
                : '处理过程',
            operationCount: calls.length,
            children: content,
          ),
        );
      } else {
        children.addAll(content);
      }
    }
    if (interrupted != null) {
      children.add(
        Padding(
          padding: const EdgeInsets.symmetric(vertical: AppLayout.spaceSm),
          child: Text(
            '本次输出未完成 · ${interrupted.message}${interrupted.willRetry ? '（已安排重试）' : ''}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
      );
    }
    if (splitReplies) return children;
    return [
      Padding(
        key: ValueKey(key),
        padding: const EdgeInsets.only(bottom: AppLayout.spaceSm),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: children,
        ),
      ),
    ];
  }
}

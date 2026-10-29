import 'package:flutter/material.dart';

import '../../application/assistant/assistant_controller.dart';
import '../../core/theme/app_layout.dart';
import '../../core/theme/colors.dart';
import '../widgets/app_confirm_dialog.dart';
import '../widgets/app_section_card.dart';
import '../widgets/app_top_bar.dart';

class AssistantHistoryPage extends StatelessWidget {
  const AssistantHistoryPage({super.key, required this.controller});

  final AssistantController controller;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: const AppTopBar(title: '会话历史'),
    body: SafeArea(
      top: false,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: AppLayout.maxPageWidth),
          child: ListenableBuilder(
            listenable: controller,
            builder: (context, _) {
              if (controller.conversations.isEmpty) {
                return const Center(child: Text('还没有保存的会话'));
              }
              return ListView(
                padding: AppLayout.pagePadding(context),
                children: [
                  for (final conversation in controller.conversations)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: AppSectionCard(
                        padding: EdgeInsets.zero,
                        child: ListTile(
                          key: ValueKey('assistant-conversation-${conversation.id}'),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          selected: conversation.id == controller.currentSessionId,
                          selectedColor: AppColors.primary,
                          title: Text(conversation.title, maxLines: 2, overflow: TextOverflow.ellipsis),
                          subtitle: Text(
                            '${_format(conversation.updatedAt)}${conversation.missionId != null ? ' · 任务会话' : conversation.goalId != null ? ' · 目标会话' : ''}',
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (conversation.id == controller.currentSessionId)
                                IconButton(
                                  tooltip: '重命名当前会话',
                                  onPressed: controller.isRunning ? null : () => _rename(context, conversation),
                                  icon: const Icon(Icons.edit_outlined),
                                ),
                              IconButton(
                                tooltip: '删除会话 ${conversation.title}',
                                onPressed: controller.isRunning ? null : () => _delete(context, conversation),
                                icon: const Icon(Icons.delete_outline),
                              ),
                            ],
                          ),
                          onTap: controller.isRunning
                              ? null
                              : () async {
                                  try {
                                    await controller.openConversation(conversation.id);
                                    if (context.mounted) Navigator.of(context).pop();
                                  } catch (error) {
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$error')));
                                    }
                                  }
                                },
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ),
    ),
  );

  Future<void> _rename(BuildContext context, AssistantConversationSummary conversation) async {
    final input = TextEditingController(text: conversation.title);
    final title = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('重命名会话'),
        content: TextField(controller: input, autofocus: true, maxLength: 120, decoration: const InputDecoration(labelText: '会话名称')),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(), child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.of(dialogContext).pop(input.text.trim()), child: const Text('保存')),
        ],
      ),
    );
    input.dispose();
    if (title == null || title.isEmpty || !context.mounted) return;
    try {
      await controller.renameCurrentSession(title);
    } catch (error) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$error')));
    }
  }

  Future<void> _delete(BuildContext context, AssistantConversationSummary conversation) async {
    final confirmed = await showAppConfirmDialog(
      context,
      title: '删除这段会话？',
      content: '只删除“${conversation.title}”的聊天记录，不会删除任务、目标或执行事实。',
      continueText: '保留会话',
      confirmText: '删除会话',
    );
    if (confirmed != true || !context.mounted) return;
    try {
      await controller.deleteConversation(conversation.id);
    } catch (error) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$error')));
    }
  }

  static String _format(DateTime value) {
    final local = value.toLocal();
    return '${local.year}-${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')} ${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  }
}

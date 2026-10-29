import 'package:flutter/material.dart';

import '../../application/assistant/assistant_controller.dart';
import '../../core/theme/app_layout.dart';
import '../../application/assistant/assistant_conversation_store.dart';
import '../../core/theme/colors.dart';
import '../widgets/app_confirm_dialog.dart';
import '../widgets/app_top_bar.dart';

class AssistantHistoryPage extends StatefulWidget {
  const AssistantHistoryPage({super.key, required this.controller});
  final AssistantController controller;

  @override
  State<AssistantHistoryPage> createState() => _AssistantHistoryPageState();
}

class _AssistantHistoryPageState extends State<AssistantHistoryPage> {
  final _search = TextEditingController();
  AssistantController get controller => widget.controller;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: const AppTopBar(title: '会话记录', maxContentWidth: 960),
    body: SafeArea(
      top: false,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 960),
          child: Column(
            children: [
              Padding(
                padding: EdgeInsets.fromLTRB(
                  AppLayout.horizontalPadding(context),
                  12,
                  AppLayout.horizontalPadding(context),
                  8,
                ),
                child: TextField(
                  key: const Key('assistant-history-search'),
                  controller: _search,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    hintText: '搜索会话',
                    prefixIcon: const Icon(Icons.search_rounded),
                    suffixIcon: _search.text.isEmpty
                        ? null
                        : IconButton(
                            tooltip: '清空搜索',
                            onPressed: () => setState(_search.clear),
                            icon: const Icon(Icons.close, size: 18),
                          ),
                  ),
                ),
              ),
              Expanded(
                child: ListenableBuilder(
                  listenable: controller,
                  builder: (context, _) => _buildList(context),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );

  Widget _buildList(BuildContext context) {
    final query = _search.text.trim().toLowerCase();
    final conversations =
        controller.conversations
            .where(
              (item) => '${item.title} ${_contextLabel(item)}'
                  .toLowerCase()
                  .contains(query),
            )
            .toList()
          ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    if (conversations.isEmpty) {
      return Center(child: Text(query.isEmpty ? '还没有保存的会话' : '没有匹配的会话'));
    }
    final today = DateUtils.dateOnly(DateTime.now());
    final rows = <Widget>[];
    String? previousGroup;
    for (final conversation in conversations) {
      final day = DateUtils.dateOnly(conversation.updatedAt.toLocal());
      final group = day == today
          ? '今天'
          : day == DateTime(today.year, today.month, today.day - 1)
          ? '昨天'
          : '更早';
      if (group != previousGroup) {
        rows.add(
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 20, 4, 8),
            child: Text(
              group,
              style: Theme.of(
                context,
              ).textTheme.labelLarge?.copyWith(color: AppColors.textSecondary),
            ),
          ),
        );
        previousGroup = group;
      }
      final selected = conversation.id == controller.currentSessionId;
      rows.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Material(
            color: selected ? AppColors.primarySoft : Colors.transparent,
            borderRadius: BorderRadius.circular(16),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              key: ValueKey('assistant-conversation-${conversation.id}'),
              onTap: controller.isBusy
                  ? null
                  : () => _open(context, conversation),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 0, 12),
                child: Row(
                  children: [
                    const CircleAvatar(
                      radius: 20,
                      backgroundColor: AppColors.primarySoft,
                      foregroundColor: AppColors.primary,
                      child: Icon(Icons.chat_bubble_outline_rounded, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            conversation.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                          const SizedBox(height: 4),
                          Wrap(
                            spacing: 8,
                            runSpacing: 4,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Text(
                                '${_contextLabel(conversation)} · ${_format(conversation.updatedAt, today)}',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                              if (selected)
                                Text(
                                  '当前',
                                  style: Theme.of(context).textTheme.labelSmall
                                      ?.copyWith(
                                        color: AppColors.primary,
                                        fontWeight: FontWeight.w600,
                                      ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    PopupMenuButton<String>(
                      tooltip: '会话操作 ${conversation.title}',
                      enabled: !controller.isBusy,
                      icon: const Icon(Icons.more_horiz),
                      onSelected: (value) {
                        if (value == 'rename') {
                          _rename(context, conversation);
                        } else if (value == 'delete') {
                          _delete(context, conversation);
                        }
                      },
                      itemBuilder: (_) => const [
                        PopupMenuItem(value: 'rename', child: Text('重命名')),
                        PopupMenuItem(value: 'delete', child: Text('删除会话')),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }
    return ListView(
      key: const Key('assistant-history-list'),
      padding: EdgeInsets.fromLTRB(
        AppLayout.horizontalPadding(context),
        0,
        AppLayout.horizontalPadding(context),
        24,
      ),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      children: rows,
    );
  }

  static String _contextLabel(AssistantConversationSummary value) =>
      value.nodeId != null
      ? '节点会话'
      : value.missionId != null
      ? '任务会话'
      : value.goalId != null
      ? '目标会话'
      : '通用会话';

  Future<void> _open(
    BuildContext context,
    AssistantConversationSummary conversation,
  ) async {
    try {
      await controller.openConversation(conversation.id);
      if (context.mounted) Navigator.of(context).pop();
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$error')));
      }
    }
  }

  Future<void> _rename(
    BuildContext context,
    AssistantConversationSummary conversation,
  ) async {
    final title = await showDialog<String>(
      context: context,
      builder: (_) => _RenameConversationDialog(title: conversation.title),
    );
    if (title == null || title.isEmpty || !context.mounted) return;
    try {
      await controller.renameConversation(conversation.id, title);
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$error')));
      }
    }
  }

  Future<void> _delete(
    BuildContext context,
    AssistantConversationSummary conversation,
  ) async {
    final confirmed = await AppConfirmDialog.show(
      context: context,
      title: '删除这段会话？',
      message: '只删除“${conversation.title}”的聊天记录，不会删除任务、目标或执行事实。',
      cancelText: '保留会话',
      confirmText: '删除会话',
    );
    if (confirmed != true || !context.mounted) return;
    try {
      await controller.deleteConversation(conversation.id);
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$error')));
      }
    }
  }

  static String _format(DateTime value, DateTime today) {
    final local = value.toLocal();
    final time =
        '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
    if (DateUtils.dateOnly(local) == today) return time;
    final date = '${local.month}月${local.day}日';
    return '${local.year == today.year ? date : '${local.year}年$date'} $time';
  }
}

// 输入控制器随弹窗 State 释放，避免返回动画期间仍被 TextField 使用。
class _RenameConversationDialog extends StatefulWidget {
  const _RenameConversationDialog({required this.title});
  final String title;
  @override
  State<_RenameConversationDialog> createState() =>
      _RenameConversationDialogState();
}

class _RenameConversationDialogState extends State<_RenameConversationDialog> {
  late final _input = TextEditingController(text: widget.title);
  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('重命名会话'),
    content: TextField(
      controller: _input,
      autofocus: true,
      maxLength: 120,
      decoration: const InputDecoration(labelText: '会话名称'),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('取消'),
      ),
      ValueListenableBuilder<TextEditingValue>(
        valueListenable: _input,
        builder: (context, value, _) => FilledButton(
          style: FilledButton.styleFrom(
            foregroundColor: AppColors.onPrimary,
            iconColor: AppColors.onPrimary,
            backgroundColor: AppColors.primary,
            disabledForegroundColor: AppColors.onDisabled,
            disabledBackgroundColor: AppColors.disabled,
          ),
          onPressed:
              value.text.trim().isEmpty || value.text.trim() == widget.title
              ? null
              : () => Navigator.of(context).pop(value.text.trim()),
          child: const Text('保存'),
        ),
      ),
    ],
  );
}

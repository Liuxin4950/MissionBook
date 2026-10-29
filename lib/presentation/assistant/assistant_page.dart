import 'dart:async';
import 'dart:convert';

import 'package:agent_core/agent_core.dart';
import 'package:flutter/material.dart';

import '../../application/assistant/assistant_controller.dart';
import '../../core/theme/app_layout.dart';
import '../../core/theme/colors.dart';
import '../widgets/app_illustration.dart';
import '../widgets/app_page_header.dart';
import '../widgets/app_section_card.dart';
import '../widgets/app_top_bar.dart';
import '../widgets/detail_pane.dart';
import 'assistant_history_page.dart';
import 'assistant_operation_card.dart';
import 'assistant_scope.dart';
import 'assistant_settings_page.dart';

class AssistantPage extends StatefulWidget {
  const AssistantPage({super.key, required this.controller, this.showBack = false});

  final AssistantController controller;
  final bool showBack;

  @override
  State<AssistantPage> createState() => _AssistantPageState();
}

class _AssistantPageState extends State<AssistantPage> {
  final _input = TextEditingController();
  final _inputFocus = FocusNode();
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    unawaited(widget.controller.initialize());
  }

  @override
  void dispose() {
    _input.dispose();
    _inputFocus.dispose();
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: widget.showBack
        ? AppTopBar(title: '助手', actions: _headerActions())
        : null,
    body: SafeArea(
      top: false,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: AppLayout.maxPageWidth),
          child: ListenableBuilder(
            listenable: widget.controller,
            builder: (context, _) {
              final controller = widget.controller;
              return Column(
                children: [
                  if (!widget.showBack)
                    Padding(
                      padding: EdgeInsets.fromLTRB(
                        AppLayout.horizontalPadding(context),
                        AppLayout.horizontalPadding(context),
                        AppLayout.horizontalPadding(context),
                        0,
                      ),
                      child: AppPageHeader(
                        title: '助手',
                        subtitle: Text(
                          '${controller.sessionTitle} · ${controller.modelProfileId == 'deepseek' ? 'Messages' : 'Chat'}',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        action: Row(mainAxisSize: MainAxisSize.min, children: _headerActions()),
                      ),
                    ),
                  if (controller.reference != null) _ReferenceBanner(controller: controller),
                  if (controller.errorMessage != null) _ErrorBanner(controller: controller, onSettings: _openSettings),
                  if (!controller.hasCredential) _CredentialBanner(onPressed: _openSettings),
                  Expanded(
                    child: controller.initializing && controller.transcript.isEmpty
                        ? const Center(child: CircularProgressIndicator(semanticsLabel: '正在初始化助手'))
                        : _buildConversation(controller),
                  ),
                  _buildComposer(controller),
                ],
              );
            },
          ),
        ),
      ),
    ),
  );

  List<Widget> _headerActions() => [
    IconButton(
      key: const Key('assistant-new-session'),
      tooltip: '新会话',
      onPressed: widget.controller.isRunning ? null : _newSession,
      icon: const Icon(Icons.add_comment_outlined),
    ),
    IconButton(
      key: const Key('assistant-history'),
      tooltip: '会话历史',
      onPressed: widget.controller.isRunning ? null : _openHistory,
      icon: const Icon(Icons.history_outlined),
    ),
    IconButton(
      key: const Key('assistant-settings'),
      tooltip: '助手设置',
      onPressed: _openSettings,
      icon: const Icon(Icons.tune_outlined),
    ),
  ];

  Widget _buildConversation(AssistantController controller) {
    final operations = {for (final operation in controller.operations) operation.callId: operation};
    final children = <Widget>[];
    if (controller.transcript.isEmpty && controller.localSchedule == null) {
      children.add(_Welcome(onLocalSchedule: controller.loadLocalSchedule, onPrompt: _usePrompt));
    }
    if (controller.localSchedule != null) {
      children.add(_LocalScheduleCard(controller: controller, onOpen: _openReference));
    }
    for (final message in controller.transcript) {
      if (message is UserMessage) {
        children.add(_MessageBubble(key: ValueKey(message.id), message: message, isUser: true));
      } else if (message is AssistantMessage) {
        if (message.text.trim().isNotEmpty) {
          children.add(_MessageBubble(key: ValueKey(message.id), message: message, isUser: false));
        }
        for (final call in message.toolCalls) {
          final operation = operations[call.id];
          if (operation != null) {
            children.add(
              AssistantOperationCard(
                key: ValueKey(call.id),
                controller: controller,
                operation: operation,
                onOpenReference: _openReference,
              ),
            );
          }
        }
      } else if (message is ContextSummaryMessage) {
        children.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text('较早对话已压缩，原始记录仍保留', style: Theme.of(context).textTheme.bodySmall),
          ),
        );
      }
    }
    if (controller.isRunning) {
      if (controller.activity.text.isNotEmpty) {
        children.add(_StreamingBubble(text: controller.activity.text));
      }
      children.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Row(
            children: [
              const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  controller.activity.toolName == null ? '正在组织下一步…' : '正在处理 ${controller.activity.toolName}',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
              TextButton(onPressed: controller.stop, child: const Text('停止')),
            ],
          ),
        ),
      );
    }
    return ListView(
      controller: _scroll,
      padding: AppLayout.pagePadding(context),
      children: children,
    );
  }

  Widget _buildComposer(AssistantController controller) => Material(
    color: Theme.of(context).colorScheme.surfaceContainerLow,
    border: Border(top: BorderSide(color: Theme.of(context).colorScheme.outlineVariant)),
    child: Padding(
      padding: EdgeInsets.fromLTRB(
        AppLayout.horizontalPadding(context),
        12,
        AppLayout.horizontalPadding(context),
        12,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: TextField(
              key: const Key('assistant-input'),
              controller: _input,
              focusNode: _inputFocus,
              minLines: 1,
              maxLines: 5,
              textInputAction: TextInputAction.send,
              onSubmitted: controller.isRunning ? null : (_) => _send(),
              decoration: const InputDecoration(
                hintText: '描述目标，或用 @ 引用当前任务…',
                border: OutlineInputBorder(),
              ),
            ),
          ),
          const SizedBox(width: 10),
          IconButton.filled(
            key: const Key('assistant-send'),
            tooltip: controller.isRunning ? '停止本轮' : '发送',
            onPressed: controller.isRunning ? controller.stop : _send,
            style: IconButton.styleFrom(fixedSize: const Size(48, 48), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
            icon: Icon(controller.isRunning ? Icons.stop_rounded : Icons.arrow_upward_rounded),
          ),
        ],
      ),
    ),
  );

  Future<void> _send() async {
    final text = _input.text.trim();
    if (text.isEmpty || widget.controller.isRunning) return;
    if (!widget.controller.hasCredential) {
      await _openSettings();
      return;
    }
    _input.clear();
    await widget.controller.send(text);
    if (!mounted) return;
    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: MediaQuery.disableAnimationsOf(context) ? Duration.zero : const Duration(milliseconds: 240),
        curve: Curves.easeOutCubic,
      );
    });
  }

  void _usePrompt(String prompt) {
    _input.text = prompt;
    _inputFocus.requestFocus();
  }

  Future<void> _newSession() async {
    try {
      await widget.controller.startNewSession();
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$error')));
    }
  }

  Future<void> _openHistory() => openDetailPane(
    context,
    label: '会话历史',
    builder: (_) => AssistantHistoryPage(controller: widget.controller),
  );

  Future<void> _openSettings() => openDetailPane(
    context,
    label: '助手设置',
    builder: (_) => AssistantSettingsPage(controller: widget.controller),
  );

  void _openReference(String type, String id) {
    if (type == 'goal') {
      unawaited(openAssistantGoal(context, id));
    } else {
      unawaited(openAssistantMission(context, id));
    }
  }
}

class _ReferenceBanner extends StatelessWidget {
  const _ReferenceBanner({required this.controller});
  final AssistantController controller;

  @override
  Widget build(BuildContext context) {
    final reference = controller.reference!;
    return Container(
      width: double.infinity,
      color: AppColors.primarySoft,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Text(
        '${reference.type == AssistantReferenceType.mission ? '当前任务' : '当前目标'} · ${reference.title}',
        style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.primary),
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.controller, required this.onSettings});
  final AssistantController controller;
  final VoidCallback onSettings;

  @override
  Widget build(BuildContext context) => Material(
    color: AppColors.errorSoft,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Semantics(
              liveRegion: true,
              child: Text(controller.errorMessage!, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.error)),
            ),
          ),
          if (!controller.hasCredential)
            TextButton(onPressed: onSettings, child: const Text('去设置')),
          IconButton(tooltip: '关闭错误提示', onPressed: controller.clearError, icon: const Icon(Icons.close, size: 18)),
        ],
      ),
    ),
  );
}

class _CredentialBanner extends StatelessWidget {
  const _CredentialBanner({required this.onPressed});
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Material(
    color: AppColors.accentSoft,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        children: [
          Expanded(child: Text('配置模型后即可对话；本地快捷查询仍可使用', style: Theme.of(context).textTheme.bodyMedium)),
          TextButton(onPressed: onPressed, child: const Text('配置模型')),
        ],
      ),
    ),
  );
}

class _Welcome extends StatelessWidget {
  const _Welcome({required this.onLocalSchedule, required this.onPrompt});
  final Future<void> Function() onLocalSchedule;
  final ValueChanged<String> onPrompt;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 24),
    child: Column(
      children: [
        const AppIllustration(asset: 'assets/illustrations/day-plan.png', width: 160, height: 136),
        const SizedBox(height: 16),
        Text('把想法变成可检查的行动', style: Theme.of(context).textTheme.titleLarge, textAlign: TextAlign.center),
        const SizedBox(height: 8),
        Text('对话负责理解意图，卡片负责修改与确认；保存结果都能回到真实任务或目标。', style: Theme.of(context).textTheme.bodyMedium, textAlign: TextAlign.center),
        const SizedBox(height: 20),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 10,
          runSpacing: 10,
          children: [
            ActionChip(key: const Key('assistant-local-today'), avatar: const Icon(Icons.today_outlined, size: 18), label: const Text('查看今天安排'), onPressed: () => onLocalSchedule()),
            ActionChip(label: const Text('帮我安排今天'), onPressed: () => onPrompt('看看今天的安排，给我下一步建议。')),
            ActionChip(label: const Text('创建一个任务'), onPressed: () => onPrompt('创建一个任务：')),
          ],
        ),
      ],
    ),
  );
}

class _LocalScheduleCard extends StatelessWidget {
  const _LocalScheduleCard({required this.controller, required this.onOpen});
  final AssistantController controller;
  final void Function(String, String) onOpen;

  @override
  Widget build(BuildContext context) {
    final missions = controller.localSchedule!;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: AppSectionCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(child: Text('${controller.localScheduleDate} · 本地快照', style: Theme.of(context).textTheme.titleMedium)),
                IconButton(tooltip: '收起本地日程', onPressed: controller.clearLocalSchedule, icon: const Icon(Icons.close)),
              ],
            ),
            if (missions.isEmpty)
              Text('这一天还没有任务', style: Theme.of(context).textTheme.bodyMedium)
            else
              for (final item in missions)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(item.mission.title, style: Theme.of(context).textTheme.titleMedium),
                  subtitle: Text('${item.schedule.plannedDurationMinutes} 分钟 · ${item.phase.name}'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => onOpen('mission', item.mission.id),
                ),
          ],
        ),
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({super.key, required this.message, required this.isUser});
  final AgentMessage message;
  final bool isUser;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 620),
        child: Material(
          color: isUser ? colors.primary : colors.surfaceContainerLow,
          borderRadius: BorderRadius.circular(18),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (message.text.isNotEmpty)
                  SelectableText(
                    message.text,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: isUser ? colors.onPrimary : colors.onSurface),
                  ),
                for (final block in message.content.whereType<ImageBlock>())
                  Padding(padding: const EdgeInsets.only(top: 8), child: _MessageImage(block: block)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StreamingBubble extends StatelessWidget {
  const _StreamingBubble({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.centerLeft,
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 620),
      child: Material(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: SelectableText(text, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.textPrimary)),
        ),
      ),
    ),
  );
}

class _MessageImage extends StatelessWidget {
  const _MessageImage({required this.block});
  final ImageBlock block;

  @override
  Widget build(BuildContext context) {
    if (block.url.startsWith('data:image')) {
      final bytes = base64Decode(block.url.split(',').last);
      return ClipRRect(borderRadius: BorderRadius.circular(12), child: Image.memory(bytes, width: 240, fit: BoxFit.contain));
    }
    if (block.url.startsWith('http')) {
      return ClipRRect(borderRadius: BorderRadius.circular(12), child: Image.network(block.url, width: 240, fit: BoxFit.contain));
    }
    return Text(block.label ?? '云端图片引用', style: Theme.of(context).textTheme.bodySmall);
  }
}

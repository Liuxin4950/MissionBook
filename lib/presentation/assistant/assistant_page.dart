import '../../application/errors/user_error_message.dart';
import 'dart:async';
import 'dart:convert';
import 'package:agent_core/agent_core.dart';
import 'package:flutter/material.dart';
import '../../application/assistant/assistant_controller.dart';
import '../../application/assistant/assistant_attachment.dart';
import '../../application/assistant/assistant_speech.dart';
import '../../data/assistant/assistant_attachment_picker.dart';
import '../../core/theme/app_layout.dart';
import '../../core/theme/colors.dart';
import '../widgets/app_page_header.dart';
import '../widgets/app_illustration.dart';
import '../widgets/app_section_card.dart';
import '../widgets/adaptive_columns.dart';
import '../widgets/app_expansion.dart';
import '../widgets/app_top_bar.dart';
import '../missions/shared/mission_phase_display.dart';
import 'assistant_history_page.dart';
import 'assistant_markdown.dart';
import 'assistant_operation_card.dart';
import 'assistant_scope.dart';
import 'assistant_settings_page.dart';
import 'assistant_voice_status.dart';
import '../../core/theme/app_motion.dart';
part 'assistant_conversation_banners.dart';
part 'assistant_welcome.dart';
part 'assistant_message_bubble.dart';
part 'assistant_composer.dart';

class AssistantPage extends StatefulWidget {
  const AssistantPage({
    super.key,
    required this.controller,
    this.showBack = false,
    this.initialText,
  });
  final AssistantController controller;
  final bool showBack;
  final String? initialText;
  @override
  State<AssistantPage> createState() => _AssistantPageState();
}

class _AssistantPageState extends State<AssistantPage> {
  late final _composer = _AssistantComposer(this);
  void _update(VoidCallback update) => setState(update);
  final _input = TextEditingController();
  final _inputFocus = FocusNode();
  final _scroll = ScrollController(keepScrollOffset: false);
  String? _draftSession;
  bool _followOutput = true;
  bool _scrollScheduled = false;
  static const _contentWidth = AppLayout.dashboardMaxWidth;
  static const _sidebarWidth = 272.0; // 会话导航的内容宽度，不是页面间距。
  final _attachments = <AssistantAttachment>[];
  bool _picking = false;
  AssistantVoiceController? _voice;
  bool _recordingVoice = false;
  String _voicePrefix = '';
  void _controllerChanged() {
    final id = widget.controller.draftKey;
    if (id != _draftSession) {
      if (_recordingVoice) {
        _recordingVoice = false;
        unawaited(_voice?.cancel());
      }
      widget.controller.saveDraft(_draftSession, _input.text);
      widget.controller.saveAttachments(_draftSession, _attachments);
      _draftSession = id;
      _input.text = widget.controller.draftFor(id);
      _attachments
        ..clear()
        ..addAll(widget.controller.attachmentsFor(id));
      _followOutput = true;
    }
    if (_followOutput) _scrollToBottom(animate: false);
  }

  @override
  void initState() {
    super.initState();
    _draftSession = widget.controller.draftKey;
    widget.controller.addListener(_controllerChanged);
    _input.text = widget.initialText ?? widget.controller.draft;
    _attachments.addAll(widget.controller.attachmentsFor(_draftSession));
    unawaited(widget.controller.initialize());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final voice = AssistantScope.maybeOf(context)?.voice;
    if (_voice != voice) {
      _voice?.removeListener(_voiceChanged);
      _voice = voice;
      _voice?.addListener(_voiceChanged);
      // 打开助手后再后台部署离线模型，避免拖慢应用首屏。
      if (voice != null) unawaited(voice.warmUp());
    }
  }

  void _voiceChanged() {
    if (!mounted || !_recordingVoice) return;
    final text = _voice!.text;
    if (text.isNotEmpty) {
      _input.value = TextEditingValue(
        text: '$_voicePrefix$text',
        selection: TextSelection.collapsed(
          offset: _voicePrefix.length + text.length,
        ),
      );
    }
    setState(() {});
  }

  @override
  void dispose() {
    widget.controller.removeListener(_controllerChanged);
    widget.controller.saveDraft(_draftSession, _input.text);
    widget.controller.saveAttachments(_draftSession, _attachments);
    _voice?.removeListener(_voiceChanged);
    if (_recordingVoice) unawaited(_voice?.cancel());
    _input.dispose();
    _inputFocus.dispose();
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: widget.showBack
        ? PreferredSize(
            preferredSize: const Size.fromHeight(AppLayout.topBarHeight),
            child: ListenableBuilder(
              listenable: widget.controller,
              builder: (context, _) => AppTopBar(
                title: widget.controller.persona.name,
                maxContentWidth: _contentWidth,
                actions: _headerActions(),
              ),
            ),
          )
        : null,
    body: SafeArea(
      top: false,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: _contentWidth),
          child: ListenableBuilder(
            listenable: widget.controller,
            builder: (context, _) {
              final controller = widget.controller;
              final conversation = Column(
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
                        title: controller.persona.name,
                        subtitle: Text(
                          '${controller.sessionTitle} · ${controller.modelProfileId == 'deepseek' ? 'Messages' : 'Chat'}',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        action: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: _headerActions(),
                        ),
                      ),
                    ),
                  if (controller.reference != null)
                    _ReferenceBanner(controller: controller),
                  Expanded(
                    child:
                        controller.initializing && controller.transcript.isEmpty
                        ? const Center(
                            child: CircularProgressIndicator(
                              semanticsLabel: '正在初始化助手',
                            ),
                          )
                        : _buildConversation(controller),
                  ),
                  _buildComposer(controller),
                ],
              );
              return LayoutBuilder(
                builder: (context, box) {
                  final wide = _useSidebar(box.maxWidth);
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (wide)
                        SizedBox(
                          width: _sidebarWidth,
                          child: _buildSidebar(controller),
                        ),
                      Expanded(child: conversation),
                    ],
                  );
                },
              );
            },
          ),
        ),
      ),
    ),
  );
  Widget _buildSidebar(AssistantController controller) => Padding(
    padding: const EdgeInsets.fromLTRB(
      AppLayout.spaceXxl,
      AppLayout.spaceLg,
      0,
      AppLayout.spaceXxl,
    ),
    child: AppSectionCard(
      padding: const EdgeInsets.all(AppLayout.spaceLg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '会话',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              IconButton(
                key: const Key('assistant-sidebar-search'),
                tooltip: '搜索会话',
                onPressed: controller.isBusy ? null : _openHistory,
                icon: const Icon(Icons.search, size: AppLayout.iconMd),
              ),
            ],
          ),
          const SizedBox(height: AppLayout.spaceLg),
          FilledButton.tonalIcon(
            key: const Key('assistant-sidebar-new'),
            onPressed: controller.isBusy ? null : _newSession,
            icon: const Icon(Icons.add),
            label: const Text('开启新会话'),
          ),
          const SizedBox(height: AppLayout.spaceXl),
          Expanded(
            child: ListView(
              children: [
                if (controller.conversations.isEmpty)
                  const Text('对话会自动保存在这台设备上。'),
                for (final item in controller.conversations)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppLayout.spaceSm),
                    child: ListTile(
                      key: ValueKey('assistant-sidebar-${item.id}'),
                      selected: item.id == controller.currentSessionId,
                      selectedTileColor: AppColors.primarySoft,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppLayout.radiusMd),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: AppLayout.spaceMd,
                      ),
                      title: Text(
                        item.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      onTap: controller.isBusy
                          ? null
                          : () => _selectConversation(item.id),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
  Future<void> _selectConversation(String id) async {
    try {
      await widget.controller.openConversation(id);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('会话暂时无法打开，请重试')));
      }
    }
  }

  bool _useSidebar(double width) =>
      width.clamp(0, _contentWidth) >=
      1180 * MediaQuery.textScalerOf(context).scale(1);
  List<Widget> _headerActions() => [
    if (!_useSidebar(MediaQuery.sizeOf(context).width)) ...[
      IconButton(
        key: const Key('assistant-new-session'),
        tooltip: '新会话',
        onPressed: widget.controller.isBusy ? null : _newSession,
        icon: const Icon(Icons.add_comment_outlined),
      ),
      IconButton(
        key: const Key('assistant-history'),
        tooltip: '会话历史',
        onPressed: widget.controller.isBusy ? null : _openHistory,
        icon: const Icon(Icons.history_outlined),
      ),
    ],
    IconButton(
      key: const Key('assistant-settings'),
      tooltip: '助手设置',
      onPressed: _openSettings,
      icon: const Icon(Icons.tune_outlined),
    ),
  ];
  Widget _buildConversation(AssistantController controller) {
    final operations = {
      for (final operation in controller.operations)
        operation.callId: operation,
    };
    final children = <Widget>[
      if (controller.errorMessage != null)
        _ErrorBanner(controller: controller, onSettings: _openSettings),
      if (!controller.hasCredential)
        _CredentialBanner(onPressed: _openSettings),
    ];
    if (controller.transcript.isEmpty && controller.localSchedule == null) {
      children.add(
        _Welcome(
          persona: controller.persona,
          onLocalSchedule: controller.loadLocalSchedule,
          onPrompt: _usePrompt,
        ),
      );
    }
    if (controller.localSchedule != null) {
      children.add(
        _LocalScheduleCard(controller: controller, onOpen: _openReference),
      );
    }
    for (final message in controller.transcript) {
      if (message is UserMessage) {
        children.add(
          _MessageBubble(
            key: ValueKey(message.id),
            message: message,
            isUser: true,
          ),
        );
      } else if (message is AssistantMessage) {
        if (message.text.trim().isNotEmpty) {
          children.add(
            _MessageBubble(
              key: ValueKey(message.id),
              message: message,
              isUser: false,
            ),
          );
        }
        for (final call in message.toolCalls) {
          final operation = operations[call.id];
          if (operation != null) {
            children.add(
              Align(
                alignment: Alignment.centerLeft,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 860),
                  child: AssistantOperationCard(
                    key: ValueKey(call.id),
                    controller: controller,
                    operation: operation,
                    onOpenReference: _openReference,
                  ),
                ),
              ),
            );
          }
        }
      } else if (message is ContextSummaryMessage) {
        children.add(
          Padding(
            padding: const EdgeInsets.only(bottom: AppLayout.spaceMd),
            child: Text(
              '较早对话已压缩，原始记录仍保留',
              style: Theme.of(context).textTheme.bodySmall,
            ),
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
          padding: const EdgeInsets.only(bottom: AppLayout.spaceLg),
          child: Row(
            children: [
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              const SizedBox(width: AppLayout.spaceSm),
              Expanded(
                child: Text(
                  controller.operations.any(
                        (item) =>
                            item.status ==
                            AssistantOperationStatus.waitingConfirmation,
                      )
                      ? '等待你确认操作'
                      : controller.activity.toolName == null
                      ? '正在组织下一步…'
                      : '正在处理操作',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
              TextButton(onPressed: controller.stop, child: const Text('停止')),
            ],
          ),
        ),
      );
    }
    return NotificationListener<UserScrollNotification>(
      onNotification: (notification) {
        if (_scroll.hasClients) {
          _followOutput =
              _scroll.position.pixels - _scroll.position.minScrollExtent < 120;
        }
        return false;
      },
      child: ListView.separated(
        key: const Key('assistant-conversation-list'),
        reverse: controller.transcript.isNotEmpty,
        controller: _scroll,
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: EdgeInsets.fromLTRB(
          AppLayout.horizontalPadding(context),
          16,
          AppLayout.horizontalPadding(context),
          20,
        ),
        itemCount: children.length,
        separatorBuilder: (_, index) =>
            const SizedBox(height: AppLayout.spaceMd),
        itemBuilder: (_, index) =>
            children[controller.transcript.isNotEmpty
                ? children.length - 1 - index
                : index],
      ),
    );
  }

  Widget _buildComposer(AssistantController controller) =>
      _composer._buildComposer(controller);
  void _scrollToBottom({bool animate = true}) {
    if (_scrollScheduled) return;
    _scrollScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollScheduled = false;
      if (!mounted || !_scroll.hasClients || !_followOutput) return;
      if (!animate || MediaQuery.disableAnimationsOf(context)) {
        _scroll.jumpTo(_scroll.position.minScrollExtent);
      } else {
        _scroll.animateTo(
          _scroll.position.minScrollExtent,
          duration: AppMotion.quick,
          curve: AppMotion.curve,
        );
      }
    });
  }

  void _usePrompt(String prompt) {
    _input.text = prompt;
    _inputFocus.requestFocus();
  }

  Future<void> _newSession() async {
    try {
      await widget.controller.startNewSession(clearReference: false);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              userErrorMessage(error, fallback: '操作未完成，请重试；仍有问题时检查模型设置'),
            ),
          ),
        );
      }
    }
  }

  Future<void> _openHistory() async {
    if (_recordingVoice) {
      _recordingVoice = false;
      await _voice?.cancel();
    }
    if (!mounted) return;
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => AssistantHistoryPage(controller: widget.controller),
      ),
    );
  }

  Future<void> _openSettings() async {
    if (_recordingVoice) {
      _recordingVoice = false;
      await _voice?.cancel();
    }
    if (!mounted) return;
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => AssistantSettingsPage(controller: widget.controller),
      ),
    );
  }

  void _openReference(String type, String id) {
    if (type == 'goal') {
      unawaited(openAssistantGoal(context, id));
    } else {
      unawaited(openAssistantMission(context, id));
    }
  }
}

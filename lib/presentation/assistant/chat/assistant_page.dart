import '../../../application/errors/user_error_message.dart';
import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:agent_core/agent_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../application/assistant/assistant_controller.dart';
import '../../../application/assistant/assistant_attachment.dart';
import '../../../application/assistant/assistant_image.dart';
import '../../attachments/photo_capture_panel.dart';
import '../../widgets/app_confirm_dialog.dart';
import '../../../application/assistant/assistant_speech.dart';
import '../../../data/assistant/assistant_attachment_picker.dart';
import '../../../core/theme/app_layout.dart';
import '../../../core/theme/colors.dart';
import '../../widgets/app_page_header.dart';
import '../../widgets/app_illustration.dart';
import '../../widgets/app_section_card.dart';
import '../../widgets/adaptive_columns.dart';
import '../../widgets/app_expansion.dart';
import '../../widgets/app_selection_option.dart';
import '../../widgets/app_top_bar.dart';
import '../../missions/shared/mission_phase_display.dart';
import '../history/assistant_history_page.dart';
import '../shared/assistant_markdown.dart';
import '../entry/assistant_scope.dart';
import '../shared/assistant_reasoning_display.dart';
import '../shared/assistant_turn_content.dart';
import '../shared/assistant_thinking.dart';
import '../settings/assistant_settings_page.dart';
import '../shared/assistant_voice_status.dart';
import '../../../core/theme/app_motion.dart';
part 'assistant_conversation_banners.dart';
part 'assistant_welcome.dart';
part 'assistant_message_bubble.dart';
part 'assistant_composer.dart';
part 'assistant_context_sheet.dart';
part 'assistant_turn.dart';

class AssistantPage extends StatefulWidget {
  const AssistantPage({
    super.key,
    required this.controller,
    this.showBack = false,
    this.initialText,
    this.initialOperationCallId,
  });
  final AssistantController controller;
  final bool showBack;
  final String? initialText;
  final String? initialOperationCallId;
  @override
  State<AssistantPage> createState() => _AssistantPageState();
}

class _AssistantPageState extends State<AssistantPage> {
  late final _composer = _AssistantComposer(this);
  void _update(VoidCallback update) {
    setState(update);
    widget.controller.saveAttachments(_draftSession, _attachments);
  }

  final _input = TextEditingController();
  final _inputFocus = FocusNode();
  final _scroll = ScrollController(keepScrollOffset: false);
  String? _draftSession;
  bool _followOutput = true;
  bool _scrollScheduled = false;
  final _readingPositions = <String?, ({double offset, bool follow})>{};

  void _pauseFollowing() {
    if (_followOutput && mounted) setState(() => _followOutput = false);
  }

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
      if (_scroll.hasClients) {
        _readingPositions[_draftSession] = (
          offset: _scroll.offset,
          follow: _followOutput,
        );
      }
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
      final reading = _readingPositions[id];
      _followOutput = reading?.follow ?? true;
      if (!_followOutput && reading != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted ||
              widget.controller.draftKey != id ||
              !_scroll.hasClients) {
            return;
          }
          _scroll.jumpTo(
            reading.offset.clamp(
              _scroll.position.minScrollExtent,
              _scroll.position.maxScrollExtent,
            ),
          );
        });
      }
    }
    final files = widget.controller.attachmentsFor(id);
    if (!listEquals(_attachments, files)) {
      setState(
        () => _attachments
          ..clear()
          ..addAll(files),
      );
    }
    if (_followOutput) _scrollToBottom(animate: false);
  }

  /// 流式增量不再触发整页重建，跟随输出需要在这里单独滚动。
  void _liveActivityChanged() {
    if (!mounted) return;
    if (_followOutput) _scrollToBottom(animate: false);
  }

  @override
  void initState() {
    super.initState();
    _draftSession = widget.controller.draftKey;
    widget.controller.addListener(_controllerChanged);
    widget.controller.liveActivity.addListener(_liveActivityChanged);
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
      // 进入文字聊天不加载语音模型；首次录音时由语音服务按需准备。
    }
  }

  void _voiceChanged() {
    if (!mounted) return;
    final text = _voice!.text;
    if (_recordingVoice && text.isNotEmpty) {
      _input.value = TextEditingValue(
        text: '$_voicePrefix$text',
        selection: TextSelection.collapsed(
          offset: _voicePrefix.length + text.length,
        ),
      );
      widget.controller.saveDraft(_draftSession, _input.text);
    }
    setState(() {});
  }

  @override
  void dispose() {
    widget.controller.removeListener(_controllerChanged);
    widget.controller.liveActivity.removeListener(_liveActivityChanged);
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
                  if (controller.unavailableReference != null)
                    Padding(
                      padding: const EdgeInsets.all(AppLayout.spaceMd),
                      child: Text(
                        controller.unavailableReference!,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
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
                  if (controller.needsOutcomeResolution)
                    Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: AppLayout.horizontalPadding(context),
                      ),
                      child: _OutcomePendingBanner(
                        onNewSession: controller.isBusy ? null : _newSession,
                      ),
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
  Widget _buildSidebar(AssistantController controller) {
    final conversations = controller.conversations;
    return Padding(
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
                  icon: const Icon(
                    Icons.search_rounded,
                    size: AppLayout.iconMd,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppLayout.spaceLg),
            FilledButton.tonalIcon(
              key: const Key('assistant-sidebar-new'),
              onPressed: controller.isBusy ? null : _newSession,
              icon: const Icon(Icons.add_rounded),
              label: const Text('开启新会话'),
            ),
            const SizedBox(height: AppLayout.spaceXl),
            Expanded(
              child: conversations.isEmpty
                  ? const Text('对话会自动保存在这台设备上。')
                  : ListView.builder(
                      itemCount: conversations.length,
                      itemBuilder: (context, index) {
                        final item = conversations[index];
                        return Padding(
                          padding: const EdgeInsets.only(
                            bottom: AppLayout.spaceSm,
                          ),
                          child: ListTile(
                            key: ValueKey('assistant-sidebar-${item.id}'),
                            selected: item.id == controller.currentSessionId,
                            selectedTileColor: AppColors.primarySoft,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(
                                AppLayout.radiusMd,
                              ),
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
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

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
    final transcript = controller.transcript;
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
    if (transcript.isEmpty && controller.localSchedule == null) {
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
    var messages = <AssistantMessage>[];
    var turnKey = '${controller.currentSessionId}:initial';
    void appendTurn({bool running = false}) {
      final active =
          running && controller.activity.turnUserMessageId == turnKey;
      if (messages.isEmpty &&
          !active &&
          !controller.interruptedAttempts.any(
            (attempt) => attempt.userMessageId == turnKey,
          )) {
        return;
      }
      if (!active &&
          messages.any(
            (message) => message.content.whereType<TextBlock>().any(
              (block) => block.text.length >= 4000,
            ),
          )) {
        children.addAll(
          AssistantTurnContent(
            identity: turnKey,
            messages: List.of(messages),
            attempts: controller.interruptedAttempts
                .where((item) => item.userMessageId == turnKey)
                .toList(),
            operations: operations,
            controller: controller,
            focusOperationCallId: widget.initialOperationCallId,
            onOpenReference: _openReference,
            replyBuilder:
                (message, block, key, streaming, slice, first, last) =>
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
          ).buildEntries(context, splitReplies: true),
        );
        messages = [];
        return;
      }
      children.add(
        _AssistantTurn(
          key: ValueKey('turn-$turnKey'),
          messages: List.of(messages),
          userMessageId: turnKey,
          operations: operations,
          controller: controller,
          onOpenReference: _openReference,
          running: active,
          focusOperationCallId: widget.initialOperationCallId,
        ),
      );
      messages = [];
    }

    for (final message in transcript) {
      if (message is UserMessage) {
        appendTurn();
        children.add(
          _MessageBubble(
            key: ValueKey(message.id),
            message: message,
            isUser: true,
          ),
        );
        turnKey = message.id;
      } else if (message is AssistantMessage) {
        messages.add(message);
      } else if (message is ContextSummaryMessage) {
        appendTurn();
        children.add(
          Text('较早对话已压缩，原始记录仍保留', style: Theme.of(context).textTheme.bodySmall),
        );
        turnKey = message.id;
      }
    }
    appendTurn(running: controller.isRunning);
    return NotificationListener<AssistantExpansionNotification>(
      onNotification: (_) {
        _pauseFollowing();
        return false;
      },
      child: NotificationListener<UserScrollNotification>(
        onNotification: (notification) {
          if (notification.depth == 0 && _scroll.hasClients) {
            _followOutput =
                _scroll.position.pixels - _scroll.position.minScrollExtent < 24;
          }
          return false;
        },
        child: SelectionArea(
          contextMenuBuilder: (context, state) =>
              AdaptiveTextSelectionToolbar.buttonItems(
                anchors: state.contextMenuAnchors,
                buttonItems: state.contextMenuButtonItems
                    .where((item) => item.type == ContextMenuButtonType.copy)
                    .toList(),
              ),
          child: ListView.separated(
            key: const Key('assistant-conversation-list'),
            reverse: transcript.isNotEmpty,
            controller: _scroll,
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: EdgeInsets.fromLTRB(
              AppLayout.horizontalPadding(context),
              16,
              AppLayout.horizontalPadding(context),
              20,
            ),
            itemCount: children.length,
            separatorBuilder: (_, index) {
              final current =
                  children[transcript.isNotEmpty
                      ? children.length - 1 - index
                      : index + 1];
              if (current is _MessageBubble && !current.firstSlice) {
                return const SizedBox.shrink();
              }
              return const SizedBox(height: AppLayout.spaceMd);
            },
            itemBuilder: (_, index) =>
                children[transcript.isNotEmpty
                    ? children.length - 1 - index
                    : index],
          ),
        ),
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
      final position = _scroll.position;
      final target = position.minScrollExtent;
      if ((position.pixels - target).abs() < 0.5) return;
      if (!animate || MediaQuery.disableAnimationsOf(context)) {
        position.jumpTo(target);
      } else {
        _scroll.animateTo(
          target,
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

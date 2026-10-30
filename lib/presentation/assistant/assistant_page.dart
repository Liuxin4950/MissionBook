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
import 'assistant_history_page.dart';
import 'assistant_markdown.dart';
import 'assistant_operation_card.dart';
import 'assistant_scope.dart';
import 'assistant_settings_page.dart';
import 'assistant_voice_status.dart';
import '../../core/theme/app_motion.dart';

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
  final _input = TextEditingController();
  final _inputFocus = FocusNode();
  final _scroll = ScrollController(keepScrollOffset: false);
  String? _draftSession;
  bool _followOutput = true;
  bool _scrollScheduled = false;
  static const _contentWidth = AppLayout.dashboardMaxWidth;
  final _attachments = <AssistantAttachment>[];
  bool _picking = false;
  AssistantVoiceController? _voice;
  bool _recordingVoice = false;
  String _voicePrefix = '';

  void _controllerChanged() {
    final id = widget.controller.currentSessionId;
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
    _draftSession = widget.controller.currentSessionId;
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
                        SizedBox(width: 272, child: _buildSidebar(controller)),
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
    padding: const EdgeInsets.fromLTRB(24, 16, 0, 24),
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

  Widget _buildComposer(
    AssistantController controller,
  ) => ValueListenableBuilder<TextEditingValue>(
    valueListenable: _input,
    builder: (context, value, _) {
      final colors = Theme.of(context).colorScheme;
      final canSend =
          (value.text.trim().isNotEmpty || _attachments.isNotEmpty) &&
          !controller.isBusy &&
          !controller.compacting &&
          !controller.initializing &&
          !_picking &&
          !(_voice?.busy ?? false) &&
          !(_voice?.listening ?? false);
      final canStop = controller.isRunning;
      final action = canStop
          ? controller.stop
          : canSend
          ? () => unawaited(_send())
          : null;
      return Padding(
        key: const Key('assistant-composer'),
        padding: EdgeInsets.fromLTRB(
          AppLayout.horizontalPadding(context),
          8,
          AppLayout.horizontalPadding(context),
          12,
        ),
        child: Material(
          color: colors.surfaceContainerLow,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppLayout.radiusXxl),
            side: const BorderSide(color: AppColors.hairline),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppLayout.spaceMd,
              AppLayout.spaceXs,
              AppLayout.spaceMd,
              AppLayout.spaceSm,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_attachments.isNotEmpty)
                  SizedBox(
                    height: 72,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: _attachments.length,
                      separatorBuilder: (_, index) =>
                          const SizedBox(width: AppLayout.spaceSm),
                      itemBuilder: (context, index) {
                        final file = _attachments[index];
                        return InputChip(
                          avatar: file.isImage
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(
                                    AppLayout.radiusSm,
                                  ),
                                  child: Image.memory(
                                    file.bytes,
                                    width: 32,
                                    height: 32,
                                    cacheWidth: 64,
                                    fit: BoxFit.cover,
                                  ),
                                )
                              : const Icon(
                                  Icons.description_outlined,
                                  size: AppLayout.iconMd,
                                ),
                          label: SizedBox(
                            width: 108,
                            child: Text(
                              file.name,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          onPressed: () => _previewAttachment(file),
                          onDeleted: controller.isBusy
                              ? null
                              : () => setState(
                                  () => _attachments.removeAt(index),
                                ),
                          deleteButtonTooltipMessage: '移除 ${file.name}',
                        );
                      },
                    ),
                  ),
                if (_recordingVoice && _voice != null) ...[
                  const SizedBox(height: AppLayout.spaceSm),
                  AssistantVoiceStatus(
                    voice: _voice!,
                    onCancel: () async {
                      _recordingVoice = false;
                      await _voice!.cancel();
                      if (mounted) setState(() {});
                    },
                  ),
                ],
                TextField(
                  key: const Key('assistant-input'),
                  controller: _input,
                  autofocus:
                      widget.showBack && MediaQuery.sizeOf(context).width < 600,
                  focusNode: _inputFocus,
                  readOnly:
                      (_voice?.listening ?? false) || (_voice?.busy ?? false),
                  onChanged: (_) {
                    _recordingVoice = false;
                  },
                  minLines: 1,
                  maxLines:
                      MediaQuery.sizeOf(context).height -
                              MediaQuery.viewInsetsOf(context).bottom <
                          480
                      ? 1
                      : MediaQuery.textScalerOf(context).scale(1) >= 1.5
                      ? 2
                      : 5,
                  textInputAction: TextInputAction.send,
                  onSubmitted: canSend ? (_) => _send() : null,
                  decoration: InputDecoration(
                    hintText: '描述你想讨论或调整的内容…',
                    filled: false,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: AppLayout.spaceXs,
                      vertical: AppLayout.spaceMd,
                    ),
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                  ),
                ),
                if (_recordingVoice && _voice?.error != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppLayout.spaceSm),
                    child: Text(
                      _voice!.error!,
                      style: const TextStyle(color: AppColors.error),
                    ),
                  ),
                Row(
                  children: [
                    PopupMenuButton<String>(
                      key: const Key('assistant-add-attachment'),
                      tooltip: '附件与快捷指令',
                      constraints: const BoxConstraints(
                        minWidth: 188,
                        maxWidth: 240,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppLayout.radiusLg),
                      ),
                      enabled:
                          !controller.isBusy &&
                          !controller.compacting &&
                          !_picking,
                      onSelected: _composerAction,
                      icon: _picking
                          ? const SizedBox.square(
                              dimension: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.add_rounded),
                      itemBuilder: (_) => [
                        _composerMenuItem(
                          'image',
                          Icons.image_outlined,
                          '添加图片',
                          enabled:
                              _attachments.length <
                              AssistantAttachment.maxCount,
                        ),
                        _composerMenuItem(
                          'file',
                          Icons.attach_file,
                          '添加文件',
                          enabled:
                              _attachments.length <
                              AssistantAttachment.maxCount,
                        ),
                        const PopupMenuDivider(height: 8),
                        _composerMenuItem(
                          'today',
                          Icons.today_outlined,
                          '查看今天安排',
                        ),
                        _composerMenuItem(
                          'plan',
                          Icons.auto_awesome_outlined,
                          '帮我规划今天',
                        ),
                        _composerMenuItem(
                          'compact',
                          Icons.compress_rounded,
                          '压缩会话',
                          enabled:
                              controller.hasCredential &&
                              controller.transcript.isNotEmpty,
                        ),
                      ],
                    ),
                    if (_voice != null)
                      IconButton(
                        key: const Key('assistant-composer-voice'),
                        tooltip: _voice!.listening ? '结束录音' : '语音输入',
                        onPressed: controller.isBusy || _voice!.busy
                            ? null
                            : _toggleVoice,
                        icon: Icon(
                          _voice!.listening
                              ? Icons.stop_circle_outlined
                              : Icons.mic_none_rounded,
                          color: _voice!.listening ? colors.primary : null,
                        ),
                      ),
                    Expanded(
                      child: Text(
                        _attachments.isEmpty
                            ? ''
                            : '${_attachments.length}/${AssistantAttachment.maxCount} 个附件',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                    _contextIndicator(controller),
                    IconButton.filled(
                      key: const Key('assistant-send'),
                      tooltip: canStop ? '停止本轮' : '发送',
                      onPressed: action,
                      style: IconButton.styleFrom(
                        minimumSize: const Size(48, 48),
                        foregroundColor: colors.onPrimary,
                        backgroundColor: colors.primary,
                        disabledForegroundColor: colors.onSurfaceVariant,
                        disabledBackgroundColor: colors.surfaceContainerHighest,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                            AppLayout.radiusLg,
                          ),
                        ),
                      ),
                      icon: Icon(
                        canStop
                            ? Icons.stop_rounded
                            : Icons.arrow_upward_rounded,
                        color: action == null
                            ? colors.onSurfaceVariant
                            : colors.onPrimary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
    },
  );

  PopupMenuItem<String> _composerMenuItem(
    String value,
    IconData icon,
    String label, {
    bool enabled = true,
  }) => PopupMenuItem(
    value: value,
    enabled: enabled,
    height: 44,
    child: Row(
      children: [
        Icon(icon, size: AppLayout.iconMd),
        const SizedBox(width: AppLayout.spaceMd),
        Expanded(
          child: Text(label, style: Theme.of(context).textTheme.bodyMedium),
        ),
      ],
    ),
  );

  Future<void> _composerAction(String action) async {
    switch (action) {
      case 'image':
        await _pickAttachment(true);
      case 'file':
        await _pickAttachment(false);
      case 'today':
        await widget.controller.loadLocalSchedule();
      case 'plan':
        _usePrompt('帮我规划今天的任务，先查看我的安排。');
      case 'compact':
        try {
          final result = await widget.controller.compactConversation();
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                result == null ? '当前会话较短，暂不需要压缩' : '已压缩上下文，聊天记录已保留',
              ),
            ),
          );
        } catch (error) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  error is StateError ? error.message : '压缩未完成，请重试；原聊天记录已保留',
                ),
              ),
            );
          }
        }
    }
  }

  Widget _contextIndicator(AssistantController controller) {
    final used = controller.estimatedContextTokens;
    final limit = controller.contextWindowTokens;
    final ratio = (used / limit).clamp(0.0, 1.0);
    final label =
        '上下文约 ${(ratio * 100).toStringAsFixed(1)}%\n$used / $limit tokens（估算）';
    return Tooltip(
      message: label,
      triggerMode: TooltipTriggerMode.tap,
      child: Semantics(
        label: label,
        child: SizedBox.square(
          key: const Key('assistant-context-usage'),
          dimension: 44,
          child: Center(
            child: SizedBox.square(
              dimension: 20,
              child: CircularProgressIndicator(
                value: ratio,
                strokeWidth: 3,
                backgroundColor: AppColors.hairline,
                color: ratio >= .9
                    ? AppColors.error
                    : ratio >= .75
                    ? AppColors.warning
                    : AppColors.primary,
                semanticsLabel: '上下文占用',
                semanticsValue: '${(ratio * 100).round()}%',
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _send() async {
    final text = _input.text.trim();
    if ((text.isEmpty && _attachments.isEmpty) || widget.controller.isBusy) {
      return;
    }
    if (!widget.controller.hasCredential) {
      await _openSettings();
      return;
    }
    final files = List<AssistantAttachment>.of(_attachments);
    final message = UserMessage.withContent(
      content: [
        if (text.isNotEmpty) TextBlock(text: text),
        ...files.map((file) => file.block),
      ],
    );
    _input.clear();
    setState(() => _attachments.clear());
    _recordingVoice = false;
    widget.controller.draft = '';
    widget.controller.saveAttachments(_draftSession, []);
    _followOutput = true;
    await widget.controller.sendMessage(message);
    if (!mounted) return;
    if (!widget.controller.transcript.any((item) => item.id == message.id) &&
        _input.text.isEmpty &&
        _attachments.isEmpty) {
      _input.text = text;
      setState(() => _attachments.addAll(files));
    }
    if (_followOutput) _scrollToBottom();
  }

  Future<void> _toggleVoice() async {
    final voice = _voice!;
    if (voice.listening) {
      await voice.stop();
      return;
    }
    _inputFocus.unfocus();
    _voicePrefix = _input.text.isEmpty ? '' : '${_input.text.trimRight()}\n';
    _recordingVoice = true;
    await voice.start();
  }

  Future<void> _pickAttachment(bool image) async {
    if (image && !widget.controller.supportsImages) {
      _showNotice('当前模型未开启图片能力，请先在助手设置中切换支持图片的模型。');
      return;
    }
    final sessionId = widget.controller.currentSessionId;
    setState(() => _picking = true);
    try {
      final file = await pickAssistantAttachment(image: image);
      if (file == null ||
          !mounted ||
          sessionId != widget.controller.currentSessionId) {
        return;
      }
      if (_attachments.fold<int>(
            file.bytes.length,
            (total, file) => total + file.bytes.length,
          ) >
          AssistantAttachment.maxTotalBytes) {
        throw const FormatException('本条消息附件合计不能超过 8 MiB');
      }
      if (_attachments.fold<int>(
            file.isImage ? 0 : (file.block as TextBlock).text.length,
            (total, file) =>
                total +
                (file.isImage ? 0 : (file.block as TextBlock).text.length),
          ) >
          AssistantAttachment.maxTextCharacters) {
        throw const FormatException('本条消息文本附件合计不能超过 32000 字符');
      }
      setState(() => _attachments.add(file));
    } catch (error) {
      if (mounted) _showNotice('$error');
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  void _showNotice(String text) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

  Future<void> _previewAttachment(AssistantAttachment file) => showDialog<void>(
    context: context,
    builder: (context) => Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720, maxHeight: 640),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text(file.name),
              trailing: IconButton(
                tooltip: '关闭预览',
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close),
              ),
            ),
            Flexible(
              child: file.isImage
                  ? InteractiveViewer(
                      child: Image.memory(file.bytes, fit: BoxFit.contain),
                    )
                  : SingleChildScrollView(
                      padding: const EdgeInsets.all(AppLayout.spaceXl),
                      child: SelectableText(
                        AssistantAttachment.textFile(file.block)!.text,
                      ),
                    ),
            ),
          ],
        ),
      ),
    ),
  );

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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$error')));
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

class _ReferenceBanner extends StatelessWidget {
  const _ReferenceBanner({required this.controller});
  final AssistantController controller;

  @override
  Widget build(BuildContext context) {
    final reference = controller.reference!;
    return Container(
      width: double.infinity,
      color: AppColors.primarySoft,
      padding: const EdgeInsets.symmetric(
        horizontal: AppLayout.spaceLg,
        vertical: AppLayout.spaceSm,
      ),
      child: Text(
        '当前${reference.label} · ${reference.title}${reference.path == null ? '' : '\n${reference.path}'}',
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(
          context,
        ).textTheme.bodySmall?.copyWith(color: AppColors.primary),
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
    borderRadius: BorderRadius.circular(AppLayout.radiusLg),
    child: Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppLayout.spaceLg,
        vertical: AppLayout.spaceSm,
      ),
      child: Row(
        children: [
          Expanded(
            child: Semantics(
              liveRegion: true,
              child: Text(
                controller.errorMessage!,
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: AppColors.error),
              ),
            ),
          ),
          if (!controller.hasCredential)
            TextButton(onPressed: onSettings, child: const Text('去设置')),
          if (controller.canContinueInterrupted)
            TextButton(
              onPressed: controller.continueInterrupted,
              child: const Text('继续本轮'),
            ),
          IconButton(
            tooltip: '关闭错误提示',
            onPressed: controller.clearError,
            icon: const Icon(Icons.close, size: AppLayout.iconSm),
          ),
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
    borderRadius: BorderRadius.circular(AppLayout.radiusLg),
    child: Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppLayout.spaceLg,
        vertical: AppLayout.spaceSm,
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              '配置模型后可创建、修改和安排任务；本地快捷查询仍可使用',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
          TextButton(onPressed: onPressed, child: const Text('配置模型')),
        ],
      ),
    ),
  );
}

class _Welcome extends StatelessWidget {
  const _Welcome({
    required this.persona,
    required this.onLocalSchedule,
    required this.onPrompt,
  });
  final AssistantPersona persona;
  final Future<void> Function() onLocalSchedule;
  final ValueChanged<String> onPrompt;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final prompts = [
      (
        const Key('assistant-local-today'),
        Icons.today_outlined,
        '查看今天安排',
        '读取这台设备上的真实日程',
        () {
          onLocalSchedule();
        },
      ),
      (
        null,
        Icons.event_available_outlined,
        '帮我安排今天',
        '结合已有安排，规划下一步',
        () => onPrompt(
          '先看看今天已有的安排，结合我的目标，帮我提出一份今天的任务计划。可用时间不明确时先问我，用计划卡集中展示新建或改期的任务。',
        ),
      ),
      (
        null,
        Icons.add_task,
        '创建一个任务',
        '把一件想做的事落到具体行动',
        () => onPrompt('创建一个任务：'),
      ),
      (
        const Key('assistant-outline-prompt'),
        Icons.account_tree_outlined,
        '拆解学习目标',
        '从方向到阶段，再到任务',
        () => onPrompt('我想创建一个学习目标，并拆成分层大纲：\n目标：\n目前基础：\n希望达到的结果：'),
      ),
      (
        const Key('assistant-retry-prompt'),
        Icons.replay_outlined,
        '复盘并重新安排',
        '回看真实记录，保留原结果',
        () => onPrompt(
          '请先查找我想复盘的已结束或已取消任务，读取真实执行和失败记录，帮我分析改进点；确认任务和新日期后，创建关联的新尝试，保留原记录。\n任务名称：\n新安排：',
        ),
      ),
      (
        const Key('assistant-adjust-prompt'),
        Icons.edit_calendar_outlined,
        '调整一组安排',
        '集中检查与修改多个任务',
        () => onPrompt(
          '请先核对相关任务与日期安排，帮我用一份可编辑计划卡集中调整，保留未调整任务。\n需要调整的任务：\n可用日期和时间：',
        ),
      ),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppSectionCard(
          paperBackground: true,
          child: LayoutBuilder(
            builder: (context, box) {
              final wide =
                  box.maxWidth >=
                  620 * MediaQuery.textScalerOf(context).scale(1);
              final picture = AppIllustration(
                asset: 'assets/illustrations/assistant-notebook.png',
                width: wide ? 160 : 120,
                height: wide ? 136 : 96,
              );
              final words = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '把想法变成可检查的行动',
                    style: wide ? text.headlineSmall : text.titleLarge,
                  ),
                  const SizedBox(height: AppLayout.spaceMd),
                  Text(
                    '${persona.name} · ${persona.role.label} · ${persona.replyStyle.label}',
                    style: text.bodySmall,
                  ),
                  const SizedBox(height: AppLayout.spaceSm),
                  Text('告诉我想做的事，一起拆解目标、安排任务、回看行动。', style: text.bodyMedium),
                ],
              );
              return wide
                  ? Row(
                      children: [
                        Expanded(child: words),
                        const SizedBox(width: 24),
                        picture,
                      ],
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [picture, const SizedBox(height: 16), words],
                    );
            },
          ),
        ),
        const SizedBox(height: AppLayout.spaceXxl),
        Text('从这里开始', style: text.titleMedium),
        const SizedBox(height: AppLayout.spaceMd),
        AdaptiveColumns(
          minColumnWidth: 220,
          maxColumns: 3,
          spacing: AppLayout.spaceMd,
          children: [
            for (final item in prompts)
              Material(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(AppLayout.radiusXl),
                child: InkWell(
                  key: item.$1,
                  onTap: item.$5,
                  borderRadius: BorderRadius.circular(AppLayout.radiusXl),
                  child: Padding(
                    padding: const EdgeInsets.all(AppLayout.spaceLg),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          item.$2,
                          color: AppColors.primary,
                          size: AppLayout.iconMd,
                        ),
                        const SizedBox(width: AppLayout.spaceMd),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(item.$3, style: text.titleSmall),
                              const SizedBox(height: AppLayout.spaceXs),
                              Text(item.$4, style: text.bodySmall),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _LocalScheduleCard extends StatelessWidget {
  const _LocalScheduleCard({required this.controller, required this.onOpen});
  final AssistantController controller;
  final void Function(String, String) onOpen;

  @override
  Widget build(BuildContext context) {
    final missions = controller.localSchedule!;
    return Padding(
      padding: EdgeInsets.zero,
      child: AppSectionCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${controller.localScheduleDate} · 本地快照',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                IconButton(
                  tooltip: '收起本地日程',
                  onPressed: controller.clearLocalSchedule,
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            if (missions.isEmpty)
              Text('这一天还没有任务', style: Theme.of(context).textTheme.bodyMedium)
            else
              for (final item in missions)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    item.mission.title,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  subtitle: Text(
                    '${item.schedule.plannedDurationMinutes} 分钟 · ${item.phase.name}',
                  ),
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
  const _MessageBubble({
    super.key,
    required this.message,
    required this.isUser,
  });
  final AgentMessage message;
  final bool isUser;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final text = message.content
        .whereType<TextBlock>()
        .where((block) => AssistantAttachment.textFile(block) == null)
        .map((block) => block.text)
        .join('\n');
    return Padding(
      padding: EdgeInsets.only(top: isUser ? AppLayout.spaceSm : 0),
      child: LayoutBuilder(
        builder: (context, constraints) => Align(
          alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: isUser
                  ? (constraints.maxWidth * .88).clamp(0, 620)
                  : constraints.maxWidth.clamp(0, 860),
            ),
            child: Material(
              color: isUser
                  ? colors.primaryContainer
                  : colors.surfaceContainerLow,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppLayout.radiusLg),
                side: isUser
                    ? BorderSide.none
                    : const BorderSide(color: AppColors.hairline),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppLayout.spaceLg,
                  vertical: AppLayout.spaceMd,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (text.isNotEmpty)
                      if (!isUser)
                        AssistantMarkdown(text: text)
                      else
                        SelectableText(
                          text,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                color: colors.onPrimaryContainer,
                                height: 1.5,
                              ),
                        ),
                    for (final block in message.content)
                      if (AssistantAttachment.textFile(block) case final file?)
                        AppExpansionTile(
                          insetHeader: false,
                          headerPadding: const EdgeInsets.symmetric(
                            vertical: AppLayout.spaceXs,
                          ),
                          childrenPadding: EdgeInsets.zero,
                          iconColor: isUser
                              ? colors.onPrimaryContainer
                              : colors.onSurface,
                          title: Text(
                            file.name,
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(
                                  color: isUser
                                      ? colors.onPrimaryContainer
                                      : colors.onSurface,
                                ),
                          ),
                          leading: Icon(
                            Icons.description_outlined,
                            color: isUser
                                ? colors.onPrimaryContainer
                                : colors.primary,
                          ),
                          children: [
                            ConstrainedBox(
                              constraints: const BoxConstraints(maxHeight: 240),
                              child: SingleChildScrollView(
                                child: SelectableText(
                                  file.text,
                                  style: TextStyle(
                                    color: isUser
                                        ? colors.onPrimaryContainer
                                        : colors.onSurface,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                    for (final block in message.content.whereType<ImageBlock>())
                      Padding(
                        padding: const EdgeInsets.only(top: AppLayout.spaceSm),
                        child: _MessageImage(block: block),
                      ),
                  ],
                ),
              ),
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
        borderRadius: BorderRadius.circular(AppLayout.radiusLg),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppLayout.spaceMd,
            vertical: AppLayout.spaceMd,
          ),
          child: AssistantMarkdown(text: text),
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
      return ClipRRect(
        borderRadius: BorderRadius.circular(AppLayout.radiusMd),
        child: InkWell(
          onTap: () => showDialog<void>(
            context: context,
            builder: (context) => Dialog(
              child: Stack(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(AppLayout.spaceLg),
                    child: InteractiveViewer(
                      child: Image.memory(bytes, fit: BoxFit.contain),
                    ),
                  ),
                  Positioned(
                    right: 4,
                    top: 4,
                    child: IconButton(
                      tooltip: '关闭图片',
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                    ),
                  ),
                ],
              ),
            ),
          ),
          child: Image.memory(
            bytes,
            width: 240,
            cacheWidth: 480,
            fit: BoxFit.contain,
            errorBuilder: (_, error, stack) => const Text('图片无法解码'),
          ),
        ),
      );
    }
    if (block.url.startsWith('http')) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(AppLayout.radiusMd),
        child: Image.network(block.url, width: 240, fit: BoxFit.contain),
      );
    }
    return Text(
      block.label ?? '云端图片引用',
      style: Theme.of(context).textTheme.bodySmall,
    );
  }
}

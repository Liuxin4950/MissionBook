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
import '../widgets/app_top_bar.dart';
import 'assistant_history_page.dart';
import 'assistant_markdown.dart';
import 'assistant_operation_card.dart';
import 'assistant_scope.dart';
import 'assistant_settings_page.dart';

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
  final _scroll = ScrollController();
  String? _draftSession;
  bool _followOutput = true;
  bool _scrollScheduled = false;
  static const _contentWidth = 960.0;
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
            preferredSize: const Size.fromHeight(64),
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
      onPressed: widget.controller.isBusy ? null : _newSession,
      icon: const Icon(Icons.add_comment_outlined),
    ),
    IconButton(
      key: const Key('assistant-history'),
      tooltip: '会话历史',
      onPressed: widget.controller.isBusy ? null : _openHistory,
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
            padding: const EdgeInsets.only(bottom: 12),
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
          padding: const EdgeInsets.only(bottom: 16),
          child: Row(
            children: [
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              const SizedBox(width: 8),
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
          _followOutput = _scroll.position.extentAfter < 120;
        }
        return false;
      },
      child: ListView.separated(
        key: const Key('assistant-conversation-list'),
        controller: _scroll,
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: EdgeInsets.fromLTRB(
          AppLayout.horizontalPadding(context),
          16,
          AppLayout.horizontalPadding(context),
          20,
        ),
        itemCount: children.length,
        separatorBuilder: (_, index) => const SizedBox(height: 12),
        itemBuilder: (_, index) => children[index],
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
          color: colors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: const BorderSide(color: AppColors.hairline),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
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
                      separatorBuilder: (_, index) => const SizedBox(width: 8),
                      itemBuilder: (context, index) {
                        final file = _attachments[index];
                        return InputChip(
                          avatar: file.isImage
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(6),
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
                                  size: 20,
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
                      ? 2
                      : 5,
                  textInputAction: TextInputAction.send,
                  onSubmitted: canSend ? (_) => _send() : null,
                  decoration: InputDecoration(
                    hintText: '描述你想讨论或调整的内容…',
                    filled: false,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 12,
                    ),
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                  ),
                ),
                if (_recordingVoice && _voice?.error != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      _voice!.error!,
                      style: const TextStyle(color: AppColors.error),
                    ),
                  ),
                Row(
                  children: [
                    PopupMenuButton<bool>(
                      key: const Key('assistant-add-attachment'),
                      tooltip: '添加图片或文件',
                      enabled:
                          !controller.isBusy &&
                          !_picking &&
                          _attachments.length < AssistantAttachment.maxCount,
                      onSelected: _pickAttachment,
                      icon: _picking
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.add_rounded),
                      itemBuilder: (_) => [
                        const PopupMenuItem(
                          value: true,
                          child: ListTile(
                            leading: Icon(Icons.image_outlined),
                            title: Text('添加图片'),
                            subtitle: Text('PNG、JPEG、WebP、GIF · 每张 4 MiB'),
                          ),
                        ),
                        const PopupMenuItem(
                          value: false,
                          child: ListTile(
                            leading: Icon(Icons.description_outlined),
                            title: Text('添加文本文件'),
                            subtitle: Text('TXT、Markdown、CSV、JSON 等'),
                          ),
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
                        _voice?.starting == true
                            ? '正在准备语音…'
                            : _voice?.stopping == true
                            ? '正在转写…'
                            : _voice?.listening == true
                            ? '正在听，点击结束'
                            : _attachments.isEmpty
                            ? ''
                            : '${_attachments.length}/${AssistantAttachment.maxCount} 个附件',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                    IconButton.filled(
                      key: const Key('assistant-send'),
                      tooltip: canStop ? '停止本轮' : '发送',
                      onPressed: action,
                      style: IconButton.styleFrom(
                        fixedSize: const Size(40, 40),
                        foregroundColor: colors.onPrimary,
                        backgroundColor: colors.primary,
                        disabledForegroundColor: colors.onSurfaceVariant,
                        disabledBackgroundColor: colors.surfaceContainerHighest,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
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
                      padding: const EdgeInsets.all(20),
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
        _scroll.jumpTo(_scroll.position.maxScrollExtent);
      } else {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
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
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
    borderRadius: BorderRadius.circular(16),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
          IconButton(
            tooltip: '关闭错误提示',
            onPressed: controller.clearError,
            icon: const Icon(Icons.close, size: 18),
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
    borderRadius: BorderRadius.circular(16),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
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
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 24),
    child: Column(
      children: [
        const AppIllustration(
          asset: 'assets/illustrations/assistant-notebook.png',
          width: 160,
          height: 136,
        ),
        const SizedBox(height: 16),
        Text(
          '把想法变成可检查的行动',
          style: Theme.of(context).textTheme.titleLarge,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          '${persona.name} · ${persona.role.label} · ${persona.replyStyle.label}',
          style: Theme.of(context).textTheme.bodySmall,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          '创建目标、拆解大纲、安排任务、改期和执行都可以直接告诉我；操作按权限确认，结果关联真实记录。',
          style: Theme.of(context).textTheme.bodyMedium,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 20),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 10,
          runSpacing: 10,
          children: [
            ActionChip(
              key: const Key('assistant-local-today'),
              avatar: const Icon(Icons.today_outlined, size: 18),
              label: const Text('查看今天安排'),
              onPressed: () => onLocalSchedule(),
            ),
            ActionChip(
              label: const Text('帮我安排今天'),
              onPressed: () => onPrompt(
                '先看看今天已有的安排，结合我的目标，帮我提出一份今天的任务计划。可用时间不明确时先问我，用计划卡集中展示新建或改期的任务。',
              ),
            ),
            ActionChip(
              label: const Text('创建一个任务'),
              onPressed: () => onPrompt('创建一个任务：'),
            ),
            ActionChip(
              key: const Key('assistant-outline-prompt'),
              avatar: const Icon(Icons.account_tree_outlined, size: 18),
              label: const Text('拆解学习目标'),
              onPressed: () =>
                  onPrompt('我想创建一个学习目标，并拆成分层大纲：\n目标：\n目前基础：\n希望达到的结果：'),
            ),
            ActionChip(
              key: const Key('assistant-retry-prompt'),
              avatar: const Icon(Icons.replay_outlined, size: 18),
              label: const Text('复盘并重新安排'),
              onPressed: () => onPrompt(
                '请先查找我想复盘的已结束或已取消任务，读取真实执行和失败记录，帮我分析改进点；确认任务和新日期后，创建关联的新尝试，保留原记录。\n任务名称：\n新安排：',
              ),
            ),
            ActionChip(
              key: const Key('assistant-adjust-prompt'),
              label: const Text('调整一组安排'),
              onPressed: () => onPrompt(
                '请先核对相关任务与日期安排，帮我用一份可编辑计划卡集中调整，保留未调整任务。\n需要调整的任务：\n可用日期和时间：',
              ),
            ),
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
      padding: EdgeInsets.only(top: isUser ? 8 : 0),
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
              color: isUser ? colors.primary : colors.surfaceContainerLow,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
                side: isUser
                    ? BorderSide.none
                    : const BorderSide(color: AppColors.hairline),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
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
                              ?.copyWith(color: colors.onPrimary, height: 1.5),
                        ),
                    for (final block in message.content)
                      if (AssistantAttachment.textFile(block) case final file?)
                        Theme(
                          data: Theme.of(
                            context,
                          ).copyWith(dividerColor: Colors.transparent),
                          child: ExpansionTile(
                            tilePadding: EdgeInsets.zero,
                            textColor: isUser
                                ? colors.onPrimary
                                : colors.onSurface,
                            collapsedTextColor: isUser
                                ? colors.onPrimary
                                : colors.onSurface,
                            iconColor: isUser
                                ? colors.onPrimary
                                : colors.onSurface,
                            collapsedIconColor: isUser
                                ? colors.onPrimary
                                : colors.onSurface,
                            title: Text(file.name),
                            leading: Icon(
                              Icons.description_outlined,
                              color: isUser ? colors.onPrimary : colors.primary,
                            ),
                            children: [
                              ConstrainedBox(
                                constraints: const BoxConstraints(
                                  maxHeight: 240,
                                ),
                                child: SingleChildScrollView(
                                  child: SelectableText(
                                    file.text,
                                    style: TextStyle(
                                      color: isUser
                                          ? colors.onPrimary
                                          : colors.onSurface,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                    for (final block in message.content.whereType<ImageBlock>())
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
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
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: () => showDialog<void>(
            context: context,
            builder: (context) => Dialog(
              child: Stack(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
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
        borderRadius: BorderRadius.circular(12),
        child: Image.network(block.url, width: 240, fit: BoxFit.contain),
      );
    }
    return Text(
      block.label ?? '云端图片引用',
      style: Theme.of(context).textTheme.bodySmall,
    );
  }
}

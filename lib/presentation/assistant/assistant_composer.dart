part of 'assistant_page.dart';

/// 助手输入区；页面状态仍由拥有它的 State 统一释放。
class _AssistantComposer {
  _AssistantComposer(this._page);
  final _AssistantPageState _page;
  BuildContext get context => _page.context;
  AssistantPage get widget => _page.widget;
  bool get mounted => _page.mounted;
  Widget _buildComposer(
    AssistantController controller,
  ) => ValueListenableBuilder<TextEditingValue>(
    valueListenable: _page._input,
    builder: (context, value, _) {
      final colors = Theme.of(context).colorScheme;
      final canSend =
          (value.text.trim().isNotEmpty || _page._attachments.isNotEmpty) &&
          !controller.isBusy &&
          !controller.compacting &&
          !controller.initializing &&
          !_page._picking &&
          !(_page._voice?.busy ?? false) &&
          !(_page._voice?.listening ?? false);
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
                if (_page._attachments.isNotEmpty)
                  SizedBox(
                    height: 72,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: _page._attachments.length,
                      separatorBuilder: (_, index) =>
                          const SizedBox(width: AppLayout.spaceSm),
                      itemBuilder: (context, index) {
                        final file = _page._attachments[index];
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
                              : () => _page._update(
                                  () => _page._attachments.removeAt(index),
                                ),
                          deleteButtonTooltipMessage: '移除 ${file.name}',
                        );
                      },
                    ),
                  ),
                if (_page._recordingVoice && _page._voice != null) ...[
                  const SizedBox(height: AppLayout.spaceSm),
                  AssistantVoiceStatus(
                    voice: _page._voice!,
                    onCancel: () async {
                      _page._recordingVoice = false;
                      await _page._voice!.cancel();
                      if (mounted) _page._update(() {});
                    },
                  ),
                ],
                TextField(
                  key: const Key('assistant-input'),
                  controller: _page._input,
                  autofocus:
                      widget.showBack && MediaQuery.sizeOf(context).width < 600,
                  focusNode: _page._inputFocus,
                  readOnly:
                      (_page._voice?.listening ?? false) ||
                      (_page._voice?.busy ?? false),
                  onChanged: (_) {
                    _page._recordingVoice = false;
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
                if (_page._recordingVoice && _page._voice?.error != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppLayout.spaceSm),
                    child: Text(
                      _page._voice!.error!,
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
                          !_page._picking,
                      onSelected: _composerAction,
                      icon: _page._picking
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
                              _page._attachments.length <
                              AssistantAttachment.maxCount,
                        ),
                        _composerMenuItem(
                          'file',
                          Icons.attach_file,
                          '添加文件',
                          enabled:
                              _page._attachments.length <
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
                    if (_page._voice != null)
                      IconButton(
                        key: const Key('assistant-composer-voice'),
                        tooltip: _page._voice!.listening ? '结束录音' : '语音输入',
                        onPressed: controller.isBusy || _page._voice!.busy
                            ? null
                            : _toggleVoice,
                        icon: Icon(
                          _page._voice!.listening
                              ? Icons.stop_circle_outlined
                              : Icons.mic_none_rounded,
                          color: _page._voice!.listening
                              ? colors.primary
                              : null,
                        ),
                      ),
                    Expanded(
                      child: Text(
                        _page._attachments.isEmpty
                            ? ''
                            : '${_page._attachments.length}/${AssistantAttachment.maxCount} 个附件',
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
        _page._usePrompt('帮我规划今天的任务，先查看我的安排。');
      case 'compact':
        try {
          final result = await widget.controller.compactConversation();
          if (!context.mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                result == null ? '当前会话较短，暂不需要压缩' : '已压缩上下文，聊天记录已保留',
              ),
            ),
          );
        } catch (error) {
          if (context.mounted) {
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
    final text = _page._input.text.trim();
    if ((text.isEmpty && _page._attachments.isEmpty) ||
        widget.controller.isBusy) {
      return;
    }
    if (!widget.controller.hasCredential) {
      await _page._openSettings();
      return;
    }
    final files = List<AssistantAttachment>.of(_page._attachments);
    final message = UserMessage.withContent(
      content: [
        if (text.isNotEmpty) TextBlock(text: text),
        ...files.map((file) => file.block),
      ],
    );
    _page._input.clear();
    _page._update(() => _page._attachments.clear());
    _page._recordingVoice = false;
    widget.controller.draft = '';
    widget.controller.saveAttachments(_page._draftSession, []);
    _page._followOutput = true;
    await widget.controller.sendMessage(message);
    if (!mounted) return;
    if (!widget.controller.transcript.any((item) => item.id == message.id) &&
        _page._input.text.isEmpty &&
        _page._attachments.isEmpty) {
      _page._input.text = text;
      _page._update(() => _page._attachments.addAll(files));
    }
    if (_page._followOutput) _page._scrollToBottom();
  }

  Future<void> _toggleVoice() async {
    final voice = _page._voice!;
    if (voice.listening) {
      await voice.stop();
      return;
    }
    _page._inputFocus.unfocus();
    _page._voicePrefix = _page._input.text.isEmpty
        ? ''
        : '${_page._input.text.trimRight()}\n';
    _page._recordingVoice = true;
    await voice.start();
  }

  Future<void> _pickAttachment(bool image) async {
    if (image && !widget.controller.supportsImages) {
      _showNotice('当前模型未开启图片能力，请先在助手设置中切换支持图片的模型。');
      return;
    }
    final draftKey = widget.controller.draftKey;
    _page._update(() => _page._picking = true);
    try {
      final file = await pickAssistantAttachment(image: image);
      if (file == null || !mounted || draftKey != widget.controller.draftKey) {
        return;
      }
      if (_page._attachments.fold<int>(
            file.bytes.length,
            (total, file) => total + file.bytes.length,
          ) >
          AssistantAttachment.maxTotalBytes) {
        throw const FormatException('本条消息附件合计不能超过 8 MiB');
      }
      if (_page._attachments.fold<int>(
            file.isImage ? 0 : (file.block as TextBlock).text.length,
            (total, file) =>
                total +
                (file.isImage ? 0 : (file.block as TextBlock).text.length),
          ) >
          AssistantAttachment.maxTextCharacters) {
        throw const FormatException('本条消息文本附件合计不能超过 32000 字符');
      }
      _page._update(() => _page._attachments.add(file));
    } catch (error) {
      if (mounted) {
        _showNotice(userErrorMessage(error, fallback: '附件未能加入，请重新选择或检查文件'));
      }
    } finally {
      if (mounted) _page._update(() => _page._picking = false);
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
}

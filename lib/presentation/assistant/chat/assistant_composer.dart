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
      final toolStyle = IconButton.styleFrom(
        minimumSize: const Size.square(AppLayout.touchTargetMin),
        iconSize: AppLayout.iconMd,
        foregroundColor: colors.onSurfaceVariant,
        disabledForegroundColor: AppColors.onDisabled,
      );
      final canSend =
          (value.text.trim().isNotEmpty || _page._attachments.isNotEmpty) &&
          !controller.isBusy &&
          !controller.needsOutcomeResolution &&
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
                    height: AppLayout.touchTargetMin,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: _page._attachments.length,
                      separatorBuilder: (_, index) =>
                          const SizedBox(width: AppLayout.spaceSm),
                      itemBuilder: (context, index) {
                        final file = _page._attachments[index];
                        if (file.isImage) {
                          return Material(
                            color: colors.surface,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(
                                AppLayout.radiusMd,
                              ),
                              side: BorderSide(color: colors.outlineVariant),
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: Tooltip(
                              message: '预览图片 ${file.name}',
                              child: InkWell(
                                onTap: () => _previewAttachment(file),
                                child: SizedBox.square(
                                  dimension: AppLayout.touchTargetMin,
                                  child: Padding(
                                    padding: const EdgeInsets.all(
                                      AppLayout.spaceXs,
                                    ),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(
                                        AppLayout.radiusSm,
                                      ),
                                      child: Image.memory(
                                        file.bytes,
                                        cacheWidth: 80,
                                        fit: BoxFit.cover,
                                        semanticLabel: '预览图片 ${file.name}',
                                        errorBuilder: (_, _, _) => const Icon(
                                          Icons.broken_image_outlined,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          );
                        }
                        return InputChip(
                          avatar: const Icon(
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
                      widget.showBack &&
                      AppLayout.windowClassOf(context) == WindowClass.compact,
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
                      popUpAnimationStyle: AppMotion.overlayStyle(context),
                      key: const Key('assistant-add-attachment'),
                      tooltip: '附件与快捷指令',
                      style: toolStyle,
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
                          : const Icon(
                              Icons.add_rounded,
                              size: AppLayout.iconMd,
                            ),
                      itemBuilder: (_) => [
                        if (kIsWeb ||
                            defaultTargetPlatform == TargetPlatform.android ||
                            defaultTargetPlatform == TargetPlatform.iOS)
                          _composerMenuItem(
                            'camera',
                            Icons.photo_camera_outlined,
                            '拍照',
                            enabled:
                                _page._attachments.length <
                                AssistantAttachment.maxCount,
                          ),
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
                      ],
                    ),
                    if (_page._voice != null)
                      IconButton(
                        key: const Key('assistant-composer-voice'),
                        tooltip: _page._voice!.listening ? '结束录音' : '语音输入',
                        style: toolStyle,
                        onPressed: controller.isBusy || _page._voice!.busy
                            ? null
                            : _toggleVoice,
                        icon: Icon(
                          _page._voice!.listening
                              ? Icons.stop_circle_outlined
                              : Icons.mic_none_rounded,
                          size: AppLayout.iconMd,
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
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                    _reasoningSelector(controller),
                    _contextIndicator(controller),
                    IconButton.filled(
                      key: const Key('assistant-send'),
                      tooltip: canStop ? '停止本轮' : '发送',
                      onPressed: action,
                      style: IconButton.styleFrom(
                        minimumSize: const Size.square(
                          AppLayout.touchTargetMin,
                        ),
                        foregroundColor: colors.onPrimary,
                        backgroundColor: colors.primary,
                        disabledForegroundColor: AppColors.onDisabled,
                        disabledBackgroundColor: AppColors.disabled,
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
                        size: AppLayout.iconMd,
                        color: action == null
                            ? AppColors.onDisabled
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
  Widget _reasoningSelector(AssistantController controller) {
    final scale = MediaQuery.textScalerOf(context).scale(1);
    final available = (MediaQuery.sizeOf(context).width - AppLayout.space3Xl)
        .clamp(0.0, double.infinity);
    final width = (128 * scale).clamp(0.0, available);
    final colors = Theme.of(context).colorScheme;
    return MenuAnchor(
      style: const MenuStyle(
        backgroundColor: WidgetStatePropertyAll(AppColors.card),
        surfaceTintColor: WidgetStatePropertyAll(Colors.transparent),
        shadowColor: WidgetStatePropertyAll(AppColors.shadow),
        elevation: WidgetStatePropertyAll(2),
        padding: WidgetStatePropertyAll(EdgeInsets.all(AppLayout.spaceXs)),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(AppLayout.radiusLg)),
          ),
        ),
      ),
      menuChildren: [
        SizedBox(
          width: width,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final effort in ReasoningEffort.values)
                MenuItemButton(
                  onPressed: () =>
                      unawaited(_selectReasoning(controller, effort)),
                  style: const ButtonStyle(
                    padding: WidgetStatePropertyAll(EdgeInsets.zero),
                    minimumSize: WidgetStatePropertyAll(
                      Size(0, AppLayout.touchTargetMin),
                    ),
                    shape: WidgetStatePropertyAll(
                      RoundedRectangleBorder(
                        borderRadius: BorderRadius.all(
                          Radius.circular(AppLayout.radiusMd),
                        ),
                      ),
                    ),
                  ),
                  child: AppSelectionOption(
                    selected: effort == controller.reasoningEffort,
                    enabled: true,
                    child: Text(assistantReasoningLabel(effort)),
                  ),
                ),
            ],
          ),
        ),
      ],
      builder: (context, menu, _) => IconButton(
        key: const Key('assistant-reasoning'),
        tooltip: '思考程度：${assistantReasoningLabel(controller.reasoningEffort)}',
        onPressed: controller.initialized && !controller.isBusy
            ? () => menu.isOpen ? menu.close() : menu.open()
            : null,
        style: IconButton.styleFrom(
          minimumSize: const Size.square(AppLayout.touchTargetMin),
          foregroundColor: controller.reasoningEffort == ReasoningEffort.off
              ? colors.onSurfaceVariant
              : colors.primary,
          disabledForegroundColor: AppColors.onDisabled,
        ),
        icon: const Icon(
          Icons.lightbulb_outline_rounded,
          size: AppLayout.iconMd,
        ),
      ),
    );
  }

  Future<void> _selectReasoning(
    AssistantController controller,
    ReasoningEffort effort,
  ) async {
    try {
      await controller.setReasoningEffort(effort);
    } catch (error) {
      if (mounted) {
        _showNotice(userErrorMessage(error, fallback: '思考程度未保存，请重试'));
      }
    }
  }

  PopupMenuItem<String> _composerMenuItem(
    String value,
    IconData icon,
    String label, {
    bool enabled = true,
  }) => PopupMenuItem(
    value: value,
    enabled: enabled,
    height: AppLayout.touchTargetMin,
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
      case 'camera':
        await _pickAttachment(true, capture: true);
      case 'image':
        await _pickAttachment(true);
      case 'file':
        await _pickAttachment(false);
    }
  }

  Widget _contextIndicator(AssistantController controller) {
    final used = controller.estimatedContextTokens;
    final limit = controller.contextInputLimit;
    final ratio = (limit <= 0 ? 1.0 : used / limit).clamp(0.0, 1.0);
    final session = controller.sessionUsage;
    final cacheRate = session.cacheHitRate;
    final last = session.lastConversationUsage;
    final label = [
      '输入占用约 ${(ratio * 100).toStringAsFixed(1)}%',
      '输入估算 $used / 可用输入 $limit tokens',
      '输出预留 ${controller.reservedOutputTokens} tokens',
      '上下文总窗口 ${controller.contextWindowTokens} tokens',
      if (session.hasUsage)
        '会话累计输入 ${session.usage.inputTokens} / 输出 ${session.usage.outputTokens} tokens',
      if (cacheRate != null) '正文缓存命中率 ${(cacheRate * 100).toStringAsFixed(1)}%',
      if (last != null) '最近一次正文输入 ${last.inputTokens} tokens',
      if (session.hasIncompleteUsage)
        '${session.incompleteReports} 次请求未完整结束，用量可能偏低',
      '点按或长按查看图表和详细用量',
    ].join('；');
    final colors = Theme.of(context).colorScheme;
    return Semantics(
      label: label,
      button: true,
      onTap: () => _showContextUsage(controller),
      child: ExcludeSemantics(
        child: IconButton(
          key: const Key('assistant-context-usage'),
          onPressed: () => _showContextUsage(controller),
          onLongPress: () => _showContextUsage(controller),
          icon: SizedBox.square(
            dimension: 20,
            child: CircularProgressIndicator(
              value: ratio,
              strokeWidth: 3,
              backgroundColor: colors.surfaceContainerHighest,
              color: ratio >= .9
                  ? colors.error
                  : ratio >= .75
                  ? AppColors.warning
                  : colors.primary,
              semanticsValue: '${(ratio * 100).round()}%',
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showContextUsage(AssistantController controller) =>
      showModalBottomSheet<void>(
        context: context,
        sheetAnimationStyle: AppMotion.overlayStyle(context),
        isScrollControlled: true,
        useSafeArea: true,
        backgroundColor: Theme.of(context).colorScheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppLayout.radiusXxl),
          ),
        ),
        builder: (_) => _AssistantContextSheet(controller: controller),
      );

  Future<void> _send() async {
    final text = _page._input.text.trim();
    if ((text.isEmpty && _page._attachments.isEmpty) ||
        widget.controller.isBusy ||
        widget.controller.needsOutcomeResolution) {
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

  Future<AssistantAttachment?> _compressImage(
    String name,
    Uint8List bytes,
  ) async {
    if (!mounted) return null;
    final accepted = await AppConfirmDialog.show(
      context: context,
      title: '图片超过 4 MiB',
      message:
          '原图 ${(bytes.length / 1024 / 1024).toStringAsFixed(1)} MiB。压缩发送副本后加入草稿，原图不变。文字细节可能降低，请发送前预览。',
      confirmText: '压缩并添加',
      cancelText: '取消',
    );
    if (!accepted || !mounted) return null;
    return compressAssistantImage(name, bytes);
  }

  Future<AssistantAttachment?> _captureImage() =>
      Navigator.of(context).push<AssistantAttachment>(
        MaterialPageRoute(
          builder: (cameraContext) => Scaffold(
            body: SafeArea(
              child: PhotoCapturePanel(
                title: '拍照发给助手',
                fullScreen: true,
                onBack: () => Navigator.pop(cameraContext),
                onCancel: () => Navigator.pop(cameraContext),
                onChooseFile: () async {
                  try {
                    final file = await pickAssistantAttachment(
                      image: true,
                      onOversizedImage: _compressImage,
                    );
                    if (cameraContext.mounted && file != null) {
                      Navigator.pop(cameraContext, file);
                    }
                  } catch (error) {
                    if (mounted) {
                      _showNotice(
                        userErrorMessage(error, fallback: '图片未能加入，请重新选择'),
                      );
                    }
                  }
                },
                onConfirmed: (bytes, capturedAt) async {
                  final name = 'photo-${capturedAt.millisecondsSinceEpoch}.jpg';
                  final file = bytes.length > AssistantAttachment.maxImageBytes
                      ? await _compressImage(name, bytes)
                      : AssistantAttachment.fromBytes(name, bytes);
                  if (cameraContext.mounted && file != null) {
                    Navigator.pop(cameraContext, file);
                  }
                },
              ),
            ),
          ),
        ),
      );

  Future<void> _pickAttachment(bool image, {bool capture = false}) async {
    if (image && !widget.controller.supportsImages) {
      _showNotice('当前模型未开启图片能力，请先在助手设置中切换支持图片的模型。');
      return;
    }
    final draftKey = widget.controller.draftKey;
    _page._update(() => _page._picking = true);
    try {
      final captured = capture ? await _captureImage() : null;
      final files = capture
          ? [?captured]
          : await pickAssistantAttachments(
              image: image,
              maxCount:
                  AssistantAttachment.maxCount - _page._attachments.length,
              onOversizedImage: _compressImage,
            );
      if (files.isEmpty || !mounted || draftKey != widget.controller.draftKey) {
        return;
      }
      if (_page._attachments.length + files.length >
          AssistantAttachment.maxCount) {
        throw const FormatException('每条消息最多添加 12 个附件');
      }
      if (_page._attachments.fold<int>(
            files.fold<int>(0, (sum, file) => sum + file.bytes.length),
            (total, file) => total + file.bytes.length,
          ) >
          AssistantAttachment.maxTotalBytes) {
        throw const FormatException('本条消息附件合计不能超过 24 MiB');
      }
      if (_page._attachments.fold<int>(
            files.fold<int>(
              0,
              (sum, file) =>
                  sum +
                  (file.isImage ? 0 : (file.block as TextBlock).text.length),
            ),
            (total, file) =>
                total +
                (file.isImage ? 0 : (file.block as TextBlock).text.length),
          ) >
          AssistantAttachment.maxTextCharacters) {
        throw const FormatException('本条消息文本附件合计不能超过 32000 字符');
      }
      _page._update(() => _page._attachments.addAll(files));
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
    animationStyle: AppMotion.overlayStyle(context),
    builder: (context) => Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720, maxHeight: 640),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text(file.name),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (file.isImage)
                    IconButton(
                      tooltip: '移除图片',
                      onPressed: widget.controller.isBusy
                          ? null
                          : () {
                              _page._update(
                                () => _page._attachments.remove(file),
                              );
                              Navigator.pop(context);
                            },
                      icon: const Icon(Icons.delete_outline_rounded),
                    ),
                  IconButton(
                    tooltip: '关闭预览',
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
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

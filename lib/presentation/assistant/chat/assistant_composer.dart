part of 'assistant_page.dart';

/// 发送动作槽里的可见圆面直径；圆面只负责绘制，48dp 触控由外层按钮承担。
const double _composerSendSurfaceSize = 36;

/// 工具行单行所需宽度：附件、麦克风、思考、上下文环、发送五个 48dp 触控槽，
/// 再加附件计数的最小文字槽。实际宽度不足时思考与上下文环另起一行。
const double _composerToolsMinWidth =
    AppMetrics.touchTargetMin * 5 + AppMetrics.spaceXxl;

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
      final desktopKeyboard =
          defaultTargetPlatform == TargetPlatform.windows ||
          defaultTargetPlatform == TargetPlatform.macOS ||
          defaultTargetPlatform == TargetPlatform.linux;
      final colors = Theme.of(context).colorScheme;
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
      final canSubmit = canSend && value.composing.isCollapsed;
      final action = canStop
          ? controller.stop
          : canSubmit
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
            borderRadius: BorderRadius.circular(AppMetrics.radiusXxl),
            side: const BorderSide(color: AppColors.hairline),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppMetrics.spaceMd,
              AppMetrics.spaceXs,
              AppMetrics.spaceMd,
              AppMetrics.spaceSm,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (controller.unsentDrafts.isNotEmpty)
                  Row(
                    children: [
                      const Expanded(child: Text('有未发送成功的内容，已保留')),
                      TextButton(
                        onPressed: () {
                          if (_page._input.text.isNotEmpty ||
                              _page._attachments.isNotEmpty) {
                            _showNotice('请先发送或保存当前草稿，再恢复未发送内容');
                            return;
                          }
                          final draft = controller.takeUnsentDraft();
                          if (draft == null) return;
                          _page._input.text = draft.text;
                          controller.saveDraft(_page._draftSession, draft.text);
                          _page._update(
                            () => _page._attachments.addAll(draft.attachments),
                          );
                        },
                        child: const Text('恢复'),
                      ),
                    ],
                  ),
                if (_page._attachments.isNotEmpty)
                  SizedBox(
                    height: AppMetrics.touchTargetMin,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: _page._attachments.length,
                      separatorBuilder: (_, index) =>
                          const SizedBox(width: AppMetrics.spaceSm),
                      itemBuilder: (context, index) {
                        final file = _page._attachments[index];
                        if (file.isImage) {
                          return Material(
                            color: colors.surface,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(
                                AppMetrics.radiusMd,
                              ),
                              side: BorderSide(color: colors.outlineVariant),
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: Tooltip(
                              message: '预览图片 ${file.name}',
                              child: InkWell(
                                onTap: () => _previewAttachment(file),
                                child: SizedBox.square(
                                  dimension: AppMetrics.touchTargetMin,
                                  child: Padding(
                                    padding: const EdgeInsets.all(
                                      AppMetrics.spaceXs,
                                    ),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(
                                        AppMetrics.radiusSm,
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
                            size: AppMetrics.iconMd,
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
                  const SizedBox(height: AppMetrics.spaceSm),
                  AssistantVoiceStatus(voice: _page._voice!),
                ],
                CallbackShortcuts(
                  bindings: canSubmit
                      ? {
                          const SingleActivator(LogicalKeyboardKey.enter): () {
                            if (_page._input.value.composing.isCollapsed) {
                              unawaited(_send());
                            }
                          },
                          const SingleActivator(
                            LogicalKeyboardKey.enter,
                            control: true,
                          ): () {
                            if (_page._input.value.composing.isCollapsed) {
                              unawaited(_send());
                            }
                          },
                        }
                      : const {},
                  child: TextField(
                    key: const Key('assistant-input'),
                    controller: _page._input,
                    autofocus:
                        widget.showBack &&
                        AppLayout.windowClassOf(context) == WindowClass.compact,
                    focusNode: _page._inputFocus,
                    readOnly:
                        (_page._voice?.listening ?? false) ||
                        (_page._voice?.busy ?? false),
                    onChanged: (text) {
                      _page._voiceInputError = null;
                      controller.saveDraft(_page._draftSession, text);
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
                    textInputAction: desktopKeyboard
                        ? TextInputAction.newline
                        : TextInputAction.send,
                    onSubmitted: !desktopKeyboard && canSubmit
                        ? (_) => _send()
                        : null,
                    decoration: InputDecoration(
                      hintText: '描述你想讨论或调整的内容…',
                      filled: false,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: AppMetrics.spaceXs,
                        vertical: AppMetrics.spaceMd,
                      ),
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                    ),
                  ),
                ),
                if (_page._voiceInputError != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppMetrics.spaceSm),
                    child: Text(
                      _page._voiceInputError!,
                      style: const TextStyle(color: AppColors.error),
                    ),
                  ),
                if (_page._recordingVoice)
                  _voiceActions()
                else
                  _composerTools(
                    controller,
                    canStop: canStop,
                    canSend: canSubmit,
                    action: action,
                  ),
              ],
            ),
          ),
        ),
      );
    },
  );
  Widget _voiceActions() {
    final voice = _page._voice!;
    return Row(
      children: [
        Tooltip(
          message: '取消本次语音',
          child: TextButton.icon(
            key: const Key('assistant-composer-voice'),
            onPressed: _page._cancelVoiceInput,
            icon: const Icon(Icons.close_rounded, size: AppMetrics.iconMd),
            label: const Text('取消'),
          ),
        ),
        const Spacer(),
        Tooltip(
          message: '结束录音并转文字',
          child: FilledButton.icon(
            key: const Key('assistant-send'),
            onPressed: voice.listening ? voice.stop : null,
            icon: const Icon(Icons.check_rounded, size: AppMetrics.iconMd),
            label: const Text('完成'),
          ),
        ),
      ],
    );
  }

  /// 工具行图标按钮的局部样式：48dp 触控、20dp 图标，不改全局 IconButton 主题。
  ButtonStyle get _toolStyle => IconButton.styleFrom(
    minimumSize: const Size.square(AppMetrics.touchTargetMin),
    iconSize: AppMetrics.iconMd,
    foregroundColor: Theme.of(context).colorScheme.onSurfaceVariant,
    disabledForegroundColor: AppColors.onDisabled,
  );

  /// 输入区底部工具行：附件、麦克风、思考、上下文环与发送共用 48dp 触控槽并
  /// 保持中心同线。实际宽度不足时，思考与上下文环整体换到主行上方，发送仍留
  /// 在主行末端；两行都按真实布局撑开，不缩放按钮，也不裁掉键盘避让。
  Widget _composerTools(
    AssistantController controller, {
    required bool canStop,
    required bool canSend,
    required VoidCallback? action,
  }) {
    final secondaryTools = <Widget>[
      _reasoningSelector(controller),
      _contextIndicator(controller),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        final singleRow = constraints.maxWidth >= _composerToolsMinWidth;
        final primaryRow = Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            _attachmentMenu(controller),
            if (_page._voice != null) _voiceButton(controller),
            Expanded(child: _attachmentCount()),
            if (singleRow) ...secondaryTools,
            _sendActionSlot(canStop: canStop, canSend: canSend, action: action),
          ],
        );
        if (singleRow) return primaryRow;
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(children: secondaryTools),
            primaryRow,
          ],
        );
      },
    );
  }

  /// 附件菜单保持原动作与可用条件，只把入口放进统一 48dp 工具槽。
  Widget _attachmentMenu(AssistantController controller) =>
      PopupMenuButton<String>(
        popUpAnimationStyle: AppMotion.overlayStyle(context),
        key: const Key('assistant-add-attachment'),
        tooltip: '附件与快捷指令',
        style: _toolStyle,
        constraints: const BoxConstraints(minWidth: 188, maxWidth: 240),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppMetrics.radiusLg),
        ),
        enabled:
            !controller.isBusy &&
            !controller.compacting &&
            !_page._picking &&
            !(_page._voice?.busy ?? false) &&
            !(_page._voice?.listening ?? false),
        onSelected: _composerAction,
        icon: _page._picking
            ? const SizedBox.square(
                dimension: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.add_rounded, size: AppMetrics.iconMd),
        itemBuilder: (_) => [
          if (kIsWeb || defaultTargetPlatform == TargetPlatform.android)
            _composerMenuItem(
              'camera',
              Icons.photo_camera_outlined,
              '拍照',
              enabled: _page._attachments.length < AssistantAttachment.maxCount,
            ),
          _composerMenuItem(
            'image',
            Icons.image_outlined,
            '添加图片',
            enabled: _page._attachments.length < AssistantAttachment.maxCount,
          ),
          _composerMenuItem(
            'file',
            Icons.attach_file,
            '添加文件',
            enabled: _page._attachments.length < AssistantAttachment.maxCount,
          ),
        ],
      );

  /// 语音入口只在装配了语音服务时出现，可用条件保持原样。
  Widget _voiceButton(AssistantController controller) => IconButton(
    key: const Key('assistant-composer-voice'),
    tooltip: '语音输入',
    style: _toolStyle,
    onPressed:
        controller.isBusy ||
            controller.compacting ||
            controller.initializing ||
            controller.needsOutcomeResolution ||
            _page._picking ||
            _page._voice!.busy ||
            _page._voice!.listening
        ? null
        : _toggleVoice,
    icon: const Icon(Icons.mic_none_rounded, size: AppMetrics.iconMd),
  );

  /// 附件数量说明占据发送前的弹性文字槽，窄宽度时省略而不挤掉触控。
  Widget _attachmentCount() => Text(
    _page._attachments.isEmpty
        ? ''
        : '${_page._attachments.length}/${AssistantAttachment.maxCount} 个附件',
    maxLines: 1,
    overflow: TextOverflow.ellipsis,
    style: Theme.of(context).textTheme.bodySmall,
  );

  /// 发送与停止共用的 48dp 动作槽：可见 36dp 圆面只负责绘制，按钮本身铺满
  /// 48dp 触控、可键盘获得焦点，并且只产生一个按钮语义节点。
  Widget _sendActionSlot({
    required bool canStop,
    required bool canSend,
    required VoidCallback? action,
  }) {
    final Color surfaceColor;
    final Color iconColor;
    if (canStop) {
      // 生成中：原位浅绿圆面配深绿停止图标，读屏仍只报“停止本轮”。
      surfaceColor = AppColors.primarySoft;
      iconColor = AppColors.primary;
    } else if (canSend) {
      surfaceColor = AppColors.primary;
      iconColor = AppColors.onPrimary;
    } else {
      // 空输入或不可发：浅中性底配次级文字色，不冒充可发送。
      surfaceColor = AppColors.surfaceMuted;
      iconColor = AppColors.textSecondary;
    }
    return SizedBox.square(
      dimension: AppMetrics.touchTargetMin,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // 圆面不参与命中和读屏，触控全部交给 48dp 的按钮。
          IgnorePointer(
            child: SizedBox.square(
              dimension: _composerSendSurfaceSize,
              child: DecoratedBox(
                key: const Key('assistant-send-surface'),
                decoration: BoxDecoration(
                  color: surfaceColor,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ),
          IconButton(
            key: const Key('assistant-send'),
            tooltip: canStop ? '停止本轮' : '发送',
            onPressed: action,
            style: IconButton.styleFrom(
              padding: EdgeInsets.zero,
              minimumSize: const Size.square(AppMetrics.touchTargetMin),
              maximumSize: const Size.square(AppMetrics.touchTargetMin),
              backgroundColor: Colors.transparent,
              // 森林绿圆面上用主色内容色提供按压/焦点反馈；浅色状态沿用
              // 全局主题的浅绿反馈，不新增或覆盖全局 IconButton 主题。
              overlayColor: canSend && !canStop ? AppColors.onPrimary : null,
              shape: const CircleBorder(),
            ),
            icon: Icon(
              canStop ? Icons.stop_rounded : Icons.arrow_upward_rounded,
              size: AppMetrics.iconMd,
              color: iconColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _reasoningSelector(AssistantController controller) {
    final scale = MediaQuery.textScalerOf(context).scale(1);
    final available = (MediaQuery.sizeOf(context).width - AppMetrics.space3Xl)
        .clamp(0.0, double.infinity);
    final width = (128 * scale).clamp(0.0, available);
    final colors = Theme.of(context).colorScheme;
    return MenuAnchor(
      style: const MenuStyle(
        backgroundColor: WidgetStatePropertyAll(AppColors.card),
        surfaceTintColor: WidgetStatePropertyAll(Colors.transparent),
        shadowColor: WidgetStatePropertyAll(AppColors.shadow),
        elevation: WidgetStatePropertyAll(2),
        padding: WidgetStatePropertyAll(EdgeInsets.all(AppMetrics.spaceXs)),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.all(
              Radius.circular(AppMetrics.radiusLg),
            ),
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
                      Size(0, AppMetrics.touchTargetMin),
                    ),
                    shape: WidgetStatePropertyAll(
                      RoundedRectangleBorder(
                        borderRadius: BorderRadius.all(
                          Radius.circular(AppMetrics.radiusMd),
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
          minimumSize: const Size.square(AppMetrics.touchTargetMin),
          foregroundColor: controller.reasoningEffort == ReasoningEffort.off
              ? colors.onSurfaceVariant
              : colors.primary,
          disabledForegroundColor: AppColors.onDisabled,
        ),
        icon: const Icon(
          Icons.lightbulb_outline_rounded,
          size: AppMetrics.iconMd,
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
    height: AppMetrics.touchTargetMin,
    child: Row(
      children: [
        Icon(icon, size: AppMetrics.iconMd),
        const SizedBox(width: AppMetrics.spaceMd),
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
            top: Radius.circular(AppMetrics.radiusXxl),
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
    final sourceDraft = widget.controller.draftKey;
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
    _page._hasNewOutput = false;
    _page._showJumpToLatest = false;
    await widget.controller.sendMessage(message);
    if (!widget.controller.transcript.any((item) => item.id == message.id)) {
      if (mounted &&
          widget.controller.draftKey == sourceDraft &&
          _page._input.text.isEmpty &&
          _page._attachments.isEmpty) {
        _page._input.text = text;
        widget.controller.saveDraft(sourceDraft, text);
        _page._update(() => _page._attachments.addAll(files));
      } else {
        widget.controller.retainUnsentDraft(
          sourceDraft,
          AssistantUnsentDraft(text, List.unmodifiable(files)),
        );
      }
    }
    if (mounted && _page._followOutput) _page._scrollToBottom();
  }

  Future<void> _toggleVoice() async {
    final voice = _page._voice!;
    if (voice.busy || voice.listening || widget.controller.isBusy) return;
    final before = _page._input.value;
    final selection = before.selection;
    final start = selection.isValid ? selection.start : before.text.length;
    final end = selection.isValid ? selection.end : before.text.length;
    _page._voiceDraftBefore = before;
    _page._voicePrefix = before.text.substring(0, start);
    _page._voiceSuffix = before.text.substring(end);
    _page._voiceInputError = null;
    _page._inputFocus.unfocus();
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
      openDetailPane<AssistantAttachment>(
        context,
        label: '拍摄助手图片',
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
      if (files.isEmpty) return;
      final current = mounted && draftKey == widget.controller.draftKey;
      final target = current
          ? _page._attachments
          : widget.controller.attachmentsFor(draftKey);
      if (target.length + files.length > AssistantAttachment.maxCount) {
        throw const FormatException('每条消息最多添加 12 个附件');
      }
      if (target.fold<int>(
            files.fold<int>(0, (sum, file) => sum + file.bytes.length),
            (total, file) => total + file.bytes.length,
          ) >
          AssistantAttachment.maxTotalBytes) {
        throw const FormatException('本条消息附件合计不能超过 24 MiB');
      }
      if (target.fold<int>(
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
      if (current) {
        _page._update(() => _page._attachments.addAll(files));
      } else {
        widget.controller.saveAttachments(draftKey, [...target, ...files]);
        if (mounted) _showNotice('附件已加入原会话草稿');
      }
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
                      padding: const EdgeInsets.all(AppMetrics.spaceXl),
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

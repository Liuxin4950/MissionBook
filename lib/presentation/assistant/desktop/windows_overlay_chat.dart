part of 'windows_assistant_overlay.dart';

class _WindowsOverlayChat extends StatelessWidget {
  // 工具栏的绘制尺寸，按钮仍使用共享触控下限。
  static const _toolbarVisualSize = 40.0;

  const _WindowsOverlayChat({required this.host});

  final _WindowsOverlayState host;

  @override
  Widget build(BuildContext context) {
    final state = host._snapshot;
    final key = host._key;
    final voice = _fields(state['voice']);
    final ready = key.isNotEmpty;
    final isShort = MediaQuery.sizeOf(context).height < 340;
    final title = _text(state, 'title');
    final name = _text(state, 'name');
    return Material(
      color: AppColors.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppMetrics.radiusMd),
        side: const BorderSide(color: AppColors.hairline),
      ),
      clipBehavior: Clip.antiAlias,
      child: LayoutBuilder(
        builder: (context, bounds) {
          final narrow = bounds.maxWidth < 285;
          final short = isShort || bounds.maxHeight < 340;
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.only(
                  left: AppMetrics.spaceMd,
                  right: AppMetrics.spaceXs,
                ),
                child: Row(
                  children: [
                    if (!narrow) ...[
                      CircleAvatar(
                        radius: 11,
                        backgroundColor: AppColors.primary,
                        child: host._avatar(22),
                      ),
                      const SizedBox(width: AppMetrics.spaceSm),
                    ],
                    Expanded(
                      child: Text(
                        title.isEmpty || title == '新会话'
                            ? (name.isEmpty ? '书祺' : name)
                            : title,
                        style: AppTypography.sectionTitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    _icon(
                      '截图',
                      Icons.screenshot_monitor_outlined,
                      host._working || voice.isNotEmpty ? null : host._capture,
                    ),
                    PopupMenuButton<String>(
                      tooltip: '会话选项',
                      popUpAnimationStyle: AppMotion.overlayStyle(context),
                      icon: const Icon(
                        Icons.more_horiz_rounded,
                        size: AppMetrics.iconSm,
                      ),
                      onSelected: (choice) async {
                        if (choice == 'main') {
                          await host._openMain();
                        } else {
                          await host._saveDraft();
                          await host._action('newSession');
                        }
                      },
                      itemBuilder: (_) => [
                        PopupMenuItem<String>(
                          value: 'new',
                          enabled: ready && !host._busy && voice.isEmpty,
                          child: const Text('新会话'),
                        ),
                        const PopupMenuItem<String>(
                          value: 'main',
                          child: Text('打开完整会话'),
                        ),
                      ],
                    ),
                    _icon(
                      '收起聊天',
                      Icons.close_rounded,
                      () => host._mode('closed'),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              if (host._preview case final preview?)
                Expanded(child: _preview(preview))
              else ...[
                Expanded(child: _conversation(context)),
                if (host._images.isNotEmpty) _imageStrip(),
                if (voice.isNotEmpty)
                  _voice(voice)
                else
                  _composer(context, ready: ready, short: short),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _conversation(BuildContext context) {
    final entries = _items(host._snapshot['messages']);
    final operations = _items(host._snapshot['operations']);
    final partial = _text(host._snapshot, 'partial');
    final error = host._error ?? host._snapshot['error'] as String?;
    final showProgress =
        host._running &&
        partial.isEmpty &&
        !operations.any((item) => item['status'] == 'waitingConfirmation');
    final content = <Widget>[
      for (final message in entries)
        KeyedSubtree(
          key: ValueKey(message['id']),
          child: _message(
            _text(message, 'text'),
            isUser: message['user'] == true,
            imageCount: _number(message, 'images'),
          ),
        ),
      if (partial.isNotEmpty) _message(partial, streaming: true),
      for (final operation in operations)
        if (operation['status'] == 'waitingConfirmation' ||
            operation['status'] == 'unknown' ||
            operation['missionId'] is String)
          _operation(operation),
      if (showProgress)
        const Align(
          alignment: Alignment.centerLeft,
          child: Padding(
            padding: EdgeInsets.all(AppMetrics.spaceSm),
            child: SizedBox.square(
              dimension: 14,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                semanticsLabel: '正在回复',
              ),
            ),
          ),
        ),
      if (!host._hasChat || host._key.isEmpty)
        const Text('正在打开会话…', style: AppTypography.metadata),
      if (host._snapshot['canUseImages'] == false && host._images.isNotEmpty)
        const Text('当前模型无法接收图片，可在完整会话切换模型。', style: AppTypography.metadata),
      if (host._draftConflict)
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            const Text('草稿已在另一窗口修改', style: AppTypography.metadata),
            TextButton(
              onPressed: () =>
                  host._acceptState(host._snapshot, replaceDraft: true),
              child: const Text('载入共享草稿'),
            ),
          ],
        ),
      if (error != null && error.isNotEmpty)
        Semantics(
          liveRegion: true,
          child: Text(
            error,
            style: AppTypography.metadata.copyWith(color: AppColors.error),
          ),
        ),
    ];
    return NotificationListener<UserScrollNotification>(
      onNotification: (event) {
        if (AssistantOutputScroll.isUserScroll(event)) {
          final atLatest = AssistantOutputScroll.isAtLatest(event.metrics);
          final hasNewOutput = atLatest ? false : host._hasNewOutput;
          final showJump = AssistantOutputScroll.shouldShowJumpToLatest(
            following: atLatest,
            hasNewOutput: hasNewOutput,
          );
          if (host._followOutput != atLatest ||
              host._hasNewOutput != hasNewOutput ||
              host._showJumpToLatest != showJump) {
            host.setState(() {
              host._followOutput = atLatest;
              host._hasNewOutput = hasNewOutput;
              host._showJumpToLatest = showJump;
            });
          }
          if (host._key.isNotEmpty) {
            host._readingPositions[host._key] = (
              offset: event.metrics.pixels,
              follow: atLatest,
              hasNewOutput: hasNewOutput,
              outputVersion: host._outputVersion,
            );
          }
        }
        return false;
      },
      child: Stack(
        children: [
          SelectionArea(
            child: ListView.separated(
              reverse: true,
              controller: host._scroll,
              padding: const EdgeInsets.symmetric(
                horizontal: AppMetrics.spaceMd,
                vertical: AppMetrics.spaceSm,
              ),
              itemBuilder: (_, index) => content[content.length - index - 1],
              separatorBuilder: (_, index) =>
                  const SizedBox(height: AppMetrics.spaceSm),
              itemCount: content.length,
            ),
          ),
          if (host._showJumpToLatest)
            Positioned(
              right: AppMetrics.spaceSm,
              bottom: AppMetrics.spaceSm,
              child: KeyedSubtree(
                key: const Key('windows-overlay-jump-to-latest'),
                child: _quietAction(
                  '回到最新消息',
                  Icons.south_rounded,
                  host._jumpToLatest,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _message(
    String text, {
    bool isUser = false,
    bool streaming = false,
    int imageCount = 0,
  }) => Align(
    alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
    child: Container(
      margin: EdgeInsets.only(
        left: isUser ? AppMetrics.spaceXl : 0,
        right: isUser ? 0 : AppMetrics.spaceXl,
      ),
      padding: const EdgeInsets.symmetric(
        vertical: AppMetrics.spaceSm,
        horizontal: AppMetrics.spaceMd,
      ),
      decoration: BoxDecoration(
        color: isUser ? AppColors.primarySoft : AppColors.background,
        borderRadius: BorderRadius.circular(AppMetrics.radiusMd),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (text.isNotEmpty)
            if (isUser)
              Text(text, style: AppTypography.itemTitle)
            else
              AssistantMarkdown(
                text: text,
                compact: true,
                streaming: streaming,
              ),
          if (imageCount > 0)
            Text('图片 × $imageCount', style: AppTypography.metadata),
        ],
      ),
    ),
  );

  Widget _operation(_Fields item) {
    final id = _text(item, 'id');
    final preview = _text(item, 'preview');
    final detail = _text(item, 'detail');
    final status = item['status'];
    final mission = _text(item, 'missionId');
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.background,
        border: Border.all(color: AppColors.hairline),
        borderRadius: BorderRadius.circular(AppMetrics.radiusMd),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppMetrics.spaceMd,
          AppMetrics.spaceSm,
          AppMetrics.spaceMd,
          0,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(_text(item, 'label'), style: AppTypography.itemTitle),
            if (preview.isNotEmpty)
              Text(preview, style: AppTypography.metadata),
            if (detail.isNotEmpty) Text(detail, style: AppTypography.metadata),
            Wrap(
              alignment: WrapAlignment.end,
              children: [
                if (status == 'waitingConfirmation') ...[
                  TextButton(
                    onPressed: host._working
                        ? null
                        : () => host._action('reject', {'operation': id}),
                    child: const Text('取消'),
                  ),
                  if (item['confirmable'] == true)
                    TextButton(
                      onPressed: host._working
                          ? null
                          : () => host._action('confirm', {
                              'operation': id,
                              'version': item['version'],
                            }),
                      child: Text(item['writes'] == true ? '确认保存' : '允许读取'),
                    )
                  else
                    TextButton(
                      onPressed: () => host._openMain(),
                      child: const Text('查看完整提案'),
                    ),
                ],
                if (status == 'unknown')
                  TextButton(
                    onPressed: host._working
                        ? null
                        : () => host._action('checkOutcome', {'operation': id}),
                    child: const Text('核对操作结果'),
                  ),
                if (mission.isNotEmpty)
                  TextButton(
                    onPressed: () => host._openMain(missionId: mission),
                    child: const Text('查看日程'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _imageStrip() => SizedBox(
    height: 40,
    child: ListView.separated(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: AppMetrics.spaceSm),
      itemBuilder: (_, index) {
        final item = host._images[index];
        return _icon(
          '预览${_text(item, 'name')}',
          Icons.image_outlined,
          host._working
              ? null
              : () => host._perform(() async {
                  final bytes = await host._workspace('image', {
                    'image': item['id'],
                  });
                  if (host.mounted && bytes is Uint8List && host._hasChat) {
                    host._showPreview((item: item, bytes: bytes));
                  }
                }),
        );
      },
      separatorBuilder: (_, index) => const SizedBox(width: AppMetrics.spaceXs),
      itemCount: host._images.length,
    ),
  );

  Widget _preview(({_Fields item, Uint8List bytes}) preview) => Column(
    children: [
      Row(
        children: [
          _icon(
            '返回聊天',
            Icons.arrow_back_rounded,
            () => host._showPreview(null),
          ),
          Expanded(
            child: Text(
              _text(preview.item, 'name'),
              style: AppTypography.itemTitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          _icon(
            '保存为记录',
            Icons.bookmark_add_outlined,
            host._working
                ? null
                : () => host._perform(() async {
                    final id = await host._workspace('stageRecord', {
                      'image': preview.item['id'],
                    });
                    if (id is String) await host._openMain(recordId: id);
                  }),
          ),
          _icon(
            '移除图片',
            Icons.delete_outline_rounded,
            host._working
                ? null
                : () => host._perform(() async {
                    final next = await host._workspace('removeImage', {
                      'image': preview.item['id'],
                    });
                    if (host.mounted) {
                      host._acceptState(_fields(next));
                      host._showPreview(null);
                    }
                  }),
          ),
        ],
      ),
      Expanded(
        child: InteractiveViewer(
          child: Center(
            child: Image.memory(preview.bytes, fit: BoxFit.contain),
          ),
        ),
      ),
    ],
  );

  Widget _voice(_Fields voice) {
    final label = voice['starting'] == true
        ? '正在准备麦克风…'
        : voice['listening'] == true
        ? '录音中 · ${_number(voice, 'seconds')} 秒'
        : voice['busy'] == true
        ? '正在转写…'
        : '语音输入';
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppMetrics.spaceSm,
        vertical: AppMetrics.spaceXs,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (voice['error'] case final String error)
            Text(
              error,
              style: AppTypography.metadata.copyWith(color: AppColors.error),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            )
          else
            Text(
              label,
              style: AppTypography.metadata,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          Wrap(
            alignment: WrapAlignment.end,
            children: [
              TextButton(
                onPressed: () => host
                    ._workspace('voiceCancel')
                    .catchError((Object _) => null),
                child: const Text('取消'),
              ),
              TextButton(
                onPressed: host._working || voice['busy'] == true
                    ? null
                    : () => host._perform(() async {
                        final result = _fields(
                          await host._workspace('voiceFinish'),
                        );
                        if (!host.mounted) return;
                        final text = _text(result, 'text').trim();
                        if (result['error'] case final String error) {
                          host._setError(error);
                        }
                        if (text.isNotEmpty) {
                          final input = host._input.value;
                          final start = input.selection.isValid
                              ? math.min(
                                  input.selection.start,
                                  input.text.length,
                                )
                              : input.text.length;
                          final end = input.selection.isValid
                              ? math.min(input.selection.end, input.text.length)
                              : input.text.length;
                          host._input.value = TextEditingValue(
                            text: input.text.replaceRange(start, end, text),
                            selection: TextSelection.collapsed(
                              offset: start + text.length,
                            ),
                          );
                          await host._saveDraft();
                        }
                        if (host.mounted && host._hasChat) {
                          host._inputFocus.requestFocus();
                        }
                      }),
                child: const Text('完成'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _composer(
    BuildContext context, {
    required bool ready,
    required bool short,
  }) => ValueListenableBuilder<TextEditingValue>(
    valueListenable: host._input,
    builder: (context, value, _) {
      final hasContent =
          value.text.trim().isNotEmpty || host._images.isNotEmpty;
      final blockedImages =
          host._images.isNotEmpty && host._snapshot['canUseImages'] == false;
      final canSend =
          ready &&
          hasContent &&
          !host._working &&
          !host._busy &&
          !blockedImages &&
          !host._draftConflict;
      final canSubmit = canSend && value.composing.isCollapsed;
      Future<void> send() => host._perform(() async {
        if (!canSubmit) return;
        host._draftTimer?.cancel();
        if (host._draftSaving case final pending?) await pending;
        if (!host.mounted || host._draftConflict) return;
        host._followOutput = true;
        host._hasNewOutput = false;
        host._showJumpToLatest = false;
        final state = await host._workspace('send', {
          'previous': host._syncedDraft,
          'text': host._input.text,
        });
        host._acceptState(_fields(state), replaceDraft: true);
      });
      return Padding(
        padding: const EdgeInsets.fromLTRB(
          AppMetrics.spaceSm,
          AppMetrics.spaceXs,
          AppMetrics.spaceSm,
          AppMetrics.spaceSm,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            _icon(
              '语音输入',
              Icons.mic_none_rounded,
              ready && !host._busy && !host._working ? host._startVoice : null,
            ),
            Expanded(
              child: CallbackShortcuts(
                bindings: canSubmit
                    ? {
                        const SingleActivator(LogicalKeyboardKey.enter): () {
                          if (host._input.value.composing.isCollapsed) {
                            unawaited(send());
                          }
                        },
                        const SingleActivator(
                          LogicalKeyboardKey.enter,
                          control: true,
                        ): () {
                          if (host._input.value.composing.isCollapsed) {
                            unawaited(send());
                          }
                        },
                      }
                    : const {},
                child: TextField(
                  controller: host._input,
                  focusNode: host._inputFocus,
                  maxLines: short ? 1 : 3,
                  minLines: 1,
                  textInputAction: TextInputAction.newline,
                  readOnly: !ready || host._working,
                  inputFormatters: [LengthLimitingTextInputFormatter(16000)],
                  style: AppTypography.itemTitle,
                  decoration: InputDecoration(
                    isDense: true,
                    hintText: '问书祺…',
                    hintStyle: AppTypography.metadata,
                    fillColor: AppColors.surfaceMuted,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: AppMetrics.spaceMd,
                      vertical: AppMetrics.spaceSm,
                    ),
                    constraints: const BoxConstraints(
                      minHeight: _toolbarVisualSize,
                    ),
                  ),
                  onChanged: host._edited,
                ),
              ),
            ),
            const SizedBox(width: AppMetrics.spaceXs),
            _sendAction(
              label: host._running ? '停止生成' : '发送（Enter）',
              icon: host._running
                  ? Icons.stop_rounded
                  : Icons.arrow_upward_rounded,
              action: host._working
                  ? null
                  : host._running
                  ? () => host._action('stop')
                  : canSubmit
                  ? send
                  : null,
            ),
          ],
        ),
      );
    },
  );

  Widget _quietAction(String label, IconData icon, VoidCallback action) =>
      SizedBox.square(
        dimension: AppMetrics.touchTargetMin,
        child: Tooltip(
          message: label,
          child: Semantics(
            label: label,
            button: true,
            child: Material(
              color: Colors.transparent,
              shape: const CircleBorder(),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: action,
                child: Center(
                  child: Container(
                    width: _toolbarVisualSize,
                    height: _toolbarVisualSize,
                    decoration: const BoxDecoration(
                      color: AppColors.surfaceMuted,
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Icon(
                      icon,
                      size: AppMetrics.iconSm,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );

  Widget _sendAction({
    required String label,
    required IconData icon,
    required VoidCallback? action,
  }) => SizedBox.square(
    dimension: AppMetrics.touchTargetMin,
    child: Tooltip(
      message: label,
      child: Semantics(
        label: label,
        button: true,
        enabled: action != null,
        child: Material(
          color: Colors.transparent,
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: action,
            child: Center(
              child: Container(
                width: _toolbarVisualSize,
                height: _toolbarVisualSize,
                decoration: BoxDecoration(
                  color: action == null
                      ? AppColors.disabled
                      : AppColors.primary,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Icon(
                  icon,
                  size: AppMetrics.iconSm,
                  color: action == null
                      ? AppColors.onDisabled
                      : AppColors.onPrimary,
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );

  Widget _icon(String label, IconData icon, VoidCallback? action) => IconButton(
    tooltip: label,
    onPressed: action,
    iconSize: AppMetrics.iconSm,
    constraints: const BoxConstraints.tightFor(
      width: AppMetrics.touchTargetMin,
      height: AppMetrics.touchTargetMin,
    ),
    padding: EdgeInsets.zero,
    icon: Icon(icon),
  );
}

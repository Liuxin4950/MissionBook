part of 'records_page.dart';

class RecordEditor extends StatefulWidget {
  const RecordEditor({
    super.key,
    this.capture = false,
    this.goalId,
    this.nodeId,
    this.missionId,
  });
  final bool capture;
  final String? goalId, nodeId, missionId;
  @override
  State<RecordEditor> createState() => _RecordEditorState();
}

class _RecordEditorState extends State<RecordEditor> {
  final _text = TextEditingController();
  final _id = const Uuid().v4();
  EvidenceDraft? _attachment;
  Future<Uint8List>? _attachmentImage;
  String? _goal, _node, _mission, _association;
  bool _camera = false, _busy = false, _initialized = false, _saved = false;
  bool _allowPop = false;
  EvidenceType _type = EvidenceType.text;
  String? _error;
  late RecordService service;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      _initialized = true;
      service = RecordScope.maybeOf(context)!.service;
      _goal = widget.goalId;
      _node = widget.nodeId;
      _mission = widget.missionId;
      if (widget.capture &&
          !kIsWeb &&
          defaultTargetPlatform == TargetPlatform.android) {
        _camera = true;
      } else if (widget.capture) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _photo());
      }
    }
  }

  Future<void> _photo() async {
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      setState(() => _camera = true);
      return;
    }
    await _pick();
  }

  Future<void> _pick({bool file = false}) async {
    setState(() => _busy = true);
    try {
      await service.missions.initializeEvidenceImages();
      final draft = file
          ? await service.missions.pickEvidenceFile(_id)
          : await service.missions.pickEvidenceImage(_id);
      if (draft != null) {
        final old = _attachment;
        setState(() => _setAttachment(draft));
        if (old != null) await service.missions.discardEvidenceDrafts([old]);
      }
    } catch (e) {
      setState(() => _error = userErrorMessage(e, fallback: '记录未保存，请检查输入后重试'));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _capture(Uint8List bytes, DateTime at) async {
    setState(() => _busy = true);
    try {
      await service.missions.initializeEvidenceImages();
      final draft = await service.missions.prepareEvidenceCameraImage(
        _id,
        bytes,
        capturedAt: at,
      );
      final old = _attachment;
      if (mounted) {
        setState(() {
          _setAttachment(draft);
          _camera = false;
        });
      }
      if (old != null) await service.missions.discardEvidenceDrafts([old]);
    } catch (e) {
      if (mounted) {
        setState(
          () => _error = userErrorMessage(e, fallback: '记录未保存，请检查输入后重试'),
        );
      }
      rethrow;
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _save() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final draft =
          _attachment?.copyWithContent(
            _text.text.trim().isEmpty ? null : _text.text.trim(),
          ) ??
          EvidenceDraft(
            id: _id,
            type: _type,
            source: EvidenceSource.user,
            content: _text.text.trim(),
          );
      await service.save(
        draft,
        goalId: _goal,
        nodeId: _node,
        missionId: _mission,
      );
      setState(() {
        _saved = true;
        _allowPop = true;
        _busy = false;
      });
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        setState(
          () => _error = userErrorMessage(e, fallback: '记录未保存，请检查输入后重试'),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String get _contentLabel {
    final attachment = _attachment;
    if (attachment != null) {
      return attachment.type == EvidenceType.image ? '照片说明（选填）' : '文件说明（选填）';
    }
    return switch (_type) {
      EvidenceType.code => '代码内容',
      EvidenceType.manualRecord => '手动记录内容',
      _ => '内容或照片说明',
    };
  }

  String get _contentHint {
    final attachment = _attachment;
    if (attachment != null) {
      return attachment.type == EvidenceType.image
          ? '为这张照片补充说明（选填）'
          : '为这个文件补充说明（选填）';
    }
    return switch (_type) {
      EvidenceType.code => '粘贴代码或说明',
      EvidenceType.manualRecord => '写下这次手动记录的内容',
      _ => '例如：今天的午餐、学习笔记、训练记录',
    };
  }

  void _setAttachment(EvidenceDraft? draft) {
    _attachment = draft;
    _attachmentImage =
        draft != null &&
            draft.type == EvidenceType.image &&
            draft.attachmentStorageKey != null
        ? service.missions.readEvidenceImage(draft.attachmentStorageKey!)
        : null;
  }

  Future<void> _removeAttachment() async {
    final attachment = _attachment;
    if (attachment == null || _busy) return;
    setState(() => _setAttachment(null));
    try {
      await service.missions.discardEvidenceDrafts([attachment]);
    } catch (error) {
      if (mounted) {
        setState(() {
          _setAttachment(attachment);
          _error = userErrorMessage(error, fallback: '移除附件失败，请重试');
        });
      }
    }
  }

  Widget _pickerRow() => AdaptiveColumns(
    minColumnWidth: 210,
    maxColumns: 2,
    spacing: AppLayout.spaceMd,
    children: [
      SizedBox(
        width: double.infinity,
        height: AppLayout.touchTargetMin,
        child: FilledButton.tonalIcon(
          key: const Key('record-pick-photo'),
          onPressed: _busy ? null : _photo,
          icon: const Icon(Icons.photo_camera_outlined),
          label: const Text('拍照 / 选图'),
        ),
      ),
      SizedBox(
        width: double.infinity,
        height: AppLayout.touchTargetMin,
        child: OutlinedButton.icon(
          key: const Key('record-pick-file'),
          onPressed: _busy ? null : () => _pick(file: true),
          icon: const Icon(Icons.attach_file),
          label: const Text('选择文件'),
        ),
      ),
    ],
  );

  Widget _typeSelector(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text('记录类型', style: Theme.of(context).textTheme.titleSmall),
      const SizedBox(height: AppLayout.spaceSm),
      IgnorePointer(
        ignoring: _busy,
        child: AppSegmentedControl<EvidenceType>(
          options: const {
            EvidenceType.text: '文字',
            EvidenceType.code: '代码',
            EvidenceType.manualRecord: '手动',
          },
          selected: _type,
          onSelected: (value) => setState(() => _type = value),
        ),
      ),
    ],
  );

  Widget _attachmentSection(BuildContext context) {
    final attachment = _attachment!;
    final theme = Theme.of(context);
    final image = attachment.type == EvidenceType.image;
    final name = attachment.attachmentFileName ?? '附件';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Icon(
              image ? Icons.image_outlined : Icons.description_outlined,
              size: AppLayout.iconMd,
              color: AppColors.textSecondary,
            ),
            const SizedBox(width: AppLayout.spaceMd),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleMedium,
                  ),
                  Text(
                    image ? '照片附件' : '文件附件',
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ],
        ),
        if (image) ...[
          const SizedBox(height: AppLayout.spaceMd),
          EvidenceImageLoader(
            future: _attachmentImage,
            name: name,
            height: 220,
            previewKey: const Key('record-attachment-preview'),
            onRetry: () => setState(() {
              _attachmentImage = RecordScope.maybeOf(context)!.service.missions
                  .readEvidenceImage(attachment.attachmentStorageKey!);
            }),
          ),
        ],
        const SizedBox(height: AppLayout.spaceSm),
        Row(
          children: [
            TextButton.icon(
              onPressed: _busy
                  ? null
                  : (image ? _photo : () => _pick(file: true)),
              style: TextButton.styleFrom(
                minimumSize: const Size(0, AppLayout.touchTargetMin),
              ),
              icon: const Icon(Icons.refresh, size: AppLayout.iconSm),
              label: Text(image ? '更换照片' : '更换文件'),
            ),
            const Spacer(),
            TextButton.icon(
              onPressed: _busy ? null : () => unawaited(_removeAttachment()),
              style: TextButton.styleFrom(
                minimumSize: const Size(0, AppLayout.touchTargetMin),
              ),
              icon: const Icon(Icons.delete_outline, size: AppLayout.iconSm),
              label: const Text('移除'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _associationRow(BuildContext context) {
    final theme = Theme.of(context);
    final enabled = !_busy && widget.missionId == null;
    final label =
        _association ??
        (_mission != null
            ? '保存为此任务的材料'
            : _node != null
            ? '关联当前节点'
            : _goal != null
            ? '关联当前目标'
            : '独立记录 · 可选择目标、节点或任务');
    return Material(
      color: enabled ? AppColors.surfaceMuted : AppColors.disabled,
      borderRadius: BorderRadius.circular(AppLayout.radiusLg),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: enabled
            ? () async {
                final result = await chooseRecordAssociation(context);
                if (result != null && mounted) {
                  setState(() {
                    _goal = result['goal'];
                    _node = result['node'];
                    _mission = result['mission'];
                    _association = result['title'];
                  });
                }
              }
            : null,
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            minHeight: AppLayout.touchTargetMin,
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppLayout.spaceLg,
              vertical: AppLayout.spaceMd,
            ),
            child: Row(
              children: [
                Icon(
                  Icons.link,
                  size: AppLayout.iconMd,
                  color: enabled
                      ? AppColors.textSecondary
                      : AppColors.onDisabled,
                ),
                const SizedBox(width: AppLayout.spaceMd),
                Expanded(
                  child: Text(
                    label,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: enabled
                          ? AppColors.textPrimary
                          : AppColors.onDisabled,
                    ),
                  ),
                ),
                if (enabled)
                  const Icon(
                    Icons.chevron_right,
                    size: AppLayout.iconMd,
                    color: AppColors.textSecondary,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    if (!_saved && _attachment != null) {
      unawaited(service.missions.discardEvidenceDrafts([_attachment!]));
    }
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop:
        !_busy && (_allowPop || (_attachment == null && _text.text.isEmpty)),
    onPopInvokedWithResult: (didPop, _) async {
      if (didPop || _busy) return;
      final discard = await AppConfirmDialog.show(
        context: context,
        title: '丢弃未保存的记录？',
        message: '照片和文字尚未保存。',
        cancelText: '继续编辑',
        confirmText: '丢弃',
      );
      if (discard && context.mounted) {
        setState(() => _allowPop = true);
        Navigator.pop(context);
      }
    },
    child: Scaffold(
      appBar: _camera ? null : AppTopBar(title: '添加记录', canGoBack: !_busy),
      body: _camera
          ? EvidenceCameraPanel(
              fullScreen: true,
              missionTitle: '随手记录',
              onConfirmed: _capture,
              onBack: () {
                if (widget.capture &&
                    _attachment == null &&
                    _text.text.isEmpty) {
                  Navigator.of(context).maybePop();
                } else {
                  setState(() => _camera = false);
                }
              },
              onChooseFile: () {
                setState(() => _camera = false);
                _pick();
              },
              onCancel: () => setState(() => _camera = false),
            )
          : SafeArea(
              top: false,
              child: SingleChildScrollView(
                padding: AppLayout.pagePadding(context),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      maxWidth: AppLayout.maxPageWidth,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        AppSectionCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              if (_attachment != null)
                                _attachmentSection(context)
                              else ...[
                                _pickerRow(),
                                const SizedBox(height: AppLayout.spaceLg),
                                _typeSelector(context),
                              ],
                              const SizedBox(height: AppLayout.spaceLg),
                              AppTextField(
                                key: const Key('record-content-input'),
                                label: _contentLabel,
                                hint: _contentHint,
                                controller: _text,
                                minLines: 4,
                                maxLines: 12,
                                readOnly: _busy,
                                onChanged: (_) => setState(() {}),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: AppLayout.spaceXl),
                        _associationRow(context),
                        if (_error != null) ...[
                          const SizedBox(height: AppLayout.spaceMd),
                          Container(
                            padding: const EdgeInsets.all(AppLayout.spaceMd),
                            decoration: BoxDecoration(
                              color: AppColors.errorSoft,
                              borderRadius: BorderRadius.circular(
                                AppLayout.radiusMd,
                              ),
                            ),
                            child: Text(
                              _error!,
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(color: AppColors.error),
                            ),
                          ),
                        ],
                        const SizedBox(height: AppLayout.spaceXl),
                        FilledButton(
                          onPressed: _busy ? null : _save,
                          style: FilledButton.styleFrom(
                            minimumSize: const Size.fromHeight(
                              AppLayout.actionMinHeight,
                            ),
                          ),
                          child: Text(_busy ? '正在保存…' : '保存记录'),
                        ),
                        const SizedBox(height: AppLayout.spaceXl),
                      ],
                    ),
                  ),
                ),
              ),
            ),
    ),
  );
}

Future<Map<String, String>?> chooseRecordAssociation(BuildContext context) =>
    showDialog<Map<String, String>>(
      context: context,
      builder: (_) => const _AssociationDialog(),
    );

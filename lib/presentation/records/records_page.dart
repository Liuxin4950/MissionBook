import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../../application/records/record_service.dart';
import '../../core/theme/app_layout.dart';
import '../../core/theme/colors.dart';
import '../../domain/entities/evidence.dart';
import '../missions/evidence/evidence_camera_panel.dart';
import '../missions/evidence/evidence_image_preview.dart';
import '../widgets/adaptive_columns.dart';
import '../widgets/app_confirm_dialog.dart';
import '../widgets/app_dropdown_form_field.dart';
import '../widgets/app_section_card.dart';
import '../widgets/app_segmented_control.dart';
import '../widgets/app_text_field.dart';
import '../widgets/app_top_bar.dart';
import 'record_scope.dart';

/// 各页面共用同一记录列表、编辑器和关联选择器。
class RecordsPage extends StatefulWidget {
  const RecordsPage({
    super.key,
    this.goalId,
    this.nodeId,
    this.missionId,
    this.date,
    this.capture = false,
  });
  final String? goalId, nodeId, missionId, date;
  final bool capture;
  @override
  State<RecordsPage> createState() => _RecordsPageState();
}

class _RecordsPageState extends State<RecordsPage> {
  Future<Map<String, Object?>>? _data;
  StreamSubscription<void>? _changes;
  int _offset = 0;
  bool _initialized = false;
  RecordService get service => RecordScope.maybeOf(context)!.service;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      _initialized = true;
      _load();
      _changes = service.missions.changes.listen((_) {
        if (mounted) _load();
      });
      if (widget.capture) {
        WidgetsBinding.instance.addPostFrameCallback(
          (_) => _create(capture: true),
        );
      }
    }
  }

  void _load() {
    setState(() {
      _data = service.repository.queryRecords(
        goalId: widget.goalId,
        nodeId: widget.nodeId,
        missionId: widget.missionId,
        date: widget.date,
        offset: _offset,
      );
    });
  }

  Future<void> _create({bool capture = false}) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => RecordEditor(
          capture: capture,
          goalId: widget.goalId,
          nodeId: widget.nodeId,
          missionId: widget.missionId,
        ),
      ),
    );
    if (mounted) _load();
  }

  Future<void> _delete(Map<String, Object?> item) async {
    if (item['mission_id'] != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('已作为任务材料的记录不能删除，请在任务材料中追加修正')),
      );
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('删除这条记录？'),
        content: const Text('删除后将无法在记录中查看。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await service.delete(item['id'] as String);
      if (mounted) {
        if (_offset > 0) {
          _offset = 0;
        }
        _load();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('删除失败：$e')));
      }
    }
  }

  @override
  void dispose() {
    _changes?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppTopBar(
      title: '记录',
      actions: [
        IconButton(
          tooltip: '拍照记录',
          onPressed: () => _create(capture: true),
          icon: const Icon(Icons.photo_camera_outlined),
        ),
        IconButton(
          tooltip: '添加记录',
          onPressed: _create,
          icon: const Icon(Icons.add),
        ),
      ],
    ),
    body: FutureBuilder<Map<String, Object?>>(
      future: _data,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('记录读取失败：${snapshot.error}'));
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final data = snapshot.data!;
        final items = data['items'] as List<Map<String, Object?>>;
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (items.isEmpty)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Text('还没有记录，可以拍照或写下文字。'),
              ),
            for (final item in items)
              _SwipeRecord(
                key: ValueKey<String>(item['id'] as String),
                onDelete: () => _delete(item),
                child: Card(
                  child: ListTile(
                    leading: item['type'] == 'IMAGE'
                        ? FutureBuilder<Uint8List>(
                            future: service.missions.readEvidenceImage(
                              item['attachment_storage_key'] as String,
                            ),
                            builder: (c, s) => s.hasData
                                ? Image.memory(
                                    s.data!,
                                    width: 64,
                                    height: 64,
                                    fit: BoxFit.cover,
                                  )
                                : const Icon(Icons.image_outlined),
                          )
                        : const Icon(Icons.notes),
                    title: Text(
                      (item['content'] as String?)?.isNotEmpty == true
                          ? item['content'] as String
                          : item['attachment_file_name'] as String? ?? '记录',
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      '${DateTime.fromMillisecondsSinceEpoch(item['occurred_at'] as int).toLocal()}\n${_analysisLabel(item['analysis'])}',
                    ),
                    onTap: () => Navigator.of(context).push<void>(
                      MaterialPageRoute(
                        builder: (_) => RecordDetail(id: item['id'] as String),
                      ),
                    ),
                  ),
                ),
              ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton(
                  onPressed: _offset == 0
                      ? null
                      : () {
                          _offset = (_offset - 20).clamp(0, 1 << 30);
                          _load();
                        },
                  child: const Text('上一页'),
                ),
                Text('共 ${data['total']} 条'),
                TextButton(
                  onPressed: data['nextOffset'] == null
                      ? null
                      : () {
                          _offset = data['nextOffset'] as int;
                          _load();
                        },
                  child: const Text('下一页'),
                ),
              ],
            ),
          ],
        );
      },
    ),
  );
}

/// 左滑露出删除操作，点击后再确认。
class _SwipeRecord extends StatefulWidget {
  const _SwipeRecord({super.key, required this.child, required this.onDelete});
  final Widget child;
  final VoidCallback onDelete;
  @override
  State<_SwipeRecord> createState() => _SwipeRecordState();
}

class _SwipeRecordState extends State<_SwipeRecord> {
  double _offset = 0;
  @override
  Widget build(BuildContext context) => ClipRect(
    child: Stack(
      children: [
        Positioned.fill(
          child: Align(
            alignment: Alignment.centerRight,
            child: SizedBox(
              width: 80,
              height: double.infinity,
              child: TextButton(
                onPressed: widget.onDelete,
                style: TextButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.errorContainer,
                  padding: EdgeInsets.zero,
                ),
                child: const Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [Icon(Icons.delete_outline), Text('删除')],
                ),
              ),
            ),
          ),
        ),
        GestureDetector(
          onHorizontalDragUpdate: (d) =>
              setState(() => _offset = (_offset + d.delta.dx).clamp(-80, 0)),
          onHorizontalDragEnd: (_) =>
              setState(() => _offset = _offset < -35 ? -80 : 0),
          child: Transform.translate(
            offset: Offset(_offset, 0),
            child: widget.child,
          ),
        ),
      ],
    ),
  );
}

String _analysisLabel(Object? value) {
  final a = value as Map<String, Object?>?;
  return switch (a?['state']) {
    'ready' => a?['stale'] == true ? '摘要待更新' : '已生成内容摘要',
    'failed' => '分析失败，可重试',
    'blocked' => '分析需配置模型能力',
    'running' => '正在分析',
    'pending' => '待分析',
    _ => '尚未分析',
  };
}

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
      setState(() => _error = '$e');
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
      if (mounted) setState(() => _error = '$e');
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
      if (mounted) setState(() => _error = '$e');
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
          _error = '移除附件失败：$error';
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
          FutureBuilder<Uint8List>(
            future: _attachmentImage,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Container(
                  padding: const EdgeInsets.all(AppLayout.spaceMd),
                  decoration: BoxDecoration(
                    color: AppColors.errorSoft,
                    borderRadius: BorderRadius.circular(AppLayout.radiusMd),
                  ),
                  child: Text(
                    '照片读取失败，请移除后重新选择。',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: AppColors.error,
                    ),
                  ),
                );
              }
              if (!snapshot.hasData) {
                return const SizedBox(
                  height: 220,
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              return EvidenceImagePreview(
                key: const Key('record-attachment-preview'),
                bytes: snapshot.data!,
                name: name,
                height: 220,
              );
            },
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

class _AssociationDialog extends StatefulWidget {
  const _AssociationDialog();
  @override
  State<_AssociationDialog> createState() => _AssociationDialogState();
}

class _AssociationDialogState extends State<_AssociationDialog> {
  String _kind = 'mission', _search = '';
  int _offset = 0;
  Future<Map<String, Object?>>? _data;
  void load() {
    setState(() {
      _data = RecordScope.maybeOf(context)!.service.repository
          .associationChoices(_kind, search: _search, offset: _offset);
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _data ??= RecordScope.maybeOf(
      context,
    )!.service.repository.associationChoices(_kind);
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    backgroundColor: Theme.of(context).colorScheme.surfaceContainerLow,
    surfaceTintColor: Colors.transparent,
    insetPadding: const EdgeInsets.all(AppLayout.spaceXxl),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppLayout.radiusXxl),
    ),
    title: const Text('关联到'),
    content: SizedBox(
      width: 440,
      height: 440,
      child: Column(
        children: [
          AppDropdownFormField<String>(
            initialValue: _kind,
            decoration: const InputDecoration(labelText: '关联类型'),
            items: const [
              DropdownMenuItem(value: 'goal', child: Text('目标')),
              DropdownMenuItem(value: 'node', child: Text('目标节点')),
              DropdownMenuItem(value: 'mission', child: Text('任务材料')),
            ],
            onChanged: (v) {
              _kind = v!;
              _offset = 0;
              load();
            },
          ),
          const SizedBox(height: AppLayout.spaceMd),
          TextField(
            style: Theme.of(context).textTheme.bodyLarge,
            decoration: const InputDecoration(labelText: '搜索名称'),
            onChanged: (v) {
              _search = v;
              _offset = 0;
              load();
            },
          ),
          Expanded(
            child: FutureBuilder<Map<String, Object?>>(
              future: _data,
              builder: (c, s) {
                if (s.hasError) return Text('读取失败：${s.error}');
                if (!s.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final d = s.data!;
                return ListView(
                  children: [
                    for (final e in d['items'] as List<Map<String, Object?>>)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(e['title'] as String),
                        subtitle: Text(e['id'] as String),
                        onTap: () => Navigator.pop(context, {
                          _kind: e['id'] as String,
                          'title': e['title'] as String,
                        }),
                      ),
                    Row(
                      children: [
                        TextButton(
                          onPressed: _offset == 0
                              ? null
                              : () {
                                  _offset -= 20;
                                  load();
                                },
                          child: const Text('上一页'),
                        ),
                        TextButton(
                          onPressed: d['nextOffset'] == null
                              ? null
                              : () {
                                  _offset = d['nextOffset'] as int;
                                  load();
                                },
                          child: const Text('下一页'),
                        ),
                      ],
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context, <String, String>{}),
        child: const Text('独立记录'),
      ),
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('取消'),
      ),
    ],
  );
}

class RecordDetail extends StatefulWidget {
  const RecordDetail({super.key, required this.id});
  final String id;
  @override
  State<RecordDetail> createState() => _RecordDetailState();
}

class _RecordDetailState extends State<RecordDetail> {
  Future<Map<String, Object?>>? _data;
  int _contentOffset = 0;
  void load() => setState(() {
    _data = RecordScope.maybeOf(context)!.service.repository.queryRecords(
      id: widget.id,
      content: true,
      contentOffset: _contentOffset,
    );
  });
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_data == null) load();
  }

  @override
  Widget build(BuildContext context) {
    final scope = RecordScope.maybeOf(context)!;
    return Scaffold(
      appBar: const AppTopBar(title: '记录详情'),
      body: FutureBuilder<Map<String, Object?>>(
        future: _data,
        builder: (c, s) {
          if (s.hasError) return Center(child: Text('读取失败：${s.error}'));
          if (!s.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final r = (s.data!['items'] as List<Map<String, Object?>>).first;
          final a = r['analysis'] as Map<String, Object?>;
          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              if (r['type'] == 'IMAGE')
                FutureBuilder<Uint8List>(
                  future: scope.service.missions.readEvidenceImage(
                    r['attachment_storage_key'] as String,
                  ),
                  builder: (c, i) => i.hasData
                      ? Image.memory(i.data!)
                      : Text(i.hasError ? '图片读取失败' : '正在读取图片…'),
                ),
              SelectableText(r['content'] as String? ?? ''),
              Wrap(
                children: [
                  if (_contentOffset > 0)
                    TextButton(
                      onPressed: () {
                        _contentOffset = (_contentOffset - 6000).clamp(
                          0,
                          1 << 30,
                        );
                        load();
                      },
                      child: const Text('上一段'),
                    ),
                  if (r['nextContentOffset'] != null)
                    TextButton(
                      onPressed: () {
                        _contentOffset = r['nextContentOffset'] as int;
                        load();
                      },
                      child: const Text('下一段'),
                    ),
                ],
              ),
              if (r['mission_id'] == null &&
                  r['contentTruncated'] != true &&
                  _contentOffset == 0)
                TextButton(
                  onPressed: () async {
                    final input = TextEditingController(
                      text: r['content'] as String? ?? '',
                    );
                    final route = DialogRoute<String>(
                      context: context,
                      builder: (c) => AlertDialog(
                        title: const Text('修改记录文字'),
                        content: TextField(
                          controller: input,
                          minLines: 3,
                          maxLines: 10,
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(c),
                            child: const Text('取消'),
                          ),
                          FilledButton(
                            onPressed: () => Navigator.pop(c, input.text),
                            child: const Text('保存'),
                          ),
                        ],
                      ),
                    );
                    final result = await Navigator.of(
                      context,
                    ).push<String>(route);
                    await route.completed;
                    input.dispose();
                    if (result != null) {
                      try {
                        await scope.service.updateContent(
                          widget.id,
                          r['content'] as String?,
                          result,
                        );
                        load();
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(
                            context,
                          ).showSnackBar(SnackBar(content: Text('$e')));
                        }
                      }
                    }
                  },
                  child: const Text('修改文字 / 说明'),
                ),
              Text(
                '发生：${DateTime.fromMillisecondsSinceEpoch(r['occurred_at'] as int).toLocal()}',
              ),
              Text(
                '保存：${DateTime.fromMillisecondsSinceEpoch(r['created_at'] as int).toLocal()}',
              ),
              Text(
                r['mission_id'] == null ? '可补关联到目标、节点或任务' : '已成为任务正式材料，原引用保留',
              ),
              if (r['mission_id'] == null)
                TextButton(
                  onPressed: () async {
                    final choice = await chooseRecordAssociation(context);
                    if (choice != null) {
                      try {
                        await scope.service.link(
                          widget.id,
                          goalId: choice['goal'],
                          nodeId: choice['node'],
                          missionId: choice['mission'],
                        );
                        load();
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(
                            context,
                          ).showSnackBar(SnackBar(content: Text('$e')));
                        }
                      }
                    }
                  },
                  child: const Text('补关联'),
                ),
              const Divider(),
              Text(_analysisLabel(a)),
              if (a['content'] != null) SelectableText(a['content'] as String),
              if (a['error'] != null) Text(a['error'] as String),
              TextButton(
                onPressed: () async {
                  await scope.analysis.store.retry('record', widget.id);
                  scope.analysis.wake();
                  load();
                },
                child: const Text('生成 / 重试摘要'),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// 小型入口复用于今天、历史、目标与节点；点击后进入同一列表。
class RecordsEntry extends StatelessWidget {
  const RecordsEntry({
    super.key,
    this.goalId,
    this.nodeId,
    this.missionId,
    this.date,
    this.label = '查看记录',
    this.iconOnly = false,
  });
  final String? goalId, nodeId, missionId, date;
  final String label;
  final bool iconOnly; // 主导航页顶栏只保留图标，名称由 Tooltip 与读屏提供。
  @override
  Widget build(BuildContext context) {
    if (RecordScope.maybeOf(context) == null) return const SizedBox.shrink();
    void open() => Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => RecordsPage(
          goalId: goalId,
          nodeId: nodeId,
          missionId: missionId,
          date: date,
        ),
      ),
    );
    if (iconOnly) {
      return IconButton(
        onPressed: open,
        tooltip: label,
        icon: const Icon(Icons.photo_library_outlined),
      );
    }
    return TextButton.icon(
      onPressed: open,
      icon: const Icon(Icons.photo_library_outlined),
      label: Text(label),
    );
  }
}

/// 今天页展示真实当日记录缩略图，仍复用同一记录详情和列表。
class DailyRecordsStrip extends StatefulWidget {
  const DailyRecordsStrip({super.key, required this.date});
  final String date;
  @override
  State<DailyRecordsStrip> createState() => _DailyRecordsStripState();
}

class _DailyRecordsStripState extends State<DailyRecordsStrip> {
  Future<Map<String, Object?>>? _data;
  StreamSubscription<void>? _changes;
  void load() {
    if (mounted) {
      setState(() {
        _data = RecordScope.maybeOf(
          context,
        )?.service.repository.queryRecords(date: widget.date);
      });
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_data == null) {
      load();
      _changes ??= RecordScope.maybeOf(
        context,
      )?.service.missions.changes.listen((_) => load());
    }
  }

  @override
  void didUpdateWidget(DailyRecordsStrip old) {
    super.didUpdateWidget(old);
    if (old.date != widget.date) load();
  }

  @override
  void dispose() {
    _changes?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scope = RecordScope.maybeOf(context);
    if (scope == null) return const SizedBox.shrink();
    return FutureBuilder<Map<String, Object?>>(
      future: _data,
      builder: (c, s) {
        final items = s.data?['items'] as List<Map<String, Object?>>? ?? [];
        final total = s.data?['total'] as int? ?? 0;
        // 没有记录时不占位置，也不显示一个空入口。
        if (!s.hasData || s.hasError || total == 0) {
          return const SizedBox.shrink();
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            RecordsEntry(
              date: widget.date,
              label: '当日记录 · ${s.data?['total'] ?? 0} 条',
            ),
            if (s.hasError) const Text('记录读取失败，点击入口重试'),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final r in items.take(3))
                  InkWell(
                    onTap: () => Navigator.of(context).push<void>(
                      MaterialPageRoute(
                        builder: (_) => RecordDetail(id: r['id'] as String),
                      ),
                    ),
                    child: SizedBox(
                      width: 120,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (r['type'] == 'IMAGE')
                            FutureBuilder<Uint8List>(
                              future: scope.service.missions.readEvidenceImage(
                                r['attachment_storage_key'] as String,
                              ),
                              builder: (c, i) => i.hasData
                                  ? Image.memory(
                                      i.data!,
                                      height: 80,
                                      width: 120,
                                      fit: BoxFit.cover,
                                    )
                                  : const SizedBox(
                                      height: 80,
                                      child: Icon(Icons.image_outlined),
                                    ),
                            ),
                          Text(
                            r['content'] as String? ??
                                r['attachment_file_name'] as String? ??
                                '记录',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ],
        );
      },
    );
  }
}

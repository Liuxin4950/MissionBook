import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../../application/missions/mission_service.dart';
import '../../../core/theme/colors.dart';
import '../../../domain/entities/evidence.dart';
import '../../../domain/entities/mission_detail.dart';
import '../../widgets/app_confirm_dialog.dart';
import '../../widgets/app_expansion.dart';
import '../shared/mission_execution_display.dart';
import 'evidence_image_preview.dart';
import '../../../core/theme/app_layout.dart';

String evidenceTypeLabel(EvidenceType type) => switch (type) {
  EvidenceType.text => '文字记录',
  EvidenceType.code => '代码',
  EvidenceType.image => '图片',
  EvidenceType.file => '文件',
  EvidenceType.manualRecord => '手动记录',
};

/// 正式材料的当前有效项、完整修正历史与单条留痕修正。
class FormalEvidenceSection extends StatefulWidget {
  const FormalEvidenceSection({
    super.key,
    required this.detail,
    required this.service,
    this.compact = false,
    this.onChanged,
  });

  final MissionDetail detail;
  final MissionService service;
  final bool compact;
  final VoidCallback? onChanged;

  @override
  State<FormalEvidenceSection> createState() => FormalEvidenceSectionState();
}

class FormalEvidenceSectionState extends State<FormalEvidenceSection>
    with AutomaticKeepAliveClientMixin<FormalEvidenceSection> {
  late MissionDetail _detail;
  final _images = <String, Future<Uint8List>>{};
  Evidence? _original;
  EvidenceDraft? _draft;
  TextEditingController? _content;
  EvidenceCorrection? _pending;
  bool _busy = false;
  bool _confirming = false;
  bool _allowPop = false;
  bool _attachmentsReady = false;
  String? _attachmentError;
  String? _error;
  String? _receipt;

  bool get hasDraft => _draft != null || _pending != null;
  @override
  bool get wantKeepAlive => hasDraft || _busy;

  @override
  void setState(VoidCallback fn) {
    super.setState(fn);
    updateKeepAlive();
  }

  @override
  void initState() {
    super.initState();
    _detail = widget.detail;
    if (_detail.effectiveEvidence.any(
      (item) => item.attachmentStorageKey != null,
    )) {
      unawaited(_prepareAttachments());
    }
  }

  @override
  void didUpdateWidget(covariant FormalEvidenceSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.detail.evidence.length >= _detail.evidence.length) {
      _detail = widget.detail;
    }
  }

  Future<void> _prepareAttachments() async {
    try {
      await widget.service.initializeEvidenceImages();
      if (mounted) setState(() => _attachmentsReady = true);
    } catch (error) {
      if (mounted) setState(() => _attachmentError = '附件准备失败：$error');
    }
  }

  void _clearDraft() {
    _content?.dispose();
    _content = null;
    _original = null;
    _draft = null;
    _pending = null;
  }

  Future<bool> prepareToLeave() => _confirmDiscard();

  Future<bool> _confirmDiscard() async {
    if (_busy || _confirming) return false;
    if (!hasDraft) return true;
    if (_pending != null) {
      await _readLatest();
      if (!mounted || _pending != null) return false;
      if (!hasDraft) return true;
    }
    _confirming = true;
    final accepted = await AppConfirmDialog.show(
      context: context,
      title: '丢弃材料修正草稿？',
      message: '原正式材料及其他执行记录会保留。',
      cancelText: '继续修改',
      confirmText: '丢弃草稿',
    );
    _confirming = false;
    if (!mounted || !accepted) return false;
    try {
      await widget.service.discardEvidenceDrafts([_draft!]);
      if (!mounted) return false;
      setState(_clearDraft);
      return true;
    } catch (error) {
      if (mounted) setState(() => _error = '草稿清理失败：$error');
      return false;
    }
  }

  Future<void> _begin(Evidence original) async {
    if (_busy || (_draft != null && !await _confirmDiscard()) || !mounted) {
      return;
    }
    if (original.attachmentStorageKey == null) {
      final draft = widget.service.createTextEvidence(
        original.content ?? '',
        type: original.type,
        supersedesEvidenceId: original.id,
      );
      setState(() {
        _original = original;
        _draft = draft;
        _content = TextEditingController(text: draft.content);
        _error = null;
      });
      return;
    }
    if (!_attachmentsReady) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final picked = original.type == EvidenceType.image
          ? await widget.service.pickEvidenceImage(
              _detail.mission.id,
              supersedesEvidenceId: original.id,
            )
          : await widget.service.pickEvidenceFile(
              _detail.mission.id,
              supersedesEvidenceId: original.id,
            );
      if (!mounted) {
        if (picked != null) {
          await widget.service.discardEvidenceDrafts([picked]);
        }
        return;
      }
      if (picked != null) {
        final draft = picked.copyWithContent(original.content);
        setState(() {
          _original = original;
          _draft = draft;
          _content = TextEditingController(text: draft.content);
        });
      }
    } catch (error) {
      if (mounted) setState(() => _error = '选择替代附件失败：$error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _save() async {
    if (_busy || _draft == null || _original == null) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      _pending ??= widget.service.prepareEvidenceCorrection(
        detail: _detail,
        original: _original!,
        draft: _draft!.copyWithContent(
          _draft!.attachmentStorageKey != null &&
                  (_content?.text.trim().isEmpty ?? true)
              ? null
              : _content?.text,
        ),
      );
      await widget.service.correctEvidence(_pending!);
      if (!mounted) return;
      setState(() {
        _clearDraft();
        _receipt = '修正已保存，原材料仍可在修正历史查看。';
      });
      await _readLatest();
    } on ArgumentError catch (error) {
      _pending = null;
      if (mounted) setState(() => _error = '${error.message}');
    } on EvidenceConflict catch (error) {
      _pending = null;
      if (mounted) setState(() => _error = error.message);
      await _readLatest(clearError: false);
    } catch (error, stack) {
      debugPrint('材料修正结果未确认：$error\n$stack');
      if (mounted) {
        setState(() => _error = '保存结果未确认，草稿已保留。请重试本次修正或读取最新记录。');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _readLatest({bool clearError = true}) async {
    try {
      final latest = await widget.service.findDetail(
        missionId: _detail.mission.id,
      );
      if (!mounted || latest == null) return;
      final saved =
          _pending != null &&
          latest.evidence.any((item) => item.id == _pending!.item.id);
      setState(() {
        _detail = latest;
        if (saved) {
          _clearDraft();
          _receipt = '已确认本次修正保存成功。';
        } else {
          _pending = null;
        }
        if (clearError) _error = null;
      });
      widget.onChanged?.call();
    } catch (_) {
      if (mounted) setState(() => _error = '最新材料读取失败，请重试；输入已保留。');
    }
  }

  Future<void> _leave() async {
    if (!await _confirmDiscard() || !mounted) return;
    setState(() => _allowPop = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && Navigator.of(context).canPop()) {
        Navigator.of(context).maybePop();
      }
    });
  }

  Widget _image(String key, String name) {
    final future = _images.putIfAbsent(
      key,
      () => widget.service.readEvidenceImage(key),
    );
    return FutureBuilder<Uint8List>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.hasError) return Text('图片无法读取：$name');
        if (!snapshot.hasData) return const LinearProgressIndicator();
        return EvidenceImagePreview(
          bytes: snapshot.data!,
          name: name,
          height: widget.compact ? 120 : 148,
        );
      },
    );
  }

  Widget _file(Evidence item) {
    final key = item.attachmentStorageKey!;
    final future = _images.putIfAbsent(
      key,
      () => widget.service.readEvidenceImage(key),
    );
    return FutureBuilder<Uint8List>(
      future: future,
      builder: (context, snapshot) => ListTile(
        contentPadding: EdgeInsets.zero,
        leading: const Icon(Icons.description_outlined),
        title: Text(item.attachmentFileName ?? '文件材料'),
        subtitle: Text(
          snapshot.hasError
              ? '文件无法读取，正式记录仍保留'
              : snapshot.hasData
              ? '${(snapshot.data!.length / 1024).toStringAsFixed(1)} KiB · 已保存在应用内'
              : '读取文件中',
        ),
      ),
    );
  }

  Widget _item(BuildContext context, Evidence item) {
    final theme = Theme.of(context);
    return Container(
      key: Key('formal-evidence-${item.id}'),
      margin: const EdgeInsets.only(top: AppLayout.spaceMd),
      padding: const EdgeInsets.all(AppLayout.spaceMd),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(AppLayout.radiusLg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              if (!widget.compact) ...[
                Icon(
                  item.type == EvidenceType.image
                      ? Icons.image_outlined
                      : item.type == EvidenceType.file
                      ? Icons.attach_file_rounded
                      : Icons.notes_rounded,
                  size: AppLayout.iconSm,
                ),
                const SizedBox(width: AppLayout.spaceSm),
              ],
              Expanded(
                child: Text(
                  evidenceTypeLabel(item.type),
                  maxLines: widget.compact ? 1 : null,
                  overflow: widget.compact ? TextOverflow.ellipsis : null,
                  style: theme.textTheme.labelLarge,
                ),
              ),
              if (widget.compact)
                IconButton(
                  key: Key('evidence-correct-${item.id}'),
                  tooltip: '修正这份材料',
                  constraints: const BoxConstraints(
                    minWidth: 28,
                    minHeight: 28,
                  ),
                  padding: EdgeInsets.zero,
                  iconSize: AppLayout.iconSm,
                  onPressed:
                      _busy ||
                          (item.attachmentStorageKey != null &&
                              !_attachmentsReady)
                      ? null
                      : () => _begin(item),
                  icon: const Icon(Icons.edit_outlined),
                )
              else
                TextButton(
                  key: Key('evidence-correct-${item.id}'),
                  onPressed:
                      _busy ||
                          (item.attachmentStorageKey != null &&
                              !_attachmentsReady)
                      ? null
                      : () => _begin(item),
                  child: const Text('修正'),
                ),
            ],
          ),
          if (item.type == EvidenceType.image)
            _image(
              item.attachmentStorageKey!,
              item.attachmentFileName ?? '图片材料',
            ),
          if (item.type == EvidenceType.image &&
              item.attachmentFileName?.isNotEmpty == true) ...[
            const SizedBox(height: AppLayout.spaceSm),
            Text(
              item.attachmentFileName!,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall,
            ),
          ],
          if (item.type == EvidenceType.file) _file(item),
          if (item.content?.trim().isNotEmpty == true) ...[
            if (item.attachmentStorageKey != null)
              const SizedBox(height: AppLayout.spaceSm),
            SelectableText(item.content!),
          ],
          if (!widget.compact)
            Text(
              '提交于 ${missionLocalTime(item.submittedAt, _detail.schedule.timeZone)}',
              style: theme.textTheme.bodySmall,
            ),
        ],
      ),
    );
  }

  Widget _editor(BuildContext context) {
    final draft = _draft!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Divider(height: 24),
        const Text('修正草稿 · 原材料会保留'),
        if (draft.type == EvidenceType.image)
          _image(
            draft.attachmentStorageKey!,
            draft.attachmentFileName ?? '替代图片',
          ),
        if (draft.type == EvidenceType.file)
          Text('替代文件：${draft.attachmentFileName}'),
        const SizedBox(height: AppLayout.spaceSm),
        TextField(
          key: const Key('evidence-correction-content'),
          controller: _content,
          enabled: !_busy && _pending == null,
          minLines: draft.attachmentStorageKey == null ? 3 : 1,
          maxLines: draft.attachmentStorageKey == null ? 10 : 4,
          decoration: InputDecoration(
            labelText: draft.attachmentStorageKey == null
                ? '${evidenceTypeLabel(draft.type)}内容'
                : '附件说明（选填）',
          ),
        ),
        const SizedBox(height: AppLayout.spaceMd),
        Wrap(
          spacing: 8,
          children: [
            FilledButton(
              key: const Key('evidence-correction-save'),
              onPressed: _busy ? null : _save,
              child: Text(_pending == null ? '保存修正' : '重试本次修正'),
            ),
            TextButton(
              onPressed: _busy ? null : () => unawaited(_confirmDiscard()),
              child: const Text('丢弃草稿'),
            ),
          ],
        ),
      ],
    );
  }

  @override
  void dispose() {
    _content?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final theme = Theme.of(context);
    final effective = _detail.effectiveEvidence;
    final images = effective.where((item) => item.type == EvidenceType.image);
    final others = effective.where((item) => item.type != EvidenceType.image);
    final corrections = _detail.evidence.where(
      (item) => item.supersedesEvidenceId != null,
    );
    return PopScope<void>(
      canPop: _allowPop || (!_busy && !hasDraft),
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) unawaited(_leave());
      },
      child: Material(
        key: Key('evidence-section-${_detail.mission.id}'),
        color: widget.compact ? AppColors.background : AppColors.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppLayout.radiusXl),
          side: const BorderSide(color: AppColors.hairline),
        ),
        child: Padding(
          padding: EdgeInsets.all(
            widget.compact ? AppLayout.spaceMd : AppLayout.spaceXl,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Icon(Icons.perm_media_outlined, size: AppLayout.iconMd),
                  const SizedBox(width: AppLayout.spaceSm),
                  Expanded(
                    child: Text('任务材料', style: theme.textTheme.titleMedium),
                  ),
                  Text(
                    '${effective.length}',
                    style: theme.textTheme.labelLarge,
                  ),
                ],
              ),
              const SizedBox(height: AppLayout.spaceSm),
              Text(
                '已提交 ${effective.length} 份材料',
                style: theme.textTheme.bodySmall,
              ),
              if (_receipt != null) Text(_receipt!),
              if (_attachmentError != null) ...[
                Text(
                  _attachmentError!,
                  style: TextStyle(color: theme.colorScheme.error),
                ),
                TextButton(
                  onPressed: _prepareAttachments,
                  child: const Text('重试附件准备'),
                ),
              ],
              if (images.isNotEmpty)
                LayoutBuilder(
                  builder: (context, box) {
                    final width = widget.compact
                        ? 152.0.clamp(0.0, box.maxWidth)
                        : ((box.maxWidth - 12) / 2).clamp(0.0, 240.0);
                    return Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        for (final item in images)
                          SizedBox(width: width, child: _item(context, item)),
                      ],
                    );
                  },
                ),
              for (final item in others) _item(context, item),
              if (_draft != null)
                Padding(
                  padding: const EdgeInsets.only(top: AppLayout.spaceMd),
                  child: _editor(context),
                ),
              if (corrections.isNotEmpty)
                AppExpansionTile(
                  key: const Key('evidence-correction-history'),
                  title: Text('修正历史 · ${corrections.length} 条'),
                  childrenPadding: const EdgeInsets.only(
                    top: AppLayout.spaceSm,
                  ),
                  children: [
                    for (final item in _detail.evidence)
                      Padding(
                        padding: const EdgeInsets.only(
                          bottom: AppLayout.spaceMd,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              '${item.supersedesEvidenceId == null ? '原材料' : '修正版本'} · ${evidenceTypeLabel(item.type)}',
                              style: theme.textTheme.titleSmall,
                            ),
                            Text(
                              missionLocalTime(
                                item.submittedAt,
                                _detail.schedule.timeZone,
                              ),
                              style: theme.textTheme.bodySmall,
                            ),
                            if (item.type == EvidenceType.image)
                              _image(
                                item.attachmentStorageKey!,
                                item.attachmentFileName ?? '图片材料',
                              ),
                            if (item.type == EvidenceType.file) _file(item),
                            if (item.content?.trim().isNotEmpty == true)
                              SelectableText(item.content!),
                          ],
                        ),
                      ),
                  ],
                ),
              if (_error != null) ...[
                Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
                TextButton(
                  onPressed: _busy ? null : _readLatest,
                  child: const Text('读取最新材料'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

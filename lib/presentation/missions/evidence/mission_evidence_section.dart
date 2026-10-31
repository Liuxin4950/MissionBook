import '../../../domain/entities/mission_phase.dart';
import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import '../../widgets/detail_pane.dart';
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

import '../../../application/missions/mission_service.dart';
import '../../../core/theme/colors.dart';
import '../../../domain/entities/evidence.dart';
import '../../../domain/entities/failure_record.dart';
import '../../../domain/entities/mission.dart';
import '../../../domain/entities/mission_detail.dart';
import '../../widgets/app_confirm_dialog.dart';
import '../../widgets/app_section_card.dart';
import '../../widgets/app_settings_row.dart';
import '../shared/mission_execution_display.dart';
import 'evidence_image_loader.dart';
import 'formal_evidence_section.dart';
import 'evidence_camera_panel.dart';
import '../../../core/theme/app_layout.dart';

/// 同一任务上下文内的材料区域：编辑草稿、一次提交、查看正式材料。
/// 页面刷新必须保留本组件的 key；草稿只在提交成功或明确丢弃后清除。
class MissionEvidenceSection extends StatefulWidget {
  const MissionEvidenceSection({
    super.key,
    required this.detail,
    required this.service,
    this.onChanged,
    this.initiallyExpanded = false,
    this.protectNavigation = true,
    this.compact = false,
  });

  final MissionDetail detail;
  final MissionService service;
  final VoidCallback? onChanged;
  final bool initiallyExpanded;
  final bool protectNavigation;
  final bool compact; // 历史行只读摘要用小图；待补材料仍保留完整编辑区。

  @override
  State<MissionEvidenceSection> createState() => MissionEvidenceSectionState();
}

class MissionEvidenceSectionState extends State<MissionEvidenceSection>
    with AutomaticKeepAliveClientMixin<MissionEvidenceSection> {
  late MissionDetail _detail;
  late bool _expanded;
  final _drafts = <EvidenceDraft>[];
  final _controllers = <String, TextEditingController>{};
  final _images = <String, Future<Uint8List>>{};
  final _formalKey = GlobalKey<FormalEvidenceSectionState>();
  EvidenceSubmission? _pending;
  bool _busy = false;
  bool _confirming = false;
  bool _allowPop = false;
  String? _error;
  String? _receipt;
  bool _imagesReady = false;
  bool _preparingImages = false;
  bool _cameraOpen = false;
  String? _imageError;

  bool get hasDraft => _drafts.isNotEmpty || _cameraOpen;
  bool get _cameraAvailable =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
  bool get busy => _busy;
  bool get _locked => _busy || _pending != null || _cameraOpen;
  bool get _canSubmit => true;
  bool get _isPending => _detail.phase == MissionPhase.evidencePending;
  @override
  bool get wantKeepAlive => hasDraft || _busy || _pending != null;

  @override
  void setState(VoidCallback fn) {
    super.setState(fn);
    // 历史/今天列表滚出屏幕时，正在整理的材料仍属于当前页面，不能被回收。
    updateKeepAlive();
  }

  @override
  void initState() {
    super.initState();
    _detail = widget.detail;
    _expanded = widget.initiallyExpanded && _isPending;
    if (_canSubmit) unawaited(_prepareImages());
  }

  // 材料区放进右栏后，切换/清空前由右栏导航先问 prepareToLeave：
  // 未提交草稿的丢弃确认与系统返回共用，不允许绕过。
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    DetailPaneScope.maybeOf(
      context,
    )?.registerTopGuard(prepareToLeave, route: ModalRoute.of(context));
  }

  @override
  void didUpdateWidget(covariant MissionEvidenceSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 同任务重读只替换正式事实；本组件拥有的草稿与提交身份继续保留。
    _detail = widget.detail;
    if (_canSubmit &&
        !_imagesReady &&
        !_preparingImages &&
        _imageError == null) {
      unawaited(_prepareImages());
    }
  }

  Future<void> _prepareImages() async {
    if (_preparingImages) return;
    _preparingImages = true;
    _imageError = null;
    try {
      // 提前完成存储恢复；之后用户点击“添加图片”即可直接打开系统选择器。
      await widget.service.initializeEvidenceImages();
      if (mounted) setState(() => _imagesReady = true);
    } catch (error) {
      if (mounted) setState(() => _imageError = '图片存储准备失败：$error');
    } finally {
      _preparingImages = false;
      if (mounted) setState(() {});
    }
  }

  /// 所属页面主动切换列表或上下文前调用，沿用同一份草稿丢弃确认。
  Future<bool> prepareToLeave() async {
    final formal = _formalKey.currentState;
    if (formal != null && !await formal.prepareToLeave()) return false;
    return _confirmDiscard(leave: true);
  }

  void _addText([EvidenceType type = EvidenceType.text]) {
    final draft = widget.service.createTextEvidence('', type: type);
    setState(() {
      _drafts.add(draft);
      _controllers[draft.id] = TextEditingController();
      _error = null;
    });
  }

  Future<void> _addImage() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      // 等待系统选择、真实解码与私有副本准备完成，再把相对引用放入草稿。
      final draft = await widget.service.pickEvidenceImage(_detail.mission.id);
      if (!mounted) {
        if (draft != null) await widget.service.discardEvidenceDrafts([draft]);
        return;
      }
      if (draft != null) {
        setState(() {
          _drafts.add(draft);
          _controllers[draft.id] = TextEditingController(text: draft.content);
        });
      }
    } catch (error) {
      if (mounted) setState(() => _error = '图片添加失败：$error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _addFile() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final draft = await widget.service.pickEvidenceFile(_detail.mission.id);
      if (!mounted) {
        if (draft != null) await widget.service.discardEvidenceDrafts([draft]);
        return;
      }
      if (draft != null) {
        setState(() {
          _drafts.add(draft);
          _controllers[draft.id] = TextEditingController();
        });
      }
    } catch (error) {
      if (mounted) setState(() => _error = '文件添加失败：$error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _confirmCameraImage(Uint8List bytes, DateTime capturedAt) async {
    final draft = await widget.service.prepareEvidenceCameraImage(
      _detail.mission.id,
      bytes,
      capturedAt: capturedAt,
    );
    if (!mounted) {
      await widget.service.discardEvidenceDrafts([draft]);
      return;
    }
    setState(() {
      _drafts.add(draft);
      _controllers[draft.id] = TextEditingController();
      _cameraOpen = false;
    });
  }

  void _updateContent(String id, String content) {
    final index = _drafts.indexWhere((draft) => draft.id == id);
    if (index >= 0) _drafts[index] = _drafts[index].copyWithContent(content);
  }

  Future<void> _remove(EvidenceDraft draft) async {
    setState(() => _busy = true);
    try {
      await widget.service.discardEvidenceDrafts([draft]);
      if (!mounted) return;
      setState(() {
        _drafts.removeWhere((item) => item.id == draft.id);
        _controllers.remove(draft.id)?.dispose();
      });
    } catch (error) {
      if (mounted) setState(() => _error = '移除失败：$error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _clearDrafts() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    _controllers.clear();
    _drafts.clear();
    _cameraOpen = false;
    _pending = null;
  }

  EvidenceDraft _draftWithCurrentInput(EvidenceDraft draft) {
    final text = _controllers[draft.id]?.text ?? draft.content;
    if ((draft.type == EvidenceType.image || draft.type == EvidenceType.file) &&
        (text?.trim().isEmpty ?? true)) {
      return draft.copyWithContent(null); // 没填写图片说明时保持“未提供”。
    }
    return draft.copyWithContent(text);
  }

  Future<void> _submit() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      // 第一次点击固定整批输入；保存结果未确认时，重试复用这一批的编号和内容。
      _pending ??= widget.service.prepareEvidenceSubmission(
        detail: _detail,
        // Controller 是输入的当前值；辅助输入可能直接更新它而不触发 onChanged。
        // 只在首次提交时读取，结果未知后的重试仍使用已固定的 _pending。
        items: [for (final draft in _drafts) _draftWithCurrentInput(draft)],
      );
      final result = await widget.service.submitEvidence(_pending!);
      if (!mounted) return;
      if (result == EvidenceSubmissionResult.submitted) {
        setState(() {
          _clearDrafts();
          _receipt = '材料已提交，原始内容已保存。';
          _expanded = false;
        });
      } else {
        setState(() {
          _clearDrafts();
          _receipt = '材料已保存，但已超过提交期限；超时记录已保留。';
          _expanded = false;
        });
      }
      await _readLatest();
    } on ArgumentError catch (error) {
      _pending = null;
      if (mounted) setState(() => _error = '${error.message}');
    } on EvidenceConflict catch (error) {
      _pending = null;
      if (mounted) setState(() => _error = error.message);
      await _readLatest(clearError: false);
    } catch (error, stack) {
      debugPrint('材料提交结果未确认：$error\n$stack');
      if (mounted) {
        setState(() => _error = '保存结果未确认，草稿已保留。请重试本次提交，或读取最新记录确认。');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _readLatest({bool clearError = true}) async {
    try {
      final latest = await widget.service.findDetailAndReconcile(
        missionId: _detail.mission.id,
      );
      if (!mounted || latest == null) return;
      final saved =
          _pending != null &&
          latest.evidence.any((item) => item.submissionId == _pending!.id);
      setState(() {
        _detail = latest;
        if (saved) {
          _clearDrafts();
          _receipt = '已确认本次材料提交成功。';
        } else {
          // 一致查询没有这批正式材料：恢复草稿编辑，下一次提交重新固定输入。
          _pending = null;
        }
        if (clearError) _error = null;
      });
      widget.onChanged?.call();
    } catch (error) {
      if (mounted) setState(() => _error = '最新记录读取失败，请重试；当前输入已保留。');
    }
  }

  Future<bool> _confirmDiscard({bool leave = false}) async {
    if (_busy || _confirming) return false;
    if (!hasDraft && _pending == null) return true;
    // 结果未知时先读取确认，避免把已经正式保存的副本当作草稿删除。
    if (_pending != null) {
      await _readLatest();
      if (!mounted || _pending != null) return false;
      if (!hasDraft) return true;
    }
    _confirming = true;
    final confirmed = await AppConfirmDialog.show(
      context: context,
      title: leave ? '离开并丢弃材料草稿？' : '丢弃材料草稿？',
      message: '尚未提交的材料将被丢弃，已经保存的执行记录保持不变。',
      cancelText: '继续整理',
      confirmText: '丢弃草稿',
    );
    _confirming = false;
    if (!mounted || !confirmed) return false;
    try {
      await widget.service.discardEvidenceDrafts(List.of(_drafts));
      if (!mounted) return false;
      setState(_clearDrafts);
      return true;
    } catch (error) {
      if (mounted) setState(() => _error = '草稿清理失败：$error');
      return false;
    }
  }

  Future<void> _skip() async {
    if (_busy || _confirming || _pending != null) return;
    _confirming = true;
    final confirmed = await AppConfirmDialog.show(
      context: context,
      title: '放弃提交并结束？',
      message: hasDraft
          ? '放弃后丢弃当前材料草稿，保留完成报告。任务结束后不能再补交首批材料。'
          : '本次完成报告会保留，任务结束后不能再补交首批材料。',
      cancelText: '继续整理',
      confirmText: '放弃提交',
    );
    _confirming = false;
    if (!mounted || !confirmed) return;
    setState(() => _busy = true);
    try {
      // 先等用户决定正式保存；写入失败时草稿仍然保留。
      await widget.service.skipOptionalEvidence(_detail.mission.id);
      try {
        await widget.service.discardEvidenceDrafts(List.of(_drafts));
        if (mounted) setState(_clearDrafts);
      } catch (error) {
        if (mounted) setState(() => _error = '任务已结束，草稿副本清理失败，可稍后明确丢弃。');
      }
      await _readLatest();
      if (mounted) setState(() => _receipt = '已放弃提交，任务已结束。');
    } catch (error) {
      if (mounted) setState(() => _error = '结束材料环节失败：$error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _leave() async {
    if (!await _confirmDiscard(leave: true) || !mounted) return;
    setState(() => _allowPop = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && Navigator.of(context).canPop()) {
        Navigator.of(context).maybePop();
      }
    });
  }

  Widget _image(String key, String name, {double height = 148}) {
    // Future 按键缓存，输入说明或重绘时不重新读取图片文件。
    final image = _images.putIfAbsent(
      key,
      () => widget.service.readEvidenceImage(key),
    );
    return EvidenceImageLoader(
      future: image,
      name: name,
      height: height,
      onRetry: () => setState(() => _images.remove(key)),
    );
  }

  /// 读取和修正正式材料由独立组件管理；首次提交草稿仍留在本任务区。
  Widget _formalMaterials(BuildContext context) => FormalEvidenceSection(
    key: _formalKey,
    detail: _detail,
    service: widget.service,
    compact: widget.compact,
    onChanged: widget.onChanged,
  );
  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    // 非正常销毁不猜测保存结果，也不删除文件；下次启动按正式引用安全清理。
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final theme = Theme.of(context);
    final requiredEvidence =
        _detail.mission.verificationPolicy ==
        VerificationPolicy.requiredEvidence;
    final deadline = _detail.schedule.evidenceDeadlineAt;
    final timedOut = _detail.failures.any(
      (item) => item.trigger == evidenceDeadlineMissedTrigger,
    );
    final hasFormal = _detail.evidence.isNotEmpty;
    if (!_isPending && !_expanded && !hasDraft && _pending == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (timedOut) const Text('材料超时'),
          if (hasFormal) _formalMaterials(context),
          AppSectionCard(
            padding: EdgeInsets.zero,
            child: AppSettingsRow(
              key: Key('evidence-open-${_detail.mission.id}'),
              onTap: () => setState(() => _expanded = true),
              icon: Icons.attach_file_outlined,
              title: hasFormal ? '补充材料' : '添加材料',
            ),
          ),
        ],
      );
    }
    if (!_canSubmit &&
        !hasFormal &&
        !hasDraft &&
        !timedOut &&
        _receipt == null) {
      return const SizedBox.shrink();
    }
    final content = Semantics(
      container: true,
      explicitChildNodes: true,
      child: Container(
        key: Key('evidence-section-${_detail.mission.id}'),
        padding: const EdgeInsets.all(AppLayout.spaceXl),
        decoration: BoxDecoration(
          color: AppColors.primarySoft,
          borderRadius: BorderRadius.circular(AppLayout.radiusXxl),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              _isPending
                  ? '执行已结束 · 待提交材料'
                  : timedOut
                  ? '材料超时'
                  : '任务材料 · 补充不改变原结果',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: AppLayout.spaceSm),
            if (_canSubmit)
              Text(
                requiredEvidence
                    ? '按要求提交文字、代码、手动记录、文件或图片，可组合提交。'
                    : _isPending
                    ? '材料可选；可以提交适合的记录，也可以放弃提交并结束。'
                    : '保存相关材料；任务的执行、完成报告和既有超时结果保持原样。',
              ),
            if (deadline != null && requiredEvidence)
              Text(
                '提交截止：${missionLocalTime(deadline, _detail.schedule.timeZone)}',
              ),
            if (_detail.executionPlan.verificationCriteria?.trim().isNotEmpty ==
                true) ...[
              const SizedBox(height: AppLayout.spaceSm),
              Text(_detail.executionPlan.verificationCriteria!),
            ],
            if (timedOut) const Text('完成报告已保存，强制材料未按时提交。'),
            if (_receipt != null)
              Semantics(liveRegion: true, child: Text(_receipt!)),
            if (_canSubmit && !_expanded)
              Align(
                alignment: Alignment.centerLeft,
                child: FilledButton.tonalIcon(
                  key: Key('evidence-open-${_detail.mission.id}'),
                  onPressed: () => setState(() => _expanded = true),
                  icon: const Icon(Icons.attach_file_rounded),
                  label: const Text('提交材料'),
                ),
              ),
            if (_expanded && (_canSubmit || hasDraft)) ...[
              const SizedBox(height: AppLayout.spaceLg),
              const Text('草稿 · 尚未进入正式记录'),
              const SizedBox(height: AppLayout.spaceMd),
              for (final draft in _drafts) ...[
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        draft.attachmentFileName ??
                            evidenceTypeLabel(draft.type),
                        style: theme.textTheme.titleSmall,
                      ),
                    ),
                    IconButton(
                      tooltip: '移除这份材料',
                      onPressed: _locked ? null : () => _remove(draft),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
                if (draft.type == EvidenceType.image) ...[
                  _image(
                    draft.attachmentStorageKey!,
                    draft.attachmentFileName ?? '图片',
                  ),
                  const SizedBox(height: AppLayout.spaceMd),
                ],
                Semantics(
                  container: true,
                  explicitChildNodes: true,
                  child: TextField(
                    key: Key('evidence-content-${draft.id}'),
                    controller: _controllers[draft.id],
                    enabled: !_locked && _canSubmit,
                    minLines: draft.attachmentStorageKey == null ? 3 : 1,
                    maxLines: draft.attachmentStorageKey == null ? 10 : 4,
                    decoration: InputDecoration(
                      labelText: draft.attachmentStorageKey == null
                          ? draft.type == EvidenceType.text
                                ? '文本内容'
                                : '${evidenceTypeLabel(draft.type)}内容'
                          : '附件说明（选填）',
                      alignLabelWithHint: true,
                    ),
                    onChanged: (value) => _updateContent(draft.id, value),
                  ),
                ),
                const SizedBox(height: AppLayout.spaceXl),
              ],
              if (_canSubmit)
                Wrap(
                  spacing: AppLayout.spaceMd,
                  runSpacing: AppLayout.spaceSm,
                  children: [
                    OutlinedButton.icon(
                      key: const Key('evidence-add-text'),
                      onPressed: _locked ? null : () => _addText(),
                      icon: const Icon(Icons.notes_rounded),
                      label: const Text('添加文本'),
                    ),
                    OutlinedButton.icon(
                      key: const Key('evidence-add-code'),
                      onPressed: _locked
                          ? null
                          : () => _addText(EvidenceType.code),
                      icon: const Icon(Icons.code_rounded),
                      label: const Text('添加代码'),
                    ),
                    OutlinedButton.icon(
                      key: const Key('evidence-add-manual'),
                      onPressed: _locked
                          ? null
                          : () => _addText(EvidenceType.manualRecord),
                      icon: const Icon(Icons.edit_note_rounded),
                      label: const Text('手动记录'),
                    ),
                    OutlinedButton.icon(
                      key: const Key('evidence-add-image'),
                      onPressed: _locked || !_imagesReady ? null : _addImage,
                      icon: const Icon(Icons.add_photo_alternate_outlined),
                      label: Text(_preparingImages ? '图片准备中' : '添加图片'),
                    ),
                    OutlinedButton.icon(
                      key: const Key('evidence-add-file'),
                      onPressed: _locked || !_imagesReady ? null : _addFile,
                      icon: const Icon(Icons.attach_file_rounded),
                      label: const Text('添加文件'),
                    ),
                    if (_cameraAvailable)
                      OutlinedButton.icon(
                        key: const Key('evidence-add-camera'),
                        onPressed: _locked || !_imagesReady
                            ? null
                            : () => setState(() => _cameraOpen = true),
                        icon: const Icon(Icons.camera_alt_outlined),
                        label: const Text('拍照'),
                      ),
                  ],
                ),
              if (_cameraOpen) ...[
                const SizedBox(height: AppLayout.spaceMd),
                EvidenceCameraPanel(
                  missionTitle: _detail.mission.title,
                  onConfirmed: _confirmCameraImage,
                  onChooseFile: () {
                    setState(() => _cameraOpen = false);
                    unawaited(_addImage());
                  },
                  onCancel: () => setState(() => _cameraOpen = false),
                ),
              ],
              if (_imageError != null) ...[
                Text(
                  _imageError!,
                  style: TextStyle(color: theme.colorScheme.error),
                ),
                OutlinedButton(
                  onPressed: _prepareImages,
                  child: const Text('重试图片准备'),
                ),
              ],
              if (_busy)
                const Padding(
                  padding: EdgeInsets.only(top: AppLayout.spaceMd),
                  child: LinearProgressIndicator(),
                ),
              if (_canSubmit)
                Padding(
                  padding: const EdgeInsets.only(top: AppLayout.spaceLg),
                  child: FilledButton(
                    key: const Key('evidence-submit'),
                    onPressed: _busy || (_drafts.isEmpty && _pending == null)
                        ? null
                        : _submit,
                    child: Text(_pending == null ? '提交材料' : '重试本次提交'),
                  ),
                ),
              if (hasDraft)
                OutlinedButton(
                  onPressed: _busy
                      ? null
                      : () async {
                          if (await _confirmDiscard() && mounted) {
                            setState(() => _expanded = false);
                          }
                        },
                  child: const Text('丢弃草稿'),
                ),
            ],
            if (_isPending && !requiredEvidence)
              OutlinedButton(
                key: const Key('evidence-skip'),
                onPressed: _locked ? null : _skip,
                child: const Text('放弃提交并结束'),
              ),
            if (_error != null) ...[
              const SizedBox(height: AppLayout.spaceMd),
              Semantics(
                liveRegion: true,
                child: Text(
                  _error!,
                  style: TextStyle(color: theme.colorScheme.error),
                ),
              ),
              OutlinedButton(
                onPressed: _busy ? null : _readLatest,
                child: const Text('读取最新记录'),
              ),
            ],
            if (hasFormal) _formalMaterials(context),
          ],
        ),
      ),
    );
    if (!widget.protectNavigation) return content;
    return PopScope<void>(
      canPop: _allowPop || (!_busy && !hasDraft && _pending == null),
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) unawaited(_leave());
      },
      child: content,
    );
  }
}

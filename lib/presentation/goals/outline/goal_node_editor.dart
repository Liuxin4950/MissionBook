import 'package:flutter/material.dart';

import '../../../application/goals/goal_service.dart';
import '../../../core/theme/app_layout.dart';
import '../../../core/theme/colors.dart';
import '../../../domain/entities/goal_node.dart';
import '../../widgets/adaptive_sheet.dart';
import '../../widgets/app_confirm_dialog.dart';
import '../../widgets/app_text_field.dart';

/// 在当前目标上方填写节点，创建、添加子节点与编辑共用这个编辑框。
class GoalNodeEditor extends StatefulWidget {
  const GoalNodeEditor({
    super.key,
    required this.service,
    required this.goalId,
    required this.contextTitle,
    this.parentNodeId,
    this.node,
  });

  final GoalService service; // 目标页传入同一个服务，不在编辑框里重新创建连接。
  final String goalId; // 正在维护的目标编号。
  final String contextTitle; // 显示目标或父节点名称，帮助用户确认添加位置。
  final String? parentNodeId; // 新增子节点时有值，顶层节点为空。
  final GoalNode? node; // 编辑已有节点时传入；新增时为空。

  static Future<bool> show({
    required BuildContext context,
    required GoalService service,
    required String goalId,
    required String contextTitle,
    String? parentNodeId,
    GoalNode? node,
  }) async {
    final saved = await showAdaptiveSheet<bool>(
      context: context,
      isDismissible: false, // 离开统一经过下面的关闭入口，以保留未保存内容提示。
      enableDrag: false,
      constraints: const BoxConstraints(maxWidth: AppLayout.maxPageWidth),
      backgroundColor: AppColors.background,
      builder: (_) => GoalNodeEditor(
        service: service,
        goalId: goalId,
        contextTitle: contextTitle,
        parentNodeId: parentNodeId,
        node: node,
      ),
    );
    return saved == true; // 只把明确保存成功转换为 true，普通关闭返回 false。
  }

  @override
  State<GoalNodeEditor> createState() => _GoalNodeEditorState();
}

class _GoalNodeEditorState extends State<GoalNodeEditor> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _title;
  late final TextEditingController _description;
  GoalNode? _expected; // 编辑时保留原记录，提交给仓储检查文字是否已被其他入口修改。
  GoalNodeCreation? _pending; // 新增首次保存时固定请求，重试继续使用它。
  bool _saving = false;
  bool _closing = false;
  bool _locked = false; // 保存结果未确认前，暂不允许改变本次请求的输入。
  String? _error;

  @override
  void initState() {
    super.initState();
    _expected = widget.node;
    _title = TextEditingController(text: widget.node?.title ?? '');
    _description = TextEditingController(text: widget.node?.description ?? '');
  }

  Future<void> _save() async {
    if (_saving || _closing || !_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      if (_expected == null) {
        _pending ??= widget.service.prepareNodeCreation(
          goalId: widget.goalId,
          parentNodeId: widget.parentNodeId,
          title: _title.text,
          description: _description.text,
        ); // ??= 只在 _pending 为空时准备一次，后续重试沿用原编号和原内容。
        _locked = true;
        await widget.service.createNode(_pending!);
      } else {
        _locked = true;
        await widget.service.updateNode(
          _expected!,
          title: _title.text,
          description: _description.text,
        );
      }
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      if (mounted) {
        setState(() {
          final reason = error is StateError ? '${error.message}。' : '';
          _error = '$reason暂未确认保存结果，输入已保留。可重试，或先确认结果再编辑。';
        });
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  /// 根据固定编号查询上次保存结果，避免创建重复节点或用旧文字覆盖别人修改的内容。
  Future<void> _confirmResult() async {
    if (_saving) return;
    final id = _pending?.id ?? _expected?.id;
    if (id == null) return;
    setState(() => _saving = true);
    try {
      final saved = await widget.service.findNodeById(id);
      if (!mounted) return;
      final description = _description.text.trim();
      if (saved != null &&
          saved.goalId == widget.goalId &&
          saved.parentNodeId ==
              (_expected?.parentNodeId ?? widget.parentNodeId) &&
          saved.title == _title.text.trim() &&
          saved.description == (description.isEmpty ? null : description) &&
          (_pending == null || saved.createdAt == _pending!.createdAt)) {
        Navigator.of(context).pop(true); // 查到的内容就是原请求，直接回到正式树。
        return;
      }
      setState(() {
        if (_expected == null && saved == null) {
          _pending = null;
          _locked = false; // 确认创建尚未发生，才允许改输入并准备下一次请求。
          _error = null;
        } else if (_expected != null &&
            saved != null &&
            saved.archivedAt == null) {
          _expected = saved;
          _locked = false;
          _error = '已读取最新节点，当前输入仍保留，请核对后再保存。';
        } else {
          _error = '节点已变化，请关闭编辑框，在最新目标路径中确认后再操作。';
        }
      });
    } catch (_) {
      if (mounted) setState(() => _error = '仍无法读取保存结果，输入已保留，请稍后重试。');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _close() async {
    if (_saving || _closing) return;
    final changed =
        _locked ||
        _title.text != (widget.node?.title ?? '') ||
        _description.text != (widget.node?.description ?? '');
    if (changed) {
      _closing = true;
      final discard = await AppConfirmDialog.show(
        context: context,
        title: '离开节点编辑？',
        message: _locked
            ? '保存结果尚未确认。离开会清空输入；若已保存，可在目标路径查看。'
            : '已填写的修改还没有保存，离开后不会保留。',
        cancelText: '继续编辑',
        confirmText: '离开',
      );
      _closing = false;
      if (!discard || !mounted) return;
    }
    if (mounted) Navigator.of(context).pop(false);
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final editing = widget.node != null;
    final heading = editing
        ? '编辑节点'
        : (widget.parentNodeId == null ? '添加节点' : '添加子节点');
    return PopScope<bool>(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _close(); // 系统返回与关闭按钮都先检查保存状态和草稿。
      },
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: SingleChildScrollView(
          padding: AppLayout.pagePadding(context),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(heading, style: theme.textTheme.titleLarge),
                    ),
                    IconButton(
                      tooltip: '关闭节点编辑',
                      onPressed: _saving ? null : _close,
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                const SizedBox(height: AppLayout.spaceXs),
                Text(
                  '${editing ? '所属位置' : '添加到'} · ${widget.contextTitle}',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: AppLayout.spaceXxl),
                AppTextField(
                  key: const Key('node-title-input'),
                  controller: _title,
                  readOnly: _saving || _locked,
                  autofocus: true,
                  minLines: 1,
                  maxLines: 3,
                  label: '节点名称（必填）',
                  hint: '这部分想学习或完成什么？',
                  validator: (value) =>
                      value == null || value.trim().isEmpty ? '请填写节点名称' : null,
                ),
                const SizedBox(height: AppLayout.spaceXl),
                AppTextField(
                  key: const Key('node-description-input'),
                  controller: _description,
                  readOnly: _saving || _locked,
                  minLines: 2,
                  maxLines: 6,
                  label: '节点说明（选填）',
                  hint: '需要时再补充范围或学习重点',
                ),
                const SizedBox(height: AppLayout.spaceXxl),
                if (_error != null) ...[
                  Semantics(
                    liveRegion: true,
                    child: Text(
                      _error!,
                      style: const TextStyle(color: AppColors.error),
                    ),
                  ),
                  if (_locked)
                    TextButton(
                      onPressed: _saving ? null : _confirmResult,
                      child: const Text('确认结果并继续编辑'),
                    ),
                  const SizedBox(height: AppLayout.spaceMd),
                ],
                FilledButton.icon(
                  key: const Key('node-save'),
                  onPressed: _saving ? null : _save,
                  icon: Icon(_saving ? Icons.hourglass_top : Icons.check),
                  label: Text(_saving ? '正在保存…' : (_locked ? '重试保存' : '保存节点')),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(0, AppLayout.actionMinHeight),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

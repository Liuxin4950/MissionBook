import 'package:flutter/material.dart';

import '../../../application/goals/goal_outline_parser.dart';
import '../../../application/goals/goal_service.dart';
import '../../../core/theme/colors.dart';
import '../../../domain/entities/goal_outline_import.dart';
import '../../widgets/app_confirm_dialog.dart';

/// 在目标页原位粘贴或读取 JSON、预览完整树，再由用户明确确认一次提交。
class GoalImportSection extends StatefulWidget {
  const GoalImportSection({
    super.key,
    required this.service,
    required this.onImported,
  });
  final GoalService service;
  final ValueChanged<String> onImported;
  @override
  State<GoalImportSection> createState() => GoalImportSectionState();
}

class GoalImportSectionState extends State<GoalImportSection> {
  final _input = TextEditingController();
  GoalOutlineImport? _preview;
  GoalOutlineCreation? _pending;
  bool _saving = false;
  bool _picking = false;
  bool _unknown = false;
  bool _saved = false;
  String? _error;

  Future<bool> prepareToCollapse() async {
    if (_saving || _picking) return false;
    if (_saved || _input.text.trim().isEmpty) return true;
    return await AppConfirmDialog.show(
      context: context,
      title: '离开目标导入？',
      message: _unknown
          ? '保存结果尚未确认。关闭后仍可在目标列表检查，但输入草稿会丢失。'
          : '当前 JSON 和预览尚未保存，关闭后输入会丢失。',
      cancelText: '继续填写',
      confirmText: '放弃草稿',
    );
  }

  void _inputChanged(String value) {
    if (_saving || _unknown) return;
    setState(() {
      _preview = null;
      _pending = null;
      _saved = false;
      _error = null;
    });
  }

  void _validate() {
    try {
      final parsed = GoalOutlineParser.parseText(_input.text);
      setState(() {
        _preview = parsed;
        _pending = null;
        _error = null;
        _saved = false;
      });
    } catch (error) {
      setState(() {
        _preview = null;
        _pending = null;
        _error = error.toString().replaceFirst('FormatException: ', '');
      });
    }
  }

  Future<void> _pick() async {
    if (_picking || _saving || _unknown) return;
    setState(() => _picking = true);
    try {
      final text = await widget.service.pickOutlineText();
      if (!mounted || text == null) return;
      _input.text = text; // 系统取消时保留原有草稿，选中时回到同一导入区预览。
      _validate();
    } catch (error) {
      if (mounted) {
        setState(
          () => _error = error.toString().replaceFirst('FormatException: ', ''),
        );
      }
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  Future<void> _save() async {
    if (_saving || _preview == null || _saved) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      _pending ??= widget.service.prepareOutlineImport(_preview!);
      await widget.service.importOutline(_pending!);
      if (!mounted) return;
      setState(() {
        _saved = true;
        _unknown = false;
      });
      widget.onImported(_pending!.goal.id);
    } catch (error, stack) {
      debugPrint('目标大纲保存结果未确认：$error\n$stack');
      if (mounted) {
        setState(() {
          _unknown = _pending != null;
          _error = '暂时未能确认导入结果。输入和预览已保留，可重试同一次导入或确认保存结果。';
        });
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _checkResult() async {
    final request = _pending;
    if (_saving || request == null) return;
    setState(() => _saving = true);
    try {
      final saved = await widget.service.findById(request.goal.id);
      if (!mounted) return;
      if (saved == null) {
        setState(() {
          _pending = null;
          _unknown = false;
          _error = '确认未保存，可继续调整输入或重试导入。';
        });
      } else {
        await widget.service.importOutline(request); // 再比较完整树，不把部分匹配冒充成功。
        if (!mounted) return;
        setState(() {
          _saved = true;
          _unknown = false;
          _error = null;
        });
        widget.onImported(request.goal.id);
      }
    } catch (error, stack) {
      debugPrint('目标大纲结果确认失败：$error\n$stack');
      if (mounted) setState(() => _error = '结果仍无法确认，原输入已保留，请稍后重试。');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final preview = _preview;
    return Container(
      key: const Key('goal-import-section'),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('导入目标大纲', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          Text(
            '粘贴 JSON，或选择 .json 文件。先校验并预览，确认后才会创建目标与节点。',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 16),
          TextField(
            key: const Key('goal-import-input'),
            controller: _input,
            onChanged: _inputChanged,
            readOnly: _saving || _unknown || _saved,
            minLines: 4,
            maxLines: 8,
            style: theme.textTheme.bodyMedium,
            decoration: InputDecoration(
              hintText: '粘贴目标大纲 JSON',
              filled: true,
              fillColor: AppColors.primarySoft.withValues(alpha: .5),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                key: const Key('goal-import-file'),
                onPressed: _picking || _saving || _unknown || _saved
                    ? null
                    : _pick,
                icon: const Icon(Icons.folder_open_outlined),
                label: Text(_picking ? '正在选择…' : '选择 JSON 文件'),
              ),
              TextButton.icon(
                key: const Key('goal-import-preview'),
                onPressed: _saving || _unknown || _saved ? null : _validate,
                icon: const Icon(Icons.fact_check_outlined),
                label: const Text('校验并预览'),
              ),
            ],
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Semantics(
              liveRegion: true,
              child: Text(
                _error!,
                key: const Key('goal-import-error'),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: AppColors.error,
                ),
              ),
            ),
          ],
          if (_unknown)
            TextButton(
              key: const Key('goal-import-check-result'),
              onPressed: _saving ? null : _checkResult,
              child: const Text('确认保存结果并继续'),
            ),
          if (preview != null) ...[
            const SizedBox(height: 20),
            const Divider(height: 1),
            const SizedBox(height: 16),
            Text(
              preview.title,
              style: theme.textTheme.bodyLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            if (preview.description != null)
              Text(preview.description!, style: theme.textTheme.bodyMedium),
            if (preview.why != null)
              Text('为什么：${preview.why!}', style: theme.textTheme.bodyMedium),
            const SizedBox(height: 10),
            Text(
              '完整大纲 · ${preview.nodeCount} 个节点',
              style: theme.textTheme.titleSmall,
            ),
            for (final node in preview.nodes) _node(context, node, 0),
            const SizedBox(height: 16),
            FilledButton.icon(
              key: const Key('goal-import-confirm'),
              onPressed: _saving || _saved ? null : _save,
              icon: Icon(_saving ? Icons.hourglass_top : Icons.check),
              label: Text(
                _saved
                    ? '已导入目标'
                    : _saving
                    ? '正在保存…'
                    : _unknown
                    ? '重试同一次导入'
                    : '确认创建目标与节点',
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _node(BuildContext context, GoalImportNode node, int depth) => Padding(
    padding: EdgeInsets.only(left: depth * 12.0, top: 8),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '• ${node.title}',
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: AppColors.textPrimary),
        ),
        if (node.description != null)
          Text(node.description!, style: Theme.of(context).textTheme.bodySmall),
        for (final child in node.children) _node(context, child, depth + 1),
      ],
    ),
  );
}

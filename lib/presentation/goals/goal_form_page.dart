import 'package:flutter/material.dart';

import '../../application/goals/goal_service.dart';
import '../../core/theme/app_layout.dart';
import '../../core/theme/colors.dart';
import '../../domain/entities/goal.dart';
import '../widgets/app_confirm_dialog.dart';
import '../widgets/app_top_bar.dart';

/// 收集一个目标的输入，保存成功后把真实编号交回列表页。
class GoalFormPage extends StatefulWidget {
  const GoalFormPage({super.key, required this.service});
  final GoalService service; // 列表传入共享服务；本页不创建数据库连接。
  @override
  State<GoalFormPage> createState() => _GoalFormPageState();
}

class _GoalFormPageState extends State<GoalFormPage> {
  final _formKey = GlobalKey<FormState>(); // 调用表单中各输入框的 validator。
  final _title = TextEditingController();
  final _description = TextEditingController();
  final _why = TextEditingController();
  Goal? _pending; // 首次保存时固定请求；失败重试继续使用同一份内容。
  bool _saving = false;
  bool _closing = false;
  String? _error;

  /// 校验草稿并提交固定创建请求，成功才关闭表单并返回编号。
  Future<void> _save() async {
    if (_saving || _closing) return; // 重复点击不能发起第二次创建。
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      _pending ??= widget.service.prepareCreation(
        title: _title.text,
        description: _description.text,
        why: _why.text,
      ); // ??= 只在首次请求时赋值，重试不重新生成目标编号。
      await widget.service.create(_pending!);
      if (mounted) Navigator.of(context).pop(_pending!.id);
    } catch (_) {
      if (mounted) {
        setState(() {
          _error = '暂时未能确认保存结果，输入已保留。请重试保存，或确认结果后继续编辑。';
        });
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  /// 发生未知保存错误后先查原编号，避免修改输入并生成第二份重复目标。
  Future<void> _resumeEditing() async {
    if (_saving || _pending == null) return;
    setState(() => _saving = true);
    try {
      final saved = await widget.service.findById(_pending!.id);
      if (!mounted) return;
      if (saved != null) {
        Navigator.of(context).pop(saved.id); // 上次实际已保存，直接展示正式结果。
      } else {
        setState(() {
          _pending = null; // 确认未保存后，才允许修改并准备新请求。
          _error = null;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _error = '仍无法确认保存结果，请稍后重试，输入已保留。');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  /// 顶栏和系统返回共用的离开入口，保存期间阻止离开，有输入时先确认。
  Future<void> _close() async {
    if (_saving || _closing) return;
    final hasInput =
        _title.text.isNotEmpty ||
        _description.text.isNotEmpty ||
        _why.text.isNotEmpty;
    if (hasInput) {
      _closing = true;
      final discard = await AppConfirmDialog.show(
        context: context,
        title: '离开本次填写？',
        message: _pending == null
            ? '返回后，已填写的内容不会保存。'
            : '保存结果尚未确认。返回后输入将清空，若已保存，可在目标列表查看。',
        cancelText: '继续填写',
        confirmText: '离开',
      );
      _closing = false;
      if (!discard || !mounted) return;
    }
    if (mounted) Navigator.of(context).pop();
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _why.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final editable = !_saving && _pending == null;
    final theme = Theme.of(context);
    // PopScope 把系统返回也交给 _close，避免键盘/返回键绕过草稿保护。
    return PopScope<String>(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _close();
      },
      child: Scaffold(
        appBar: AppTopBar(title: '新建目标', onBack: _close, canGoBack: !_saving),
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: AppLayout.maxPageWidth,
              ),
              child: SingleChildScrollView(
                padding: AppLayout.pagePadding(context),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text('你希望做到什么？', style: theme.textTheme.headlineSmall),
                      const SizedBox(height: 8),
                      Text(
                        '先确定一个方向，说明和原因可以慢慢补充。',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 28),
                      TextFormField(
                        key: const Key('goal-title-input'),
                        controller: _title,
                        readOnly: !editable,
                        decoration: _decoration(
                          '目标名称（必填）',
                          '例如：能独立开发 Flutter 应用',
                        ),
                        textInputAction: TextInputAction.next,
                        minLines: 1,
                        maxLines: 3,
                        validator: (value) =>
                            value == null || value.trim().isEmpty
                            ? '请填写目标名称'
                            : null,
                      ),
                      const SizedBox(height: 20),
                      TextFormField(
                        key: const Key('goal-description-input'),
                        controller: _description,
                        readOnly: !editable,
                        decoration: _decoration('目标说明（选填）', '你希望达到什么程度？'),
                        minLines: 3,
                        maxLines: 8,
                      ),
                      const SizedBox(height: 20),
                      TextFormField(
                        key: const Key('goal-why-input'),
                        controller: _why,
                        readOnly: !editable,
                        decoration: _decoration('为什么想实现（选填）', '写给自己的一点提醒'),
                        minLines: 2,
                        maxLines: 6,
                      ),
                      const SizedBox(height: 28),
                      if (_error != null) ...[
                        Semantics(
                          liveRegion: true,
                          child: Text(
                            _error!,
                            style: const TextStyle(color: AppColors.error),
                          ),
                        ),
                        TextButton(
                          onPressed: _saving ? null : _resumeEditing,
                          child: const Text('确认结果并继续编辑'),
                        ),
                        const SizedBox(height: 12),
                      ],
                      FilledButton.icon(
                        key: const Key('goal-save'),
                        onPressed: _saving ? null : _save,
                        icon: Icon(_saving ? Icons.hourglass_top : Icons.check),
                        label: Text(
                          _saving
                              ? '正在保存…'
                              : (_pending == null ? '创建目标' : '重试保存'),
                        ),
                        style: FilledButton.styleFrom(
                          minimumSize: const Size(0, 52),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _decoration(String label, String hint) => InputDecoration(
    labelText: label,
    hintText: hint,
    alignLabelWithHint: true,
    filled: true,
    fillColor: AppColors.card,
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
  );
}

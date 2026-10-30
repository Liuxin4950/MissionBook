import 'package:flutter/material.dart';

import '../../../application/goals/goal_service.dart';
import '../../../core/theme/app_layout.dart';
import '../../../core/theme/colors.dart';
import '../../../domain/entities/goal.dart';
import '../../widgets/app_confirm_dialog.dart';
import '../../widgets/app_text_field.dart';
import '../../widgets/app_top_bar.dart';
import '../../widgets/app_section_card.dart';
import '../../widgets/page_footer_bar.dart';
import '../../widgets/detail_pane.dart';

/// 收集一个目标的输入，保存成功后把真实编号交回列表页。
class GoalFormPage extends StatefulWidget {
  const GoalFormPage({super.key, required this.service, this.goal});
  final GoalService service; // 列表传入共享服务；本页不创建数据库连接。
  final Goal? goal; // 编辑时传入当前版本；创建时为空。
  @override
  State<GoalFormPage> createState() => _GoalFormPageState();
}

class _GoalFormPageState extends State<GoalFormPage> {
  final _formKey = GlobalKey<FormState>(); // 调用表单中各输入框的 validator。
  final _title = TextEditingController();
  final _description = TextEditingController();
  final _why = TextEditingController();
  Goal? _pending; // 首次保存时固定请求；失败重试继续使用同一份内容。
  Goal? _editingExpected;
  Goal? _latestConflict;
  bool _editResultUnknown = false;
  bool _saving = false;
  bool _closing = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _editingExpected = widget.goal;
    if (widget.goal != null) {
      _title.text = widget.goal!.title;
      _description.text = widget.goal!.description ?? '';
      _why.text = widget.goal!.why ?? '';
    }
  }

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
      if (_editingExpected != null) {
        await widget.service.updateGoal(
          _editingExpected!,
          title: _title.text,
          description: _description.text,
          why: _why.text,
        );
        if (mounted) Navigator.of(context).pop(_editingExpected!.id);
      } else {
        _pending ??= widget.service.prepareCreation(
          title: _title.text,
          description: _description.text,
          why: _why.text,
        ); // ??= 只在首次请求时赋值，重试不重新生成目标编号。
        await widget.service.create(_pending!);
        if (mounted) Navigator.of(context).pop(_pending!.id);
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _editResultUnknown = _editingExpected != null;
          _error = '暂时未能确认保存结果，输入已保留。请重试保存，或确认结果后继续编辑。';
        });
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  /// 发生未知保存错误后先查原编号，避免修改输入并生成第二份重复目标。
  Future<void> _resumeEditing() async {
    if (_saving || (_pending == null && _editingExpected == null)) return;
    setState(() => _saving = true);
    try {
      final saved = await widget.service.findById(
        (_editingExpected ?? _pending)!.id,
      );
      if (!mounted) return;
      if (_editingExpected != null) {
        final expected = _editingExpected!;
        if (saved != null &&
            saved.title == _title.text.trim() &&
            saved.description == _optional(_description.text) &&
            saved.why == _optional(_why.text) &&
            saved.status == expected.status) {
          Navigator.of(context).pop(saved.id); // 写入成功但回复丢失时，不再重复更新。
        } else if (saved != null &&
            saved.updatedAt == expected.updatedAt &&
            saved.title == expected.title &&
            saved.description == expected.description &&
            saved.why == expected.why &&
            saved.status == expected.status) {
          setState(() {
            _editResultUnknown = false; // 确认先前没有写入，继续保留用户这次填写的草稿。
            _error = null;
          });
        } else if (saved != null) {
          setState(() {
            _latestConflict = saved;
            _error = '目标已变化，原输入仍保留。确认后可放弃本次修改并读取最新内容。';
          });
        } else {
          setState(() => _error = '目标已不存在，请返回列表刷新。');
        }
      } else if (saved != null) {
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

  String? _optional(String value) => value.trim().isEmpty ? null : value.trim();

  void _adoptLatest() {
    final latest = _latestConflict;
    if (latest == null) return;
    setState(() {
      _editingExpected = latest;
      _title.text = latest.title;
      _description.text = latest.description ?? '';
      _why.text = latest.why ?? '';
      _latestConflict = null;
      _editResultUnknown = false;
      _error = null;
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    DetailPaneScope.maybeOf(
      context,
    )?.registerTopGuard(_mayLeave, route: ModalRoute.of(context));
  }

  /// 顶栏、系统返回、主导航切换共用草稿确认，守卫不自行关闭路由。
  Future<bool> _mayLeave() async {
    if (_saving || _closing) return false;
    final hasInput = _editingExpected == null
        ? _title.text.isNotEmpty ||
              _description.text.isNotEmpty ||
              _why.text.isNotEmpty
        : _title.text != widget.goal!.title ||
              _optional(_description.text) != widget.goal!.description ||
              _optional(_why.text) != widget.goal!.why;
    if (hasInput) {
      _closing = true;
      final discard = await AppConfirmDialog.show(
        context: context,
        title: widget.goal == null ? '离开本次填写？' : '放弃这次修改？',
        message: _pending == null && !_editResultUnknown
            ? '返回后，已填写的内容不会保存。'
            : '保存结果尚未确认。返回后输入将清空，若已保存，可在目标列表查看。',
        cancelText: '继续填写',
        confirmText: '离开',
      );
      _closing = false;
      if (!discard || !mounted) return false;
    }
    return mounted;
  }

  Future<void> _close() async {
    if (await _mayLeave() && mounted) Navigator.of(context).pop();
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
    final editable = !_saving && _pending == null && !_editResultUnknown;
    final theme = Theme.of(context);
    // PopScope 把系统返回也交给 _close，避免键盘/返回键绕过草稿保护。
    return PopScope<String>(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _close();
      },
      child: Scaffold(
        appBar: AppTopBar(
          title: widget.goal == null ? '新建目标' : '编辑目标',
          onBack: _close,
          canGoBack: !_saving,
        ),
        body: SafeArea(
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: AppLayout.maxPageWidth,
              ),
              child: SingleChildScrollView(
                padding: AppLayout.pagePadding(context),
                child: Form(
                  key: _formKey,
                  child: AppSectionCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          widget.goal == null ? '你希望做到什么？' : '调整目标内容',
                          style: theme.textTheme.titleLarge,
                        ),
                        const SizedBox(height: AppLayout.spaceXxl),
                        AppTextField(
                          key: const Key('goal-title-input'),
                          controller: _title,
                          readOnly: !editable,
                          label: '目标名称（必填）',
                          hint: '例如：能独立开发 Flutter 应用',
                          textInputAction: TextInputAction.next,
                          minLines: 1,
                          maxLines: 3,
                          validator: (value) =>
                              value == null || value.trim().isEmpty
                              ? '请填写目标名称'
                              : null,
                        ),
                        const SizedBox(height: AppLayout.spaceXl),
                        AppTextField(
                          key: const Key('goal-description-input'),
                          controller: _description,
                          readOnly: !editable,
                          label: '目标说明（选填）',
                          hint: '你希望达到什么程度？',
                          minLines: 3,
                          maxLines: 8,
                        ),
                        const SizedBox(height: AppLayout.spaceXl),
                        AppTextField(
                          key: const Key('goal-why-input'),
                          controller: _why,
                          readOnly: !editable,
                          label: '为什么想实现（选填）',
                          hint: '写给自己的一点提醒',
                          minLines: 2,
                          maxLines: 6,
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
                          TextButton(
                            onPressed: _saving ? null : _resumeEditing,
                            child: const Text('确认结果并继续编辑'),
                          ),
                          if (_latestConflict != null)
                            TextButton(
                              onPressed: _saving ? null : _adoptLatest,
                              child: const Text('放弃本次修改并读取最新内容'),
                            ),
                          const SizedBox(height: AppLayout.spaceMd),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        bottomNavigationBar: SafeArea(
          top: false,
          child: PageFooterBar(
            bottomPadding: 16 + MediaQuery.viewInsetsOf(context).bottom,
            child: FilledButton.icon(
              key: const Key('goal-save'),
              onPressed: _saving ? null : _save,
              icon: Icon(_saving ? Icons.hourglass_top : Icons.check),
              label: Text(
                _saving
                    ? '正在保存…'
                    : (_pending != null || _editResultUnknown
                          ? '重试保存'
                          : widget.goal == null
                          ? '创建目标'
                          : '保存修改'),
              ),
              style: FilledButton.styleFrom(
                minimumSize: const Size(0, AppLayout.actionMinHeight),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

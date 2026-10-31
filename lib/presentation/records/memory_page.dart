import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/theme/app_layout.dart';
import '../widgets/app_confirm_dialog.dart';
import '../widgets/app_empty_state.dart';
import '../widgets/app_section_card.dart';
import '../widgets/app_settings_row.dart';
import '../widgets/app_top_bar.dart';
import '../widgets/app_info_sheet.dart';
import 'record_scope.dart';
import 'package:uuid/uuid.dart';
import '../widgets/adaptive_sheet.dart';
import '../widgets/app_date_picker.dart';
import '../widgets/app_dropdown_form_field.dart';
import '../widgets/app_expansion.dart';

String _dateLabel(DateTime date) => '${date.year}年${date.month}月${date.day}日';
String _kindLabel(Object? kind) => switch (kind) {
  'preference' => '偏好',
  'constraint' => '临时约束',
  'observation' => '待验证观察',
  _ => '明确事实',
};

/// 日记本直接读取结构化记忆，保留来源、更正和忘记的业务规则。
class MemoryPage extends StatefulWidget {
  const MemoryPage({super.key});
  @override
  State<MemoryPage> createState() => _MemoryPageState();
}

class _MemoryPageState extends State<MemoryPage> {
  Future<Map<String, Object?>>? _data;
  final _search = TextEditingController();
  StreamSubscription<void>? _changes;
  int _offset = 0;
  bool _showExpired = false, _retrying = false;
  String? _error;
  void load({bool reset = false}) {
    if (!mounted) return;
    setState(() {
      if (reset) _offset = 0;
      _data = RecordScope.maybeOf(context)!.memory!.query(
        offset: _offset,
        includeExpired: _showExpired,
        search: _search.text.trim().isEmpty ? null : _search.text.trim(),
      );
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_data == null) {
      load();
      _changes = RecordScope.maybeOf(
        context,
      )!.analysis.changes.listen((_) => load());
    }
  }

  @override
  void dispose() {
    _changes?.cancel();
    _search.dispose();
    super.dispose();
  }

  Future<void> edit([Map<String, Object?>? entry]) async {
    final saved = await showAdaptiveSheet<bool>(
      context: context,
      isDismissible: false,
      enableDrag: false,
      builder: (_) => _MemoryEditor(entry: entry),
    );
    if (saved == true && mounted) load();
  }

  Future<void> forget(Map<String, Object?> entry) async {
    final yes = await AppConfirmDialog.show(
      context: context,
      title: '忘记这条记忆？',
      message: entry['content'] as String,
      cancelText: '保留',
      confirmText: '忘记',
    );
    if (!yes || !mounted) return;
    try {
      await RecordScope.maybeOf(context)!.memory!.forget(entry['id'] as String);
      if (mounted) load();
    } catch (_) {
      if (mounted) setState(() => _error = '未能忘记这条记忆，请重试');
    }
  }

  Future<void> retry(List jobs) async {
    setState(() => _retrying = true);
    try {
      final scope = RecordScope.maybeOf(context)!;
      for (final job in jobs) {
        await scope.analysis.store.retry('memory', job['target_id'] as String);
      }
      scope.analysis.wake();
      if (mounted) load();
    } catch (_) {
      if (mounted) setState(() => _error = '重新整理失败，请稍后重试');
    } finally {
      if (mounted) setState(() => _retrying = false);
    }
  }

  Widget memoryCard(Map<String, Object?> entry) {
    final expiry = entry['expires_at'] as int?;
    final expired =
        expiry != null && expiry <= DateTime.now().millisecondsSinceEpoch;
    final source = entry['source'] as String;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppLayout.spaceMd),
      child: AppSectionCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${_kindLabel(entry['kind'])}${expired
                        ? ' · 已过期'
                        : entry['certainty'] != 'stated'
                        ? ' · 待确认'
                        : ''}',
                    style: Theme.of(context).textTheme.labelMedium,
                  ),
                ),
                IconButton(
                  onPressed: () => edit(entry),
                  tooltip: '更正记忆',
                  icon: const Icon(Icons.edit_outlined),
                ),
                IconButton(
                  onPressed: () => forget(entry),
                  tooltip: '忘记记忆',
                  icon: const Icon(Icons.delete_outline),
                ),
              ],
            ),
            SelectableText(
              entry['content'] as String,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: AppLayout.spaceSm),
            AppExpansionTile(
              title: const Text('来源与有效期'),
              subtitle: Text(
                '${entry['goal_id'] == null ? '全局记忆' : entry['goalTitle'] ?? '目标记忆'} · ${_dateLabel(DateTime.fromMillisecondsSinceEpoch(entry['updated_at'] as int))}',
              ),
              insetHeader: false,
              children: [
                Text(entry['certainty'] == 'stated' ? '用户明确陈述' : '助手观察，尚待验证'),
                if (entry['user_edited'] == 1) const Text('已由你确认或更正'),
                Text(
                  '来源：${source.startsWith('conversation:') ? '助手对话中的用户消息' : source}',
                ),
                if (entry['sourceText'] != null)
                  SelectableText('原话：${entry['sourceText']}'),
                Text(
                  expiry == null
                      ? '有效期：长期有效'
                      : '有效期：至 ${_dateLabel(DateTime.fromMillisecondsSinceEpoch(expiry))}${expired ? '，已停止自动载入' : ''}',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppTopBar(
      title: 'AI 日记本',
      actions: [
        IconButton(
          tooltip: '日记本说明',
          icon: const Icon(Icons.info_outline),
          onPressed: () => showAppInfoSheet(
            context,
            'AI 日记本',
            '这里保存助手记住的偏好、事实、约束和待验证观察。你可以检查来源、更正或忘记。过期内容不再自动载入；任务进度仍从任务事实与目标摘要读取。',
          ),
        ),
        IconButton.filled(
          onPressed: edit,
          tooltip: '添加记忆',
          style: IconButton.styleFrom(
            foregroundColor: Theme.of(context).colorScheme.onPrimary,
          ),
          icon: const Icon(Icons.add),
        ),
      ],
    ),
    body: SafeArea(
      top: false,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: AppLayout.maxPageWidth),
          child: FutureBuilder<Map<String, Object?>>(
            future: _data,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return AppEmptyState(
                  title: '日记本读取失败',
                  actions: OutlinedButton.icon(
                    onPressed: load,
                    icon: const Icon(Icons.refresh),
                    label: const Text('重试'),
                  ),
                );
              }
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final data = snapshot.data!;
              final items = data['items'] as List<Map<String, Object?>>;
              final extraction = data['extraction'] as Map?;
              final jobs = extraction?['retriable'] as List? ?? const [];
              return ListView(
                padding: AppLayout.pagePadding(context),
                children: [
                  TextField(
                    controller: _search,
                    textInputAction: TextInputAction.search,
                    decoration: InputDecoration(
                      hintText: '搜索助手记住的内容',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: IconButton(
                        tooltip: '搜索记忆',
                        onPressed: () => load(reset: true),
                        icon: const Icon(Icons.arrow_forward),
                      ),
                    ),
                    onSubmitted: (_) => load(reset: true),
                  ),
                  const SizedBox(height: AppLayout.spaceMd),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '共 ${data['total']} 条记忆',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ),
                      FilterChip(
                        label: const Text('包含过期'),
                        selected: _showExpired,
                        onSelected: (v) {
                          _showExpired = v;
                          load(reset: true);
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: AppLayout.spaceLg),
                  if ((extraction?['pending'] as int? ?? 0) > 0 ||
                      jobs.isNotEmpty) ...[
                    AppSectionCard(
                      padding: EdgeInsets.zero,
                      child: AppSettingsRow(
                        icon: Icons.auto_awesome_outlined,
                        title: jobs.isEmpty ? '正在整理新的记忆' : '部分记忆尚未整理完成',
                        subtitle: jobs.isEmpty
                            ? '${extraction?['pending']} 项等待整理'
                            : '点击重试整理',
                        enabled: !_retrying,
                        onTap: jobs.isEmpty ? null : () => retry(jobs),
                      ),
                    ),
                    const SizedBox(height: AppLayout.spaceMd),
                  ],
                  if (_error != null)
                    Text(
                      _error!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  if (items.isEmpty)
                    AppEmptyState(
                      title: _offset > 0
                          ? '这一页没有记忆'
                          : _search.text.trim().isNotEmpty
                          ? '没有找到相关记忆'
                          : '还没有记忆',
                      details: Text(
                        _offset > 0
                            ? '可以返回上一页查看其他记忆。'
                            : '告诉助手你的偏好，或添加一条希望它记住的事。',
                      ),
                      actions: OutlinedButton.icon(
                        onPressed: edit,
                        icon: const Icon(Icons.add),
                        label: const Text('添加记忆'),
                      ),
                    ),
                  for (final entry in items) memoryCard(entry),
                  if (_offset > 0 || data['nextOffset'] != null)
                    Row(
                      children: [
                        IconButton(
                          tooltip: '上一页',
                          onPressed: _offset == 0
                              ? null
                              : () {
                                  _offset -= 20;
                                  load();
                                },
                          icon: const Icon(Icons.chevron_left),
                        ),
                        Expanded(
                          child: Text(
                            '第 ${_offset ~/ 20 + 1} 页',
                            textAlign: TextAlign.center,
                          ),
                        ),
                        IconButton(
                          tooltip: '下一页',
                          onPressed: data['nextOffset'] == null
                              ? null
                              : () {
                                  _offset = data['nextOffset'] as int;
                                  load();
                                },
                          icon: const Icon(Icons.chevron_right),
                        ),
                      ],
                    ),
                ],
              );
            },
          ),
        ),
      ),
    ),
  );
}

/// 编辑弹层自己持有输入控制器，关闭动画结束前不提前释放。
class _MemoryEditor extends StatefulWidget {
  const _MemoryEditor({this.entry});
  final Map<String, Object?>? entry;
  @override
  State<_MemoryEditor> createState() => _MemoryEditorState();
}

class _MemoryEditorState extends State<_MemoryEditor> {
  late final _content = TextEditingController(
    text: widget.entry?['content'] as String? ?? '',
  );
  late final _source = TextEditingController(
    text: widget.entry?['source'] as String? ?? '用户手动记录',
  );
  late String _kind = widget.entry?['kind'] as String? ?? 'fact';
  late DateTime? _expiry = widget.entry?['expires_at'] == null
      ? null
      : DateTime.fromMillisecondsSinceEpoch(widget.entry!['expires_at'] as int);
  final _id = const Uuid().v4();
  bool _saving = false;
  String? _error;
  @override
  void dispose() {
    _content.dispose();
    _source.dispose();
    super.dispose();
  }

  Future<void> save() async {
    if (_saving) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await RecordScope.maybeOf(context)!.memory!.save({
        'id': widget.entry?['id'] ?? _id,
        'goalId': widget.entry?['goal_id'],
        'content': _content.text.trim(),
        'kind': _kind,
        'certainty': _kind == 'observation' ? 'unverified' : 'stated',
        'source': _source.text.trim(),
        'conflictKey': widget.entry?['conflict_key'] ?? _content.text.trim(),
        'expiresAt': _expiry?.millisecondsSinceEpoch,
      }, userEdited: true);
      if (mounted) Navigator.pop(context, true);
    } catch (_) {
      if (mounted) setState(() => _error = '保存失败，请检查内容、来源和有效期后重试');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> chooseExpiry() async {
    final now = DateTime.now();
    final picked = await showAppDatePicker(
      context: context,
      initialDate: _expiry ?? now,
      currentDate: now,
      firstDate: DateTime(2000),
      lastDate: DateTime(now.year + 20),
      title: '记忆有效至',
    );
    if (picked != null && mounted) {
      setState(
        () => _expiry = DateTime(
          picked.year,
          picked.month,
          picked.day,
          23,
          59,
          59,
          999,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) => PopScope<bool>(
    canPop: !_saving,
    child: SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * .85,
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppLayout.spaceXxl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  widget.entry == null ? '添加记忆' : '更正记忆',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: AppLayout.spaceLg),
                TextField(
                  key: const Key('memory-content'),
                  controller: _content,
                  enabled: !_saving,
                  minLines: 3,
                  maxLines: 8,
                  maxLength: 1000,
                  decoration: const InputDecoration(labelText: '内容'),
                ),
                const SizedBox(height: AppLayout.spaceMd),
                AppDropdownFormField<String>(
                  initialValue: _kind,
                  decoration: const InputDecoration(labelText: '类型'),
                  items: [
                    for (final kind in [
                      'preference',
                      'fact',
                      'constraint',
                      'observation',
                    ])
                      DropdownMenuItem(
                        value: kind,
                        child: Text(_kindLabel(kind)),
                      ),
                  ],
                  onChanged: _saving ? null : (v) => setState(() => _kind = v!),
                ),
                const SizedBox(height: AppLayout.spaceMd),
                AppSectionCard(
                  padding: EdgeInsets.zero,
                  child: Column(
                    children: [
                      AppSettingsRow(
                        icon: Icons.event_outlined,
                        title: '有效期',
                        subtitle: _expiry == null
                            ? '长期有效'
                            : '至 ${_dateLabel(_expiry!)} 当天结束',
                        enabled: !_saving,
                        onTap: chooseExpiry,
                      ),
                      if (_expiry != null)
                        AppSettingsRow(
                          icon: Icons.all_inclusive,
                          title: '设为长期有效',
                          enabled: !_saving,
                          onTap: () => setState(() => _expiry = null),
                        ),
                    ],
                  ),
                ),
                AppExpansionTile(
                  title: const Text('记忆来源'),
                  children: [
                    TextField(
                      controller: _source,
                      enabled: !_saving,
                      decoration: const InputDecoration(labelText: '来源'),
                    ),
                  ],
                ),
                if (_error != null)
                  Text(
                    _error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                const SizedBox(height: AppLayout.spaceLg),
                FilledButton(
                  key: const Key('memory-save'),
                  onPressed: _saving ? null : save,
                  child: Text(_saving ? '正在保存…' : '保存'),
                ),
                const SizedBox(height: AppLayout.spaceSm),
                OutlinedButton(
                  onPressed: _saving ? null : () => Navigator.pop(context),
                  child: const Text('取消'),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

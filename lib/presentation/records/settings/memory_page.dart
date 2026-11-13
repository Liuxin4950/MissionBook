import '../../../core/theme/colors.dart';
import '../../../domain/entities/analysis_scope.dart';
import '../../../domain/entities/goal.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import '../../../core/theme/app_layout.dart';
import '../../../application/goals/goal_service.dart';
import '../../widgets/app_confirm_dialog.dart';
import '../../widgets/app_empty_state.dart';
import '../../widgets/app_section_card.dart';
import '../../widgets/app_settings_row.dart';
import '../../widgets/app_top_bar.dart';
import '../../widgets/app_info_sheet.dart';
import '../shared/record_scope.dart';
import 'package:uuid/uuid.dart';
import '../../widgets/adaptive_sheet.dart';
import '../../widgets/app_date_picker.dart';
import '../../widgets/app_dropdown_form_field.dart';
import '../../widgets/app_expansion.dart';
import '../../../application/errors/user_error_message.dart';

String _dateLabel(DateTime date) => '${date.year}年${date.month}月${date.day}日';
String _layerText(Object? layer) => switch (layer) {
  'identity' => '身份与稳定偏好',
  'procedural' => '习惯流程',
  'episodic' => '情节记忆',
  'observation' => '待验证观察',
  _ => '一般事实',
};
String _certaintyText(Object? certainty) => switch (certainty) {
  'stated' => '用户确认',
  'inferred' => '助手归纳',
  _ => '未验证',
};

/// 只有 stated 且非观察层才进入稳定事实块；其余只参与检索与观察区。
bool _unverified(Map<String, Object?> entry) =>
    entry['layer'] == 'observation' || entry['certainty'] != 'stated';

String _loadLabel(Map<String, Object?> entry, bool expired) {
  if (expired) return '已过期，不载入';
  if (_unverified(entry)) return '不作事实，仅观察区';
  return entry['goal_id'] != null ? '引用该目标时载入候选，按相关性与预算选入' : '全局候选，按相关性与预算选入';
}

/// 日记本直接读取结构化记忆，保留来源、更正和忘记的业务规则。
class MemoryPage extends StatefulWidget {
  const MemoryPage({super.key, this.clock = DateTime.now});
  final DateTime Function() clock;
  @override
  State<MemoryPage> createState() => _MemoryPageState();
}

class _MemoryPageState extends State<MemoryPage> {
  Future<Map<String, Object?>>? _data;
  final _search = TextEditingController();
  StreamSubscription<void>? _changes;
  StreamSubscription<void>? _goalChanges;
  Future<List<Goal>>? _goalChoices;
  GoalService? _goals;
  int _offset = 0;
  String? _goalId;
  String? _layer;
  bool _showExpired = false, _retrying = false;
  String? _error;
  void load({bool reset = false}) {
    if (!mounted) return;
    setState(() {
      if (reset) _offset = 0;
      _data = RecordScope.maybeOf(context)!.memory!.query(
        offset: _offset,
        goalId: _goalId,
        includeExpired: _showExpired,
        layer: _layer,
        search: _search.text.trim().isEmpty ? null : _search.text.trim(),
      );
    });
  }

  Future<List<Goal>> _loadGoals(GoalService goals) => Future.wait([
    goals.findAll(),
    goals.findDropped(),
  ]).then((groups) => [...groups[0], ...groups[1]]);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final scope = RecordScope.maybeOf(context)!;
    if (_goals == null && scope.goals != null) {
      final goals = scope.goals!;
      _goals = goals;
      _goalChoices = _loadGoals(goals);
      _goalChanges = goals.changes.listen((_) {
        if (mounted) setState(() => _goalChoices = _loadGoals(goals));
      });
    }
    if (_data == null) {
      load();
      _changes = scope.analysis.changes.listen((_) => load());
    }
  }

  @override
  void dispose() {
    _changes?.cancel();
    _goalChanges?.cancel();
    _search.dispose();
    super.dispose();
  }

  Future<void> edit([Map<String, Object?>? entry]) async {
    final saved = await showAdaptiveSheet<bool>(
      context: context,
      isDismissible: false,
      enableDrag: false,
      builder: (_) => _MemoryEditor(entry: entry, clock: widget.clock),
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
    setState(() => _error = null);
    try {
      await RecordScope.maybeOf(context)!.memory!.forget(entry['id'] as String);
      if (mounted) load();
    } catch (error) {
      if (mounted) {
        setState(
          () => _error = userErrorMessage(error, fallback: '未能忘记这条记忆，请重试'),
        );
      }
    }
  }

  Future<void> retry(List<Map<String, Object?>> jobs) async {
    setState(() {
      _retrying = true;
      _error = null;
    });
    try {
      final scope = RecordScope.maybeOf(context)!;
      for (final job in jobs) {
        await scope.analysis.requestManual(
          AnalysisScope.memory,
          job['target_id'] as String,
        );
      }
      if (mounted) load();
    } catch (error) {
      if (mounted) {
        setState(
          () => _error = userErrorMessage(error, fallback: '重新整理失败，请稍后重试'),
        );
      }
    } finally {
      if (mounted) setState(() => _retrying = false);
    }
  }

  Widget memoryCard(Map<String, Object?> entry) {
    final expiry = entry['expires_at'] as int?;
    final expired =
        expiry != null && expiry <= widget.clock().millisecondsSinceEpoch;
    final unverified = _unverified(entry);
    final source =
        entry['source_ref'] as String? ??
        switch (entry['source_kind']) {
          'user' => '用户明确陈述',
          'manual' => '用户手动记录',
          'extraction' => '后台抽取',
          'reflection' => '反思整理',
          _ => '助手',
        };
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
                    '${_layerText(entry['layer'])} · '
                    '${_certaintyText(entry['certainty'])} · '
                    '重要度 ${entry['importance'] ?? 50} · '
                    '${_loadLabel(entry, expired)}',
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
                Text(unverified ? '未验证：只参与检索与观察区，不作事实' : '用户确认事实：可进入稳定事实块'),
                if (entry['user_edited'] == 1) const Text('已由你确认或更正'),
                if (entry['topic_name'] != null)
                  Text('主题：${entry['topic_name']}'),
                if (entry['topic_aliases'] != null)
                  Text('别名：${entry['topic_aliases']}'),
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
            '这里保存助手记住的偏好、事实、约束和未验证观察。每轮从有界候选中按相关性与预算选择全局记忆；引用目标时也可选择该目标的记忆，话题命中优先，不保证每条都载入。观察区明确标注不是事实。你可以检查来源、更正或忘记。过期内容不再自动载入；任务进度仍从任务事实与目标摘要读取。',
          ),
        ),
        FutureBuilder<Map<String, Object?>>(
          future: _data,
          builder: (context, snapshot) {
            // 空日记本的主要操作在插画下；已有内容时放到顶栏。
            if ((snapshot.data?['total'] as int? ?? 0) == 0) {
              return const SizedBox.shrink();
            }
            return IconButton.filled(
              onPressed: edit,
              tooltip: '添加记忆',
              style: IconButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.onPrimary,
              ),
              icon: const Icon(Icons.add_rounded),
            );
          },
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
              final extraction = data['extraction'] as Map<String, dynamic>?;
              final jobs =
                  (extraction?['retriable'] as List<dynamic>? ?? const [])
                      .whereType<Map<String, Object?>>()
                      .toList();
              final padding = AppLayout.pagePadding(context);
              return CustomScrollView(
                slivers: [
                  SliverPadding(
                    padding: padding.copyWith(bottom: 0),
                    sliver: SliverList.list(
                      children: [
                        _MemoryToolbar(
                          search: _search,
                          total: data['total'] as int,
                          showExpired: _showExpired,
                          layer: _layer,
                          goalId: _goalId,
                          goals: _goals == null ? null : _goalChoices,
                          onSearch: () => load(reset: true),
                          onShowExpired: (value) {
                            _showExpired = value;
                            load(reset: true);
                          },
                          onLayer: (value) {
                            _layer = value;
                            load(reset: true);
                          },
                          onGoal: (value) {
                            _goalId = value;
                            load(reset: true);
                          },
                          onRetryGoals: () => setState(
                            () => _goalChoices = _loadGoals(_goals!),
                          ),
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
                            style: TextStyle(color: AppColors.error),
                          ),
                      ],
                    ),
                  ),
                  if (items.isEmpty)
                    SliverLayoutBuilder(
                      builder: (context, constraints) => SliverToBoxAdapter(
                        child: ConstrainedBox(
                          // 扣掉搜索区的实际高度；内容超出剩余空间时自然滚动。
                          constraints: BoxConstraints(
                            minHeight:
                                (constraints.viewportMainAxisExtent -
                                        constraints.precedingScrollExtent)
                                    .clamp(0.0, double.infinity),
                          ),
                          child: Align(
                            alignment: const Alignment(0, -0.4),
                            child: Padding(
                              padding: padding.copyWith(top: 0),
                              child: AppEmptyState(
                                asset:
                                    _offset == 0 && _search.text.trim().isEmpty
                                    ? 'assets/illustrations/memory-notebook.png'
                                    : null,
                                horizontalWhenWide: true,
                                title: _offset > 0
                                    ? '这一页没有记忆'
                                    : _search.text.trim().isNotEmpty
                                    ? '没有找到相关记忆'
                                    : '还没有记忆',
                                details: Text(
                                  _offset > 0
                                      ? '返回上一页，继续查看。'
                                      : _search.text.trim().isNotEmpty
                                      ? '换个关键词，或查看全部记忆。'
                                      : '偏好、小事，都可以记在这里。',
                                ),
                                actions: _offset > 0
                                    ? OutlinedButton.icon(
                                        onPressed: () {
                                          _offset -= 20;
                                          load();
                                        },
                                        icon: const Icon(Icons.chevron_left),
                                        label: const Text('上一页'),
                                      )
                                    : _search.text.trim().isNotEmpty
                                    ? OutlinedButton.icon(
                                        onPressed: () {
                                          _search.clear();
                                          load(reset: true);
                                        },
                                        icon: const Icon(Icons.close_rounded),
                                        label: const Text('清除搜索'),
                                      )
                                    : ConstrainedBox(
                                        constraints: const BoxConstraints(
                                          minHeight: AppLayout.actionMinHeight,
                                        ),
                                        child: FilledButton.icon(
                                          onPressed: edit,
                                          icon: const Icon(Icons.add_rounded),
                                          label: const Text('添加第一条记忆'),
                                        ),
                                      ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    )
                  else
                    SliverPadding(
                      padding: padding.copyWith(top: 0),
                      sliver: SliverList.list(
                        children: [
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
                      ),
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

/// 根据正文可用宽度与字号切换工具栏；不按整个窗口猜测面板宽度。
class _MemoryToolbar extends StatelessWidget {
  const _MemoryToolbar({
    required this.search,
    required this.total,
    required this.showExpired,
    required this.layer,
    required this.goalId,
    required this.goals,
    required this.onSearch,
    required this.onShowExpired,
    required this.onLayer,
    required this.onGoal,
    required this.onRetryGoals,
  });

  final TextEditingController search;
  final int total;
  final bool showExpired;
  final String? layer;
  final String? goalId;
  final Future<List<Goal>>? goals;
  final VoidCallback onSearch;
  final ValueChanged<bool> onShowExpired;
  final ValueChanged<String?> onLayer;
  final ValueChanged<String?> onGoal;
  final VoidCallback onRetryGoals;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final inline =
          constraints.maxWidth >=
          AppLayout.mediumBreakpoint *
              MediaQuery.textScalerOf(context).scale(1);
      final theme = Theme.of(context);
      final field = TextField(
        controller: search,
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          hintText: '搜索记忆',
          prefixIcon: const Icon(Icons.search_rounded),
          suffixIcon: IconButton(
            tooltip: '搜索记忆',
            onPressed: onSearch,
            icon: const Icon(Icons.arrow_forward),
          ),
        ),
        onSubmitted: (_) => onSearch(),
      );
      final filter = FilterChip(
        label: const Text('包含过期'),
        selected: showExpired,
        onSelected: onShowExpired,
      );
      final layerFilter = AppDropdownFormField<String?>(
        key: ValueKey('memory-layer-${layer ?? 'all'}'),
        initialValue: layer,
        style: theme.textTheme.bodySmall,
        decoration: const InputDecoration(labelText: '记忆层'),
        items: const [
          DropdownMenuItem(value: null, child: Text('全部层')),
          DropdownMenuItem(value: 'identity', child: Text('身份与偏好')),
          DropdownMenuItem(value: 'semantic', child: Text('一般事实')),
          DropdownMenuItem(value: 'episodic', child: Text('情节记忆')),
          DropdownMenuItem(value: 'procedural', child: Text('习惯流程')),
          DropdownMenuItem(value: 'observation', child: Text('待验证观察')),
        ],
        onChanged: onLayer,
      );
      final goalFilter = goals == null
          ? null
          : FutureBuilder<List<Goal>>(
              future: goals,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Row(
                    children: [
                      Expanded(
                        child: Text(
                          '目标读取失败，暂不能按目标筛选。',
                          style: theme.textTheme.bodyMedium,
                        ),
                      ),
                      TextButton(
                        onPressed: onRetryGoals,
                        child: const Text('重试'),
                      ),
                    ],
                  );
                }
                final items = snapshot.data ?? const <Goal>[];
                return AppDropdownFormField<String?>(
                  key: ValueKey('memory-goal-${goalId ?? 'all'}'),
                  initialValue: goalId,
                  style: theme.textTheme.bodySmall,
                  decoration: const InputDecoration(labelText: '目标范围（含全局记忆）'),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('全部记忆')),
                    for (final goal in items)
                      DropdownMenuItem(
                        value: goal.id,
                        child: Text(
                          goal.title,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                  onChanged: onGoal,
                );
              },
            );
      final count = Text(
        '$total 条记忆',
        style: Theme.of(context).textTheme.bodyMedium,
      );
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (inline) ...[
            Row(
              children: [
                Expanded(child: field),
                const SizedBox(width: AppLayout.spaceLg),
                filter,
              ],
            ),
            if (goalFilter != null) ...[
              const SizedBox(height: AppLayout.spaceMd),
              Row(
                children: [
                  Expanded(child: layerFilter),
                  const SizedBox(width: AppLayout.spaceMd),
                  Expanded(child: goalFilter),
                ],
              ),
            ] else ...[
              const SizedBox(height: AppLayout.spaceMd),
              layerFilter,
            ],
            if (total > 0) ...[
              const SizedBox(height: AppLayout.spaceMd),
              count,
            ],
          ] else ...[
            field,
            const SizedBox(height: AppLayout.spaceMd),
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: AppLayout.spaceMd,
              runSpacing: AppLayout.spaceSm,
              children: [if (total > 0) count, filter],
            ),
            const SizedBox(height: AppLayout.spaceMd),
            layerFilter,
            if (goalFilter != null) ...[
              const SizedBox(height: AppLayout.spaceMd),
              goalFilter,
            ],
          ],
        ],
      );
    },
  );
}

/// 编辑弹层自己持有输入控制器，关闭动画结束前不提前释放。
class _MemoryEditor extends StatefulWidget {
  const _MemoryEditor({this.entry, required this.clock});
  final DateTime Function() clock;
  final Map<String, Object?>? entry;
  @override
  State<_MemoryEditor> createState() => _MemoryEditorState();
}

class _MemoryEditorState extends State<_MemoryEditor> {
  late final _content = TextEditingController(
    text: widget.entry?['content'] as String? ?? '',
  );
  late final _source = TextEditingController(
    text: widget.entry?['source_ref'] as String? ?? '用户手动记录',
  );
  late final _topic = TextEditingController(
    text: widget.entry?['topic_name'] as String? ?? '',
  );
  late final _aliases = TextEditingController(
    text: widget.entry?['topic_aliases'] as String? ?? '',
  );
  late String _layer = widget.entry?['layer'] as String? ?? 'semantic';
  late String _certainty = widget.entry?['certainty'] as String? ?? 'stated';
  late int _importance = widget.entry?['importance'] as int? ?? 50;
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
    _topic.dispose();
    _aliases.dispose();
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
        'layer': _layer,
        'certainty': _layer == 'observation' ? 'unverified' : _certainty,
        'topic': _topic.text.trim().isEmpty
            ? _content.text.trim()
            : _topic.text.trim(),
        'aliases': [
          for (final alias in _aliases.text.split(RegExp(r'[,，、\s]+')))
            if (alias.trim().isNotEmpty) alias.trim(),
        ],
        'importance': _importance,
        'sourceKind': widget.entry?['source_kind'] ?? 'manual',
        'sourceRef': _source.text.trim(),
        'expiresAt': _expiry?.millisecondsSinceEpoch,
      }, userEdited: true);
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (mounted) {
        setState(
          () => _error = userErrorMessage(
            error,
            fallback: '保存失败，请检查内容、来源和有效期后重试',
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> chooseExpiry() async {
    final now = widget.clock();
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
                  initialValue: _layer,
                  decoration: const InputDecoration(labelText: '层级'),
                  items: [
                    for (final layer in [
                      'identity',
                      'semantic',
                      'episodic',
                      'procedural',
                      'observation',
                    ])
                      DropdownMenuItem(
                        value: layer,
                        child: Text(_layerText(layer)),
                      ),
                  ],
                  onChanged: _saving
                      ? null
                      : (v) => setState(() {
                          _layer = v!;
                          if (_layer == 'observation') {
                            _certainty = 'unverified';
                          }
                        }),
                ),
                const SizedBox(height: AppLayout.spaceMd),
                AppDropdownFormField<String>(
                  initialValue: _certainty,
                  decoration: const InputDecoration(labelText: '确认程度'),
                  items: [
                    for (final certainty in [
                      'stated',
                      'inferred',
                      'unverified',
                    ])
                      DropdownMenuItem(
                        value: certainty,
                        child: Text(_certaintyText(certainty)),
                      ),
                  ],
                  onChanged: _saving || _layer == 'observation'
                      ? null
                      : (v) => setState(() => _certainty = v!),
                ),
                const SizedBox(height: AppLayout.spaceMd),
                AppDropdownFormField<int>(
                  key: const Key('memory-importance'),
                  initialValue: _importance,
                  decoration: const InputDecoration(labelText: '重要度（1–100）'),
                  items: [
                    for (var value = 1; value <= 100; value++)
                      DropdownMenuItem(value: value, child: Text('$value')),
                  ],
                  onChanged: _saving
                      ? null
                      : (value) => setState(() => _importance = value!),
                ),
                const SizedBox(height: AppLayout.spaceMd),
                TextField(
                  controller: _topic,
                  enabled: !_saving,
                  decoration: const InputDecoration(
                    labelText: '主题（可选）',
                    helperText: '留空时使用正文；同一主题的新说法不会覆盖原事实',
                  ),
                ),
                const SizedBox(height: AppLayout.spaceMd),
                TextField(
                  key: const Key('memory-aliases'),
                  controller: _aliases,
                  enabled: !_saving,
                  decoration: const InputDecoration(
                    labelText: '同义别名（可选）',
                    helperText: '用逗号分隔；用于检索与每轮自动命中，例如“晨跑，早上跑步”',
                  ),
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
                  Text(_error!, style: TextStyle(color: AppColors.error)),
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

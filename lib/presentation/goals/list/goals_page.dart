import 'dart:async';
import 'package:flutter/material.dart';
import '../../widgets/detail_pane.dart';

import '../../../application/goals/goal_service.dart';
import '../../../application/missions/mission_service.dart';
import '../../../core/theme/app_layout.dart';
import '../../widgets/adaptive_sheet.dart';
import '../../widgets/app_page_header.dart';
import '../../../core/theme/colors.dart';
import '../../../domain/entities/goal.dart';
import '../detail/goal_detail_page.dart';
import '../form/goal_form_page.dart';
import '../outline/goal_outline_section.dart';
import '../shared/goal_record_summary.dart';
import '../shared/goal_status_display.dart';
import '../form/goal_import_section.dart';

/// 目标导航页：读取正式目标、创建目标并进入详情。
class GoalsPage extends StatefulWidget {
  const GoalsPage({super.key, required this.service, this.missionService});
  final GoalService service;
  final MissionService? missionService;
  @override
  State<GoalsPage> createState() => _GoalsPageState();
}

class _GoalsPageState extends State<GoalsPage> with WidgetsBindingObserver {
  late Future<List<Goal>> _goals;
  StreamSubscription<void>? _changes;
  bool _opening = false; // 防止连续点击叠加两个创建或详情页面。
  GoalStatus _selectedStatus = GoalStatus.active;
  bool _importOpen = false;
  final _importKey = GlobalKey<GoalImportSectionState>();

  Future<void> _chooseNewGoal() async {
    if (_opening) return;
    _opening = true;
    String? choice;
    try {
      choice = await showAdaptiveSheet<String>(
        context: context,
        constraints: const BoxConstraints(maxWidth: AppLayout.maxPageWidth),
        builder: (sheetContext) => SafeArea(
          child: Padding(
            padding: AppLayout.pagePadding(sheetContext),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  '新建目标',
                  style: Theme.of(sheetContext).textTheme.titleLarge,
                ),
                const SizedBox(height: 16),
                ListTile(
                  key: const Key('goal-create-manual'),
                  leading: const Icon(Icons.edit_outlined),
                  title: const Text('手动创建'),
                  subtitle: const Text('填写名称、说明与原因'),
                  onTap: () => Navigator.pop(sheetContext, 'manual'),
                ),
                ListTile(
                  key: const Key('goal-create-import'),
                  leading: const Icon(Icons.file_upload_outlined),
                  title: const Text('导入 JSON 大纲'),
                  subtitle: const Text('先校验并预览完整目标路径'),
                  onTap: () => Navigator.pop(sheetContext, 'import'),
                ),
              ],
            ),
          ),
        ),
      );
    } finally {
      _opening = false;
    }
    if (!mounted) return;
    if (choice == 'manual') await _create();
    if (choice == 'import') setState(() => _importOpen = true);
  }

  Future<void> _closeImport() async {
    if (!await (_importKey.currentState?.prepareToCollapse() ??
        Future.value(true))) {
      return;
    }
    if (mounted) setState(() => _importOpen = false);
  }

  void _imported(String id) {
    if (!mounted) return;
    setState(() {
      _importOpen = false;
      _selectedStatus = GoalStatus.active;
      _goals = _load();
    });
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('目标和完整路径已创建')));
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _listen();
  }

  /// 首次读取列表并登记保存通知；通知到来时重新查询正式记录。
  void _listen() {
    _goals = _load();
    _changes = widget.service.changes.listen((_) => _refresh());
  }

  /// 发起一次查询，把等待结果的 Future 留给页面展示。
  Future<List<Goal>> _load() {
    final result = _selectedStatus == GoalStatus.dropped
        ? widget.service.findDropped()
        : widget.service.findAll();
    result.ignore(); // IndexedStack 中页面可能暂不可见，错误仍交给 FutureBuilder 展示。
    return result;
  }

  /// 更换当前查询；只触发读取，不修改目标或任务。
  void _refresh() {
    if (mounted) {
      setState(() {
        _goals = _load(); // 这里只替换 Future；setState 回调本身不能返回 Future。
      });
    }
  }

  void _selectStatus(GoalStatus value) {
    if (_selectedStatus == value) return;
    setState(() {
      _selectedStatus = value;
      _goals = _load();
    });
  }

  @override
  void didUpdateWidget(covariant GoalsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.service != widget.service) {
      unawaited(_changes?.cancel());
      _listen();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refresh();
  }

  /// 打开表单，保存后用返回的编号进入正式详情。
  Future<void> _create() async {
    if (_opening) return;
    _opening = true;
    try {
      final id = await openDetailPane<String>(
        context,
        label: '新建目标',
        builder: (_) => GoalFormPage(service: widget.service),
      ); // 表单保存成功才返回目标编号，放弃填写返回 null。
      if (!mounted) return;
      if (id != null) _selectStatus(GoalStatus.active);
      _refresh();
      if (id != null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('目标已创建')));
      }
    } finally {
      _opening = false;
      _refresh();
    }
  }

  /// 点击列表项时打开同一目标的只读详情，返回后刷新列表。
  Future<void> _open(Goal goal) async {
    if (_opening) return;
    _opening = true;
    try {
      await openDetailPane<void>(
        context,
        label: '目标详情',
        builder: (_) => GoalDetailPage(
          service: widget.service,
          goalId: goal.id,
          missionService: widget.missionService,
        ),
      );
    } finally {
      _opening = false;
      _refresh();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_changes?.cancel());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: AppLayout.maxPageWidth),
          child: FutureBuilder<List<Goal>>(
            future: _goals,
            builder: (context, snapshot) {
              final waiting =
                  !snapshot.hasData &&
                  snapshot.connectionState != ConnectionState.done;
              final goals = snapshot.data ?? const <Goal>[];
              final visible = [
                for (final goal in goals)
                  if (goal.status == _selectedStatus) goal,
              ];
              return RefreshIndicator(
                onRefresh: () async {
                  _refresh();
                  try {
                    await _goals;
                  } catch (_) {
                    /* 错误由上面的分支展示。 */
                  }
                },
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: AppLayout.pagePadding(context),
                  children: [
                    AppPageHeader(
                      title: '目标',
                      subtitle: Text(
                        waiting
                            ? '正在读取目标…'
                            : snapshot.hasError
                            ? '目标暂时无法读取'
                            : visible.isEmpty &&
                                  _selectedStatus == GoalStatus.active
                            ? '给接下来的行动一个方向'
                            : '${visible.length} 个${_selectedStatus == GoalStatus.dropped
                                  ? '已放弃'
                                  : _selectedStatus == GoalStatus.paused
                                  ? '已搁置'
                                  : _selectedStatus == GoalStatus.achieved
                                  ? '已达成'
                                  : '进行中'}目标',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      action: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          PopupMenuButton<GoalStatus>(
                            key: const Key('goal-more-filters'),
                            tooltip: '更多目标分类',
                            onSelected: _selectStatus,
                            itemBuilder: (_) => const [
                              PopupMenuItem(
                                value: GoalStatus.dropped,
                                child: Text('已放弃的目标'),
                              ),
                            ],
                            icon: const Icon(Icons.more_horiz),
                          ),
                          IconButton.filled(
                            key: const Key('goal-create'),
                            tooltip: '新建目标',
                            onPressed: _chooseNewGoal,
                            style: IconButton.styleFrom(
                              fixedSize: const Size(48, 48),
                              shape: const CircleBorder(),
                            ),
                            icon: const Icon(
                              Icons.add,
                              color: AppColors.onPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    _statusTabs(context),
                    const SizedBox(height: 20),
                    if (_importOpen) ...[
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton.icon(
                          onPressed: _closeImport,
                          icon: const Icon(Icons.close),
                          label: const Text('收起导入区'),
                        ),
                      ),
                      GoalImportSection(
                        key: _importKey,
                        service: widget.service,
                        onImported: _imported,
                      ),
                      const SizedBox(height: 20),
                    ],
                    if (_selectedStatus == GoalStatus.dropped)
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton.icon(
                          onPressed: () => _selectStatus(GoalStatus.active),
                          icon: const Icon(Icons.arrow_back),
                          label: const Text('返回进行中'),
                        ),
                      ),
                    if (waiting)
                      const Padding(
                        padding: EdgeInsets.all(40),
                        child: Center(child: CircularProgressIndicator()),
                      )
                    else if (snapshot.hasError)
                      Column(
                        children: [
                          const Text('暂时无法读取目标，你的数据不会被清除'),
                          TextButton(
                            onPressed: _refresh,
                            child: const Text('重试'),
                          ),
                        ],
                      )
                    else if (visible.isEmpty)
                      _empty(context),
                    for (final (index, goal) in visible.indexed)
                      Padding(
                        key: ValueKey(goal.id), // 刷新列表时让同一个目标保留路径展开状态。
                        padding: const EdgeInsets.only(bottom: 16),
                        child: _GoalCard(
                          goal: goal,
                          service: widget.service,
                          missionService: widget.missionService,
                          ordinal: index + 1,
                          onTap: () => _open(goal),
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    ),
  );

  Widget _statusTabs(BuildContext context) {
    const choices = [GoalStatus.active, GoalStatus.paused, GoalStatus.achieved];
    final scale = MediaQuery.textScalerOf(context).scale(14) / 14;
    Widget tab(GoalStatus value) => TextButton(
      key: Key('goal-filter-${value.name}'),
      onPressed: () => _selectStatus(value),
      style: TextButton.styleFrom(
        backgroundColor: _selectedStatus == value
            ? AppColors.accent
            : Colors.transparent,
        foregroundColor: AppColors.textPrimary,
        shape: const StadiumBorder(),
        minimumSize: const Size(0, 48),
        textStyle: Theme.of(context).textTheme.labelMedium,
      ),
      child: Text(switch (value) {
        GoalStatus.active => '进行中',
        GoalStatus.paused => '已搁置',
        GoalStatus.achieved => '已达成',
        GoalStatus.dropped => '已放弃',
      }),
    );
    return LayoutBuilder(
      builder: (context, box) {
        final narrow = box.maxWidth < 3 * 112 * scale;
        return Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: AppColors.primarySoft,
            borderRadius: BorderRadius.circular(32),
          ),
          child: narrow
              ? SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      for (final value in choices)
                        SizedBox(width: 112 * scale, child: tab(value)),
                    ],
                  ),
                )
              : Row(
                  children: [
                    for (final value in choices) Expanded(child: tab(value)),
                  ],
                ),
        );
      },
    );
  }

  Widget _empty(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
    decoration: BoxDecoration(
      color: AppColors.card,
      borderRadius: BorderRadius.circular(24),
    ),
    child: Column(
      children: [
        const CircleAvatar(
          radius: 32,
          backgroundColor: AppColors.primarySoft,
          child: Icon(Icons.flag_outlined, size: 30, color: AppColors.primary),
        ),
        const SizedBox(height: 20),
        Text(
          _selectedStatus == GoalStatus.active
              ? '从一个想实现的目标开始'
              : _selectedStatus == GoalStatus.paused
              ? '没有已搁置的目标'
              : _selectedStatus == GoalStatus.achieved
              ? '没有已达成的目标'
              : '没有已放弃的目标',
          style: Theme.of(context).textTheme.titleMedium,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          _selectedStatus == GoalStatus.active
              ? '学习一项技能，或完成一件在意的事。'
              : _selectedStatus == GoalStatus.dropped
              ? '放弃的目标会保留在这里，随时可以恢复。'
              : '目标状态由你自己决定，可以在目标详情中调整。',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 24),
        if (_selectedStatus == GoalStatus.active)
          FilledButton.icon(
            onPressed: _chooseNewGoal,
            icon: const Icon(Icons.add),
            label: const Text('创建第一个目标'),
          ),
      ],
    ),
  );
}

/// 目标名称打开完整详情，路径按钮在当前卡片展开节点操作。
class _GoalCard extends StatefulWidget {
  const _GoalCard({
    required this.goal,
    required this.service,
    required this.onTap,
    required this.ordinal,
    this.missionService,
  });
  final Goal goal;
  final GoalService service;
  final VoidCallback onTap;
  final int ordinal;
  final MissionService? missionService;
  @override
  State<_GoalCard> createState() => _GoalCardState();
}

class _GoalCardState extends State<_GoalCard> {
  bool _expanded = false;
  final _outlineKey = GlobalKey<GoalOutlineSectionState>();
  Future<void> _toggle() async {
    if (_expanded &&
        !await (_outlineKey.currentState?.prepareToCollapse() ??
            Future.value(true))) {
      return;
    }
    if (mounted) setState(() => _expanded = !_expanded);
  }

  @override
  Widget build(BuildContext context) {
    final emphasized = widget.goal.status == GoalStatus.active;
    final cardColor = emphasized
        ? AppColors.primary
        : widget.goal.status == GoalStatus.paused
        ? AppColors.primarySoft
        : AppColors.card;
    final foreground = emphasized ? AppColors.onPrimary : AppColors.textPrimary;
    return Material(
      color: cardColor,
      borderRadius: BorderRadius.circular(24),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 颜色只表达目标自身的真实状态；所有正在推进的目标使用相同强调面。
          Ink(
            color: cardColor,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                InkWell(
                  key: Key('goal-${widget.goal.id}'),
                  onTap: widget.onTap,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 22, 16, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Text(
                              '目标 ${widget.ordinal.toString().padLeft(2, '0')}',
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(color: foreground),
                            ),
                            const Spacer(),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 5,
                              ),
                              decoration: BoxDecoration(
                                color: emphasized
                                    ? AppColors.accent
                                    : AppColors.primarySoft,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                goalStatusLabel(widget.goal.status),
                                style: Theme.of(context).textTheme.labelSmall
                                    ?.copyWith(color: AppColors.textPrimary),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Text(
                                widget.goal.title,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.titleLarge
                                    ?.copyWith(color: foreground),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Icon(
                              Icons.north_east_rounded,
                              size: 20,
                              color: foreground,
                            ),
                          ],
                        ),
                        if (widget.goal.description != null) ...[
                          const SizedBox(height: 8),
                          Text(
                            widget.goal.description!,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(
                                  color: emphasized
                                      ? AppColors.onPrimary.withValues(
                                          alpha: .82,
                                        )
                                      : AppColors.textSecondary,
                                ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                if (widget.missionService != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
                    child: Column(
                      children: [
                        Divider(
                          height: 1,
                          color: emphasized
                              ? AppColors.onPrimary.withValues(alpha: .24)
                              : AppColors.hairline,
                        ),
                        const SizedBox(height: 12),
                        GoalRecordSummary(
                          goalId: widget.goal.id,
                          goals: widget.service,
                          missions: widget.missionService!,
                          highlighted: emphasized,
                        ),
                      ],
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 0, 8, 6),
                  child: Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 8,
                    children: [
                      TextButton(
                        key: Key('goal-outline-toggle-${widget.goal.id}'),
                        onPressed: _toggle,
                        style:
                            TextButton.styleFrom(
                              foregroundColor: foreground,
                              textStyle: Theme.of(
                                context,
                              ).textTheme.labelMedium,
                              backgroundColor: emphasized
                                  ? AppColors.onPrimary.withValues(alpha: .14)
                                  : AppColors.primarySoft,
                              shape: const StadiumBorder(),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 10,
                              ),
                            ).copyWith(
                              overlayColor: Theme.of(
                                context,
                              ).textButtonTheme.style?.overlayColor,
                            ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(_expanded ? '收起目录' : '展开目录'),
                            const SizedBox(width: 6),
                            Icon(
                              _expanded ? Icons.expand_less : Icons.expand_more,
                              size: 18,
                            ),
                          ],
                        ),
                      ),
                      if (_expanded)
                        TextButton.icon(
                          key: Key('node-add-root-${widget.goal.id}'),
                          onPressed: () =>
                              _outlineKey.currentState?.addRootNode(),
                          style: TextButton.styleFrom(
                            textStyle: Theme.of(context).textTheme.labelMedium,
                            foregroundColor: foreground,
                            backgroundColor: emphasized
                                ? AppColors.onPrimary.withValues(alpha: .14)
                                : AppColors.primarySoft,
                            shape: const StadiumBorder(),
                          ),
                          icon: const Icon(Icons.add, size: 16),
                          label: const Text('添加节点'),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (_expanded)
            Divider(
              height: 1,
              indent: 20,
              endIndent: 20,
              color: emphasized
                  ? AppColors.onPrimary.withValues(alpha: .24)
                  : AppColors.hairline,
            ),
          if (_expanded)
            Material(
              color: AppColors.card,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: GoalOutlineSection(
                  key: _outlineKey,
                  service: widget.service,
                  missionService: widget.missionService,
                  goal: widget.goal,
                  goalId: widget.goal.id,
                  goalTitle: widget.goal.title,
                  embedded: true,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

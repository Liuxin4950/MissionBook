import 'dart:async';
import 'package:flutter/material.dart';
import '../../widgets/app_empty_state.dart';
import '../../widgets/app_section_card.dart';
import '../../widgets/detail_pane.dart';

import '../../../application/goals/goal_service.dart';
import '../../../application/missions/mission_service.dart';
import '../../../core/theme/app_layout.dart';
import '../../widgets/app_page_header.dart';
import '../../widgets/app_segmented_control.dart';
import '../../widgets/adaptive_columns.dart';
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
  Goal? _outlineGoal;
  bool _switchingOutline = false;
  final _outlineKey = GlobalKey<GoalOutlineSectionState>();

  Future<void> _toggleOutline(Goal goal) async {
    if (_switchingOutline) return;
    _switchingOutline = true;
    try {
      if (!await (_outlineKey.currentState?.prepareToCollapse() ??
          Future.value(true))) {
        return;
      }
      if (mounted) {
        setState(
          () => _outlineGoal = _outlineGoal?.id == goal.id ? null : goal,
        );
      }
    } finally {
      _switchingOutline = false;
    }
  }

  final _importKey = GlobalKey<GoalImportSectionState>();

  // 导入是独立的次级入口；普通创建直接打开表单，不再先问一次创建方式。
  void _openImport() {
    if (_selectedStatus != GoalStatus.active) return;
    if (!_importOpen) setState(() => _importOpen = true);
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

  Future<void> _selectStatus(GoalStatus value) async {
    if (_selectedStatus == value || _switchingOutline) return;
    _switchingOutline = true;
    try {
      final canLeaveOutline =
          await (_outlineKey.currentState?.prepareToCollapse() ??
              Future.value(true));
      if (!mounted || !canLeaveOutline) return;
      final canLeaveImport =
          await (_importKey.currentState?.prepareToCollapse() ??
              Future.value(true));
      if (!mounted || !canLeaveImport) return;
      setState(() {
        _outlineGoal = null;
        _importOpen = false;
        _selectedStatus = value;
        _goals = _load();
      });
    } finally {
      _switchingOutline = false;
    }
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
    unawaited(
      openDetailPane<void>(
        context,
        label: '目标详情',
        builder: (_) => GoalDetailPage(
          service: widget.service,
          goalId: goal.id,
          missionService: widget.missionService,
        ),
      ).then((_) => _refresh()),
    );
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
          constraints: const BoxConstraints(
            maxWidth: AppLayout.dashboardMaxWidth,
          ),
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
              final emptyActive =
                  !waiting &&
                  !snapshot.hasError &&
                  visible.isEmpty &&
                  _selectedStatus == GoalStatus.active;
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
                            ? '读取中…'
                            : snapshot.hasError
                            ? '读取失败'
                            : '${visible.length} 个目标',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      action: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          PopupMenuButton<String>(
                            key: const Key('goal-more-filters'),
                            tooltip: '更多目标操作',
                            onSelected: (value) {
                              if (value == 'import') _openImport();
                              if (value == 'dropped') {
                                _selectStatus(GoalStatus.dropped);
                              }
                            },
                            itemBuilder: (_) => [
                              if (_selectedStatus == GoalStatus.active)
                                const PopupMenuItem(
                                  key: Key('goal-import-menu'),
                                  value: 'import',
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.file_upload_outlined,
                                        size: 20,
                                      ),
                                      SizedBox(width: 12),
                                      Text('导入目标大纲'),
                                    ],
                                  ),
                                ),
                              const PopupMenuItem(
                                value: 'dropped',
                                child: Row(
                                  children: [
                                    Icon(Icons.archive_outlined, size: 20),
                                    SizedBox(width: 12),
                                    Text('已放弃的目标'),
                                  ],
                                ),
                              ),
                            ],
                            icon: const Icon(Icons.more_horiz),
                          ),
                          if (_selectedStatus == GoalStatus.active &&
                              (waiting ||
                                  snapshot.hasError ||
                                  visible.isNotEmpty))
                            IconButton.filled(
                              key: const Key('goal-create'),
                              tooltip: '新建目标',
                              onPressed: _create,
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
                    if (_selectedStatus == GoalStatus.active &&
                        _importOpen &&
                        !emptyActive) ...[
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
                    if (_selectedStatus == GoalStatus.dropped &&
                        (waiting || snapshot.hasError || visible.isNotEmpty))
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
                    else if (emptyActive)
                      _emptyWorkspace(context)
                    else if (visible.isEmpty)
                      _emptyStatusWorkspace(context),
                    if (visible.isNotEmpty) _goalWorkspace(context, visible),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    ),
  );

  Widget _goalWorkspace(BuildContext context, List<Goal> visible) {
    final selected = _outlineGoal;
    final hasPath =
        selected != null && visible.any((goal) => goal.id == selected.id);
    return LayoutBuilder(
      builder: (context, box) {
        final scale = MediaQuery.textScalerOf(context).scale(14) / 14;
        final split = hasPath && box.maxWidth >= 860 * scale;
        final listWidth = split
            ? (box.maxWidth * .3).clamp(300.0, 380.0)
            : box.maxWidth;
        return Wrap(
          key: const Key('goal-workspace'),
          spacing: 20,
          runSpacing: 20,
          children: [
            SizedBox(
              key: const Key('goal-library-pane'),
              width: listWidth,
              child: AdaptiveColumns(
                key: const Key('goal-card-grid'),
                minColumnWidth: 300,
                children: [
                  for (final goal in visible)
                    _GoalCard(
                      key: ValueKey(goal.id),
                      goal: goal,
                      service: widget.service,
                      missionService: widget.missionService,
                      selected: _outlineGoal?.id == goal.id,
                      compact: split,
                      onTap: () => _open(goal),
                      onToggleOutline: () => _toggleOutline(goal),
                    ),
                ],
              ),
            ),
            if (hasPath)
              SizedBox(
                key: const Key('goal-action-pane'),
                width: split ? box.maxWidth - listWidth - 20 : box.maxWidth,
                child: AnimatedSize(
                  alignment: Alignment.topLeft,
                  duration: MediaQuery.disableAnimationsOf(context)
                      ? Duration.zero
                      : const Duration(milliseconds: 260),
                  curve: Curves.easeOutCubic,
                  child: AppSectionCard(
                    key: const Key('goal-path-panel'),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                '行动路径 · ${_outlineGoal!.title}',
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                            ),
                            IconButton(
                              key: Key('node-add-root-${_outlineGoal!.id}'),
                              tooltip: '添加节点',
                              onPressed: () =>
                                  _outlineKey.currentState?.addRootNode(),
                              icon: const Icon(Icons.add),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        GoalOutlineSection(
                          key: _outlineKey,
                          service: widget.service,
                          missionService: widget.missionService,
                          goal: visible.firstWhere(
                            (goal) => goal.id == _outlineGoal!.id,
                          ),
                          goalId: _outlineGoal!.id,
                          goalTitle: _outlineGoal!.title,
                          embedded: true,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _emptyWorkspace(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      final scale = MediaQuery.textScalerOf(context).scale(14) / 14;
      final split = box.maxWidth >= 900 * scale;
      final width = split ? (box.maxWidth - 24) / 2 : box.maxWidth;
      return Wrap(
        key: const Key('goal-empty-workspace'),
        spacing: 24,
        runSpacing: 24,
        children: [
          if (split || !_importOpen)
            SizedBox(
              width: width,
              child: _empty(context, showImportAction: !split),
            ),
          if (split || _importOpen)
            SizedBox(
              key: const Key('goal-import-pane'),
              width: width,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (!split)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton.icon(
                          key: const Key('goal-create'),
                          onPressed: _create,
                          icon: const Icon(Icons.add),
                          label: const Text('新建目标'),
                        ),
                        TextButton.icon(
                          onPressed: _closeImport,
                          icon: const Icon(Icons.close),
                          label: const Text('收起导入区'),
                        ),
                      ],
                    ),
                  GoalImportSection(
                    key: _importKey,
                    service: widget.service,
                    onImported: _imported,
                    onDraftChanged: _openImport,
                  ),
                ],
              ),
            ),
        ],
      );
    },
  );

  // 状态分类只展示本分类内容，空列表不补放其他分类或创建工作区。
  Widget _emptyStatusWorkspace(BuildContext context) => Align(
    key: const Key('goal-empty-workspace'),
    alignment: Alignment.topCenter,
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: AppLayout.maxPageWidth),
      child: _empty(context),
    ),
  );

  Widget _statusTabs(BuildContext context) => AppSegmentedControl<GoalStatus>(
    options: {
      GoalStatus.active: '进行中',
      GoalStatus.paused: '已搁置',
      GoalStatus.achieved: '已达成',
      if (_selectedStatus == GoalStatus.dropped) GoalStatus.dropped: '已放弃',
    },
    selected: _selectedStatus,
    optionKey: (status) => Key('goal-filter-${status.name}'),
    onSelected: _selectStatus,
  );

  Widget _empty(BuildContext context, {bool showImportAction = true}) {
    final active = _selectedStatus == GoalStatus.active;
    final title = active
        ? '从一个目标开始'
        : _selectedStatus == GoalStatus.paused
        ? '没有已搁置的目标'
        : _selectedStatus == GoalStatus.achieved
        ? '没有已达成的目标'
        : '没有已放弃的目标';
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          maxWidth: AppLayout.dashboardMaxWidth,
        ),
        child: AppSectionCard(
          key: const Key('goal-empty-state'),
          padding: const EdgeInsets.all(24),
          paperBackground: true,
          child: AppEmptyState(
            title: title,
            asset: 'assets/illustrations/goal-path.png',
            illustrationKey: ValueKey(
              'goal-empty-illustration-${_selectedStatus.name}',
            ),
            details: active ? const _GoalJourneyHint() : null,
            actions: active
                ? Wrap(
                    spacing: 12,
                    runSpacing: 8,
                    alignment: WrapAlignment.center,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      FilledButton.icon(
                        key: const Key('goal-create'),
                        onPressed: _create,
                        icon: const Icon(Icons.add),
                        label: const Text('创建目标'),
                      ),
                      if (showImportAction)
                        TextButton(
                          key: const Key('goal-create-import'),
                          onPressed: _openImport,
                          child: const Text('导入大纲'),
                        ),
                    ],
                  )
                : null,
          ),
        ),
      ),
    );
  }
}

/// 用顺序显现表达目标→行动→记录的关系，不表示已经完成任何一步。
class _GoalJourneyHint extends StatefulWidget {
  const _GoalJourneyHint();

  @override
  State<_GoalJourneyHint> createState() => _GoalJourneyHintState();
}

class _GoalJourneyHintState extends State<_GoalJourneyHint>
    with SingleTickerProviderStateMixin {
  late final _flow = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 640),
  );
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _started = true;
      _flow.value = 1;
    } else if (!_started && TickerMode.valuesOf(context).enabled) {
      _started = true;
      _flow.forward();
    }
  }

  @override
  void dispose() {
    _flow.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Semantics(
    label: '使用流程：设定目标，拆分行动，回看记录',
    child: ExcludeSemantics(
      child: AnimatedBuilder(
        animation: _flow,
        builder: (context, _) => Row(
          children: [
            for (var index = 0; index < 3; index++) ...[
              if (index > 0)
                SizedBox(
                  width: 24,
                  child: Opacity(
                    opacity: ((_flow.value - index * .15) / .6).clamp(0, 1),
                    child: const Icon(Icons.arrow_forward, size: 16),
                  ),
                ),
              Expanded(
                child: Opacity(
                  opacity:
                      .25 +
                      .75 * ((_flow.value - index * .15) / .6).clamp(0, 1),
                  child: Column(
                    children: [
                      Icon(
                        [
                          Icons.flag_outlined,
                          Icons.route_outlined,
                          Icons.auto_stories_outlined,
                        ][index],
                        size: 24,
                        color: AppColors.primary,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        ['目标', '行动', '记录'][index],
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    ),
  );
}

/// 目标卡负责选择与阅读；宽屏将目录放在卡片旁，窄屏在下方继续。
class _GoalCard extends StatelessWidget {
  const _GoalCard({
    super.key,
    required this.goal,
    required this.service,
    required this.onTap,
    required this.onToggleOutline,
    required this.selected,
    this.compact = false,
    this.missionService,
  });
  final Goal goal;
  final GoalService service;
  final MissionService? missionService;
  final VoidCallback onTap;
  final VoidCallback onToggleOutline;
  final bool selected;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: AppColors.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: selected ? AppColors.primary : AppColors.hairline,
          width: selected ? 1.5 : 1,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            key: Key('goal-${goal.id}'),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: selected
                              ? AppColors.primarySoft
                              : AppColors.surfaceMuted,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(Icons.flag_outlined),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              goal.title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.titleMedium,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              goalStatusLabel(goal.status),
                              style: theme.textTheme.bodyMedium,
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.chevron_right, size: 20),
                    ],
                  ),
                  if (!compact && goal.description != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      goal.description!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium,
                    ),
                  ],
                ],
              ),
            ),
          ),
          if (missionService != null && (!compact || selected))
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: GoalRecordSummary(
                goalId: goal.id,
                goals: service,
                missions: missionService!,
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
            child: TextButton.icon(
              key: Key('goal-outline-toggle-${goal.id}'),
              onPressed: onToggleOutline,
              style: TextButton.styleFrom(
                backgroundColor: AppColors.background,
                textStyle: theme.textTheme.labelMedium,
              ),
              icon: Icon(
                selected ? Icons.expand_less : Icons.route_outlined,
                size: 18,
              ),
              label: Text(selected ? '收起目录' : '展开目录'),
            ),
          ),
        ],
      ),
    );
  }
}

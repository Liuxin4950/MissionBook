import 'dart:async';

import 'package:flutter/material.dart';

import '../../widgets/app_journey_hero.dart';
import '../../widgets/app_section_card.dart';
import '../../widgets/adaptive_columns.dart';
import '../../widgets/detail_pane.dart';

import '../../../application/goals/goal_service.dart';
import '../../../application/missions/mission_service.dart';
import '../../../core/theme/app_layout.dart';
import '../../widgets/app_page_header.dart';
import '../../widgets/app_segmented_control.dart';
import '../../../core/theme/colors.dart';
import '../../../domain/entities/goal.dart';
import '../detail/goal_detail_page.dart';
import '../form/goal_form_page.dart';
import '../outline/goal_outline_section.dart';
import '../shared/goal_record_summary.dart';
import '../shared/goal_status_display.dart';
import '../form/goal_import_page.dart';

/// 目标导航页：读取正式目标、创建目标并进入详情。
class GoalsPage extends StatefulWidget {
  const GoalsPage({
    super.key,
    required this.service,
    this.missionService,
    this.active = true,
  });
  final GoalService service;
  final MissionService? missionService;
  final bool active;
  @override
  State<GoalsPage> createState() => _GoalsPageState();
}

class _GoalsPageState extends State<GoalsPage> with WidgetsBindingObserver {
  late Future<List<Goal>> _goals;
  StreamSubscription<void>? _changes;
  bool _opening = false; // 防止连续点击叠加两个创建或详情页面。
  bool _refreshWhenActive = false;
  GoalStatus _selectedStatus = GoalStatus.active;
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

  Future<void> _openImport() async {
    if (_opening || _selectedStatus != GoalStatus.active) return;
    _opening = DetailPaneScope.maybeOf(context) == null;
    try {
      final id = await openDetailPane<String>(
        context,
        label: '导入目标与计划',
        builder: (_) => GoalImportPage(service: widget.service),
      );
      if (!mounted) return;
      _refresh();
      if (id != null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('已导入目标与计划')));
      }
    } finally {
      _opening = false;
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _listen();
  }

  /// 首次读取列表并登记保存通知；通知到来时重新查询正式记录。
  void _listen() {
    _goals = widget.active ? _load() : Future.value(const []);
    _refreshWhenActive = !widget.active;
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
    if (!widget.active) {
      _refreshWhenActive = true;
      return;
    }
    _refreshWhenActive = false;
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
      setState(() {
        _outlineGoal = null;
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
    if (oldWidget.active != widget.active) {
      if (widget.active) {
        if (_refreshWhenActive) _refresh();
      } else {
        _refreshWhenActive = true;
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && widget.active) _refresh();
  }

  /// 打开表单，保存后用返回的编号进入正式详情。
  Future<void> _create() async {
    if (_opening) return;
    _opening = DetailPaneScope.maybeOf(context) == null;
    try {
      final id = await openDetailPane<String>(
        context,
        label: '新建目标',
        builder: (_) => GoalFormPage(service: widget.service),
      ); // 表单保存成功才返回目标编号，放弃填写返回 null。
      if (!mounted) return;
      if (id != null) {
        await _selectStatus(GoalStatus.active);
        if (!mounted) return;
      }
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
    _opening = DetailPaneScope.maybeOf(context) == null;
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
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: AppLayout.pagePadding(context),
                  children: [
                    AppPageHeader(
                      title: '目标',
                      showTitle: false,
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
                                        Icons.upload_file_outlined,
                                        size: AppLayout.iconMd,
                                      ),
                                      SizedBox(width: AppLayout.spaceMd),
                                      Text('导入目标大纲'),
                                    ],
                                  ),
                                ),
                              const PopupMenuItem(
                                value: 'dropped',
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.archive_outlined,
                                      size: AppLayout.iconMd,
                                    ),
                                    SizedBox(width: AppLayout.spaceMd),
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
                                Icons.add_rounded,
                                color: AppColors.onPrimary,
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppLayout.spaceLg),
                    _statusTabs(context),
                    const SizedBox(height: AppLayout.spaceMd),
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
                        padding: EdgeInsets.all(AppLayout.space3Xl),
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
    final selected = visible
        .where((goal) => goal.id == _outlineGoal?.id)
        .firstOrNull;
    return LayoutBuilder(
      builder: (context, box) {
        final scale = MediaQuery.textScalerOf(context).scale(1);
        final split =
            selected != null &&
            box.maxWidth >= AppLayout.paneMinContentWidth * scale;
        final listWidth = split ? AppLayout.paneRightMin : box.maxWidth;
        return Wrap(
          key: const Key('goal-workspace'),
          spacing: AppLayout.paneGap,
          runSpacing: AppLayout.spaceMd,
          children: [
            SizedBox(
              key: const Key('goal-library-pane'),
              width: listWidth,
              child: AdaptiveColumns(
                key: const Key('goal-card-grid'),
                minColumnWidth: AppLayout.paneRightMin,
                maxColumns: selected == null ? 3 : 1,
                spacing: AppLayout.spaceMd,
                children: [
                  for (final goal in visible)
                    Padding(
                      key: ValueKey(goal.id),
                      padding: EdgeInsets.zero,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _GoalCard(
                            goal: goal,
                            service: widget.service,
                            missionService: widget.missionService,
                            selected: selected?.id == goal.id,
                            onTap: () => _open(goal),
                            onToggleOutline: () => _toggleOutline(goal),
                          ),
                          // 手机上目录紧跟被选目标，不需要越过其他目标才能找到路径。
                          if (!split && selected?.id == goal.id) ...[
                            const SizedBox(height: AppLayout.spaceSm),
                            _pathPanel(goal),
                          ],
                        ],
                      ),
                    ),
                ],
              ),
            ),
            if (split)
              SizedBox(
                key: const Key('goal-action-pane'),
                width: box.maxWidth - listWidth - AppLayout.paneGap,
                child: _pathPanel(selected),
              ),
          ],
        );
      },
    );
  }

  Widget _pathPanel(Goal goal) => AppSectionCard(
    key: const Key('goal-path-panel'),
    padding: const EdgeInsets.all(AppLayout.spaceSm),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const SizedBox(width: AppLayout.spaceSm),
            Expanded(
              child: Text(
                '行动路径',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            IconButton(
              key: Key('node-add-root-${goal.id}'),
              tooltip: '添加节点',
              onPressed: () => _outlineKey.currentState?.addRootNode(),
              icon: const Icon(Icons.add_rounded, size: AppLayout.iconMd),
            ),
          ],
        ),
        GoalOutlineSection(
          key: _outlineKey,
          service: widget.service,
          missionService: widget.missionService,
          goal: goal,
          goalId: goal.id,
          goalTitle: goal.title,
          embedded: true,
          active: widget.active,
        ),
      ],
    ),
  );

  Widget _emptyWorkspace(BuildContext context) => _empty(context);

  // 状态分类只展示本分类内容，空列表不补放其他分类或创建工作区。
  Widget _emptyStatusWorkspace(BuildContext context) => SizedBox(
    key: const Key('goal-empty-workspace'),
    width: double.infinity,
    child: _empty(context),
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
    return AppJourneyHero(
      key: const Key('goal-empty-state'),
      title: title,
      subtitle: switch (_selectedStatus) {
        GoalStatus.active => '让想做的事，有一条清晰的路。',
        GoalStatus.paused => '需要暂缓的目标会留在这里，准备好时再继续。',
        GoalStatus.achieved => '达成的目标会留在这里，记录走过的路。',
        GoalStatus.dropped => '放下的目标会留在这里，已有任务与记录仍会保留。',
      },
      illustrationKey: ValueKey(
        'goal-empty-illustration-${_selectedStatus.name}',
      ),
      actions: active
          ? Wrap(
              spacing: AppLayout.spaceMd,
              runSpacing: AppLayout.spaceSm,
              children: [
                FilledButton.icon(
                  key: const Key('goal-create'),
                  onPressed: _create,
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('创建目标'),
                ),
                if (showImportAction)
                  OutlinedButton.icon(
                    key: const Key('goal-create-import'),
                    onPressed: _openImport,
                    icon: const Icon(
                      Icons.upload_file_outlined,
                      size: AppLayout.iconSm,
                    ),
                    label: const Text('导入文件'),
                  ),
              ],
            )
          : TextButton.icon(
              key: const Key('goal-return-active'),
              onPressed: () => _selectStatus(GoalStatus.active),
              icon: const Icon(Icons.arrow_back, size: AppLayout.iconSm),
              label: const Text('查看进行中'),
            ),
    );
  }
}

/// 点击目标展开路径，详情按钮进入编辑、状态及完整说明所在的详情页。
class _GoalCard extends StatelessWidget {
  const _GoalCard({
    required this.goal,
    required this.service,
    required this.onTap,
    required this.onToggleOutline,
    required this.selected,
    this.missionService,
  });
  final Goal goal;
  final GoalService service;
  final MissionService? missionService;
  final VoidCallback onTap;
  final VoidCallback onToggleOutline;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: AppColors.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppLayout.radiusLg),
        side: BorderSide(
          color: selected ? AppColors.primary : AppColors.hairline,
          width: selected ? AppLayout.strokeFocus : AppLayout.strokeThin,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Semantics(
                  expanded: selected,
                  button: true,
                  child: InkWell(
                    key: Key('goal-outline-toggle-${goal.id}'),
                    onTap: onToggleOutline,
                    child: Padding(
                      padding: const EdgeInsets.all(AppLayout.spaceMd),
                      child: Row(
                        key: Key('goal-${goal.id}'),
                        children: [
                          Icon(
                            selected ? Icons.expand_less : Icons.expand_more,
                            size: AppLayout.iconMd,
                            color: AppColors.primary,
                          ),
                          const SizedBox(width: AppLayout.spaceSm),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  goal.title,
                                  maxLines: selected ? null : 2,
                                  overflow: selected
                                      ? null
                                      : TextOverflow.ellipsis,
                                  style: theme.textTheme.titleSmall,
                                ),
                                const SizedBox(height: AppLayout.spaceXs),
                                Text(
                                  goalStatusLabel(goal.status),
                                  style: theme.textTheme.bodySmall,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              IconButton(
                key: Key('goal-details-${goal.id}'),
                tooltip: '目标详情：${goal.title}',
                onPressed: onTap,
                icon: const Icon(
                  Icons.chevron_right_rounded,
                  size: AppLayout.iconMd,
                ),
              ),
              const SizedBox(width: AppLayout.spaceXs),
            ],
          ),
          if (missionService != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppLayout.spaceMd,
                0,
                AppLayout.spaceMd,
                AppLayout.spaceMd,
              ),
              child: GoalRecordSummary(
                goalId: goal.id,
                goals: service,
                missions: missionService!,
              ),
            ),
        ],
      ),
    );
  }
}

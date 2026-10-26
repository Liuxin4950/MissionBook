import 'dart:async';
import 'package:flutter/material.dart';
import '../../widgets/detail_pane.dart';

import '../../../application/goals/goal_service.dart';
import '../../../application/missions/mission_service.dart';
import '../../../core/theme/app_layout.dart';
import '../../widgets/adaptive_sheet.dart';
import '../../widgets/app_page_header.dart';
import '../../widgets/app_segmented_control.dart';
import '../../widgets/adaptive_columns.dart';
import '../../widgets/app_section_card.dart';
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

  Future<void> _selectStatus(GoalStatus value) async {
    if (_selectedStatus == value || _switchingOutline) return;
    _switchingOutline = true;
    final canLeave =
        await (_outlineKey.currentState?.prepareToCollapse() ??
            Future.value(true));
    _switchingOutline = false;
    if (!mounted || !canLeave) return;
    setState(() {
      _outlineGoal = null;
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
                            initialValue: _selectedStatus,
                            onSelected: _selectStatus,
                            itemBuilder: (_) => const [
                              PopupMenuItem(
                                value: GoalStatus.dropped,
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
                    AdaptiveColumns(
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
                            onTap: () => _open(goal),
                            onToggleOutline: () => _toggleOutline(goal),
                          ),
                      ],
                    ),
                    if (_outlineGoal != null &&
                        visible.any((goal) => goal.id == _outlineGoal!.id)) ...[
                      const SizedBox(height: 20),
                      AppSectionCard(
                        key: const Key('goal-path-panel'),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    '行动路径 · ${_outlineGoal!.title}',
                                    style: Theme.of(
                                      context,
                                    ).textTheme.titleMedium,
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
                    ],
                  ],
                ),
              );
            },
          ),
        ),
      ),
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

  Widget _empty(BuildContext context) {
    final active = _selectedStatus == GoalStatus.active;
    final foreground = active ? AppColors.onPrimary : AppColors.textPrimary;
    final title = active
        ? '从一个想实现的目标开始'
        : _selectedStatus == GoalStatus.paused
        ? '没有已搁置的目标'
        : _selectedStatus == GoalStatus.achieved
        ? '没有已达成的目标'
        : '没有已放弃的目标';
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: active ? AppColors.primary : AppColors.card,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: active ? AppColors.accent : AppColors.primarySoft,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              _selectedStatus == GoalStatus.dropped
                  ? Icons.archive_outlined
                  : Icons.flag_outlined,
              size: 28,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(color: foreground),
          ),
          const SizedBox(height: 12),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Text(
              active
                  ? '学习一项技能，或完成一件在意的事。把方向拆成行动，让每次实践留下记录。'
                  : _selectedStatus == GoalStatus.dropped
                  ? '放弃的目标会保留在这里，需要时可以在目标详情中恢复推进。'
                  : '按自己的节奏调整方向，在目标详情中管理状态。',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: foreground),
            ),
          ),
          if (active) ...[
            const SizedBox(height: 28),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.accent,
                foregroundColor: AppColors.textPrimary,
              ),
              onPressed: _chooseNewGoal,
              icon: const Icon(Icons.add),
              label: const Text('创建第一个目标'),
            ),
          ],
        ],
      ),
    );
  }
}

/// 卡片只负责选择与阅读入口；整份行动路径在卡片网格下方使用完整可用宽度。
class _GoalCard extends StatelessWidget {
  const _GoalCard({
    super.key,
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
                              ? AppColors.accent
                              : AppColors.primarySoft,
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
                              style: theme.textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.chevron_right, size: 20),
                    ],
                  ),
                  if (goal.description != null) ...[
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
          if (missionService != null)
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

import 'dart:async';
import 'package:flutter/material.dart';

import '../../application/goals/goal_service.dart';
import '../../application/missions/mission_service.dart';
import '../../core/theme/app_layout.dart';
import '../../core/theme/colors.dart';
import '../../domain/entities/goal.dart';
import 'goal_detail_page.dart';
import 'goal_form_page.dart';
import 'goal_outline_section.dart';
import 'goal_record_summary.dart';

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
    final result = widget.service.findAll();
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
      final id = await Navigator.of(context).push<String>(
        MaterialPageRoute(
          builder: (_) => GoalFormPage(service: widget.service),
        ),
      ); // 表单保存成功才返回目标编号，放弃填写返回 null。
      if (!mounted) return;
      _refresh();
      if (id != null) {
        await Navigator.of(context).push<void>(
          MaterialPageRoute(
            builder: (_) => GoalDetailPage(
              service: widget.service,
              goalId: id,
              missionService: widget.missionService,
            ),
          ),
        ); // 用详情替换已关闭的表单；返回不会重新进入填写页面。
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
      await Navigator.of(context).push<void>(
        MaterialPageRoute(
          builder: (_) => GoalDetailPage(
            service: widget.service,
            goalId: goal.id,
            missionService: widget.missionService,
          ),
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
    appBar: AppBar(
      automaticallyImplyLeading: false,
      toolbarHeight: 88,
      titleSpacing: AppLayout.horizontalPadding(context),
      title: Text('目标', style: Theme.of(context).textTheme.headlineSmall),
      actions: [
        Padding(
          padding: EdgeInsets.only(right: AppLayout.horizontalPadding(context)),
          child: IconButton.filled(
            key: const Key('goal-create'),
            tooltip: '新建目标',
            onPressed: _create,
            icon: const Icon(Icons.add, color: AppColors.onPrimary),
          ),
        ),
      ],
    ),
    body: SafeArea(
      top: false,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: AppLayout.maxPageWidth),
          child: FutureBuilder<List<Goal>>(
            future: _goals,
            builder: (context, snapshot) {
              if (!snapshot.hasData &&
                  snapshot.connectionState != ConnectionState.done) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('暂时无法读取目标，你的数据不会被清除'),
                      TextButton(onPressed: _refresh, child: const Text('重试')),
                    ],
                  ),
                );
              }
              final goals = snapshot.data!;
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
                    Text(
                      goals.isEmpty
                          ? '给接下来的行动一个方向'
                          : '${goals.length} 个目标，按自己的节奏推进',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 24),
                    if (goals.isEmpty) _empty(context),
                    for (final goal in goals)
                      Padding(
                        key: ValueKey(goal.id), // 刷新列表时让同一个目标保留路径展开状态。
                        padding: const EdgeInsets.only(bottom: 16),
                        child: _GoalCard(
                          goal: goal,
                          service: widget.service,
                          missionService: widget.missionService,
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

  Widget _empty(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
    decoration: BoxDecoration(
      color: AppColors.card,
      borderRadius: BorderRadius.circular(28),
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
          '从一个想实现的目标开始',
          style: Theme.of(context).textTheme.titleMedium,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        const Text(
          '学习一项技能，或完成一件在意的事。',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.textSecondary),
        ),
        const SizedBox(height: 24),
        FilledButton.icon(
          onPressed: _create,
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
    this.missionService,
  });
  final Goal goal;
  final GoalService service;
  final VoidCallback onTap;
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
  Widget build(BuildContext context) => Material(
    color: AppColors.card,
    borderRadius: BorderRadius.circular(24),
    clipBehavior: Clip.antiAlias,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 卡片保持白底，展开由箭头和目录内容表达，不用整块高饱和色当作按下反馈。
        Ink(
          color: AppColors.card,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              InkWell(
                key: Key('goal-${widget.goal.id}'),
                onTap: widget.onTap,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 22, 16, 16),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: _expanded
                              ? AppColors.primary.withValues(alpha: .08)
                              : AppColors.primarySoft,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(
                          Icons.flag_outlined,
                          size: 22,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.goal.title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.bodyLarge
                                  ?.copyWith(
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textPrimary,
                                  ),
                            ),
                            if (widget.goal.description != null) ...[
                              const SizedBox(height: 5),
                              Text(
                                widget.goal.description!,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.bodyMedium
                                    ?.copyWith(
                                      color: _expanded
                                          ? AppColors.primary
                                          : AppColors.textSecondary,
                                    ),
                              ),
                            ],
                            const SizedBox(height: 8),
                            Text(
                              goalStatusLabel(widget.goal.status),
                              style: Theme.of(context).textTheme.labelSmall
                                  ?.copyWith(color: AppColors.primary),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Padding(
                        padding: EdgeInsets.only(top: 3),
                        child: Icon(
                          Icons.north_east_rounded,
                          size: 20,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (widget.missionService != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
                  child: GoalRecordSummary(
                    goalId: widget.goal.id,
                    goals: widget.service,
                    missions: widget.missionService!,
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
                            foregroundColor: AppColors.primary,
                            textStyle: Theme.of(context).textTheme.labelMedium,
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
        if (_expanded) const Divider(height: 1, indent: 20, endIndent: 20),
        if (_expanded)
          Padding(
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
      ],
    ),
  );
}

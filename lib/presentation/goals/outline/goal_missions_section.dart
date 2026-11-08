import 'package:flutter/material.dart';

import '../../widgets/detail_pane.dart';
import '../../../application/missions/mission_service.dart';
import '../../../core/theme/colors.dart';
import '../../../domain/entities/goal.dart';
import '../../../domain/entities/goal_node.dart';
import '../../../domain/entities/mission_detail.dart';
import '../../../domain/entities/mission_phase.dart';
import '../../../domain/rules/goal_node_record_rules.dart';
import '../../missions/form/mission_form_page.dart';
import '../../missions/detail/mission_detail_page.dart';
import '../../missions/record/mission_record_workspace.dart';
import '../../missions/execution/mission_execution_page.dart';
import '../../missions/shared/mission_phase_display.dart';
import '../../missions/shared/mission_live_status.dart';
import '../../../core/theme/app_layout.dart';

/// 目标或节点下的直接关联任务，操作转入独立任务页面。
class GoalMissionsSection extends StatefulWidget {
  // 节点标记与树线共用定位尺寸，文字换行只增加行高，不移动标记。
  static const markerExtent = AppLayout.touchTargetMin;

  const GoalMissionsSection({
    super.key,
    required this.goal,
    this.node,
    required this.service,
    required this.missions,
    required this.onRefresh,
    this.leading,
    this.onToggleChildren,
    this.childrenExpanded,
    this.trailing,
    this.annotation,
    this.relatedContent,
    this.directOnly = false,
  });
  final Goal goal;
  final GoalNode? node; // null 时只显示“关联目标、没有关联节点”的任务。
  final MissionService service;
  final Future<List<MissionDetail>> missions; // 上层一次读取整个目标，各节点在内存中筛选直接关联项。
  final VoidCallback onRefresh;
  final Widget? leading; // 节点树传入展开箭头；任务区负责把它与节点标题放在同一行。
  final VoidCallback? onToggleChildren;
  final bool? childrenExpanded;
  final Widget? trailing; // 节点维护菜单，由原来的树组件提供，操作逻辑不搬到这里。
  final String? annotation;
  final Widget? relatedContent; // 节点自身的记录入口，与任务并列，由目标工作区组装。
  final bool directOnly;
  @override
  State<GoalMissionsSection> createState() => GoalMissionsSectionState();
}

class GoalMissionsSectionState extends State<GoalMissionsSection> {
  bool _expanded = false;
  bool _opening = false;
  static const _pageSize = 10;
  int _pageIndex = 0;
  List<MissionDetail>? _lastMissions;
  Future<void> createMission() => _open(); // 节点菜单与行内按钮共用同一个建任务入口。

  Future<void> toggleTasks() async {
    if (mounted) setState(() => _expanded = !_expanded);
  }

  Widget _createMissionAction(String title) => IconButton(
    key: Key('node-create-mission-${widget.node?.id ?? widget.goal.id}'),
    tooltip: '为“$title”新建任务',
    onPressed: _opening ? null : () => _open(),
    icon: const Icon(
      Icons.add_rounded,
      size: AppLayout.iconSm,
      color: AppColors.primary,
    ),
  );

  Future<void> _open({MissionDetail? detail}) async {
    if (_opening) return;
    setState(() => _opening = true);
    try {
      await openDetailPane<void>(
        context,
        label: detail == null
            ? '新建任务'
            : detail.phase == MissionPhase.running ||
                  (detail.phase == MissionPhase.paused ||
                      detail.phase == MissionPhase.reportPending)
            ? '任务执行'
            : detail.phase == MissionPhase.closed
            ? '执行记录'
            : '任务详情',
        builder: (_) {
          if (detail == null) {
            return MissionFormPage.forGoal(
              missionService: widget.service,
              goal: widget.goal,
              node: widget.node,
            );
          }
          if (detail.phase == MissionPhase.running ||
              (detail.phase == MissionPhase.paused ||
                  detail.phase == MissionPhase.reportPending)) {
            return MissionExecutionPage(
              detail: detail,
              service: widget.service,
            );
          }
          if (detail.phase == MissionPhase.closed) {
            return MissionRecordWorkspace(
              detail: detail,
              service: widget.service,
            );
          }
          return MissionDetailPage(
            missionId: detail.mission.id,
            missionService: widget.service,
          );
        },
      );
    } finally {
      if (mounted) {
        setState(() {
          _opening = false;
          if (detail == null) {
            _expanded = true;
            _pageIndex = 0;
          }
        });
        widget.onRefresh();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final available =
        widget.goal.status == GoalStatus.active &&
        widget.node?.archivedAt == null;
    final theme = Theme.of(context);
    return FutureBuilder<List<MissionDetail>>(
      future: widget.missions,
      builder: (context, snapshot) {
        if (snapshot.hasData) _lastMissions = snapshot.data;
        final direct =
            _lastMissions
                ?.where(
                  (detail) =>
                      widget.directOnly ||
                      detail.mission.goalNodeId == widget.node?.id,
                )
                .toList() ??
            [];
        int priority(MissionDetail detail) => switch (detail.phase) {
          MissionPhase.running => 0,
          MissionPhase.paused => 1,
          MissionPhase.reportPending => 1,
          MissionPhase.notStarted => 2,
          MissionPhase.evidencePending => 3,
          MissionPhase.closed => 4,
          MissionPhase.cancelled => 5,
        };
        direct.sort((a, b) {
          final group = priority(a).compareTo(priority(b));
          if (group != 0) return group;
          final byDate = a.schedule.scheduledDate.compareTo(
            b.schedule.scheduledDate,
          );
          if (byDate != 0) {
            return priority(a) >= 4 ? -byDate : byDate;
          }
          final aStart = a.schedule.fixedStartAt;
          final bStart = b.schedule.fixedStartAt;
          if (aStart != null && bStart != null) {
            final byTime = aStart.compareTo(bStart);
            if (byTime != 0) return byTime;
          }
          return a.mission.id.compareTo(b.mission.id);
        });
        // 完成记录与任务状态的口径集中在 domain/rules/goal_node_record_rules.dart。
        final pageCount = direct.isEmpty
            ? 1
            : (direct.length + _pageSize - 1) ~/ _pageSize;
        final pageIndex = _pageIndex.clamp(0, pageCount - 1);
        final completed = hasCompletionRecord(direct);
        var label = nodeRecordLabel(direct);
        if (widget.node == null) label = '关联任务';
        if (snapshot.hasError) {
          label = '任务读取失败';
        } else if (_lastMissions == null) {
          label = '正在读取任务…';
        }
        final title = widget.node?.title ?? '仅关联目标的任务';
        final showTaskSummary =
            snapshot.hasError || _lastMissions == null || direct.isNotEmpty;
        final createButton = available
            ? TextButton.icon(
                key: Key(
                  'node-create-mission-${widget.node?.id ?? widget.goal.id}',
                ),
                onPressed: _opening ? null : () => _open(),
                style: TextButton.styleFrom(
                  textStyle: theme.textTheme.labelSmall,
                  minimumSize: const Size(0, AppLayout.touchTargetMin),
                ),
                icon: const Icon(Icons.add_rounded, size: AppLayout.iconSm),
                label: Text(widget.node == null ? '为目标建任务' : '新建任务'),
              )
            : null;
        // 目标直属任务为空时保留真实创建入口；节点使用标题行的加号和菜单。
        if (widget.node == null && direct.isEmpty && !snapshot.hasError) {
          return createButton == null
              ? const SizedBox.shrink()
              : Align(alignment: Alignment.centerLeft, child: createButton);
        }
        final statusText = snapshot.hasError || _lastMissions == null
            ? label
            : '$label · ${direct.length} 项任务';
        final titleAction =
            widget.onToggleChildren ?? (showTaskSummary ? toggleTasks : null);
        final leading = SizedBox.square(
          key: Key('node-marker-${widget.node?.id ?? widget.goal.id}'),
          dimension: GoalMissionsSection.markerExtent,
          child:
              widget.leading ??
              Icon(
                widget.node == null
                    ? Icons.flag_outlined
                    : completed
                    ? Icons.receipt_long_outlined
                    : Icons.radio_button_unchecked,
                size: AppLayout.iconSm,
                color: completed ? AppColors.primary : AppColors.outline,
              ),
        );
        return Padding(
          padding: EdgeInsets.only(
            top: widget.node == null ? AppLayout.spaceLg : 0,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              LayoutBuilder(
                builder: (context, box) {
                  // 窄面板把创建入口收进已有菜单，为名称和任务计数留出空间。
                  final showCreate =
                      available &&
                      (widget.trailing == null || box.maxWidth >= 360);
                  final titleContent = Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: AppLayout.spaceXs,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          title,
                          maxLines: _expanded ? null : 1,
                          overflow: _expanded ? null : TextOverflow.ellipsis,
                          style: theme.textTheme.titleSmall,
                        ),
                        if (showTaskSummary)
                          Text(
                            label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall,
                          ),
                      ],
                    ),
                  );
                  return Row(
                    key: Key(
                      'node-header-${widget.node?.id ?? widget.goal.id}',
                    ),
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      leading,
                      Expanded(
                        child: Semantics(
                          button: titleAction != null,
                          expanded: widget.onToggleChildren == null
                              ? _expanded
                              : widget.childrenExpanded,
                          hint: titleAction == null
                              ? null
                              : widget.onToggleChildren != null
                              ? (widget.childrenExpanded == true
                                    ? '收起子节点'
                                    : '展开子节点')
                              : (_expanded ? '收起任务' : '展开任务'),
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(
                              minHeight: AppLayout.touchTargetMin,
                            ),
                            key: Key(
                              'node-title-${widget.node?.id ?? widget.goal.id}',
                            ),
                            child: widget.node == null
                                ? InkWell(
                                    onTap: titleAction,
                                    borderRadius: BorderRadius.circular(
                                      AppLayout.radiusSm,
                                    ),
                                    child: titleContent,
                                  )
                                : titleContent,
                          ),
                        ),
                      ),
                      if (showTaskSummary)
                        Tooltip(
                          message: statusText,
                          child: Semantics(
                            label: statusText,
                            button: true,
                            expanded: _expanded,
                            hint: _expanded ? '收起任务' : '展开任务',
                            child: SizedBox(
                              width:
                                  AppLayout.touchTargetMin + AppLayout.spaceSm,
                              child: TextButton(
                                key: Key(
                                  'node-tasks-${widget.node?.id ?? widget.goal.id}',
                                ),
                                onPressed: toggleTasks,
                                style: TextButton.styleFrom(
                                  minimumSize: const Size(
                                    0,
                                    AppLayout.touchTargetMin,
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: AppLayout.spaceXs,
                                  ),
                                  foregroundColor: AppColors.textSecondary,
                                  textStyle: theme.textTheme.bodySmall,
                                ),
                                child: ExcludeSemantics(
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Flexible(
                                        child: Text(
                                          '${direct.length}',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      Icon(
                                        _expanded
                                            ? Icons.expand_less
                                            : Icons.expand_more,
                                        size: AppLayout.iconSm,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      if (showCreate) _createMissionAction(title),
                      if (widget.trailing != null) widget.trailing!,
                    ],
                  );
                },
              ),
              if (widget.annotation?.isNotEmpty == true)
                Padding(
                  padding: const EdgeInsets.only(
                    left: AppLayout.touchTargetMin,
                    bottom: AppLayout.spaceXs,
                  ),
                  child: Text(
                    widget.annotation!,
                    style: theme.textTheme.bodySmall,
                  ),
                ),
              if (!_expanded &&
                  direct.any(
                    (detail) => detail.phase == MissionPhase.evidencePending,
                  ))
                Padding(
                  padding: const EdgeInsets.only(
                    left: AppLayout.touchTargetMin,
                    bottom: AppLayout.spaceSm,
                  ),
                  child: Text(
                    '待补材料',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppColors.primary,
                    ),
                  ),
                ),
              if (_expanded && !available)
                Padding(
                  padding: const EdgeInsets.only(
                    left: AppLayout.touchTargetMin,
                    bottom: AppLayout.spaceSm,
                  ),
                  child: Text(
                    widget.node?.archivedAt != null
                        ? '已归档 · 恢复后可建任务，原任务仍可办理'
                        : '目标未推进 · 原任务仍可办理',
                    style: theme.textTheme.bodySmall,
                  ),
                ),
              if (_expanded)
                Padding(
                  // 任务已有独立表面，只保留节点内边距；树层级由外层缩进表达。
                  padding: EdgeInsets.symmetric(
                    horizontal: widget.node == null ? 0 : AppLayout.spaceSm,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (snapshot.hasError)
                        TextButton(
                          onPressed: widget.onRefresh,
                          child: const Text('重试读取任务'),
                        ),
                      for (final detail
                          in direct.skip(pageIndex * _pageSize).take(_pageSize))
                        _taskTile(
                          context,
                          detail,
                          emphasized:
                              detail.phase == MissionPhase.running ||
                              (detail.phase == MissionPhase.paused ||
                                  detail.phase == MissionPhase.reportPending),
                        ),
                      if (direct.length > _pageSize)
                        Wrap(
                          spacing: AppLayout.spaceSm,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            TextButton(
                              onPressed: pageIndex == 0
                                  ? null
                                  : () => setState(
                                      () => _pageIndex = pageIndex - 1,
                                    ),
                              child: const Text('上一页任务'),
                            ),
                            Text(
                              '${pageIndex + 1}/$pageCount 页 · 共 ${direct.length} 项',
                              style: theme.textTheme.bodySmall,
                            ),
                            TextButton(
                              onPressed:
                                  (pageIndex + 1) * _pageSize >= direct.length
                                  ? null
                                  : () => setState(
                                      () => _pageIndex = pageIndex + 1,
                                    ),
                              child: const Text('下一页任务'),
                            ),
                          ],
                        ),
                      if (widget.relatedContent != null) widget.relatedContent!,
                    ],
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _taskTile(
    BuildContext context,
    MissionDetail detail, {
    required bool emphasized,
  }) {
    final theme = Theme.of(context);
    final phase = phaseLabel(detail.phase, schedule: detail.schedule);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppLayout.spaceXs),
      child: Material(
        key: ValueKey('goal-task-${detail.mission.id}'),
        color: emphasized ? AppColors.primarySoft : AppColors.surfaceMuted,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppLayout.radiusSm),
          side: BorderSide(
            color: emphasized ? AppColors.primary : AppColors.hairline,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: _opening ? null : () => _open(detail: detail),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppLayout.spaceMd,
              vertical: AppLayout.spaceSm,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        detail.mission.title,
                        style: theme.textTheme.titleSmall,
                      ),
                      const SizedBox(height: AppLayout.spaceXs),
                      Text(
                        '${detail.schedule.scheduledDate} · $phase · ${detail.schedule.plannedDurationMinutes} 分钟',
                        style: theme.textTheme.bodySmall,
                      ),
                      if (detail.events.isNotEmpty)
                        MissionLiveStatus(
                          phase: detail.phase,
                          events: detail.events,
                          schedule: detail.schedule,
                          includePhase: false,
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: AppLayout.spaceSm),
                Icon(
                  detail.phase == MissionPhase.closed
                      ? Icons.history_rounded
                      : Icons.chevron_right_rounded,
                  size: AppLayout.iconSm,
                  color: AppColors.primary,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

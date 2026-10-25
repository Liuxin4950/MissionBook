import 'package:flutter/material.dart';
import '../../../application/missions/mission_service.dart';
import '../../../core/theme/colors.dart';
import '../../../domain/entities/goal.dart';
import '../../../domain/entities/goal_node.dart';
import '../../../domain/entities/mission_detail.dart';
import '../../../domain/entities/mission_phase.dart';
import '../../../domain/rules/goal_node_record_rules.dart';
import '../../missions/form/mission_form_page.dart';
import '../../missions/detail/mission_detail_page.dart';
import '../../missions/record/mission_record_page.dart';
import '../../missions/execution/mission_execution_page.dart';
import '../../missions/shared/mission_phase_display.dart';
import '../../missions/shared/mission_live_status.dart';

/// 目标或节点下的直接关联任务，操作转入独立任务页面。
class GoalMissionsSection extends StatefulWidget {
  const GoalMissionsSection({
    super.key,
    required this.goal,
    this.node,
    required this.service,
    required this.missions,
    required this.onRefresh,
    this.leading,
    this.trailing,
    this.annotation,
  });
  final Goal goal;
  final GoalNode? node; // null 时只显示“关联目标、没有关联节点”的任务。
  final MissionService service;
  final Future<List<MissionDetail>> missions; // 上层一次读取整个目标，各节点在内存中筛选直接关联项。
  final VoidCallback onRefresh;
  final Widget? leading; // 节点树传入展开箭头；任务区负责把它与节点标题放在同一行。
  final Widget? trailing; // 节点维护菜单，由原来的树组件提供，操作逻辑不搬到这里。
  final String? annotation;
  @override
  State<GoalMissionsSection> createState() => GoalMissionsSectionState();
}

class GoalMissionsSectionState extends State<GoalMissionsSection> {
  bool _expanded = false;
  bool _opening = false;
  List<MissionDetail>? _lastMissions;
  Future<void> createMission() => _open(); // 节点菜单与行内按钮共用同一个建任务入口。

  Future<void> _toggle() async {
    if (mounted) setState(() => _expanded = !_expanded);
  }

  Future<void> _open({MissionDetail? detail}) async {
    if (_opening) return;
    setState(() => _opening = true);
    try {
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) {
            if (detail == null) {
              return MissionFormPage.forGoal(
                missionService: widget.service,
                goal: widget.goal,
                node: widget.node,
              );
            }
            if (detail.phase == MissionPhase.running ||
                detail.phase == MissionPhase.paused) {
              return MissionExecutionPage(
                detail: detail,
                service: widget.service,
              );
            }
            if (detail.phase == MissionPhase.closed) {
              return MissionRecordPage(detail: detail, service: widget.service);
            }
            return MissionDetailPage(
              missionId: detail.mission.id,
              missionService: widget.service,
            );
          },
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _opening = false);
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
                  (detail) => detail.mission.goalNodeId == widget.node?.id,
                )
                .toList() ??
            [];
        int priority(MissionDetail detail) => switch (detail.phase) {
          MissionPhase.running => 0,
          MissionPhase.paused => 1,
          MissionPhase.notStarted => 2,
          MissionPhase.evidencePending => 3,
          MissionPhase.closed => 4,
          MissionPhase.cancelled => 5,
        };
        direct.sort((a, b) {
          final group = priority(a).compareTo(priority(b));
          if (group != 0) return group;
          final created = b.mission.createdAt.compareTo(a.mission.createdAt);
          return created != 0 ? created : a.mission.id.compareTo(b.mission.id);
        });
        // 完成记录与记录标签的口径集中在 domain/rules/goal_node_record_rules.dart，
        // 这里只负责展示；“完成”只是 END 报告已完成，不表示掌握程度。
        final completed = hasCompletionRecord(direct);
        var label = nodeRecordLabel(direct);
        if (widget.node == null) label = '关联任务';
        if (snapshot.hasError) {
          label = '任务读取失败';
        } else if (_lastMissions == null) {
          label = '正在读取任务…';
        }
        final title = widget.node?.title ?? '仅关联目标的任务';
        final createButton = available
            ? TextButton.icon(
                key: Key(
                  'node-create-mission-${widget.node?.id ?? widget.goal.id}',
                ),
                onPressed: _opening ? null : () => _open(),
                style:
                    TextButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      minimumSize: const Size(0, 40),
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      textStyle: theme.textTheme.labelMedium,
                    ).copyWith(
                      splashFactory: NoSplash.splashFactory,
                      overlayColor: theme.textButtonTheme.style?.overlayColor,
                    ),
                icon: const Icon(Icons.add, size: 16),
                label: Text(
                  widget.node == null && direct.isEmpty ? '直接为目标建任务' : '建任务',
                ),
              )
            : null;
        // 空节点没有任务可展开，不再用可点击箭头引导到空面板；新建入口始终独立保留。
        if (widget.node == null && direct.isEmpty && !snapshot.hasError) {
          return createButton == null
              ? const SizedBox.shrink()
              : Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: createButton,
                  ),
                );
        }
        final status = direct.isEmpty && !snapshot.hasError
            ? Padding(
                padding: const EdgeInsets.symmetric(vertical: 5),
                child: Text(label, style: theme.textTheme.bodyMedium),
              )
            : TextButton(
                key: Key('node-tasks-${widget.node?.id ?? widget.goal.id}'),
                onPressed: snapshot.hasError ? widget.onRefresh : _toggle,
                style:
                    TextButton.styleFrom(
                      foregroundColor: AppColors.textSecondary,
                      padding: EdgeInsets.zero,
                      minimumSize: const Size(0, 36),
                      alignment: Alignment.centerLeft,
                      textStyle: theme.textTheme.bodyMedium,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ).copyWith(
                      splashFactory: NoSplash.splashFactory,
                      overlayColor: theme.textButtonTheme.style?.overlayColor,
                    ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(child: Text('$label · ${direct.length}')),
                    const SizedBox(width: 3),
                    Icon(
                      _expanded ? Icons.expand_less : Icons.expand_more,
                      size: 16,
                    ),
                  ],
                ),
              );
        final leading =
            widget.leading ??
            SizedBox(
              width: 36,
              height: 48,
              child: Icon(
                widget.node == null
                    ? Icons.flag_outlined
                    : completed
                    ? Icons.check_circle_outline
                    : Icons.radio_button_unchecked,
                size: 18,
                color: completed ? AppColors.primary : AppColors.outline,
              ),
            );
        return Padding(
          padding: EdgeInsets.only(top: widget.node == null ? 16 : 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              LayoutBuilder(
                builder: (context, box) {
                  final compact =
                      box.maxWidth <
                      270 * MediaQuery.textScalerOf(context).scale(1);
                  final name = Text(
                    title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  );
                  if (compact) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            leading,
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 10,
                                ),
                                child: name,
                              ),
                            ),
                            if (widget.trailing != null) widget.trailing!,
                          ],
                        ),
                        Padding(
                          padding: const EdgeInsets.only(left: 36),
                          child: Wrap(
                            spacing: 10,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [status, ?createButton],
                          ),
                        ),
                      ],
                    );
                  }
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      leading,
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [name, status],
                          ),
                        ),
                      ),
                      ?createButton,
                      if (widget.trailing != null) widget.trailing!,
                    ],
                  );
                },
              ),
              if (widget.annotation?.isNotEmpty == true)
                Padding(
                  padding: const EdgeInsets.only(left: 40, bottom: 4),
                  child: Text(
                    widget.annotation!,
                    style: theme.textTheme.bodySmall,
                  ),
                ),
              if (direct.any(
                (detail) => detail.phase == MissionPhase.evidencePending,
              ))
                Padding(
                  padding: const EdgeInsets.only(left: 40, bottom: 6),
                  child: Text(
                    '待补材料',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: AppColors.primary,
                    ),
                  ),
                ),
              if (!available)
                Padding(
                  padding: const EdgeInsets.only(left: 40, bottom: 8),
                  child: Text(
                    widget.node?.archivedAt != null
                        ? '已归档 · 恢复后可建任务，原任务仍可办理'
                        : '目标未推进 · 原任务仍可办理',
                    style: theme.textTheme.bodyMedium,
                  ),
                ),
              if (_expanded && direct.isNotEmpty) ...[
                if (widget.node?.description != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                    child: Text(
                      widget.node!.description!,
                      style: theme.textTheme.bodyMedium,
                    ),
                  ),
                if (snapshot.hasError)
                  TextButton(
                    onPressed: widget.onRefresh,
                    child: const Text('重试读取任务'),
                  ),
                for (final detail in direct)
                  _taskTile(
                    context,
                    detail,
                    emphasized:
                        detail.phase == MissionPhase.running ||
                        detail.phase == MissionPhase.paused,
                  ),
              ],
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
    final color = emphasized ? AppColors.primary : AppColors.textSecondary;
    final date = detail.schedule.scheduledDate;
    return Container(
      key: ValueKey('goal-task-${detail.mission.id}'),
      margin: const EdgeInsets.only(top: 12, bottom: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: emphasized ? Border.all(color: AppColors.primary) : null,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 3, right: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      date.substring(5).replaceFirst('-', '/'),
                      style: theme.textTheme.bodyMedium?.copyWith(color: color),
                    ),
                    Text(
                      date.substring(0, 4),
                      style: theme.textTheme.bodySmall?.copyWith(color: color),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      detail.mission.title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${phaseLabel(detail.phase)} · 计划 ${detail.schedule.plannedDurationMinutes} 分钟',
                      style: theme.textTheme.bodyMedium?.copyWith(color: color),
                    ),
                    if (detail.events.isNotEmpty)
                      MissionLiveStatus(
                        phase: detail.phase,
                        events: detail.events,
                        includePhase: false,
                      ),
                  ],
                ),
              ),
              IconButton(
                onPressed: _opening ? null : () => _open(detail: detail),
                tooltip:
                    detail.phase == MissionPhase.running ||
                        detail.phase == MissionPhase.paused
                    ? '返回执行'
                    : detail.phase == MissionPhase.closed
                    ? '查看执行记录'
                    : detail.phase == MissionPhase.evidencePending
                    ? '提交材料'
                    : '任务详情',
                icon: Icon(
                  detail.phase == MissionPhase.closed
                      ? Icons.history_rounded
                      : Icons.open_in_new_rounded,
                  size: 18,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
          if (detail.phase == MissionPhase.evidencePending)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: _opening ? null : () => _open(detail: detail),
                child: const Text('提交材料'),
              ),
            ),
        ],
      ),
    );
  }
}

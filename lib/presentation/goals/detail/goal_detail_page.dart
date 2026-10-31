import '../../../domain/entities/analysis_scope.dart';
import '../../records/analysis_panel.dart';
import '../../records/records_page.dart';
import 'dart:async';
import '../../assistant/assistant_launcher.dart';
import 'package:flutter/material.dart';
import '../../widgets/detail_pane.dart';

import '../../../application/goals/goal_service.dart';
import '../../../application/missions/mission_service.dart';
import '../../../core/theme/app_layout.dart';
import '../../../core/theme/colors.dart';
import '../../../domain/entities/goal.dart';
import '../../widgets/app_top_bar.dart';
import '../../widgets/app_confirm_dialog.dart';
import '../../widgets/app_expansion.dart';
import '../form/goal_form_page.dart';
import '../outline/goal_outline_section.dart';
import '../shared/goal_record_summary.dart';
import '../shared/goal_status_display.dart';

/// 按编号读取目标，并提供目标路径及说明的完整阅读入口。
class GoalDetailPage extends StatefulWidget {
  const GoalDetailPage({
    super.key,
    required this.service,
    required this.goalId,
    this.missionService,
  });
  final GoalService service;
  final MissionService? missionService;
  final String goalId; // 列表或创建成功结果提供的目标编号。
  @override
  State<GoalDetailPage> createState() => _GoalDetailPageState();
}

class _GoalDetailPageState extends State<GoalDetailPage> {
  late Future<Goal?> _goal;
  Goal? _lastGoal; // 刷新期间保留最近一次成功内容，避免卸载节点工作区。
  StreamSubscription<void>? _changes;
  bool _busy = false;

  void _refresh() {
    if (mounted) {
      setState(() {
        _goal = widget.service.findById(widget.goalId);
      });
    }
  }

  void _listen() {
    _changes = widget.service.changes.listen((_) => _refresh());
  }

  @override
  void initState() {
    super.initState();
    _goal = widget.service.findById(widget.goalId);
    _listen();
  }

  @override
  void didUpdateWidget(covariant GoalDetailPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.service != widget.service ||
        oldWidget.goalId != widget.goalId) {
      if (oldWidget.goalId != widget.goalId) _lastGoal = null;
      _goal = widget.service.findById(widget.goalId);
      if (oldWidget.service != widget.service) {
        unawaited(_changes?.cancel());
        _listen();
      }
    }
  }

  @override
  void dispose() {
    unawaited(_changes?.cancel());
    super.dispose();
  }

  Future<void> _edit(Goal goal) async {
    if (_busy) return;
    _busy = true;
    try {
      await openDetailPane<String>(
        context,
        label: '编辑目标',
        builder: (_) => GoalFormPage(service: widget.service, goal: goal),
      );
    } finally {
      _busy = false;
      _refresh();
    }
  }

  Future<void> _changeStatus(Goal goal, GoalStatus status) async {
    if (_busy || goal.status == status) return;
    _busy = true;
    try {
      if (status == GoalStatus.dropped) {
        final confirmed = await AppConfirmDialog.show(
          context: context,
          title: '放弃这项目标？',
          message: '它会从默认列表隐藏。已有任务、节点和执行记录都会保留，之后仍可恢复推进。',
          cancelText: '继续推进',
          confirmText: '放弃目标',
        );
        if (!confirmed || !mounted) return;
      }
      await widget.service.setGoalStatus(goal, status);
      if (!mounted) return;
      _refresh();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('目标已${goalStatusLabel(status)}')));
    } catch (error) {
      if (!mounted) return;
      _refresh();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString().replaceFirst('Bad state: ', '')),
        ),
      );
    } finally {
      _busy = false;
    }
  }

  @override
  Widget build(BuildContext context) =>
      AssistantSurface(goalId: widget.goalId, child: _buildPage(context));

  Widget _buildPage(BuildContext context) => Scaffold(
    appBar: const AppTopBar(title: '目标详情'),
    body: SafeArea(
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: AppLayout.maxPageWidth),
          child: FutureBuilder<Goal?>(
            future: _goal, // FutureBuilder 接收查询结果，等待、失败和成功分别展示。
            builder: (context, snapshot) {
              final waiting = snapshot.connectionState != ConnectionState.done;
              final goal = snapshot.data ?? _lastGoal;
              if (goal == null) {
                if (waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('暂时无法读取目标'),
                        TextButton(
                          onPressed: () => setState(() {
                            _goal = widget.service.findById(widget.goalId);
                          }),
                          child: const Text('重试'),
                        ),
                      ],
                    ),
                  );
                }
                return const Center(child: Text('未找到这个目标，请返回列表刷新'));
              }
              // 有最近成功内容时先继续显示，刷新完成后原位替换。
              _lastGoal = goal;
              final theme = Theme.of(context);
              return SingleChildScrollView(
                padding: AppLayout.pagePadding(context),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    LayoutBuilder(
                      builder: (context, box) {
                        final title = SelectableText(
                          goal.title,
                          style: theme.textTheme.headlineSmall,
                        );
                        final badge = Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppLayout.spaceMd,
                            vertical: AppLayout.spaceSm,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primarySoft,
                            borderRadius: BorderRadius.circular(
                              AppLayout.radiusXl,
                            ),
                          ),
                          child: Text(
                            goalStatusLabel(goal.status),
                            style: theme.textTheme.labelMedium?.copyWith(
                              color: AppColors.primary,
                            ),
                          ),
                        );
                        if (box.maxWidth <
                            300 * MediaQuery.textScalerOf(context).scale(1)) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              title,
                              const SizedBox(height: AppLayout.spaceMd),
                              badge,
                            ],
                          );
                        }
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(child: title),
                            const SizedBox(width: AppLayout.spaceLg),
                            badge,
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: AppLayout.spaceMd),
                    AnalysisPanel(scope: AnalysisScope.goal, id: goal.id),
                    RecordsEntry(goalId: goal.id, label: '目标相关记录'),
                    Wrap(
                      spacing: AppLayout.spaceMd,
                      runSpacing: AppLayout.spaceSm,
                      children: [
                        OutlinedButton.icon(
                          key: const Key('goal-edit'),
                          onPressed: _busy ? null : () => _edit(goal),
                          icon: const Icon(
                            Icons.edit_outlined,
                            size: AppLayout.iconSm,
                          ),
                          label: const Text('编辑目标'),
                        ),
                        PopupMenuButton<GoalStatus>(
                          key: const Key('goal-status-menu'),
                          tooltip: '更改目标状态',
                          enabled: !_busy,
                          onSelected: (status) => _changeStatus(goal, status),
                          itemBuilder: (_) => [
                            if (goal.status != GoalStatus.active)
                              const PopupMenuItem(
                                value: GoalStatus.active,
                                child: Text('恢复推进'),
                              ),
                            if (goal.status != GoalStatus.dropped) ...[
                              if (goal.status != GoalStatus.paused)
                                const PopupMenuItem(
                                  value: GoalStatus.paused,
                                  child: Text('暂时搁置'),
                                ),
                              if (goal.status != GoalStatus.achieved)
                                const PopupMenuItem(
                                  value: GoalStatus.achieved,
                                  child: Text('标为已达成'),
                                ),
                              const PopupMenuItem(
                                value: GoalStatus.dropped,
                                child: Text('放弃目标'),
                              ),
                            ],
                          ],
                          child: const Padding(
                            padding: EdgeInsets.symmetric(
                              horizontal: AppLayout.spaceMd,
                              vertical: AppLayout.spaceMd,
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.more_horiz, size: AppLayout.iconMd),
                                SizedBox(width: AppLayout.spaceSm),
                                Text('更改状态'),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (goal.description != null || goal.why != null)
                      AppExpansionTile(
                        key: const Key('goal-description-toggle'),
                        childrenPadding: const EdgeInsets.only(
                          top: AppLayout.spaceSm,
                          bottom: AppLayout.spaceXl,
                        ),
                        expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
                        title: Text('目标说明', style: theme.textTheme.bodyMedium),
                        children: [
                          if (goal.description != null)
                            SelectableText(
                              goal.description!,
                              style: theme.textTheme.bodyMedium,
                            ),
                          if (goal.why != null) ...[
                            const SizedBox(height: AppLayout.spaceMd),
                            Text('为什么想实现', style: theme.textTheme.titleSmall),
                            const SizedBox(height: AppLayout.spaceSm),
                            SelectableText(
                              goal.why!,
                              style: theme.textTheme.bodyMedium,
                            ),
                          ],
                        ],
                      ),
                    const SizedBox(height: AppLayout.spaceXxl),
                    if (widget.missionService != null) ...[
                      GoalRecordSummary(
                        goalId: goal.id,
                        goals: widget.service,
                        missions: widget.missionService!,
                      ),
                      const SizedBox(height: AppLayout.spaceXxl),
                    ],
                    GoalOutlineSection(
                      service: widget.service,
                      missionService: widget.missionService,
                      goal: goal,
                      goalId: goal.id,
                      goalTitle: goal.title,
                    ),
                    const SizedBox(height: AppLayout.spaceXxl),
                    Text(
                      '创建于 ${_date(goal.createdAt.toLocal())}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
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

  String _date(DateTime value) => '${value.year}年${value.month}月${value.day}日';
}

import 'dart:async';
import 'package:flutter/material.dart';

import '../../../application/goals/goal_service.dart';
import '../../../application/missions/mission_service.dart';
import '../../../core/theme/app_layout.dart';
import '../../../core/theme/colors.dart';
import '../../../domain/entities/goal.dart';
import '../../widgets/app_top_bar.dart';
import '../../widgets/app_confirm_dialog.dart';
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
      await Navigator.of(context).push<String>(
        MaterialPageRoute(
          builder: (_) => GoalFormPage(service: widget.service, goal: goal),
        ),
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
  Widget build(BuildContext context) => Scaffold(
    appBar: const AppTopBar(title: '目标详情'),
    body: SafeArea(
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: AppLayout.maxPageWidth),
          child: FutureBuilder<Goal?>(
            future: _goal, // FutureBuilder 接收查询结果，等待、失败和成功分别展示。
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
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
              final goal = snapshot.data;
              if (goal == null) {
                return const Center(child: Text('未找到这个目标，请返回列表刷新'));
              }
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
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primarySoft,
                            borderRadius: BorderRadius.circular(20),
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
                              const SizedBox(height: 12),
                              badge,
                            ],
                          );
                        }
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(child: title),
                            const SizedBox(width: 16),
                            badge,
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 12,
                      runSpacing: 8,
                      children: [
                        OutlinedButton.icon(
                          key: const Key('goal-edit'),
                          onPressed: _busy ? null : () => _edit(goal),
                          icon: const Icon(Icons.edit_outlined, size: 18),
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
                              horizontal: 12,
                              vertical: 12,
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.more_horiz, size: 20),
                                SizedBox(width: 6),
                                Text('更改状态'),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (goal.description != null || goal.why != null)
                      ExpansionTile(
                        key: const Key('goal-description-toggle'),
                        tilePadding: EdgeInsets.zero,
                        childrenPadding: const EdgeInsets.only(bottom: 20),
                        shape: const Border(),
                        collapsedShape: const Border(),
                        expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
                        title: Text('目标说明', style: theme.textTheme.bodyMedium),
                        children: [
                          if (goal.description != null)
                            SelectableText(
                              goal.description!,
                              style: theme.textTheme.bodyMedium,
                            ),
                          if (goal.why != null) ...[
                            const SizedBox(height: 12),
                            Text('为什么想实现', style: theme.textTheme.titleSmall),
                            const SizedBox(height: 6),
                            SelectableText(
                              goal.why!,
                              style: theme.textTheme.bodyMedium,
                            ),
                          ],
                        ],
                      ),
                    const SizedBox(height: 28),
                    if (widget.missionService != null) ...[
                      GoalRecordSummary(
                        goalId: goal.id,
                        goals: widget.service,
                        missions: widget.missionService!,
                      ),
                      const SizedBox(height: 28),
                    ],
                    GoalOutlineSection(
                      service: widget.service,
                      missionService: widget.missionService,
                      goal: goal,
                      goalId: goal.id,
                      goalTitle: goal.title,
                    ),
                    const SizedBox(height: 24),
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

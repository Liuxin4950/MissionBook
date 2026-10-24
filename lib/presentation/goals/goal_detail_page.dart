import 'package:flutter/material.dart';

import '../../application/goals/goal_service.dart';
import '../../application/missions/mission_service.dart';
import '../../core/theme/app_layout.dart';
import '../../core/theme/colors.dart';
import '../../domain/entities/goal.dart';
import '../widgets/app_top_bar.dart';
import 'goal_outline_section.dart';
import 'goal_record_summary.dart';

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
  @override
  void initState() {
    super.initState();
    _goal = widget.service.findById(widget.goalId);
  }

  @override
  void didUpdateWidget(covariant GoalDetailPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.service != widget.service ||
        oldWidget.goalId != widget.goalId) {
      _goal = widget.service.findById(widget.goalId);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: const AppTopBar(title: '目标详情'),
    body: SafeArea(
      child: Center(
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

/// 列表与详情共用目标状态文字，不使用任务的“执行阶段”文案。
String goalStatusLabel(GoalStatus status) => switch (status) {
  GoalStatus.active => '正在推进',
  GoalStatus.paused => '暂时搁置',
  GoalStatus.achieved => '已经达到',
  GoalStatus.dropped => '已放弃',
};

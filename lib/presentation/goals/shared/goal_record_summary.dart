import 'dart:async';
import 'package:flutter/material.dart';
import '../../../application/goals/goal_service.dart';
import '../../../application/missions/mission_service.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/app_layout.dart';

/// 目标卡和详情共用的真实记录摘要；仅统计有效节点的直接完成报告，不表示掌握程度。
class GoalRecordSummary extends StatefulWidget {
  const GoalRecordSummary({
    super.key,
    required this.goalId,
    required this.goals,
    required this.missions,
    this.highlighted = false,
  });
  final String goalId;
  final GoalService goals;
  final MissionService missions;
  final bool highlighted;
  @override
  State<GoalRecordSummary> createState() => _GoalRecordSummaryState();
}

class _GoalRecordSummaryState extends State<GoalRecordSummary> {
  // Dart 的记录类型一次装两个具名整数；这是查询结果，不是一张新表或新的可写状态。
  late Future<({int total, int completed})> _summary;
  StreamSubscription<void>? _goals, _missions;
  @override
  void initState() {
    super.initState();
    _listen();
  }

  void _listen() {
    _read();
    _goals = widget.goals.changes.listen((_) => setState(_read));
    _missions = widget.missions.changes.listen((_) => setState(_read));
  }

  void _read() {
    _summary = _load();
    _summary.ignore();
  }

  Future<({int total, int completed})> _load() async {
    final nodes = await widget.goals.findNodes(widget.goalId);
    // 覆盖率口径（有效节点、直接完成报告、去重）集中在
    // domain/rules/goal_node_record_rules.dart，页面只负责展示。
    return widget.missions.findGoalCoverage(widget.goalId, nodes);
  }

  @override
  void didUpdateWidget(covariant GoalRecordSummary oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.goals != widget.goals ||
        oldWidget.missions != widget.missions ||
        oldWidget.goalId != widget.goalId) {
      unawaited(_goals?.cancel());
      unawaited(_missions?.cancel());
      _listen();
    }
  }

  @override
  void dispose() {
    unawaited(_goals?.cancel());
    unawaited(_missions?.cancel());
    super.dispose();
  }

  @override
  Widget build(
    BuildContext context,
  ) => FutureBuilder<({int total, int completed})>(
    future: _summary,
    builder: (context, snapshot) {
      final color = widget.highlighted
          ? AppColors.onPrimary
          : AppColors.textSecondary;
      if (snapshot.hasError) {
        return TextButton(
          onPressed: () => setState(_read),
          child: const Text('重新读取节点记录'),
        );
      }
      if (!snapshot.hasData) {
        return Text(
          '正在读取节点记录…',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: color),
        );
      }
      final value = snapshot.data!;
      if (value.total == 0) {
        return Text(
          '暂无节点',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: color),
        );
      }
      return Semantics(
        key: Key('goal-record-summary-${widget.goalId}'),
        container: true,
        label: '有效节点${value.total}项，其中${value.completed}项有直接完成记录，不表示掌握程度',
        child: ExcludeSemantics(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '节点完成记录',
                      style: Theme.of(
                        context,
                      ).textTheme.bodyMedium?.copyWith(color: color),
                    ),
                  ),
                  Text(
                    '${value.completed}',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: widget.highlighted
                          ? AppColors.accent
                          : AppColors.primary,
                    ),
                  ),
                  Text(
                    ' / ${value.total}',
                    style: Theme.of(
                      context,
                    ).textTheme.bodyMedium?.copyWith(color: color),
                  ),
                ],
              ),
              const SizedBox(height: AppLayout.spaceMd),
              if (value.total <= 12)
                Row(
                  children: [
                    for (var i = 0; i < value.total; i++)
                      Expanded(
                        child: Container(
                          height: 7,
                          margin: EdgeInsets.only(
                            right: i == value.total - 1 ? 0 : AppLayout.spaceXs,
                          ),
                          decoration: BoxDecoration(
                            color: i < value.completed
                                ? widget.highlighted
                                      ? AppColors.accent
                                      : AppColors.primary
                                : (widget.highlighted
                                      ? AppColors.onPrimary.withValues(
                                          alpha: .24,
                                        )
                                      : AppColors.primarySoft),
                            borderRadius: BorderRadius.circular(
                              AppLayout.radiusSm,
                            ),
                          ),
                        ),
                      ),
                  ],
                )
              else
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppLayout.radiusSm),
                  child: LinearProgressIndicator(
                    value: value.completed / value.total,
                    minHeight: 7,
                    color: widget.highlighted
                        ? AppColors.accent
                        : AppColors.primary,
                    backgroundColor: widget.highlighted
                        ? AppColors.onPrimary.withValues(alpha: .24)
                        : AppColors.primarySoft,
                  ),
                ),
            ],
          ),
        ),
      );
    },
  );
}

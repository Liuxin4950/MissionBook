import 'dart:async';

import 'package:flutter/material.dart';

import '../../../application/goals/goal_service.dart';
import '../../../application/missions/mission_service.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/app_layout.dart';

/// 目标卡和详情共用的任务完成进度；节点全部直接任务报告完成后才计为完成。
class GoalRecordSummary extends StatefulWidget {
  const GoalRecordSummary({
    super.key,
    required this.goalId,
    required this.goals,
    required this.missions,
  });
  final String goalId;
  final GoalService goals;
  final MissionService missions;
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
    // 进度口径（有效节点、全部直接任务均有完成报告）集中在
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
  Widget build(BuildContext context) =>
      FutureBuilder<({int total, int completed})>(
        future: _summary,
        builder: (context, snapshot) {
          final textStyle = Theme.of(context).textTheme.bodySmall;
          if (snapshot.hasError) {
            return TextButton(
              onPressed: () => setState(_read),
              child: const Text('重新读取节点记录'),
            );
          }
          if (!snapshot.hasData) {
            return Text('正在读取节点记录…', style: textStyle);
          }
          final value = snapshot.data!;
          if (value.total == 0) {
            return Text('暂无节点', style: textStyle);
          }
          return Semantics(
            key: Key('goal-record-summary-${widget.goalId}'),
            container: true,
            label:
                '有效节点${value.total}项，其中${value.completed}项的直接任务全部报告完成，不表示掌握程度',
            child: ExcludeSemantics(
              child: Row(
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(AppLayout.radiusXs),
                      child: LinearProgressIndicator(
                        value: value.completed / value.total,
                        minHeight: AppLayout.spaceXs,
                        color: AppColors.primary,
                        backgroundColor: AppColors.primarySoft,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppLayout.spaceSm),
                  Flexible(
                    child: Text(
                      '任务全部完成的节点 ${value.completed}/${value.total}',
                      style: textStyle,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
}

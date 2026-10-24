import 'dart:async';
import 'package:flutter/material.dart';
import '../../application/goals/goal_service.dart';
import '../../application/missions/mission_service.dart';
import '../../core/theme/colors.dart';
import '../../domain/entities/execution_event.dart';

/// 目标卡和详情共用的真实记录摘要；仅统计有效节点的直接完成报告，不表示掌握程度。
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
    final tasks = await widget.missions.findForGoal(widget.goalId);
    final completedIds = <String>{}; // Set 按节点编号去重，同节点完成多次也只记一次。
    for (final task in tasks) {
      final nodeId = task.mission.goalNodeId;
      if (nodeId != null &&
          task.events.any(
            (event) =>
                event.type == ExecutionEventType.end &&
                event.userReportedResult == UserReportedResult.completed,
          )) {
        completedIds.add(nodeId);
      }
    }
    final active = nodes.where((node) => node.archivedAt == null).toList();
    return (
      total: active.length,
      completed: active.where((node) => completedIds.contains(node.id)).length,
    );
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
    } else {
      _read();
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
      const color = AppColors.textSecondary;
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
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
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
              const SizedBox(height: 10),
              if (value.total <= 12)
                Row(
                  children: [
                    for (var i = 0; i < value.total; i++)
                      Expanded(
                        child: Container(
                          height: 7,
                          margin: EdgeInsets.only(
                            right: i == value.total - 1 ? 0 : 4,
                          ),
                          decoration: BoxDecoration(
                            color: i < value.completed
                                ? AppColors.primary
                                : AppColors.primarySoft,
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                  ],
                )
              else
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: value.completed / value.total,
                    minHeight: 7,
                    color: AppColors.primary,
                    backgroundColor: AppColors.primarySoft,
                  ),
                ),
            ],
          ),
        ),
      );
    },
  );
}

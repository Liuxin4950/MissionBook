import '../../../domain/entities/goal.dart';

/// 列表与详情共用目标状态文字，不使用任务的“执行阶段”文案。
String goalStatusLabel(GoalStatus status) => switch (status) {
  GoalStatus.active => '正在推进',
  GoalStatus.paused => '暂时搁置',
  GoalStatus.achieved => '已经达到',
  GoalStatus.dropped => '已放弃',
};

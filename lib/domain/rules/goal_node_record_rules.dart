import '../entities/goal_node.dart';
import '../entities/mission_detail.dart';
import '../entities/mission_phase.dart';

/// 目标节点状态的纯规则：节点行显示记录存在，目标进度要求所有直接任务完成。
/// END(COMPLETED) 是用户完成报告，不表示验证通过或技能掌握。

/// 一组直接关联任务里是否存在用户报告“已完成”的完成记录。
bool hasCompletionRecord(List<MissionDetail> directMissions) =>
    directMissions.any((detail) => detail.endReportedCompleted);

/// 节点状态：所有直接任务都报告完成时显示已完成；否则显示局部完成或当前阶段。
String nodeRecordLabel(List<MissionDetail> directMissions) {
  if (directMissions.isNotEmpty &&
      directMissions.every((detail) => detail.endReportedCompleted)) {
    return '已完成';
  }
  if (hasCompletionRecord(directMissions)) return '部分完成';
  if (directMissions.any(
    (detail) => detail.phase == MissionPhase.reportPending,
  )) {
    return '待确认';
  }
  if (directMissions.any(
    (detail) =>
        detail.phase == MissionPhase.running ||
        detail.phase == MissionPhase.paused,
  )) {
    return '执行中';
  }
  if (directMissions.any((detail) => detail.phase == MissionPhase.notStarted)) {
    return '已安排';
  }
  return '暂无完成记录';
}

/// 目标进度：分母是未归档节点，分子是有直接任务且全部报告完成的节点。
///
/// 每个节点只计一次；无直接任务的节点不算完成。分母为 0 时调用方显示“暂无节点”，
/// 不显示 100%。返回的记录类型一次装两个具名整数。
({int total, int completed}) goalNodeCoverage(
  List<GoalNode> nodes,
  List<MissionDetail> tasks,
) {
  final missionsByNode = <String, List<MissionDetail>>{};
  for (final task in tasks) {
    final nodeId = task.mission.goalNodeId;
    if (nodeId != null) {
      (missionsByNode[nodeId] ??= []).add(task);
    }
  }
  final completedNodeIds = missionsByNode.entries
      .where((entry) => entry.value.every((task) => task.endReportedCompleted))
      .map((entry) => entry.key)
      .toSet();
  return goalNodeCoverageFromIds(nodes, completedNodeIds);
}

/// 全部直接任务已报告完成的节点编号，可由批量查询提供。
({int total, int completed}) goalNodeCoverageFromIds(
  List<GoalNode> nodes,
  Set<String> completedNodeIds,
) {
  final active = nodes.where((node) => node.archivedAt == null).toList();
  return (
    total: active.length,
    completed: active
        .where((node) => completedNodeIds.contains(node.id))
        .length,
  );
}

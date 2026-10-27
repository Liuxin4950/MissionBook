import '../entities/goal_node.dart';
import '../entities/mission_detail.dart';
import '../entities/mission_phase.dart';

/// 目标节点的真实记录口径（领域模型 §2.3）。
///
/// 两个页面（目标大纲的任务区、目标卡的记录摘要）过去各自实现了一遍
/// 同样的判定，改动口径要改多处。这里集中“完成记录 / 记录标签 / 覆盖率”
/// 三个纯函数：只读取已保存事实，不查库、不写库、不看当前时间。
/// 注意：完成记录只是 END 报告“已完成”，不表示验证通过或技能掌握。

/// 一组直接关联任务里是否存在用户报告“已完成”的完成记录。
bool hasCompletionRecord(List<MissionDetail> directMissions) =>
    directMissions.any((detail) => detail.endReportedCompleted);

/// 节点记录标签，按领域模型 §2.3 的优先级取第一个成立的：
/// 有完成记录 > 执行中（含已暂停）> 已安排 > 暂无完成记录。
String nodeRecordLabel(List<MissionDetail> directMissions) {
  if (hasCompletionRecord(directMissions)) return '有完成记录';
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

/// 节点覆盖率：分母是未归档的有效节点，分子是其中“有直接完成记录”的节点。
///
/// 同一节点完成多个任务只记一次；分母为 0 时调用方显示“暂无节点”，
/// 不显示 100%。返回的记录类型一次装两个具名整数。
({int total, int completed}) goalNodeCoverage(
  List<GoalNode> nodes,
  List<MissionDetail> tasks,
) {
  // Set 按节点编号去重，同节点完成多次也只记一次。
  final completedNodeIds = <String>{};
  for (final task in tasks) {
    final nodeId = task.mission.goalNodeId;
    if (nodeId != null && task.endReportedCompleted) {
      completedNodeIds.add(nodeId);
    }
  }
  return goalNodeCoverageFromIds(nodes, completedNodeIds);
}

/// 完成节点编号来自直接关联任务的 END(COMPLETED)，可由批量查询提供。
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

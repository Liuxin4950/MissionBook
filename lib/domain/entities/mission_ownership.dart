import 'goal.dart';
import 'goal_node.dart';

/// 一次任务的归属选择；两个编号都为空时就是独立任务。
class MissionOwnership {
  const MissionOwnership({this.goalId, this.goalNodeId});
  final String? goalId; // 只选目标时，节点编号仍可为空。
  final String? goalNodeId; // 选择节点时，必须同时提供它所属的目标编号。

  void validate() {
    if ((goalId != null &&
            (goalId!.trim().isEmpty || goalId != goalId!.trim())) ||
        (goalNodeId != null &&
            (goalNodeId!.trim().isEmpty || goalNodeId != goalNodeId!.trim())) ||
        (goalNodeId != null && goalId == null)) {
      throw ArgumentError('任务归属无效：选择节点时必须同时选择所属目标');
    }
  }

  // 重写 ==，让两个归属对象按编号比较；不要求它们是同一个对象实例。
  @override
  bool operator ==(Object other) =>
      other is MissionOwnership &&
      other.goalId == goalId &&
      other.goalNodeId == goalNodeId;
  @override
  int get hashCode => Object.hash(goalId, goalNodeId);
}

/// 选择器读取的一个目标及其全部节点，不对应新的数据库表。
class MissionGoalChoices {
  const MissionGoalChoices({required this.goal, required this.nodes});
  final Goal goal;
  final List<GoalNode> nodes; // 包含归档项，已有任务仍需要显示原来的路径。

  MissionOwnershipInfo resolve(MissionOwnership ownership) {
    if (ownership.goalId != goal.id) throw StateError('任务与目标归属不一致');
    final byId = {for (final node in nodes) node.id: node};
    final reversed = <GoalNode>[];
    final visited = <String>{};
    var id = ownership.goalNodeId;
    while (id != null) {
      final node = byId[id];
      if (node == null || !visited.add(id)) throw StateError('任务关联的节点路径不完整');
      reversed.add(node);
      id = node.parentNodeId; // 从所选节点向上找父节点，最后反转为从根到叶的阅读顺序。
    }
    return MissionOwnershipInfo(goal: goal, path: reversed.reversed.toList());
  }
}

/// 任务详情读取到的目标名称和节点路径；名称变化不会改变任务保存的归属编号。
class MissionOwnershipInfo {
  const MissionOwnershipInfo({required this.goal, this.path = const []});
  final Goal goal;
  final List<GoalNode> path;
  bool get available =>
      goal.status == GoalStatus.active &&
      path.every((node) => node.archivedAt == null);
  String get label =>
      [goal.title, ...path.map((node) => node.title)].join(' / ');
}

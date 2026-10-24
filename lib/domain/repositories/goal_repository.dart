import '../entities/goal.dart';
import '../entities/goal_node.dart';

/// 约定目标及其节点需要哪些存取操作；业务层不需要认识 SQL 或 Drift 的类型。
abstract interface class GoalRepository {
  Future<void> create(Goal goal); // 保存准备好的目标；相同编号和内容重试不重复插入。
  Future<List<Goal>> findAll(); // 默认不含放弃的目标，按创建时间从新到旧排列。
  Future<Goal?> findById(String id); // 查不到时返回 null，由页面显示明确提示。

  // 目标与它的大纲由同一个仓储维护，页面通过 GoalService 调用这些操作。
  Future<List<GoalNode>> findNodes(String goalId); // 包含归档项，供树展示、恢复和同级调序使用。
  Future<GoalNode?> findNodeById(String id); // 用固定编号确认上次创建是否已保存。
  Future<void> createNode(GoalNodeCreation request); // 事务内校验父节点并分配同级顺序。
  Future<void> updateNode(
    GoalNode expected, { // 页面读到的原记录，用来发现其他入口已经修改的内容。
    required String title,
    String? description,
  });
  Future<void> reorderNodes({
    required String goalId,
    required String? parentNodeId,
    required List<String> expectedIds, // 页面操作前的全部同级编号，包含归档项。
    required List<String> orderedIds, // 希望保存的新顺序，成员必须与原顺序相同。
  });
  Future<void> setNodeArchived(
    String id, {
    required bool archived,
  }); // 整棵子树一起归档或恢复。
}

import 'goal.dart';
import 'goal_node.dart';

/// 外部 JSON 校验后的预览结构；key 只在本次解析中去重，不写入数据库。
class GoalImportNode {
  const GoalImportNode({
    required this.key,
    required this.title,
    this.description,
    this.children = const [],
  });
  final String key;
  final String title;
  final String? description;
  final List<GoalImportNode> children;
}

class GoalOutlineImport {
  const GoalOutlineImport({
    required this.title,
    this.description,
    this.why,
    required this.nodes,
    required this.nodeCount,
  });
  final String title;
  final String? description;
  final String? why;
  final List<GoalImportNode> nodes;
  final int nodeCount;
}

/// 一次固定的导入请求，失败重试使用同样的编号、父子关系与顺序。
class GoalOutlineCreation {
  const GoalOutlineCreation({required this.goal, required this.nodes});
  final Goal goal;
  final List<GoalNode> nodes;
}

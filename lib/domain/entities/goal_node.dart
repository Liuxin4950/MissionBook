/// 表达已经保存的目标节点；父子关系与顺序共同决定大纲位置。
class GoalNode {
  const GoalNode({
    required this.id,
    required this.goalId,
    required this.title,
    required this.orderIndex,
    required this.createdAt,
    required this.updatedAt,
    this.parentNodeId,
    this.description,
    this.archivedAt,
  });

  final String id; // 节点自身的编号。
  final String goalId; // 所属目标的编号。
  final String? parentNodeId; // 父节点编号；null 表示顶层节点。
  final String title; // 去除首尾空白后的非空名称。
  final String? description; // 选填的节点说明，未填保存 null。
  final int orderIndex; // 包含归档项的同级存储顺序，从 0 开始。
  final DateTime? archivedAt; // 归档时刻；恢复后重新为 null。
  final DateTime createdAt; // UTC 创建时刻。
  final DateTime updatedAt; // UTC 最近修改时刻。
}

/// 保存前固定节点的编号和输入；同级顺序留给仓储在写入时分配。
class GoalNodeCreation {
  const GoalNodeCreation({
    required this.id,
    required this.goalId,
    required this.title,
    required this.createdAt,
    this.parentNodeId,
    this.description,
  });

  final String id; // 服务首次准备请求时生成，重试不再生成。
  final String goalId; // 打开编辑框的目标提供。
  final String? parentNodeId; // 添加子节点时传入父节点编号；添加顶层时为空。
  final String title; // 用户填写并整理后的名称。
  final String? description; // 用户填写并整理后的说明。
  final DateTime createdAt; // 请求首次准备时固定的 UTC 毫秒时刻。

  void validate() {
    final identifiers = [id, goalId];
    if (parentNodeId != null) identifiers.add(parentNodeId!);
    for (final value in identifiers) {
      if (value.trim().isEmpty || value != value.trim()) {
        throw ArgumentError('节点、目标或父节点编号不能为空或带首尾空白');
      }
    }
    validateGoalNodeText(title, description);
    if (parentNodeId == id) throw ArgumentError('节点不能作为自己的父节点');
    if (!createdAt.isUtc || createdAt.microsecond != 0) {
      throw ArgumentError('节点创建时刻必须使用 UTC 毫秒精度');
    }
  }
}

/// 创建和编辑共用文字校验，防止绕过表单后写入空名称。
void validateGoalNodeText(String title, String? description) {
  if (title.trim().isEmpty || title != title.trim()) {
    throw ArgumentError('请填写节点名称，并去除首尾空白');
  }
  if (description != null &&
      (description.isEmpty || description != description.trim())) {
    throw ArgumentError('节点说明为空时使用 null，有内容时去除首尾空白');
  }
}

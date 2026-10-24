import 'package:drift/drift.dart';

import 'goals.dart';

/// 保存目标大纲的所有层级，通过父节点编号连接成树。
@TableIndex.sql(
  'CREATE INDEX goal_nodes_siblings ON goal_nodes (goal_id, parent_node_id, order_index)',
)
@DataClassName('GoalNodeRow') // 数据库行叫 GoalNodeRow，业务对象叫 GoalNode。
class GoalNodes extends Table {
  TextColumn get id => text()(); // 服务生成的节点编号；失败重试沿用这个编号。
  TextColumn get goalId => text().references(Goals, #id)(); // 引用已保存的目标。
  TextColumn get parentNodeId => text().nullable()(); // 顶层节点没有父节点，保存 null。
  TextColumn get title => text().customConstraint(
    'NOT NULL CHECK (length(trim(title)) > 0)',
  )(); // 名称必填；说明可以不填。
  TextColumn get description => text().nullable()();
  IntColumn get orderIndex => integer().customConstraint(
    'NOT NULL CHECK (order_index >= 0)',
  )(); // 同级顺序由仓储在事务内分配，页面不用猜下一个序号。
  IntColumn get archivedAt =>
      integer().nullable()(); // null 表示有效；有值表示归档的 UTC 毫秒。
  IntColumn get createdAt => integer()(); // 创建时刻，UTC 毫秒。
  IntColumn get updatedAt => integer()(); // 最近一次编辑、调序或归档恢复的时刻。

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<String> get customConstraints => [
    'UNIQUE (id, goal_id)', // 供下面的组合外键引用同一行的编号和目标。
    'FOREIGN KEY (parent_node_id, goal_id) REFERENCES goal_nodes (id, goal_id)',
    'CHECK (parent_node_id IS NULL OR parent_node_id <> id)',
  ]; // 组合外键要求父节点与子节点属于同一目标；不级联删除任何记录。
}

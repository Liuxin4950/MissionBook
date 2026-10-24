import 'package:drift/drift.dart';
import 'goals.dart';
import 'goal_nodes.dart';

// 指定 Drift 生成的“数据库行对象”叫 MissionRow，
// 避免与 domain 中的 Mission 混淆。
@DataClassName('MissionRow')
@TableIndex.sql(
  'CREATE INDEX missions_goal_node ON missions (goal_id, goal_node_id)',
)
class Missions extends Table {
  // v8：都可以为空，旧任务升级后自然仍是独立任务。
  TextColumn get goalId => text().nullable().references(Goals, #id)();
  TextColumn get goalNodeId => text()
      .nullable()
      .references(GoalNodes, #id)
      .check(
        const CustomExpression<bool>(
          'goal_node_id IS NULL OR goal_id IS NOT NULL',
        ),
      )();

  // 任务唯一编号，由创建流程生成后传入。
  TextColumn get id => text()();

  // 任务标题。
  // 数据库要求不能为 null；去除空白后非空由业务流程校验。
  TextColumn get title => text()();

  // 任务描述，可以没有。
  TextColumn get description => text().nullable()();

  // 为什么现在做这个任务，可以没有。
  TextColumn get why => text().nullable()();

  // 验证策略，使用稳定字符串保存。
  // SELF_REPORT：自报
  // OPTIONAL_EVIDENCE：可选材料
  // REQUIRED_EVIDENCE：强制材料
  // 插入时省略该列，数据库默认使用 SELF_REPORT。
  TextColumn get verificationPolicy =>
      text().withDefault(const Constant('SELF_REPORT'))();

  // 创建时刻：距 Unix 纪元的毫秒数。
  IntColumn get createdAt => integer()();

  // 最近业务修改时刻：距 Unix 纪元的毫秒数。
  IntColumn get updatedAt => integer()();

  // 取消时刻：距 Unix 纪元的毫秒数。
  // null 表示没有取消。
  IntColumn get cancelledAt => integer().nullable()();

  // v5：用户放弃可选材料的 UTC 时刻；阶段仍从事实推导。
  IntColumn get evidenceWaivedAt => integer().nullable()();

  // v4：再次尝试的来源。只复制计划，不复制来源的事件、报告或材料。
  TextColumn get sourceMissionId =>
      text().nullable().references(Missions, #id)();
  TextColumn get relationType => text().nullable().customConstraint(
    "NULL CHECK (relation_type IS NULL OR relation_type = 'RETRY')",
  )();

  // 使用 id 作为主键，唯一标识每条任务记录。
  @override
  Set<Column> get primaryKey => {id};
}

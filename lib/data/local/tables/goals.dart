import 'package:drift/drift.dart';

/// 定义目标在 SQLite 中的存储结构，不承担页面交互或业务创建流程。
@DataClassName('GoalRow') // 生成的行叫 GoalRow，与业务对象 Goal 区分。
class Goals extends Table {
  TextColumn get id => text()(); // 创建流程生成的 UUID，重试保存沿用同一个编号。
  TextColumn get title => text().customConstraint(
    'NOT NULL CHECK (length(trim(title)) > 0)',
  )(); // 数据库也拒绝空名称；完整输入清理由业务入口负责。
  TextColumn get description => text().nullable()(); // 未填写说明时保存 null。
  TextColumn get why => text().nullable()(); // 用户为什么希望实现这个目标，可不填。
  IntColumn get desireLevel => integer().nullable().customConstraint(
    'CHECK (desire_level BETWEEN 1 AND 5)',
  )();
  TextColumn get status =>
      text().withDefault(const Constant('ACTIVE'))(); // 稳定文本。
  IntColumn get createdAt => integer()(); // UTC 时刻，单位为 Unix 毫秒。
  IntColumn get updatedAt => integer()(); // 最近修改时刻；不代表完整修改历史。

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<String> get customConstraints => [
    "CHECK (status IN ('ACTIVE', 'PAUSED', 'ACHIEVED', 'DROPPED'))",
  ]; // 表级约束限定合法状态，不覆盖 Drift 提供的默认值。
}

import 'package:drift/drift.dart';

// 指定 Drift 生成的“数据库行对象”叫 MissionRow，
// 避免与 domain 中的 Mission 混淆。
@DataClassName('MissionRow')
class Missions extends Table {
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

  // 使用 id 作为主键，唯一标识每条任务记录。
  @override
  Set<Column> get primaryKey => {id};
}
import 'package:drift/drift.dart';

import 'missions.dart';

// 查询得到的一条方案记录，生成类型名为 ExecutionPlanRow。
@DataClassName('ExecutionPlanRow')
class ExecutionPlans extends Table {
  // 执行方案自身的唯一编号。
  TextColumn get id => text()();

  // 所属任务编号，引用 missions 表中的 id。
  // 同时要求该编号在本表内不能重复：一个任务最多一份方案。
  TextColumn get missionId => text().references(Missions, #id).unique()();

  // 本次任务的具体目标。
  // 用户未单独填写时，由创建流程采用任务标题。
  TextColumn get objective => text()();

  // 有序步骤列表，以 JSON 文本保存。
  // 例如 ["创建按钮","编写点击事件"]。
  // 未填写步骤时保存空列表文本 []。
  TextColumn get steps => text().withDefault(const Constant('[]'))();

  // 用户填写的验收方向。
  // 自报策略可以为空，材料策略的非空要求由业务流程校验。
  TextColumn get verificationCriteria => text().nullable()();

  // 补充说明，可以没有。
  TextColumn get notes => text().nullable()();

  // 方案首次创建时刻，保存为毫秒时间戳。
  IntColumn get createdAt => integer()();

  // 方案最近修改时刻，保存为毫秒时间戳。
  IntColumn get updatedAt => integer()();

  // 使用方案自身的 id 作为主键。
  @override
  Set<Column> get primaryKey => {id};
}

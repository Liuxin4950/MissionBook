import 'package:drift/drift.dart';

import 'missions.dart';

// 查询得到的一条排期记录，生成类型名为 MissionScheduleRevisionRow。
@DataClassName('MissionScheduleRevisionRow')
class MissionScheduleRevisions extends Table {
  // 这条排期记录自身的唯一编号。
  TextColumn get id => text()();

  // 所属任务编号，引用 missions 表中的 id。
  TextColumn get missionId => text().references(Missions, #id)();

  // 同一任务内的排期版本号，从 1 开始递增。
  // 正整数、连续递增及首次必须为 1，由业务流程校验。
  IntColumn get revisionNumber => integer()();

  // 排期日期，保存为 YYYY-MM-DD，例如 2026-10-19。
  TextColumn get scheduledDate => text()();

  // 排期采用的 IANA 时区名称，例如 Asia/Shanghai。
  TextColumn get timeZone => text()();

  // 时间策略：FLEXIBLE 为自选时间，FIXED 为固定时间。
  // 插入时省略这一列，默认使用 FLEXIBLE。
  TextColumn get timePolicy => text().withDefault(const Constant('FLEXIBLE'))();

  // 固定开始时刻，保存为毫秒时间戳。
  // 固定时间策略必须有值，自选时间策略必须为空。
  IntColumn get fixedStartAt => integer().nullable()();

  // 计划投入的分钟数，业务流程要求为正整数。
  IntColumn get plannedDurationMinutes => integer()();

  // 强制材料提交截止时刻，保存为毫秒时间戳。
  // 仅强制材料策略需要，其他策略为空。
  IntColumn get evidenceDeadlineAt => integer().nullable()();

  // 用户填写的改期原因，可以没有。
  TextColumn get changeReason => text().nullable()();

  // 这条排期版本产生的时刻，保存为毫秒时间戳。
  IntColumn get changedAt => integer()();

  // 每条排期记录使用自己的 id 作为主键。
  @override
  Set<Column> get primaryKey => {id};

  // 同一任务内，排期版本号不能重复。
  @override
  List<Set<Column>> get uniqueKeys => [
    {missionId, revisionNumber},
  ];
}

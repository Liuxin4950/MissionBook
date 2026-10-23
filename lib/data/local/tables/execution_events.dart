import 'package:drift/drift.dart';

import 'mission_schedule_revisions.dart';
import 'missions.dart';

// 两个“部分唯一索引”：分别只检查 START 行和 END 行。
// 不能直接让 {missionId, type} 唯一，否则同一任务也只能暂停一次。
@TableIndex.sql(
  "CREATE UNIQUE INDEX execution_events_one_start ON execution_events (mission_id) WHERE type = 'START'",
)
@TableIndex.sql(
  "CREATE UNIQUE INDEX execution_events_one_end ON execution_events (mission_id) WHERE type = 'END'",
)
@DataClassName('ExecutionEventRow')
class ExecutionEvents extends Table {
  // 本次操作的唯一编号；同一次请求重试应复用原编号。
  TextColumn get id => text()();

  // 所属任务。外键拒绝引用不存在的任务，不级联删除历史。
  TextColumn get missionId => text().references(Missions, #id)();

  // 同一任务内的顺序号，从 1 开始。
  // 数据库保证正数和不重复；连续性仍须在写事务内结合旧事件校验。
  IntColumn get sequence => integer()();

  // 用稳定字符串保存动作，不保存 Dart 枚举的下标。
  TextColumn get type => text()();

  // 实际操作时刻，保存 UTC 毫秒时间戳；不使用页面计时器累计值。
  IntColumn get occurredAt => integer()();

  // 仅 START 有值。外键保证排期存在；同任务和最新版本在事务内校验。
  TextColumn get scheduleRevisionId =>
      text().nullable().references(MissionScheduleRevisions, #id)();

  // 仅 EXTEND 有值，单位分钟；null 表示这条事件没有增加额度。
  IntColumn get grantedDurationMinutes => integer().nullable()();

  // PAUSE 的可选原因；未完成原因属于后续 FailureRecord，不放在这里。
  TextColumn get reason => text().nullable()();

  // 仅 END 有报告：COMPLETED（完成）或 NOT_COMPLETED（未完成）。
  TextColumn get userReportedResult => text().nullable()();

  // 仅 END + 完成 + 可选材料策略适用。
  // true 为稍后补材料，false 为直接结束，null 为不适用，不能混用。
  BoolColumn get submitOptionalEvidence => boolean().nullable()();

  @override
  Set<Column> get primaryKey => {id};

  // A/1 与 B/1 可共存，A/1 不能重复；同时支持按任务与序号读取时间线。
  @override
  List<Set<Column>> get uniqueKeys => [
    {missionId, sequence},
  ];

  // CHECK 是 SQLite 对每条写入的基本检查；使用实际的 snake_case 列名。
  // 可空列值为 null 时允许通过，是否适用仍由业务规则结合动作/策略判断。
  @override
  List<String> get customConstraints => [
    'CHECK (sequence > 0)',
    "CHECK (type IN ('START', 'PAUSE', 'RESUME', 'EXTEND', 'END'))",
    'CHECK (granted_duration_minutes > 0)',
    "CHECK (user_reported_result IN ('COMPLETED', 'NOT_COMPLETED'))",
  ];
}

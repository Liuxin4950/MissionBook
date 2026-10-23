import 'package:drift/drift.dart';
import 'missions.dart';

/// END 与必要失败记录同事务保存；原因可空，记录本身不可省略。
@DataClassName('FailureRecordRow')
class FailureRecords extends Table {
  TextColumn get id => text()();
  TextColumn get missionId => text().references(Missions, #id)();
  // USER_MARKED_NOT_COMPLETED / EVIDENCE_DEADLINE_MISSED，稳定字符串。
  TextColumn get trigger => text()();
  // UTC 毫秒；用户未完成时等于 END.occurredAt。
  IntColumn get occurredAt => integer()();
  TextColumn get userReasonCategory => text().nullable()();
  TextColumn get userReasonText => text().nullable()();
  // 实际落库时刻，UTC 毫秒。
  IntColumn get createdAt => integer()();

  @override
  Set<Column> get primaryKey => {id};
  @override
  List<Set<Column>> get uniqueKeys => [
    {missionId, trigger},
  ];
  @override
  List<String> get customConstraints => [
    'CHECK ("trigger" IN (\'USER_MARKED_NOT_COMPLETED\', \'EVIDENCE_DEADLINE_MISSED\'))',
    "CHECK (user_reason_category IN ('TIME_INSUFFICIENT', 'TOO_DIFFICULT', 'URGENT_EVENT', 'BAD_STATE', 'DO_NOT_WANT_CONTINUE', 'ENVIRONMENT_PROBLEM', 'OTHER'))",
  ];
}

import 'package:drift/drift.dart';

@TableIndex.sql(
  'CREATE INDEX assistant_sessions_updated ON assistant_sessions(updated_at, id)',
)
class AssistantSessions extends Table {
  TextColumn get id => text()();
  TextColumn get title => text()();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();
  TextColumn get missionId => text().nullable()();
  TextColumn get goalId => text().nullable()();
  TextColumn get writerToken => text().nullable()();
  IntColumn get writerLeaseUntil => integer().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

class AssistantSessionRecords extends Table {
  TextColumn get sessionId => text().references(AssistantSessions, #id)();
  IntColumn get sequence => integer()();
  IntColumn get timestamp => integer()();
  TextColumn get type => text()();
  TextColumn get data => text()();
  IntColumn get version => integer().withDefault(const Constant(1))();
  BoolColumn get ignorable => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {sessionId, sequence};
}

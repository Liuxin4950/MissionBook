import 'package:drift/drift.dart';
import 'goals.dart';

/// 与创建数据同事务保存的回执；后续编辑任务不改变首次导入身份。
@TableIndex.sql(
  'CREATE INDEX import_receipts_content ON import_receipts(schema_name, content_sha256)',
)
class ImportReceipts extends Table {
  TextColumn get schemaName => text()();
  TextColumn get packageId => text()();
  IntColumn get schemaVersion => integer()();
  TextColumn get payloadSha256 => text()();
  TextColumn get contentSha256 => text()();
  TextColumn get goalId => text().references(Goals, #id)();
  IntColumn get importedAt => integer()();
  IntColumn get nodeCount => integer()();
  IntColumn get missionCount => integer()();
  @override
  Set<Column> get primaryKey => {schemaName, packageId};
}

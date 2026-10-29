import 'package:drift/drift.dart';

@TableIndex.sql(
  'CREATE INDEX operation_receipts_entity ON operation_receipts(kind, entity_id)',
)
class OperationReceipts extends Table {
  TextColumn get id => text()();
  TextColumn get kind => text()();
  TextColumn get fingerprint => text()();
  TextColumn get entityId => text()();
  TextColumn get resultJson => text()();
  IntColumn get createdAt => integer()();

  @override
  Set<Column> get primaryKey => {id};
}

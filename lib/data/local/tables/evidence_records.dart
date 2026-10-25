import 'package:drift/drift.dart';
import 'missions.dart';

/// 正式材料追加保存；草稿不入表。批次身份解决“保存成功但响应丢失”的重试。
@DataClassName('EvidenceRow')
class EvidenceRecords extends Table {
  TextColumn get id => text()();
  TextColumn get missionId => text().references(Missions, #id)();
  TextColumn get submissionId => text()();
  TextColumn get type => text()();
  TextColumn get source => text()();
  TextColumn get content => text().nullable()();
  TextColumn get attachmentStorageKey => text().nullable().unique()();
  TextColumn get attachmentFileName => text().nullable()();
  TextColumn get attachmentMimeType => text().nullable()();
  IntColumn get capturedAt => integer().nullable()();
  IntColumn get submittedAt => integer()(); // UTC 毫秒；同批相同。
  TextColumn get supersedesEvidenceId =>
      text().nullable().unique().references(EvidenceRecords, #id)();
  @override
  Set<Column> get primaryKey => {id};
  @override
  List<String> get customConstraints => [
    "CHECK (((type IN ('TEXT', 'CODE', 'MANUAL_RECORD')) AND source = 'USER' AND content IS NOT NULL AND length(trim(content)) > 0 AND attachment_storage_key IS NULL AND attachment_file_name IS NULL AND attachment_mime_type IS NULL) OR (type = 'IMAGE' AND source IN ('FILE_SYSTEM', 'CAMERA') AND attachment_storage_key IS NOT NULL AND attachment_file_name IS NOT NULL) OR (type = 'FILE' AND source = 'FILE_SYSTEM' AND attachment_storage_key IS NOT NULL AND attachment_file_name IS NOT NULL))",
  ];
}

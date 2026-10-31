import 'package:drift/drift.dart';
import '../../domain/entities/evidence.dart';
import '../local/app_database.dart';

/// 旧列仅用于旧库/旧导入兼容，业务查询统一从记录还原材料投影。
Future<List<EvidenceRow>> hydrateEvidenceRows(
  AppDatabase database,
  Iterable<EvidenceRow> input,
) async {
  final rows = input.toList();
  final ids = rows.map((e) => e.recordId).whereType<String>().toSet();
  if (ids.isEmpty) return rows;
  final records = await (database.select(
    database.records,
  )..where((t) => t.id.isIn(ids))).get();
  final byId = {for (final r in records) r.id: r};
  return rows.map((e) {
    if (e.recordId == null) return e;
    final r = byId[e.recordId];
    if (r == null) throw const FormatException('材料引用的记录不存在');
    return e.copyWith(
      content: Value(r.content),
      attachmentStorageKey: Value(r.attachmentStorageKey),
      attachmentFileName: Value(r.attachmentFileName),
      attachmentMimeType: Value(r.attachmentMimeType),
      capturedAt: Value(r.capturedAt),
    );
  }).toList();
}

/// 新材料创建记录；关联已有记录只追加引用，两条入口共用同一写入函数。
Future<void> insertEvidence(
  AppDatabase database,
  Evidence item, {
  String? existingRecordId,
}) async {
  final payload = evidenceToCompanion(item);
  final mission = await (database.select(
    database.missions,
  )..where((t) => t.id.equals(item.missionId))).getSingle();
  if (existingRecordId == null) {
    await database
        .into(database.records)
        .insert(
          RecordsCompanion.insert(
            id: item.id,
            type: payload.type.value,
            source: payload.source.value,
            content: payload.content,
            attachmentStorageKey: payload.attachmentStorageKey,
            attachmentFileName: payload.attachmentFileName,
            attachmentMimeType: payload.attachmentMimeType,
            capturedAt: payload.capturedAt,
            occurredAt:
                (item.capturedAt ?? item.submittedAt).millisecondsSinceEpoch,
            createdAt: item.submittedAt.millisecondsSinceEpoch,
            goalId: Value(mission.goalId),
            goalNodeId: Value(mission.goalNodeId),
          ),
        );
  } else {
    final record = await (database.select(
      database.records,
    )..where((row) => row.id.equals(existingRecordId))).getSingleOrNull();
    if (record == null ||
        !sameEvidenceInput(
          evidenceDraftFromRecord(record, id: item.id),
          item,
        )) {
      throw const EvidenceConflict('记录内容已变化，请重新读取后关联');
    }
  }
  await database
      .into(database.evidenceRecords)
      .insert(
        payload.copyWith(
          recordId: Value(existingRecordId ?? item.id),
          content: const Value(null),
          attachmentStorageKey: const Value(null),
          attachmentFileName: const Value(null),
          attachmentMimeType: const Value(null),
          capturedAt: const Value(null),
        ),
      );
}

/// 存储层把稳定文本/UTC 毫秒转换成业务类型，未知值立即报错。
Evidence evidenceFromRow(EvidenceRow row) => Evidence(
  id: row.id,
  missionId: row.missionId,
  submissionId: row.submissionId,
  type: evidenceTypeFromStorage(row.type),
  source: evidenceSourceFromStorage(row.source),
  content: row.content,
  attachmentStorageKey: row.attachmentStorageKey,
  attachmentFileName: row.attachmentFileName,
  attachmentMimeType: row.attachmentMimeType,
  capturedAt: row.capturedAt == null
      ? null
      : DateTime.fromMillisecondsSinceEpoch(row.capturedAt!, isUtc: true),
  submittedAt: DateTime.fromMillisecondsSinceEpoch(
    row.submittedAt,
    isUtc: true,
  ),
  supersedesEvidenceId: row.supersedesEvidenceId,
);

/// 从既有记录准备材料意图，提交身份与时刻仍由材料命令决定。
EvidenceDraft evidenceDraftFromRecord(RecordRow row, {required String id}) =>
    EvidenceDraft(
      id: id,
      type: evidenceTypeFromStorage(row.type),
      source: evidenceSourceFromStorage(row.source),
      content: row.content,
      attachmentStorageKey: row.attachmentStorageKey,
      attachmentFileName: row.attachmentFileName,
      attachmentMimeType: row.attachmentMimeType,
      capturedAt: row.capturedAt == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(row.capturedAt!, isUtc: true),
    );

EvidenceType evidenceTypeFromStorage(String value) => switch (value) {
  'TEXT' => EvidenceType.text,
  'CODE' => EvidenceType.code,
  'IMAGE' => EvidenceType.image,
  'FILE' => EvidenceType.file,
  'MANUAL_RECORD' => EvidenceType.manualRecord,
  _ => throw FormatException('未知材料类型：$value'),
};

EvidenceSource evidenceSourceFromStorage(String value) => switch (value) {
  'USER' => EvidenceSource.user,
  'FILE_SYSTEM' => EvidenceSource.fileSystem,
  'CAMERA' => EvidenceSource.camera,
  _ => throw FormatException('未知材料来源：$value'),
};

EvidenceRecordsCompanion evidenceToCompanion(Evidence item) =>
    EvidenceRecordsCompanion.insert(
      id: item.id,
      missionId: item.missionId,
      submissionId: item.submissionId,
      type: switch (item.type) {
        EvidenceType.text => 'TEXT',
        EvidenceType.code => 'CODE',
        EvidenceType.image => 'IMAGE',
        EvidenceType.file => 'FILE',
        EvidenceType.manualRecord => 'MANUAL_RECORD',
      },
      source: switch (item.source) {
        EvidenceSource.user => 'USER',
        EvidenceSource.fileSystem => 'FILE_SYSTEM',
        EvidenceSource.camera => 'CAMERA',
      },
      content: Value(item.content),
      attachmentStorageKey: Value(item.attachmentStorageKey),
      attachmentFileName: Value(item.attachmentFileName),
      attachmentMimeType: Value(item.attachmentMimeType),
      capturedAt: Value(item.capturedAt?.millisecondsSinceEpoch),
      submittedAt: item.submittedAt.millisecondsSinceEpoch,
      supersedesEvidenceId: Value(item.supersedesEvidenceId),
    );

/// 同批次重试逐项比较业务输入，不重新捕获提交时间，也不接受换内容复用身份。
bool sameEvidenceInput(EvidenceDraft a, EvidenceDraft b) =>
    a.id == b.id &&
    a.type == b.type &&
    a.source == b.source &&
    a.content == b.content &&
    a.attachmentStorageKey == b.attachmentStorageKey &&
    a.attachmentFileName == b.attachmentFileName &&
    a.attachmentMimeType == b.attachmentMimeType &&
    a.capturedAt?.millisecondsSinceEpoch ==
        b.capturedAt?.millisecondsSinceEpoch &&
    a.supersedesEvidenceId == b.supersedesEvidenceId;

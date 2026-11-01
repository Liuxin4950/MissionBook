import 'content_mapping.dart';
import '../../domain/entities/record_draft.dart';
import 'package:drift/drift.dart';
import '../../domain/entities/evidence.dart';
import '../local/app_database.dart';

/// 新材料创建记录；关联记录保留来源身份，两条入口均保存提交时的内容快照。
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
      .insert(payload.copyWith(recordId: Value(existingRecordId ?? item.id)));
}

/// 存储层把稳定文本/UTC 毫秒转换成业务类型，未知值立即报错。
Evidence evidenceFromRow(EvidenceRow row) => Evidence(
  id: row.id,
  missionId: row.missionId,
  submissionId: row.submissionId,
  sourceRecordId: row.recordId,
  type: contentTypeFromStorage(row.type),
  source: contentSourceFromStorage(row.source),
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
    EvidenceDraft.fromContent(recordDraftFromRow(row, id: id));

/// 数据行转换成独立记录草稿，不经过任务材料对象。
RecordDraft recordDraftFromRow(RecordRow row, {required String id}) =>
    RecordDraft(
      id: id,
      type: contentTypeFromStorage(row.type),
      source: contentSourceFromStorage(row.source),
      content: row.content,
      attachmentStorageKey: row.attachmentStorageKey,
      attachmentFileName: row.attachmentFileName,
      attachmentMimeType: row.attachmentMimeType,
      capturedAt: row.capturedAt == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(row.capturedAt!, isUtc: true),
    );

EvidenceRecordsCompanion evidenceToCompanion(Evidence item) =>
    EvidenceRecordsCompanion.insert(
      id: item.id,
      missionId: item.missionId,
      submissionId: item.submissionId,
      type: switch (item.type) {
        ContentType.text => 'TEXT',
        ContentType.code => 'CODE',
        ContentType.image => 'IMAGE',
        ContentType.file => 'FILE',
        ContentType.manualRecord => 'MANUAL_RECORD',
      },
      source: switch (item.source) {
        ContentSource.user => 'USER',
        ContentSource.fileSystem => 'FILE_SYSTEM',
        ContentSource.camera => 'CAMERA',
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

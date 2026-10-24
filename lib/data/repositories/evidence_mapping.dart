import 'package:drift/drift.dart';
import '../../domain/entities/evidence.dart';
import '../local/app_database.dart';

/// 存储层把稳定文本/UTC 毫秒转换成业务类型，未知值立即报错。
Evidence evidenceFromRow(EvidenceRow row) => Evidence(
  id: row.id,
  missionId: row.missionId,
  submissionId: row.submissionId,
  type: switch (row.type) {
    'TEXT' => EvidenceType.text,
    'IMAGE' => EvidenceType.image,
    _ => throw FormatException('未知材料类型：${row.type}'),
  },
  source: switch (row.source) {
    'USER' => EvidenceSource.user,
    'FILE_SYSTEM' => EvidenceSource.fileSystem,
    _ => throw FormatException('未知材料来源：${row.source}'),
  },
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
);

EvidenceRecordsCompanion evidenceToCompanion(Evidence item) =>
    EvidenceRecordsCompanion.insert(
      id: item.id,
      missionId: item.missionId,
      submissionId: item.submissionId,
      type: item.type == EvidenceType.text ? 'TEXT' : 'IMAGE',
      source: item.source == EvidenceSource.user ? 'USER' : 'FILE_SYSTEM',
      content: Value(item.content),
      attachmentStorageKey: Value(item.attachmentStorageKey),
      attachmentFileName: Value(item.attachmentFileName),
      attachmentMimeType: Value(item.attachmentMimeType),
      capturedAt: Value(item.capturedAt?.millisecondsSinceEpoch),
      submittedAt: item.submittedAt.millisecondsSinceEpoch,
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
        b.capturedAt?.millisecondsSinceEpoch;

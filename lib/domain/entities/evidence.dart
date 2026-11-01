import 'content_draft.dart';

/// 任务材料草稿；修正目标仅属于材料，不进入记录模型。
class EvidenceDraft extends ContentDraft {
  const EvidenceDraft({
    required super.id,
    required super.type,
    required super.source,
    super.content,
    super.attachmentStorageKey,
    super.attachmentFileName,
    super.attachmentMimeType,
    super.capturedAt,
    this.supersedesEvidenceId,
  });

  EvidenceDraft.fromContent(ContentDraft value, {String? supersedesEvidenceId})
    : this(
        id: value.id,
        type: value.type,
        source: value.source,
        content: value.content,
        attachmentStorageKey: value.attachmentStorageKey,
        attachmentFileName: value.attachmentFileName,
        attachmentMimeType: value.attachmentMimeType,
        capturedAt: value.capturedAt,
        supersedesEvidenceId: supersedesEvidenceId,
      );
  final String? supersedesEvidenceId; // 修正指向旧正式材料；首次提交为空。

  /// 文本框提供新的内容，其他身份及附件引用保持不变。
  EvidenceDraft copyWithContent(String? content) => EvidenceDraft(
    id: id,
    type: type,
    source: source,
    content: content,
    attachmentStorageKey: attachmentStorageKey,
    attachmentFileName: attachmentFileName,
    attachmentMimeType: attachmentMimeType,
    capturedAt: capturedAt,
    supersedesEvidenceId: supersedesEvidenceId,
  );
}

/// 不可变的正式材料。extends 复用草稿的内容字段，super 参数传给父类构造。
/// 新增的提交批次和时刻由写入事务提供，不采用页面时间。
class Evidence extends EvidenceDraft {
  const Evidence({
    required super.id,
    required this.missionId,
    required this.submissionId,
    required this.submittedAt,
    this.sourceRecordId,
    required super.type,
    required super.source,
    super.content,
    super.attachmentStorageKey,
    super.attachmentFileName,
    super.attachmentMimeType,
    super.capturedAt,
    super.supersedesEvidenceId,
  });

  final String missionId;
  final String submissionId; // 一批材料共用的稳定身份，用于识别响应丢失后的重试。
  final DateTime submittedAt;
  final String? sourceRecordId; // 原记录可删除，材料内容仍由本对象自持。
}

/// 固定一次提交的完整输入。复制为不可修改列表，避免点击保存后草稿变化。
class EvidenceSubmission {
  EvidenceSubmission({
    required this.id,
    required this.missionId,
    required List<EvidenceDraft> items,
  }) : items = List.unmodifiable(items);
  final String id;
  final String missionId;
  final List<EvidenceDraft> items;
}

/// 一条修正的固定输入；重试沿用同一草稿 id，不覆盖原记录。
class EvidenceCorrection {
  const EvidenceCorrection({required this.missionId, required this.item});
  final String missionId;
  final EvidenceDraft item;
}

/// 材料均已保存；deadlineMissed 表示任务已有材料超时事实，重试返回相同结果。
enum EvidenceSubmissionResult { submitted, deadlineMissed }

class EvidenceConflict implements Exception {
  const EvidenceConflict(this.message);
  final String message;
  @override
  String toString() => message;
}

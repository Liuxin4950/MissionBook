/// 类型说明如何读取原始材料，不表示验证通过。
enum EvidenceType { text, code, image, file, manualRecord }

/// 输入渠道，不代表作者身份：粘贴 AI 文本仍属于用户提交。
enum EvidenceSource { user, fileSystem, camera }

/// 页面持有的一份草稿。id 在添加时固定，失败重试沿用；构造不等于入库。
class EvidenceDraft {
  const EvidenceDraft({
    required this.id,
    required this.type,
    required this.source,
    this.content,
    this.attachmentStorageKey,
    this.attachmentFileName,
    this.attachmentMimeType,
    this.capturedAt,
    this.supersedesEvidenceId,
  });

  final String id;
  final EvidenceType type;
  final EvidenceSource source;
  final String? content; // 文本正文；图片为可空说明。
  final String? attachmentStorageKey; // 应用私有附件目录内的相对键。
  final String? attachmentFileName; // 原名仅用于展示，不作为文件路径。
  final String? attachmentMimeType;
  final DateTime? capturedAt; // 来源可确认的产生时刻；未知留空。
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

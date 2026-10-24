/// 本轮开放文本、图片；类型说明如何读取原始材料，不表示验证通过。
enum EvidenceType { text, image }

/// 输入渠道，不代表作者身份：粘贴 AI 文本仍属于用户提交。
enum EvidenceSource { user, fileSystem }

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
  });

  final String id;
  final EvidenceType type;
  final EvidenceSource source;
  final String? content; // 文本正文；图片为可空说明。
  final String? attachmentStorageKey; // 应用私有附件目录内的相对键。
  final String? attachmentFileName; // 原名仅用于展示，不作为文件路径。
  final String? attachmentMimeType;
  final DateTime? capturedAt; // 来源可确认的产生时刻；未知留空。

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

/// 超时也有已提交的事实，因此返回业务结果，不抛异常回滚超时记录。
enum EvidenceSubmissionResult { submitted, deadlineMissed }

class EvidenceConflict implements Exception {
  const EvidenceConflict(this.message);
  final String message;
  @override
  String toString() => message;
}

/// 原始内容的读取形式；不代表完成或验证结论。
enum ContentType { text, code, image, file, manualRecord }

/// 内容输入渠道，不代表作者身份。
enum ContentSource { user, fileSystem, camera }

/// 记录与材料草稿共用的内容字段，不包含归属、提交、修正或任务事实。
class ContentDraft {
  const ContentDraft({
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
  final ContentType type;
  final ContentSource source;
  final String? content;
  final String? attachmentStorageKey;
  final String? attachmentFileName;
  final String? attachmentMimeType;
  final DateTime? capturedAt;
}

import 'content_draft.dart';
export 'content_draft.dart' show ContentType, ContentSource;

/// 独立记录的保存意图；没有任务提交、修正或执行语义。
class RecordDraft extends ContentDraft {
  const RecordDraft({
    required super.id,
    required super.type,
    required super.source,
    super.content,
    super.attachmentStorageKey,
    super.attachmentFileName,
    super.attachmentMimeType,
    super.capturedAt,
  });

  /// 附件选择器只提供内容；记录保存时不继承材料修正身份。
  RecordDraft.fromContent(ContentDraft value)
    : super(
        id: value.id,
        type: value.type,
        source: value.source,
        content: value.content,
        attachmentStorageKey: value.attachmentStorageKey,
        attachmentFileName: value.attachmentFileName,
        attachmentMimeType: value.attachmentMimeType,
        capturedAt: value.capturedAt,
      );

  /// 更新正文或附件说明，保留草稿身份和附件。
  RecordDraft copyWithContent(String? content) => RecordDraft(
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

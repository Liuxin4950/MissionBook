import '../entities/content_draft.dart';

/// 记录和材料共用的内容完整性、来源与附件路径校验。
void validateContentDraft(ContentDraft item) {
  if (item.id.trim().isEmpty) throw ArgumentError('内容编号不能为空');
  if (item.capturedAt != null && !item.capturedAt!.isUtc) {
    throw ArgumentError('内容产生时刻必须使用 UTC');
  }
  switch (item.type) {
    case ContentType.text:
    case ContentType.code:
    case ContentType.manualRecord:
      if (item.source != ContentSource.user ||
          (item.content?.trim().isEmpty ?? true)) {
        throw ArgumentError('请填写正文内容');
      }
      if (item.attachmentStorageKey != null ||
          item.attachmentFileName != null ||
          item.attachmentMimeType != null) {
        throw ArgumentError('文字、代码和手动记录不能包含附件引用');
      }
    case ContentType.image:
    case ContentType.file:
      final key = item.attachmentStorageKey;
      // 只允许应用私有的平铺附件键。UUID 由准备入口提供，不允许盘符或 ../。
      if ((item.source != ContentSource.fileSystem &&
              !(item.type == ContentType.image &&
                  item.source == ContentSource.camera)) ||
          key == null ||
          !key.startsWith('attachments/') ||
          key.split('/').length != 3 ||
          key.contains('..') ||
          key.contains('\\') ||
          key.contains(':') ||
          key.endsWith('/') ||
          (item.attachmentFileName?.trim().isEmpty ?? true)) {
        throw ArgumentError('附件引用无效，请重新选择文件');
      }
  }
}

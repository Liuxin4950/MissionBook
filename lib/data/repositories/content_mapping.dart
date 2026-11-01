import '../../domain/entities/content_draft.dart';

/// 存储协议转换集中在边界，枚举重命名不会改变 SQL 中的既有字符串。
ContentType contentTypeFromStorage(String value) => switch (value) {
  'TEXT' => ContentType.text,
  'CODE' => ContentType.code,
  'IMAGE' => ContentType.image,
  'FILE' => ContentType.file,
  'MANUAL_RECORD' => ContentType.manualRecord,
  _ => throw FormatException('未知内容类型：$value'),
};

ContentSource contentSourceFromStorage(String value) => switch (value) {
  'USER' => ContentSource.user,
  'FILE_SYSTEM' => ContentSource.fileSystem,
  'CAMERA' => ContentSource.camera,
  _ => throw FormatException('未知内容来源：$value'),
};

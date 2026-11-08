import 'dart:typed_data';
import 'package:file_selector_platform_interface/file_selector_platform_interface.dart';
import '../../application/assistant/assistant_attachment.dart';

Future<AssistantAttachment?> pickAssistantAttachment({
  required bool image,
  String confirmButtonText = '添加到对话',
  Future<AssistantAttachment?> Function(String name, Uint8List bytes)?
  onOversizedImage,
}) async {
  final files = await pickAssistantAttachments(
    image: image,
    maxCount: 1,
    confirmButtonText: confirmButtonText,
    onOversizedImage: onOversizedImage,
  );
  return files.firstOrNull;
}

Future<List<AssistantAttachment>> pickAssistantAttachments({
  required bool image,
  int maxCount = AssistantAttachment.maxCount,
  String confirmButtonText = '添加到对话',
  Future<AssistantAttachment?> Function(String name, Uint8List bytes)?
  onOversizedImage,
}) async {
  final groups = [
    XTypeGroup(
      label: image ? '图片' : '文本文件',
      extensions: image
          ? AssistantAttachment.imageExtensions
          : AssistantAttachment.textExtensions,
      mimeTypes: image
          ? ['image/*']
          : [
              'text/*',
              'application/json',
              'application/xml',
              'application/x-yaml',
            ],
    ),
  ];
  final List<XFile> files;
  if (maxCount == 1) {
    final file = await FileSelectorPlatform.instance.openFile(
      acceptedTypeGroups: groups,
      confirmButtonText: confirmButtonText,
    );
    files = [?file];
  } else {
    files = await FileSelectorPlatform.instance.openFiles(
      acceptedTypeGroups: groups,
      confirmButtonText: confirmButtonText,
    );
  }
  if (files.length > maxCount) throw FormatException('本次最多还能添加 $maxCount 个附件');
  final result = <AssistantAttachment>[];
  var total = 0;
  for (final file in files) {
    final attachment = await _readAttachment(
      file,
      image: image,
      onOversizedImage: onOversizedImage,
    );
    if (attachment == null) return [];
    total += attachment.bytes.length;
    if (total > AssistantAttachment.maxTotalBytes) {
      throw const FormatException('本条消息附件合计不能超过 24 MiB');
    }
    result.add(attachment);
  }
  return result;
}

Future<AssistantAttachment?> _readAttachment(
  XFile file, {
  required bool image,
  Future<AssistantAttachment?> Function(String name, Uint8List bytes)?
  onOversizedImage,
}) async {
  final limit = image ? 20 * 1024 * 1024 : AssistantAttachment.maxTextBytes;
  if (await file.length() > limit) {
    throw FormatException(image ? '原图不能超过 20 MiB，请先裁剪' : '文本文件不能超过 256 KiB');
  }
  final data = BytesBuilder(copy: false);
  await for (final chunk in file.openRead()) {
    if (data.length + chunk.length > limit) {
      throw const FormatException('文件读取时超出大小限制');
    }
    data.add(chunk);
  }
  final bytes = data.takeBytes();
  if (image &&
      bytes.length > AssistantAttachment.maxImageBytes &&
      onOversizedImage != null) {
    return onOversizedImage(file.name, bytes);
  }
  return AssistantAttachment.fromBytes(file.name, bytes);
}

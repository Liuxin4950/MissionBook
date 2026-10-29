import 'dart:typed_data';
import 'package:file_selector_platform_interface/file_selector_platform_interface.dart';
import '../../application/assistant/assistant_attachment.dart';

Future<AssistantAttachment?> pickAssistantAttachment({
  required bool image,
}) async {
  final file = await FileSelectorPlatform.instance.openFile(
    acceptedTypeGroups: [
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
    ],
    confirmButtonText: '添加到对话',
  );
  if (file == null) return null;
  final limit = image
      ? AssistantAttachment.maxImageBytes
      : AssistantAttachment.maxTextBytes;
  if (await file.length() > limit) {
    throw FormatException(image ? '单张图片不能超过 4 MiB' : '文本文件不能超过 256 KiB');
  }
  final data = BytesBuilder(copy: false);
  await for (final chunk in file.openRead()) {
    if (data.length + chunk.length > limit) {
      throw const FormatException('文件读取时超出大小限制');
    }
    data.add(chunk);
  }
  return AssistantAttachment.fromBytes(file.name, data.takeBytes());
}

import 'dart:typed_data';
import 'package:file_selector_platform_interface/file_selector_platform_interface.dart';
import '../../application/assistant/assistant_attachment.dart';

Future<AssistantAttachment?> pickAssistantAttachment({
  required bool image,
  Future<AssistantAttachment?> Function(String name, Uint8List bytes)?
  onOversizedImage,
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

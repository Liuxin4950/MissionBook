import 'dart:convert';
import 'dart:typed_data';

import 'package:agent_core/agent_core.dart';

/// 用户主动选择的会话附件；内容随消息持久化，不依赖临时文件路径。
class AssistantAttachment {
  AssistantAttachment._(this.name, this.bytes, this.block);

  static const maxCount = 4;
  static const maxImageBytes = 4 * 1024 * 1024;
  static const maxTextBytes = 256 * 1024;
  static const maxTotalBytes = 8 * 1024 * 1024;
  static const maxTextCharacters = 32000;
  static const imageExtensions = ['png', 'jpg', 'jpeg', 'webp', 'gif'];
  static const textExtensions = [
    'txt',
    'md',
    'csv',
    'json',
    'log',
    'yaml',
    'yml',
    'xml',
    'html',
    'dart',
    'py',
    'js',
    'ts',
    'java',
    'kt',
  ];
  static const textPrefix = '[MissionBook 文本附件]\n';

  final String name;
  final Uint8List bytes;
  final ContentBlock block;
  bool get isImage => block is ImageBlock;

  factory AssistantAttachment.fromBytes(String name, Uint8List bytes) {
    final extension = name.split('.').last.toLowerCase();
    if (imageExtensions.contains(extension)) {
      if (bytes.length > maxImageBytes) {
        throw const FormatException('单张图片不能超过 4 MiB');
      }
      return AssistantAttachment._(
        name,
        bytes,
        ImageInput.fromBytes(bytes, name: name).inline(),
      );
    }
    if (!textExtensions.contains(extension)) {
      throw const FormatException(
        '请选择图片或 UTF-8 文本文件（TXT、Markdown、CSV、JSON 等）；PDF 和 Word 请先导出为图片或文本。',
      );
    }
    if (bytes.isEmpty || bytes.length > maxTextBytes) {
      throw const FormatException('文本文件需大于 0 且不超过 256 KiB');
    }
    final text = utf8.decode(bytes); // 严格校验编码，不能把二进制文件当文字发送。
    if (text.contains('\u0000') || text.length > maxTextCharacters) {
      throw const FormatException('文本文件应使用 UTF-8 编码，正文不超过 32000 字符');
    }
    return AssistantAttachment._(
      name,
      bytes,
      TextBlock(text: '$textPrefix${jsonEncode({'name': name, 'text': text})}'),
    );
  }

  static ({String name, String text})? textFile(ContentBlock block) {
    if (block is! TextBlock || !block.text.startsWith(textPrefix)) return null;
    try {
      final data = jsonDecode(block.text.substring(textPrefix.length)) as Map;
      if (data['name'] is String && data['text'] is String) {
        return (name: data['name'] as String, text: data['text'] as String);
      }
    } catch (_) {
      // 不是本应用生成的附件块时，按原始消息显示。
    }
    return null;
  }
}

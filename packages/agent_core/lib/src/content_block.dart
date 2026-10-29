import 'json_value.dart';

enum ImageDetail { auto, low, high, original }

/// 模型消息中的一个内容块。
sealed class ContentBlock {
  const ContentBlock();
}

/// 模型消息中的纯文字内容。
final class TextBlock extends ContentBlock {
  const TextBlock({required this.text});

  final String text; // 由创建者传入的原始文字。
}

/// 用户提供的图片地址或 base64 data URL；实际能否理解图片由模型决定。
final class ImageBlock extends ContentBlock {
  ImageBlock({
    required this.url,
    this.detail = ImageDetail.auto,
    this.label,
    this.width,
    this.height,
    this.byteLength,
  }) : fileId = null,
       provider = null {
    final parsed = Uri.tryParse(url);
    final remote =
        parsed != null &&
        ['http', 'https'].contains(parsed.scheme) &&
        parsed.host.isNotEmpty;
    final inline = RegExp(
      r'^data:image/(png|jpeg|gif|webp);base64,[A-Za-z0-9+/=\r\n]+$',
    ).hasMatch(url);
    if (!remote && !inline) {
      throw ArgumentError('图片需要 HTTP 地址或支持的 base64 data URL');
    }
  }

  final String url;
  final String? fileId; // 云端图片引用；正文不需要反复携带 base64。
  final String? provider; // 文件引用只能交回上传它的供应商。
  final ImageDetail detail;
  final String? label; // 文件名或来源，供界面和不支持视觉的摘要模型说明来源。
  final int? width; // 本地解析的像素宽高；远程链接可未知，交给供应商核对。
  final int? height;
  final int? byteLength;

  ImageBlock.file({
    required String id,
    this.provider = 'deepseek',
    this.label,
    this.width,
    this.height,
    this.byteLength,
  }) : fileId = id,
       url = '',
       detail = ImageDetail.auto {
    if (!RegExp(r'^[A-Za-z0-9_-]{1,200}$').hasMatch(id)) {
      throw ArgumentError('图片文件编号无效');
    }
  }
}

/// 保留供应商返回的思考块，使后续请求可以原样回传。
final class ThinkingBlock extends ContentBlock {
  const ThinkingBlock({required this.text, this.signature});

  final String text; // 与面向用户的回答分开保存。
  final String? signature; // 供应商返回时保留，不自行生成。
}

/// 模型提出的一次工具调用；创建这个对象本身不会执行工具。
final class ToolCallBlock extends ContentBlock {
  ToolCallBlock({
    required this.id,
    required this.name,
    required Map<String, Object?> input,
  }) : input = freezeJsonObject(input) {
    if (id.trim().isEmpty || name.trim().isEmpty) {
      throw ArgumentError('工具调用必须包含非空 id 和 name');
    }
  }

  final String id; // 模型给出的编号，工具结果必须回答这个编号。
  final String name; // 用来查找应用实际注册的工具。
  final Map<String, Object?> input; // 模型提供的参数，执行前还要验证。
}

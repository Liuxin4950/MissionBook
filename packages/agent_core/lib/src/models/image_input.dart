import 'dart:convert';
import 'dart:typed_data';

import 'package:image/image.dart' as images;

import '../content_block.dart';
import 'configuration.dart';

/// 已核对实际格式、尺寸和大小的图片；只解析文件头，不展开整张像素图。
final class ImageInput {
  ImageInput._(this.bytes, this.name, this.mediaType, this.width, this.height);
  final Uint8List bytes;
  final String name;
  final String mediaType;
  final int width;
  final int height;

  factory ImageInput.fromBytes(Uint8List bytes, {String name = 'image'}) {
    if (bytes.isEmpty || bytes.length > 64 * 1024 * 1024) {
      throw ArgumentError('图片需要大于 0 且不超过 64 MiB');
    }
    final decoder = images.findDecoderForData(bytes);
    final mediaType = switch (decoder) {
      images.PngDecoder() => 'image/png',
      images.JpegDecoder() => 'image/jpeg',
      images.GifDecoder() => 'image/gif',
      images.WebPDecoder() => 'image/webp',
      _ => throw ArgumentError('图片内容需要为 JPEG、PNG、GIF 或 WebP'),
    };
    final info = decoder!.startDecode(bytes);
    if (info == null || info.width <= 0 || info.height <= 0) {
      throw ArgumentError('图片文件头损坏');
    }
    if (info.width > 8192 || info.height > 8192) {
      throw ArgumentError('图片任一边不能超过 8192 像素');
    }
    return ImageInput._(
      Uint8List.fromList(bytes),
      name,
      mediaType,
      info.width,
      info.height,
    );
  }

  ImageBlock inline({ImageDetail detail = ImageDetail.auto}) {
    if (bytes.length > DeepSeekFlash.maxImageBytes) {
      throw ArgumentError('内联图片不能超过 32 MiB，请先上传并使用 file_id');
    }
    return ImageBlock(
      url: 'data:$mediaType;base64,${base64Encode(bytes)}',
      detail: detail,
      label: name,
      width: width,
      height: height,
      byteLength: bytes.length,
    );
  }
}

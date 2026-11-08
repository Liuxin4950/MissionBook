import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:mission_book/application/assistant/assistant_attachment.dart';
import 'package:mission_book/application/assistant/assistant_image.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('头像裁成小尺寸透明 PNG，源图片保持不变', () async {
    final source = img.encodePng(
      img.Image(width: 400, height: 200, numChannels: 4),
    );
    final original = Uint8List.fromList(source);
    final encoded = await prepareAssistantAvatar(source);
    final decoded = img.decodePng(base64Decode(encoded))!;
    expect(decoded.width, 192);
    expect(decoded.height, 192);
    expect(decoded.getPixel(96, 96).a, 0);
    expect(source, original);
    await expectLater(
      prepareAssistantAvatar(Uint8List.fromList([1, 2, 3])),
      throwsFormatException,
    );
  });
  test('大于4MiB的真实图片压缩为可解码JPEG，源数据不变', () async {
    final random = Random(17);
    final pixels = Uint8List.fromList(
      List.generate(1400 * 1400 * 3, (_) => random.nextInt(256)),
    );
    final source = img.Image.fromBytes(
      width: 1400,
      height: 1400,
      bytes: pixels.buffer,
      numChannels: 3,
    );
    final bytes = img.encodePng(source, level: 0);
    final original = Uint8List.fromList(bytes);
    expect(bytes.length, greaterThan(AssistantAttachment.maxImageBytes));
    final file = await compressAssistantImage('拍照.png', bytes);
    expect(
      file.bytes.length,
      lessThanOrEqualTo(AssistantAttachment.maxImageBytes),
    );
    expect(file.name, '拍照-compressed.jpg');
    expect(file.isImage, isTrue);
    final decoded = img.decodeJpg(file.bytes)!;
    expect(decoded.width, 1400);
    expect(decoded.height, 1400);
    expect(bytes, original);
  });
  test('无法解码的图片明确失败，不加入伪造附件', () async {
    await expectLater(
      compressAssistantImage('bad.jpg', Uint8List.fromList([1, 2, 3])),
      throwsFormatException,
    );
  });
}

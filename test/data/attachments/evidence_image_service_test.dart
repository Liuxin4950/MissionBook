import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:mission_book/application/evidence/evidence_image_service.dart';
import 'package:mission_book/data/attachments/evidence_image_native.dart';

class _Picker implements EvidenceImagePicker {
  _Picker(this.selection);
  final SelectedEvidenceImage? selection;
  @override
  Future<SelectedEvidenceImage?> pick() async => selection;
}

// 用真实图片编码和独立磁盘目录验证；不访问设备上正在使用的应用数据。
Future<Uint8List> _pngBytes() async {
  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder);
  canvas.drawColor(const ui.Color(0xff244d3d), ui.BlendMode.src);
  final picture = recorder.endRecording();
  final image = await picture.toImage(2, 2);
  try {
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    return data!.buffer.asUint8List();
  } finally {
    image.dispose();
    picture.dispose();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory directory;
  late NativeEvidenceImageStore store;
  late Uint8List png;
  setUpAll(() async => png = await _pngBytes());
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('mission_book_images_');
    store = NativeEvidenceImageStore(
      applicationDirectory: () async => directory,
    );
  });
  tearDown(() async => directory.delete(recursive: true));

  EvidenceImageService service(
    SelectedEvidenceImage? selection, {
    String id = 'image-a',
  }) {
    return EvidenceImageService(
      store: store,
      picker: _Picker(selection),
      nextId: () => id,
    );
  }

  SelectedEvidenceImage selection(Uint8List bytes, {int? declaredSize}) {
    return SelectedEvidenceImage(
      fileName: '事务结果.png',
      byteLength: declaredSize ?? bytes.length,
      readBytes: () async => bytes,
    );
  }

  test('取消选择不产生附件或正式引用', () async {
    expect(await service(null).pickAndPrepare('mission-a'), isNull);
    expect(await store.listKeys(), isEmpty);
  });

  test('声明超限时不读取内容，不创建副本', () async {
    var read = false;
    final pickerResult = SelectedEvidenceImage(
      fileName: 'large.png',
      byteLength: EvidenceImageService.maxBytes + 1,
      readBytes: () async {
        read = true;
        return png;
      },
    );
    await expectLater(
      service(pickerResult).pickAndPrepare('mission-a'),
      throwsArgumentError,
    );
    expect(read, isFalse);
    expect(await store.listKeys(), isEmpty);
  });

  test('实际读取超过限制也拒绝，不相信选择器的声明长度', () async {
    final oversized = Uint8List(EvidenceImageService.maxBytes + 1);
    await expectLater(
      service(
        selection(oversized, declaredSize: 20),
      ).pickAndPrepare('mission-a'),
      throwsArgumentError,
    );
    expect(await store.listKeys(), isEmpty);
  });

  test('扩展名是图片但真实内容无法解码时不保存', () async {
    await expectLater(
      service(
        selection(Uint8List.fromList([1, 2, 3])),
      ).pickAndPrepare('mission-a'),
      throwsArgumentError,
    );
    expect(await store.listKeys(), isEmpty);
  });

  test('来源文件删除后，重建存储对象仍可读取完整私有副本', () async {
    final source = File('${directory.path}/original.png');
    await source.writeAsBytes(png);
    final images = service(
      SelectedEvidenceImage(
        fileName: '事务结果.png',
        byteLength: await source.length(),
        readBytes: source.readAsBytes,
      ),
    );
    final image = (await images.pickAndPrepare('mission-a'))!;
    expect(image.storageKey, 'attachments/mission-a/image-a.png');
    expect(image.fileName, '事务结果.png');
    expect(image.mimeType, 'image/png');
    await source.delete();
    final reopened = NativeEvidenceImageStore(
      applicationDirectory: () async => directory,
    );
    expect(await reopened.read(image.storageKey), png);
  });

  test('展示文件名不参与存储路径，去掉来源路径和控制字符', () async {
    final image = (await service(
      SelectedEvidenceImage(
        fileName: '../other\\结果\u0000.png',
        byteLength: png.length,
        readBytes: () async => png,
      ),
    ).pickAndPrepare('mission-a'))!;
    expect(image.fileName, '结果_.png');
    expect(image.storageKey, 'attachments/mission-a/image-a.png');
  });

  test('同键重复准备拒绝覆盖，已保存的字节保持', () async {
    final images = service(selection(png));
    final image = (await images.pickAndPrepare('mission-a'))!;
    await expectLater(
      images.pickAndPrepare('mission-a'),
      throwsA(isA<FileSystemException>()),
    );
    expect(await store.read(image.storageKey), png);
  });

  test('路径穿越、盘符、URI及任务编号越界均被拒绝', () async {
    for (final key in [
      '../outside.png',
      'attachments/../outside.png',
      'C:/private/x.png',
      'content://images/1',
      'attachments/mission-a/../outside.png',
    ]) {
      await expectLater(store.read(key), throwsArgumentError);
      await expectLater(store.delete(key), throwsArgumentError);
    }
    await expectLater(
      service(selection(png)).pickAndPrepare('../outside'),
      throwsArgumentError,
    );
  });

  test('清理只删除无引用的合法附件，正式引用及目录外文件保留', () async {
    const formal = 'attachments/mission-a/formal.png';
    const orphan = 'attachments/mission-a/orphan.png';
    await store.writeNew(formal, png);
    await store.writeNew(orphan, png);
    final outside = File('${directory.path}/do-not-delete.txt');
    final unknown = File('${directory.path}/attachments/keep.txt');
    await outside.writeAsString('keep');
    await unknown.writeAsString('keep');
    await service(null).removeUnreferenced({formal});
    expect(await store.listKeys(), {formal});
    expect(await store.read(formal), png);
    expect(await outside.exists(), isTrue);
    expect(await unknown.exists(), isTrue);
  });

  test('损坏的正式引用使清理停止，不把未知引用当成无引用', () async {
    const key = 'attachments/mission-a/formal.png';
    await store.writeNew(key, png);
    await expectLater(
      service(null).removeUnreferenced({'../damaged'}),
      throwsArgumentError,
    );
    expect(await store.listKeys(), {key});
  });

  test('正式附件缺失返回明确错误，删除已不存在的草稿可安全重试', () async {
    const missing = 'attachments/mission-a/missing.png';
    await expectLater(service(null).read(missing), throwsStateError);
    await service(null).delete(missing);
    expect(await store.listKeys(), isEmpty);
  });
}

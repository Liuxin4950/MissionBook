import 'dart:typed_data';

import 'package:file_selector_platform_interface/file_selector_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mission_book/data/assistant/assistant_attachment_picker_native.dart';

class BatchSelector extends FileSelectorPlatform {
  List<XFile> files = [];
  @override
  Future<List<XFile>> openFiles({
    List<XTypeGroup>? acceptedTypeGroups,
    String? initialDirectory,
    String? confirmButtonText,
  }) async => files;
}

void main() {
  final selector = BatchSelector();
  late FileSelectorPlatform original;
  setUp(() {
    original = FileSelectorPlatform.instance;
    FileSelectorPlatform.instance = selector;
  });
  tearDown(() => FileSelectorPlatform.instance = original);

  test('批量选择保持次序和名称，取消返回空列表', () async {
    selector.files = List.generate(
      6,
      (i) => XFile.fromData(
        Uint8List.fromList('内容$i'.codeUnits.map((v) => v % 128).toList()),
        path: '$i.txt',
      ),
    );
    final files = await pickAssistantAttachments(image: false);
    expect(files.map((file) => file.name), List.generate(6, (i) => '$i.txt'));
    selector.files = [];
    expect(await pickAssistantAttachments(image: true), isEmpty);
  });

  test('批量超过剩余名额时拒绝整批', () async {
    selector.files = List.generate(
      4,
      (i) => XFile.fromData(Uint8List.fromList([65]), path: '$i.txt'),
    );
    await expectLater(
      pickAssistantAttachments(image: false, maxCount: 3),
      throwsFormatException,
    );
  });
}

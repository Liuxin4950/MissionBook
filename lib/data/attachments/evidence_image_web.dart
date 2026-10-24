import 'dart:async';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

import '../../application/evidence/evidence_image_service.dart';

EvidenceImageStore createImageStore() => WebEvidenceImageStore();
EvidenceImagePicker createImagePicker() => WebEvidenceImagePicker();

/// 系统选择仍由浏览器发起，取消回到同一草稿，不创建额外页面。
class WebEvidenceImagePicker implements EvidenceImagePicker {
  @override
  Future<SelectedEvidenceImage?> pick() async {
    final result = Completer<SelectedEvidenceImage?>();
    final input = web.HTMLInputElement()
      ..type = 'file'
      ..accept = 'image/*';
    input.style.display = 'none';
    input.onchange = ((web.Event event) {
      final file = input.files?.item(0);
      if (file == null) {
        result.complete(null);
      } else {
        result.complete(
          SelectedEvidenceImage(
            fileName: file.name,
            byteLength: file.size,
            readBytes: () async =>
                (await file.arrayBuffer().toDart).toDart.asUint8List(),
          ),
        );
      }
    }).toJS;
    input.oncancel = ((web.Event event) {
      if (!result.isCompleted) result.complete(null);
    }).toJS;
    web.document.body!.append(input);
    try {
      input.click();
      return await result.future;
    } finally {
      input.remove();
    }
  }
}

/// 浏览器附件存入同源 OPFS，刷新后仍读取实际文件；不可用时明确失败。
class WebEvidenceImageStore implements EvidenceImageStore {
  Future<web.FileSystemDirectoryHandle> _root() async {
    try {
      final origin = await web.window.navigator.storage.getDirectory().toDart;
      return await origin
          .getDirectoryHandle(
            'attachments',
            web.FileSystemGetDirectoryOptions(create: true),
          )
          .toDart;
    } catch (_) {
      throw StateError('当前浏览器无法持久保存图片，请允许网站存储或使用原生应用');
    }
  }

  Future<web.FileSystemDirectoryHandle> _mission(
    String key, {
    bool create = false,
  }) async {
    final parts = validateAttachmentKey(key);
    final root = await _root();
    return root
        .getDirectoryHandle(
          parts[1],
          web.FileSystemGetDirectoryOptions(create: create),
        )
        .toDart;
  }

  @override
  Future<void> writeNew(String storageKey, Uint8List bytes) async {
    validateAttachmentKey(storageKey);
    // 同源的不同标签页也共用此锁：检查存在和创建不能被另一次同键写入穿插。
    final callback = ((web.Lock lock) {
      final persisted = _writeNewLocked(
        storageKey,
        bytes,
      ).then<JSAny?>((_) => null);
      return persisted.toJS;
    }).toJS;
    await web.window.navigator.locks
        .request('mission_book:image:$storageKey', callback)
        .toDart;
  }

  Future<void> _writeNewLocked(String storageKey, Uint8List bytes) async {
    final parts = validateAttachmentKey(storageKey);
    final directory = await _mission(storageKey, create: true);
    try {
      await directory.getFileHandle(parts[2]).toDart;
    } catch (error) {
      if (!_isNotFound(error)) rethrow;
      final handle = await directory
          .getFileHandle(parts[2], web.FileSystemGetFileOptions(create: true))
          .toDart;
      web.FileSystemWritableFileStream? writer;
      try {
        writer = await handle.createWritable().toDart;
        await writer.write(bytes.toJS).toDart;
        await writer.close().toDart; // 关闭成功才代表完整内容已写入 OPFS。
      } catch (_) {
        try {
          await writer?.abort().toDart;
        } catch (_) {
          /* 保留原始写入错误。 */
        }
        try {
          await directory.removeEntry(parts[2]).toDart;
        } catch (_) {
          /* 下次启动清理。 */
        }
        rethrow;
      }
      return;
    }
    throw StateError('图片编号已存在，不能覆盖原始材料');
  }

  @override
  Future<Uint8List> read(String storageKey) async {
    final parts = validateAttachmentKey(storageKey);
    try {
      final directory = await _mission(storageKey);
      final handle = await directory.getFileHandle(parts[2]).toDart;
      final file = await handle.getFile().toDart;
      if (file.size > EvidenceImageService.maxBytes) {
        throw StateError('图片文件大小异常');
      }
      return (await file.arrayBuffer().toDart).toDart.asUint8List();
    } catch (error) {
      if (_isNotFound(error)) throw StateError('图片文件已缺失，请检查备份或原始材料');
      rethrow;
    }
  }

  @override
  Future<void> delete(String storageKey) async {
    final parts = validateAttachmentKey(storageKey);
    try {
      final directory = await _mission(storageKey);
      await directory.removeEntry(parts[2]).toDart;
    } catch (error) {
      if (!_isNotFound(error)) rethrow;
    }
  }

  @override
  Future<Set<String>> listKeys() async {
    final root = await _root();
    final result = <String>{};
    await for (final mission in _entries(root)) {
      if (mission.kind != 'directory') continue;
      try {
        validateAttachmentSegment(mission.name);
      } on ArgumentError {
        continue;
      }
      final directory = await root.getDirectoryHandle(mission.name).toDart;
      await for (final file in _entries(directory)) {
        if (file.kind != 'file') continue;
        final key = 'attachments/${mission.name}/${file.name}';
        try {
          validateAttachmentKey(key);
        } on ArgumentError {
          continue;
        }
        result.add(key);
      }
    }
    return result;
  }
}

bool _isNotFound(Object error) {
  // Promise 的拒绝可能是浏览器 DOMException，也可能是我们自己的 Dart 异常。
  // isA 检查真实 JavaScript 原型，不能用 Dart 的 is 误判互操作类型。
  final jsError = error as JSAny;
  return jsError.isA<web.DOMException>() &&
      (jsError as web.DOMException).name == 'NotFoundError';
}

// package:web 的生成类型尚未暴露异步目录迭代器；仅补齐这一项标准接口。
extension type _IterableDirectory(JSObject _) implements JSObject {
  external _HandleIterator values();
}
extension type _HandleIterator(JSObject _) implements JSObject {
  external JSPromise<_HandleIteration> next();
}
extension type _HandleIteration(JSObject _) implements JSObject {
  external bool get done;
  external web.FileSystemHandle get value;
}

Stream<web.FileSystemHandle> _entries(
  web.FileSystemDirectoryHandle directory,
) async* {
  final iterator = _IterableDirectory(directory).values();
  while (true) {
    final item = await iterator.next().toDart;
    if (item.done) return;
    yield item.value;
  }
}

import 'dart:io';
import 'dart:typed_data';

import 'package:file_selector_platform_interface/file_selector_platform_interface.dart';
import 'package:path_provider/path_provider.dart';

import '../../application/evidence/evidence_image_service.dart';

EvidenceImageStore createImageStore() => NativeEvidenceImageStore(
  applicationDirectory: getApplicationSupportDirectory,
);
EvidenceImagePicker createImagePicker() => NativeEvidenceImagePicker();

/// Windows 使用已注册的官方选择器；Android 复用应用的 ACTION_OPEN_DOCUMENT 通道。
class NativeEvidenceImagePicker implements EvidenceImagePicker {
  @override
  Future<SelectedEvidenceImage?> pick() async {
    final file = await FileSelectorPlatform.instance.openFile(
      acceptedTypeGroups: const [
        XTypeGroup(
          label: '图片',
          extensions: ['png', 'jpg', 'jpeg', 'gif', 'webp', 'bmp'],
          mimeTypes: ['image/*'],
        ),
      ],
      confirmButtonText: '添加图片',
    );
    if (file == null) return null;
    return SelectedEvidenceImage(
      fileName: file.name,
      byteLength: await file.length(),
      readBytes: () async {
        final builder = BytesBuilder(copy: false);
        // 分块读取并累计实际大小，防止选中后文件变大而一次读入过量内容。
        await for (final chunk in file.openRead()) {
          if (builder.length + chunk.length > EvidenceImageService.maxBytes) {
            throw ArgumentError('每张图片不能超过 20 MiB');
          }
          builder.add(chunk);
        }
        return builder.takeBytes();
      },
    );
  }
}

/// 只读写应用支持目录下的 attachments；测试传入独立临时目录。
class NativeEvidenceImageStore implements EvidenceImageStore {
  NativeEvidenceImageStore({required this.applicationDirectory});
  final Future<Directory> Function() applicationDirectory;

  Future<Directory> _root({bool create = false}) async {
    final base = await applicationDirectory();
    final root = Directory('${base.path}${Platform.pathSeparator}attachments');
    await _checkDirectory(root, create: create);
    return root;
  }

  Future<void> _checkDirectory(
    Directory directory, {
    required bool create,
  }) async {
    final type = await FileSystemEntity.type(
      directory.path,
      followLinks: false,
    );
    if (type == FileSystemEntityType.link ||
        (type != FileSystemEntityType.notFound &&
            type != FileSystemEntityType.directory)) {
      throw StateError('图片目录异常，已停止访问');
    }
    if (create && type == FileSystemEntityType.notFound) {
      await directory.create(recursive: true);
    }
  }

  Future<File> _file(String key, {bool createDirectory = false}) async {
    final parts = validateAttachmentKey(key);
    final root = await _root(create: createDirectory);
    final directory = Directory(
      '${root.path}${Platform.pathSeparator}${parts[1]}',
    );
    await _checkDirectory(directory, create: createDirectory);
    final file = File('${directory.path}${Platform.pathSeparator}${parts[2]}');
    final type = await FileSystemEntity.type(file.path, followLinks: false);
    if (type != FileSystemEntityType.notFound &&
        type != FileSystemEntityType.file) {
      throw StateError('图片文件异常，已停止访问');
    }
    return file;
  }

  @override
  Future<void> writeNew(String storageKey, Uint8List bytes) async {
    final file = await _file(storageKey, createDirectory: true);
    // exclusive 拒绝已有同名文件，正式图片不会被后来的一次写入覆盖。
    await file.create(exclusive: true);
    try {
      await file.writeAsBytes(bytes, flush: true);
    } catch (_) {
      // 文件属于本次尚未返回的准备操作，失败只回收自己的不完整副本。
      try {
        await file.delete();
      } catch (_) {
        /* 启动清理可再次回收。 */
      }
      rethrow;
    }
  }

  @override
  Future<Uint8List> read(String storageKey) async {
    final file = await _file(storageKey);
    if (!await file.exists()) throw StateError('图片文件已缺失，请检查备份或原始材料');
    if (await file.length() > EvidenceImageService.maxBytes) {
      throw StateError('图片文件大小异常');
    }
    return file.readAsBytes();
  }

  @override
  Future<void> delete(String storageKey) async {
    final file = await _file(storageKey);
    if (await file.exists()) await file.delete();
  }

  @override
  Future<Set<String>> listKeys() async {
    final root = await _root();
    if (!await root.exists()) return {};
    final keys = <String>{};
    // 不跟随符号链接，也不递归删除目录；仅返回本应用生成的合法文件键。
    await for (final entry in root.list(recursive: true, followLinks: false)) {
      if (entry is! File) continue;
      final relative = entry.path
          .substring(root.path.length + 1)
          .replaceAll('\\', '/');
      final key = 'attachments/$relative';
      try {
        validateAttachmentKey(key);
        keys.add(key);
      } on ArgumentError {
        // 不认识的文件保留，避免清理意外扩展到其他内容。
      }
    }
    return keys;
  }
}

import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart'
    show debugPrint, debugPrintStack, kDebugMode;
import 'package:uuid/uuid.dart';

/// 图片已复制到应用存储后的结果；调用者把这些值放进材料草稿。
class PreparedEvidenceImage {
  const PreparedEvidenceImage({
    required this.storageKey,
    required this.fileName,
    this.mimeType,
  });

  final String storageKey; // 应用内部相对键，不是用户原图的绝对路径。
  final String fileName; // 仅用于展示，不参与拼接存储路径。
  final String? mimeType; // 从文件内容识别，无法确认时为空。
}

/// 系统选择器返回的临时选择；读取前先检查声明大小，再检查实际字节数。
class SelectedEvidenceImage {
  const SelectedEvidenceImage({
    required this.fileName,
    required this.byteLength,
    required this.readBytes,
  });

  final String fileName;
  final int byteLength;
  final Future<Uint8List> Function() readBytes;
}

/// 图片业务使用的两个外部能力；测试可以注入独立实现，不触碰用户文件。
abstract interface class EvidenceImagePicker {
  Future<SelectedEvidenceImage?> pick();
}

abstract interface class EvidenceImageStore {
  Future<void> writeNew(String storageKey, Uint8List bytes);
  Future<Uint8List> read(String storageKey);
  Future<void> delete(String storageKey);
  Future<Set<String>> listKeys();
}

/// 组织“选择 → 校验 → 复制”，不创建正式 Evidence，也不修改任务阶段。
class EvidenceImageService {
  EvidenceImageService({
    required EvidenceImageStore store,
    required EvidenceImagePicker picker,
    String Function()? nextId,
  }) : _store = store,
       _picker = picker,
       _nextId = nextId ?? const Uuid().v4;

  static const maxBytes = 20 * 1024 * 1024;
  final EvidenceImageStore _store;
  final EvidenceImagePicker _picker;
  final String Function() _nextId;

  Future<PreparedEvidenceImage?> pickAndPrepare(String missionId) async {
    validateAttachmentSegment(missionId);
    // 系统选择取消返回 null，已有的文字和其他图片草稿不受影响。
    final selection = await _picker.pick();
    if (selection == null) return null;
    _validateSize(selection.byteLength);
    final bytes = await selection.readBytes();
    _validateSize(bytes.length); // 不相信扩展名或选择器给出的长度。
    await _validateDecodableImage(bytes);

    final id = _nextId();
    validateAttachmentSegment(id);
    final format = _imageFormat(bytes);
    final key = 'attachments/$missionId/$id.${format.$1}';
    // 等副本全部写完才返回。之后提交只写数据库引用，不再复制一遍图片。
    await _store.writeNew(key, bytes);
    return PreparedEvidenceImage(
      storageKey: key,
      fileName: _displayName(selection.fileName),
      mimeType: format.$2,
    );
  }

  Future<Uint8List> read(String storageKey) {
    validateAttachmentKey(storageKey);
    return _store.read(storageKey);
  }

  /// 调用者先确认它属于当前草稿且没有正式引用，才可以删除。
  Future<void> delete(String storageKey) {
    validateAttachmentKey(storageKey);
    return _store.delete(storageKey);
  }

  /// 只在数据库恢复后、新草稿创建前调用；调用者负责排除并发创建/提交。
  Future<void> removeUnreferenced(Set<String> referencedKeys) async {
    // 先验证全部引用，发现损坏关系就停止，不能把未知引用当成“没有引用”。
    for (final key in referencedKeys) {
      validateAttachmentKey(key);
    }
    for (final key in await _store.listKeys()) {
      if (!referencedKeys.contains(key)) await _store.delete(key);
    }
  }

  void _validateSize(int size) {
    if (size <= 0) throw ArgumentError('所选图片为空');
    if (size > maxBytes) throw ArgumentError('每张图片不能超过 20 MiB');
  }

  Future<void> _validateDecodableImage(Uint8List bytes) async {
    ui.Codec? codec;
    try {
      // Web 的 encoded ImageDescriptor 不提供 width/height；直接使用共用解码入口。
      // 此处只验证首帧能否解码，1×1 目标控制校验位图大小，不修改保存的原图字节。
      // 禁止放大后，即使原图只有一个像素也不为校验分配多余的显示位图。
      codec = await ui.instantiateImageCodec(
        bytes,
        targetWidth: 1,
        targetHeight: 1,
        allowUpscaling: false,
      );
      final frame = await codec.getNextFrame();
      frame.image.dispose();
    } catch (error, stackTrace) {
      // 开发日志保留真实平台异常，便于区分格式损坏与平台能力缺失；不输出图片内容。
      if (kDebugMode) {
        debugPrint('材料图片校验失败：${error.runtimeType}: $error');
        debugPrintStack(stackTrace: stackTrace, maxFrames: 8);
      }
      throw ArgumentError('所选文件无法读取为图片，请重新选择');
    } finally {
      codec?.dispose();
    }
  }
}

/// 相对键固定三段，避免把盘符、来源 URI 或父目录跳转写入材料引用。
List<String> validateAttachmentKey(String key) {
  final parts = key.split('/');
  if (parts.length != 3 || parts.first != 'attachments') {
    throw ArgumentError('图片存储位置无效');
  }
  validateAttachmentSegment(parts[1]);
  if (!RegExp(
    r'^[A-Za-z0-9][A-Za-z0-9_-]{0,127}\.[a-z0-9]{1,8}$',
  ).hasMatch(parts[2])) {
    throw ArgumentError('图片存储位置无效');
  }
  return parts;
}

void validateAttachmentSegment(String value) {
  if (!RegExp(r'^[A-Za-z0-9][A-Za-z0-9_-]{0,127}$').hasMatch(value)) {
    throw ArgumentError('图片所属任务或文件编号无效');
  }
}

String _displayName(String raw) {
  final name = raw
      .replaceAll('\\', '/')
      .split('/')
      .last
      .replaceAll(RegExp(r'[\x00-\x1f\x7f]'), '_')
      .trim();
  if (name.isEmpty) return '图片';
  return name.length > 180 ? name.substring(0, 180) : name;
}

// 后缀由文件签名确定；未知但可以解码的图片保留原始字节，类型不猜测。
(String, String?) _imageFormat(Uint8List bytes) {
  if (bytes.length >= 8 &&
      bytes[0] == 0x89 &&
      bytes[1] == 0x50 &&
      bytes[2] == 0x4e &&
      bytes[3] == 0x47) {
    return ('png', 'image/png');
  }
  if (bytes.length >= 3 &&
      bytes[0] == 0xff &&
      bytes[1] == 0xd8 &&
      bytes[2] == 0xff) {
    return ('jpg', 'image/jpeg');
  }
  if (bytes.length >= 6 && String.fromCharCodes(bytes.take(3)) == 'GIF') {
    return ('gif', 'image/gif');
  }
  if (bytes.length >= 12 &&
      String.fromCharCodes(bytes.take(4)) == 'RIFF' &&
      String.fromCharCodes(bytes.skip(8).take(4)) == 'WEBP') {
    return ('webp', 'image/webp');
  }
  if (bytes.length >= 2 && bytes[0] == 0x42 && bytes[1] == 0x4d) {
    return ('bmp', 'image/bmp');
  }
  return ('image', null);
}

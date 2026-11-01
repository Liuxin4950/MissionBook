import 'dart:typed_data';
import 'package:uuid/uuid.dart';
import '../../domain/entities/content_draft.dart';
import 'attachment_file_service.dart';

/// 协调记录和任务共用的附件草稿、正式引用与文件清理。
class AttachmentCoordinator {
  AttachmentCoordinator({
    required Future<Set<String>> Function() referencedKeys,
    AttachmentFileService? files,
  }) : _referencedKeys = referencedKeys,
       _files = files;

  final Future<Set<String>> Function() _referencedKeys;
  final AttachmentFileService? _files;
  final _preparedKeys = <String>{};
  final _uuid = const Uuid();
  Future<void>? _initialization;
  Future<void>? _queue;

  AttachmentFileService get _store =>
      _files ?? (throw StateError('当前环境未配置图片存储，请重新打开应用'));

  /// 把文件检查与数据库提交、草稿清理串行化；失败不会阻塞后续操作。
  Future<T> synchronized<T>(Future<T> Function() operation) {
    final previous = _queue;
    final result = previous == null
        ? Future<T>.sync(operation)
        : previous.then<T>((_) => operation());
    late final Future<void> tail;
    void release() {
      if (identical(_queue, tail)) _queue = null;
    }

    tail = result.then<void>(
      (_) => release(),
      onError: (Object _, StackTrace _) => release(),
    );
    _queue = tail;
    return result;
  }

  /// 首次准备时清理无引用文件；与正在提交的记录和材料互斥。
  Future<void> initialize() async {
    final initialization = _initialization ??= synchronized(() async {
      final referenced = await _referencedKeys();
      await _store.removeUnreferenced(referenced);
    });
    try {
      await initialization;
    } catch (_) {
      if (identical(_initialization, initialization)) _initialization = null;
      rethrow;
    }
  }

  Future<ContentDraft?> pickImage(String ownerId) async {
    await initialize();
    final prepared = await _store.pickAndPrepare(ownerId);
    if (prepared == null) return null;
    _preparedKeys.add(prepared.storageKey);
    return ContentDraft(
      id: _uuid.v4(),
      type: ContentType.image,
      source: ContentSource.fileSystem,
      attachmentStorageKey: prepared.storageKey,
      attachmentFileName: prepared.fileName,
      attachmentMimeType: prepared.mimeType,
    );
  }

  Future<ContentDraft?> pickFile(String ownerId) async {
    await initialize();
    final prepared = await _store.pickFileAndPrepare(ownerId);
    if (prepared == null) return null;
    _preparedKeys.add(prepared.storageKey);
    return ContentDraft(
      id: _uuid.v4(),
      type: ContentType.file,
      source: ContentSource.fileSystem,
      attachmentStorageKey: prepared.storageKey,
      attachmentFileName: prepared.fileName,
      attachmentMimeType: prepared.mimeType,
    );
  }

  Future<ContentDraft> captureImage(
    String ownerId,
    Uint8List bytes, {
    required DateTime capturedAt,
  }) async {
    await initialize();
    final prepared = await _store.prepareCapturedImage(ownerId, bytes);
    _preparedKeys.add(prepared.storageKey);
    return ContentDraft(
      id: _uuid.v4(),
      type: ContentType.image,
      source: ContentSource.camera,
      attachmentStorageKey: prepared.storageKey,
      attachmentFileName: prepared.fileName,
      attachmentMimeType: prepared.mimeType,
      capturedAt: capturedAt.toUtc(),
    );
  }

  Future<Uint8List> read(String key) => _store.read(key);

  /// 在 synchronized 的提交成功后调用，解除对应草稿的清理资格。
  void markCommitted(Iterable<ContentDraft> items) {
    for (final item in items) {
      _preparedKeys.remove(item.attachmentStorageKey);
    }
  }

  Future<void> discard(Iterable<ContentDraft> items) => synchronized(() async {
    final referenced = await _referencedKeys();
    for (final item in items) {
      final key = item.attachmentStorageKey;
      if (key != null &&
          _preparedKeys.contains(key) &&
          !referenced.contains(key)) {
        await _store.delete(key);
        _preparedKeys.remove(key);
      }
    }
  });
}

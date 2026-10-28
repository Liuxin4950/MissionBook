import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:uuid/uuid.dart';

import '../agent_result.dart';
import '../json_value.dart';
import '../models/configuration.dart';
import '../sessions/session_store.dart';

/// 原生平台的追加日志；持有文件锁，完整行带校验值，每次提交后 flush。
final class FileSessionStore implements SessionStore {
  FileSessionStore(this.directory);
  final Directory directory;
  static final Set<String> _processWriters = {};
  @override
  Future<SessionHandle> create(String id) => _open(id, create: true);
  @override
  Future<SessionHandle> open(String id) => _open(id, create: false);

  Future<SessionHandle> _open(String id, {required bool create}) async {
    validateSessionId(id);
    await directory.create(recursive: true);
    final file = File('${directory.path}/$id.jsonl');
    final canonical = file.absolute.uri.normalizePath().toString();
    final writerKey = Platform.isWindows ? canonical.toLowerCase() : canonical;
    if (!_processWriters.add(writerKey)) throw StateError('会话已有写入者：$id');
    RandomAccessFile? lock;
    RandomAccessFile? output;
    try {
      lock = await File('${file.path}.lock').open(mode: FileMode.append);
      await lock.lock(FileLock.exclusive);
      if (create) {
        await file.create(exclusive: true);
        await file.writeAsString(
          '${jsonEncode({'format': 'agent_core_session', 'version': 1, 'id': id})}\n',
          flush: true,
        );
      }
      final bytes = await file.readAsBytes();
      final completeEnd = bytes.lastIndexOf(10) + 1;
      if (completeEnd == 0) throw const FormatException('会话缺少完整文件头');
      final lines = utf8.decode(bytes.sublist(0, completeEnd)).split('\n');
      final header = readObject(jsonDecode(lines.first));
      if (header['format'] != 'agent_core_session' ||
          header['version'] != 1 ||
          header['id'] != id) {
        throw const FormatException('会话文件格式、版本或编号不匹配');
      }
      final records = <SessionRecord>[];
      for (final line in lines.skip(1)) {
        if (line.isEmpty) continue;
        final envelope = readObject(jsonDecode(line));
        final json = readObject(envelope['record']);
        if (_digest(json) != envelope['sha256']) {
          throw const FormatException('会话记录校验失败，原文件保留');
        }
        final record = SessionRecord.fromJson(json);
        if (record.sequence != records.length) {
          throw const FormatException('会话日志序号不连续');
        }
        records.add(record);
      }
      final recovered = bytes.length - completeEnd;
      if (recovered > 0) {
        // 只处理最后一个未提交的尾片段；完整但损坏的行绝不自动丢弃。
        await File(
          '${file.path}.torn-${const Uuid().v4()}',
        ).writeAsBytes(bytes.sublist(completeEnd), flush: true);
        final repair = await file.open(mode: FileMode.append);
        try {
          await repair.truncate(completeEnd);
          await repair.flush();
        } finally {
          await repair.close();
        }
      }
      output = await file.open(mode: FileMode.append);
      return _FileSessionHandle(
        id,
        records,
        output,
        lock,
        recovered,
        () => _processWriters.remove(writerKey),
      );
    } catch (error) {
      await output?.close();
      await lock?.close();
      _processWriters.remove(writerKey);
      rethrow;
    }
  }

  @override
  Future<List<String>> listSessionIds() async {
    if (!await directory.exists()) return [];
    final ids = <String>[];
    await for (final entry in directory.list()) {
      if (entry is! File || !entry.path.endsWith('.jsonl')) continue;
      final name = entry.uri.pathSegments.last;
      final id = name.substring(0, name.length - 6);
      if (RegExp(r'^[A-Za-z0-9_-]{1,80}$').hasMatch(id)) ids.add(id);
    }
    return ids..sort();
  }
}

String _digest(Map<String, Object?> record) =>
    sha256.convert(utf8.encode(jsonEncode(record))).toString();

final class _FileSessionHandle implements SessionHandle {
  _FileSessionHandle(
    this.id,
    this._records,
    this._file,
    this._lock,
    this.recoveredTailBytes,
    this._release,
  );
  @override
  final String id;
  final List<SessionRecord> _records;
  final RandomAccessFile _file;
  final RandomAccessFile _lock;
  @override
  final int recoveredTailBytes;
  final void Function() _release;
  Future<void> _writes = Future.value();
  Future<void>? _closing;
  bool _broken = false;
  @override
  List<SessionRecord> get records => List.unmodifiable(_records);

  @override
  Future<SessionRecord> append(String type, Map<String, Object?> data) {
    final snapshot = freezeJsonObject(data);
    if (_closing != null || _broken) {
      return Future.error(
        const AgentPersistenceException('会话日志已关闭或写入失败，需要重新打开'),
      );
    }
    final operation = _writes.then((_) async {
      if (_broken) throw const AgentPersistenceException('前一次日志写入失败，已停止后续写入');
      final record = SessionRecord(
        sequence: _records.length,
        timestamp: DateTime.now().toUtc(),
        type: type,
        data: snapshot,
      );
      final bytes = utf8.encode(
        '${jsonEncode({'record': record.toJson(), 'sha256': _digest(record.toJson())})}\n',
      );
      try {
        await _file.writeFrom(bytes);
        await _file.flush();
      } catch (error) {
        _broken = true;
        throw AgentPersistenceException(
          '无法保存会话，已停止后续操作；请检查存储后重新打开',
          cause: error,
        );
      }
      _records.add(record);
      return record;
    });
    _writes = operation.then<void>(
      (_) {},
      onError: (Object error, StackTrace stack) {
        // 错误由 operation 交给调用者；此链只负责串行等待已经排队的写入。
      },
    );
    return operation;
  }

  @override
  Future<void> close() => _closing ??= _close();
  Future<void> _close() async {
    await _writes;
    try {
      await _file.close();
    } finally {
      try {
        await _lock.close();
      } finally {
        _release();
      }
    }
  }
}

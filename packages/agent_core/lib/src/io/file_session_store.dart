import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:uuid/uuid.dart';

import '../agent_result.dart';
import '../json_value.dart';
import '../models/configuration.dart';
import '../sessions/session_store.dart';

/// 可分页读取的 JSONL 日志；SQLite 只负责跨进程、跨 isolate 的写租约。
final class FileSessionStore implements SessionStore {
  FileSessionStore(
    this.directory, {
    this.maxJournalBytes = 256 * 1024 * 1024,
    this.maxRecordBytes = 64 * 1024 * 1024,
  });

  final Directory directory;
  final int maxJournalBytes;
  final int maxRecordBytes;

  File _file(String id) {
    validateSessionId(id);
    return File('${directory.path}/$id.jsonl');
  }

  Database _lease(String id) {
    // SQLite 的锁管理能处理同进程的多个连接；进程中断后由系统释放。
    final lock = sqlite3.open('${_file(id).path}.lock');
    try {
      lock.execute('BEGIN EXCLUSIVE');
      return lock;
    } catch (error) {
      lock.close();
      if (error is SqliteException &&
          (error.resultCode == 5 || error.resultCode == 6)) {
        throw StateError('会话已有写入者：$id');
      }
      rethrow;
    }
  }

  @override
  Future<SessionHandle> create(
    String id, {
    List<SessionRecord> initialRecords = const [],
  }) async {
    await directory.create(recursive: true);
    final file = _file(id);
    final lease = _lease(id);
    try {
      if (await file.exists() && await file.length() > 0) {
        final scan = await _scan(file, id);
        if (scan.offsets.isNotEmpty || scan.tail.isNotEmpty) {
          throw StateError('会话已存在：$id');
        }
      }
      // 先完整写入临时文件，再一次改名；中断不会留下半份已接受的导入。
      final staged = File('${file.path}.staging-${const Uuid().v4()}');
      try {
        final output = await staged.open(mode: FileMode.write);
        try {
          await output.writeString(
            '${jsonEncode({'format': 'agent_core_session', 'version': 1, 'id': id})}\n',
          );
          for (var index = 0; index < initialRecords.length; index++) {
            final record = initialRecords[index];
            if (record.sequence != index) {
              throw const FormatException('初始日志序号不连续');
            }
            final bytes = _encodeRecord(record);
            _checkSize(bytes.length, await output.position());
            await output.writeFrom(bytes);
          }
          await output.flush();
        } finally {
          await output.close();
        }
        await staged.rename(file.path);
      } finally {
        if (await staged.exists()) await staged.delete();
      }
      return await _openLocked(id, file, lease, readOnly: false);
    } catch (_) {
      lease.close();
      rethrow;
    }
  }

  @override
  Future<SessionHandle> open(String id, {bool readOnly = false}) async {
    final file = _file(id);
    if (!await file.exists()) throw StateError('会话不存在：$id');
    final lease = readOnly ? null : _lease(id);
    try {
      return await _openLocked(id, file, lease, readOnly: readOnly);
    } catch (_) {
      lease?.close();
      rethrow;
    }
  }

  Future<SessionHandle> _openLocked(
    String id,
    File file,
    Database? lease, {
    required bool readOnly,
  }) async {
    final scan = await _scan(file, id);
    var committedLength = scan.committedLength;
    if (scan.tail.isNotEmpty && !readOnly) {
      await File(
        '${file.path}.torn-${const Uuid().v4()}',
      ).writeAsBytes(scan.tail, flush: true);
      final repair = await file.open(mode: FileMode.append);
      try {
        await repair.truncate(committedLength);
        await repair.flush();
      } finally {
        await repair.close();
      }
    }
    final handle = _FileSessionHandle(
      this,
      id,
      file,
      lease,
      scan.offsets,
      committedLength,
      readOnly,
    );
    if (scan.tail.isNotEmpty && !readOnly && scan.offsets.isNotEmpty) {
      await handle.append('storage_tail_recovered', {
        'bytes': scan.tail.length,
      });
    }
    return handle;
  }

  Future<_JournalIndex> _scan(File file, String id) async {
    if (await file.length() > maxJournalBytes) {
      throw const FormatException('会话日志超过本地体积限额，请先归档');
    }
    final offsets = <(int, int)>[];
    final pending = BytesBuilder(copy: false);
    var offset = 0;
    var committedLength = 0;
    var headerRead = false;
    await for (final chunk in file.openRead()) {
      var start = 0;
      for (var index = 0; index < chunk.length; index++) {
        if (chunk[index] != 10) continue;
        pending.add(chunk.sublist(start, index));
        final line = pending.takeBytes();
        if (line.length > maxRecordBytes) {
          throw const FormatException('单条会话记录过大');
        }
        final length = line.length + 1;
        if (!headerRead) {
          final header = readObject(jsonDecode(utf8.decode(line)));
          if (header['format'] != 'agent_core_session' ||
              header['version'] != 1 ||
              header['id'] != id) {
            throw const FormatException('会话文件格式、版本或编号不匹配');
          }
          headerRead = true;
        } else if (line.isNotEmpty) {
          final record = _decodeRecord(line);
          if (record.sequence != offsets.length) {
            throw const FormatException('会话日志序号不连续');
          }
          offsets.add((offset, length));
        }
        offset += length;
        committedLength = offset;
        start = index + 1;
      }
      pending.add(chunk.sublist(start));
      if (pending.length > maxRecordBytes) {
        throw const FormatException('单条会话记录过大');
      }
    }
    if (!headerRead) throw const FormatException('会话缺少完整文件头；空文件可重新 create');
    return _JournalIndex(offsets, committedLength, pending.takeBytes());
  }

  void _checkSize(int recordBytes, int existingBytes) {
    if (recordBytes > maxRecordBytes) {
      throw const AgentPersistenceException('单条记录超过本地体积限额');
    }
    if (existingBytes + recordBytes > maxJournalBytes) {
      throw const AgentPersistenceException('会话日志达到体积限额，请导出归档并新建会话');
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

  @override
  Future<void> delete(String id) async {
    final file = _file(id);
    if (!await file.exists()) return;
    final lease = _lease(id);
    try {
      await file.delete();
    } finally {
      lease.close();
    }
  }
}

final class _JournalIndex {
  const _JournalIndex(this.offsets, this.committedLength, this.tail);
  final List<(int, int)> offsets;
  final int committedLength;
  final List<int> tail;
}

List<int> _encodeRecord(SessionRecord record) {
  final json = record.toJson();
  return utf8.encode(
    '${jsonEncode({'record': json, 'sha256': _digest(json)})}\n',
  );
}

String _digest(Map<String, Object?> record) =>
    sha256.convert(utf8.encode(jsonEncode(record))).toString();

SessionRecord _decodeRecord(List<int> bytes) {
  final envelope = readObject(jsonDecode(utf8.decode(bytes)));
  final json = readObject(envelope['record']);
  if (_digest(json) != envelope['sha256']) {
    throw const FormatException('会话记录校验失败，原文件保留');
  }
  return SessionRecord.fromJson(json);
}

final class _FileSessionHandle implements SessionHandle {
  _FileSessionHandle(
    this.store,
    this.id,
    this.file,
    this.lease,
    this.offsets,
    this.length,
    this.readOnly,
  );
  final FileSessionStore store;
  @override
  final String id;
  final File file;
  final Database? lease;
  final List<(int, int)> offsets;
  int length;
  @override
  final bool readOnly;
  bool _closed = false;
  bool _broken = false;
  Future<void>? _closing;
  Future<void> _writes = Future.value();
  @override
  int get recordCount => offsets.length;

  @override
  Future<List<SessionRecord>> readRecords({int start = 0, int? limit}) async {
    if (_closed) throw StateError('会话存储已关闭');
    if (start < 0 || limit != null && limit < 0) {
      throw ArgumentError('分页参数不能为负数');
    }
    final result = <SessionRecord>[];
    final selected = offsets.skip(start).take(limit ?? offsets.length).toList();
    final input = await file.open();
    try {
      for (final (offset, size) in selected) {
        await input.setPosition(offset);
        final bytes = await input.read(size - 1);
        result.add(_decodeRecord(bytes));
      }
    } finally {
      await input.close();
    }
    return List.unmodifiable(result);
  }

  @override
  Future<SessionRecord> append(String type, Map<String, Object?> data) {
    if (readOnly) throw StateError('只读会话不能追加记录');
    if (_closing != null || _closed) {
      return Future.error(const AgentPersistenceException('会话存储正在关闭'));
    }
    final snapshot = freezeJsonObject(data);
    final operation = _writes.then((_) async {
      if (_closed || _broken) {
        throw const AgentPersistenceException('日志已关闭或上次写入失败');
      }
      final record = SessionRecord(
        sequence: offsets.length,
        timestamp: DateTime.now().toUtc(),
        type: type,
        data: snapshot,
      );
      final bytes = _encodeRecord(record);
      store._checkSize(bytes.length, length);
      final output = await file.open(mode: FileMode.append);
      try {
        await output.writeFrom(bytes);
        await output.flush();
      } catch (error) {
        _broken = true;
        throw AgentPersistenceException('无法保存会话，已停止后续操作', cause: error);
      } finally {
        await output.close();
      }
      offsets.add((length, bytes.length));
      length += bytes.length;
      return record;
    });
    _writes = operation.then<void>(
      (_) {},
      onError: (Object error, StackTrace stack) {},
    );
    return operation;
  }

  @override
  Future<void> close() => _closing ??= _close();
  Future<void> _close() async {
    await _writes;
    if (_closed) return;
    _closed = true;
    lease?.close();
  }
}

import 'dart:async';
import 'dart:convert';

import 'package:agent_core/agent_core.dart';
import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../local/app_database.dart';

class AssistantConversationSummary {
  const AssistantConversationSummary({
    required this.id,
    required this.title,
    required this.createdAt,
    required this.updatedAt,
    this.missionId,
    this.goalId,
  });

  final String id;
  final String title;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? missionId;
  final String? goalId;
}

/// 把基座原始日志存入 AppDatabase；列表索引与记录在同一事务更新。
class DriftSessionStore implements SessionStore {
  DriftSessionStore(
    this._database, {
    DateTime Function()? clock,
    Duration writerLease = const Duration(seconds: 30),
  }) : _clock = clock ?? DateTime.now,
       _writerLease = writerLease {
    if (writerLease < const Duration(seconds: 3)) {
      throw ArgumentError('会话写租约不能短于 3 秒');
    }
  }

  final AppDatabase _database;
  final DateTime Function() _clock;
  final Duration _writerLease;
  final _uuid = const Uuid();

  int get _nowMilliseconds => _clock().toUtc().millisecondsSinceEpoch;
  int get _leaseUntil => _nowMilliseconds + _writerLease.inMilliseconds;

  @override
  Future<SessionHandle> create(
    String id, {
    List<SessionRecord> initialRecords = const [],
  }) async {
    _validateId(id);
    for (var index = 0; index < initialRecords.length; index++) {
      if (initialRecords[index].sequence != index) {
        throw const FormatException('初始日志序号不连续');
      }
    }
    final existing = await _sessionById(id);
    if (existing != null) throw StateError('会话已存在：$id');
    final token = _uuid.v4();
    final now = _nowMilliseconds;
    final createdAt = initialRecords.isEmpty
        ? now
        : initialRecords.first.timestamp.toUtc().millisecondsSinceEpoch;
    final updatedAt = initialRecords.isEmpty
        ? now
        : initialRecords.last.timestamp.toUtc().millisecondsSinceEpoch;
    final title = _initialTitle(initialRecords);
    await _database.transaction(() async {
      await _database
          .into(_database.assistantSessions)
          .insert(
            AssistantSessionsCompanion.insert(
              id: id,
              title: title,
              createdAt: createdAt,
              updatedAt: updatedAt,
              writerToken: Value(token),
              writerLeaseUntil: Value(_leaseUntil),
            ),
          );
      for (final record in initialRecords) {
        await _insertRecord(id, record);
      }
    });
    return _DriftSessionHandle._writer(
      _database,
      id,
      initialRecords.length,
      token,
      _clock,
      _writerLease,
    );
  }

  @override
  Future<SessionHandle> open(String id, {bool readOnly = false}) async {
    _validateId(id);
    if (await _sessionById(id) == null) throw StateError('会话不存在：$id');
    final count = await _recordCount(id);
    if (readOnly) return _DriftSessionHandle._reader(_database, id, count);
    final token = _uuid.v4();
    final now = _nowMilliseconds;
    final changed = await _database.transaction(() async {
      final update = _database.update(_database.assistantSessions);
      update.where(
        (table) =>
            table.id.equals(id) &
            (table.writerLeaseUntil.isNull() |
                table.writerLeaseUntil.isSmallerThanValue(now)),
      );
      return update.write(
        AssistantSessionsCompanion(
          writerToken: Value(token),
          writerLeaseUntil: Value(_leaseUntil),
        ),
      );
    });
    if (changed != 1) throw StateError('会话仍由另一个窗口或进程使用：$id');
    return _DriftSessionHandle._writer(
      _database,
      id,
      count,
      token,
      _clock,
      _writerLease,
    );
  }

  @override
  Future<List<String>> listSessionIds() async {
    final query = _database.select(_database.assistantSessions)
      ..orderBy([
        (table) => OrderingTerm.desc(table.updatedAt),
        (table) => OrderingTerm.asc(table.id),
      ]);
    final rows = await query.get();
    return [for (final row in rows) row.id];
  }

  Future<List<AssistantConversationSummary>> listConversations() async {
    final query = _database.select(_database.assistantSessions)
      ..orderBy([
        (table) => OrderingTerm.desc(table.updatedAt),
        (table) => OrderingTerm.asc(table.id),
      ]);
    final rows = await query.get();
    return [
      for (final row in rows)
        AssistantConversationSummary(
          id: row.id,
          title: row.title,
          createdAt: DateTime.fromMillisecondsSinceEpoch(
            row.createdAt,
            isUtc: true,
          ),
          updatedAt: DateTime.fromMillisecondsSinceEpoch(
            row.updatedAt,
            isUtc: true,
          ),
          missionId: row.missionId,
          goalId: row.goalId,
        ),
    ];
  }

  Future<void> attachReference(
    String id, {
    String? missionId,
    String? goalId,
  }) async {
    if (missionId != null && goalId != null) {
      throw ArgumentError('一个会话只关联一个任务或一个目标');
    }
    final update = _database.update(_database.assistantSessions);
    update.where((table) => table.id.equals(id));
    final changed = await update.write(
      AssistantSessionsCompanion(
        missionId: Value(missionId),
        goalId: Value(goalId),
      ),
    );
    if (changed != 1) throw StateError('会话不存在：$id');
  }

  @override
  Future<void> delete(String id) async {
    _validateId(id);
    final now = _nowMilliseconds;
    await _database.transaction(() async {
      final session = await _sessionById(id);
      if (session == null) return;
      final lease = session.writerLeaseUntil;
      if (lease != null && lease > now) {
        throw StateError('请先关闭该会话，再删除');
      }
      final records = _database.delete(_database.assistantSessionRecords);
      records.where((table) => table.sessionId.equals(id));
      await records.go();
      final sessions = _database.delete(_database.assistantSessions);
      sessions.where((table) => table.id.equals(id));
      await sessions.go();
    });
  }

  Future<AssistantSession?> _sessionById(String id) {
    final query = _database.select(_database.assistantSessions)
      ..where((table) => table.id.equals(id));
    return query.getSingleOrNull();
  }

  Future<int> _recordCount(String id) async {
    final query = _database.selectOnly(_database.assistantSessionRecords)
      ..addColumns([_database.assistantSessionRecords.sequence])
      ..where(_database.assistantSessionRecords.sessionId.equals(id));
    return (await query.get()).length;
  }

  Future<void> _insertRecord(String sessionId, SessionRecord record) {
    return _database
        .into(_database.assistantSessionRecords)
        .insert(
          AssistantSessionRecordsCompanion.insert(
            sessionId: sessionId,
            sequence: record.sequence,
            timestamp: record.timestamp.toUtc().millisecondsSinceEpoch,
            type: record.type,
            data: jsonEncode(record.data),
            version: Value(record.version),
            ignorable: Value(record.ignorable),
          ),
        );
  }

  static String _initialTitle(List<SessionRecord> records) {
    if (records.isEmpty) return '新会话';
    final title = records.first.data['title'];
    return title is String && title.trim().isNotEmpty ? title : '新会话';
  }

  static void _validateId(String id) {
    if (!RegExp(r'^[A-Za-z0-9_-]{1,80}$').hasMatch(id)) {
      throw ArgumentError('无效会话编号');
    }
  }
}

final class _DriftSessionHandle implements SessionHandle {
  _DriftSessionHandle._reader(this._database, this.id, this._recordCount)
    : readOnly = true,
      _writerToken = null,
      _clock = null,
      _writerLease = null;

  _DriftSessionHandle._writer(
    this._database,
    this.id,
    this._recordCount,
    this._writerToken,
    this._clock,
    this._writerLease,
  ) : readOnly = false {
    _leaseTimer = Timer.periodic(
      Duration(milliseconds: _writerLease!.inMilliseconds ~/ 3),
      (_) => unawaited(_renewLease()),
    );
  }

  final AppDatabase _database;
  @override
  final String id;
  @override
  final bool readOnly;
  final String? _writerToken;
  final DateTime Function()? _clock;
  final Duration? _writerLease;
  int _recordCount;
  bool _closed = false;
  Timer? _leaseTimer;

  @override
  int get recordCount => _recordCount;

  String get _requiredWriterToken =>
      _writerToken ?? (throw StateError('只读会话没有写租约'));

  @override
  Future<List<SessionRecord>> readRecords({int start = 0, int? limit}) async {
    if (_closed) throw StateError('会话存储已关闭');
    if (start < 0 || limit != null && limit < 0) {
      throw ArgumentError('分页参数不能为负数');
    }
    final query = _database.select(_database.assistantSessionRecords)
      ..where((table) => table.sessionId.equals(id))
      ..orderBy([(table) => OrderingTerm.asc(table.sequence)])
      ..limit(limit ?? -1, offset: start);
    final rows = await query.get();
    return [
      for (final row in rows)
        SessionRecord(
          sequence: row.sequence,
          timestamp: DateTime.fromMillisecondsSinceEpoch(
            row.timestamp,
            isUtc: true,
          ),
          type: row.type,
          data: Map<String, Object?>.from(jsonDecode(row.data) as Map),
          version: row.version,
          ignorable: row.ignorable,
        ),
    ];
  }

  @override
  Future<SessionRecord> append(String type, Map<String, Object?> data) async {
    if (_closed) throw StateError('会话存储已关闭');
    if (readOnly) throw StateError('只读会话不能追加记录');
    final now = _clock!().toUtc();
    final record = SessionRecord(
      sequence: _recordCount,
      timestamp: now,
      type: type,
      data: data,
    );
    await _database.transaction(() async {
      await _checkLease();
      final duplicate =
          await (_database.select(_database.assistantSessionRecords)..where(
                (table) =>
                    table.sessionId.equals(id) &
                    table.sequence.equals(record.sequence),
              ))
              .getSingleOrNull();
      if (duplicate != null) throw StateError('会话记录序号冲突');
      await _database
          .into(_database.assistantSessionRecords)
          .insert(
            AssistantSessionRecordsCompanion.insert(
              sessionId: id,
              sequence: record.sequence,
              timestamp: record.timestamp.millisecondsSinceEpoch,
              type: type,
              data: jsonEncode(record.data),
            ),
          );
      final title = switch (type) {
        'session_created' || 'title_changed' => data['title'] as String?,
        _ => null,
      };
      final update = _database.update(_database.assistantSessions);
      update.where((table) => table.id.equals(id));
      await update.write(
        AssistantSessionsCompanion(
          title: title == null ? const Value.absent() : Value(title),
          updatedAt: Value(record.timestamp.millisecondsSinceEpoch),
          writerLeaseUntil: Value(
            now.millisecondsSinceEpoch + _writerLease!.inMilliseconds,
          ),
        ),
      );
    });
    _recordCount++;
    return record;
  }

  Future<void> _checkLease() async {
    final query = _database.select(_database.assistantSessions)
      ..where((table) => table.id.equals(id));
    final session = await query.getSingleOrNull();
    final now = _clock!().toUtc().millisecondsSinceEpoch;
    if (session == null ||
        session.writerToken != _writerToken ||
        session.writerLeaseUntil == null ||
        session.writerLeaseUntil! <= now) {
      throw StateError('会话写租约已失效，请重新打开');
    }
  }

  Future<void> _renewLease() async {
    if (_closed || readOnly) return;
    try {
      final now = _clock!().toUtc().millisecondsSinceEpoch;
      final update = _database.update(_database.assistantSessions);
      update.where(
        (table) =>
            table.id.equals(id) &
            table.writerToken.equals(_requiredWriterToken) &
            table.writerLeaseUntil.isBiggerThanValue(now),
      );
      await update.write(
        AssistantSessionsCompanion(
          writerLeaseUntil: Value(now + _writerLease!.inMilliseconds),
        ),
      );
    } catch (_) {
      // 下次 append 会在事务内重新验证租约；后台续期失败不伪装写入成功。
    }
  }

  @override
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    _leaseTimer?.cancel();
    if (readOnly) return;
    final update = _database.update(_database.assistantSessions);
    update.where(
      (table) =>
          table.id.equals(id) & table.writerToken.equals(_requiredWriterToken),
    );
    await update.write(
      const AssistantSessionsCompanion(
        writerToken: Value(null),
        writerLeaseUntil: Value(null),
      ),
    );
  }
}

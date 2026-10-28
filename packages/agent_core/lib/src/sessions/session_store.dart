import '../agent_result.dart';
import '../json_value.dart';
import '../models/configuration.dart';

/// 日志里的一条已提交事实；序号从 0 开始且只能连续增长。
final class SessionRecord {
  SessionRecord({
    required this.sequence,
    required this.timestamp,
    required this.type,
    required Map<String, Object?> data,
  }) : data = freezeJsonObject(data) {
    if (sequence < 0 || type.isEmpty) throw const FormatException('无效会话记录');
  }
  final int sequence;
  final DateTime timestamp;
  final String type;
  final Map<String, Object?> data;

  Map<String, Object?> toJson() => {
    'sequence': sequence,
    'timestamp': timestamp.toUtc().toIso8601String(),
    'type': type,
    'data': data,
  };
  factory SessionRecord.fromJson(Map<String, Object?> json) {
    final sequence = json['sequence'];
    if (sequence is! int) throw const FormatException('无效日志序号');
    return SessionRecord(
      sequence: sequence,
      timestamp: DateTime.parse(readString(json, 'timestamp')),
      type: readString(json, 'type'),
      data: readObject(json['data']),
    );
  }
}

/// 一个写会话句柄独占该日志；append 成功后才更新 records。
abstract interface class SessionHandle {
  String get id;
  List<SessionRecord> get records;
  int get recoveredTailBytes;
  Future<SessionRecord> append(String type, Map<String, Object?> data);
  Future<void> close();
}

abstract interface class SessionStore {
  Future<SessionHandle> create(String id);
  Future<SessionHandle> open(String id);
  Future<List<String>> listSessionIds();
}

/// Web 和测试可使用；数据活在这个 store 对象内，关闭句柄后仍可再次打开。
final class MemorySessionStore implements SessionStore {
  final Map<String, List<SessionRecord>> _journals = {};
  final Set<String> _writers = {};
  @override
  Future<SessionHandle> create(String id) async {
    validateSessionId(id);
    if (_journals.containsKey(id)) throw StateError('会话已存在：$id');
    _journals[id] = [];
    return _open(id);
  }

  @override
  Future<SessionHandle> open(String id) async {
    validateSessionId(id);
    if (!_journals.containsKey(id)) throw StateError('会话不存在：$id');
    return _open(id);
  }

  SessionHandle _open(String id) {
    if (!_writers.add(id)) throw StateError('会话已有写入者：$id');
    return _MemorySessionHandle(id, _journals[id]!, () => _writers.remove(id));
  }

  @override
  Future<List<String>> listSessionIds() async =>
      _journals.keys.toList()..sort();
}

final class _MemorySessionHandle implements SessionHandle {
  _MemorySessionHandle(this.id, this._records, this._release);
  @override
  final String id;
  final List<SessionRecord> _records;
  final void Function() _release;
  bool _closed = false;
  @override
  int get recoveredTailBytes => 0;
  @override
  List<SessionRecord> get records => List.unmodifiable(_records);
  @override
  Future<SessionRecord> append(String type, Map<String, Object?> data) async {
    if (_closed) throw const AgentPersistenceException('会话存储已关闭');
    final record = SessionRecord(
      sequence: _records.length,
      timestamp: DateTime.now().toUtc(),
      type: type,
      data: data,
    );
    _records.add(record);
    return record;
  }

  @override
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    _release();
  }
}

void validateSessionId(String id) {
  if (!RegExp(r'^[A-Za-z0-9_-]{1,80}$').hasMatch(id)) {
    throw ArgumentError('无效会话编号');
  }
}

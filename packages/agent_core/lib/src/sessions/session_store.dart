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
    this.version = 1,
    this.ignorable = false,
  }) : data = freezeJsonObject(data) {
    if (sequence < 0 || type.isEmpty) throw const FormatException('无效会话记录');
  }
  final int sequence;
  final DateTime timestamp;
  final String type;
  final Map<String, Object?> data;
  final int version; // 记录自身的格式版本；旧记录未声明时视为 1。
  final bool ignorable; // 只有明确声明为诊断类记录，未来读者才可以跳过。

  Map<String, Object?> toJson() => {
    'sequence': sequence,
    'timestamp': timestamp.toUtc().toIso8601String(),
    'type': type,
    'data': data,
    'version': version,
    if (ignorable) 'ignorable': true,
  };
  factory SessionRecord.fromJson(Map<String, Object?> json) {
    final sequence = json['sequence'];
    if (sequence is! int) throw const FormatException('无效日志序号');
    return SessionRecord(
      sequence: sequence,
      timestamp: DateTime.parse(readString(json, 'timestamp')),
      type: readString(json, 'type'),
      data: readObject(json['data']),
      version: json['version'] as int? ?? 1,
      ignorable: json['ignorable'] as bool? ?? false,
    );
  }
}

/// 一个写会话句柄独占该日志；append 成功后才更新 records。
abstract interface class SessionHandle {
  String get id;
  int get recordCount;
  bool get readOnly;
  Future<List<SessionRecord>> readRecords({int start = 0, int? limit});
  Future<SessionRecord> append(String type, Map<String, Object?> data);
  Future<void> close();
}

abstract interface class SessionStore {
  Future<SessionHandle> create(
    String id, {
    List<SessionRecord> initialRecords = const [],
  });
  Future<SessionHandle> open(String id, {bool readOnly = false});
  Future<List<String>> listSessionIds();
  Future<void> delete(String id); // 只删除已关闭的会话；宿主决定何时允许用户删除。
}

/// Web 和测试可使用；数据活在这个 store 对象内，关闭句柄后仍可再次打开。
final class MemorySessionStore implements SessionStore {
  final Map<String, List<SessionRecord>> _journals = {};
  final Set<String> _writers = {};
  @override
  Future<SessionHandle> create(
    String id, {
    List<SessionRecord> initialRecords = const [],
  }) async {
    validateSessionId(id);
    if (_journals.containsKey(id)) throw StateError('会话已存在：$id');
    for (var index = 0; index < initialRecords.length; index++) {
      if (initialRecords[index].sequence != index) {
        throw const FormatException('初始日志序号不连续');
      }
    }
    _journals[id] = List.of(initialRecords);
    return _open(id);
  }

  @override
  Future<SessionHandle> open(String id, {bool readOnly = false}) async {
    validateSessionId(id);
    if (!_journals.containsKey(id)) throw StateError('会话不存在：$id');
    return _open(id, readOnly: readOnly);
  }

  SessionHandle _open(String id, {bool readOnly = false}) {
    if (!readOnly && !_writers.add(id)) throw StateError('会话已有写入者：$id');
    return _MemorySessionHandle(id, _journals[id]!, readOnly, () {
      if (!readOnly) _writers.remove(id);
    });
  }

  @override
  Future<List<String>> listSessionIds() async =>
      _journals.keys.toList()..sort();

  @override
  Future<void> delete(String id) async {
    validateSessionId(id);
    if (_writers.contains(id)) throw StateError('请先关闭该会话');
    _journals.remove(id);
  }
}

final class _MemorySessionHandle implements SessionHandle {
  _MemorySessionHandle(this.id, this._records, this.readOnly, this._release);
  @override
  final String id;
  final List<SessionRecord> _records;
  final void Function() _release;
  bool _closed = false;
  @override
  final bool readOnly;
  @override
  int get recordCount => _records.length;
  @override
  Future<List<SessionRecord>> readRecords({int start = 0, int? limit}) async {
    if (_closed) throw StateError('会话存储已关闭');
    if (start < 0 || limit != null && limit < 0) {
      throw ArgumentError('分页参数不能为负数');
    }
    return List.unmodifiable(
      _records.skip(start).take(limit ?? _records.length),
    );
  }

  @override
  Future<SessionRecord> append(String type, Map<String, Object?> data) async {
    if (_closed) throw const AgentPersistenceException('会话存储已关闭');
    if (readOnly) throw StateError('只读会话不能追加记录');
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

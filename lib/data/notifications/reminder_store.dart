import 'dart:convert';
import 'dart:io';

/// 单个任务的提醒偏好（规格 §7.1：本地应用设置，不进八张领域表、不参加业务统计）。
class ReminderPreference {
  ReminderPreference({
    required this.missionId,
    required this.scheduleRevisionId,
    this.snoozedUntil,
    this.delivered = false,
  });

  final String missionId;

  /// 偏好只对这个排期版本有效；改期后旧偏好直接丢弃。
  String scheduleRevisionId;

  /// 有效延后时刻（UTC）；对账时优先于原 fixedStartAt（§7.1）。
  DateTime? snoozedUntil;

  /// 该版本是否已实际送达。每次延后重置为未送达；“调度成功”≠已送达。
  bool delivered;

  Map<String, Object?> toJson() => {
    'missionId': missionId,
    'scheduleRevisionId': scheduleRevisionId,
    'snoozedUntil': snoozedUntil?.toIso8601String(),
    'delivered': delivered,
  };

  static ReminderPreference fromJson(Map<String, dynamic> json) =>
      ReminderPreference(
        missionId: json['missionId'] as String,
        scheduleRevisionId: json['scheduleRevisionId'] as String,
        snoozedUntil: json['snoozedUntil'] == null
            ? null
            : DateTime.parse(json['snoozedUntil'] as String),
        delivered: json['delivered'] as bool? ?? false,
      );
}

/// 提醒元数据仓库：偏好 + 稳定通知 id 分配表，JSON 文件持久化。
///
/// 存文件而非 SQLite：提醒偏好按规格不进业务库，也就天然不进备份；
/// 保存失败必须抛给调用方提示，不能假装延后成功（§7.1）。
class ReminderStore {
  ReminderStore(this.file);

  final File file;
  final Map<String, ReminderPreference> _preferences = {};
  final Map<String, int> _notificationIds = {};
  int _nextNotificationId = 1;

  /// 写操作串行链：上一笔结束（成功或失败）后才开始下一笔，
  /// 串行链吸收失败以允许后续重试，调用方仍收到原始错误。
  Future<void> _writeQueue = Future<void>.value();

  /// 读取持久化状态；文件缺失按空仓库处理，格式损坏抛 FormatException
  /// （调用方据此提示“延后偏好可能丢失”）。
  Future<void> load() async {
    if (!await file.exists()) return;
    final json = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
    _preferences.clear();
    _notificationIds.clear();
    for (final entry
        in (json['preferences'] as Map<String, dynamic>? ?? {}).entries) {
      _preferences[entry.key] = ReminderPreference.fromJson(
        entry.value as Map<String, dynamic>,
      );
    }
    _notificationIds.addAll({
      for (final entry
          in (json['notificationIds'] as Map<String, dynamic>? ?? {}).entries)
        entry.key: entry.value as int,
    });
    _nextNotificationId = json['nextNotificationId'] as int? ?? 1;
  }

  Future<void> _save() async {
    await file.parent.create(recursive: true);
    // 先写同目录临时文件再 rename 覆盖：中途失败不会留下半截 JSON。
    final temp = File('${file.path}.tmp');
    await temp.writeAsString(
      jsonEncode({
        'preferences': {
          for (final entry in _preferences.entries)
            entry.key: entry.value.toJson(),
        },
        'notificationIds': _notificationIds,
        'nextNotificationId': _nextNotificationId,
      }),
      flush: true,
    );
    await temp.rename(file.path);
  }

  /// 串行执行“改内存 + 保存”：失败时恢复改动前状态并原样抛出，
  /// 不能把未落盘的变更留在内存里伪装成功（§7.1）。
  Future<T> _write<T>(T Function() mutate) {
    final result = _writeQueue.then((_) async {
      // 偏好对象可变，深拷贝后整体快照，失败时统一恢复。
      final previousPreferences = {
        for (final entry in _preferences.entries)
          entry.key: ReminderPreference.fromJson(entry.value.toJson()),
      };
      final previousIds = Map<String, int>.of(_notificationIds);
      final previousNextId = _nextNotificationId;
      try {
        final value = mutate();
        await _save();
        return value;
      } catch (_) {
        _preferences
          ..clear()
          ..addAll(previousPreferences);
        _notificationIds
          ..clear()
          ..addAll(previousIds);
        _nextNotificationId = previousNextId;
        rethrow;
      }
    });
    _writeQueue = result.then<void>((_) {}, onError: (Object _) {});
    return result;
  }

  ReminderPreference? preferenceOf(String missionId) => _preferences[missionId];

  /// 已分配通知 id 的只读快照，供调用方清理旧通知时读取。
  Map<String, int> get notificationIds => Map.unmodifiable(_notificationIds);

  /// 幂等键 → 稳定 int 通知 id：同一键永远同 id，重排即覆盖。
  /// 新 id 必须保存成功后才返回，避免重启后重新分配撞号。
  Future<int> notificationIdOf(String idempotencyKey) async {
    // 不能读到上一笔尚未落盘的内存分配，尤其是同键的并发调用。
    await _writeQueue;
    final existing = _notificationIds[idempotencyKey];
    if (existing != null) return existing;
    return _write(() {
      // 排队期间可能已有同键分配完成，直接复用，不能重复递增。
      final allocated = _notificationIds[idempotencyKey];
      if (allocated != null) return allocated;
      final id = _nextNotificationId++;
      _notificationIds[idempotencyKey] = id;
      return id;
    });
  }

  /// 延后：写入 snoozedUntil 并把送达标记重置为未送达（§7.1）。
  Future<void> snooze({
    required String missionId,
    required String scheduleRevisionId,
    required DateTime until,
  }) => _write<void>(() {
    final pref = _preferences[missionId] ??= ReminderPreference(
      missionId: missionId,
      scheduleRevisionId: scheduleRevisionId,
    );
    pref
      ..scheduleRevisionId = scheduleRevisionId
      ..snoozedUntil = until
      ..delivered = false;
  });

  /// 标记已送达；此后对账不再反复弹出。
  Future<void> markDelivered(String missionId) async {
    await _writeQueue;
    final pref = _preferences[missionId];
    if (pref == null || pref.delivered) return Future<void>.value();
    return _write<void>(() {
      final current = _preferences[missionId];
      if (current == null || current.delivered) return;
      current.delivered = true;
    });
  }

  /// 对账时登记/更新当前版本偏好（不含延后与送达，各自独立维护）。
  Future<void> register({
    required String missionId,
    required String scheduleRevisionId,
  }) async {
    await _writeQueue;
    final pref = _preferences[missionId];
    if (pref != null && pref.scheduleRevisionId == scheduleRevisionId) {
      return Future<void>.value();
    }
    return _write<void>(() {
      final current = _preferences[missionId];
      if (current == null) {
        _preferences[missionId] = ReminderPreference(
          missionId: missionId,
          scheduleRevisionId: scheduleRevisionId,
        );
        return;
      }
      if (current.scheduleRevisionId == scheduleRevisionId) return;
      // 排期版本变化：旧延后与送达状态一并作废（§7.1）。
      current
        ..scheduleRevisionId = scheduleRevisionId
        ..snoozedUntil = null
        ..delivered = false;
    });
  }

  /// 丢弃失效偏好（任务已开始/已取消/版本过期）并回收其通知 id 登记。
  Future<void> discard(String missionId) async {
    await _writeQueue;
    if (!_preferences.containsKey(missionId)) return Future<void>.value();
    return _write<void>(() {
      _preferences.remove(missionId);
    });
  }
}

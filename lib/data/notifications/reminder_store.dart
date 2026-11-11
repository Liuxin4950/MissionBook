import 'dart:convert';
import 'dart:io';
import '../../application/notifications/reminder_store.dart' as contract;

/// 单个任务的本机提醒送达状态，不参加业务统计和备份。
class ReminderPreference implements contract.ReminderStatus {
  ReminderPreference({
    required this.missionId,
    required this.scheduleRevisionId,
    this.delivered = false,
    this.waitingDelivered = false,
  });

  final String missionId;

  /// 偏好只对这个排期版本有效；改期后旧偏好直接丢弃。
  String scheduleRevisionId;

  /// 该版本是否已实际送达；“调度成功”不等于已送达。
  @override
  bool delivered;
  @override
  bool waitingDelivered; // 到点执行冲突提醒与提前提醒分别去重。

  Map<String, Object?> toJson() => {
    'missionId': missionId,
    'scheduleRevisionId': scheduleRevisionId,
    'delivered': delivered,
    'waitingDelivered': waitingDelivered,
  };

  static ReminderPreference fromJson(Map<String, dynamic> json) =>
      ReminderPreference(
        missionId: json['missionId'] as String,
        scheduleRevisionId: json['scheduleRevisionId'] as String,
        delivered: json['delivered'] as bool? ?? false,
        waitingDelivered: json['waitingDelivered'] as bool? ?? false,
      );
}

/// 提醒元数据仓库：偏好 + 稳定通知 id 分配表，JSON 文件持久化。
///
/// 本机调度状态保存在业务库之外；保存失败交给调用方提示和重试。
class ReminderStore implements contract.ReminderStore {
  ReminderStore(this.file, {this.recoverCorruption = true});

  final File file;
  final bool recoverCorruption;
  bool _needsNotificationReset = false;
  bool get needsNotificationReset => _needsNotificationReset;
  final Map<String, ReminderPreference> _preferences = {};
  final Map<String, int> _notificationIds = {};
  final Set<String> _synchronizedMissions = {};
  int _nextNotificationId = 1;
  @override
  int reminderLeadMinutes = 10; // 全局提前提醒分钟数，-1 表示关闭。

  static const reminderLeadOptions = [-1, 0, 5, 10, 15, 30, 60];

  /// 写操作串行链：上一笔结束（成功或失败）后才开始下一笔，
  /// 串行链吸收失败以允许后续重试，调用方仍收到原始错误。
  Future<void> _writeQueue = Future<void>.value();

  /// 读取持久化状态；文件缺失按空仓库处理，格式损坏抛 FormatException
  /// 调用方负责提示读取失败并提供重试。
  @override
  Future<void> load() async {
    if (!await file.exists()) return;
    final contents = await file.readAsString();
    try {
      _loadJson(jsonDecode(contents) as Map<String, dynamic>);
    } on FormatException {
      await _recover(contents);
    } on TypeError {
      await _recover(contents);
    }
  }

  void _loadJson(Map<String, dynamic> json) {
    final minutes = json['reminderLeadMinutes'] as int? ?? 10;
    if (!reminderLeadOptions.contains(minutes)) {
      throw const FormatException('计划任务提醒设置无效');
    }
    final preferences = <String, ReminderPreference>{};
    for (final entry
        in (json['preferences'] as Map<String, dynamic>? ?? {}).entries) {
      final preference = ReminderPreference.fromJson(
        entry.value as Map<String, dynamic>,
      );
      if (preference.missionId != entry.key) {
        throw const FormatException('提醒所属任务无效');
      }
      preferences[entry.key] = preference;
    }
    final ids = (json['notificationIds'] as Map<String, dynamic>? ?? {})
        .cast<String, int>();
    final nextId = json['nextNotificationId'] as int? ?? 1;
    if (ids.values.any((id) => id <= 0 || id >= nextId) ||
        ids.values.toSet().length != ids.length ||
        nextId <= 0) {
      throw const FormatException('通知编号分配表无效');
    }
    final synchronized = (json['synchronizedMissions'] as List? ?? const [])
        .cast<String>();
    final needsReset = json['needsNotificationReset'] as bool? ?? false;
    reminderLeadMinutes = minutes;
    _preferences.clear();
    _notificationIds.clear();
    _synchronizedMissions
      ..clear()
      ..addAll(synchronized);
    _preferences.addAll(preferences);
    _notificationIds.addAll(ids);
    _nextNotificationId = nextId;
    _needsNotificationReset = needsReset;
  }

  Future<void> _recover(String contents) async {
    // 后台只读取设置，不与前台竞争改写同一个 JSON 文件。
    if (recoverCorruption) {
      await File(
        '${file.path}.corrupt-${DateTime.now().microsecondsSinceEpoch}',
      ).writeAsString(contents, flush: true);
    }
    _preferences.clear();
    _notificationIds.clear();
    _synchronizedMissions.clear();
    _nextNotificationId = 1;
    reminderLeadMinutes = 10;
    _needsNotificationReset = true;
    if (recoverCorruption) await _save();
  }

  /// App 已全量撤销旧系统通知；失败时保留标记，下次启动继续恢复。
  Future<void> completeNotificationReset() => _write<void>(() {
    _needsNotificationReset = false;
  });

  Future<void> _save() async {
    await file.parent.create(recursive: true);
    // 先写同目录临时文件再 rename 覆盖：中途失败不会留下半截 JSON。
    final temp = File('${file.path}.tmp');
    await temp.writeAsString(
      jsonEncode({
        'reminderLeadMinutes': reminderLeadMinutes,
        'preferences': {
          for (final entry in _preferences.entries)
            entry.key: entry.value.toJson(),
        },
        'notificationIds': _notificationIds,
        'synchronizedMissions': _synchronizedMissions.toList(),
        'nextNotificationId': _nextNotificationId,
        'needsNotificationReset': _needsNotificationReset,
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
      final previousLead = reminderLeadMinutes;
      final previousReset = _needsNotificationReset;
      final previousSynchronized = Set<String>.of(_synchronizedMissions);
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
        reminderLeadMinutes = previousLead;
        _needsNotificationReset = previousReset;
        _synchronizedMissions
          ..clear()
          ..addAll(previousSynchronized);
        rethrow;
      }
    });
    _writeQueue = result.then<void>((_) {}, onError: (Object _) {});
    return result;
  }

  /// 保存全局提醒选择；落盘失败时回滚，界面不得显示保存成功。
  @override
  Future<void> setReminderLeadMinutes(int minutes) {
    if (!reminderLeadOptions.contains(minutes)) {
      throw ArgumentError('不支持的提前提醒时间');
    }
    return _write<void>(() {
      reminderLeadMinutes = minutes;
      for (final preference in _preferences.values) {
        preference.delivered = false;
      }
    });
  }

  @override
  ReminderPreference? preferenceOf(String missionId) => _preferences[missionId];
  @override
  Set<String> get synchronizedMissions =>
      Set.unmodifiable({..._synchronizedMissions, ..._preferences.keys});

  @override
  Future<void> rememberSynchronizedMissions(Set<String> ids) async {
    await _writeQueue;
    if (ids.length == _synchronizedMissions.length &&
        ids.containsAll(_synchronizedMissions)) {
      return;
    }
    await _write<void>(() {
      _synchronizedMissions
        ..clear()
        ..addAll(ids);
    });
  }

  /// 已分配通知 id 的只读快照，供调用方清理旧通知时读取。
  @override
  Map<String, int> get notificationIds => Map.unmodifiable(_notificationIds);

  /// 有效幂等键在重排中保持稳定编号；确认撤销后可回收键，数字不再复用。
  /// 新 id 必须保存成功后才返回，避免重启后重新分配撞号。
  @override
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

  @override
  Future<void> forgetNotificationIds(Iterable<String> keys) async {
    final removing = keys.toSet();
    await _writeQueue;
    if (!removing.any(_notificationIds.containsKey)) return;
    await _write<void>(() {
      _notificationIds.removeWhere((key, _) => removing.contains(key));
    });
  }

  /// 标记已送达；此后对账不再反复弹出。
  @override
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

  @override
  Future<void> markWaitingDelivered(String missionId) => _write<void>(() {
    _preferences[missionId]?.waitingDelivered = true;
  });

  /// 对账时登记当前排期版本，送达状态独立维护。
  @override
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
      // 排期版本变化后重新计算送达状态。
      current
        ..scheduleRevisionId = scheduleRevisionId
        ..delivered = false
        ..waitingDelivered = false;
    });
  }

  /// 丢弃送达偏好；通知键由分发端确认撤销后单独回收。
  @override
  Future<void> discard(String missionId) async {
    await _writeQueue;
    if (!_preferences.containsKey(missionId)) return Future<void>.value();
    return _write<void>(() {
      _preferences.remove(missionId);
    });
  }
}

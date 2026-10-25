import 'dart:async';

import '../../data/notifications/notification_dispatcher.dart';
import '../../data/notifications/reminder_store.dart';
import '../../domain/entities/execution_event.dart';
import '../../domain/entities/execution_command.dart';
import '../../domain/entities/mission_detail.dart';
import '../../domain/entities/mission_phase.dart';
import '../../domain/notifications/reminder_request.dart';
import '../missions/mission_service.dart';

/// 通知动作的执行结论：事实类动作的成败、以及需要 UI 接手的部分。
enum NotificationActionResult {
  /// 动作已通过 MissionService 工作流完成。
  handled,

  /// 前置条件过期（旧 sequence/阶段已变）：提示刷新，不允许旧按钮改后来状态。
  stale,

  /// 停止动作在 PAUSE 后需要打开 END 确认（取消确认保持 PAUSED）。
  openEndConfirm,

  /// 保存提醒偏好失败：必须提示，不能假装延后成功（§7.1）。
  preferenceSaveFailed,

  // 点击通知正文只进入任务，不代替用户按事实动作按钮。
  openMission,

  actionFailed,
}

/// 需要 UI 接手的通知动作：外壳订阅后打开 END 确认或提示刷新（§7.2）。
class NotificationUiAction {
  const NotificationUiAction(this.missionId, this.result, {this.message});
  final String missionId;
  final NotificationActionResult result;
  final String? message;
}

/// 提醒调度编排：订阅任务变更、启动对账、延后偏好、执行通知刷新。
///
/// 业务事实一律经 MissionService 工作流写入（与前台按钮同一路径），
/// 本服务只整理提醒投影与本地偏好，不写数据库（§7.2）。
class AppNotificationService {
  AppNotificationService({
    required MissionService missions,
    required ReminderStore store,
    required NotificationDispatcher dispatcher,
    required DateTime Function() now,
  }) : _missions = missions,
       _store = store,
       _dispatcher = dispatcher,
       _now = now;

  final MissionService _missions;
  final ReminderStore _store;
  final NotificationDispatcher _dispatcher;

  // 与仓储同款的可控时钟；测试注入假时钟，业务时刻不散落 DateTime.now()。
  final DateTime Function() _now;
  StreamSubscription<void>? _changes;
  Future<void>? _refreshing;
  bool _refreshAgain = false;
  Future<void> _actions = Future<void>.value();
  final _pendingUiActions = <NotificationUiAction>[];

  // UI 意图广播：事实动作在服务里完成，需要界面接手的部分交回外壳。
  final _uiActions = StreamController<NotificationUiAction>.broadcast();
  Stream<NotificationUiAction> get uiActions => _uiActions.stream;

  List<NotificationUiAction> takePendingUiActions() {
    final actions = List<NotificationUiAction>.of(_pendingUiActions);
    _pendingUiActions.clear();
    return actions;
  }

  void _emit(NotificationUiAction action) {
    if (_uiActions.isClosed) return;
    _pendingUiActions.add(action);
    _uiActions.add(action);
  }

  /// 挂接变更流并做一次启动对账；App 启动/回前台都调用它。
  Future<void> start() async {
    await _store.load();
    _changes ??= _missions.changes.listen((_) {
      unawaited(
        refresh().catchError((Object error) {
          reportFailure('提醒更新失败，请稍后重试：$error');
        }),
      );
    });
    await refresh();
  }

  /// 对账 + 全量重排（幂等，重启安全）。只整理提醒，不写任何业务事实。
  Future<void> refresh() {
    _refreshAgain = true;
    return _refreshing ??= _runRefresh().whenComplete(() => _refreshing = null);
  }

  Future<void> _runRefresh() async {
    do {
      _refreshAgain = false;
      final missions = await _missions.findAllDetails();
      for (final detail in missions) {
        await _syncOne(detail);
      }
    } while (_refreshAgain);
  }

  void reportFailure(String message) {
    _emit(
      NotificationUiAction(
        '',
        NotificationActionResult.actionFailed,
        message: message,
      ),
    );
  }

  Future<void> _cancelStartReminders(
    String missionId, {
    String? keepKey,
  }) async {
    final prefix = 'mission-$missionId-startReminder-';
    for (final entry in _store.notificationIds.entries) {
      if (entry.key.startsWith(prefix) && entry.key != keepKey) {
        await _dispatcher.cancel(entry.value);
      }
    }
  }

  Future<void> _syncOne(MissionDetail detail) async {
    final missionId = detail.mission.id;
    final started = detail.events.isNotEmpty;
    final ended = started && detail.events.last.type == ExecutionEventType.end;
    final cancelled = detail.phase == MissionPhase.cancelled;
    final scheduled = detail.schedule.fixedStartAt;
    await _cancelStartReminders(
      missionId,
      keepKey: !started && !cancelled && scheduled != null
          ? _key(missionId, detail.schedule.id)
          : null,
    );
    if (cancelled || ended) {
      // 已结束/已取消：开始提醒与执行通知一并清理（§7.2：END 后清理执行通知）。
      await _store.discard(missionId);
      final executionId = _store.notificationIds[_executionKey(missionId)];
      if (executionId != null) await _dispatcher.cancel(executionId);
      return;
    }
    if (started) {
      // 执行通知：每次执行事件提交（含 EXTEND）后刷新内容与 payload（§7.2），
      // 合法的新按钮携带最新 sequence；开始提醒就此清理（§7.1）。
      await _store.discard(missionId);
      await _dispatcher.show(await _executionNotification(detail));
      return;
    }
    // FLEXIBLE 不安排开始提醒（§7.1）。
    if (scheduled == null) {
      await _store.discard(missionId);
      return;
    }
    // 版本变化时旧延后与送达状态一并作废，杜绝旧延后用在新版本上。
    await _store.register(
      missionId: missionId,
      scheduleRevisionId: detail.schedule.id,
    );
    final pref = _store.preferenceOf(missionId);
    // 有有效 snoozedUntil 时保留它，不用原 fixedStartAt 覆盖（§7.1）。
    final effective = pref?.snoozedUntil ?? scheduled;
    final request = await _startReminder(detail, effective);
    if (effective.isAfter(_now())) {
      // 未来提醒：同幂等键覆盖调度；送达标记只影响补发，不影响重排。
      await _dispatcher.schedule(request);
      return;
    }
    // 过期：未送达补发一次并标记；已送达不反复弹出（§7.1）。
    if (pref?.delivered != true) {
      // cancel在Android也会删除可见通知，必须先撤旧调度再显示补发。
      await _dispatcher.cancel(request.notificationId);
      await _dispatcher.show(request);
      await _store.markDelivered(missionId);
    }
  }

  /// 延后 15 分钟（§7.2）：纯提醒偏好操作，不是改期、不是执行事件。
  Future<NotificationActionResult> snooze(MissionDetail detail) async {
    final until = _now().add(const Duration(minutes: 15));
    try {
      await _store.snooze(
        missionId: detail.mission.id,
        scheduleRevisionId: detail.schedule.id,
        until: until,
      );
    } on Object {
      return NotificationActionResult.preferenceSaveFailed;
    }
    await _dispatcher.schedule(await _startReminder(detail, until));
    return NotificationActionResult.handled;
  }

  /// 通知按钮与前台按钮走同一工作流（§7.2）。
  ///
  /// 开始/继续写事实前校验 expectedSequence：旧按钮只得到 stale 提示。
  /// 延后不碰事实；停止写 PAUSE 后交回 UI 打开 END 确认（取消确认保持 PAUSED）。
  Future<NotificationActionResult> handleAction(
    ReminderRequest request, {
    String? actionId,
  }) {
    final result = _actions.then(
      (_) => _handleAction(request, actionId: actionId),
    );
    _actions = result.then<void>((_) {}, onError: (Object _) {});
    return result;
  }

  Future<NotificationActionResult> _handleAction(
    ReminderRequest request, {
    String? actionId,
  }) async {
    NotificationActionResult result;
    String? message;
    try {
      result = await _act(request, actionId: actionId);
    } on ExecutionConflict catch (error) {
      result = NotificationActionResult.stale;
      message = error.message;
    } on Object catch (error) {
      result = NotificationActionResult.actionFailed;
      message = '通知操作未完成，请刷新后重试：$error';
    }
    // 旧按钮提示刷新、停止后打开 END 确认：都由 UI 接手，服务不直接导航。
    if (result == NotificationActionResult.stale ||
        result == NotificationActionResult.openEndConfirm ||
        result == NotificationActionResult.openMission ||
        result == NotificationActionResult.preferenceSaveFailed ||
        result == NotificationActionResult.actionFailed) {
      _emit(
        NotificationUiAction(
          request.missionId,
          result,
          message:
              message ??
              (result == NotificationActionResult.preferenceSaveFailed
                  ? '延后提醒保存失败，请重试'
                  : null),
        ),
      );
    }
    return result;
  }

  Future<NotificationActionResult> _act(
    ReminderRequest request, {
    String? actionId,
  }) async {
    final detail = await _missions.findDetail(missionId: request.missionId);
    if (detail == null) return NotificationActionResult.stale;
    // 装配层明确传空字符串表示点击正文；兼容已有应用服务调用的默认动作。
    final action =
        actionId ??
        switch (request.kind) {
          ReminderKind.startReminder => 'start',
          ReminderKind.executionRunning => 'stop',
          ReminderKind.executionPaused => 'resume',
        };
    if (action.isEmpty) return NotificationActionResult.openMission;
    final type = switch (action) {
      'start' => ExecutionEventType.start,
      'stop' => ExecutionEventType.pause,
      'resume' => ExecutionEventType.resume,
      _ => null,
    };
    final candidate =
        request.candidateEventIds[action == 'stop' ? 'pause' : action];
    // 已提交的同一候选动作直接结束，不再次打开END确认或提示过期。
    if (candidate != null &&
        detail.events.any(
          (event) =>
              event.id == candidate &&
              event.type == type &&
              event.sequence == request.expectedSequence + 1,
        )) {
      return NotificationActionResult.handled;
    }
    if (request.scheduleRevisionId != detail.schedule.id ||
        detail.phase == MissionPhase.cancelled) {
      return NotificationActionResult.stale;
    }
    if (request.expectedSequence != detail.lastSequence) {
      return NotificationActionResult.stale;
    }
    switch (action) {
      case 'snooze':
        if (request.kind != ReminderKind.startReminder ||
            detail.events.isNotEmpty) {
          return NotificationActionResult.stale;
        }
        return snooze(detail);
      case 'start':
        if (request.kind != ReminderKind.startReminder ||
            detail.phase != MissionPhase.notStarted) {
          return NotificationActionResult.stale;
        }
        await _missions.execute(
          _missions.prepareExecution(
            detail: detail,
            type: ExecutionEventType.start,
            commandId: request.candidateEventIds['start'],
          ),
        );
        return NotificationActionResult.handled;
      case 'resume':
        if (request.kind != ReminderKind.executionPaused ||
            detail.phase != MissionPhase.paused) {
          return NotificationActionResult.stale;
        }
        await _missions.execute(
          _missions.prepareExecution(
            detail: detail,
            type: ExecutionEventType.resume,
            commandId: request.candidateEventIds['resume'],
          ),
        );
        return NotificationActionResult.handled;
      case 'stop':
        if (request.kind != ReminderKind.executionRunning ||
            (detail.phase != MissionPhase.running &&
                detail.phase != MissionPhase.paused)) {
          return NotificationActionResult.stale;
        }
        // “停止”只在 RUNNING 时写 PAUSE；随后打开 END 确认由 UI 接手。
        if (detail.phase == MissionPhase.running) {
          await _missions.execute(
            _missions.prepareExecution(
              detail: detail,
              type: ExecutionEventType.pause,
              commandId: request.candidateEventIds['pause'],
            ),
          );
        }
        return NotificationActionResult.openEndConfirm;
      default:
        return NotificationActionResult.handled;
    }
  }

  Future<ReminderRequest> _startReminder(
    MissionDetail detail,
    DateTime at,
  ) async {
    final missionId = detail.mission.id;
    final key = _key(missionId, detail.schedule.id);
    final local = at.toLocal();
    return ReminderRequest(
      idempotencyKey: key,
      notificationId: await _store.notificationIdOf(key),
      missionId: missionId,
      scheduleRevisionId: detail.schedule.id,
      kind: ReminderKind.startReminder,
      title: '任务时间到了：${detail.mission.title}',
      body:
          '计划 ${local.hour.toString().padLeft(2, '0')}:'
          '${local.minute.toString().padLeft(2, '0')} 开始',
      expectedSequence: detail.lastSequence,
      candidateEventIds: {
        'start': 'notif-start-$missionId-${detail.schedule.id}',
      },
      scheduledFor: at,
    );
  }

  /// 执行通知：RUNNING 显示「停止」、PAUSED 显示「继续」（§7.2）。
  /// 稳定候选事件 id 绑定当前 sequence：重复回调幂等，旧按钮被拒绝。
  Future<ReminderRequest> _executionNotification(MissionDetail detail) async {
    final missionId = detail.mission.id;
    final running = detail.phase == MissionPhase.running;
    final sequence = detail.lastSequence;
    return ReminderRequest(
      idempotencyKey: _executionKey(missionId),
      notificationId: await _store.notificationIdOf(_executionKey(missionId)),
      missionId: missionId,
      scheduleRevisionId: detail.schedule.id,
      kind: running
          ? ReminderKind.executionRunning
          : ReminderKind.executionPaused,
      title: detail.mission.title,
      body: running ? '执行中，可点「停止」暂停并确认结束' : '已暂停，可点「继续」恢复执行',
      expectedSequence: sequence,
      candidateEventIds: {
        'pause': 'notif-pause-$missionId-$sequence',
        'resume': 'notif-resume-$missionId-$sequence',
      },
    );
  }

  String _key(String missionId, String scheduleRevisionId) =>
      'mission-$missionId-startReminder-$scheduleRevisionId';

  String _executionKey(String missionId) => 'mission-$missionId-execution';

  Future<void> dispose() async {
    await _changes?.cancel();
    _changes = null;
    await _actions;
    await _refreshing;
    await _uiActions.close();
  }
}

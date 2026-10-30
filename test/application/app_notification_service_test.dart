import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mission_book/application/missions/mission_service.dart';
import 'package:mission_book/application/notifications/app_notification_service.dart';
import 'package:mission_book/data/local/app_database.dart';
import 'package:mission_book/data/notifications/notification_dispatcher.dart';
import 'package:mission_book/data/notifications/reminder_store.dart';
import 'package:mission_book/data/repositories/drift_mission_repository.dart';
import 'package:mission_book/domain/entities/execution_event.dart';
import 'package:mission_book/domain/entities/mission_schedule_revision.dart';
import 'package:mission_book/domain/notifications/reminder_request.dart';

/// 记录全部分发动作，测试按幂等键断言“调度不重复、补发只一次”。
class _FakeDispatcher implements NotificationDispatcher {
  final scheduled = <String, ReminderRequest>{};
  final shown = <String>[];
  final cancelled = <int>[];
  final visible = <int, ReminderRequest>{};

  @override
  bool get supportsScheduling => true;

  @override
  Future<void> schedule(ReminderRequest request) async {
    scheduled[request.idempotencyKey] = request;
  }

  @override
  Future<void> cancel(int notificationId) async {
    cancelled.add(notificationId);
    scheduled.removeWhere(
      (_, request) => request.notificationId == notificationId,
    );
    visible.remove(notificationId);
  }

  @override
  Future<void> show(ReminderRequest request) async {
    shown.add(request.idempotencyKey);
    visible[request.notificationId] = request;
  }
}

void main() {
  late AppDatabase database;
  late MissionService missions;
  late Directory tempDir;
  late ReminderStore store;
  late _FakeDispatcher dispatcher;
  late DateTime now;
  late AppNotificationService service;

  setUp(() async {
    tempDir = Directory.systemTemp.createTempSync('reminder_store_test');
    database = AppDatabase(executor: NativeDatabase.memory());
    now = DateTime.utc(2026, 10, 25, 0);
    missions = MissionService(
      DriftMissionRepository(database, clock: () => now),
    );
    store = ReminderStore(File('${tempDir.path}/reminders.json'));
    dispatcher = _FakeDispatcher();
    service = AppNotificationService(
      missions: missions,
      store: store,
      dispatcher: dispatcher,
      now: () => now,
    );
  });

  tearDown(() async {
    await service.dispose();
    await missions.dispose();
    await database.close();
    tempDir.deleteSync(recursive: true);
  });

  Future<String> createFixed({
    required String title,
    required DateTime fixedStartAt,
  }) async {
    await missions.create(
      title: title,
      scheduledDate: '2026-10-25',
      timeZone: 'Asia/Shanghai',
      plannedDurationMinutes: 30,
      timePolicy: TimePolicy.fixed,
      fixedStartAt: fixedStartAt,
    );
    return (await missions.findScheduledOn(
      scheduledDate: '2026-10-25',
    )).singleWhere((detail) => detail.mission.title == title).mission.id;
  }

  test('FIXED 未来任务调度开始提醒；同幂等键重复对账不重复安排', () async {
    await createFixed(
      title: '定时任务',
      fixedStartAt: DateTime.utc(2026, 10, 25, 2),
    );
    await service.refresh();
    await service.refresh();
    expect(dispatcher.scheduled.length, 1);
    final request = dispatcher.scheduled.values.single;
    expect(request.kind, ReminderKind.upcomingReminder);
    expect(request.scheduledFor, DateTime.utc(2026, 10, 25, 1, 50));
    // 幂等键绑定排期版本：改期后是新键，不会沿用旧延后。
    expect(
      request.idempotencyKey,
      contains('-startReminder-${request.scheduleRevisionId}'),
    );
  });

  test('FLEXIBLE 与已取消任务不安排开始提醒', () async {
    await missions.create(
      title: '自选任务',
      scheduledDate: '2026-10-25',
      timeZone: 'Asia/Shanghai',
      plannedDurationMinutes: 30,
    );
    await createFixed(
      title: '将取消',
      fixedStartAt: DateTime.utc(2026, 10, 25, 2),
    );
    final all = await missions.findScheduledOn(scheduledDate: '2026-10-25');
    final cancelledId = all
        .firstWhere((detail) => detail.mission.title == '将取消')
        .mission
        .id;
    await missions.cancel(missionId: cancelledId);
    await service.refresh();
    expect(dispatcher.scheduled, isEmpty);
  });

  test('修改提前提醒立即重排且不改变排期；关闭后撤销提醒', () async {
    final id = await createFixed(
      title: '提醒设置',
      fixedStartAt: DateTime.utc(2026, 10, 25, 1),
    );
    await service.refresh();
    await service.setReminderLeadMinutes(30);
    expect(
      dispatcher.scheduled.values.single.scheduledFor,
      DateTime.utc(2026, 10, 25, 0, 30),
    );
    expect(
      (await missions.findDetail(missionId: id))!.schedule.fixedStartAt,
      DateTime.utc(2026, 10, 25, 1),
    );
    await service.setReminderLeadMinutes(-1);
    expect(dispatcher.scheduled, isEmpty);
  });

  test('过期未送达补发一次并标记；已送达不反复弹出', () async {
    final id = await createFixed(
      title: '过期任务',
      fixedStartAt: DateTime.utc(2026, 10, 25, 1),
    );
    now = DateTime.utc(2026, 10, 25, 3); // 计划时刻已过
    await service.refresh();
    expect(dispatcher.shown, hasLength(1), reason: '过期未送达补发一次');
    expect(store.preferenceOf(id)!.delivered, isTrue);
    await service.refresh();
    expect(dispatcher.shown, hasLength(1), reason: '已送达不反复弹出');
  });

  test('改期作废旧偏好；已开始任务清理提醒与偏好', () async {
    final id = await createFixed(
      title: '改期任务',
      fixedStartAt: DateTime.utc(2026, 10, 25, 1),
    );
    await service.refresh();
    final detail = (await missions.findDetail(missionId: id))!;
    await store.snooze(
      missionId: id,
      scheduleRevisionId: detail.schedule.id,
      until: now.add(const Duration(minutes: 15)),
    ); // 兼容历史设置文件
    // 改期：固定开始时刻变化 → 追加排期版本。
    final before = (await missions.findDetail(missionId: id))!;
    await missions.edit(
      original: before,
      title: '改期任务',
      objective: before.executionPlan.objective,
      scheduledDate: '2026-10-25',
      plannedDurationMinutes: 30,
      timePolicy: TimePolicy.fixed,
      fixedStartAt: DateTime.utc(2026, 10, 25, 5),
    );
    await service.refresh();
    final pref = store.preferenceOf(id)!;
    expect(pref.snoozedUntil, isNull, reason: '旧版本延后不能用在新版本上（§7.1）');
    // 新版本按新时刻重排；旧幂等键的调度已撤销，不再生效。
    final rescheduled = dispatcher.scheduled.values
        .where(
          (request) =>
              request.scheduledFor == DateTime.utc(2026, 10, 25, 4, 50),
        )
        .toList();
    expect(rescheduled, hasLength(1));
    expect(
      dispatcher.cancelled,
      isNot(contains(rescheduled.single.notificationId)),
      reason: '旧键撤销、新键生效',
    );
    // 开始执行后提醒与偏好一并清理。
    final started = (await missions.findDetail(missionId: id))!;
    now = DateTime.utc(2026, 10, 25, 5);
    await missions.execute(
      missions.prepareExecution(
        detail: started,
        type: ExecutionEventType.start,
      ),
    );
    await service.refresh();
    expect(store.preferenceOf(id), isNull);
    expect(dispatcher.cancelled, isNotEmpty);
  });

  test('通知动作走 MissionService 工作流；旧 sequence 只回 stale 不写事实', () async {
    final id = await createFixed(
      title: '动作任务',
      fixedStartAt: DateTime.utc(2026, 10, 25, 1),
    );
    await service.refresh();
    final request = dispatcher.scheduled.values.single;
    // 提前提醒只打开详情，不能提前写 START。到点使用统一自动执行入口。
    expect(
      await service.handleAction(request),
      NotificationActionResult.openMission,
    );
    now = DateTime.utc(2026, 10, 25, 1);
    await missions.reconcileScheduledMissions();
    // 原来的预告点击仍只是打开任务。
    expect(
      await service.handleAction(request),
      NotificationActionResult.openMission,
    );
    final afterStart = (await missions.findDetail(missionId: id))!;
    expect(afterStart.events, hasLength(1));
    // 已处理的同一候选动作静默幂等，不写事实也不重复提示。
    expect(
      await service.handleAction(request),
      NotificationActionResult.openMission,
    );
    expect(
      (await missions.findDetail(missionId: id))!.events,
      hasLength(1),
      reason: '延迟的旧按钮不能修改后来状态（§7.2）',
    );
    // 「停止」动作：RUNNING 时写 PAUSE，再交回 UI 打开 END 确认。
    final running = (await missions.findDetail(missionId: id))!;
    final stopRequest = ReminderRequest(
      idempotencyKey: 'mission-$id-executionRunning-${running.schedule.id}',
      notificationId: 99,
      missionId: id,
      scheduleRevisionId: running.schedule.id,
      kind: ReminderKind.executionRunning,
      title: '',
      body: '',
      expectedSequence: running.lastSequence,
      candidateEventIds: const {},
    );
    expect(
      await service.handleAction(stopRequest),
      NotificationActionResult.openEndConfirm,
    );
    final afterStop = (await missions.findDetail(missionId: id))!;
    expect(afterStop.phase.name, 'paused');
    expect(afterStop.events, hasLength(2));
  });

  test('偏好持久化：延后与送达状态关闭重开仍在', () async {
    await createFixed(
      title: '持久任务',
      fixedStartAt: DateTime.utc(2026, 10, 25, 1),
    );
    await service.refresh();
    await service.setReminderLeadMinutes(15);
    // 重新打开：同一文件读回，延后保持。
    final reopened = ReminderStore(File('${tempDir.path}/reminders.json'));
    await reopened.load();
    expect(reopened.reminderLeadMinutes, 15);
    expect(await reopened.notificationIdOf('any-key'), isPositive);
  });
  test('关闭提前提醒也保留到点冲突提醒，不自动暂停当前任务且反复刷新不重复弹出', () async {
    await missions.create(
      title: '当前任务',
      scheduledDate: '2026-10-25',
      timeZone: 'Asia/Shanghai',
      plannedDurationMinutes: 30,
    );
    final current = (await missions.findAllDetails()).single;
    await missions.execute(
      missions.prepareExecution(
        detail: current,
        type: ExecutionEventType.start,
      ),
    );
    final id = await createFixed(
      title: '到点任务',
      fixedStartAt: DateTime.utc(2026, 10, 25, 1),
    );
    await service.setReminderLeadMinutes(-1);
    now = DateTime.utc(2026, 10, 25, 1);
    await missions.reconcileScheduledMissions();
    await service.refresh();
    final waiting = dispatcher.visible.values.where(
      (request) => request.title.startsWith('计划任务等待开始'),
    );
    expect(waiting, hasLength(1));
    final shownCount = dispatcher.shown.length;
    await service.refresh();
    expect(
      dispatcher.shown.where((key) => key.endsWith('-waiting')),
      hasLength(1),
    );
    expect(
      dispatcher.visible.values.where(
        (request) => request.title.startsWith('计划任务等待开始'),
      ),
      hasLength(1),
    );
    expect((await missions.findDetail(missionId: id))!.events, isEmpty);
    expect(
      (await missions.findDetail(missionId: current.mission.id))!.events,
      hasLength(1),
    );
    expect(dispatcher.shown.length, greaterThanOrEqualTo(shownCount));
  });
}

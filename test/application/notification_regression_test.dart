import 'dart:io';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mission_book/application/missions/mission_service.dart';
import 'package:mission_book/application/notifications/app_notification_service.dart';
import 'package:mission_book/data/local/app_database.dart';
import 'package:mission_book/data/notifications/notification_dispatcher.dart';
import 'package:mission_book/data/notifications/reminder_store.dart';
import 'package:mission_book/data/repositories/drift_mission_repository.dart';
import 'package:mission_book/domain/entities/mission_schedule_revision.dart';
import 'package:mission_book/domain/entities/execution_event.dart';
import 'package:mission_book/domain/notifications/reminder_request.dart';

class StateDispatcher implements NotificationDispatcher {
  final scheduled = <int, ReminderRequest>{};
  final visible = <int, ReminderRequest>{};
  @override
  bool get supportsScheduling => true;
  @override
  Future<void> schedule(ReminderRequest request) async {
    scheduled[request.notificationId] = request;
  }

  @override
  Future<void> show(ReminderRequest request) async {
    visible[request.notificationId] = request;
  }

  @override
  Future<void> cancel(int id) async {
    scheduled.remove(id);
    visible.remove(id);
  }
}

void main() {
  late AppDatabase db;
  late MissionService missions;
  late Directory dir;
  late ReminderStore store;
  late StateDispatcher dispatcher;
  late AppNotificationService service;
  late DateTime now;
  setUp(() async {
    dir = await Directory.systemTemp.createTemp('mission-review-fixture-');
    db = AppDatabase(executor: NativeDatabase.memory());
    now = DateTime.utc(2026, 10, 25);
    missions = MissionService(
      DriftMissionRepository(db, clock: () => now),
      clock: () => now,
    );
    store = ReminderStore(File('${dir.path}/reminders.json'));
    dispatcher = StateDispatcher();
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
    await db.close();
    await dir.delete(recursive: true);
  });
  Future<String> create() async {
    await missions.create(
      title: 'review',
      scheduledDate: '2026-10-25',
      timeZone: 'Asia/Shanghai',
      plannedDurationMinutes: 30,
      timePolicy: TimePolicy.fixed,
      fixedStartAt: DateTime.utc(2026, 10, 25, 1),
    );
    return (await missions.findScheduledOn(
      scheduledDate: '2026-10-25',
    )).single.mission.id;
  }

  Future<void> reschedule(String id, {bool flexible = false}) async {
    final detail = (await missions.findDetail(missionId: id))!;
    await missions.edit(
      original: detail,
      title: detail.mission.title,
      objective: detail.executionPlan.objective,
      scheduledDate: '2026-10-25',
      plannedDurationMinutes: 30,
      timePolicy: flexible ? TimePolicy.flexible : TimePolicy.fixed,
      fixedStartAt: flexible ? null : DateTime.utc(2026, 10, 25, 5),
    );
  }

  test(
    'reschedule removes the previous revision pending notification',
    () async {
      final id = await create();
      await service.refresh();
      final oldId = dispatcher.scheduled.keys.single;
      await reschedule(id);
      await service.refresh();
      expect(dispatcher.scheduled.containsKey(oldId), isFalse);
    },
  );
  test('FIXED to FLEXIBLE removes the original reminder', () async {
    final id = await create();
    await service.refresh();
    await reschedule(id, flexible: true);
    await service.refresh();
    expect(dispatcher.scheduled, isEmpty);
  });
  test('overdue catch-up remains visible after refresh', () async {
    await create();
    now = DateTime.utc(2026, 10, 25, 3);
    await service.refresh();
    expect(dispatcher.visible.length, 1);
  });
  test('old schedule payload cannot start rescheduled mission', () async {
    final id = await create();
    await service.refresh();
    final oldRequest = dispatcher.scheduled.values.single;
    await reschedule(id);
    expect(
      await service.handleAction(oldRequest, actionId: 'start'),
      NotificationActionResult.stale,
    );
    expect((await missions.findDetail(missionId: id))!.events, isEmpty);
  });
  test(
    'allocated notification id survives restart without collision',
    () async {
      await create();
      await service.refresh();
      final allocated = dispatcher.scheduled.keys.single;
      final reopened = ReminderStore(store.file);
      await reopened.load();
      expect(
        await reopened.notificationIdOf('unrelated-new-key'),
        isNot(allocated),
      );
    },
  );
  test(
    'notification body opens task without writing execution facts',
    () async {
      final id = await create();
      await service.refresh();
      final request = dispatcher.scheduled.values.single;
      expect(
        await service.handleAction(request, actionId: ''),
        NotificationActionResult.openMission,
      );
      expect((await missions.findDetail(missionId: id))!.events, isEmpty);
      expect(
        service.takePendingUiActions().single.result,
        NotificationActionResult.openMission,
      );
    },
  );
  test(
    'legacy snooze action is stale and does not postpone automatic start',
    () async {
      final id = await create();
      await service.refresh();
      final request = dispatcher.scheduled.values.single;
      expect(
        await service.handleAction(request, actionId: 'snooze'),
        NotificationActionResult.stale,
      );
      expect(store.preferenceOf(id)!.snoozedUntil, isNull);
      expect((await missions.findDetail(missionId: id))!.events, isEmpty);
    },
  );
  test('执行摘要复用真实时间规则：暂停冻结、延长不恢复、继续累计、END撤销', () async {
    final id = await create();
    await service.refresh();
    now = DateTime.utc(2026, 10, 25, 1);
    await missions.startDueScheduledMissions();
    now = now.add(const Duration(seconds: 75));
    await service.refresh();
    final running = dispatcher.visible.values.single;
    expect(running.focusMilliseconds, 75000);
    expect(running.body, contains('专注 01:15'));
    expect(running.budgetMinutes, 30);
    Future<void> act(
      ExecutionEventType type, {
      int? minutes,
      UserReportedResult? report,
    }) async {
      final detail = (await missions.findDetail(missionId: id))!;
      await missions.execute(
        missions.prepareExecution(
          detail: detail,
          type: type,
          minutes: minutes,
          report: report,
        ),
      );
      await service.refresh();
    }

    await act(ExecutionEventType.pause);
    now = now.add(const Duration(minutes: 10));
    await act(ExecutionEventType.extend, minutes: 5);
    final paused = dispatcher.visible.values.single;
    expect(paused.kind, ReminderKind.executionPaused);
    expect(paused.focusMilliseconds, 75000);
    expect(paused.budgetMinutes, 35);
    expect(paused.notificationId, running.notificationId);
    expect(paused.expectedSequence, 3);
    await act(ExecutionEventType.resume);
    now = now.add(const Duration(seconds: 45));
    await service.refresh();
    expect(dispatcher.visible.values.single.focusMilliseconds, 120000);
    now = now.add(const Duration(hours: 1));
    await service.refresh();
    expect(dispatcher.visible.values.single.body, contains('专注 01:02:00'));
    final correctTime = now;
    now = now.subtract(const Duration(hours: 2));
    await service.refresh();
    expect(dispatcher.visible.values.single.clockBehind, isTrue);
    expect(dispatcher.visible.values.single.body, contains('请校时'));
    now = correctTime;
    await act(ExecutionEventType.end, report: UserReportedResult.completed);
    expect(dispatcher.visible, isEmpty);
  });

  test(
    'concurrent duplicate stop callback emits one confirmation and one PAUSE',
    () async {
      final id = await create();
      await service.refresh();
      now = DateTime.utc(2026, 10, 25, 1);
      await missions.startDueScheduledMissions();
      await service.refresh();
      final request = dispatcher.visible.values.single;
      final results = await Future.wait([
        service.handleAction(request, actionId: 'stop'),
        service.handleAction(request, actionId: 'stop'),
      ]);
      expect(results, [
        NotificationActionResult.openEndConfirm,
        NotificationActionResult.handled,
      ]);
      expect((await missions.findDetail(missionId: id))!.events, hasLength(2));
      expect(
        service.takePendingUiActions().where(
          (a) => a.result == NotificationActionResult.openEndConfirm,
        ),
        hasLength(1),
      );
    },
  );
}

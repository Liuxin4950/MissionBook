import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mission_book/application/missions/mission_service.dart';
import 'package:mission_book/application/missions/planned_mission_scheduler.dart';
import 'package:mission_book/application/notifications/execution_reminder.dart';
import 'package:mission_book/data/local/app_database.dart';
import 'package:mission_book/data/repositories/drift_mission_repository.dart';
import 'package:mission_book/domain/entities/execution_command.dart';
import 'package:mission_book/domain/entities/execution_event.dart';
import 'package:mission_book/domain/entities/mission.dart';
import 'package:mission_book/domain/entities/mission_detail.dart';
import 'package:mission_book/domain/entities/mission_phase.dart';
import 'package:mission_book/domain/entities/mission_schedule_revision.dart';
import 'package:mission_book/domain/notifications/reminder_request.dart';
import 'package:mission_book/domain/rules/execution_time_rules.dart';

void main() {
  final start = DateTime.utc(2026, 10, 30, 2);
  late DateTime now;
  late AppDatabase db;
  late MissionService service;

  setUp(() {
    now = start.subtract(const Duration(minutes: 10));
    db = AppDatabase(executor: NativeDatabase.memory());
    service = MissionService(
      DriftMissionRepository(db, clock: () => now),
      clock: () => now,
    );
  });
  tearDown(() async {
    await service.dispose();
    await db.close();
  });

  Future<MissionDetail> create({
    String title = '会议',
    DateTime? at,
    bool flexible = false,
    VerificationPolicy policy = VerificationPolicy.optionalEvidence,
  }) async {
    final request = service.prepareCreation(
      title: title,
      scheduledDate: '2026-10-30',
      timeZone: 'Asia/Shanghai',
      plannedDurationMinutes: 30,
      timePolicy: flexible ? TimePolicy.flexible : TimePolicy.fixed,
      fixedStartAt: flexible ? null : (at ?? start),
      verificationPolicy: policy,
    );
    await service.createPrepared(request);
    return (await service.findDetail(missionId: request.mission.id))!;
  }

  Future<MissionDetail> read(String id) async =>
      (await service.findDetail(missionId: id))!;
  Future<void> act(
    String id,
    ExecutionEventType type, {
    int? minutes,
    UserReportedResult? report,
    bool? submit,
  }) async {
    await service.execute(
      service.prepareExecution(
        detail: await read(id),
        type: type,
        minutes: minutes,
        report: report,
        submitOptionalEvidence: submit,
      ),
    );
  }

  test('退出五小时后恢复，只计到计划结束；待确认不产生完成或失败事实', () async {
    final task = await create();
    now = start;
    await service.reconcileScheduledMissions();
    now = start.add(const Duration(hours: 5));
    expect(await service.reconcileScheduledMissions(), [task.mission.id]);
    expect(await service.reconcileScheduledMissions(), isEmpty);
    final stopped = await read(task.mission.id);
    expect(stopped.phase, MissionPhase.reportPending);
    expect(stopped.events.map((e) => e.type), [
      ExecutionEventType.start,
      ExecutionEventType.stop,
    ]);
    expect(
      stopped.events.last.occurredAt,
      start.add(const Duration(minutes: 30)),
    );
    expect(stopped.endReportedCompleted, isFalse);
    expect(stopped.failures, isEmpty);
    final times = calculateExecutionTimes(stopped.events, now);
    expect(times.focus, const Duration(minutes: 30));
    expect(times.elapsed, const Duration(minutes: 30));
    expect((await service.findPlannedSnapshot()).nextEndAt, isNull);
    final reminder = executionReminder(stopped, 7, now: now);
    expect(reminder.kind, ReminderKind.executionStopped);
    expect(reminder.body, contains('待确认'));
    expect(reminder.candidateEventIds.containsKey('resume'), isFalse);

    await act(
      task.mission.id,
      ExecutionEventType.end,
      report: UserReportedResult.completed,
      submit: true,
    );
    final reported = await read(task.mission.id);
    expect(reported.phase, MissionPhase.evidencePending);
    expect(reported.events.last.occurredAt, now);
    expect(
      calculateExecutionTimes(reported.events, now).focus,
      const Duration(minutes: 30),
    );
    expect(
      calculateExecutionTimes(reported.events, now).elapsed,
      const Duration(minutes: 30),
    );
    await service.submitEvidence(
      service.prepareEvidenceSubmission(
        detail: reported,
        items: [service.createTextEvidence('会议纪要')],
      ),
    );
    expect((await read(task.mission.id)).phase, MissionPhase.closed);
  });

  test('执行中多次加时重排系统唤醒，原结束点不停止', () async {
    final task = await create();
    final alarms = <DateTime?>[];
    final scheduler = PlannedMissionScheduler(
      missions: service,
      now: () => now,
      scheduleInSystem: (at) async => alarms.add(at),
    );
    try {
      await scheduler.start();
      expect(alarms.last, start);
      now = start;
      await scheduler.refresh();
      expect(alarms.last, start.add(const Duration(minutes: 30)));
      now = start.add(const Duration(minutes: 20));
      await act(task.mission.id, ExecutionEventType.extend, minutes: 10);
      await act(task.mission.id, ExecutionEventType.extend, minutes: 5);
      await scheduler.refresh();
      expect(alarms.last, start.add(const Duration(minutes: 45)));
      now = start.add(const Duration(minutes: 30));
      await scheduler.refresh();
      expect((await read(task.mission.id)).phase, MissionPhase.running);
      now = start.add(const Duration(minutes: 45));
      await scheduler.refresh();
      expect((await read(task.mission.id)).phase, MissionPhase.reportPending);
      expect(alarms.last, isNull);
    } finally {
      await scheduler.dispose();
    }
  });

  test('暂停不顺延固定日程，暂停任务到点也进入待确认，等待不计入时长', () async {
    final task = await create();
    now = start;
    await service.reconcileScheduledMissions();
    now = start.add(const Duration(minutes: 10));
    await act(task.mission.id, ExecutionEventType.pause);
    now = start.add(const Duration(hours: 5));
    await service.reconcileScheduledMissions();
    final stopped = await read(task.mission.id);
    expect(stopped.phase, MissionPhase.reportPending);
    final times = calculateExecutionTimes(stopped.events, now);
    expect(times.focus, const Duration(minutes: 10));
    expect(times.paused, const Duration(minutes: 20));
    expect(times.elapsed, const Duration(minutes: 30));
    await act(
      task.mission.id,
      ExecutionEventType.end,
      report: UserReportedResult.notCompleted,
    );
    final reported = await read(task.mission.id);
    expect(reported.phase, MissionPhase.closed);
    expect(reported.failures, hasLength(1));
  });

  test('迟到加时或继续被拒绝，独立提交的停止事实仍保留', () async {
    final task = await create();
    now = start;
    await service.reconcileScheduledMissions();
    final old = service.prepareExecution(
      detail: await read(task.mission.id),
      type: ExecutionEventType.extend,
      minutes: 10,
    );
    now = start.add(const Duration(minutes: 30));
    await expectLater(service.execute(old), throwsA(isA<ExecutionConflict>()));
    expect((await read(task.mission.id)).phase, MissionPhase.reportPending);
    await expectLater(
      act(task.mission.id, ExecutionEventType.resume),
      throwsArgumentError,
    );
    await expectLater(
      act(task.mission.id, ExecutionEventType.extend, minutes: 10),
      throwsArgumentError,
    );
    expect((await read(task.mission.id)).events, hasLength(2));
  });

  test('相邻日程先停止前一个再开始后一个；不要求先填写报告', () async {
    final first = await create();
    final second = await create(
      title: '下一场',
      at: start.add(const Duration(minutes: 30)),
    );
    now = start;
    await service.reconcileScheduledMissions();
    now = start.add(const Duration(minutes: 30));
    expect(await service.reconcileScheduledMissions(), [
      first.mission.id,
      second.mission.id,
    ]);
    expect((await read(first.mission.id)).phase, MissionPhase.reportPending);
    expect((await read(second.mission.id)).phase, MissionPhase.running);
  });

  test('延迟开始仍按固定结束点停止，不给延迟唤醒多算时间', () async {
    final task = await create();
    now = start.add(const Duration(minutes: 7));
    await service.reconcileScheduledMissions();
    now = start.add(const Duration(hours: 5));
    await service.reconcileScheduledMissions();
    expect(
      calculateExecutionTimes((await read(task.mission.id)).events, now).focus,
      const Duration(minutes: 23),
    );
  });

  test('自选时间继续沿用手动结束，错过完整时段后手动开始获得完整预算', () async {
    final flexible = await create(flexible: true);
    await act(flexible.mission.id, ExecutionEventType.start);
    now = start.add(const Duration(hours: 5));
    await service.reconcileScheduledMissions();
    expect((await read(flexible.mission.id)).phase, MissionPhase.running);
    await act(flexible.mission.id, ExecutionEventType.pause);
    final missed = await create(title: '补做');
    await act(missed.mission.id, ExecutionEventType.start);
    expect(
      (await service.findPlannedSnapshot()).nextEndAt,
      now.add(const Duration(minutes: 30)),
    );
  });

  test('停止写入失败回滚；成功后回拨不会重启或重复停止', () async {
    final task = await create();
    now = start;
    await service.reconcileScheduledMissions();
    now = start.add(const Duration(minutes: 30));
    await db.customStatement(
      "CREATE TRIGGER reject_stop BEFORE INSERT ON execution_events WHEN NEW.type='STOP' BEGIN SELECT RAISE(ABORT, 'test failure'); END",
    );
    await expectLater(
      service.reconcileScheduledMissions(),
      throwsA(isA<Exception>()),
    );
    expect((await read(task.mission.id)).events, hasLength(1));
    await db.customStatement('DROP TRIGGER reject_stop');
    await service.reconcileScheduledMissions();
    now = start.add(const Duration(minutes: 5));
    await service.reconcileScheduledMissions();
    expect((await read(task.mission.id)).events, hasLength(2));
    expect((await read(task.mission.id)).phase, MissionPhase.reportPending);
  });

  testWidgets('前台真实到点唤醒自动停止，不依赖手动刷新', (tester) async {
    final task = await create();
    now = start;
    final scheduler = PlannedMissionScheduler(
      missions: service,
      now: () => now,
    );
    try {
      await scheduler.refresh();
      now = start.add(const Duration(minutes: 30));
      await tester.pump(const Duration(minutes: 30));
      await tester.runAsync(() async {
        for (var attempt = 0; attempt < 100; attempt++) {
          final phase = (await read(task.mission.id)).phase;
          if (phase == MissionPhase.reportPending) {
            return;
          }
          await Future<void>.delayed(Duration.zero);
        }
      });
      expect((await read(task.mission.id)).phase, MissionPhase.reportPending);
    } finally {
      await scheduler.dispose();
    }
  });

  test('加时与到点调度竞争，最终停止时刻取决于加时是否先成功', () async {
    final task = await create();
    now = start;
    await service.reconcileScheduledMissions();
    final extend = service.prepareExecution(
      detail: await read(task.mission.id),
      type: ExecutionEventType.extend,
      minutes: 10,
    );
    now = start.add(const Duration(minutes: 30));
    final results = await Future.wait<Object?>([
      service
          .execute(extend)
          .then<Object?>((e) => e, onError: (Object error) => error),
      service.reconcileScheduledMissions(),
    ]);
    expect(results.first, isA<ExecutionConflict>());
    final stopped = await read(task.mission.id);
    expect(
      stopped.events.where((e) => e.type == ExecutionEventType.stop),
      hasLength(1),
    );
    expect(
      stopped.events.where((e) => e.type == ExecutionEventType.extend),
      isEmpty,
    );
    expect(stopped.events.last.occurredAt, now);
  });

  test('查询期间跨过结束边界会立即再次对账，不漏掉停止', () async {
    final task = await create();
    now = start;
    await service.reconcileScheduledMissions();
    now = start
        .add(const Duration(minutes: 30))
        .subtract(const Duration(milliseconds: 1));
    final scheduler = PlannedMissionScheduler(
      missions: service,
      now: () {
        now = start.add(const Duration(minutes: 30));
        return now;
      },
    );
    try {
      await scheduler.refresh();
      expect((await read(task.mission.id)).phase, MissionPhase.reportPending);
    } finally {
      await scheduler.dispose();
    }
  });

  test('文件库关闭重开以及两个连接重复唤醒只保存一次停止', () async {
    final dir = Directory.systemTemp.createTempSync('scheduled-end-');
    final file = File('${dir.path}/test.sqlite');
    final first = AppDatabase(executor: NativeDatabase(file));
    final one = MissionService(
      DriftMissionRepository(first, clock: () => now),
      clock: () => now,
    );
    late String id;
    try {
      final request = one.prepareCreation(
        title: '会议',
        scheduledDate: '2026-10-30',
        timeZone: 'Asia/Shanghai',
        plannedDurationMinutes: 30,
        timePolicy: TimePolicy.fixed,
        fixedStartAt: start,
      );
      id = request.mission.id;
      await one.createPrepared(request);
      now = start;
      await one.reconcileScheduledMissions();
    } finally {
      await one.dispose();
      await first.close();
    }
    final second = AppDatabase(
      executor: NativeDatabase.createInBackground(file),
    );
    final third = AppDatabase(
      executor: NativeDatabase.createInBackground(file),
    );
    final two = DriftMissionRepository(second, clock: () => now);
    final three = DriftMissionRepository(third, clock: () => now);
    try {
      await two.findDetail(id);
      await three.findDetail(id);
      now = start.add(const Duration(hours: 5));
      await Future.wait([
        two.reconcileScheduledMissions(),
        three.reconcileScheduledMissions(),
      ]);
      expect((await two.findDetail(id))!.events, hasLength(2));
      expect(
        calculateExecutionTimes(
          (await three.findDetail(id))!.events,
          now,
        ).focus,
        const Duration(minutes: 30),
      );
    } finally {
      await second.close();
      await third.close();
      await dir.delete(recursive: true);
    }
  });
}

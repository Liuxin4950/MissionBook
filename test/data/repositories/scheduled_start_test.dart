import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mission_book/application/missions/mission_service.dart';
import 'package:mission_book/application/missions/planned_mission_scheduler.dart';
import 'package:mission_book/data/local/app_database.dart';
import 'package:mission_book/data/repositories/drift_mission_repository.dart';
import 'package:mission_book/domain/entities/execution_event.dart';
import 'package:mission_book/domain/entities/mission_detail.dart';
import 'package:mission_book/domain/entities/mission_phase.dart';
import 'package:mission_book/domain/entities/mission_schedule_revision.dart';
import 'package:mission_book/domain/rules/execution_time_rules.dart';

class _SlowScheduledRead extends DriftMissionRepository {
  _SlowScheduledRead(super.database, {required super.clock});
  void Function()? afterRead;

  @override
  Future<MissionDetail?> findDetail(String missionId) async {
    final result = await super.findDetail(missionId);
    afterRead?.call();
    return result;
  }
}

void main() {
  late AppDatabase database;
  late MissionService missions;
  late DateTime now;
  final plannedAt = DateTime.utc(2026, 10, 26, 2);

  setUp(() {
    now = plannedAt.subtract(const Duration(minutes: 30));
    database = AppDatabase(executor: NativeDatabase.memory());
    missions = MissionService(
      DriftMissionRepository(database, clock: () => now),
      clock: () => now,
    );
  });
  tearDown(() async {
    await missions.dispose();
    await database.close();
  });

  Future<MissionDetail> create({
    String title = '计划任务',
    DateTime? at,
    bool flexible = false,
  }) async {
    await missions.create(
      title: title,
      scheduledDate: '2026-10-26',
      timeZone: 'Asia/Shanghai',
      plannedDurationMinutes: 30,
      timePolicy: flexible ? TimePolicy.flexible : TimePolicy.fixed,
      fixedStartAt: flexible ? null : (at ?? plannedAt),
    );
    return (await missions.findAllDetails()).singleWhere(
      (item) => item.mission.title == title,
    );
  }

  test('到点前可改期且不能提前开始；旧时刻无效，新时刻只开始一次', () async {
    final original = await create();
    await expectLater(
      missions.execute(
        missions.prepareExecution(
          detail: original,
          type: ExecutionEventType.start,
        ),
      ),
      throwsA(isA<Exception>()),
    );
    await missions.edit(
      original: original,
      title: original.mission.title,
      objective: original.executionPlan.objective,
      scheduledDate: '2026-10-26',
      plannedDurationMinutes: 30,
      timePolicy: TimePolicy.fixed,
      fixedStartAt: plannedAt.add(const Duration(minutes: 10)),
    );
    now = plannedAt;
    expect(await missions.startDueScheduledMissions(), isEmpty);
    now = plannedAt.add(const Duration(minutes: 10));
    expect(await missions.startDueScheduledMissions(), [original.mission.id]);
    expect(await missions.startDueScheduledMissions(), isEmpty);
    final detail = (await missions.findDetail(missionId: original.mission.id))!;
    expect(detail.phase, MissionPhase.running);
    expect(detail.events.single.scheduleRevisionId, detail.schedule.id);
    expect(detail.events.single.occurredAt, now);
    expect(detail.events.single.sequence, 1);
    await expectLater(
      missions.edit(
        original: original,
        title: '开始后不能改',
        timePolicy: TimePolicy.flexible,
        objective: '目标',
        scheduledDate: '2026-10-26',
        plannedDurationMinutes: 30,
      ),
      throwsA(isA<MissionEditConflict>()),
    );
  });

  test('延迟唤醒只从真实开始时刻计时；回拨不会提前写 START', () async {
    final detail = await create();
    now = plannedAt.subtract(const Duration(milliseconds: 1));
    expect(await missions.startDueScheduledMissions(), isEmpty);
    now = plannedAt.add(const Duration(minutes: 3));
    await missions.startDueScheduledMissions();
    final started = (await missions.findDetail(missionId: detail.mission.id))!;
    expect(started.events.single.occurredAt, now);
    expect(calculateExecutionTimes(started.events, now).focus, Duration.zero);
  });

  test('错过完整时段、自选时间、已取消的任务不被自动开始', () async {
    final missed = await create(title: '错过时段');
    final cancelled = await create(title: '取消任务');
    await create(title: '自选任务', flexible: true);
    await missions.cancel(missionId: cancelled.mission.id);
    now = plannedAt.add(const Duration(minutes: 30));
    expect(await missions.startDueScheduledMissions(), isEmpty);
    expect(
      (await missions.findDetail(missionId: missed.mission.id))!.events,
      isEmpty,
    );
  });

  test('查询期间跨过计划结束边界，不再自动写START，仍可手动开始', () async {
    final detail = await create();
    final repository = _SlowScheduledRead(database, clock: () => now);
    now = plannedAt
        .add(const Duration(minutes: 30))
        .subtract(const Duration(milliseconds: 1));
    repository.afterRead = () =>
        now = plannedAt.add(const Duration(minutes: 30));
    expect(await repository.startDueScheduledMissions(), isEmpty);
    final missed = (await missions.findDetail(missionId: detail.mission.id))!;
    expect(missed.events, isEmpty);
    await missions.execute(
      missions.prepareExecution(detail: missed, type: ExecutionEventType.start),
    );
    expect(
      (await missions.findDetail(
        missionId: detail.mission.id,
      ))!.events.single.occurredAt,
      now,
    );
  });

  test('已有执行中的任务时，计划任务到点不会暂停或挤走它', () async {
    final current = await create(title: '正在处理', flexible: true);
    await missions.execute(
      missions.prepareExecution(
        detail: current,
        type: ExecutionEventType.start,
      ),
    );
    final planned = await create();
    now = plannedAt;
    expect(await missions.startDueScheduledMissions(), isEmpty);
    expect(
      (await missions.findDetail(missionId: planned.mission.id))!.events,
      isEmpty,
    );
    final retained = (await missions.findDetail(
      missionId: current.mission.id,
    ))!;
    expect(retained.phase, MissionPhase.running);
    expect(retained.events, hasLength(1));
  });

  test('自动开始写入失败完整回滚，重试后只保留一次START', () async {
    final detail = await create();
    now = plannedAt;
    await database.customStatement(
      "CREATE TRIGGER reject_scheduled_start BEFORE INSERT ON execution_events WHEN NEW.type = 'START' BEGIN SELECT RAISE(ABORT, 'test failure'); END",
    );
    await expectLater(
      missions.startDueScheduledMissions(),
      throwsA(isA<Exception>()),
    );
    expect(
      (await missions.findDetail(missionId: detail.mission.id))!.events,
      isEmpty,
    );
    await database.customStatement('DROP TRIGGER reject_scheduled_start');
    await missions.startDueScheduledMissions();
    expect(
      (await missions.findDetail(missionId: detail.mission.id))!.events,
      hasLength(1),
    );
  });

  test('自动开始与取消竞争不会同时保存START和取消', () async {
    final detail = await create();
    now = plannedAt;
    Future<void> cancel() async {
      try {
        await missions.cancel(missionId: detail.mission.id);
      } catch (_) {}
    }

    await Future.wait([missions.startDueScheduledMissions(), cancel()]);
    final latest = (await missions.findDetail(missionId: detail.mission.id))!;
    expect(
      latest.phase == MissionPhase.running ||
          latest.phase == MissionPhase.cancelled,
      isTrue,
    );
    expect(
      latest.events.isNotEmpty && latest.mission.cancelledAt != null,
      isFalse,
    );
  });

  test('重读期间刚好到点也会再次执行事务，不会漏掉系统唤醒', () async {
    final detail = await create();
    now = plannedAt.subtract(const Duration(milliseconds: 1));
    final scheduler = PlannedMissionScheduler(
      missions: missions,
      now: () {
        now = plannedAt; // 模拟查询结束时刚好跨过开始边界。
        return now;
      },
    );
    await scheduler.start();
    expect(
      (await missions.findDetail(missionId: detail.mission.id))!.phase,
      MissionPhase.running,
    );
    await scheduler.dispose();
  });

  test('前台调度跟随改期和取消重排下一次系统唤醒，停止后无残留计时', () async {
    final detail = await create();
    final alarms = <DateTime?>[];
    final scheduler = PlannedMissionScheduler(
      missions: missions,
      now: () => now,
      scheduleInSystem: (at) async => alarms.add(at),
    );
    await scheduler.start();
    expect(alarms.last, plannedAt);
    await missions.cancel(missionId: detail.mission.id);
    await scheduler.refresh();
    expect(alarms.last, isNull);
    await scheduler.dispose();
  });

  testWidgets('系统调度失败不丢掉本地到点唤醒，重试计时在释放时清理', (tester) async {
    final detail = await create();
    now = plannedAt.subtract(const Duration(seconds: 1));
    final errors = <Object>[];
    final scheduler = PlannedMissionScheduler(
      missions: missions,
      now: () => now,
      scheduleInSystem: (_) async => throw StateError('模拟系统提醒调度失败'),
      onError: errors.add,
    );
    try {
      await scheduler.refreshSafely();
      expect(errors, hasLength(1));
      now = plannedAt;
      await tester.pump(const Duration(seconds: 1));
      // 等待此次事务查询完成，不主动调用调度器，验证原有到点唤醒没有丢失。
      await tester.runAsync(() async {
        for (var i = 0; i < 100; i++) {
          final latest = (await missions.findDetail(
            missionId: detail.mission.id,
          ))!;
          if (latest.events.isNotEmpty) return;
          await Future<void>.delayed(Duration.zero);
        }
      });
      expect(
        (await missions.findDetail(missionId: detail.mission.id))!.events,
        hasLength(1),
      );
    } finally {
      await scheduler.dispose();
    }
  });

  test('多个同刻任务稳定选一个；两个文件连接重复唤醒与重开不重复 START', () async {
    final directory = Directory.systemTemp.createTempSync('planned-start-race');
    final file = File('${directory.path}/race.sqlite');
    final first = AppDatabase(executor: NativeDatabase(file));
    final second = AppDatabase(executor: NativeDatabase(file));
    final one = MissionService(
      DriftMissionRepository(first, clock: () => now),
      clock: () => now,
    );
    final two = MissionService(
      DriftMissionRepository(second, clock: () => now),
      clock: () => now,
    );
    try {
      for (final title in ['一', '二']) {
        await one.create(
          title: title,
          scheduledDate: '2026-10-26',
          timeZone: 'Asia/Shanghai',
          plannedDurationMinutes: 30,
          timePolicy: TimePolicy.fixed,
          fixedStartAt: plannedAt,
        );
      }
      await two.findAllDetails(); // 两连接都完成开库，随后竞争写事务。
      now = plannedAt;
      Future<void> attempt(MissionService service) async {
        try {
          await service.startDueScheduledMissions();
        } catch (_) {
          // SQLite BUSY 允许稍后重试；不能留下半条事实或第二个 RUNNING。
        }
      }

      await Future.wait([attempt(one), attempt(two)]);
      await one.startDueScheduledMissions();
      final details = await one.findAllDetails();
      expect(
        details.where((item) => item.phase == MissionPhase.running),
        hasLength(1),
      );
      expect(
        details.fold<int>(0, (count, detail) => count + detail.events.length),
        1,
      );
    } finally {
      await one.dispose();
      await two.dispose();
      await first.close();
      await second.close();
    }
    final reopened = AppDatabase(executor: NativeDatabase(file));
    try {
      final repo = DriftMissionRepository(reopened, clock: () => now);
      expect(await repo.startDueScheduledMissions(), isEmpty);
      expect((await repo.findActive()).single.events, hasLength(1));
    } finally {
      await reopened.close();
      await directory.delete(recursive: true);
    }
  });
}

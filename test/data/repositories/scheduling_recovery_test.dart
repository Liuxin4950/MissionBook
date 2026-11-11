import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mission_book/application/missions/mission_service.dart';
import 'package:mission_book/data/local/app_database.dart';
import 'package:mission_book/data/repositories/drift_mission_repository.dart';
import 'package:mission_book/domain/entities/execution_event.dart';
import 'package:mission_book/domain/entities/mission_detail.dart';
import 'package:mission_book/domain/entities/mission_phase.dart';
import 'package:mission_book/domain/entities/mission_schedule_revision.dart';
import 'package:mission_book/domain/entities/user_execution_report.dart';

void main() {
  final start = DateTime.utc(2026, 11, 11, 2);
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
  Future<MissionDetail> create(String title, DateTime at) async {
    final request = service.prepareCreation(
      title: title,
      scheduledDate: '2026-11-11',
      timeZone: 'Asia/Shanghai',
      plannedDurationMinutes: 30,
      timePolicy: TimePolicy.fixed,
      fixedStartAt: at,
    );
    await service.createPrepared(request);
    return (await service.findDetail(missionId: request.mission.id))!;
  }

  Future<MissionDetail> read(String id) async =>
      (await service.findDetail(missionId: id))!;
  Future<void> act(String id, ExecutionEventType type) async {
    await service.execute(
      service.prepareExecution(detail: await read(id), type: type),
    );
  }

  test('补记 END 固定任务不再参与开始候选，也不阻挡后续有效任务', () async {
    final done = await create('已线下完成', start);
    final next = await create('仍需开始', start);
    now = start;
    await service.reportExecution(
      UserExecutionReport(
        id: 'report',
        missionId: done.mission.id,
        occurrenceDate: '2026-11-11',
        timeZoneId: 'Asia/Shanghai',
        basis: '已线下完成',
      ),
      expectedSequence: 0,
      scheduleId: done.schedule.id,
      result: UserReportedResult.completed,
    );
    expect((await read(done.mission.id)).events.single.isRetrospective, isTrue);
    expect(await service.reconcileScheduledMissions(), [next.mission.id]);
    expect(
      (await read(done.mission.id)).events.single.type,
      ExecutionEventType.end,
    );
    expect((await read(next.mission.id)).phase, MissionPhase.running);
    expect((await service.findPlannedSnapshot()).candidates, isEmpty);
  });
  test('后一个 START 写入失败，先前到期 STOP 保留并通知页面，重试不重复停止', () async {
    final first = await create('先停止', start);
    final second = await create('后开始', start.add(const Duration(minutes: 30)));
    now = start;
    await act(first.mission.id, ExecutionEventType.start);
    await db.customStatement(
      "CREATE TRIGGER reject_start BEFORE INSERT ON execution_events WHEN NEW.type='START' AND NEW.mission_id='${second.mission.id}' BEGIN SELECT RAISE(ABORT, 'injected failure'); END",
    );
    now = start.add(const Duration(minutes: 35));
    var notifications = 0;
    final subscription = service.changes.listen((_) => notifications++);
    await expectLater(
      service.reconcileScheduledMissions(),
      throwsA(isA<Exception>()),
    );
    await Future<void>.delayed(Duration.zero);
    expect(notifications, greaterThan(0));
    expect((await read(first.mission.id)).phase, MissionPhase.reportPending);
    expect((await read(first.mission.id)).events.map((e) => e.type), [
      ExecutionEventType.start,
      ExecutionEventType.stop,
    ]);
    expect((await read(second.mission.id)).events, isEmpty);
    await db.customStatement('DROP TRIGGER reject_start');
    expect(await service.reconcileScheduledMissions(), [second.mission.id]);
    expect((await read(first.mission.id)).events, hasLength(2));
    await subscription.cancel();
  });
  test('批量到期的暂停与执行任务全部 STOP，再开始相邻任务', () async {
    final first = await create('第一项', start);
    final second = await create('第二项', start);
    final next = await create('下一项', start.add(const Duration(minutes: 30)));
    now = start;
    await act(first.mission.id, ExecutionEventType.start);
    await act(first.mission.id, ExecutionEventType.pause);
    await act(second.mission.id, ExecutionEventType.start);
    now = start.add(const Duration(minutes: 30));
    expect(
      await service.reconcileScheduledMissions(),
      unorderedEquals([first.mission.id, second.mission.id, next.mission.id]),
    );
    expect((await read(first.mission.id)).phase, MissionPhase.reportPending);
    expect((await read(second.mission.id)).phase, MissionPhase.reportPending);
    expect((await read(next.mission.id)).phase, MissionPhase.running);
  });

  test('编辑版本时间取事务时钟，旧提案时间和回拨不使已提交版本倒退', () async {
    final original = await create('编辑时间', start);
    final proposal = MissionScheduleRevision(
      id: 'rescheduled',
      missionId: original.mission.id,
      revisionNumber: 2,
      scheduledDate: original.schedule.scheduledDate,
      timeZone: original.schedule.timeZone,
      plannedDurationMinutes: 45,
      timePolicy: TimePolicy.fixed,
      fixedStartAt: start,
      changedAt: now,
    );
    now = now.add(const Duration(minutes: 5));
    final repository = DriftMissionRepository(db, clock: () => now);
    await repository.edit(
      original: original,
      title: '事务时钟',
      objective: original.executionPlan.objective,
      schedule: proposal,
    );
    final edited = await read(original.mission.id);
    expect(edited.mission.updatedAt, now);
    now = now.subtract(const Duration(minutes: 20));
    await repository.edit(
      original: edited,
      title: '回拨后编辑',
      objective: edited.executionPlan.objective,
      schedule: edited.schedule,
    );
    expect(
      (await read(original.mission.id)).mission.updatedAt,
      edited.mission.updatedAt,
    );
  });

  test('详情阶段由不可变事实计算，调用方修改原列表不污染已读取的阶段', () async {
    final detail = await create('不可变快照', start);
    final events = <ExecutionEvent>[];
    final snapshot = MissionDetail(
      mission: detail.mission,
      schedule: detail.schedule,
      executionPlan: detail.executionPlan,
      events: events,
    );
    events.add(
      ExecutionEvent(
        id: 'external',
        missionId: detail.mission.id,
        sequence: 1,
        type: ExecutionEventType.start,
        occurredAt: start,
        scheduleRevisionId: detail.schedule.id,
      ),
    );
    expect(snapshot.events, isEmpty);
    expect(snapshot.phase, MissionPhase.notStarted);
    expect(() => snapshot.events.add(events.single), throwsUnsupportedError);
  });

  test('报告保存后时钟回拨，新时间更正继续替代当前尾项而非最大时间戳', () async {
    final detail = await create('回拨后更正', start);
    now = start;
    await service.reportExecution(
      UserExecutionReport(
        id: 'first',
        missionId: detail.mission.id,
        occurrenceDate: '2026-11-11',
        timeZoneId: 'Asia/Shanghai',
        basis: '线下完成',
      ),
      expectedSequence: 0,
      scheduleId: detail.schedule.id,
      result: UserReportedResult.completed,
    );
    now = start.subtract(const Duration(minutes: 5));
    for (final item in [('second', 'first'), ('third', 'second')]) {
      final current = await read(detail.mission.id);
      await service.reportExecution(
        UserExecutionReport(
          id: item.$1,
          missionId: detail.mission.id,
          occurrenceDate: '2026-11-11',
          timeZoneId: 'Asia/Shanghai',
          basis: '继续更正',
          supersedesId: item.$2,
        ),
        expectedSequence: current.lastSequence,
        scheduleId: current.schedule.id,
      );
      now = now.add(const Duration(minutes: 1));
    }
    expect((await read(detail.mission.id)).effectiveUserReport!.id, 'third');
    expect(
      (await service.findAllDetails()).single.effectiveUserReport!.id,
      'third',
    );
  });
}

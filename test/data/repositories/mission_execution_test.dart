import 'dart:io';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mission_book/application/missions/mission_service.dart';
import 'package:mission_book/data/local/app_database.dart';
import 'package:mission_book/data/repositories/drift_mission_repository.dart';
import 'package:mission_book/domain/entities/execution_command.dart';
import 'package:mission_book/domain/entities/execution_event.dart';
import 'package:mission_book/domain/entities/mission_phase.dart';
import 'package:mission_book/domain/entities/mission.dart';
import 'package:mission_book/domain/rules/execution_time_rules.dart';
import 'mission_cancellation_test.dart' show seedMission;

void main() {
  late AppDatabase database;
  late DriftMissionRepository repository;
  late MissionService service;
  late DateTime now;
  setUp(() async {
    now = DateTime.utc(2026, 10, 23, 6, 20);
    database = AppDatabase(executor: NativeDatabase.memory());
    repository = DriftMissionRepository(database, clock: () => now);
    service = MissionService(repository);
    await seedMission(repository, 'a');
    await seedMission(repository, 'b');
  });
  tearDown(() async {
    await service.dispose();
    await database.close();
  });

  Future<ExecutionCommand> command(
    ExecutionEventType type, {
    String mission = 'a',
    int? minutes,
    UserReportedResult? report,
    String? reason,
    String? category,
    String? text,
  }) async {
    final detail = (await repository.findDetail(mission))!;
    return service.prepareExecution(
      detail: detail,
      type: type,
      minutes: minutes,
      report: report,
      reason: reason,
      userReasonCategory: category,
      userReasonText: text,
    );
  }

  Future<void> act(
    ExecutionEventType type, {
    String mission = 'a',
    int? minutes,
    UserReportedResult? report,
  }) async {
    await service.execute(
      await command(type, mission: mission, minutes: minutes, report: report),
    );
  }

  test('收到开始通知后能重读START；详情与日期列表使用相同事实显示运行', () async {
    final start = await command(ExecutionEventType.start);
    // 先登记监听，再开始；通知不带任务数据，监听者自己按任务编号重读。
    final notifiedDetail = service.changes
        .asyncMap((_) => service.findDetail(missionId: 'a'))
        .first;

    final saved = await service.execute(start);
    final detail = (await notifiedDetail)!;
    final scheduled = (await service.findScheduledOn(
      scheduledDate: detail.schedule.scheduledDate,
    )).singleWhere((item) => item.mission.id == 'a');

    expect(service.changeRevision, 1);
    expect(detail.phase, MissionPhase.running);
    expect(detail.events.single.id, saved.id);
    expect(detail.lastSequence, 1);
    expect(detail.events.single.scheduleRevisionId, detail.schedule.id);
    expect(scheduled.phase, detail.phase);
    expect(scheduled.events.single.id, saved.id);
  });

  test('START插入失败整体回滚，不发刷新通知，不增加刷新计数；原命令可重试', () async {
    final start = await command(ExecutionEventType.start);
    var notificationCount = 0;
    final subscription = service.changes.listen((_) => notificationCount++);
    addTearDown(subscription.cancel);
    await database.customStatement(
      "CREATE TRIGGER fail_start BEFORE INSERT ON execution_events WHEN NEW.type = 'START' BEGIN SELECT RAISE(ABORT, '模拟开始写入失败'); END",
    );

    await expectLater(service.execute(start), throwsA(isA<SqliteException>()));
    final detail = (await service.findDetail(missionId: 'a'))!;
    // broadcast 的回调异步投递，给本轮通知一次处理机会再断言“没有收到”。
    await Future<void>.delayed(Duration.zero);
    expect(notificationCount, 0);
    expect(service.changeRevision, 0);
    expect(detail.events, isEmpty);
    expect(detail.phase, MissionPhase.notStarted);
    expect(await service.findActive(), isEmpty);

    await database.customStatement('DROP TRIGGER fail_start');
    final notified = service.changes.first;
    final saved = await service.execute(start);
    await notified;
    expect(saved.id, start.id);
    expect(saved.sequence, 1);
    expect(notificationCount, 1);
    expect(service.changeRevision, 1);
    expect((await service.findDetail(missionId: 'a'))!.events, hasLength(1));
  });

  test('另一个任务运行时拒绝开始，不为冲突发通知或增加刷新计数', () async {
    await act(ExecutionEventType.start);
    final revisionBefore = service.changeRevision;
    var notificationCount = 0;
    final subscription = service.changes.listen((_) => notificationCount++);
    addTearDown(subscription.cancel);
    final startOther = await command(ExecutionEventType.start, mission: 'b');

    await expectLater(
      service.execute(startOther),
      throwsA(isA<ExecutionConflict>()),
    );
    await Future<void>.delayed(Duration.zero);
    expect(notificationCount, 0);
    expect(service.changeRevision, revisionBefore);
    expect((await service.findDetail(missionId: 'b'))!.events, isEmpty);
    expect((await service.findActive()).single.mission.id, 'a');
  });

  test('再次尝试只复制计划并保存来源，原事件报告及失败原因不被复制或修改', () async {
    await act(ExecutionEventType.start);
    await act(ExecutionEventType.end, report: UserReportedResult.notCompleted);
    final source = (await repository.findDetail('a'))!;
    await service.create(
      title: '新的尝试',
      objective: '调整后的目标',
      scheduledDate: '2026-10-25',
      timeZone: 'Asia/Shanghai',
      plannedDurationMinutes: 15,
      retrySource: source,
    );
    final retry = (await service.findScheduledOn(
      scheduledDate: '2026-10-25',
    )).single;
    final detail = (await repository.findDetail(retry.mission.id))!;
    expect(detail.mission.id, isNot(source.mission.id));
    expect(detail.mission.sourceMissionId, 'a');
    expect(detail.mission.relationType, MissionRelationType.retry);
    expect(detail.executionPlan.objective, '调整后的目标');
    expect(detail.executionPlan.steps, source.executionPlan.steps);
    expect(detail.events, isEmpty);
    expect(detail.failures, isEmpty);
    expect(detail.lastSequence, 0);
    expect(
      (await repository.findDetail('a'))!.events.map((event) => event.id),
      source.events.map((event) => event.id),
    );
    expect(
      (await repository.findDetail('a'))!.failures.single.id,
      source.failures.single.id,
    );
  });

  test('拒绝从未结束的任务创建重试，不留下任务、排期或方案', () async {
    final source = (await repository.findDetail('a'))!;
    await expectLater(
      service.create(
        title: '非法重试',
        scheduledDate: '2026-10-25',
        timeZone: 'Asia/Shanghai',
        plannedDurationMinutes: 15,
        retrySource: source,
      ),
      throwsArgumentError,
    );
    expect(await database.select(database.missions).get(), hasLength(2));
    expect(
      await database.select(database.missionScheduleRevisions).get(),
      hasLength(2),
    );
    expect(await database.select(database.executionPlans).get(), hasLength(2));
  });

  test('未结束任务存在失败事实时查询明确失败，不把损坏记录显示成正常状态', () async {
    await database.customStatement(
      'INSERT INTO failure_records (id, mission_id, "trigger", occurred_at, created_at) VALUES (?, ?, ?, ?, ?)',
      [
        'unexpected',
        'a',
        'USER_MARKED_NOT_COMPLETED',
        now.millisecondsSinceEpoch,
        now.millisecondsSinceEpoch,
      ],
    );
    await expectLater(
      repository.findDetail('a'),
      throwsA(isA<FormatException>()),
    );
  });

  test('真实开始暂停延长继续结束：序号、UTC时刻、额度与时长一致', () async {
    await act(ExecutionEventType.start);
    now = now.add(const Duration(minutes: 30));
    await act(ExecutionEventType.pause);
    now = now.add(const Duration(minutes: 10));
    await act(ExecutionEventType.extend, minutes: 30);
    expect((await repository.findDetail('a'))!.phase, MissionPhase.paused);
    now = now.add(const Duration(minutes: 10));
    await act(ExecutionEventType.resume);
    now = now.add(const Duration(minutes: 40));
    await act(ExecutionEventType.end, report: UserReportedResult.completed);
    final detail = (await repository.findDetail('a'))!;
    expect(detail.phase, MissionPhase.closed);
    expect(detail.events.map((e) => e.sequence), [1, 2, 3, 4, 5]);
    expect(detail.events.every((e) => e.occurredAt.isUtc), isTrue);
    expect(detail.events.first.scheduleRevisionId, 'a-1');
    final times = calculateExecutionTimes(
      detail.events,
      now.add(const Duration(days: 1)),
    );
    expect(times.focus, const Duration(minutes: 70));
    expect(times.paused, const Duration(minutes: 20));
    expect(times.elapsed, const Duration(minutes: 90));
    expect(times.extensionMinutes, 30);
    expect(await repository.findActive(), isEmpty);
    expect((await repository.findFinished()).single.mission.id, 'a');
    expect(detail.failures, isEmpty);
  });

  test('同id延长重试仅生效一次，旧序号新id和输入碰撞被拒绝', () async {
    await act(ExecutionEventType.start);
    final extend = await command(ExecutionEventType.extend, minutes: 10);
    final first = await service.execute(extend);
    now = now.add(const Duration(minutes: 1));
    final retry = await service.execute(extend);
    expect(retry.occurredAt, first.occurredAt);
    expect((await repository.findDetail('a'))!.events, hasLength(2));
    await expectLater(
      service.execute(
        ExecutionCommand(
          id: 'stale',
          missionId: 'a',
          expectedSequence: 1,
          type: ExecutionEventType.extend,
          grantedDurationMinutes: 10,
        ),
      ),
      throwsA(isA<ExecutionConflict>()),
    );
    await expectLater(
      service.execute(
        ExecutionCommand(
          id: extend.id,
          missionId: 'a',
          expectedSequence: 1,
          type: ExecutionEventType.extend,
          grantedDurationMinutes: 20,
        ),
      ),
      throwsA(isA<ExecutionConflict>()),
    );
    await act(ExecutionEventType.pause);
    // 后续状态变化后重试旧成功请求，也只返回原事件。
    expect((await service.execute(extend)).sequence, 2);
  });

  test('START旧排期与非法动作拒绝，取消后不能开始', () async {
    await expectLater(
      service.execute(
        ExecutionCommand(
          id: 'old-plan',
          missionId: 'a',
          expectedSequence: 0,
          type: ExecutionEventType.start,
          scheduleRevisionId: 'b-1',
        ),
      ),
      throwsA(isA<ExecutionConflict>()),
    );
    await expectLater(
      act(ExecutionEventType.resume),
      throwsA(isA<ArgumentError>()),
    );
    await service.cancel(missionId: 'a');
    await expectLater(
      act(ExecutionEventType.start),
      throwsA(isA<ArgumentError>()),
    );
    expect(await database.select(database.executionEvents).get(), isEmpty);
  });

  test('开始后编辑与取消均被拒绝；暂停其他任务后才能开始/恢复', () async {
    final original = (await repository.findDetail('a'))!;
    await act(ExecutionEventType.start);
    await expectLater(
      service.cancel(missionId: 'a'),
      throwsA(isA<ExecutionConflict>()),
    );
    await expectLater(
      service.edit(
        original: original,
        title: '不可修改',
        objective: '新目标',
        scheduledDate: '2026-10-23',
        plannedDurationMinutes: 20,
        timePolicy: original.schedule.timePolicy,
      ),
      throwsA(anything),
    );
    await expectLater(
      act(ExecutionEventType.start, mission: 'b'),
      throwsA(isA<ExecutionConflict>()),
    );
    await act(ExecutionEventType.pause);
    await act(ExecutionEventType.start, mission: 'b');
    await expectLater(
      act(ExecutionEventType.resume),
      throwsA(isA<ExecutionConflict>()),
    );
    final active = await repository.findActive();
    expect(active.map((e) => e.mission.id), ['b', 'a']);
    expect(
      (await repository.findDetail('a'))!.mission.title,
      original.mission.title,
    );
  });

  test('系统时间倒退拒绝新事实，查询临时上界不产生负时长', () async {
    await act(ExecutionEventType.start);
    now = now.subtract(const Duration(minutes: 5));
    await expectLater(
      act(ExecutionEventType.pause),
      throwsA(isA<ExecutionConflict>()),
    );
    final detail = (await repository.findDetail('a'))!;
    final times = calculateExecutionTimes(detail.events, now);
    expect(times.focus, Duration.zero);
    expect(times.clockBehind, isTrue);
    expect(detail.events, hasLength(1));
  });

  test('打开报告的暂停与END独立；旧报告不能结束已恢复任务', () async {
    await act(ExecutionEventType.start);
    await act(ExecutionEventType.pause);
    final end = await command(
      ExecutionEventType.end,
      report: UserReportedResult.completed,
    );
    await act(ExecutionEventType.resume);
    await expectLater(service.execute(end), throwsA(isA<ExecutionConflict>()));
    expect((await repository.findDetail('a'))!.phase, MissionPhase.running);
  });

  test('未完成允许空原因，END与失败记录同时保存，重试核对原因不覆盖', () async {
    await act(ExecutionEventType.start);
    final end = await command(
      ExecutionEventType.end,
      report: UserReportedResult.notCompleted,
    );
    await service.execute(end);
    await service.execute(end);
    final detail = (await repository.findDetail('a'))!;
    expect(detail.phase, MissionPhase.closed);
    expect(detail.failures, hasLength(1));
    expect(detail.failures.single.userReasonText, isNull);
    expect(detail.failures.single.occurredAt, detail.events.last.occurredAt);
    await expectLater(
      service.execute(
        ExecutionCommand(
          id: end.id,
          missionId: 'a',
          expectedSequence: 1,
          type: ExecutionEventType.end,
          userReportedResult: UserReportedResult.notCompleted,
          userReasonText: '不同原因',
        ),
      ),
      throwsA(isA<ExecutionConflict>()),
    );
  });

  test('失败记录插入故障会回滚END，保留已提交暂停及原id供重试', () async {
    await act(ExecutionEventType.start);
    await act(ExecutionEventType.pause);
    final end = await command(
      ExecutionEventType.end,
      report: UserReportedResult.notCompleted,
      category: 'URGENT_EVENT',
      text: '  有事  ',
    );
    await database.customStatement(
      "CREATE TRIGGER fail_record BEFORE INSERT ON failure_records BEGIN SELECT RAISE(ABORT, '模拟失败'); END",
    );
    await expectLater(service.execute(end), throwsA(isA<SqliteException>()));
    final paused = (await repository.findDetail('a'))!;
    expect(paused.phase, MissionPhase.paused);
    expect(paused.events, hasLength(2));
    expect(paused.failures, isEmpty);
    await database.customStatement('DROP TRIGGER fail_record');
    await service.execute(end);
    expect(
      (await repository.findDetail('a'))!.failures.single.userReasonText,
      '有事',
    );
  });

  test('关闭时间固定，多个暂停任务可以共存且跨日期查询不丢失', () async {
    await act(ExecutionEventType.start);
    await act(ExecutionEventType.pause);
    await act(ExecutionEventType.start, mission: 'b');
    await act(ExecutionEventType.pause, mission: 'b');
    now = now.add(const Duration(days: 2));
    expect(await repository.findActive(), hasLength(2));
    final detail = (await repository.findDetail('a'))!;
    expect(calculateExecutionTimes(detail.events, now).focus, Duration.zero);
  });

  test('两个独立文件连接并发开始只成功一个，文件重开恢复事实', () async {
    final directory = await Directory.systemTemp.createTemp(
      'missionbook-execution-race-',
    );
    final file = File('${directory.path}/race.sqlite');
    final first = AppDatabase(executor: NativeDatabase(file));
    final second = AppDatabase(executor: NativeDatabase(file));
    try {
      final r1 = DriftMissionRepository(first, clock: () => now);
      final r2 = DriftMissionRepository(second, clock: () => now);
      await seedMission(r1, 'one');
      await seedMission(r1, 'two');
      final d1 = (await r1.findDetail('one'))!;
      final d2 = (await r2.findDetail('two'))!;
      Future<bool> attempt(
        DriftMissionRepository repo,
        ExecutionCommand c,
      ) async {
        try {
          await repo.execute(c);
          return true;
        } catch (_) {
          return false;
        }
      }

      final results = await Future.wait([
        attempt(
          r1,
          service.prepareExecution(detail: d1, type: ExecutionEventType.start),
        ),
        attempt(
          r2,
          service.prepareExecution(detail: d2, type: ExecutionEventType.start),
        ),
      ]);
      expect(results.where((s) => s), hasLength(1));
      expect(
        (await r1.findActive()).where((d) => d.phase == MissionPhase.running),
        hasLength(1),
      );
    } finally {
      await first.close();
      await second.close();
    }
    final reopened = AppDatabase(executor: NativeDatabase(file));
    try {
      final active = await DriftMissionRepository(reopened).findActive();
      expect(active, hasLength(1));
      expect(active.single.events.single.sequence, 1);
    } finally {
      await reopened.close();
      await directory.delete(recursive: true);
    }
  });

  test('同一任务的START与取消并发互斥，没有取消同时开始的事实', () async {
    final start = await command(ExecutionEventType.start);
    Future<void> ignoreFailure(Future<Object?> task) async {
      try {
        await task;
      } catch (_) {}
    }

    await Future.wait([
      ignoreFailure(service.execute(start)),
      ignoreFailure(service.cancel(missionId: 'a')),
    ]);
    final detail = (await repository.findDetail('a'))!;
    expect(
      detail.mission.cancelledAt != null && detail.events.isNotEmpty,
      isFalse,
    );
    expect(detail.phase, anyOf(MissionPhase.running, MissionPhase.cancelled));
  });
}

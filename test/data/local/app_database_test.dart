import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mission_book/application/missions/mission_service.dart';
import 'package:mission_book/data/local/app_database.dart';
import 'package:mission_book/data/repositories/drift_mission_repository.dart';
import 'package:mission_book/domain/entities/mission.dart';
import 'package:mission_book/domain/entities/mission_schedule_revision.dart';
import 'package:mission_book/domain/entities/execution_plan.dart';

void main() {
  test('真实文件数据库关闭重开后能读回任务、排期和执行方案', () async {
    // 使用专属临时目录，不访问应用真实数据；检查结束后删除整个测试目录。
    final directory = await Directory.systemTemp.createTemp(
      'missionbook-test-',
    );
    try {
      final file = File('${directory.path}/mission_book.sqlite');
      final firstConnection = AppDatabase(executor: NativeDatabase(file));
      try {
        final repository = DriftMissionRepository(firstConnection);
        await MissionService(repository).create(
          title: '  文件持久化检查  ',
          scheduledDate: '2026-10-22',
          timeZone: 'Asia/Shanghai',
          plannedDurationMinutes: 20,
        );
        await MissionService(repository).create(
          title: '固定时间文件检查',
          scheduledDate: '2026-10-23',
          timeZone: 'Asia/Shanghai',
          plannedDurationMinutes: 45,
          timePolicy: TimePolicy.fixed,
          fixedStartAt: DateTime.utc(2026, 10, 22, 16, 15),
        );
      } finally {
        await firstConnection.close();
      }

      // 创建全新的连接，确保读到的是磁盘记录，不是上一次连接的内存状态。
      final secondConnection = AppDatabase(executor: NativeDatabase(file));
      try {
        final repository = DriftMissionRepository(secondConnection);
        final missions = await MissionService(
          repository,
        ).findScheduledOn(scheduledDate: '2026-10-22');
        expect(missions, hasLength(1));
        expect(missions.single.mission.title, '文件持久化检查');
        expect(missions.single.schedule.missionId, missions.single.mission.id);
        expect(missions.single.schedule.plannedDurationMinutes, 20);
        final plans = await secondConnection
            .select(secondConnection.executionPlans)
            .get();
        expect(plans, hasLength(2));
        final originalPlan = plans.singleWhere(
          (plan) => plan.missionId == missions.single.mission.id,
        );
        expect(originalPlan.objective, '文件持久化检查');
        final fixed = await repository.findScheduledOn('2026-10-23');
        expect(fixed, hasLength(1));
        expect(fixed.single.schedule.timePolicy, TimePolicy.fixed);
        expect(
          fixed.single.schedule.fixedStartAt,
          DateTime.utc(2026, 10, 22, 16, 15),
        );
        expect(fixed.single.schedule.fixedStartAt!.isUtc, isTrue);
        final detail = await repository.findDetail(fixed.single.mission.id);
        expect(
          detail!.schedule.fixedStartAt,
          fixed.single.schedule.fixedStartAt,
        );
        expect(detail.executionPlan.objective, '固定时间文件检查');
      } finally {
        await secondConnection.close();
      }
    } finally {
      await directory.delete(recursive: true);
    }
  });

  late AppDatabase database;
  const timestamp = 1792368000000;

  setUp(() {
    // 每个测试使用独立内存数据库，不接触用户的本地文件。
    database = AppDatabase(executor: NativeDatabase.memory());
  });

  tearDown(() async {
    await database.close();
  });

  Future<void> insertMission(String id) async {
    await database
        .into(database.missions)
        .insert(
          MissionsCompanion.insert(
            id: id,
            title: '测试任务',
            createdAt: timestamp,
            updatedAt: timestamp,
          ),
        );
  }

  Future<void> insertSchedule(String id, String missionId, int revision) async {
    await database
        .into(database.missionScheduleRevisions)
        .insert(
          MissionScheduleRevisionsCompanion.insert(
            id: id,
            missionId: missionId,
            revisionNumber: revision,
            scheduledDate: '2026-10-19',
            timeZone: 'Asia/Shanghai',
            plannedDurationMinutes: 45,
            changedAt: timestamp,
          ),
        );
  }

  Future<void> insertPlan(String id, String missionId) async {
    await database
        .into(database.executionPlans)
        .insert(
          ExecutionPlansCompanion.insert(
            id: id,
            missionId: missionId,
            objective: '验证数据库约束',
            createdAt: timestamp,
            updatedAt: timestamp,
          ),
        );
  }

  Matcher sqliteConstraint(int code) => isA<SqliteException>().having(
    (error) => error.extendedResultCode,
    'extendedResultCode',
    code,
  );

  test('首次打开建立三张表、启用外键并采用数据库默认值', () async {
    await insertMission('mission-a');
    await insertSchedule('schedule-a', 'mission-a', 1);
    await insertPlan('plan-a', 'mission-a');

    final foreignKeys = await database
        .customSelect('PRAGMA foreign_keys')
        .getSingle();
    expect(foreignKeys.read<int>('foreign_keys'), 1);

    final mission = await database.select(database.missions).getSingle();
    final schedule = await database
        .select(database.missionScheduleRevisions)
        .getSingle();
    final plan = await database.select(database.executionPlans).getSingle();
    expect(mission.verificationPolicy, 'SELF_REPORT');
    expect(mission.createdAt, timestamp);
    expect(schedule.timePolicy, 'FLEXIBLE');
    expect(schedule.fixedStartAt, isNull);
    expect(plan.steps, '[]');
  });

  test('排期和方案都拒绝引用不存在的任务', () async {
    await expectLater(
      insertSchedule('orphan-schedule', 'missing', 1),
      throwsA(sqliteConstraint(787)),
    );
    await expectLater(
      insertPlan('orphan-plan', 'missing'),
      throwsA(sqliteConstraint(787)),
    );
  });

  test('同任务版本不能重复，不同任务可以使用相同版本号', () async {
    await insertMission('mission-a');
    await insertMission('mission-b');
    await insertSchedule('a-1', 'mission-a', 1);
    await insertSchedule('a-2', 'mission-a', 2);
    await insertSchedule('b-1', 'mission-b', 1);

    await expectLater(
      insertSchedule('a-duplicate', 'mission-a', 1),
      throwsA(sqliteConstraint(2067)),
    );
    expect(
      await database.select(database.missionScheduleRevisions).get(),
      hasLength(3),
    );
  });

  test('同一个任务不能保存两份执行方案', () async {
    await insertMission('mission-a');
    await insertPlan('plan-a', 'mission-a');

    await expectLater(
      insertPlan('plan-duplicate', 'mission-a'),
      throwsA(sqliteConstraint(2067)),
    );
  });

  test('跨表事务失败时回滚任务、排期和方案', () async {
    await expectLater(
      database.transaction(() async {
        await insertMission('mission-a');
        await insertSchedule('schedule-a', 'mission-a', 1);
        await insertPlan('plan-a', 'mission-a');
        // 故意违反唯一约束，验证此前三张表的写入一起回滚。
        await insertPlan('plan-duplicate', 'mission-a');
      }),
      throwsA(sqliteConstraint(2067)),
    );

    expect(await database.select(database.missions).get(), isEmpty);
    expect(
      await database.select(database.missionScheduleRevisions).get(),
      isEmpty,
    );
    expect(await database.select(database.executionPlans).get(), isEmpty);
  });

  group('DriftMissionRepository.create', () {
    final createdAt = DateTime.utc(2026, 10, 20, 1);
    final updatedAt = DateTime.utc(2026, 10, 20, 2);
    final fixedStartAt = DateTime.utc(2026, 10, 20, 10);
    final deadline = DateTime.utc(2026, 10, 20, 15);
    const steps = ['阅读“第一章”', '记录\n心得'];

    // 每次调用都创建三个业务对象，再走真实仓储入口。
    // 可选参数仅用于在失败测试里故意提供错误关联或重复编号。
    Future<void> createTask({
      String missionId = 'mission-a',
      String planId = 'plan-a',
      String? scheduleMissionId,
      String? planMissionId,
      int revisionNumber = 1,
      DateTime? cancelledAt,
    }) {
      return DriftMissionRepository(database).create(
        mission: Mission(
          id: missionId,
          title: '读书',
          description: '读完第一章',
          why: '准备讨论',
          verificationPolicy: VerificationPolicy.requiredEvidence,
          createdAt: createdAt,
          updatedAt: updatedAt,
          cancelledAt: cancelledAt,
        ),
        initialSchedule: MissionScheduleRevision(
          id: 'schedule-$missionId',
          missionId: scheduleMissionId ?? missionId,
          revisionNumber: revisionNumber,
          scheduledDate: '2026-10-20',
          timeZone: 'Asia/Shanghai',
          timePolicy: TimePolicy.fixed,
          fixedStartAt: fixedStartAt,
          plannedDurationMinutes: 30,
          evidenceDeadlineAt: deadline,
          changeReason: '首次安排',
          changedAt: createdAt,
        ),
        executionPlan: ExecutionPlan(
          id: planId,
          missionId: planMissionId ?? missionId,
          objective: '读完十页',
          steps: steps,
          verificationCriteria: '提交读书笔记',
          notes: '重点记录问题',
          createdAt: createdAt,
          updatedAt: updatedAt,
        ),
      );
    }

    // 失败测试不仅检查有异常，还检查没有留下任何半条任务。
    Future<void> expectEmptyDatabase() async {
      expect(await database.select(database.missions).get(), isEmpty);
      expect(
        await database.select(database.missionScheduleRevisions).get(),
        isEmpty,
      );
      expect(await database.select(database.executionPlans).get(), isEmpty);
    }

    test('创建后能读回关联记录、时间、枚举和含特殊字符的步骤', () async {
      await createTask();

      // getSingle 同时检查每张表恰好有一条记录。
      final mission = await database.select(database.missions).getSingle();
      final schedule = await database
          .select(database.missionScheduleRevisions)
          .getSingle();
      final plan = await database.select(database.executionPlans).getSingle();

      expect(mission.id, 'mission-a');
      expect(mission.title, '读书');
      expect(mission.description, '读完第一章');
      expect(mission.why, '准备讨论');
      expect(mission.verificationPolicy, 'REQUIRED_EVIDENCE');
      expect(mission.createdAt, createdAt.millisecondsSinceEpoch);
      expect(mission.updatedAt, updatedAt.millisecondsSinceEpoch);
      expect(mission.cancelledAt, isNull);

      expect(schedule.id, 'schedule-mission-a');
      expect(schedule.missionId, mission.id);
      expect(schedule.revisionNumber, 1);
      expect(schedule.scheduledDate, '2026-10-20');
      expect(schedule.timeZone, 'Asia/Shanghai');
      expect(schedule.timePolicy, 'FIXED');
      expect(schedule.fixedStartAt, fixedStartAt.millisecondsSinceEpoch);
      expect(schedule.plannedDurationMinutes, 30);
      expect(schedule.evidenceDeadlineAt, deadline.millisecondsSinceEpoch);
      expect(schedule.changeReason, '首次安排');
      expect(schedule.changedAt, createdAt.millisecondsSinceEpoch);

      expect(plan.id, 'plan-a');
      expect(plan.missionId, mission.id);
      expect(plan.objective, '读完十页');
      // 解码后比较，确认引号、换行和步骤顺序都没有丢失。
      expect(jsonDecode(plan.steps), steps);
      expect(plan.verificationCriteria, '提交读书笔记');
      expect(plan.notes, '重点记录问题');
      expect(plan.createdAt, createdAt.millisecondsSinceEpoch);
      expect(plan.updatedAt, updatedAt.millisecondsSinceEpoch);
    });

    test('拒绝不属于当前任务的排期，且不写入数据', () async {
      await expectLater(
        createTask(scheduleMissionId: 'other-mission'),
        throwsArgumentError,
      );
      await expectEmptyDatabase();
    });

    test('拒绝不属于当前任务的方案，且不写入数据', () async {
      await expectLater(
        createTask(planMissionId: 'other-mission'),
        throwsArgumentError,
      );
      await expectEmptyDatabase();
    });

    test('拒绝首次排期版本不是 1，且不写入数据', () async {
      await expectLater(createTask(revisionNumber: 2), throwsArgumentError);
      await expectEmptyDatabase();
    });

    test('拒绝创建已取消任务，且不写入数据', () async {
      await expectLater(
        createTask(cancelledAt: updatedAt),
        throwsArgumentError,
      );
      await expectEmptyDatabase();
    });

    test('第三次写入失败时回滚新任务和排期，保留原有数据', () async {
      await createTask();
      final oldMission = await database.select(database.missions).getSingle();
      final oldSchedule = await database
          .select(database.missionScheduleRevisions)
          .getSingle();
      final oldPlan = await database
          .select(database.executionPlans)
          .getSingle();

      // mission-b 和它的排期可以写入，但 plan-a 已存在：
      // 第三次插入违反主键约束，必须撤销前两次写入。
      await expectLater(
        createTask(missionId: 'mission-b', planId: 'plan-a'),
        throwsA(sqliteConstraint(1555)),
      );

      // 整表比较：新记录没有留下，原有记录也没有被覆盖或删除。
      expect(await database.select(database.missions).get(), [oldMission]);
      expect(await database.select(database.missionScheduleRevisions).get(), [
        oldSchedule,
      ]);
      expect(await database.select(database.executionPlans).get(), [oldPlan]);
    });
  });
}

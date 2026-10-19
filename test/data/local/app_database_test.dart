import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mission_book/data/local/app_database.dart';

void main() {
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
}

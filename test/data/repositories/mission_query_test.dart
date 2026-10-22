import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mission_book/application/get_scheduled_missions.dart';
import 'package:mission_book/data/local/app_database.dart';
import 'package:mission_book/data/repositories/drift_mission_repository.dart';
import 'package:mission_book/domain/entities/execution_plan.dart';
import 'package:mission_book/domain/entities/mission.dart';
import 'package:mission_book/domain/entities/mission_schedule_revision.dart';

void main() {
  late AppDatabase database;
  late DriftMissionRepository repository;
  final createdAt = DateTime.utc(2026, 10, 20);
  const date = '2026-10-21';

  setUp(() {
    database = AppDatabase(executor: NativeDatabase.memory());
    repository = DriftMissionRepository(database);
  });
  tearDown(() => database.close());

  Future<void> addTask(
    String id, {
    String day = date,
    DateTime? created,
    DateTime? start,
  }) => repository.create(
    mission: Mission(
      id: id,
      title: '任务 $id',
      description: '真实仓储查询',
      why: '验证关联结果',
      createdAt: created ?? createdAt,
      updatedAt: created ?? createdAt,
    ),
    initialSchedule: MissionScheduleRevision(
      id: '$id-1',
      missionId: id,
      revisionNumber: 1,
      scheduledDate: day,
      timeZone: 'Asia/Shanghai',
      timePolicy: start == null ? TimePolicy.flexible : TimePolicy.fixed,
      fixedStartAt: start,
      plannedDurationMinutes: 20,
      changedAt: createdAt,
    ),
    executionPlan: ExecutionPlan(
      id: '$id-plan',
      missionId: id,
      objective: '查询测试',
      createdAt: createdAt,
      updatedAt: createdAt,
    ),
  );

  Future<void> reschedule(String id, String day, int revision) => database
      .into(database.missionScheduleRevisions)
      .insert(
        scheduleToCompanion(
          MissionScheduleRevision(
            id: '$id-$revision',
            missionId: id,
            revisionNumber: revision,
            scheduledDate: day,
            timeZone: 'Asia/Shanghai',
            plannedDurationMinutes: 35,
            changeReason: '改到其他日期',
            changedAt: createdAt.add(Duration(days: revision)),
          ),
        ),
      );

  test('固定按开始时刻，自选按创建时刻；同值按 id，取消记录仍可查询', () async {
    final morning = DateTime.utc(2026, 10, 21, 1);
    // 故意打乱插入和创建顺序，固定时间相同时不能错误地用创建时间排序。
    await addTask('fixed-b', start: morning);
    await addTask('flex-b');
    await addTask('fixed-late', start: morning.add(const Duration(hours: 2)));
    await addTask(
      'fixed-a',
      start: morning,
      created: createdAt.add(const Duration(days: 1)),
    );
    await addTask('flex-a');
    await addTask(
      'flex-old',
      created: createdAt.subtract(const Duration(days: 1)),
    );
    await addTask(
      'cancelled',
      created: createdAt.add(const Duration(hours: 1)),
    );
    await (database.update(
      database.missions,
    )..where((row) => row.id.equals('cancelled'))).write(
      MissionsCompanion(cancelledAt: Value(createdAt.millisecondsSinceEpoch)),
    );
    await addTask('other-day', day: '2026-10-22');

    final result = await repository.findScheduledOn(date);
    expect(result.map((item) => item.mission.id), [
      'fixed-a',
      'fixed-b',
      'fixed-late',
      'flex-old',
      'flex-a',
      'flex-b',
      'cancelled',
    ]);
    expect(result.first.mission.description, '真实仓储查询');
    expect(
      result.first.mission.verificationPolicy,
      VerificationPolicy.selfReport,
    );
    expect(result.first.mission.createdAt.isUtc, isTrue);
    expect(result.first.schedule.fixedStartAt, morning);
    expect(result.first.schedule.fixedStartAt!.isUtc, isTrue);
    expect(result.last.mission.cancelledAt, createdAt);
  });

  test('先取最新排期再筛日期；改走的不回旧列表，改回的只出现一次', () async {
    await addTask('moved-away');
    await reschedule('moved-away', '2026-10-22', 2);
    await addTask('moved-back');
    await reschedule('moved-back', '2026-10-22', 2);
    await reschedule('moved-back', date, 3);

    final result = await repository.findScheduledOn(date);
    expect(result, hasLength(1));
    expect(result.single.mission.id, 'moved-back');
    expect(result.single.schedule.revisionNumber, 3);
    expect(result.single.schedule.plannedDurationMinutes, 35);
    expect(result.single.schedule.changeReason, '改到其他日期');
  });

  test('每次调用只读取一次，写入或改期后重新调用才得到新结果', () async {
    final firstResult = await repository.findScheduledOn(date);
    expect(firstResult, isEmpty);

    await addTask('new-task');
    expect(firstResult, isEmpty);
    final secondResult = await repository.findScheduledOn(date);
    expect(secondResult, hasLength(1));
    expect(secondResult.single.schedule.missionId, 'new-task');

    await reschedule('new-task', '2026-10-22', 2);
    expect(secondResult, hasLength(1));
    final thirdResult = await repository.findScheduledOn(date);
    expect(thirdResult, isEmpty);
  });

  test('无法解释的存储策略作为查询错误传出，不能伪装成正常任务', () async {
    await addTask('invalid');
    await database
        .update(database.missions)
        .write(const MissionsCompanion(verificationPolicy: Value('UNKNOWN')));
    await expectLater(repository.findScheduledOn(date), throwsFormatException);
  });

  test('查询入口拒绝不存在的日期和错误格式', () async {
    final getMissions = GetScheduledMissions(repository);
    for (final invalid in [
      '2026-02-30',
      '2026-2-1',
      '',
      '2026-10-21T00:00:00',
      '2026-10-21\n',
    ]) {
      // 先取得 Future，再检查异步错误；若 execute 同步抛错，本测试会直接失败。
      final query = getMissions.execute(scheduledDate: invalid);
      await expectLater(query, throwsArgumentError);
    }
    expect(await getMissions.execute(scheduledDate: date), isEmpty);
  });

  test('查询接受合法闰日和设备时区可能跳过的日历日期', () async {
    final getMissions = GetScheduledMissions(repository);
    final validDates = ['2011-12-30', '2024-02-29', '0001-01-01', '9999-12-31'];
    for (final selectedDate in validDates) {
      await addTask('calendar-$selectedDate', day: selectedDate);
      final result = await getMissions.execute(scheduledDate: selectedDate);
      expect(result, hasLength(1));
      expect(result.single.schedule.scheduledDate, selectedDate);
    }
  });
}

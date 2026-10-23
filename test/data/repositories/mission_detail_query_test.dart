import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mission_book/application/missions/mission_service.dart';
import 'package:mission_book/data/local/app_database.dart';
import 'package:mission_book/data/repositories/drift_mission_repository.dart';
import 'package:mission_book/domain/entities/execution_plan.dart';
import 'package:mission_book/domain/entities/mission.dart';
import 'package:mission_book/domain/entities/mission_schedule_revision.dart';

void main() {
  late AppDatabase database;
  late DriftMissionRepository repository;
  final now = DateTime.utc(2026, 10, 23);

  setUp(() {
    // 独立内存库只保存本测试的样本，不打开用户数据库。
    database = AppDatabase(executor: NativeDatabase.memory());
    repository = DriftMissionRepository(database);
  });
  tearDown(() => database.close());

  MissionScheduleRevision schedule(int version) => MissionScheduleRevision(
    id: 'schedule-$version',
    missionId: 'mission-a',
    revisionNumber: version,
    scheduledDate: '2026-10-${22 + version}',
    timeZone: 'Asia/Shanghai',
    plannedDurationMinutes: 20 * version,
    changedAt: now,
  );

  Future<void> createTask() => repository.create(
    mission: Mission(
      id: 'mission-a',
      title: '阅读完整标题',
      description: '一份真实的任务说明',
      why: '理解查询到页面的过程',
      createdAt: now,
      updatedAt: now,
    ),
    initialSchedule: schedule(1),
    executionPlan: ExecutionPlan(
      id: 'plan-a',
      missionId: 'mission-a',
      objective: '能追踪一次详情读取',
      steps: ['先看接口', '再看仓储与页面'],
      verificationCriteria: '能说明输入与结果',
      notes: '保留真实笔记',
      createdAt: now,
      updatedAt: now,
    ),
  );

  test('详情按编号读取三对象，跨日期仍取最新排期，不修改历史或方案', () async {
    await createTask();
    await database
        .into(database.missionScheduleRevisions)
        .insert(scheduleToCompanion(schedule(2)));

    final detail = await MissionService(
      repository,
    ).findDetail(missionId: 'mission-a');
    expect(detail, isNotNull);
    expect(detail!.mission.id, 'mission-a');
    expect(detail.mission.title, '阅读完整标题');
    expect(detail.mission.description, '一份真实的任务说明');
    expect(detail.mission.why, '理解查询到页面的过程');
    expect(detail.mission.createdAt, now);
    expect(detail.mission.createdAt.isUtc, isTrue);
    expect(detail.schedule.revisionNumber, 2);
    expect(detail.schedule.scheduledDate, '2026-10-24');
    expect(detail.schedule.plannedDurationMinutes, 40);
    expect(detail.executionPlan.id, 'plan-a');
    expect(detail.executionPlan.missionId, 'mission-a');
    expect(detail.executionPlan.objective, '能追踪一次详情读取');
    expect(detail.executionPlan.steps, ['先看接口', '再看仓储与页面']);
    expect(detail.executionPlan.verificationCriteria, '能说明输入与结果');
    expect(detail.executionPlan.notes, '保留真实笔记');
    expect(detail.executionPlan.updatedAt.isUtc, isTrue);
    expect(
      () => detail.executionPlan.steps.add('不能修改'),
      throwsUnsupportedError,
    );

    // 连读两次不产生写入；旧排期仍存在，方案仍是原来那条完整记录。
    await repository.findDetail('mission-a');
    final versions = await database
        .select(database.missionScheduleRevisions)
        .get();
    expect(versions.map((row) => row.revisionNumber), unorderedEquals([1, 2]));
    final plans = await database.select(database.executionPlans).get();
    expect(plans.single.steps, '["先看接口","再看仓储与页面"]');
    expect(plans.single.updatedAt, now.millisecondsSinceEpoch);
  });

  test('不存在的编号返回 null；已取消任务仍能读取取消事实', () async {
    await createTask();
    expect(await repository.findDetail('unknown-id'), isNull);
    await (database.update(
      database.missions,
    )..where((row) => row.id.equals('mission-a'))).write(
      MissionsCompanion(cancelledAt: Value(now.millisecondsSinceEpoch)),
    );
    final detail = await repository.findDetail('mission-a');
    expect(detail!.mission.cancelledAt, now);
    expect(detail.mission.cancelledAt!.isUtc, isTrue);
  });

  test('任务存在但缺少方案或排期时传出错误，不伪装成未找到', () async {
    await createTask();
    await database.delete(database.executionPlans).go();
    await expectLater(
      repository.findDetail('mission-a'),
      throwsFormatException,
    );
    await database
        .into(database.executionPlans)
        .insert(
          executionPlanToCompanion(
            ExecutionPlan(
              id: 'replacement-plan',
              missionId: 'mission-a',
              objective: '完整方案',
              createdAt: now,
              updatedAt: now,
            ),
          ),
        );
    await database.delete(database.missionScheduleRevisions).go();
    await expectLater(
      repository.findDetail('mission-a'),
      throwsFormatException,
    );
  });

  test('损坏 JSON、非数组及混合步骤都作为读取错误传出', () async {
    await createTask();
    for (final invalid in ['{', '{}', '["第一步", 2]']) {
      await database
          .update(database.executionPlans)
          .write(ExecutionPlansCompanion(steps: Value(invalid)));
      await expectLater(
        repository.findDetail('mission-a'),
        throwsFormatException,
      );
    }
  });

  test('空编号通过异步错误拒绝，仓储转换失败继续向上传递', () async {
    final missionService = MissionService(repository);
    for (final invalid in ['', '  ']) {
      final result = missionService.findDetail(missionId: invalid);
      await expectLater(result, throwsArgumentError);
    }
    await createTask();
    await database
        .update(database.missions)
        .write(const MissionsCompanion(verificationPolicy: Value('UNKNOWN')));
    await expectLater(
      missionService.findDetail(missionId: 'mission-a'),
      throwsFormatException,
    );
  });

  test('无效排期时区在读取 Future 中报错，避免页面构建时才失败', () async {
    await createTask();
    await database
        .update(database.missionScheduleRevisions)
        .write(
          const MissionScheduleRevisionsCompanion(
            timeZone: Value('Invalid/Zone'),
          ),
        );
    await expectLater(
      MissionService(repository).findDetail(missionId: 'mission-a'),
      throwsException,
    );
  });
}

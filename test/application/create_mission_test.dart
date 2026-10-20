import 'package:flutter_test/flutter_test.dart';

import 'package:mission_book/application/create_mission.dart';
import 'package:mission_book/domain/entities/mission.dart';
import 'package:mission_book/domain/entities/mission_schedule_revision.dart';
import 'package:mission_book/domain/entities/execution_plan.dart';
import 'package:mission_book/domain/repositories/mission_repository.dart';

// implements 表示这个类遵守 MissionRepository 的约定，
// 因此必须提供接口要求的 create 方法。
class RecordingMissionRepository implements MissionRepository {
  // 对象尚未收到时为 null；create 被调用后再记录下来。
  Mission? receivedMission;
  MissionScheduleRevision? receivedSchedule;
  ExecutionPlan? receivedPlan;

  int createCallCount = 0;

  @override
  Future<void> create({
    required Mission mission,
    required MissionScheduleRevision initialSchedule,
    required ExecutionPlan executionPlan,
  }) async {
    // 这些参数由 CreateMission.execute 在最后调用仓储时提供。
    createCallCount += 1;
    receivedMission = mission;
    receivedSchedule = initialSchedule;
    receivedPlan = executionPlan;
  }
}

void main() {
  // test 注册一个测试：第一个参数是名称，第二个参数是测试过程。
  // 测试运行器执行后面的回调；async 允许里面等待异步创建完成。
  test('合法输入创建三个关联对象，并交给仓储一次', () async {
    final repository = RecordingMissionRepository();

    // 把测试仓储传给业务对象。
    // execute 最后调用的 repository 就是这里这个实例。
    final createMission = CreateMission(repository);

    // 测试扮演未来页面的角色，提供用户填写的四个值。
    // 故意给标题两边加空格，检查业务方法是否清理输入。
    await createMission.execute(
      title: '  阅读 20 分钟  ',
      scheduledDate: '2026-10-20',
      timeZone: 'Asia/Shanghai',
      plannedDurationMinutes: 20,
    );

    // expect(实际结果, 预期结果)：不符合时，这个测试失败。
    expect(repository.createCallCount, 1);

    // isNotNull 是测试包提供的检查条件，要求实际值不为空。
    expect(repository.receivedMission, isNotNull);
    expect(repository.receivedSchedule, isNotNull);
    expect(repository.receivedPlan, isNotNull);

    // 上面已经检查非空；这里用 ! 取得非空对象，便于检查字段。
    // 如果意外为 null，! 会抛出异常，测试也会失败。
    final mission = repository.receivedMission!;
    final schedule = repository.receivedSchedule!;
    final plan = repository.receivedPlan!;

    // 输入应被正确使用，标题应去掉首尾空白。
    expect(mission.title, '阅读 20 分钟');
    expect(schedule.scheduledDate, '2026-10-20');
    expect(schedule.timeZone, 'Asia/Shanghai');
    expect(schedule.plannedDurationMinutes, 20);
    expect(plan.objective, '阅读 20 分钟');

    // 排期和方案必须归属于这次新建的任务。
    // ID 由业务方法随机生成，因此检查关联关系，不写死具体编号。
    expect(mission.id, isNotEmpty);
    expect(schedule.id, isNotEmpty);
    expect(plan.id, isNotEmpty);
    expect(schedule.missionId, mission.id);
    expect(plan.missionId, mission.id);

    // 当前默认创建路径：自报、灵活排期、首次版本为 1。
    expect(mission.verificationPolicy, VerificationPolicy.selfReport);
    expect(schedule.timePolicy, TimePolicy.flexible);
    expect(schedule.revisionNumber, 1);
    expect(schedule.fixedStartAt, isNull);
    expect(mission.cancelledAt, isNull);

    // 不猜测当前时间的具体数值，而是检查统一 UTC 和时间一致性。
    expect(mission.createdAt.isUtc, isTrue);
    expect(mission.updatedAt, mission.createdAt);
    expect(schedule.changedAt, mission.createdAt);
    expect(plan.createdAt, mission.createdAt);
    expect(plan.updatedAt, mission.createdAt);
  });
}

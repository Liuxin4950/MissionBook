import 'package:flutter_test/flutter_test.dart';

import 'package:mission_book/application/missions/mission_service.dart';
import 'package:mission_book/domain/entities/mission.dart';
import 'package:mission_book/domain/entities/mission_schedule_revision.dart';
import 'package:mission_book/domain/entities/execution_plan.dart';
import 'package:mission_book/domain/repositories/mission_repository.dart';
import 'package:mission_book/domain/entities/scheduled_mission.dart';
import 'package:mission_book/domain/entities/mission_detail.dart';

// implements 表示这个类遵守 MissionRepository 的约定，
// 因此必须提供接口要求的 create 方法。
class RecordingMissionRepository implements MissionRepository {
  @override
  Future<MissionDetail?> findDetail(String missionId) =>
      throw UnsupportedError('创建业务测试不读取详情');

  @override
  Future<List<ScheduledMission>> findScheduledOn(String scheduledDate) =>
      throw UnsupportedError('创建业务测试不调用查询');

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
    // 这些参数由 MissionService.create 在最后调用仓储时提供。
    createCallCount += 1;
    receivedMission = mission;
    receivedSchedule = initialSchedule;
    receivedPlan = executionPlan;
  }
}

// 模拟“仓储保存失败”的测试替身。
// 它遵守同一个 MissionRepository 接口，所以 MissionService 不需要知道这是测试代码。
class FailingMissionRepository implements MissionRepository {
  @override
  Future<MissionDetail?> findDetail(String missionId) =>
      throw UnsupportedError('创建业务测试不读取详情');

  @override
  Future<List<ScheduledMission>> findScheduledOn(String scheduledDate) =>
      throw UnsupportedError('创建业务测试不调用查询');

  @override
  Future<void> create({
    required Mission mission,
    required MissionScheduleRevision initialSchedule,
    required ExecutionPlan executionPlan,
  }) async {
    // async 函数里的 throw 会让返回的 Future 以错误结束，
    // 不会像同步方法那样直接在调用行抛出。
    throw StateError('模拟数据库保存失败');
  }
}

void main() {
  // test 注册一个测试：第一个参数是名称，第二个参数是测试过程。
  // 测试运行器执行后面的回调；async 允许里面等待异步创建完成。
  test('合法输入创建三个关联对象，并交给仓储一次', () async {
    final repository = RecordingMissionRepository();

    // 把测试仓储传给业务对象。
    // create 最后调用的 repository 就是这里这个实例。
    final missionService = MissionService(repository);

    // 测试扮演未来页面的角色，提供用户填写的四个值。
    // 故意给标题两边加空格，检查业务方法是否清理输入。
    await missionService.create(
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
  test('合法日历日期原样保存，包括闰日和设备时区可能跳过的日期', () async {
    final validDates = ['2011-12-30', '2024-02-29', '0001-01-01', '9999-12-31'];
    for (final date in validDates) {
      final repository = RecordingMissionRepository();
      final missionService = MissionService(repository);

      await missionService.create(
        title: '日历日期测试',
        scheduledDate: date,
        timeZone: 'Asia/Shanghai',
        plannedDurationMinutes: 20,
      );

      expect(repository.createCallCount, 1);
      expect(repository.receivedSchedule!.scheduledDate, date);
      expect(repository.receivedSchedule!.timeZone, 'Asia/Shanghai');
    }
  });

  // 错误异常测试
  test('空白标题被拒绝，且不调用仓储', () async {
    final repository = RecordingMissionRepository();
    final missionService = MissionService(repository);

    // 只把 title 换成全空格，其余参数保持合法。
    // 这样测试失败时，可以确定问题在标题校验。
    await expectLater(
      missionService.create(
        title: '   ', //异常空是否正常处理
        scheduledDate: '2026-10-20',
        timeZone: 'Asia/Shanghai',
        plannedDurationMinutes: 20,
      ),
      throwsArgumentError,
    );

    // 校验在 repository.create 之前完成，所以仓储一次也不应被调用。
    expect(repository.createCallCount, 0);
  });

  test('计划时长不是正数时被拒绝，且不调用仓储', () async {
    final repository = RecordingMissionRepository();
    final missionService = MissionService(repository);

    // 0 是 <= 0 的边界；负数走同一个判断，不需要为每个数值重复测试。
    await expectLater(
      missionService.create(
        title: '阅读 20 分钟',
        scheduledDate: '2026-10-20',
        timeZone: 'Asia/Shanghai',
        plannedDurationMinutes: 0,
      ),
      throwsArgumentError,
    );

    expect(repository.createCallCount, 0);
  });

  test('日期格式不是 YYYY-MM-DD 时被拒绝', () async {
    final repository = RecordingMissionRepository();
    final missionService = MissionService(repository);

    // 业务入口要求精确日期键；页面可以先清理输入，其他调用者不能传入多余字符。
    final invalidDates = ['2026/10/20', '2026-10-20\n', ' 2026-10-20'];
    for (final date in invalidDates) {
      await expectLater(
        missionService.create(
          title: '阅读 20 分钟',
          scheduledDate: date,
          timeZone: 'Asia/Shanghai',
          plannedDurationMinutes: 20,
        ),
        throwsArgumentError,
      );
    }

    expect(repository.createCallCount, 0);
  });

  test('不存在的日历日期被拒绝', () async {
    final repository = RecordingMissionRepository();
    final missionService = MissionService(repository);

    // 格式正确也不代表日期存在：分别覆盖闰年、月份和日期越界。
    final invalidDates = [
      '2026-02-30',
      '1900-02-29',
      '2026-00-01',
      '2026-13-01',
      '2026-02-00',
      '2026-04-31',
    ];
    for (final date in invalidDates) {
      await expectLater(
        missionService.create(
          title: '阅读 20 分钟',
          scheduledDate: date,
          timeZone: 'Asia/Shanghai',
          plannedDurationMinutes: 20,
        ),
        throwsArgumentError,
      );
    }

    expect(repository.createCallCount, 0);
  });

  test('无效时区名称被拒绝', () async {
    final repository = RecordingMissionRepository();
    final missionService = MissionService(repository);

    // tz.getLocation 找不到该名称时抛出 LocationNotFoundException，
    // 业务代码把它转换成统一的 ArgumentError。
    await expectLater(
      missionService.create(
        title: '阅读 20 分钟',
        scheduledDate: '2026-10-20',
        timeZone: 'Mars/Olympus',
        plannedDurationMinutes: 20,
      ),
      throwsArgumentError,
    );

    expect(repository.createCallCount, 0);
  });

  test('仓储保存失败时，异常向上传递给调用者', () async {
    final repository = FailingMissionRepository();
    final missionService = MissionService(repository);

    // 所有输入都合法，失败只可能来自仓储。
    // create 没有 try/catch，await 会把仓储的错误继续交给测试。
    await expectLater(
      missionService.create(
        title: '阅读 20 分钟',
        scheduledDate: '2026-10-20',
        timeZone: 'Asia/Shanghai',
        plannedDurationMinutes: 20,
      ),
      throwsStateError,
    );
  });
  test('固定时刻使用排期时区校验，统一UTC，允许过去日期和跨UTC日界', () async {
    final repository = RecordingMissionRepository();
    final service = MissionService(repository);
    for (final clock in [
      '2020-01-02T00:15:00+08:00',
      '2020-01-02T23:59:00+08:00',
    ]) {
      await service.create(
        title: '固定任务',
        scheduledDate: '2020-01-02',
        timeZone: 'Asia/Shanghai',
        plannedDurationMinutes: 45,
        timePolicy: TimePolicy.fixed,
        fixedStartAt: DateTime.parse(clock),
      );
      final schedule = repository.receivedSchedule!;
      expect(schedule.timePolicy, TimePolicy.fixed);
      expect(schedule.fixedStartAt, DateTime.parse(clock).toUtc());
      expect(schedule.fixedStartAt!.isUtc, isTrue);
      expect(schedule.scheduledDate, '2020-01-02');
      expect(schedule.revisionNumber, 1);
      expect(repository.receivedMission!.cancelledAt, isNull);
    }
  });

  test('固定缺时刻、自选带时刻和时区日期不匹配全部在写入前拒绝', () async {
    final repository = RecordingMissionRepository();
    final service = MissionService(repository);
    for (final input in [
      (TimePolicy.fixed, null),
      (TimePolicy.flexible, DateTime.utc(2026, 10, 24, 6)),
      // UTC 10月24日16:00 已是上海10月25日，不能只比较UTC日期。
      (TimePolicy.fixed, DateTime.utc(2026, 10, 24, 16)),
      (TimePolicy.fixed, DateTime.utc(2026, 10, 23, 15, 59)),
    ]) {
      await expectLater(
        service.create(
          title: '非法排期',
          scheduledDate: '2026-10-24',
          timeZone: 'Asia/Shanghai',
          plannedDurationMinutes: 20,
          timePolicy: input.$1,
          fixedStartAt: input.$2,
        ),
        throwsArgumentError,
      );
    }
    expect(repository.createCallCount, 0);
  });
}

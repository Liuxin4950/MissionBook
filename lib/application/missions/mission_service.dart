import 'package:uuid/uuid.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../../domain/entities/mission.dart';
import '../../domain/entities/mission_schedule_revision.dart';
import '../../domain/entities/execution_plan.dart';
import '../../domain/repositories/mission_repository.dart';
import '../../domain/entities/scheduled_mission.dart';
import '../../domain/entities/mission_detail.dart';

/// 任务的应用业务入口：组织创建、查询和取消。
///
/// App 只创建一个 MissionService，页面通过方法名选择要做的事。
/// 本类负责输入检查与业务对象组织；SQL、行转换和事务保存仍由仓储完成。
class MissionService {
  // 调用者传入仓储对象，保存到下面的 repository 属性。
  MissionService(this.repository) {
    // 创建共享服务时准备时区资料，多个业务方法共用。
    tzdata.initializeTimeZones();
  }

  // 只依赖仓储接口；这里不需要知道 Companion 或数据库表。
  final MissionRepository repository;

  // 创建一个编号生成器，后面用 v4() 生成唯一编号。
  final Uuid uuid = const Uuid();

  /// 详情页传入当前任务编号；等待仓储事务完成，页面才能显示取消结果。
  Future<void> cancel({required String missionId}) async {
    if (missionId.trim().isEmpty) {
      throw ArgumentError('任务编号不能为空');
    }
    // 不使用页面之前读到的状态判断是否已取消；由仓储重读最新事实。
    await repository.cancel(missionId);
  }

  /// 创建独立、自报任务；默认自选时间，也可指定固定开始时刻。
  ///
  /// fixedStartAt 表达绝对时刻，保存前统一转 UTC；固定策略必须提供，
  /// 且在 timeZone 内属于 scheduledDate，自选策略则必须为空。
  /// 输入无效时以 ArgumentError 结束 Future，且不调用仓储。
  /// 仓储保存失败时继续向调用者传递异常；成功完成才表示三表事务已提交。
  Future<void> create({
    required String title,
    required String scheduledDate, // 例如 '2026-10-20'
    required String timeZone, // 例如 'Asia/Shanghai'
    required int plannedDurationMinutes,
    TimePolicy timePolicy = TimePolicy.flexible,
    DateTime? fixedStartAt,
  }) async {
    // trim 去掉标题首尾空白；全是空格也算没填写。
    final cleanTitle = title.trim();

    if (cleanTitle.isEmpty) {
      throw ArgumentError('任务标题不能为空');
    }

    if (plannedDurationMinutes <= 0) {
      throw ArgumentError('计划时长必须大于 0 分钟');
    }

    // 与查询入口共用日历校验，不把日期解释成设备本地的午夜时刻。
    validateScheduledDate(scheduledDate);

    // 查询时区资料；名称不存在时，转成明确的输入错误。
    final tz.Location location;
    try {
      location = tz.getLocation(timeZone);
    } on tz.LocationNotFoundException {
      throw ArgumentError('时区名称无效');
    }

    if (timePolicy == TimePolicy.fixed) {
      if (fixedStartAt == null) {
        throw ArgumentError('固定时间任务必须填写开始时刻');
      }
      // 页面提供的是绝对时刻；转回排期时区，检查有没有落到另一天。
      // 不要求晚于现在：规格允许过去日期仍保留为待开始。
      final localStart = tz.TZDateTime.from(fixedStartAt, location);
      final dateParts = scheduledDate.split('-');
      if (localStart.year != int.parse(dateParts[0]) ||
          localStart.month != int.parse(dateParts[1]) ||
          localStart.day != int.parse(dateParts[2])) {
        throw ArgumentError('固定开始时刻必须属于所选计划日期');
      }
    } else if (fixedStartAt != null) {
      throw ArgumentError('自选时间任务不能包含固定开始时刻');
    }

    // 校验通过后再生成编号、取得当前时间。
    // 同一次创建只取一次 now，让三个对象的创建时间一致。
    final missionId = uuid.v4();
    final now = DateTime.now().toUtc();

    final mission = Mission(
      id: missionId,
      title: cleanTitle,
      verificationPolicy: VerificationPolicy.selfReport,
      createdAt: now,
      updatedAt: now,
    );

    final schedule = MissionScheduleRevision(
      id: uuid.v4(), // 排期有自己的编号。
      missionId: missionId, // 但所属任务编号与上面相同。
      revisionNumber: 1,
      scheduledDate: scheduledDate,
      timeZone: timeZone,
      timePolicy: timePolicy,
      fixedStartAt: fixedStartAt?.toUtc(),
      plannedDurationMinutes: plannedDurationMinutes,
      changedAt: now,
    );

    final plan = ExecutionPlan(
      id: uuid.v4(), // 方案也有自己的编号。
      missionId: missionId,
      objective: cleanTitle, // 默认用任务标题作为具体目标。
      createdAt: now,
      updatedAt: now,
    );

    // 三个业务对象准备完毕，交给已有仓储。
    // await 等待仓储的整个事务完成；保存失败会把异常传回调用者。
    await repository.create(
      mission: mission,
      initialSchedule: schedule,
      executionPlan: plan,
    );
  }

  /// 检查 YYYY-MM-DD 日历日期，返回按仓储约定排序的查询结果。
  ///
  /// 无效输入以 ArgumentError 结束 Future，仓储错误继续向上传递。
  /// 今天页的 _loadMissions 提供所选日期，并等待此 Future 后显示结果。
  Future<List<ScheduledMission>> findScheduledOn({
    required String scheduledDate,
  }) async {
    validateScheduledDate(scheduledDate);
    // 这里只约束输入；读表和存储类型转换由真实仓储负责。
    final missions = await repository.findScheduledOn(scheduledDate);
    return missions;
  }

  /// 按编号读取任务详情；不存在返回 null，读取或转换失败通过 Future 传出错误。
  ///
  /// missionId 来自用户点击的那条任务，不用标题或列表位置代替唯一编号。
  Future<MissionDetail?> findDetail({required String missionId}) async {
    if (missionId.trim().isEmpty) {
      throw ArgumentError('任务编号不能为空');
    }

    // await 等仓储读完，再把完整结果交回详情页；这里不创建或修改任务。
    final detail = await repository.findDetail(missionId);
    if (detail != null) {
      // 页面需要按此时区换算时刻。无效时区在 Future 中报错，走页面的重试状态，
      // 避免等到 Widget 排版时才抛错，导致整个详情区域无法构建。
      tz.getLocation(detail.schedule.timeZone);
    }
    return detail;
  }
}

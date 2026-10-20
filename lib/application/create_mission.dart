import 'package:uuid/uuid.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../domain/entities/mission.dart';
import '../domain/entities/mission_schedule_revision.dart';
import '../domain/entities/execution_plan.dart';
import '../domain/repositories/mission_repository.dart';

class CreateMission {
  // 调用者传入仓储对象，保存到下面的 repository 属性。
  CreateMission(this.repository) {
    // 读入包内置的时区资料，供下面检查时区名称使用。
    tzdata.initializeTimeZones();
  }

  // 只依赖仓储接口；这里不需要知道 Companion 或数据库表。
  final MissionRepository repository;

  // 创建一个编号生成器，后面用 v4() 生成唯一编号。
  final Uuid uuid = const Uuid();

  // execute 是我们给这个业务方法取的名字。
  // 四个参数以后由页面收集，测试时也可以直接传入。
  Future<void> execute({
    required String title,
    required String scheduledDate, // 例如 '2026-10-20'
    required String timeZone, // 例如 'Asia/Shanghai'
    required int plannedDurationMinutes,
  }) async {
    // trim 去掉标题首尾空白；全是空格也算没填写。
    final cleanTitle = title.trim();

    if (cleanTitle.isEmpty) {
      throw ArgumentError('任务标题不能为空');
    }

    if (plannedDurationMinutes <= 0) {
      throw ArgumentError('计划时长必须大于 0 分钟');
    }

    // 先要求日期是四位年、两位月、两位日的格式。
    if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(scheduledDate)) {
      throw ArgumentError('日期格式必须为 YYYY-MM-DD');
    }

    // tryParse 尝试读取日期，失败时返回 null。
    // Dart 会把“2 月 30 日”顺延，因此还要和原日期比较。
    final date = DateTime.tryParse(scheduledDate);
    if (date == null ||
        date.toIso8601String().substring(0, 10) != scheduledDate) {
      throw ArgumentError('计划日期不存在');
    }

    // 查询时区资料；名称不存在时，转成明确的输入错误。
    try {
      tz.getLocation(timeZone);
    } on tz.LocationNotFoundException {
      throw ArgumentError('时区名称无效');
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
      timePolicy: TimePolicy.flexible,
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
}

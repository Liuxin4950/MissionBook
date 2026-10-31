/// 检查排期日期的格式及年月日；无效时抛出 [ArgumentError]。
///
/// 创建和查询共用此规则。这里只验证日历日期，不查询时区或写入数据库。
void validateScheduledDate(String scheduledDate) {
  final dateFormat = RegExp(r'^\d{4}-\d{2}-\d{2}$');
  if (scheduledDate.length != 10 || !dateFormat.hasMatch(scheduledDate)) {
    throw ArgumentError('日期格式必须为 YYYY-MM-DD');
  }

  // 格式通过后再取出年月日，因此三个字符串都可以安全转换为整数。
  final dateParts = scheduledDate.split('-');
  final year = int.parse(dateParts[0]);
  final month = int.parse(dateParts[1]);
  final day = int.parse(dateParts[2]);

  // 借用 UTC 日历核对年月日，避开设备本地时区的跳日与夏令时规则。
  // 这里的 DateTime 只用于校验；保存和查询仍使用原来的日期字符串。
  // DateTime 会把“2 月 30 日”顺延，因此还要分别比较三个日历字段。
  final calendarDate = DateTime.utc(year, month, day);
  if (calendarDate.year != year ||
      calendarDate.month != month ||
      calendarDate.day != day) {
    throw ArgumentError('计划日期不存在');
  }
}

/// 产品默认排期时区；表单、今天页、时间轴和助手上下文共用，避免各自写字面量。
const defaultScheduleTimeZone = 'Asia/Shanghai';

/// 时间安排策略，决定任务是否指定固定开始时刻。
enum TimePolicy {
  flexible, // 自选时间：只安排日期，由用户决定当天何时开始
  fixed, // 固定时间：安排日期，同时指定开始时刻
}

/// 【业务实体】任务的一次完整排期，由 mission_schedule_revisions 表保存。
///
/// 修改时新增版本，保留旧版本。本类不是“任务＋排期”的查询组合；
/// 它只表达一条排期的业务内容，数据库列定义仍位于 data/local/tables/。
class MissionScheduleRevision {
  const MissionScheduleRevision({
    required this.id,
    required this.missionId,
    required this.revisionNumber,
    required this.scheduledDate,
    required this.timeZone,
    required this.plannedDurationMinutes,
    required this.changedAt,
    this.timePolicy = TimePolicy.flexible,
    this.fixedStartAt,
    this.evidenceDeadlineAt,
    this.changeReason,
  });

  /// 排期记录自身的唯一编号。
  /// 同一个任务的不同排期版本，各有不同的 id。
  final String id;

  /// 所属任务的编号，对应 Mission.id。
  /// 通过它知道这条排期属于哪个任务。
  final String missionId;

  /// 排期版本号：第一次为 1，每次有效修改后加 1。
  /// 同一任务中，版本号最大的记录就是当前排期。
  final int revisionNumber;

  /// 计划在哪一天做，格式为 YYYY-MM-DD，例如 2026-10-19。
  /// 表示下面 timeZone 所在时区的日期，不包含几点几分。
  final String scheduledDate;

  /// 这次排期采用的时区，例如 Asia/Shanghai（上海时区）。
  /// 用来解释计划日期，以及判断固定开始时间是否属于这一天。
  final String timeZone;

  /// 时间安排方式，默认是 flexible（自选时间）。
  final TimePolicy timePolicy;

  /// 固定开始时刻，约定使用 UTC DateTime。
  /// fixed 策略必须提供；flexible 策略必须为空。
  /// 这是计划开始时刻，实际开始时刻由执行事件记录。
  final DateTime? fixedStartAt;

  /// 计划投入多少分钟，例如 45 表示计划做 45 分钟。
  /// 必须是正整数；它不是已经执行的实际时长。
  final int plannedDurationMinutes;

  /// 强制提交材料的截止时刻，约定使用 UTC DateTime。
  /// 任务采用强制材料策略时必须提供；其他策略必须为空。
  /// 它限制材料提交，不会在到点时自动停止任务执行。
  final DateTime? evidenceDeadlineAt;

  /// 用户填写的改期原因，例如“下午有课，改到晚上”。
  /// 可以不填写；第一次创建排期时通常为空。
  final String? changeReason;

  /// 这条排期版本产生的时刻，约定使用 UTC DateTime。
  /// 第一次创建记录创建时刻，后续版本记录改期时刻。
  /// 它不是任务计划开始的时刻。
  final DateTime changedAt;
}

// 时间安排策略：决定任务是否指定固定开始时刻。
enum TimePolicy {
  flexible, // 自选时间：只安排日期，由用户决定当天何时开始
  fixed, // 固定时间：安排日期，同时指定开始时刻
}

// 任务的一次完整排期记录。
// 修改排期时新增一个版本，保留旧版本。
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

  // 排期记录自身的唯一编号。
  // 同一个任务的不同排期版本，各有不同的 id。
  final String id;

  // 所属任务的编号，对应 Mission.id。
  // 通过它知道这条排期属于哪个任务。
  final String missionId;

  // 排期版本号：第一次为 1，每次有效修改后加 1。
  // 同一任务中，版本号最大的记录就是当前排期。
  final int revisionNumber;

  // 计划在哪一天做，格式为 YYYY-MM-DD，例如 2026-10-19。
  // 表示下面 timeZone 所在时区的日期，不包含几点几分。
  final String scheduledDate;

  // 这次排期采用的时区，例如 Asia/Shanghai（上海时区）。
  // 用来解释计划日期，以及判断固定开始时间是否属于这一天。
  final String timeZone;

  // 时间安排方式，默认是 flexible（自选时间）。
  final TimePolicy timePolicy;

  // 固定开始时刻，约定使用 UTC DateTime。
  // fixed 策略必须提供；flexible 策略必须为空。
  // 这是计划开始时刻，实际开始时刻由执行事件记录。
  final DateTime? fixedStartAt;

  // 计划投入多少分钟，例如 45 表示计划做 45 分钟。
  // 必须是正整数；它不是已经执行的实际时长。
  final int plannedDurationMinutes;

  // 强制提交材料的截止时刻，约定使用 UTC DateTime。
  // 任务采用强制材料策略时必须提供；其他策略必须为空。
  // 它限制材料提交，不会在到点时自动停止任务执行。
  final DateTime? evidenceDeadlineAt;

  // 用户填写的改期原因，例如“下午有课，改到晚上”。
  // 可以不填写；第一次创建排期时通常为空。
  final String? changeReason;

  // 这条排期版本产生的时刻，约定使用 UTC DateTime。
  // 第一次创建记录创建时刻，后续版本记录改期时刻。
  // 它不是任务计划开始的时刻。
  final DateTime changedAt;
}
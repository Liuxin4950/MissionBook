import 'package:timezone/timezone.dart' as tz;

import '../../domain/entities/mission_schedule_revision.dart';
import '../../domain/entities/scheduled_mission.dart';
import '../../domain/entities/mission_phase.dart';
import '../../domain/entities/execution_event.dart';
import '../missions/shared/mission_phase_display.dart';

// 今天页专用的显示工具。不依赖 Flutter，不访问数据库。
// 页面通过这里取得日期文字；一次查询成功后通过 groupMissionsForDisplay 整理整份结果。
/// 今天页默认使用的排期时区。
const todayScheduleTimeZone = 'Asia/Shanghai';
const _weekdays = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];

/// 取得默认排期时区中的当前时间，供默认日期和“回到今天”使用。
DateTime todayInScheduleTimeZone() =>
    tz.TZDateTime.now(tz.getLocation(todayScheduleTimeZone));

/// 将所选日历日期转换为查询和新建表单共用的 YYYY-MM-DD 日期键。
String scheduleDateKey(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-'
    '${date.month.toString().padLeft(2, '0')}-'
    '${date.day.toString().padLeft(2, '0')}';

/// 将所选日历日期转换为页头的月日和星期文字。
String scheduleDateLabel(DateTime date) =>
    '${date.month}月${date.day}日 · ${_weekdays[date.weekday - 1]}';

/// 为业务查询结果准备显示文字；自选任务先放未开始，再放执行中、待补和已结束。
///
/// 由 TodayPage._loadMissions 在查询成功后调用一次；不查询或写入数据库。
TodayMissionGroups groupMissionsForDisplay(List<ScheduledMission> missions) {
  final fixed = <TodayMissionItem>[];
  final flexible = <TodayMissionItem>[];
  final activeFlexible = <TodayMissionItem>[];
  final pendingFlexible = <TodayMissionItem>[];
  final closedFlexible = <TodayMissionItem>[];
  final cancelled = <TodayMissionItem>[];
  for (final mission in missions) {
    final item = _missionItem(mission);
    if (item.isCancelled) {
      cancelled.add(item);
    } else if (item.isFixed) {
      fixed.add(item);
    } else {
      // 只调整显示顺序，同阶段仍沿用仓储的创建顺序；不把排序写成业务状态。
      switch (item.phase) {
        case MissionPhase.notStarted:
          flexible.add(item);
        case MissionPhase.running:
        case MissionPhase.paused:
          activeFlexible.add(item);
        case MissionPhase.evidencePending:
        case MissionPhase.reportPending:
          pendingFlexible.add(item);
        case MissionPhase.closed:
        case MissionPhase.cancelled:
          closedFlexible.add(item);
      }
    }
  }
  return TodayMissionGroups(
    fixed: List.unmodifiable(fixed),
    flexible: List.unmodifiable([
      ...flexible,
      ...activeFlexible,
      ...pendingFlexible,
      ...closedFlexible,
    ]),
    cancelled: List.unmodifiable(cancelled),
  );
}

// 一项任务的展示文字集中在这里准备。Widget 只读取字段，不重复转换。
TodayMissionItem _missionItem(ScheduledMission item) {
  final schedule = item.schedule;
  final isFixed = schedule.timePolicy == TimePolicy.fixed;
  final isCancelled = item.mission.cancelledAt != null;
  final executionLabel = item.phase == MissionPhase.notStarted
      ? ''
      : '${phaseLabel(item.phase)} · ';
  var startTime = '';
  if (isFixed) {
    final startAt = schedule.fixedStartAt;
    if (startAt == null) {
      throw const FormatException('固定任务缺少开始时刻');
    }
    final local = tz.TZDateTime.from(
      startAt,
      tz.getLocation(schedule.timeZone),
    );
    startTime =
        '${local.hour.toString().padLeft(2, '0')}:'
        '${local.minute.toString().padLeft(2, '0')}';
  }
  return TodayMissionItem(
    phase: item.phase,
    events: item.events,
    id: item.mission.id,
    title: item.mission.title,
    isFixed: isFixed,
    isCancelled: isCancelled,
    startTime: startTime,
    fixedStartAt: schedule.fixedStartAt,
    plannedDurationMinutes: schedule.plannedDurationMinutes,
    durationLabel:
        '${isCancelled ? '已取消 · ' : executionLabel}'
        '计划 ${schedule.plannedDurationMinutes} 分钟',
    timeZoneLabel: schedule.timeZone == todayScheduleTimeZone
        ? null
        : schedule.timeZone,
  );
}

/// 今天页整理后的三个显示分区，不拥有数据库或页面交互。
// 页面只保存整理后的这一份结果。三个区域共用同一批数据，没有额外查询。
class TodayMissionGroups {
  const TodayMissionGroups({
    required this.fixed,
    required this.flexible,
    required this.cancelled,
  });

  const TodayMissionGroups.empty()
    : fixed = const [],
      flexible = const [],
      cancelled = const [];

  final List<TodayMissionItem> fixed;
  final List<TodayMissionItem> flexible;
  final List<TodayMissionItem> cancelled;

  bool get isEmpty => fixed.isEmpty && flexible.isEmpty && cancelled.isEmpty;
}

/// 一项任务的显示投影，不替代业务事实，也不写回数据库。
// id 用于稳定的列表 Key，也在点击任务时传给详情查询入口。
class TodayMissionItem {
  const TodayMissionItem({
    required this.id,
    required this.title,
    required this.isFixed,
    required this.isCancelled,
    required this.startTime,
    required this.fixedStartAt,
    required this.plannedDurationMinutes,
    required this.durationLabel,
    required this.timeZoneLabel,
    this.phase = MissionPhase.notStarted,
    this.events = const [],
  });

  final String id;
  final String title;
  final bool isFixed;
  final bool isCancelled;
  final String startTime;
  final DateTime? fixedStartAt;
  final int plannedDurationMinutes;
  final String durationLabel;
  final String? timeZoneLabel;
  final MissionPhase phase;
  final List<ExecutionEvent> events;
}

/// 当前是否处于计划时间段：[开始，开始 + 计划分钟数)。仅用于视觉强调。
/// 不表示用户已开始执行，也不生成执行、完成或取消事实。
bool isInPlannedTimeSlot(TodayMissionItem item, DateTime now) {
  final start = item.fixedStartAt;
  if (!item.isFixed || item.isCancelled || start == null) return false;
  final end = start.add(Duration(minutes: item.plannedDurationMinutes));
  return !now.isBefore(start) && now.isBefore(end);
}

/// 一条任务自身计划时段的经过比例，供与卡片等高的轨道段使用。
double plannedTimeSlotProgress(TodayMissionItem item, DateTime now) {
  final start = item.fixedStartAt;
  if (!item.isFixed ||
      item.isCancelled ||
      start == null ||
      item.plannedDurationMinutes <= 0) {
    return 0;
  }
  return timelineSegmentProgress(
    start,
    start.add(Duration(minutes: item.plannedDurationMinutes)),
    now,
  );
}

/// 将真实时刻投影到两个相邻开始节点之间；节点间距仍沿用紧凑排版。
/// 同一时刻的多个节点一起到达，不进行除零运算。
double timelineSegmentProgress(DateTime start, DateTime end, DateTime now) {
  if (now.isBefore(start)) return 0;
  if (!now.isBefore(end)) return 1;
  final interval = end.difference(start).inMicroseconds;
  if (interval <= 0) return 1;
  return now.difference(start).inMicroseconds / interval;
}

/// 首页展示当前时段（否则下一项）附近的连续窗口，保留一项前情。
/// 列表已按开始时间排序；全部结束时展示末尾，空列表直接返回。
List<TodayMissionItem> schedulePreview(
  List<TodayMissionItem> items,
  DateTime now, {
  int limit = 4,
}) {
  assert(limit > 0);
  if (items.length <= limit) return items;
  var focus = items.indexWhere((item) => isInPlannedTimeSlot(item, now));
  if (focus < 0) {
    focus = items.indexWhere((item) => item.fixedStartAt!.isAfter(now));
  }
  if (focus < 0) focus = items.length - 1;
  final start = (focus - 1).clamp(0, items.length - limit);
  return items.sublist(start, start + limit);
}

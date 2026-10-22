import 'package:timezone/timezone.dart' as tz;

import '../../domain/entities/mission_schedule_revision.dart';
import '../../domain/entities/scheduled_mission.dart';

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

/// 为业务查询结果准备显示文字，按固定、自选、已取消分区并保留原顺序。
///
/// 由 TodayPage._loadMissions 在查询成功后调用一次；不查询或写入数据库。
TodayMissionGroups groupMissionsForDisplay(List<ScheduledMission> missions) {
  final fixed = <TodayMissionItem>[];
  final flexible = <TodayMissionItem>[];
  final cancelled = <TodayMissionItem>[];
  for (final mission in missions) {
    final item = _missionItem(mission);
    if (item.isCancelled) {
      cancelled.add(item);
    } else if (item.isFixed) {
      fixed.add(item);
    } else {
      flexible.add(item);
    }
  }
  return TodayMissionGroups(
    fixed: List.unmodifiable(fixed),
    flexible: List.unmodifiable(flexible),
    cancelled: List.unmodifiable(cancelled),
  );
}

// 一项任务的展示文字集中在这里准备。Widget 只读取字段，不重复转换。
TodayMissionItem _missionItem(ScheduledMission item) {
  final schedule = item.schedule;
  final isFixed = schedule.timePolicy == TimePolicy.fixed;
  final isCancelled = item.mission.cancelledAt != null;
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
    id: item.mission.id,
    title: item.mission.title,
    isFixed: isFixed,
    isCancelled: isCancelled,
    startTime: startTime,
    durationLabel:
        '${isCancelled ? '已取消 · ' : ''}'
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
// id 保留给列表 Key 和将来的任务点击入口使用。
class TodayMissionItem {
  const TodayMissionItem({
    required this.id,
    required this.title,
    required this.isFixed,
    required this.isCancelled,
    required this.startTime,
    required this.durationLabel,
    required this.timeZoneLabel,
  });

  final String id;
  final String title;
  final bool isFixed;
  final bool isCancelled;
  final String startTime;
  final String durationLabel;
  final String? timeZoneLabel;
}

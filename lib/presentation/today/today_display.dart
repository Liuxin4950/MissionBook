import 'package:timezone/timezone.dart' as tz;

import '../../domain/entities/mission_schedule_revision.dart';
import '../../domain/entities/scheduled_mission.dart';

// 今天页专用的显示工具。不依赖 Flutter，不访问数据库。
// 页面通过这里取得日期文字；一次查询成功后通过 missions 整理整份结果。
abstract final class TodayDisplay {
  static const timeZone = 'Asia/Shanghai';
  static const _weekdays = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];

  static DateTime now() => tz.TZDateTime.now(tz.getLocation(timeZone));

  // 日期选择 → 查询入口、新建表单：两个入口使用同一份 YYYY-MM-DD 规则。
  static String dateKey(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';

  static String dateLabel(DateTime date) =>
      '${date.month}月${date.day}日 · ${_weekdays[date.weekday - 1]}';

  // 调用者：TodayPage._loadMissions。输入已经是业务对象，不是数据库行。
  // 按仓储返回顺序走一遍：准备文字，然后分进对应区域；这里不重新排序。
  static TodayMissionGroups missions(List<ScheduledMission> missions) {
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
  static TodayMissionItem _missionItem(ScheduledMission item) {
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
      timeZoneLabel: schedule.timeZone == timeZone ? null : schedule.timeZone,
    );
  }
}

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

// 显示结果，不替代 Mission/排期业务对象，也不写回数据库。
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

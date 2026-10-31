import 'dart:math' as math;

import 'package:timezone/timezone.dart' as tz;

import '../../../domain/entities/execution_event.dart';
import '../../../domain/entities/mission_detail.dart';
import '../../../domain/entities/mission_schedule_revision.dart';
import '../../../domain/entities/scheduled_mission.dart';
import '../../../domain/entities/mission_phase.dart';
import '../../../domain/rules/execution_time_rules.dart';

// 同一时间轴不能混用各任务的钟面时间；默认时区由领域统一定义。

DateTime timetableNow(DateTime instant) =>
    tz.TZDateTime.from(instant, tz.getLocation(defaultScheduleTimeZone));

String timetableClock(double minute) {
  final value = minute.floor();
  return '${(value ~/ 60).toString().padLeft(2, '0')}:'
      '${(value % 60).toString().padLeft(2, '0')}';
}

/// 所选日期内的占位，不改变任务阶段或保存任何执行事实。
class TimetableSlot {
  TimetableSlot(
    this.detail,
    this.start,
    this.end, {
    this.continuesBefore = false,
    this.continuesAfter = false,
    this.actual = false,
  });

  final ScheduledMission detail;
  final double start; // 相对所选日期零点的分钟数，跨日任务已裁切。
  final double end;
  final bool continuesBefore; // 真实起点在前一天，当前只显示续入部分。
  final bool continuesAfter; // 真实终点在后一天。
  // false：固定任务的计划时段；true：自选任务按执行记录绘制的实际区间。
  final bool actual;
  int column = 0;
  int columns = 1;
  final conflicts = <TimetableConflict>[];

  String get id => detail.mission.id;
  String get timeLabel =>
      '${actual ? '实际 ' : ''}'
      '${timetableClock(start)}–${timetableClock(end)}'
      '${continuesBefore ? ' · 接前日' : ''}${continuesAfter ? ' · 续次日' : ''}';

  // 多个冲突区间取并集，三项同时重叠时不重复累计分钟。
  double get conflictMinutes {
    if (conflicts.isEmpty) return 0;
    final sorted = [...conflicts]..sort((a, b) => a.start.compareTo(b.start));
    var start = sorted.first.start;
    var end = sorted.first.end;
    var total = 0.0;
    for (final conflict in sorted.skip(1)) {
      if (conflict.start <= end) {
        end = math.max(end, conflict.end);
      } else {
        total += end - start;
        start = conflict.start;
        end = conflict.end;
      }
    }
    return total + end - start;
  }
}

/// 两个任务在当前日期内实际重叠的计划区间。
class TimetableConflict {
  const TimetableConflict(this.first, this.second, this.start, this.end);
  final TimetableSlot first;
  final TimetableSlot second;
  final double start;
  final double end;
}

/// 时间轴的显示窗口（相对所选日期零点的分钟数）。
///
/// 内容前后各留一刻钟，向外取整到半点；至少保留 [minWindow] 分钟上下文。
/// 窗口始终覆盖所有可见时段，不压缩任务之间的真实时间距离。
/// 没有任何占位时回退到默认的 8:00–18:00。
({double start, double end}) timetableWindow(
  Iterable<TimetableSlot> slots, {
  double? nowMinute,
  double minWindow = 120,
}) {
  double? lowest = nowMinute;
  double? highest = nowMinute;
  for (final slot in slots) {
    lowest = lowest == null ? slot.start : math.min(lowest, slot.start);
    highest = highest == null ? slot.end : math.max(highest, slot.end);
  }
  if (lowest == null || highest == null) {
    return (start: 8 * 60, end: 18 * 60);
  }
  var start = math.max(0.0, ((lowest - 15) / 30).floor() * 30.0);
  var end = math.min(1440.0, ((highest + 15) / 30).ceil() * 30.0);
  // 内容太少时按半小时向两侧补齐；贴近一天两端就只向另一侧扩。
  while (end - start < minWindow && (start > 0 || end < 1440)) {
    if (start > 0) start -= 30;
    if (end - start < minWindow && end < 1440) end += 30;
  }
  return (start: start, end: end);
}

/// 自选任务的已知执行区间：从 START 到 END（未结束则到 now）。
/// 没有执行记录或仍在等待 now 时返回 null，这类任务不上图、只在列表阅读。
({DateTime from, DateTime until})? _actualSpan(
  ScheduledMission detail,
  DateTime? now,
) {
  if (detail.events.isEmpty) return null;
  if (detail.events.first.isRetrospective) return null;
  final from = detail.events.first.occurredAt; // 时间线第一条必为 START。
  if (now == null && detail.events.last.type != ExecutionEventType.end) {
    return null;
  }
  // 与专注时长复用同一上界：系统回拨时至少显示到最后一条已发生的事件。
  final times = calculateExecutionTimes(detail.events, now ?? from);
  return (from: from, until: from.add(times.elapsed));
}

({DateTime from, DateTime until})? _displaySpan(
  ScheduledMission detail,
  DateTime? now,
) {
  if (detail.phase == MissionPhase.cancelled) return null;
  final fixedStart = detail.schedule.fixedStartAt;
  return fixedStart == null
      ? _actualSpan(detail, now)
      : (
          from: fixedStart,
          until: fixedStart.add(
            Duration(minutes: detail.schedule.plannedDurationMinutes),
          ),
        );
}

/// 全部日期分组同时包含计划列表日期和图上区间覆盖的日期，跨日事实不会失联。
Iterable<String> timetableDateKeys(MissionDetail detail, DateTime now) sync* {
  final span = _displaySpan(_scheduled(detail), now);
  if (detail.schedule.fixedStartAt == null || span == null) {
    yield detail.schedule.scheduledDate;
  }
  if (span == null) return;
  final from = timetableNow(span.from);
  // 半开区间：刚好在次日 00:00 结束，不多建次日分组。
  final until = timetableNow(
    span.until.isAfter(span.from)
        ? span.until.subtract(const Duration(microseconds: 1))
        : span.from,
  );
  var day = DateTime.utc(from.year, from.month, from.day);
  final last = DateTime.utc(until.year, until.month, until.day);
  while (!day.isAfter(last)) {
    yield '${day.year.toString().padLeft(4, '0')}-'
        '${day.month.toString().padLeft(2, '0')}-'
        '${day.day.toString().padLeft(2, '0')}';
    day = DateTime.utc(day.year, day.month, day.day + 1);
  }
}

/// 当日完整计划用于检测冲突，筛选后的任务单独分配显示列。
class TimetableDay {
  const TimetableDay(this.slots, this.allSlots, this.conflicts);
  final List<TimetableSlot> slots;
  final List<TimetableSlot> allSlots;
  final List<TimetableConflict> conflicts;

  factory TimetableDay.build(
    List<MissionDetail> records,
    DateTime day, {
    bool Function(MissionDetail)? visible,
    DateTime? now,
    double minimumDisplayMinutes = 0,
  }) {
    final visibleIds = visible == null
        ? null
        : {
            for (final detail in records)
              if (visible(detail)) detail.mission.id,
          };
    return TimetableDay.fromScheduled(
      records.map(_scheduled).toList(),
      day,
      visible: visibleIds == null
          ? null
          : (task) => visibleIds.contains(task.mission.id),
      now: now,
      minimumDisplayMinutes: minimumDisplayMinutes,
    );
  }

  /// 今天页已有排期投影，可直接复用时间轴，无需逐项重查完整详情。
  factory TimetableDay.fromScheduled(
    List<ScheduledMission> records,
    DateTime day, {
    bool Function(ScheduledMission)? visible,
    DateTime? now,
    double minimumDisplayMinutes = 0,
  }) {
    final zone = tz.getLocation(defaultScheduleTimeZone);
    final start = tz.TZDateTime(zone, day.year, day.month, day.day);
    final end = tz.TZDateTime(zone, day.year, day.month, day.day + 1);
    final all = <TimetableSlot>[]; // 固定任务的计划时段：参与冲突检测。
    final actual = <TimetableSlot>[]; // 自选任务的实际区间：只参与显示排布。
    for (final detail in records) {
      final span = _displaySpan(detail, now);
      if (span == null) continue;
      final from = detail.schedule.fixedStartAt;
      final spanFrom = span.from;
      final spanUntil = span.until;
      // 半开区间：前项恰好结束、后项恰好开始不算冲突。
      if (!spanFrom.isBefore(end) ||
          (spanUntil == spanFrom
              ? spanFrom.isBefore(start)
              : !spanUntil.isAfter(start))) {
        continue;
      }
      final slot = TimetableSlot(
        detail,
        math.max(0, spanFrom.difference(start).inMilliseconds / 60000),
        math.min(1440, spanUntil.difference(start).inMilliseconds / 60000),
        continuesBefore: spanFrom.isBefore(start),
        continuesAfter: spanUntil.isAfter(end),
        actual: from == null,
      );
      (from == null ? actual : all).add(slot);
    }
    all.sort((a, b) {
      final order = a.start.compareTo(b.start);
      return order != 0 ? order : a.id.compareTo(b.id);
    });
    actual.sort((a, b) {
      final order = a.start.compareTo(b.start);
      return order != 0 ? order : a.id.compareTo(b.id);
    });
    final conflicts = <TimetableConflict>[];
    for (var i = 0; i < all.length; i++) {
      for (var j = i + 1; j < all.length; j++) {
        if (all[j].start >= all[i].end) break;
        final conflict = TimetableConflict(
          all[i],
          all[j],
          all[j].start,
          math.min(all[i].end, all[j].end),
        );
        all[i].conflicts.add(conflict);
        all[j].conflicts.add(conflict);
        conflicts.add(conflict);
      }
    }
    // 计划与实际区间一起排布显示列，谁也不遮住谁；
    // “计划时间冲突”仍只统计固定任务的计划时段。
    final shown =
        [
          ...all.where((slot) => visible?.call(slot.detail) ?? true),
          ...actual.where((slot) => visible?.call(slot.detail) ?? true),
        ]..sort((a, b) {
          final order = a.start.compareTo(b.start);
          return order != 0 ? order : a.id.compareTo(b.id);
        });
    var group = <TimetableSlot>[];
    var groupEnd = 0.0;
    // 短条为了容纳标题会增高；只在显示列排布中预留高度，不改变真实冲突区间。
    double displayEnd(TimetableSlot slot) =>
        math.max(slot.end, slot.start + minimumDisplayMinutes);
    void placeGroup() {
      final ends = <double>[];
      for (final slot in group) {
        var column = ends.indexWhere((end) => end <= slot.start);
        if (column < 0) {
          column = ends.length;
          ends.add(displayEnd(slot));
        } else {
          ends[column] = displayEnd(slot);
        }
        slot.column = column;
      }
      for (final slot in group) {
        slot.columns = ends.length;
      }
    }

    for (final slot in shown) {
      if (group.isNotEmpty && slot.start >= groupEnd) {
        placeGroup();
        group = [];
      }
      group.add(slot);
      groupEnd = group.length == 1
          ? displayEnd(slot)
          : math.max(groupEnd, displayEnd(slot));
    }
    placeGroup();
    final shownIds = shown.map((slot) => slot.id).toSet();
    return TimetableDay(
      shown,
      all,
      conflicts
          .where(
            (c) =>
                shownIds.contains(c.first.id) || shownIds.contains(c.second.id),
          )
          .toList(),
    );
  }
}

ScheduledMission _scheduled(MissionDetail detail) => ScheduledMission(
  mission: detail.mission,
  schedule: detail.schedule,
  phase: detail.phase,
  events: detail.events,
);

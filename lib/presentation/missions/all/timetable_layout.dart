import 'dart:math' as math;

import 'package:timezone/timezone.dart' as tz;

import '../../../domain/entities/mission_detail.dart';
import '../../../domain/entities/mission_phase.dart';

// 与今天页默认排期时区一致；同一时间轴不能混用各任务的钟面时间。
const timetableTimeZone = 'Asia/Shanghai';

DateTime timetableNow(DateTime instant) =>
    tz.TZDateTime.from(instant, tz.getLocation(timetableTimeZone));

String timetableClock(double minute) {
  final value = minute.floor();
  return '${(value ~/ 60).toString().padLeft(2, '0')}:'
      '${(value % 60).toString().padLeft(2, '0')}';
}

/// 所选日期内的计划占位，不改变任务阶段或保存任何执行事实。
class TimetableSlot {
  TimetableSlot(
    this.detail,
    this.start,
    this.end, {
    this.continuesBefore = false,
    this.continuesAfter = false,
  });

  final MissionDetail detail;
  final double start; // 相对所选日期零点的分钟数，跨日任务已裁切。
  final double end;
  final bool continuesBefore; // 真实计划起点在前一天，当前只显示续入部分。
  final bool continuesAfter; // 真实计划终点在后一天。
  int column = 0;
  int columns = 1;
  final conflicts = <TimetableConflict>[];

  String get id => detail.mission.id;
  String get timeLabel =>
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
  }) {
    final zone = tz.getLocation(timetableTimeZone);
    final start = tz.TZDateTime(zone, day.year, day.month, day.day);
    final end = tz.TZDateTime(zone, day.year, day.month, day.day + 1);
    final all = <TimetableSlot>[];
    for (final detail in records) {
      final from = detail.schedule.fixedStartAt;
      if (from == null || detail.phase == MissionPhase.cancelled) continue;
      final until = from.add(
        Duration(minutes: detail.schedule.plannedDurationMinutes),
      );
      // 半开区间：前项恰好结束、后项恰好开始不算冲突。
      if (!from.isBefore(end) || !until.isAfter(start)) continue;
      all.add(
        TimetableSlot(
          detail,
          math.max(0, from.difference(start).inMilliseconds / 60000),
          math.min(1440, until.difference(start).inMilliseconds / 60000),
          continuesBefore: from.isBefore(start),
          continuesAfter: until.isAfter(end),
        ),
      );
    }
    all.sort((a, b) {
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
    final shown = all
        .where((slot) => visible?.call(slot.detail) ?? true)
        .toList();
    var group = <TimetableSlot>[];
    var groupEnd = 0.0;
    void placeGroup() {
      final ends = <double>[];
      for (final slot in group) {
        var column = ends.indexWhere((end) => end <= slot.start);
        if (column < 0) {
          column = ends.length;
          ends.add(slot.end);
        } else {
          ends[column] = slot.end;
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
      groupEnd = group.length == 1 ? slot.end : math.max(groupEnd, slot.end);
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

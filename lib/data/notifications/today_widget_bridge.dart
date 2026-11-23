import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:timezone/timezone.dart' as tz;

import '../../application/missions/mission_service.dart';
import '../../domain/entities/mission_phase.dart';
import '../../domain/entities/mission_schedule_revision.dart';
import '../../domain/entities/scheduled_mission.dart';
import '../../domain/rules/scheduled_execution_rules.dart';

/// A bounded, read-only projection for Android's launcher, not a task store.
Future<String> buildTodayWidgetSnapshot({
  required DateTime now,
  required Future<List<ScheduledMission>> Function(String date) query,
}) async {
  final location = tz.getLocation(defaultScheduleTimeZone);
  final today = tz.TZDateTime.from(now, location);
  final days = <Map<String, Object>>[];
  for (var offset = 0; offset < 2; offset++) {
    final day = tz.TZDateTime(
      location,
      today.year,
      today.month,
      today.day + offset,
    );
    final date = day.toIso8601String().substring(0, 10);
    final missions = (await query(
      date,
    )).where((item) => item.phase != MissionPhase.cancelled).toList();
    days.add({
      'date': date,
      'total': missions.length,
      'rows': [for (final item in missions.take(5)) _widgetRow(item)],
      if (_featured(missions, now) case final item?)
        'featured': _widgetRow(item),
    });
  }
  return jsonEncode({'schemaVersion': 1, 'days': days});
}

// Keep the list chronological, but give the small card an actionable item.
ScheduledMission? _featured(List<ScheduledMission> missions, DateTime now) {
  const priorities = [
    MissionPhase.running,
    MissionPhase.paused,
    MissionPhase.reportPending,
  ];
  for (final phase in priorities) {
    for (final mission in missions) {
      if (mission.phase == phase) return mission;
    }
  }
  for (final mission in missions) {
    if (mission.phase == MissionPhase.notStarted &&
        mission.schedule.fixedStartAt?.isAfter(now) == true) {
      return mission;
    }
  }
  for (final mission in missions) {
    if (mission.phase == MissionPhase.notStarted &&
        mission.schedule.fixedStartAt == null) {
      return mission;
    }
  }
  return missions.firstOrNull;
}

Map<String, Object?> _widgetRow(ScheduledMission item) {
  final schedule = item.schedule;
  final start = schedule.fixedStartAt;
  final timeZone = tz.getLocation(schedule.timeZone);
  String formatTime(DateTime time) {
    final local = tz.TZDateTime.from(time, timeZone);
    return '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  }

  return {
    'id': item.mission.id,
    'title': String.fromCharCodes(item.mission.title.runes.take(160)),
    'start': start == null ? null : formatTime(start),
    'end': start == null
        ? null
        : formatTime(
            fixedTimeSlotEnd(
              start,
              schedule.plannedDurationMinutes,
              item.events,
            ),
          ),
    'phase': item.phase.name,
  };
}

/// Publishes on initial load, app resume and committed mission changes.
class TodayWidgetBridge {
  TodayWidgetBridge(this._missions) {
    _changes = _missions.changes.listen((_) => refresh());
    refresh();
  }

  static const channel = MethodChannel('mission_book/today_widget');
  static const _retryDelay = Duration(seconds: 30);
  final MissionService _missions;
  late final StreamSubscription<void> _changes;
  Timer? _retry;
  Future<void>? _inFlight;
  bool _pending = false;
  bool _closed = false;

  void refresh() {
    if (_closed) return;
    _retry?.cancel();
    _retry = null;
    _pending = true;
    _inFlight ??= _drain().whenComplete(() {
      _inFlight = null;
      if (_pending && !_closed) refresh();
    });
  }

  Future<void> _drain() async {
    while (_pending && !_closed) {
      _pending = false;
      try {
        await publish(_missions);
      } catch (error) {
        debugPrint('桌面任务快照更新失败：${error.runtimeType}');
        if (!_closed && _retry == null && _pending == false) {
          // A transient channel or read failure must not freeze an old snapshot
          // until the next commit; retry with a bounded delay.
          _retry = Timer(_retryDelay, () {
            _retry = null;
            refresh();
          });
        }
      }
    }
  }

  Future<void> close() async {
    _closed = true;
    _retry?.cancel();
    _retry = null;
    await _changes.cancel();
    await _inFlight;
  }

  static Future<void> publish(MissionService missions) async {
    final token = await channel.invokeMethod<int>('beginSnapshot');
    if (token == null) return; // No launcher instances means no extra reads.
    final json = await buildTodayWidgetSnapshot(
      now: DateTime.now(),
      query: (date) => missions.findScheduledOn(scheduledDate: date),
    );
    await channel.invokeMethod<void>('publish', {'token': token, 'json': json});
  }
}

import 'dart:convert';

import 'package:agent_core/agent_core.dart';
import 'package:timezone/timezone.dart' as tz;

import '../../domain/entities/mission_schedule_revision.dart';

/// 仅格式化交给模型的结果；数据库事实、日历日期、时长和编号保持原值。
class AssistantToolResultFormatter {
  AssistantToolResultFormatter({
    DateTime Function()? clock,
    String timeZone = defaultScheduleTimeZone,
  }) : _clock = clock ?? DateTime.now,
       _location = tz.getLocation(timeZone);

  final DateTime Function() _clock;
  final tz.Location _location;

  ToolOutput format(ToolOutput output, {bool includeTimeContext = true}) {
    if (output.isError) return output;
    final Object? value;
    try {
      value = jsonDecode(output.text);
    } on FormatException {
      return output;
    }
    final formatted = _value(value, _location);
    if (includeTimeContext && formatted is Map<String, Object?>) {
      final now = tz.TZDateTime.from(_clock(), _location);
      formatted['timeContext'] = {
        'timeZone': _location.name,
        'now': _instant(now, _location),
        'today':
            '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}',
        'format': 'ISO 8601，含时区偏移；日期字段为 YYYY-MM-DD；时长保留字段声明的单位',
      };
    }
    return ToolOutput.success(jsonEncode(formatted));
  }

  Object? _value(Object? value, tz.Location inherited) {
    if (value is List) {
      return [for (final item in value) _value(item, inherited)];
    }
    if (value is! Map) return value;
    var location = inherited;
    final zone =
        value['timeZone'] ??
        value['timeZoneId'] ??
        value['time_zone'] ??
        value['time_zone_id'];
    if (zone is String) {
      try {
        location = tz.getLocation(zone);
      } on tz.LocationNotFoundException {
        // 无效时区不能导致已提交操作被当作失败；用明确的 UTC 偏移呈现。
        location = tz.UTC;
      }
    }
    return <String, Object?>{
      for (final entry in value.entries)
        entry.key as String: _timestampField(
          entry.key as String,
          entry.value,
          location,
        ),
    };
  }

  Object? _timestampField(String key, Object? value, tz.Location location) {
    // 白名单只含持久化的时刻，不把版本、秒数或日期当时间戳。
    const fields = {
      'createdAt',
      'updatedAt',
      'cancelledAt',
      'archivedAt',
      'occurredAt',
      'submittedAt',
      'capturedAt',
      'fixedStartAt',
      'evidenceDeadlineAt',
      'actualStart',
      'actualEnd',
      'expiresAt',
      'deletedAt',
      'startedAt',
      'finishedAt',
      'completedAt',
      'requestedAt',
      'publishedAt',
      'reportedAt',
      'changedAt',
      'evidenceWaivedAt',
      'importedAt',
      'availableAt',
      'created_at',
      'updated_at',
      'cancelled_at',
      'archived_at',
      'occurred_at',
      'submitted_at',
      'captured_at',
      'fixed_start_at',
      'evidence_deadline_at',
      'actual_start',
      'actual_end',
      'expires_at',
      'deleted_at',
      'reported_at',
      'changed_at',
      'evidence_waived_at',
      'imported_at',
      'available_at',
    };
    if (fields.contains(key) && value is int) {
      return _instant(
        DateTime.fromMillisecondsSinceEpoch(value, isUtc: true),
        location,
      );
    }
    if ((fields.contains(key) || key == 'start' || key == 'end') &&
        value is String &&
        RegExp(
          r'^\d{4}-\d{2}-\d{2}T.*(?:Z|[+-]\d{2}:\d{2})$',
        ).hasMatch(value)) {
      final instant = DateTime.tryParse(value);
      if (instant != null) return _instant(instant, location);
    }
    return _value(value, location);
  }

  String _instant(DateTime instant, tz.Location location) {
    final local = tz.TZDateTime.from(instant, location);
    final minutes = local.timeZoneOffset.inMinutes;
    String two(int value) => value.toString().padLeft(2, '0');
    final offset =
        '${minutes < 0 ? '-' : '+'}${two(minutes.abs() ~/ 60)}:${two(minutes.abs() % 60)}';
    final stamp = DateTime.utc(
      local.year,
      local.month,
      local.day,
      local.hour,
      local.minute,
      local.second,
      local.millisecond,
      local.microsecond,
    ).toIso8601String();
    return '${stamp.substring(0, stamp.length - 1)}$offset';
  }
}

import 'package:timezone/timezone.dart' as tz;

import '../entities/execution_plan.dart';
import '../entities/goal_package_import.dart';
import '../entities/mission.dart';
import '../entities/mission_creation.dart';
import '../entities/mission_schedule_revision.dart';
import 'mission_creation_rules.dart';

/// 协议字段校验及默认值展开；不决定当前任务是否可以执行，不写数据库。
abstract final class GoalPackageRules {
  static const outlineSchema = 'mission-book.goal-outline';
  static const packageSchema = 'mission-book.goal-package';
  static final _keyPattern = RegExp(r'^[a-z0-9][a-z0-9._-]*$');
  static final _instantPattern = RegExp(
    r'^([0-9]{4})-(0[1-9]|1[0-2])-([0-2][0-9]|3[01])T([01][0-9]|2[0-3]):([0-5][0-9]):([0-5][0-9])(\.[0-9]{1,3})?(Z|[+-]([01][0-9]|2[0-3]):[0-5][0-9])$',
  );

  static bool validateRoot(Map<String, Object?> root) {
    final schema = root['schema'];
    if (schema != outlineSchema && schema != packageSchema) {
      fail('UNSUPPORTED_SCHEMA', '/schema', '不支持此导入格式');
    }
    if (root['version'] is! int || root['version'] != 1) {
      fail('UNSUPPORTED_VERSION', '/version', '版本必须为整数 1');
    }
    final outline = schema == outlineSchema;
    final required = outline
        ? {'schema', 'version', 'goal', 'nodes'}
        : {
            'schema',
            'version',
            'packageId',
            'goal',
            'defaults',
            'nodes',
            'missions',
          };
    for (final field in required) {
      if (!root.containsKey(field)) fail('MISSING_FIELD', '/$field', '缺少必填字段');
    }
    for (final field in root.keys) {
      if (!required.contains(field)) {
        fail('UNKNOWN_FIELD', '/$field', '此协议不允许该字段');
      }
    }
    final goal = object(root['goal'], '/goal');
    text(goal, 'title', '/goal', required: true, max: 200);
    optional(goal, 'description', '/goal');
    optional(goal, 'why', '/goal');
    if (root['nodes'] is! List) fail('INVALID_TYPE', '/nodes', '必须为数组');
    if (!outline) {
      key(root['packageId'], '/packageId', max: 128);
      if (root['missions'] is! List) fail('INVALID_TYPE', '/missions', '必须为数组');
      final defaults = object(root['defaults'], '/defaults');
      zone(defaults['timeZone'], '/defaults/timeZone');
      duration(
        defaults['plannedDurationMinutes'],
        '/defaults/plannedDurationMinutes',
      );
      policy(defaults['verificationPolicy'], '/defaults/verificationPolicy');
    }
    return outline;
  }

  static String validateNode(GoalImportEntry entry, {required bool outline}) {
    final path = '/nodes/${entry.sourceIndex}';
    text(entry.raw, 'title', path, required: true, max: 200);
    optional(entry.raw, 'description', path);
    if (entry.raw.containsKey('children') && entry.raw['children'] is! List) {
      fail('INVALID_TYPE', '$path/children', '必须为数组');
    }
    return outline
        ? text(entry.raw, 'key', path, required: true)!
        : key(entry.raw['key'], '$path/key');
  }

  static Map<String, Object?> resolveMission(
    GoalImportEntry entry,
    Map<String, Object?> defaults,
    Map<String, String> nodes,
  ) {
    final raw = entry.raw;
    final path = '/missions/${entry.sourceIndex}';
    key(raw['key'], '$path/key');
    final title = text(raw, 'title', path, required: true, max: 200)!;
    final nodeKey = raw.containsKey('nodeKey')
        ? key(raw['nodeKey'], '$path/nodeKey')
        : null;
    if (nodeKey != null && !nodes.containsKey(nodeKey)) {
      fail('UNKNOWN_NODE_KEY', '$path/nodeKey', '未找到节点：$nodeKey');
    }
    final schedule = object(raw['schedule'], '$path/schedule');
    final plan = raw.containsKey('executionPlan')
        ? object(raw['executionPlan'], '$path/executionPlan')
        : <String, Object?>{};
    final zoneName = schedule.containsKey('timeZone')
        ? schedule['timeZone']
        : defaults['timeZone'];
    final location = zone(zoneName, '$path/schedule/timeZone');
    final minutes = duration(
      schedule.containsKey('plannedDurationMinutes')
          ? schedule['plannedDurationMinutes']
          : defaults['plannedDurationMinutes'],
      '$path/schedule/plannedDurationMinutes',
    );
    final effectivePolicy = policy(
      raw.containsKey('verificationPolicy')
          ? raw['verificationPolicy']
          : defaults['verificationPolicy'],
      '$path/verificationPolicy',
    );
    final date = text(
      schedule,
      'scheduledDate',
      '$path/schedule',
      required: true,
    )!;
    try {
      validateScheduledDate(date);
    } on ArgumentError {
      fail(
        'INVALID_DATE',
        '$path/schedule/scheduledDate',
        '需要真实的 YYYY-MM-DD 日期',
      );
    }
    final timePolicy = schedule['timePolicy'];
    if (timePolicy != 'FIXED' && timePolicy != 'FLEXIBLE') {
      fail(
        'INVALID_TIME_POLICY',
        '$path/schedule/timePolicy',
        '必须是 FIXED 或 FLEXIBLE',
      );
    }
    DateTime? start;
    if (timePolicy == 'FIXED') {
      start = instant(
        schedule['fixedStartAt'],
        location,
        '$path/schedule/fixedStartAt',
      );
    } else if (schedule.containsKey('fixedStartAt')) {
      fail('UNEXPECTED_FIELD', '$path/schedule/fixedStartAt', '自选任务不接受固定开始时刻');
    }
    final objective = plan.containsKey('objective')
        ? text(
            plan,
            'objective',
            '$path/executionPlan',
            required: true,
            max: 200,
          )!
        : title;
    final steps = <String>[];
    if (plan.containsKey('steps')) {
      final values = plan['steps'];
      if (values is! List || values.length > 100) {
        fail('INVALID_STEPS', '$path/executionPlan/steps', '需要最多 100 条步骤数组');
      }
      for (var i = 0; i < values.length; i++) {
        final value = values[i];
        if (value is! String ||
            value.trim().isEmpty ||
            value.runes.length > 2000) {
          fail(
            'INVALID_STEP',
            '$path/executionPlan/steps/$i',
            '步骤应为最多 2000 字的非空文本',
          );
        }
        steps.add(value.trim());
      }
    }
    final criteria = optional(
      plan,
      'verificationCriteria',
      '$path/executionPlan',
    );
    if (plan.containsKey('verificationCriteria') && criteria == null) {
      fail(
        'INVALID_CRITERIA',
        '$path/executionPlan/verificationCriteria',
        '已填写的验收方向不能为空',
      );
    }
    DateTime? deadline;
    if (effectivePolicy == 'REQUIRED_EVIDENCE') {
      if (criteria == null) {
        fail(
          'REQUIRED_CRITERIA',
          '$path/executionPlan/verificationCriteria',
          '强制材料必须填写验收方向',
        );
      }
      deadline = schedule.containsKey('evidenceDeadlineAt')
          ? instant(
              schedule['evidenceDeadlineAt'],
              location,
              '$path/schedule/evidenceDeadlineAt',
            )
          : nextMidnight(date, location, '$path/schedule/evidenceDeadlineAt');
    } else if (schedule.containsKey('evidenceDeadlineAt')) {
      fail(
        'UNEXPECTED_DEADLINE',
        '$path/schedule/evidenceDeadlineAt',
        '只有强制材料任务可以设置截止',
      );
    }
    return {
      'title': title,
      'description': optional(raw, 'description', path),
      'why': optional(raw, 'why', path),
      'goalNodeId': nodeKey == null ? null : nodes[nodeKey],
      'verificationPolicy': effectivePolicy,
      'scheduledDate': date,
      'timeZone': zoneName,
      'timePolicy': timePolicy,
      'plannedDurationMinutes': minutes,
      'fixedStartAt': start?.toIso8601String(),
      'evidenceDeadlineAt': deadline?.toIso8601String(),
      'objective': objective,
      'steps': steps,
      'verificationCriteria': criteria,
      'notes': optional(plan, 'notes', '$path/executionPlan'),
    };
  }

  static MissionCreation creation(
    GoalImportEntry entry,
    String goalId,
    DateTime createdAt,
  ) {
    final values = entry.resolved;
    if (values == null) fail('UNRESOLVED_MISSION', '/', '任务尚未完成校验');
    final mission = Mission(
      id: entry.id,
      title: values['title']! as String,
      description: values['description'] as String?,
      why: values['why'] as String?,
      goalId: goalId,
      goalNodeId: values['goalNodeId'] as String?,
      verificationPolicy: switch (values['verificationPolicy']) {
        'SELF_REPORT' => VerificationPolicy.selfReport,
        'OPTIONAL_EVIDENCE' => VerificationPolicy.optionalEvidence,
        'REQUIRED_EVIDENCE' => VerificationPolicy.requiredEvidence,
        _ => throw const FormatException('未知材料策略'),
      },
      createdAt: createdAt,
      updatedAt: createdAt,
    );
    final schedule = MissionScheduleRevision(
      id: entry.scheduleId!,
      missionId: entry.id,
      revisionNumber: 1,
      scheduledDate: values['scheduledDate']! as String,
      timeZone: values['timeZone']! as String,
      timePolicy: values['timePolicy'] == 'FIXED'
          ? TimePolicy.fixed
          : TimePolicy.flexible,
      plannedDurationMinutes: values['plannedDurationMinutes']! as int,
      fixedStartAt: _utc(values['fixedStartAt']),
      evidenceDeadlineAt: _utc(values['evidenceDeadlineAt']),
      changedAt: createdAt,
    );
    final plan = ExecutionPlan(
      id: entry.planId!,
      missionId: entry.id,
      objective: values['objective']! as String,
      steps: (values['steps']! as List).cast<String>(),
      verificationCriteria: values['verificationCriteria'] as String?,
      notes: values['notes'] as String?,
      createdAt: createdAt,
      updatedAt: createdAt,
    );
    final request = MissionCreation(
      mission: mission,
      schedule: schedule,
      plan: plan,
    );
    validateMissionCreation(request);
    return request;
  }

  static DateTime? _utc(Object? value) =>
      value == null ? null : DateTime.parse(value as String).toUtc();

  static Map<String, Object?> object(Object? value, String path) {
    if (value is! Map) fail('INVALID_TYPE', path, '需要对象');
    return value.cast<String, Object?>();
  }

  static String? text(
    Map<String, Object?> source,
    String field,
    String path, {
    bool required = false,
    int max = 20000,
  }) {
    final value = source[field];
    if (value is! String ||
        value.runes.length > max ||
        (required && value.trim().isEmpty)) {
      fail(
        'INVALID_TEXT',
        '$path/$field',
        '需要最多 $max 字的${required ? '非空文本' : '文本'}',
      );
    }
    return value.trim().isEmpty ? null : value.trim();
  }

  static String? optional(
    Map<String, Object?> source,
    String field,
    String path,
  ) => source.containsKey(field) ? text(source, field, path) : null;

  static String key(Object? value, String path, {int max = 64}) {
    if (value is! String ||
        value.length > max ||
        !_keyPattern.hasMatch(value)) {
      fail('INVALID_KEY', path, '键需为小写字母/数字开头，仅含字母、数字、点、短横线和下划线');
    }
    return value;
  }

  static int duration(Object? value, String path) {
    if (value is! int || value < 1 || value > 1440) {
      fail('INVALID_DURATION', path, '时长必须为 1–1440 的整数分钟');
    }
    return value;
  }

  static String policy(Object? value, String path) {
    if (value != 'SELF_REPORT' &&
        value != 'OPTIONAL_EVIDENCE' &&
        value != 'REQUIRED_EVIDENCE') {
      fail('INVALID_POLICY', path, '材料策略无效');
    }
    return value! as String;
  }

  static tz.Location zone(Object? value, String path) {
    if (value is! String || value.length > 100) {
      fail('UNKNOWN_TIME_ZONE', path, '需要 IANA 时区名称');
    }
    try {
      return tz.getLocation(value);
    } on tz.LocationNotFoundException {
      fail('UNKNOWN_TIME_ZONE', path, '找不到时区：$value');
    }
  }

  static DateTime instant(Object? value, tz.Location location, String path) {
    if (value is! String || value.endsWith('-00:00')) {
      fail('INVALID_INSTANT', path, '需要含明确时区偏移或 Z 的时刻');
    }
    final match = _instantPattern.firstMatch(value);
    if (match == null) fail('INVALID_INSTANT', path, '时刻需要真实日期、秒和时区，最多毫秒精度');
    final year = int.parse(match[1]!);
    final month = int.parse(match[2]!);
    final day = int.parse(match[3]!);
    final hour = int.parse(match[4]!);
    final minute = int.parse(match[5]!);
    final second = int.parse(match[6]!);
    final wall = DateTime.utc(year, month, day, hour, minute, second);
    if (wall.year != year || wall.month != month || wall.day != day) {
      fail('INVALID_DATE', path, '日期不存在');
    }
    final parsed = DateTime.tryParse(value)?.toUtc();
    if (parsed == null) fail('INVALID_INSTANT', path, '时刻无效');
    final local = tz.TZDateTime.from(parsed, location);
    if (!value.endsWith('Z') &&
        (local.year != year ||
            local.month != month ||
            local.day != day ||
            local.hour != hour ||
            local.minute != minute ||
            local.second != second)) {
      fail('OFFSET_ZONE_MISMATCH', path, '时间偏移与排期时区不匹配，或当地时刻不存在');
    }
    return parsed;
  }

  static DateTime nextMidnight(String date, tz.Location location, String path) {
    final parts = date.split('-').map(int.parse).toList();
    final next = DateTime.utc(parts[0], parts[1], parts[2] + 1);
    if (next.year > 9999) fail('INVALID_DEADLINE', path, '默认截止超出支持年份，请自定截止');
    final result = tz.TZDateTime(location, next.year, next.month, next.day);
    if (result.year != next.year ||
        result.month != next.month ||
        result.day != next.day ||
        result.hour != 0 ||
        result.minute != 0) {
      fail('INVALID_DEADLINE', path, '次日零点不存在，请自定截止');
    }
    // 对具有历史偏移变化的时区检查重叠午夜，不能默默选择其中一次。
    for (final offset
        in location.zones.map((zone) => zone.offset.inMilliseconds).toSet()) {
      final candidate = DateTime.fromMillisecondsSinceEpoch(
        next.millisecondsSinceEpoch - offset,
        isUtc: true,
      );
      final local = tz.TZDateTime.from(candidate, location);
      if (candidate.millisecondsSinceEpoch != result.millisecondsSinceEpoch &&
          local.year == next.year &&
          local.month == next.month &&
          local.day == next.day &&
          local.hour == 0 &&
          local.minute == 0 &&
          local.second == 0) {
        fail('INVALID_DEADLINE', path, '次日零点有歧义，请自定带偏移的截止');
      }
    }
    return result.toUtc();
  }

  static Never fail(String code, String path, String message) =>
      throw GoalImportException(code, path, message);
}

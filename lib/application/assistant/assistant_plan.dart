import 'package:timezone/timezone.dart' as tz;
import 'package:uuid/uuid.dart';

import '../../domain/entities/mission_detail.dart';
import '../../domain/entities/mission_plan.dart';
import '../../domain/entities/mission_ownership.dart';
import '../../domain/entities/mission_schedule_revision.dart';
import '../missions/mission_service.dart';

class AssistantPlanDraft {
  const AssistantPlanDraft(this.input, this.originals);
  final Map<String, Object?> input;
  final Map<String, MissionDetail> originals; // 按条目编号固定原任务快照。
}

/// 把模型计划和用户修改转为实际任务提案；预览和保存使用同一套转换。
class AssistantPlanService {
  AssistantPlanService({
    required MissionService missions,
    required DateTime Function() clock,
    required String timeZone,
  }) : _missions = missions,
       _clock = clock,
       _location = tz.getLocation(timeZone);

  final MissionService _missions;
  final DateTime Function() _clock;
  final tz.Location _location;

  static const schema = <String, Object?>{
    'type': 'object',
    'additionalProperties': false,
    'required': ['title', 'items'],
    'properties': {
      'title': {'type': 'string', 'maxLength': 120},
      'items': {
        'type': 'array',
        'minItems': 1,
        'maxItems': 20,
        'items': {
          'type': 'object',
          'additionalProperties': false,
          'required': ['itemId', 'kind', 'scheduledDate'],
          'properties': {
            'itemId': {
              'type': 'string',
              'description': '本份计划内唯一稳定编号，例如 item-1',
            },
            'kind': {
              'type': 'string',
              'enum': ['CREATE', 'RESCHEDULE'],
            },
            'missionId': {
              'type': 'string',
              'description': 'RESCHEDULE 必填，必须先查询真实任务',
            },
            'title': {'type': 'string', 'description': 'CREATE 必填任务名称'},
            'scheduledDate': {'type': 'string', 'description': 'YYYY-MM-DD'},
            'plannedMinutes': {
              'type': 'integer',
              'minimum': 1,
              'maximum': 1440,
            },
            'timePolicy': {
              'type': 'string',
              'enum': ['FIXED', 'FLEXIBLE'],
            },
            'fixedStartLocal': {
              'type': 'string',
              'description': 'FIXED 时必填 HH:mm',
            },
            'objective': {'type': 'string'},
            'steps': {
              'type': 'array',
              'items': {'type': 'string'},
            },
            'notes': {'type': 'string'},
            'description': {'type': 'string'},
            'why': {'type': 'string'},
            'goalId': {'type': 'string'},
            'goalNodeId': {'type': 'string'},
          },
        },
      },
    },
  };

  static List<Map<String, Object?>> rows(Map<String, Object?> input) => [
    if (input['items'] is List)
      for (final value in input['items'] as List)
        if (value is Map) Map<String, Object?>.from(value),
  ];

  static String? validate(Map<String, Object?> input) {
    if ((input['title'] as String).trim().isEmpty) return '请填写计划名称';
    final items = rows(input);
    if (items.isEmpty || items.length > 20) return '每份计划需要 1–20 项安排';
    final ids = <String>{};
    final missions = <String>{};
    for (final item in items) {
      final id = item['itemId'] as String;
      if (!RegExp(r'^[a-zA-Z0-9_-]{1,64}$').hasMatch(id) || !ids.add(id)) {
        return '条目编号必须唯一，使用 1–64 位字母、数字、短横线或下划线';
      }
      try {
        validateScheduledDate(item['scheduledDate'] as String);
      } on ArgumentError {
        return '“${item['title'] ?? id}”的日期无效';
      }
      if (item['kind'] == 'CREATE') {
        if ((item['title'] as String? ?? '').trim().isEmpty ||
            item['plannedMinutes'] == null) {
          return '新任务需要名称和计划分钟数';
        }
        if (item['missionId'] != null) return '新任务不能指定已有任务编号';
      } else {
        final missionId = item['missionId'] as String?;
        if (missionId == null ||
            missionId.trim().isEmpty ||
            !missions.add(missionId)) {
          return '改期需要真实任务编号，同一任务不能重复出现';
        }
        for (final field in [
          'objective',
          'steps',
          'notes',
          'description',
          'why',
          'goalId',
          'goalNodeId',
        ]) {
          if (item.containsKey(field)) return '批量改期只修改日期、时长和时间方式，请另用任务编辑修改内容';
        }
      }
      if (item['timePolicy'] == 'FIXED' && item['fixedStartLocal'] == null) {
        return '固定安排需要填写开始时间';
      }
      final time = item['fixedStartLocal'];
      if (time != null &&
          !RegExp(r'^(?:[01]\d|2[0-3]):[0-5]\d$').hasMatch(time as String)) {
        return '开始时间请使用 HH:mm，例如 09:30';
      }
      if (item['objective'] is String &&
          (item['objective'] as String).trim().isEmpty) {
        return '具体目标不能为空';
      }
    }
    return null;
  }

  Future<AssistantPlanDraft> prepare(Map<String, Object?> input) async {
    final error = validate(input);
    if (error != null) throw ArgumentError(error);
    final items = rows(input);
    final originals = <String, MissionDetail>{};
    for (final item in items) {
      if (item['kind'] == 'RESCHEDULE') {
        final detail = await _missions.findDetailSnapshot(
          missionId: item['missionId'] as String,
        );
        if (detail == null) throw ArgumentError('计划中的任务已不存在');
        if (detail.events.isNotEmpty || detail.mission.cancelledAt != null) {
          throw ArgumentError('“${detail.mission.title}”已经开始或取消，不能改期');
        }
        originals[item['itemId'] as String] = detail;
        item['title'] = detail.mission.title;
        item['plannedMinutes'] ??= detail.schedule.plannedDurationMinutes;
        final originalStart = detail.schedule.fixedStartAt;
        item['timePolicy'] ??= originalStart == null ? 'FLEXIBLE' : 'FIXED';
        if (item['timePolicy'] == 'FIXED' &&
            item['fixedStartLocal'] == null &&
            originalStart != null) {
          final local = tz.TZDateTime.from(
            originalStart,
            tz.getLocation(detail.schedule.timeZone),
          );
          item['fixedStartLocal'] = '${_two(local.hour)}:${_two(local.minute)}';
        }
      } else {
        item['timePolicy'] ??= item['fixedStartLocal'] == null
            ? 'FLEXIBLE'
            : 'FIXED';
      }
      if (item['timePolicy'] == 'FLEXIBLE') item.remove('fixedStartLocal');
    }
    return AssistantPlanDraft({
      ...input,
      'items': items,
    }, Map.unmodifiable(originals));
  }

  MissionPlan build(
    Map<String, Object?> input,
    Map<String, MissionDetail> originals,
    String operationId,
  ) {
    final error = validate(input);
    if (error != null) throw ArgumentError(error);
    return MissionPlan(
      id: operationId,
      items: [
        for (final item in rows(input))
          _buildItem(item, originals, operationId),
      ],
    );
  }

  MissionPlanItem _buildItem(
    Map<String, Object?> item,
    Map<String, MissionDetail> originals,
    String operationId,
  ) {
    final id = item['itemId'] as String;
    final original = originals[id];
    final zone = original?.schedule.timeZone ?? _location.name;
    final policy = item['timePolicy'] == 'FIXED'
        ? TimePolicy.fixed
        : TimePolicy.flexible;
    final date = item['scheduledDate'] as String;
    DateTime? start;
    if (policy == TimePolicy.fixed) {
      final parts = date.split('-').map(int.parse).toList();
      final time = (item['fixedStartLocal'] as String)
          .split(':')
          .map(int.parse)
          .toList();
      final local = tz.TZDateTime(
        tz.getLocation(zone),
        parts[0],
        parts[1],
        parts[2],
        time[0],
        time[1],
      );
      if (local.hour != time[0] || local.minute != time[1]) {
        throw ArgumentError('该时区的开始时间不存在，请调整时间');
      }
      start = local.toUtc();
    }
    if (item['kind'] == 'CREATE') {
      return MissionPlanItem.create(
        id: id,
        value: _missions.prepareCreation(
          title: item['title'] as String,
          scheduledDate: date,
          timeZone: zone,
          plannedDurationMinutes: item['plannedMinutes'] as int,
          timePolicy: policy,
          fixedStartAt: start,
          objective: item['objective'] as String?,
          steps: (item['steps'] as List?)?.cast<String>(),
          notes: item['notes'] as String?,
          ownership: MissionOwnership(
            goalId: item['goalId'] as String?,
            goalNodeId: item['goalNodeId'] as String?,
          ),
          description: item['description'] as String?,
          why: item['why'] as String?,
          requestId: '$operationId:$id',
        ),
      );
    }
    if (original == null || original.mission.id != item['missionId']) {
      throw ArgumentError('计划条目与原任务不一致，请重新提出');
    }
    return MissionPlanItem.reschedule(
      id: id,
      before: original,
      schedule: MissionScheduleRevision(
        id: const Uuid().v5(Namespace.url.value, '$operationId:$id:schedule'),
        missionId: original.mission.id,
        revisionNumber: original.schedule.revisionNumber + 1,
        scheduledDate: date,
        timeZone: zone,
        timePolicy: policy,
        fixedStartAt: start,
        plannedDurationMinutes: item['plannedMinutes'] as int,
        evidenceDeadlineAt: original.schedule.evidenceDeadlineAt,
        changedAt: _clock().toUtc(),
        changeReason: '助手整份计划改期',
      ),
    );
  }

  Future<List<MissionPlanConflict>> preview(
    Map<String, Object?> input,
    Map<String, MissionDetail> originals,
  ) => _missions.checkPlan(build(input, originals, 'preview'));

  static String _two(int value) => value.toString().padLeft(2, '0');
}

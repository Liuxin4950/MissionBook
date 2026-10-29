import 'dart:async';
import 'dart:convert';

import 'package:agent_core/agent_core.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:uuid/uuid.dart';

import '../../domain/entities/execution_command.dart';
import '../../domain/entities/execution_event.dart';
import '../../domain/entities/mission_detail.dart';
import '../../domain/entities/mission_ownership.dart';
import '../../domain/entities/mission_schedule_revision.dart';
import '../../domain/entities/scheduled_mission.dart';
import '../goals/goal_service.dart';
import '../missions/mission_service.dart';

class PreparedToolCall {
  PreparedToolCall(this.input, {Map<String, Object?>? snapshot})
    : snapshot = snapshot ?? const {};

  Map<String, Object?> input;
  final Map<String, Object?> snapshot;
}

typedef AssistantCallResolver = PreparedToolCall Function(String callId);

/// 把模型参数转成现有业务服务调用；工具输出只报告实际查询或提交结果。
class AssistantTools {
  AssistantTools({
    required MissionService missions,
    required GoalService goals,
    required AssistantCallResolver resolveCall,
    DateTime Function()? clock,
    String timeZone = 'Asia/Shanghai',
  }) : _missions = missions,
       _goals = goals,
       _resolveCall = resolveCall,
       _clock = clock ?? DateTime.now,
       _location = tz.getLocation(timeZone) {
    _tools = [
      _tool(
        'schedule_query',
        '查询指定日期的真实任务快照。日期省略时使用宿主今天；不会触发材料截止补算。',
        _schema({'date': _string('YYYY-MM-DD；省略表示今天')}),
        _scheduleQuery,
        readOnly: true,
      ),
      _tool(
        'mission_query',
        '按稳定任务编号读取任务、当前排期、方案、阶段与执行事实。',
        _schema({'missionId': _string('任务稳定编号')}, required: ['missionId']),
        _missionQuery,
        readOnly: true,
      ),
      _tool(
        'goal_list',
        '查询未放弃目标及状态；需要节点和任务时继续使用 goal_query。',
        _schema(const {}),
        _goalList,
        readOnly: true,
      ),
      _tool(
        'goal_query',
        '读取目标、节点树和关联任务的真实快照。',
        _schema({'goalId': _string('目标稳定编号')}, required: ['goalId']),
        _goalQuery,
        readOnly: true,
      ),
      _tool(
        'mission_create',
        '创建一个自报完成任务。保存前需通过宿主授权；同一调用身份只创建一份。',
        _schema(
          {
            'title': _string('任务名称'),
            'scheduledDate': _string('计划日期 YYYY-MM-DD'),
            'plannedMinutes': _integer('计划分钟数，大于 0'),
            'objective': _string('具体目标；省略时使用任务名称'),
            'fixedStartLocal': _string('可选固定开始时间 HH:mm；不提供则为自选任务'),
            'goalId': _string('可选目标编号'),
            'goalNodeId': _string('可选节点编号，必须同时提供 goalId'),
            'steps': _stringArray('可选行动步骤'),
            'notes': _string('可选方案备注'),
            'description': _string('可选任务说明'),
            'why': _string('可选安排原因'),
          },
          required: ['title', 'scheduledDate', 'plannedMinutes'],
        ),
        _createMission,
      ),
      _tool(
        'mission_reschedule',
        '修改尚未开始任务的日期、时长或固定开始时间。使用确认前的任务快照检查冲突。',
        _schema(
          {
            'missionId': _string('任务稳定编号'),
            'scheduledDate': _string('新计划日期 YYYY-MM-DD'),
            'plannedMinutes': _integer('新计划分钟数；省略保持不变'),
            'timePolicy': _enum('FIXED 或 FLEXIBLE', ['FIXED', 'FLEXIBLE']),
            'fixedStartLocal': _string('FIXED 时的开始时间 HH:mm'),
          },
          required: ['missionId', 'scheduledDate'],
        ),
        _rescheduleMission,
      ),
      _tool(
        'mission_execute',
        '提交 START/PAUSE/RESUME/EXTEND/END。END 的报告结果必须来自用户明确陈述。',
        _schema(
          {
            'missionId': _string('任务稳定编号'),
            'type': _enum('执行动作', [
              'START',
              'PAUSE',
              'RESUME',
              'EXTEND',
              'END',
            ]),
            'minutes': _integer('EXTEND 增加的分钟数'),
            'reason': _string('PAUSE 的可选原因'),
            'report': _enum('END 用户报告', ['COMPLETED', 'NOT_COMPLETED']),
            'submitOptionalEvidence': _boolean('可选材料任务 END 时是否稍后提交'),
            'userReasonCategory': _string('未完成原因分类'),
            'userReasonText': _string('未完成原因说明'),
          },
          required: ['missionId', 'type'],
        ),
        _executeMission,
      ),
      _tool(
        'mission_cancel',
        '取消尚未开始的任务；保留原排期与方案，不伪造 END。',
        _schema({'missionId': _string('任务稳定编号')}, required: ['missionId']),
        _cancelMission,
      ),
      _tool(
        'goal_create',
        '创建一个正在推进的目标。',
        _schema(
          {
            'title': _string('目标名称'),
            'description': _string('可选说明'),
            'why': _string('可选原因'),
          },
          required: ['title'],
        ),
        _createGoal,
      ),
      _tool(
        'goal_node_create',
        '在有效目标下创建一个大纲节点。',
        _schema(
          {
            'goalId': _string('目标编号'),
            'title': _string('节点名称'),
            'parentNodeId': _string('可选父节点编号'),
            'description': _string('可选节点说明'),
          },
          required: ['goalId', 'title'],
        ),
        _createGoalNode,
      ),
    ];
  }

  final MissionService _missions;
  final GoalService _goals;
  final AssistantCallResolver _resolveCall;
  final DateTime Function() _clock;
  final tz.Location _location;
  late final List<AgentTool> _tools;

  List<AgentTool> get tools => List.unmodifiable(_tools);

  static const writeToolNames = {
    'mission_create',
    'mission_reschedule',
    'mission_execute',
    'mission_cancel',
    'goal_create',
    'goal_node_create',
  };

  Future<PreparedToolCall> prepare(
    String toolName,
    Map<String, Object?> input,
  ) async {
    if (!writeToolNames.contains(toolName)) return PreparedToolCall(input);
    if (toolName == 'mission_reschedule' || toolName == 'mission_execute') {
      final detail = await _missions.findDetailSnapshot(
        missionId: input['missionId'] as String,
      );
      if (detail == null) throw const ToolRejected('not_found', '任务不存在，请刷新后重试');
      if (toolName == 'mission_reschedule') {
        final originalStart = detail.schedule.fixedStartAt;
        final localStart = originalStart == null
            ? null
            : tz.TZDateTime.from(originalStart, _location);
        return PreparedToolCall(
          {
            ...input,
            'timePolicy':
                input['timePolicy'] ??
                (detail.schedule.timePolicy == TimePolicy.fixed
                    ? 'FIXED'
                    : 'FLEXIBLE'),
            if (localStart != null)
              'fixedStartLocal':
                  input['fixedStartLocal'] ??
                  '${localStart.hour.toString().padLeft(2, '0')}:${localStart.minute.toString().padLeft(2, '0')}',
          },
          snapshot: {'detail': detail},
        );
      }
      return PreparedToolCall(input, snapshot: {'detail': detail});
    }
    return PreparedToolCall(input);
  }

  String? validate(String toolName, Map<String, Object?> input) {
    for (final tool in _tools) {
      if (tool.definition.name == toolName) return tool.validateInput(input);
    }
    return '未知工具：$toolName';
  }

  Future<ToolOutput?> recoverOutcome({
    required String toolName,
    required String idempotencyKey,
    required Map<String, Object?> input,
  }) async {
    const uuid = Uuid();
    switch (toolName) {
      case 'mission_create':
        final missionId = uuid.v5(
          Namespace.url.value,
          '$idempotencyKey:mission',
        );
        final detail = await _missions.findDetailSnapshot(missionId: missionId);
        return detail == null ? null : _missionResult(toolName, detail);
      case 'mission_reschedule':
        final receipt = await _missions.findOperationReceipt(idempotencyKey);
        if (receipt == null) return null;
        final detail = await _missions.findDetailSnapshot(
          missionId: input['missionId'] as String,
        );
        return detail == null ? null : _missionResult(toolName, detail);
      case 'mission_execute':
        final missionId = input['missionId'] as String;
        final detail = await _missions.findDetailSnapshot(missionId: missionId);
        final event = detail?.events
            .where((item) => item.id == idempotencyKey)
            .firstOrNull;
        return event == null ? null : _eventResult(event, missionId);
      case 'mission_cancel':
        final missionId = input['missionId'] as String;
        final detail = await _missions.findDetailSnapshot(missionId: missionId);
        if (detail?.mission.cancelledAt == null) return null;
        return _success({
          'ok': true,
          'operation': toolName,
          'missionId': missionId,
        });
      case 'goal_create':
        final goalId = uuid.v5(Namespace.url.value, '$idempotencyKey:goal');
        final goal = await _goals.findById(goalId);
        if (goal == null) return null;
        return _success({
          'ok': true,
          'operation': toolName,
          'goalId': goal.id,
          'title': goal.title,
        });
      case 'goal_node_create':
        final nodeId = uuid.v5(Namespace.url.value, '$idempotencyKey:node');
        final node = await _goals.findNodeById(nodeId);
        if (node == null) return null;
        return _success({
          'ok': true,
          'operation': toolName,
          'goalId': node.goalId,
          'nodeId': node.id,
        });
      default:
        return null;
    }
  }

  Future<ToolOutput> _scheduleQuery(Map<String, Object?> input, _) async {
    final date = input['date'] as String? ?? _today();
    final missions = await _missions.findScheduledSnapshotOn(
      scheduledDate: date,
    );
    return _success({
      'ok': true,
      'date': date,
      'timeZone': _location.name,
      'queriedAt': _clock().toUtc().toIso8601String(),
      'missions': [for (final mission in missions) _scheduledSummary(mission)],
      'references': [
        for (final mission in missions)
          _reference(mission.mission.id, mission.mission.title),
      ],
    });
  }

  Future<ToolOutput> _missionQuery(Map<String, Object?> input, _) async {
    final detail = await _missions.findDetailSnapshot(
      missionId: input['missionId'] as String,
    );
    if (detail == null) return ToolOutput.failure('not_found', '任务不存在');
    return _success({
      'ok': true,
      'mission': _detailSummary(detail, includeEvents: true),
    });
  }

  Future<ToolOutput> _goalList(Map<String, Object?> input, _) async {
    final goals = await _goals.findAll();
    return _success({
      'ok': true,
      'goals': [
        for (final goal in goals)
          {
            'id': goal.id,
            'title': goal.title,
            'status': goal.status.name,
            'description': goal.description,
          },
      ],
      'references': [
        for (final goal in goals) _reference(goal.id, goal.title, type: 'goal'),
      ],
    });
  }

  Future<ToolOutput> _goalQuery(Map<String, Object?> input, _) async {
    final goalId = input['goalId'] as String;
    final goal = await _goals.findById(goalId);
    if (goal == null) return ToolOutput.failure('not_found', '目标不存在');
    final nodes = await _goals.findNodes(goalId);
    final missions = await _missions.findForGoalSnapshot(goalId);
    return _success({
      'ok': true,
      'goal': {
        'id': goal.id,
        'title': goal.title,
        'status': goal.status.name,
        'description': goal.description,
        'why': goal.why,
      },
      'nodes': [
        for (final node in nodes)
          {
            'id': node.id,
            'parentNodeId': node.parentNodeId,
            'title': node.title,
            'description': node.description,
            'archived': node.archivedAt != null,
            'orderIndex': node.orderIndex,
          },
      ],
      'missions': [for (final detail in missions) _detailSummary(detail)],
    });
  }

  Future<ToolOutput> _createMission(
    Map<String, Object?> input,
    ToolContext context,
  ) async {
    final prepared = _call(context, input);
    final values = prepared.input;
    final request = _missions.prepareCreation(
      title: values['title'] as String,
      scheduledDate: values['scheduledDate'] as String,
      timeZone: _location.name,
      plannedDurationMinutes: values['plannedMinutes'] as int,
      fixedStartAt: _fixedStart(values),
      objective: values['objective'] as String?,
      ownership: MissionOwnership(
        goalId: values['goalId'] as String?,
        goalNodeId: values['goalNodeId'] as String?,
      ),
      steps: _stringList(values['steps']),
      notes: values['notes'] as String?,
      description: values['description'] as String?,
      why: values['why'] as String?,
      requestId: context.idempotencyKey,
    );
    try {
      await _missions.createPrepared(request);
    } catch (error) {
      final saved = await _missions.findDetailSnapshot(
        missionId: request.mission.id,
      );
      if (saved != null) return _missionResult('mission_create', saved);
      if (error is ArgumentError || error is StateError) {
        throw ToolRejected('create_rejected', '$error');
      }
      rethrow;
    }
    final saved = await _missions.findDetailSnapshot(
      missionId: request.mission.id,
    );
    if (saved == null) throw StateError('创建提交后未能读取任务');
    return _missionResult('mission_create', saved);
  }

  Future<ToolOutput> _rescheduleMission(
    Map<String, Object?> input,
    ToolContext context,
  ) async {
    final prepared = _call(context, input);
    final values = prepared.input;
    final original = prepared.snapshot['detail'] as MissionDetail;
    final timePolicy = switch (values['timePolicy']) {
      'FIXED' => TimePolicy.fixed,
      'FLEXIBLE' => TimePolicy.flexible,
      _ => original.schedule.timePolicy,
    };
    try {
      await _missions.edit(
        original: original,
        title: original.mission.title,
        objective: original.executionPlan.objective,
        scheduledDate: values['scheduledDate'] as String,
        plannedDurationMinutes:
            values['plannedMinutes'] as int? ??
            original.schedule.plannedDurationMinutes,
        timePolicy: timePolicy,
        fixedStartAt: timePolicy == TimePolicy.fixed
            ? _fixedStart(values)
            : null,
        operationId: context.idempotencyKey,
      );
    } catch (error) {
      final receipt = await _missions.findOperationReceipt(
        context.idempotencyKey,
      );
      if (receipt != null) {
        final saved = await _missions.findDetailSnapshot(
          missionId: original.mission.id,
        );
        if (saved != null) return _missionResult('mission_reschedule', saved);
      }
      if (error is ArgumentError || error is MissionEditConflict) {
        throw ToolRejected('edit_rejected', '$error');
      }
      rethrow;
    }
    final saved = await _missions.findDetailSnapshot(
      missionId: original.mission.id,
    );
    if (saved == null) throw StateError('改期提交后未能读取任务');
    return _missionResult('mission_reschedule', saved);
  }

  Future<ToolOutput> _executeMission(
    Map<String, Object?> input,
    ToolContext context,
  ) async {
    final prepared = _call(context, input);
    final values = prepared.input;
    final detail = prepared.snapshot['detail'] as MissionDetail;
    final type = _executionType(values['type'] as String);
    final report = switch (values['report']) {
      'COMPLETED' => UserReportedResult.completed,
      'NOT_COMPLETED' => UserReportedResult.notCompleted,
      null => null,
      _ => throw const ToolRejected('invalid_report', '未知结束报告'),
    };
    if (type == ExecutionEventType.end && report == null) {
      throw const ToolRejected('report_required', '结束任务必须提供用户明确报告的结果');
    }
    if (type != ExecutionEventType.end && report != null) {
      throw const ToolRejected('unexpected_report', '只有 END 可以携带用户报告');
    }
    final command = _missions.prepareExecution(
      detail: detail,
      type: type,
      minutes: values['minutes'] as int?,
      reason: values['reason'] as String?,
      report: report,
      submitOptionalEvidence: values['submitOptionalEvidence'] as bool?,
      userReasonCategory: values['userReasonCategory'] as String?,
      userReasonText: values['userReasonText'] as String?,
      commandId: context.idempotencyKey,
    );
    try {
      final event = await _missions.execute(command);
      return _eventResult(event, detail.mission.id);
    } catch (error) {
      final current = await _missions.findDetailSnapshot(
        missionId: detail.mission.id,
      );
      final existing = current?.events
          .where((event) => event.id == command.id)
          .firstOrNull;
      if (existing != null) return _eventResult(existing, detail.mission.id);
      if (error is ExecutionConflict || error is ArgumentError) {
        throw ToolRejected('execution_rejected', '$error');
      }
      rethrow;
    }
  }

  Future<ToolOutput> _cancelMission(
    Map<String, Object?> input,
    ToolContext context,
  ) async {
    final prepared = _call(context, input).input;
    final missionId = prepared['missionId'] as String;
    try {
      await _missions.cancel(missionId: missionId);
    } catch (error) {
      final current = await _missions.findDetailSnapshot(missionId: missionId);
      if (current?.mission.cancelledAt != null) {
        return _success({
          'ok': true,
          'operation': 'mission_cancel',
          'missionId': missionId,
        });
      }
      if (error is ExecutionConflict ||
          error is ArgumentError ||
          error is StateError) {
        throw ToolRejected('cancel_rejected', '$error');
      }
      rethrow;
    }
    return _success({
      'ok': true,
      'operation': 'mission_cancel',
      'missionId': missionId,
    });
  }

  Future<ToolOutput> _createGoal(
    Map<String, Object?> input,
    ToolContext context,
  ) async {
    final prepared = _call(context, input).input;
    final goal = _goals.prepareCreation(
      title: prepared['title'] as String,
      description: prepared['description'] as String?,
      why: prepared['why'] as String?,
      requestId: context.idempotencyKey,
    );
    try {
      await _goals.create(goal);
    } catch (error) {
      final saved = await _goals.findById(goal.id);
      if (saved != null) {
        return _success({
          'ok': true,
          'operation': 'goal_create',
          'goalId': saved.id,
          'title': saved.title,
        });
      }
      if (error is ArgumentError || error is StateError) {
        throw ToolRejected('goal_create_rejected', '$error');
      }
      rethrow;
    }
    return _success({
      'ok': true,
      'operation': 'goal_create',
      'goalId': goal.id,
      'title': goal.title,
    });
  }

  Future<ToolOutput> _createGoalNode(
    Map<String, Object?> input,
    ToolContext context,
  ) async {
    final prepared = _call(context, input).input;
    final request = _goals.prepareNodeCreation(
      goalId: prepared['goalId'] as String,
      title: prepared['title'] as String,
      parentNodeId: prepared['parentNodeId'] as String?,
      description: prepared['description'] as String?,
      requestId: context.idempotencyKey,
    );
    try {
      await _goals.createNode(request);
    } catch (error) {
      final saved = await _goals.findNodeById(request.id);
      if (saved != null) {
        return _success({
          'ok': true,
          'operation': 'goal_node_create',
          'goalId': saved.goalId,
          'nodeId': saved.id,
        });
      }
      if (error is ArgumentError || error is StateError) {
        throw ToolRejected('node_create_rejected', '$error');
      }
      rethrow;
    }
    return _success({
      'ok': true,
      'operation': 'goal_node_create',
      'goalId': request.goalId,
      'nodeId': request.id,
    });
  }

  PreparedToolCall _call(ToolContext context, Map<String, Object?> input) {
    try {
      return _resolveCall(context.callId);
    } catch (_) {
      return PreparedToolCall(input);
    }
  }

  DateTime? _fixedStart(Map<String, Object?> input) {
    final value = input['fixedStartLocal'] as String?;
    if (value == null) return null;
    final match = RegExp(r'^(\d{2}):(\d{2})$').firstMatch(value);
    if (match == null) throw ArgumentError('固定开始时间必须为 HH:mm');
    final hour = int.parse(match.group(1)!);
    final minute = int.parse(match.group(2)!);
    if (hour > 23 || minute > 59) throw ArgumentError('固定开始时间无效');
    final date = (input['scheduledDate'] as String)
        .split('-')
        .map(int.parse)
        .toList();
    return tz.TZDateTime(
      _location,
      date[0],
      date[1],
      date[2],
      hour,
      minute,
    ).toUtc();
  }

  ToolOutput _missionResult(String operation, MissionDetail detail) =>
      _success({
        'ok': true,
        'operation': operation,
        'missionId': detail.mission.id,
        'mission': _detailSummary(detail),
        'references': [_reference(detail.mission.id, detail.mission.title)],
      });

  ToolOutput _eventResult(ExecutionEvent event, String missionId) => _success({
    'ok': true,
    'operation': 'mission_execute',
    'missionId': missionId,
    'event': {
      'id': event.id,
      'sequence': event.sequence,
      'type': event.type.name,
      'occurredAt': event.occurredAt.toUtc().toIso8601String(),
      'report': event.userReportedResult?.name,
    },
    'references': [_reference(missionId, '查看任务')],
  });

  Map<String, Object?> _scheduledSummary(ScheduledMission item) => {
    'id': item.mission.id,
    'title': item.mission.title,
    'phase': item.phase.name,
    'scheduledDate': item.schedule.scheduledDate,
    'plannedMinutes': item.schedule.plannedDurationMinutes,
    'timePolicy': item.schedule.timePolicy.name,
    'fixedStartAt': item.schedule.fixedStartAt?.toUtc().toIso8601String(),
    'cancelled': item.mission.cancelledAt != null,
  };

  Map<String, Object?> _detailSummary(
    MissionDetail detail, {
    bool includeEvents = false,
  }) => {
    'id': detail.mission.id,
    'title': detail.mission.title,
    'objective': detail.executionPlan.objective,
    'phase': detail.phase.name,
    'scheduledDate': detail.schedule.scheduledDate,
    'scheduleRevisionId': detail.schedule.id,
    'plannedMinutes': detail.schedule.plannedDurationMinutes,
    'timePolicy': detail.schedule.timePolicy.name,
    'fixedStartAt': detail.schedule.fixedStartAt?.toUtc().toIso8601String(),
    'steps': detail.executionPlan.steps,
    'notes': detail.executionPlan.notes,
    'ownership': detail.ownershipInfo?.label,
    'cancelledAt': detail.mission.cancelledAt?.toUtc().toIso8601String(),
    if (includeEvents)
      'events': [
        for (final event in detail.events)
          {
            'id': event.id,
            'sequence': event.sequence,
            'type': event.type.name,
            'occurredAt': event.occurredAt.toUtc().toIso8601String(),
            'report': event.userReportedResult?.name,
          },
      ],
  };

  Map<String, Object?> _reference(
    String id,
    String title, {
    String type = 'mission',
  }) => {'type': type, 'id': id, 'title': title};

  String _today() {
    final now = tz.TZDateTime.from(_clock(), _location);
    return '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  static ToolOutput _success(Map<String, Object?> value) =>
      ToolOutput.success(jsonEncode(value));

  static List<String>? _stringList(Object? value) => value is List<Object?>
      ? [for (final item in value) item as String]
      : null;

  static ExecutionEventType _executionType(String value) => switch (value) {
    'START' => ExecutionEventType.start,
    'PAUSE' => ExecutionEventType.pause,
    'RESUME' => ExecutionEventType.resume,
    'EXTEND' => ExecutionEventType.extend,
    'END' => ExecutionEventType.end,
    _ => throw ToolRejected('invalid_action', '不支持执行动作：$value'),
  };

  static AgentTool _tool(
    String name,
    String description,
    Map<String, Object?> schema,
    FutureOr<ToolOutput> Function(Map<String, Object?>, ToolContext) handler, {
    bool readOnly = false,
  }) => AgentTool(
    definition: ToolDefinition(
      name: name,
      description: description,
      inputSchema: schema,
    ),
    execute: handler,
    readOnly: readOnly,
  );

  static Map<String, Object?> _schema(
    Map<String, Object?> properties, {
    List<String> required = const [],
  }) => {
    'type': 'object',
    'properties': properties,
    'required': required,
    'additionalProperties': false,
  };

  static Map<String, Object?> _string(String description) => {
    'type': 'string',
    'description': description,
  };
  static Map<String, Object?> _integer(String description) => {
    'type': 'integer',
    'minimum': 1,
    'description': description,
  };
  static Map<String, Object?> _boolean(String description) => {
    'type': 'boolean',
    'description': description,
  };
  static Map<String, Object?> _enum(String description, List<String> values) =>
      {'type': 'string', 'enum': values, 'description': description};
  static Map<String, Object?> _stringArray(String description) => {
    'type': 'array',
    'items': {'type': 'string'},
    'description': description,
  };
}

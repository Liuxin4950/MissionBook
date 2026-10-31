import '../errors/user_error_message.dart';
import '../memory/memory_service.dart';
import 'dart:async';
import 'dart:convert';

import 'package:agent_core/agent_core.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:uuid/uuid.dart';

import '../../domain/entities/execution_command.dart';
import '../../domain/entities/execution_plan.dart';
import '../../domain/entities/goal.dart';
import '../../domain/entities/mission.dart';
import '../../domain/entities/mission_phase.dart';
import '../../domain/entities/goal_node.dart';
import '../../domain/entities/execution_event.dart';
import '../../domain/entities/mission_detail.dart';
import '../../domain/entities/historical_completion.dart';
import '../../domain/entities/schedule_proposal.dart';
import '../../domain/entities/mission_ownership.dart';
import '../../domain/entities/mission_schedule_revision.dart';
import '../../domain/rules/historical_completion_rules.dart';
import '../goals/goal_service.dart';
import 'assistant_reader.dart';
import 'assistant_schedule.dart';
import 'assistant_goal_outline.dart';
import '../missions/mission_service.dart';

part 'assistant_tool_catalog.dart';
part 'assistant_tool_preparation.dart';
part 'assistant_tool_queries.dart';
part 'assistant_tool_execution.dart';

class PreparedToolCall {
  PreparedToolCall(this.input, {Map<String, Object?>? snapshot})
    : snapshot = snapshot ?? const {};

  Map<String, Object?> input;
  final Map<String, Object?> snapshot;
}

typedef AssistantCallResolver = PreparedToolCall Function(String callId);

/// 把模型参数转成现有业务服务调用；工具输出只报告实际查询或提交结果。
class AssistantTools {
  late final _preparation = _AssistantToolPreparation(this);
  late final _queries = _AssistantToolQueries(this);
  late final _execution = _AssistantToolExecution(this);

  AssistantTools({
    required AssistantReader reader,
    required MissionService missions,
    required GoalService goals,
    required AssistantCallResolver resolveCall,
    List<AgentTool> extraTools = const [],
    MemoryService? memory,
    DateTime Function()? clock,
    String timeZone = defaultScheduleTimeZone,
  }) : _memory = memory,
       _reader = reader,
       _missions = missions,
       _goals = goals,
       _resolveCall = resolveCall,
       _clock = clock ?? DateTime.now,
       _location = tz.getLocation(timeZone) {
    _plans = AssistantScheduleService(
      missions: missions,
      clock: _clock,
      timeZone: timeZone,
    );
    _tools = _AssistantToolCatalog(this).build(extraTools);
  }
  static const canonicalNames = {
    'mission_complete_history': 'completeHistory',
    'goal_outline_create': 'createGoalOutline',
    'mission_retry': 'retryMission',
    'mission_plan': 'planMissions',
    'mission_create': 'createMission',
    'mission_reschedule': 'rescheduleMission',
    'mission_update': 'updateMission',
    'mission_execute': 'executeMission',
    'mission_cancel': 'cancelMission',
    'goal_create': 'createGoal',
    'goal_node_create': 'createGoalNode',
    'goal_update': 'updateGoal',
    'goal_node_update': 'updateGoalNode',
    'schedule_query': 'getSchedule',
    'mission_query': 'getMission',
    'goal_list': 'listGoals',
    'goal_query': 'getGoalDetail',
    'goal_node_query': 'getGoalNode',
    'mission_search': 'findMissions',
    'mission_content': 'getMissionContent',
    'mission_records': 'getMissionRecords',
    'evidence_content': 'getMaterial',
  };
  static String legacyName(String name) =>
      canonicalNames.entries.where((e) => e.value == name).firstOrNull?.key ??
      name;

  final AssistantReader _reader;
  final MemoryService? _memory;
  int _readCharacters = 0;
  void beginTurn() {
    _readCharacters = 0;
  }

  static const _offsetSchema = {
    'type': 'integer',
    'minimum': 0,
    'maximum': 10000000,
  };

  final MissionService _missions;
  final GoalService _goals;
  final AssistantCallResolver _resolveCall;
  final DateTime Function() _clock;
  final tz.Location _location;
  late final List<AgentTool> _tools;
  late final AssistantScheduleService _plans;

  List<AgentTool> get tools => List.unmodifiable(_tools);

  static const writeToolNames = {
    'startMakeup',
    'saveRecord',
    'linkRecord',
    'reportExecution',
    'correctExecutionTime',
    'saveMemory',
    'forgetMemory',
    'retryAnalysis',
    'mission_complete_history',
    'goal_outline_create',
    'mission_retry',
    'mission_plan',
    'mission_create',
    'mission_reschedule',
    'mission_update',
    'mission_execute',
    'mission_cancel',
    'goal_create',
    'goal_node_create',
    'goal_update',
    'goal_node_update',
  };

  Future<PreparedToolCall> prepare(
    String toolName,
    Map<String, Object?> input,
  ) => _preparation.prepare(toolName, input);

  String? validate(String toolName, Map<String, Object?> input) =>
      _preparation.validate(toolName, input);

  Future<ToolOutput?> recoverOutcome({
    required String toolName,
    required String idempotencyKey,
    required Map<String, Object?> input,
  }) => _execution.recoverOutcome(
    toolName: toolName,
    idempotencyKey: idempotencyKey,
    input: input,
  );

  Future<List<ScheduleConflict>> previewPlan(PreparedToolCall prepared) =>
      _preparation.previewPlan(prepared);

  Future<ToolOutput> _applyPlan(
    Map<String, Object?> input,
    ToolContext context,
  ) => _execution._applyPlan(input, context);

  Future<ToolOutput> _completeHistory(
    Map<String, Object?> input,
    ToolContext context,
  ) => _execution._completeHistory(input, context);

  ToolOutput _readResult(Map<String, Object?> result) =>
      _queries._readResult(result);

  Future<ToolOutput> _scheduleQuery(
    Map<String, Object?> input,
    ToolContext context,
  ) => _queries._scheduleQuery(input, context);
  Future<ToolOutput> _missionSearch(
    Map<String, Object?> input,
    ToolContext context,
  ) => _queries._missionSearch(input, context);
  Future<ToolOutput> _missionContent(
    Map<String, Object?> input,
    ToolContext context,
  ) => _queries._missionContent(input, context);
  Future<ToolOutput> _missionQuery(
    Map<String, Object?> input,
    ToolContext context,
  ) => _queries._missionQuery(input, context);

  Future<ToolOutput> _goalList(
    Map<String, Object?> input,
    ToolContext context,
  ) => _queries._goalList(input, context);
  Future<ToolOutput> _goalQuery(
    Map<String, Object?> input,
    ToolContext context,
  ) => _queries._goalQuery(input, context);

  Future<ToolOutput> _queryNode(
    Map<String, Object?> input,
    ToolContext context,
  ) => _queries._queryNode(input, context);

  Future<ToolOutput> _updateGoal(
    Map<String, Object?> input,
    ToolContext context,
  ) => _execution._updateGoal(input, context);

  Future<ToolOutput> _updateNode(
    Map<String, Object?> input,
    ToolContext context,
  ) => _execution._updateNode(input, context);

  Future<ToolOutput> _createMission(
    Map<String, Object?> input,
    ToolContext context,
  ) => _execution._createMission(input, context);

  Future<ToolOutput> _createGoalOutline(
    Map<String, Object?> input,
    ToolContext context,
  ) => _execution._createGoalOutline(input, context);

  Future<ToolOutput> _retryMission(
    Map<String, Object?> input,
    ToolContext context,
  ) => _execution._retryMission(input, context);

  DateTime _evidenceDeadline(String value) =>
      _preparation._evidenceDeadline(value);

  Future<ToolOutput> _rescheduleMission(
    Map<String, Object?> input,
    ToolContext context, {
    String operation = 'mission_reschedule',
  }) => _execution._rescheduleMission(input, context, operation: operation);

  Future<ToolOutput> _executeMission(
    Map<String, Object?> input,
    ToolContext context,
  ) => _execution._executeMission(input, context);

  Future<ToolOutput> _cancelMission(
    Map<String, Object?> input,
    ToolContext context,
  ) => _execution._cancelMission(input, context);

  Future<ToolOutput> _createGoal(
    Map<String, Object?> input,
    ToolContext context,
  ) => _execution._createGoal(input, context);

  Future<ToolOutput> _createGoalNode(
    Map<String, Object?> input,
    ToolContext context,
  ) => _execution._createGoalNode(input, context);

  T _prepareWithoutWrite<T>(T Function() prepare) =>
      _preparation._prepareWithoutWrite(prepare);

  DateTime? _fixedStart(Map<String, Object?> input, {String? timeZone}) =>
      _preparation._fixedStart(input, timeZone: timeZone);

  Map<String, Object?> _detailSummary(
    MissionDetail detail, {
    bool includeEvents = false,
  }) => _queries._detailSummary(detail, includeEvents: includeEvents);

  Map<String, Object?> _reference(
    String id,
    String title, {
    String type = 'mission',
  }) => _queries._reference(id, title, type: type);

  String _today() {
    final now = tz.TZDateTime.from(_clock(), _location);
    return '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  static String? _preview(String? value, int limit) =>
      value == null || value.length <= limit
      ? value
      : value.substring(0, limit);

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

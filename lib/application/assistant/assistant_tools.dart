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
import '../../domain/entities/mission_plan.dart';
import '../../domain/entities/mission_ownership.dart';
import '../../domain/entities/mission_schedule_revision.dart';
import '../goals/goal_service.dart';
import 'assistant_reader.dart';
import 'assistant_plan.dart';
import 'assistant_goal_outline.dart';
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
    required AssistantReader reader,
    required MissionService missions,
    required GoalService goals,
    required AssistantCallResolver resolveCall,
    DateTime Function()? clock,
    String timeZone = 'Asia/Shanghai',
  }) : _reader = reader,
       _missions = missions,
       _goals = goals,
       _resolveCall = resolveCall,
       _clock = clock ?? DateTime.now,
       _location = tz.getLocation(timeZone) {
    _plans = AssistantPlanService(
      missions: missions,
      clock: _clock,
      timeZone: timeZone,
    );
    _tools = [
      _tool(
        'goal_outline_create',
        '一次创建新目标及1–20个分层大纲节点，最多4层。整份可编辑、删除子树并按权限一次确认，全部成功或全部回滚。适用于把新学习目标拆成阶段；不用于向已有目标追加，不创建任务、不标记掌握。随后按用户时间使用 mission_plan 安排任务。',
        AssistantGoalOutline.schema,
        _createGoalOutline,
      ),
      _tool(
        'mission_retry',
        '从已结束或已取消任务创建新的再次尝试，保留来源关联、归属、材料策略和原始记录。先用 mission_query 核对来源，询问新日期；强制材料需用户提供本次新截止，不复制旧截止。不把原任务改回未开始。',
        _schema(
          {
            'missionId': _string('来源任务稳定编号'),
            'scheduledDate': _string('新尝试日期 YYYY-MM-DD'),
            'plannedMinutes': _integer('计划分钟，省略沿用来源'),
            'title': _string('新尝试名称，省略沿用来源'),
            'objective': _string('改进后的具体目标，省略沿用来源'),
            'steps': _stringArray('改进后的完整步骤，省略沿用来源'),
            'notes': _string('新备注，省略沿用来源'),
            'fixedStartLocal': _string('可选 HH:mm；省略为自选'),
            'evidenceDeadlineLocal': _string('仅强制材料必填 YYYY-MM-DD HH:mm，应用时区'),
          },
          required: ['missionId', 'scheduledDate'],
        ),
        _retryMission,
      ),
      _tool(
        'mission_plan',
        '集中安排或改期 1–20 项任务，先查真实任务和相关日期安排。整份计划可编辑、移除条目；冲突时整份零写入，成功后返回每项真实结果。多个任务优先用本工具，不能逐项创建绕过整份计划确认。',
        AssistantPlanService.schema,
        _applyPlan,
      ),
      _tool(
        'schedule_query',
        '查询指定日期的真实任务快照。日期省略时使用宿主今天；不会触发材料截止补算。',
        _schema({
          'date': _string('YYYY-MM-DD；省略表示今天'),
          'offset': _offsetSchema,
        }),
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
        _schema({'offset': _offsetSchema}),
        _goalList,
        readOnly: true,
      ),
      _tool(
        'goal_query',
        '读取目标和分页节点索引及任务总数；不装载所有任务。',
        _schema(
          {'goalId': _string('目标稳定编号'), 'offset': _offsetSchema},
          required: ['goalId'],
        ),
        _goalQuery,
        readOnly: true,
      ),
      _tool(
        'mission_search',
        '按目标、节点、日期或标题搜索任务候选，每页最多20条。索引不代表完整阶段。',
        _schema({
          'goalId': _string('目标编号'),
          'nodeId': _string('节点编号'),
          'date': _string('YYYY-MM-DD'),
          'search': _string('标题包含文字'),
          'offset': _offsetSchema,
        }),
        _missionSearch,
        readOnly: true,
      ),
      _tool(
        'mission_content',
        '按需读取任务的长文字片段，每次最多2000字符，steps为JSON数组原文。',
        _schema(
          {
            'missionId': _string('任务编号'),
            'field': _enum('正文字段', [
              'objective',
              'steps',
              'notes',
              'description',
              'why',
            ]),
            'offset': _offsetSchema,
          },
          required: ['missionId', 'field'],
        ),
        _missionContent,
        readOnly: true,
      ),
      _tool(
        'goal_update',
        '修改目标名称、说明或原因，未提供字段保持原值。',
        _schema(
          {
            'goalId': _string('目标编号'),
            'title': _string('新名称'),
            'description': _string('新说明；空串清空'),
            'why': _string('新原因；空串清空'),
          },
          required: ['goalId'],
        ),
        _updateGoal,
      ),
      _tool(
        'goal_node_query',
        '读取指定节点和所属目标编号，描述最多1000字预览。',
        _schema({'nodeId': _string('节点编号')}, required: ['nodeId']),
        _queryNode,
        readOnly: true,
      ),
      _tool(
        'goal_node_update',
        '修改节点名称或说明，未提供字段保持原值，不改变归属与任务。',
        _schema(
          {
            'nodeId': _string('节点编号'),
            'title': _string('新名称'),
            'description': _string('新说明；空串清空'),
          },
          required: ['nodeId'],
        ),
        _updateNode,
      ),
      _tool(
        'mission_records',
        '分页读取任务已保存的执行事件、失败原因或材料索引，区分事实与AI判断。',
        _schema(
          {
            'missionId': _string('任务编号'),
            'section': _enum('记录范围', ['execution', 'failures', 'evidence']),
            'offset': _offsetSchema,
          },
          required: ['missionId', 'section'],
        ),
        (input, _) async => _readResult(
          await _reader.records(
            input['missionId'] as String,
            input['section'] as String,
            offset: input['offset'] as int? ?? 0,
          ),
        ),
        readOnly: true,
      ),
      _tool(
        'evidence_content',
        '按材料稳定编号分段读取正式文本、代码或手动记录；不把材料当成AI评价。',
        _schema(
          {'evidenceId': _string('材料编号'), 'offset': _offsetSchema},
          required: ['evidenceId'],
        ),
        (input, _) async => _readResult(
          await _reader.evidenceContent(
            input['evidenceId'] as String,
            offset: input['offset'] as int? ?? 0,
          ),
        ),
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
        'mission_update',
        '修改尚未开始任务的名称、具体目标、步骤、备注、说明或安排。未提供字段保持原值。',
        _schema(
          {
            'missionId': _string('任务编号'),
            'title': _string('新名称'),
            'objective': _string('新具体目标'),
            'steps': _stringArray('完整新步骤列表；空数组清空'),
            'notes': _string('新备注；空串清空'),
            'description': _string('新说明；空串清空'),
            'why': _string('新原因；空串清空'),
            'scheduledDate': _string('新日期 YYYY-MM-DD'),
            'plannedMinutes': _integer('计划分钟'),
            'timePolicy': _enum('时间方式', ['FIXED', 'FLEXIBLE']),
            'fixedStartLocal': _string('HH:mm'),
          },
          required: ['missionId'],
        ),
        (input, context) =>
            _rescheduleMission(input, context, operation: 'mission_update'),
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

  final AssistantReader _reader;
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
  late final AssistantPlanService _plans;

  List<AgentTool> get tools => List.unmodifiable(_tools);

  static const writeToolNames = {
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
  ) async {
    if (!writeToolNames.contains(toolName)) return PreparedToolCall(input);
    if (toolName == 'mission_plan') {
      try {
        final draft = await _plans.prepare(input);
        final prepared = PreparedToolCall(
          draft.input,
          snapshot: {'planOriginals': draft.originals},
        );
        prepared.snapshot['planConflicts'] = await previewPlan(prepared);
        return prepared;
      } on ArgumentError catch (error) {
        throw ToolRejected('invalid_plan', '${error.message}');
      } on StateError catch (error) {
        throw ToolRejected('invalid_plan', '$error');
      }
    }
    if (toolName == 'goal_update') {
      final goal = await _goals.findById(input['goalId'] as String);
      if (goal == null) throw const ToolRejected('not_found', '目标不存在');
      return PreparedToolCall(
        input,
        snapshot: {'goal': goal, 'targetTitle': goal.title},
      );
    }
    if (toolName == 'goal_node_update') {
      final node = await _goals.findNodeById(input['nodeId'] as String);
      if (node == null) throw const ToolRejected('not_found', '节点不存在');
      return PreparedToolCall(
        input,
        snapshot: {'node': node, 'targetTitle': node.title},
      );
    }
    if (toolName == 'mission_reschedule' ||
        toolName == 'mission_update' ||
        toolName == 'mission_execute' ||
        toolName == 'mission_retry') {
      final detail = await _missions.findDetailSnapshot(
        missionId: input['missionId'] as String,
      );
      if (detail == null) throw const ToolRejected('not_found', '任务不存在，请刷新后重试');
      if (toolName == 'mission_retry') {
        if (detail.phase != MissionPhase.closed &&
            detail.phase != MissionPhase.cancelled) {
          throw const ToolRejected('retry_rejected', '只能从已结束或已取消任务创建新尝试');
        }
        if (detail.mission.verificationPolicy ==
                VerificationPolicy.requiredEvidence &&
            input['evidenceDeadlineLocal'] == null) {
          throw const ToolRejected(
            'deadline_required',
            '请先询问用户本次尝试的新材料截止时间，不沿用旧截止',
          );
        }
        return PreparedToolCall(
          {
            ...input,
            'title': input['title'] ?? detail.mission.title,
            'objective': input['objective'] ?? detail.executionPlan.objective,
            'plannedMinutes':
                input['plannedMinutes'] ??
                detail.schedule.plannedDurationMinutes,
          },
          snapshot: {'detail': detail},
        );
      }
      if (toolName == 'mission_reschedule' || toolName == 'mission_update') {
        final originalStart = detail.schedule.fixedStartAt;
        final localStart = originalStart == null
            ? null
            : tz.TZDateTime.from(
                originalStart,
                tz.getLocation(detail.schedule.timeZone),
              );
        return PreparedToolCall(
          {
            ...input,
            'scheduledDate':
                input['scheduledDate'] ?? detail.schedule.scheduledDate,
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
    final tool = _tools
        .where((item) => item.definition.name == toolName)
        .firstOrNull;
    if (tool == null) return '未知工具：$toolName';
    final schemaError = tool.validateInput(input);
    if (schemaError != null) return schemaError;
    if (toolName == 'mission_plan') return AssistantPlanService.validate(input);
    if (toolName == 'goal_outline_create') {
      return AssistantGoalOutline.validate(input);
    }
    try {
      if (input['scheduledDate'] is String) {
        validateScheduledDate(input['scheduledDate'] as String);
      }
      for (final field in ['title', 'objective']) {
        if (input[field] is String && (input[field] as String).trim().isEmpty) {
          return field == 'title' ? '名称不能为空' : '具体目标不能为空';
        }
      }
      if (input['fixedStartLocal'] != null) _fixedStart(input);
      if (input['evidenceDeadlineLocal'] != null) {
        _evidenceDeadline(input['evidenceDeadlineLocal'] as String);
      }
      if (input['timePolicy'] == 'FIXED' && input['fixedStartLocal'] == null) {
        return '固定时间需要填写开始时刻';
      }
      if (input['type'] == 'EXTEND' && input['minutes'] == null) {
        return '延长需要填写增加的分钟数';
      }
    } on ArgumentError catch (error) {
      return '$error';
    }
    return null;
  }

  Future<ToolOutput?> recoverOutcome({
    required String toolName,
    required String idempotencyKey,
    required Map<String, Object?> input,
  }) async {
    const uuid = Uuid();
    switch (toolName) {
      case 'mission_plan':
        final receipt = await _missions.findOperationReceipt(idempotencyKey);
        return receipt?.kind == 'mission_plan'
            ? ToolOutput.success(receipt!.resultJson)
            : null;
      case 'goal_update':
      case 'goal_node_update':
        final receipt = await _missions.findOperationReceipt(idempotencyKey);
        return receipt == null ? null : ToolOutput.success(receipt.resultJson);
      case 'mission_create':
      case 'mission_retry':
        final missionId = uuid.v5(
          Namespace.url.value,
          '$idempotencyKey:mission',
        );
        final detail = await _missions.findDetailSnapshot(missionId: missionId);
        return detail == null ? null : _missionResult(toolName, detail);
      case 'mission_reschedule':
      case 'mission_update':
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
        final receipt = await _missions.findOperationReceipt(idempotencyKey);
        if (receipt?.kind != 'mission_cancel' ||
            receipt?.entityId != input['missionId']) {
          return null;
        }
        return _success({
          'ok': true,
          'operation': toolName,
          'missionId': receipt!.entityId,
        });
      case 'goal_create':
      case 'goal_outline_create':
        final goalId = uuid.v5(Namespace.url.value, '$idempotencyKey:goal');
        final goal = await _goals.findById(goalId);
        if (goal == null) return null;
        return _success({
          'ok': true,
          'operation': toolName,
          'goalId': goal.id,
          'title': goal.title,
          'references': [
            {'type': 'goal', 'id': goal.id, 'title': goal.title},
          ],
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

  Future<List<MissionPlanConflict>> previewPlan(PreparedToolCall prepared) =>
      _plans.preview(
        prepared.input,
        prepared.snapshot['planOriginals'] as Map<String, MissionDetail>,
      );

  Future<ToolOutput> _applyPlan(
    Map<String, Object?> input,
    ToolContext context,
  ) async {
    final prepared = _call(context, input);
    try {
      final plan = _plans.build(
        prepared.input,
        prepared.snapshot['planOriginals'] as Map<String, MissionDetail>,
        context.idempotencyKey,
      );
      final receipt = await _missions.applyPlan(plan);
      return ToolOutput.success(receipt.resultJson);
    } on MissionPlanConflictException catch (error) {
      throw ToolRejected('plan_conflict', '整份计划未保存：$error');
    } on MissionEditConflict catch (error) {
      throw ToolRejected('plan_changed', '整份计划未保存：$error');
    } on ArgumentError catch (error) {
      throw ToolRejected('invalid_plan', '整份计划未保存：${error.message}');
    } on StateError catch (error) {
      throw ToolRejected('plan_rejected', '整份计划未保存：$error');
    }
  }

  ToolOutput _readResult(Map<String, Object?> result) {
    if (result['ok'] == false) {
      return ToolOutput.failure(
        result['code'] as String? ?? 'read_failed',
        result['message'] as String? ?? '读取失败',
      );
    }
    final text = jsonEncode(result);
    if (_readCharacters + text.length > 64000) {
      return ToolOutput.failure(
        'read_budget_exceeded',
        '本轮已到累计读取预算。请基于已有片段回答并说明未覆盖部分，或让用户另开一轮缩小范围。',
      );
    }
    _readCharacters += text.length;
    return ToolOutput.success(text);
  }

  Future<ToolOutput> _scheduleQuery(Map<String, Object?> input, _) async =>
      _readResult({
        ...await _reader.missions(
          date: input['date'] as String? ?? _today(),
          offset: input['offset'] as int? ?? 0,
        ),
        'date': input['date'] ?? _today(),
        'queriedAt': _clock().toUtc().toIso8601String(),
      });
  Future<ToolOutput> _missionSearch(Map<String, Object?> input, _) async =>
      _readResult(
        await _reader.missions(
          date: input['date'] as String?,
          goalId: input['goalId'] as String?,
          nodeId: input['nodeId'] as String?,
          search: input['search'] as String?,
          offset: input['offset'] as int? ?? 0,
        ),
      );
  Future<ToolOutput> _missionContent(Map<String, Object?> input, _) async =>
      _readResult(
        await _reader.content(
          input['missionId'] as String,
          input['field'] as String,
          offset: input['offset'] as int? ?? 0,
        ),
      );
  Future<ToolOutput> _missionQuery(Map<String, Object?> input, _) async {
    final detail = await _missions.findDetailSnapshot(
      missionId: input['missionId'] as String,
    );
    if (detail == null) return ToolOutput.failure('not_found', '任务不存在');
    return _readResult({
      'ok': true,
      'mission': _detailSummary(detail),
      'eventCount': detail.events.length,
      'lastEvent': detail.events.isEmpty
          ? null
          : {
              'type': detail.events.last.type.name,
              'sequence': detail.events.last.sequence,
              'occurredAt': detail.events.last.occurredAt.toIso8601String(),
            },
      'hint': '长文字按预览长度截断；用 mission_content 分段读取。',
    });
  }

  Future<ToolOutput> _goalList(Map<String, Object?> input, _) async =>
      _readResult(await _reader.goals(offset: input['offset'] as int? ?? 0));
  Future<ToolOutput> _goalQuery(Map<String, Object?> input, _) async =>
      _readResult(
        await _reader.goal(
          input['goalId'] as String,
          offset: input['offset'] as int? ?? 0,
        ),
      );

  Future<ToolOutput> _queryNode(Map<String, Object?> input, _) async {
    final node = await _goals.findNodeById(input['nodeId'] as String);
    if (node == null) return ToolOutput.failure('not_found', '节点不存在');
    return _readResult({
      'ok': true,
      'node': {
        'id': node.id,
        'goalId': node.goalId,
        'parentNodeId': node.parentNodeId,
        'title': node.title,
        'description': _preview(node.description, 1000),
        'descriptionLength': node.description?.length ?? 0,
        'updatedAt': node.updatedAt.toIso8601String(),
      },
    });
  }

  Future<ToolOutput> _updateGoal(
    Map<String, Object?> input,
    ToolContext context,
  ) async {
    final prepared = _call(context, input);
    final goal = prepared.snapshot['goal'] as Goal;
    final values = prepared.input;
    return _updateWithReceipt(
      context,
      () => _goals.updateGoal(
        goal,
        title: values['title'] as String? ?? goal.title,
        description: values.containsKey('description')
            ? values['description'] as String?
            : goal.description,
        why: values.containsKey('why') ? values['why'] as String? : goal.why,
        operationId: context.idempotencyKey,
      ),
    );
  }

  Future<ToolOutput> _updateNode(
    Map<String, Object?> input,
    ToolContext context,
  ) async {
    final prepared = _call(context, input);
    final node = prepared.snapshot['node'] as GoalNode;
    final values = prepared.input;
    return _updateWithReceipt(
      context,
      () => _goals.updateNode(
        node,
        title: values['title'] as String? ?? node.title,
        description: values.containsKey('description')
            ? values['description'] as String?
            : node.description,
        operationId: context.idempotencyKey,
      ),
    );
  }

  Future<ToolOutput> _updateWithReceipt(
    ToolContext context,
    Future<void> Function() write,
  ) async {
    try {
      await write();
    } catch (error) {
      final receipt = await _missions.findOperationReceipt(
        context.idempotencyKey,
      );
      if (receipt != null) return ToolOutput.success(receipt.resultJson);
      if (error is ArgumentError || error is StateError) {
        throw ToolRejected('edit_rejected', '$error');
      }
      rethrow;
    }
    final receipt = await _missions.findOperationReceipt(
      context.idempotencyKey,
    );
    if (receipt == null) throw StateError('写入后未找到操作回执');
    return ToolOutput.success(receipt.resultJson);
  }

  Future<ToolOutput> _createMission(
    Map<String, Object?> input,
    ToolContext context,
  ) async {
    final prepared = _call(context, input);
    final values = prepared.input;
    final request = _prepareWithoutWrite(
      () => _missions.prepareCreation(
        title: values['title'] as String,
        scheduledDate: values['scheduledDate'] as String,
        timeZone: _location.name,
        plannedDurationMinutes: values['plannedMinutes'] as int,
        timePolicy: values['fixedStartLocal'] == null
            ? TimePolicy.flexible
            : TimePolicy.fixed,
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
      ),
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

  Future<ToolOutput> _createGoalOutline(
    Map<String, Object?> input,
    ToolContext context,
  ) async {
    final values = _call(context, input).input;
    final recovered = await recoverOutcome(
      toolName: 'goal_outline_create',
      idempotencyKey: context.idempotencyKey,
      input: values,
    );
    if (recovered != null) return recovered;
    final request = _prepareWithoutWrite(
      () => _goals.prepareOutlineImport(
        AssistantGoalOutline.parse(values),
        requestId: context.idempotencyKey,
      ),
    );
    try {
      // 复用目标导入的单一事务，不逐个创建节点造成半份大纲。
      await _goals.importOutline(request);
    } catch (error) {
      final saved = await recoverOutcome(
        toolName: 'goal_outline_create',
        idempotencyKey: context.idempotencyKey,
        input: values,
      );
      if (saved != null) return saved;
      if (error is ArgumentError || error is StateError) {
        throw ToolRejected('outline_rejected', '$error');
      }
      rethrow;
    }
    return _success({
      'ok': true,
      'operation': 'goal_outline_create',
      'goalId': request.goal.id,
      'title': request.goal.title,
      'nodeCount': request.nodes.length,
      'references': [
        {'type': 'goal', 'id': request.goal.id, 'title': request.goal.title},
      ],
    });
  }

  Future<ToolOutput> _retryMission(
    Map<String, Object?> input,
    ToolContext context,
  ) async {
    final prepared = _call(context, input);
    final values = prepared.input;
    final source = prepared.snapshot['detail'] as MissionDetail;
    final request = _prepareWithoutWrite(
      () => _missions.prepareCreation(
        title: values['title'] as String,
        scheduledDate: values['scheduledDate'] as String,
        timeZone: _location.name,
        plannedDurationMinutes: values['plannedMinutes'] as int,
        timePolicy: values['fixedStartLocal'] == null
            ? TimePolicy.flexible
            : TimePolicy.fixed,
        fixedStartAt: _fixedStart(values),
        retrySource: source,
        ownership: source.mission.ownership,
        objective: values['objective'] as String,
        steps: values.containsKey('steps')
            ? _stringList(values['steps'])
            : null,
        notes: values['notes'] as String?,
        description: source.mission.description,
        why: source.mission.why,
        verificationPolicy: source.mission.verificationPolicy,
        verificationCriteria: source.executionPlan.verificationCriteria,
        evidenceDeadlineAt: values['evidenceDeadlineLocal'] == null
            ? null
            : _evidenceDeadline(values['evidenceDeadlineLocal'] as String),
        requestId: context.idempotencyKey,
      ),
    );
    try {
      await _missions.createPrepared(request);
    } catch (error) {
      final saved = await _missions.findDetailSnapshot(
        missionId: request.mission.id,
      );
      if (saved != null) return _missionResult('mission_retry', saved);
      if (error is ArgumentError || error is StateError) {
        throw ToolRejected('retry_rejected', '$error');
      }
      rethrow;
    }
    final saved = await _missions.findDetailSnapshot(
      missionId: request.mission.id,
    );
    if (saved == null) throw StateError('新尝试保存后未能读取，请核对结果');
    return _missionResult('mission_retry', saved);
  }

  DateTime _evidenceDeadline(String value) {
    if (!RegExp(r'^\d{4}-\d{2}-\d{2} \d{2}:\d{2}$').hasMatch(value)) {
      throw ArgumentError('材料截止格式应为 YYYY-MM-DD HH:mm');
    }
    final parts = value.split(' ');
    validateScheduledDate(parts[0]);
    final date = parts[0].split('-').map(int.parse).toList();
    final time = parts[1].split(':').map(int.parse).toList();
    if (time[0] > 23 || time[1] > 59) throw ArgumentError('材料截止时刻无效');
    return tz.TZDateTime(
      _location,
      date[0],
      date[1],
      date[2],
      time[0],
      time[1],
    ).toUtc();
  }

  Future<ToolOutput> _rescheduleMission(
    Map<String, Object?> input,
    ToolContext context, {
    String operation = 'mission_reschedule',
  }) async {
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
        title: values['title'] as String? ?? original.mission.title,
        objective:
            values['objective'] as String? ?? original.executionPlan.objective,
        content: values.containsKey('steps') || values.containsKey('notes')
            ? ExecutionPlanContent(
                steps:
                    _stringList(values['steps']) ??
                    original.executionPlan.steps,
                notes: values.containsKey('notes')
                    ? values['notes'] as String?
                    : original.executionPlan.notes,
              )
            : null,
        updateContext:
            values.containsKey('description') || values.containsKey('why'),
        description: values.containsKey('description')
            ? values['description'] as String?
            : original.mission.description,
        why: values.containsKey('why')
            ? values['why'] as String?
            : original.mission.why,
        ownership: original.mission.ownership,
        scheduledDate: values['scheduledDate'] as String,
        plannedDurationMinutes:
            values['plannedMinutes'] as int? ??
            original.schedule.plannedDurationMinutes,
        timePolicy: timePolicy,
        fixedStartAt: timePolicy == TimePolicy.fixed
            ? _fixedStart(values, timeZone: original.schedule.timeZone)
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
        if (saved != null) return _missionResult(operation, saved);
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
    return _missionResult(operation, saved);
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
    final command = _prepareWithoutWrite(
      () => _missions.prepareExecution(
        detail: detail,
        type: type,
        minutes: values['minutes'] as int?,
        reason: values['reason'] as String?,
        report: report,
        submitOptionalEvidence: values['submitOptionalEvidence'] as bool?,
        userReasonCategory: values['userReasonCategory'] as String?,
        userReasonText: values['userReasonText'] as String?,
        commandId: context.idempotencyKey,
      ),
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
      await _missions.cancel(
        missionId: missionId,
        operationId: context.idempotencyKey,
      );
    } catch (error) {
      final receipt = await _missions.findOperationReceipt(
        context.idempotencyKey,
      );
      if (receipt?.kind == 'mission_cancel' && receipt?.entityId == missionId) {
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
    final goal = _prepareWithoutWrite(
      () => _goals.prepareCreation(
        title: prepared['title'] as String,
        description: prepared['description'] as String?,
        why: prepared['why'] as String?,
        requestId: context.idempotencyKey,
      ),
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
    final request = _prepareWithoutWrite(
      () => _goals.prepareNodeCreation(
        goalId: prepared['goalId'] as String,
        title: prepared['title'] as String,
        parentNodeId: prepared['parentNodeId'] as String?,
        description: prepared['description'] as String?,
        requestId: context.idempotencyKey,
      ),
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

  T _prepareWithoutWrite<T>(T Function() prepare) {
    try {
      return prepare();
    } on ArgumentError catch (error) {
      throw ToolRejected('invalid_arguments', '$error');
    } on StateError catch (error) {
      throw ToolRejected('invalid_arguments', '$error');
    }
  }

  PreparedToolCall _call(ToolContext context, Map<String, Object?> input) {
    try {
      return _resolveCall(context.callId);
    } catch (_) {
      return PreparedToolCall(input);
    }
  }

  DateTime? _fixedStart(Map<String, Object?> input, {String? timeZone}) {
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
      timeZone == null ? _location : tz.getLocation(timeZone),
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

  Map<String, Object?> _detailSummary(
    MissionDetail detail, {
    bool includeEvents = false,
  }) => {
    'id': detail.mission.id,
    'goalId': detail.mission.goalId,
    'nodeId': detail.mission.goalNodeId,
    'sourceMissionId': detail.mission.sourceMissionId,
    'verificationPolicy': detail.mission.verificationPolicy.name,
    'verificationCriteria': _preview(
      detail.executionPlan.verificationCriteria,
      500,
    ),
    'verificationCriteriaLength':
        detail.executionPlan.verificationCriteria?.length ?? 0,
    'evidenceDeadlineAt': detail.schedule.evidenceDeadlineAt
        ?.toUtc()
        .toIso8601String(),
    'timeZone': detail.schedule.timeZone,
    'title': _preview(detail.mission.title, 120),
    'objective': _preview(detail.executionPlan.objective, 500),
    'objectiveLength': detail.executionPlan.objective.length,
    'phase': detail.phase.name,
    'scheduledDate': detail.schedule.scheduledDate,
    'scheduleRevisionId': detail.schedule.id,
    'plannedMinutes': detail.schedule.plannedDurationMinutes,
    'timePolicy': detail.schedule.timePolicy.name,
    'fixedStartAt': detail.schedule.fixedStartAt?.toUtc().toIso8601String(),
    'stepCount': detail.executionPlan.steps.length,
    'notesPreview': _preview(detail.executionPlan.notes, 500),
    'notesLength': detail.executionPlan.notes?.length ?? 0,
    'ownership': _preview(detail.ownershipInfo?.label, 500),
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
  }) => {'type': type, 'id': id, 'title': _preview(title, 120)};

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

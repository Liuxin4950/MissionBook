part of 'assistant_tools.dart';

/// 模型工具的参数准备或执行职责。
class _AssistantToolExecution {
  _AssistantToolExecution(this._tools);
  final AssistantTools _tools;
  List<AgentTool> get tools => _tools.tools;

  Future<ToolOutput?> recoverOutcome({
    required String toolName,
    required String idempotencyKey,
    required Map<String, Object?> input,
  }) async {
    const uuid = Uuid();
    toolName = AssistantTools.legacyName(toolName);
    if (toolName == 'startMakeup') {
      final detail = await _tools._missions.findDetail(
        missionId: input['missionId'] as String,
      );
      return detail?.events.any(
                (e) => e.id == uuid.v5(Namespace.url.value, idempotencyKey),
              ) ==
              true
          ? ToolOutput.success(
              jsonEncode({'saved': true, 'missionId': input['missionId']}),
            )
          : null;
    }
    if ([
      'startMakeup',
      'saveRecord',
      'linkRecord',
      'reportExecution',
      'correctExecutionTime',
      'saveMemory',
      'forgetMemory',
      'retryAnalysis',
    ].contains(toolName)) {
      final receipt = await _tools._missions.findOperationReceipt(
        uuid.v5(Namespace.url.value, idempotencyKey),
      );
      return receipt == null ? null : ToolOutput.success(receipt.resultJson);
    }
    switch (toolName) {
      case 'mission_complete_history':
      case 'mission_plan':
        final receipt = await _tools._missions.findOperationReceipt(
          idempotencyKey,
        );
        return receipt?.kind == toolName
            ? ToolOutput.success(receipt!.resultJson)
            : null;
      case 'goal_update':
      case 'goal_node_update':
        final receipt = await _tools._missions.findOperationReceipt(
          idempotencyKey,
        );
        return receipt == null ? null : ToolOutput.success(receipt.resultJson);
      case 'mission_create':
      case 'mission_retry':
        final missionId = uuid.v5(
          Namespace.url.value,
          '$idempotencyKey:mission',
        );
        final detail = await _tools._missions.findDetail(missionId: missionId);
        return detail == null ? null : _missionResult(toolName, detail);
      case 'mission_reschedule':
      case 'mission_update':
        final receipt = await _tools._missions.findOperationReceipt(
          idempotencyKey,
        );
        if (receipt == null) return null;
        final detail = await _tools._missions.findDetail(
          missionId: input['missionId'] as String,
        );
        return detail == null ? null : _missionResult(toolName, detail);
      case 'mission_execute':
        final missionId = input['missionId'] as String;
        final detail = await _tools._missions.findDetail(missionId: missionId);
        final event = detail?.events
            .where((item) => item.id == idempotencyKey)
            .firstOrNull;
        return event == null ? null : _eventResult(event, missionId);
      case 'mission_cancel':
        final receipt = await _tools._missions.findOperationReceipt(
          idempotencyKey,
        );
        if (receipt?.kind != 'mission_cancel' ||
            receipt?.entityId != input['missionId']) {
          return null;
        }
        return AssistantTools._success({
          'ok': true,
          'operation': toolName,
          'missionId': receipt!.entityId,
        });
      case 'goal_create':
      case 'goal_outline_create':
        final goalId = uuid.v5(Namespace.url.value, '$idempotencyKey:goal');
        final goal = await _tools._goals.findById(goalId);
        if (goal == null) return null;
        return AssistantTools._success({
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
        final node = await _tools._goals.findNodeById(nodeId);
        if (node == null) return null;
        return AssistantTools._success({
          'ok': true,
          'operation': toolName,
          'goalId': node.goalId,
          'nodeId': node.id,
        });
      default:
        return null;
    }
  }

  Future<ToolOutput> _applyPlan(
    Map<String, Object?> input,
    ToolContext context,
  ) async {
    final prepared = _call(context, input);
    try {
      final plan = _tools._plans.build(
        prepared.input,
        prepared.snapshot['planOriginals'] as Map<String, MissionDetail>,
        context.idempotencyKey,
      );
      final receipt = await _tools._missions.applyPlan(plan);
      return ToolOutput.success(receipt.resultJson);
    } on ScheduleConflictException catch (error) {
      throw ToolRejected(
        'plan_conflict',
        userErrorMessage(error, fallback: '整份计划未保存，请重试'),
      );
    } on MissionEditConflict catch (error) {
      throw ToolRejected(
        'plan_changed',
        userErrorMessage(error, fallback: '整份计划未保存，请重试'),
      );
    } on ArgumentError catch (error) {
      throw ToolRejected('invalid_plan', '整份计划未保存：${error.message}');
    } on StateError catch (error) {
      throw ToolRejected(
        'plan_rejected',
        userErrorMessage(error, fallback: '整份计划未保存，请重试'),
      );
    }
  }

  Future<ToolOutput> _completeHistory(
    Map<String, Object?> input,
    ToolContext context,
  ) async {
    final prepared = _call(context, input);
    try {
      final receipt = await _tools._missions.completeHistory(
        HistoricalCompletion(
          id: context.idempotencyKey,
          goalId: prepared.input['goalId'] as String,
          beforeDate: prepared.input['beforeDate'] as String,
          statement: prepared.input['statement'] as String,
          originals:
              prepared.snapshot['historyMissions'] as List<MissionDetail>,
        ),
      );
      return ToolOutput.success(receipt.resultJson);
    } on ExecutionConflict catch (error) {
      throw ToolRejected(
        'history_changed',
        userErrorMessage(error, fallback: '操作未完成，请重试；仍有问题时检查模型设置'),
      );
    } on ArgumentError catch (error) {
      throw ToolRejected(
        'invalid_history',
        userErrorMessage(error, fallback: '操作未完成，请重试；仍有问题时检查模型设置'),
      );
    }
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
      () => _tools._goals.updateGoal(
        goal,
        title: values['title'] as String? ?? goal.title,
        description: values.containsKey('description')
            ? values['description'] as String?
            : goal.description,
        why: values.containsKey('why') ? values['why'] as String? : goal.why,
        desireLevel: values['desireLevel'] as int?,
        updateDesire: values.containsKey('desireLevel'),
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
      () => _tools._goals.updateNode(
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
      final receipt = await _tools._missions.findOperationReceipt(
        context.idempotencyKey,
      );
      if (receipt != null) return ToolOutput.success(receipt.resultJson);
      if (error is ArgumentError || error is StateError) {
        throw ToolRejected(
          'edit_rejected',
          userErrorMessage(error, fallback: '操作未完成，请重试；仍有问题时检查模型设置'),
        );
      }
      rethrow;
    }
    final receipt = await _tools._missions.findOperationReceipt(
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
    final request = _tools._prepareWithoutWrite(
      () => _tools._missions.prepareCreation(
        title: values['title'] as String,
        scheduledDate: values['scheduledDate'] as String,
        timeZone: _tools._location.name,
        plannedDurationMinutes: values['plannedMinutes'] as int,
        timePolicy: values['fixedStartLocal'] == null
            ? TimePolicy.flexible
            : TimePolicy.fixed,
        fixedStartAt: _tools._fixedStart(values),
        objective: values['objective'] as String?,
        ownership: MissionOwnership(
          goalId: values['goalId'] as String?,
          goalNodeId: values['goalNodeId'] as String?,
        ),
        steps: AssistantTools._stringList(values['steps']),
        notes: values['notes'] as String?,
        description: values['description'] as String?,
        why: values['why'] as String?,
        requestId: context.idempotencyKey,
      ),
    );
    try {
      await _tools._missions.createPrepared(request);
    } catch (error) {
      final saved = await _tools._missions.findDetail(
        missionId: request.mission.id,
      );
      if (saved != null) return _missionResult('mission_create', saved);
      if (error is ArgumentError || error is StateError) {
        throw ToolRejected(
          'create_rejected',
          userErrorMessage(error, fallback: '操作未完成，请重试；仍有问题时检查模型设置'),
        );
      }
      rethrow;
    }
    final saved = await _tools._missions.findDetail(
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
    final request = _tools._prepareWithoutWrite(
      () => _tools._goals.prepareOutlineImport(
        AssistantGoalOutline.parse(values),
        requestId: context.idempotencyKey,
      ),
    );
    try {
      // 复用目标导入的单一事务，不逐个创建节点造成半份大纲。
      await _tools._goals.importOutline(request);
    } catch (error) {
      final saved = await recoverOutcome(
        toolName: 'goal_outline_create',
        idempotencyKey: context.idempotencyKey,
        input: values,
      );
      if (saved != null) return saved;
      if (error is ArgumentError || error is StateError) {
        throw ToolRejected(
          'outline_rejected',
          userErrorMessage(error, fallback: '操作未完成，请重试；仍有问题时检查模型设置'),
        );
      }
      rethrow;
    }
    return AssistantTools._success({
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
    final request = _tools._prepareWithoutWrite(
      () => _tools._missions.prepareCreation(
        title: values['title'] as String,
        scheduledDate: values['scheduledDate'] as String,
        timeZone: _tools._location.name,
        plannedDurationMinutes: values['plannedMinutes'] as int,
        timePolicy: values['fixedStartLocal'] == null
            ? TimePolicy.flexible
            : TimePolicy.fixed,
        fixedStartAt: _tools._fixedStart(values),
        retrySource: source,
        ownership: source.mission.ownership,
        objective: values['objective'] as String,
        steps: values.containsKey('steps')
            ? AssistantTools._stringList(values['steps'])
            : null,
        notes: values['notes'] as String?,
        description: source.mission.description,
        why: source.mission.why,
        verificationPolicy: source.mission.verificationPolicy,
        verificationCriteria: source.executionPlan.verificationCriteria,
        evidenceDeadlineAt: values['evidenceDeadlineLocal'] == null
            ? null
            : _tools._evidenceDeadline(
                values['evidenceDeadlineLocal'] as String,
              ),
        requestId: context.idempotencyKey,
      ),
    );
    try {
      await _tools._missions.createPrepared(request);
    } catch (error) {
      final saved = await _tools._missions.findDetail(
        missionId: request.mission.id,
      );
      if (saved != null) return _missionResult('mission_retry', saved);
      if (error is ArgumentError || error is StateError) {
        throw ToolRejected(
          'retry_rejected',
          userErrorMessage(error, fallback: '操作未完成，请重试；仍有问题时检查模型设置'),
        );
      }
      rethrow;
    }
    final saved = await _tools._missions.findDetail(
      missionId: request.mission.id,
    );
    if (saved == null) throw StateError('新尝试保存后未能读取，请核对结果');
    return _missionResult('mission_retry', saved);
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
      await _tools._missions.edit(
        original: original,
        title: values['title'] as String? ?? original.mission.title,
        objective:
            values['objective'] as String? ?? original.executionPlan.objective,
        content: values.containsKey('steps') || values.containsKey('notes')
            ? ExecutionPlanContent(
                steps:
                    AssistantTools._stringList(values['steps']) ??
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
            ? _tools._fixedStart(values, timeZone: original.schedule.timeZone)
            : null,
        operationId: context.idempotencyKey,
      );
    } catch (error) {
      final receipt = await _tools._missions.findOperationReceipt(
        context.idempotencyKey,
      );
      if (receipt != null) {
        final saved = await _tools._missions.findDetail(
          missionId: original.mission.id,
        );
        if (saved != null) return _missionResult(operation, saved);
      }
      if (error is ArgumentError || error is MissionEditConflict) {
        throw ToolRejected(
          'edit_rejected',
          userErrorMessage(error, fallback: '操作未完成，请重试；仍有问题时检查模型设置'),
        );
      }
      rethrow;
    }
    final saved = await _tools._missions.findDetail(
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
    final type = AssistantTools._executionType(values['type'] as String);
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
    final command = _tools._prepareWithoutWrite(
      () => _tools._missions.prepareExecution(
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
      final event = await _tools._missions.execute(command);
      return _eventResult(event, detail.mission.id);
    } catch (error) {
      final current = await _tools._missions.findDetail(
        missionId: detail.mission.id,
      );
      final existing = current?.events
          .where((event) => event.id == command.id)
          .firstOrNull;
      if (existing != null) return _eventResult(existing, detail.mission.id);
      if (error is ExecutionConflict || error is ArgumentError) {
        throw ToolRejected(
          'execution_rejected',
          userErrorMessage(error, fallback: '操作未完成，请重试；仍有问题时检查模型设置'),
        );
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
      await _tools._missions.cancel(
        missionId: missionId,
        operationId: context.idempotencyKey,
      );
    } catch (error) {
      final receipt = await _tools._missions.findOperationReceipt(
        context.idempotencyKey,
      );
      if (receipt?.kind == 'mission_cancel' && receipt?.entityId == missionId) {
        return AssistantTools._success({
          'ok': true,
          'operation': 'mission_cancel',
          'missionId': missionId,
        });
      }
      if (error is ExecutionConflict ||
          error is ArgumentError ||
          error is StateError) {
        throw ToolRejected(
          'cancel_rejected',
          userErrorMessage(error, fallback: '操作未完成，请重试；仍有问题时检查模型设置'),
        );
      }
      rethrow;
    }
    return AssistantTools._success({
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
    final goal = _tools._prepareWithoutWrite(
      () => _tools._goals.prepareCreation(
        title: prepared['title'] as String,
        description: prepared['description'] as String?,
        why: prepared['why'] as String?,
        desireLevel: prepared['desireLevel'] as int?,
        requestId: context.idempotencyKey,
      ),
    );
    try {
      await _tools._goals.create(goal);
    } catch (error) {
      final saved = await _tools._goals.findById(goal.id);
      if (saved != null) {
        return AssistantTools._success({
          'ok': true,
          'operation': 'goal_create',
          'goalId': saved.id,
          'title': saved.title,
        });
      }
      if (error is ArgumentError || error is StateError) {
        throw ToolRejected(
          'goal_create_rejected',
          userErrorMessage(error, fallback: '操作未完成，请重试；仍有问题时检查模型设置'),
        );
      }
      rethrow;
    }
    return AssistantTools._success({
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
    final request = _tools._prepareWithoutWrite(
      () => _tools._goals.prepareNodeCreation(
        goalId: prepared['goalId'] as String,
        title: prepared['title'] as String,
        parentNodeId: prepared['parentNodeId'] as String?,
        description: prepared['description'] as String?,
        requestId: context.idempotencyKey,
      ),
    );
    try {
      await _tools._goals.createNode(request);
    } catch (error) {
      final saved = await _tools._goals.findNodeById(request.id);
      if (saved != null) {
        return AssistantTools._success({
          'ok': true,
          'operation': 'goal_node_create',
          'goalId': saved.goalId,
          'nodeId': saved.id,
        });
      }
      if (error is ArgumentError || error is StateError) {
        throw ToolRejected(
          'node_create_rejected',
          userErrorMessage(error, fallback: '操作未完成，请重试；仍有问题时检查模型设置'),
        );
      }
      rethrow;
    }
    return AssistantTools._success({
      'ok': true,
      'operation': 'goal_node_create',
      'goalId': request.goalId,
      'nodeId': request.id,
    });
  }

  PreparedToolCall _call(ToolContext context, Map<String, Object?> input) {
    try {
      return _tools._resolveCall(context.callId);
    } catch (_) {
      return PreparedToolCall(input);
    }
  }

  ToolOutput _missionResult(String operation, MissionDetail detail) =>
      AssistantTools._success({
        'ok': true,
        'operation': operation,
        'missionId': detail.mission.id,
        'mission': _tools._detailSummary(detail),
        'references': [
          _tools._reference(detail.mission.id, detail.mission.title),
        ],
      });

  ToolOutput _eventResult(ExecutionEvent event, String missionId) =>
      AssistantTools._success({
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
        'references': [_tools._reference(missionId, '查看任务')],
      });
}

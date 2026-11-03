part of 'assistant_tools.dart';

/// 模型工具的参数准备或执行职责。
class _AssistantToolPreparation {
  _AssistantToolPreparation(this._tools);
  final AssistantTools _tools;
  List<AgentTool> get tools => _tools.tools;

  Future<PreparedToolCall> prepare(
    String toolName,
    Map<String, Object?> input, {
    String? sessionId,
  }) async {
    if (toolName == 'manageMissions') {
      if (input['missionIds'] == null &&
          input['goalId'] == null &&
          input['beforeDate'] == null &&
          input['phase'] == null &&
          input['all'] != true) {
        throw const ToolRejected(
          'scope_required',
          '请明确任务编号或筛选范围；只有用户明确要求所有任务时才可设置 all=true',
        );
      }
      try {
        final proposal = await _tools._missions.prepareMaintenance(
          action: MissionMaintenanceAction.values.byName(
            input['action'] as String,
          ),
          ids: (input['missionIds'] as List?)?.cast<String>(),
          goalId: input['goalId'] as String?,
          beforeDate: input['beforeDate'] as String?,
          phase: input['phase'] as String?,
        );
        return PreparedToolCall(
          input,
          snapshot: {
            'maintenance': proposal,
            'targetTitle':
                '${switch (proposal.action) {
                  MissionMaintenanceAction.cancel => '取消',
                  MissionMaintenanceAction.delete => '永久删除',
                  MissionMaintenanceAction.reset => '撤销执行结果',
                }} · ${proposal.items.length} 项任务；${proposal.items.take(5).map((d) => d.mission.title).join('、')}${proposal.items.length > 5 ? '等' : ''}${proposal.action == MissionMaintenanceAction.delete ? '；永久删除，不能恢复' : ''}',
          },
        );
      } on ArgumentError catch (error) {
        throw ToolRejected(
          'invalid_input',
          error.message?.toString() ?? '无效范围',
        );
      } on MissionEditConflict catch (error) {
        throw ToolRejected('conflict', error.message);
      }
    }
    if (!_tools.isWriteTool(toolName)) {
      return PreparedToolCall(input);
    }
    if ([
      'reportExecution',
      'correctExecutionTime',
      'startMakeup',
    ].contains(toolName)) {
      final detail = await _tools._missions.findDetail(
        missionId: input['missionId'] as String,
      );
      if (detail == null) {
        throw ToolRejected(
          'not_found',
          '任务 ${jsonEncode(input['missionId'])} 不存在或已删除，请重新查询',
        );
      }
      return PreparedToolCall(
        input,
        snapshot: {'detail': detail, 'targetTitle': detail.mission.title},
      );
    }
    if (toolName == 'manageMemory' && _tools._memory != null) {
      if (sessionId == null) {
        throw const ToolRejected('invalid_selection', '缺少当前会话');
      }
      final Map<String, Object?> result;
      try {
        result = await _tools._memory.previewForget(
          sessionId: sessionId,
          selectionId: input['selectionId'] as String,
          itemIds: (input['items'] as List)
              .map((item) => (item as Map)['itemId'] as String)
              .toList(),
        );
      } on ArgumentError catch (error) {
        throw ToolRejected(
          'invalid_selection',
          error.message?.toString() ?? '无效选择',
        );
      }
      if (result['status'] != 'ready') {
        throw ToolRejected('invalid_selection', jsonEncode(result));
      }
      final items = result['items'] as List;
      return PreparedToolCall(
        input,
        snapshot: {
          'targetTitle': items
              .map((item) => '${item['itemId']}. ${item['content']}')
              .join('\n'),
        },
      );
    }
    if (toolName == 'saveMemory' &&
        input['id'] != null &&
        _tools._memory != null) {
      final result = await _tools._memory.query(
        search: input['id'] as String,
        includeExpired: true,
      );
      final target = (result['items'] as List<Map<String, Object?>>)
          .where((entry) => entry['id'] == input['id'])
          .firstOrNull;
      if (target == null) {
        throw ToolRejected(
          'not_found',
          '记忆 ${jsonEncode(input['id'])} 不存在或已忘记；如果要新建，请不要传 id',
        );
      }
      const fields = [
        'id',
        'goal_id',
        'kind',
        'content',
        'source',
        'certainty',
        'conflict_key',
        'updated_at',
        'expires_at',
        'forgotten',
        'user_edited',
      ];
      return PreparedToolCall(
        input,
        snapshot: {
          'targetTitle': target['content'],
          'memoryVersion': {for (final field in fields) field: target[field]},
        },
      );
    }

    if (toolName == 'completeHistory') {
      final date = input['beforeDate'] as String;
      try {
        validateScheduledDate(date);
      } on ArgumentError {
        throw const ToolRejected('invalid_date', '请使用有效的截止日期');
      }
      if (date.compareTo(_tools._today()) > 0 ||
          (input['statement'] as String).trim().isEmpty) {
        throw const ToolRejected('invalid_history', '只能补记今天以前的任务，且需用户明确提供完成依据');
      }
      final goal = await _tools._goals.findById(input['goalId'] as String);
      if (goal == null) {
        throw ToolRejected(
          'not_found',
          '目标 ${jsonEncode(input['goalId'])} 不存在，请重新查询',
        );
      }
      final List<MissionDetail> past;
      try {
        past = await _tools._missions.findHistoryScope(goal.id, date);
      } on ArgumentError catch (error) {
        throw ToolRejected('too_many', error.message?.toString() ?? '请缩小日期范围');
      }
      final eligible =
          past
              .where(
                (d) => isHistoricalCompletionCandidate(
                  d,
                  beforeDate: date,
                  goalId: goal.id,
                ),
              )
              .toList()
            ..sort((a, b) => a.mission.id.compareTo(b.mission.id));
      if (past.length > 10000) {
        throw const ToolRejected('too_many', '请缩小日期范围，每批最多10000项');
      }
      final excluded =
          past
              .where(
                (d) => !isHistoricalCompletionCandidate(
                  d,
                  beforeDate: date,
                  goalId: goal.id,
                ),
              )
              .toList()
            ..sort((a, b) => a.mission.id.compareTo(b.mission.id));
      return PreparedToolCall(
        input,
        snapshot: {
          'targetTitle': goal.title,
          'historyMissions': eligible,
          'historyExcluded': excluded,
          'historySkippedCount': excluded.length,
        },
      );
    }
    if (toolName == 'planMissions') {
      try {
        final draft = await _tools._plans.prepare(input);
        final prepared = PreparedToolCall(
          draft.input,
          snapshot: {'planOriginals': draft.originals},
        );
        prepared.snapshot['planConflicts'] = await previewPlan(prepared);
        return prepared;
      } on ArgumentError catch (error) {
        throw ToolRejected(
          'invalid_plan',
          userErrorMessage(error, fallback: '操作未完成，请重试；仍有问题时检查模型设置'),
        );
      } on StateError catch (error) {
        throw ToolRejected(
          'invalid_plan',
          userErrorMessage(error, fallback: '操作未完成，请重试；仍有问题时检查模型设置'),
        );
      }
    }
    if (toolName == 'updateGoal') {
      final goal = await _tools._goals.findById(input['goalId'] as String);
      if (goal == null) {
        throw ToolRejected(
          'not_found',
          '目标 ${jsonEncode(input['goalId'])} 不存在，请重新查询',
        );
      }
      return PreparedToolCall(
        input,
        snapshot: {'goal': goal, 'targetTitle': goal.title},
      );
    }
    if (toolName == 'updateGoalNode') {
      final node = await _tools._goals.findNodeById(input['nodeId'] as String);
      if (node == null) throw const ToolRejected('not_found', '节点不存在');
      return PreparedToolCall(
        input,
        snapshot: {'node': node, 'targetTitle': node.title},
      );
    }
    if (toolName == 'rescheduleMission' ||
        toolName == 'updateMission' ||
        toolName == 'executeMission' ||
        toolName == 'retryMission') {
      final detail = await _tools._missions.findDetail(
        missionId: input['missionId'] as String,
      );
      if (detail == null) throw const ToolRejected('not_found', '任务不存在，请刷新后重试');
      if (toolName == 'retryMission') {
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
      if (toolName == 'rescheduleMission' || toolName == 'updateMission') {
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
    final tool = _tools._tools
        .where((item) => item.definition.name == toolName)
        .firstOrNull;
    if (tool == null) return '未知工具：$toolName';
    final schemaError = tool.validateInput(input);
    if (schemaError != null) return schemaError;
    if (toolName == 'planMissions') {
      return AssistantScheduleService.validate(input);
    }
    if (toolName == 'createGoalOutline') {
      return AssistantGoalOutline.validate(input);
    }
    try {
      if (toolName == 'completeHistory') {
        validateScheduledDate(input['beforeDate'] as String);
        if ((input['beforeDate'] as String).compareTo(_tools._today()) > 0 ||
            (input['statement'] as String).trim().isEmpty) {
          return '请提供有效的历史日期范围和补记依据';
        }
      }
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
      return userErrorMessage(error, fallback: '操作未完成，请重试；仍有问题时检查模型设置');
    }
    return null;
  }

  Future<List<ScheduleConflict>> previewPlan(PreparedToolCall prepared) =>
      _tools._plans.preview(
        prepared.input,
        prepared.snapshot['planOriginals'] as Map<String, MissionDetail>,
      );

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
      _tools._location,
      date[0],
      date[1],
      date[2],
      time[0],
      time[1],
    ).toUtc();
  }

  T _prepareWithoutWrite<T>(T Function() prepare) {
    try {
      return prepare();
    } on ArgumentError catch (error) {
      throw ToolRejected(
        'invalid_arguments',
        userErrorMessage(error, fallback: '操作未完成，请重试；仍有问题时检查模型设置'),
      );
    } on StateError catch (error) {
      throw ToolRejected(
        'invalid_arguments',
        userErrorMessage(error, fallback: '操作未完成，请重试；仍有问题时检查模型设置'),
      );
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
      timeZone == null ? _tools._location : tz.getLocation(timeZone),
      date[0],
      date[1],
      date[2],
      hour,
      minute,
    ).toUtc();
  }
}

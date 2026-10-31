part of 'assistant_tools.dart';

/// 模型工具的参数准备或执行职责。
class _AssistantToolPreparation {
  _AssistantToolPreparation(this._tools);
  final AssistantTools _tools;
  List<AgentTool> get tools => _tools.tools;

  Future<PreparedToolCall> prepare(
    String toolName,
    Map<String, Object?> input,
  ) async {
    toolName = AssistantTools.legacyName(toolName);
    if (!AssistantTools.writeToolNames.contains(toolName)) {
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
      if (detail == null) throw const ToolRejected('not_found', '任务不存在');
      return PreparedToolCall(
        input,
        snapshot: {'detail': detail, 'targetTitle': detail.mission.title},
      );
    }
    if (toolName == 'forgetMemory' && _tools._memory != null) {
      final result = await _tools._memory.query(
        search: input['id'] as String,
        includeExpired: true,
      );
      final target = (result['items'] as List<Map<String, Object?>>)
          .where((e) => e['id'] == input['id'])
          .firstOrNull;
      if (target == null) throw const ToolRejected('not_found', '记忆不存在或已忘记');
      return PreparedToolCall(
        input,
        snapshot: {'targetTitle': target['content']},
      );
    }

    if (toolName == 'mission_complete_history') {
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
      if (goal == null) throw const ToolRejected('not_found', '目标不存在');
      final all = await _tools._missions.findForGoal(goal.id);
      final past = all
          .where((d) => d.schedule.scheduledDate.compareTo(date) < 0)
          .toList();
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
      if (eligible.isEmpty) {
        throw const ToolRejected('no_candidates', '这个日期范围没有可处理的历史自报任务');
      }
      if (eligible.length > 10000) {
        throw const ToolRejected('too_many', '请缩小日期范围，每批最多10000项');
      }
      return PreparedToolCall(
        input,
        snapshot: {
          'targetTitle': goal.title,
          'historyMissions': eligible,
          'historySkippedCount': past.length - eligible.length,
        },
      );
    }
    if (toolName == 'mission_plan') {
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
    if (toolName == 'goal_update') {
      final goal = await _tools._goals.findById(input['goalId'] as String);
      if (goal == null) throw const ToolRejected('not_found', '目标不存在');
      return PreparedToolCall(
        input,
        snapshot: {'goal': goal, 'targetTitle': goal.title},
      );
    }
    if (toolName == 'goal_node_update') {
      final node = await _tools._goals.findNodeById(input['nodeId'] as String);
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
      final detail = await _tools._missions.findDetail(
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
    toolName = AssistantTools.legacyName(toolName);
    final tool = _tools._tools
        .where((item) => item.definition.name == toolName)
        .firstOrNull;
    if (tool == null) return '未知工具：$toolName';
    final schemaError = tool.validateInput(input);
    if (schemaError != null) return schemaError;
    if (toolName == 'mission_plan') {
      return AssistantScheduleService.validate(input);
    }
    if (toolName == 'goal_outline_create') {
      return AssistantGoalOutline.validate(input);
    }
    try {
      if (toolName == 'mission_complete_history') {
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

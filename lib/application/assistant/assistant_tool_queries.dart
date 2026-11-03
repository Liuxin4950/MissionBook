part of 'assistant_tools.dart';

/// 模型工具的参数准备或执行职责。
class _AssistantToolQueries {
  _AssistantToolQueries(this._tools);
  final AssistantTools _tools;
  List<AgentTool> get tools => _tools.tools;

  ToolOutput _readResult(Map<String, Object?> result) {
    if (result['ok'] == false) {
      return ToolOutput.failure(
        result['code'] as String? ?? 'read_failed',
        result['message'] as String? ?? '读取失败',
      );
    }
    final text = _tools
        ._formatOutput(
          ToolOutput.success(jsonEncode(result)),
          includeTimeContext: true,
        )
        .text;
    if (result['summaryComplete'] != true &&
        _tools._readCharacters + text.length > 64000) {
      return ToolOutput.failure(
        'read_budget_exceeded',
        '本轮已到累计读取预算，本次结果未返回。此前累计读取 ${_tools._readCharacters} 字符；本次请求 offset=${result['offset'] ?? '无'}，范围总量=${result['total'] ?? '未知'}。必须说明已读页和未覆盖部分，不能推断全量。统计请改用 getMission(summaryOnly:true) 读取完整范围的精确计数。',
      );
    }
    _tools._readCharacters += text.length;
    return ToolOutput.success(text);
  }

  Future<ToolOutput> _scheduleQuery(Map<String, Object?> input, _) async =>
      _readResult(
        await _tools._unifiedReader.getSchedule(
          date: input['date'] as String?,
          offset: input['offset'] as int? ?? 0,
        ),
      );
  Future<ToolOutput> _missionQuery(Map<String, Object?> input, _) async =>
      _readResult(
        await _tools._unifiedReader.getMission(
          mission: input['mission'] as String?,
          search: input['search'] as String?,
          goalId: input['goalId'] as String?,
          nodeId: input['nodeId'] as String?,
          date: input['date'] as String?,
          beforeDate: input['beforeDate'] as String?,
          phase: input['phase'] as String?,
          summaryOnly: input['summaryOnly'] == true,
          offset: input['offset'] as int? ?? 0,
        ),
      );
  Future<ToolOutput> _goalQuery(Map<String, Object?> input, _) async =>
      _readResult(
        await _tools._unifiedReader.getGoal(
          goal: input['goal'] as String?,
          node: input['node'] as String?,
          mission: input['mission'] as String?,
          offset: input['offset'] as int? ?? 0,
        ),
      );
  Future<ToolOutput> _missionContent(Map<String, Object?> input, _) async =>
      _readResult(
        await _tools._unifiedReader.content(
          input['missionId'] as String,
          input['field'] as String,
          offset: input['offset'] as int? ?? 0,
        ),
      );

  Map<String, Object?> _detailSummary(
    MissionDetail detail, {
    bool includeEvents = false,
  }) => {
    'id': detail.mission.id,
    'goalId': detail.mission.goalId,
    'nodeId': detail.mission.goalNodeId,
    'sourceMissionId': detail.mission.sourceMissionId,
    'verificationPolicy': detail.mission.verificationPolicy.name,
    'verificationCriteria': AssistantTools._preview(
      detail.executionPlan.verificationCriteria,
      500,
    ),
    'verificationCriteriaLength':
        detail.executionPlan.verificationCriteria?.length ?? 0,
    'evidenceDeadlineAt': detail.schedule.evidenceDeadlineAt
        ?.toUtc()
        .toIso8601String(),
    'timeZone': detail.schedule.timeZone,
    'title': AssistantTools._preview(detail.mission.title, 120),
    'objective': AssistantTools._preview(detail.executionPlan.objective, 500),
    'objectiveLength': detail.executionPlan.objective.length,
    'phase': detail.phase.name,
    'scheduledDate': detail.schedule.scheduledDate,
    'scheduleRevisionId': detail.schedule.id,
    'plannedMinutes': detail.schedule.plannedDurationMinutes,
    'timePolicy': detail.schedule.timePolicy.name,
    'fixedStartAt': detail.schedule.fixedStartAt?.toUtc().toIso8601String(),
    'stepCount': detail.executionPlan.steps.length,
    'notesPreview': AssistantTools._preview(detail.executionPlan.notes, 500),
    'notesLength': detail.executionPlan.notes?.length ?? 0,
    'ownership': AssistantTools._preview(detail.ownershipInfo?.label, 500),
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
  }) => {'type': type, 'id': id, 'title': AssistantTools._preview(title, 120)};
}

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
    final text = jsonEncode(result);
    if (_tools._readCharacters + text.length > 64000) {
      return ToolOutput.failure(
        'read_budget_exceeded',
        '本轮已到累计读取预算。请基于已有片段回答并说明未覆盖部分，或让用户另开一轮缩小范围。',
      );
    }
    _tools._readCharacters += text.length;
    return ToolOutput.success(text);
  }

  Future<ToolOutput> _scheduleQuery(Map<String, Object?> input, _) async =>
      _readResult({
        ...await _tools._reader.missions(
          date: input['date'] as String? ?? _tools._today(),
          offset: input['offset'] as int? ?? 0,
        ),
        'date': input['date'] ?? _tools._today(),
        'queriedAt': _tools._clock().toUtc().toIso8601String(),
      });
  Future<ToolOutput> _missionSearch(Map<String, Object?> input, _) async =>
      _readResult(
        await _tools._reader.missions(
          date: input['date'] as String?,
          goalId: input['goalId'] as String?,
          nodeId: input['nodeId'] as String?,
          search: input['search'] as String?,
          offset: input['offset'] as int? ?? 0,
        ),
      );
  Future<ToolOutput> _missionContent(Map<String, Object?> input, _) async =>
      _readResult(
        await _tools._reader.content(
          input['missionId'] as String,
          input['field'] as String,
          offset: input['offset'] as int? ?? 0,
        ),
      );
  Future<ToolOutput> _missionQuery(Map<String, Object?> input, _) async {
    final detail = await _tools._missions.findDetail(
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
      _readResult(
        await _tools._reader.goals(offset: input['offset'] as int? ?? 0),
      );
  Future<ToolOutput> _goalQuery(Map<String, Object?> input, _) async =>
      _readResult(
        await _tools._reader.goal(
          input['goalId'] as String,
          offset: input['offset'] as int? ?? 0,
        ),
      );

  Future<ToolOutput> _queryNode(Map<String, Object?> input, _) async {
    final node = await _tools._goals.findNodeById(input['nodeId'] as String);
    if (node == null) return ToolOutput.failure('not_found', '节点不存在');
    return _readResult({
      'ok': true,
      'node': {
        'id': node.id,
        'goalId': node.goalId,
        'parentNodeId': node.parentNodeId,
        'title': node.title,
        'description': AssistantTools._preview(node.description, 1000),
        'descriptionLength': node.description?.length ?? 0,
        'updatedAt': node.updatedAt.toIso8601String(),
      },
    });
  }

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

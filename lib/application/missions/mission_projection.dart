import '../../domain/entities/execution_event.dart';
import '../../domain/entities/mission_detail.dart';
import '../../domain/rules/execution_time_rules.dart';
import '../../domain/rules/mission_attention_rules.dart';

/// 列表中的判断依据：身份、当前阶段、时间安排和材料要求。
Map<String, Object?> missionIndexProjection(MissionDetail d, DateTime now) => {
  'id': d.mission.id,
  'title': String.fromCharCodes(d.mission.title.runes.take(120)),
  'titleLength': d.mission.title.runes.length,
  'goalId': d.mission.goalId,
  'nodeId': d.mission.goalNodeId,
  'phase': d.phase.name,
  'attention': missionAttention(d.phase, d.schedule, now).name,
  'scheduledDate': d.schedule.scheduledDate,
  'timeZone': d.schedule.timeZone,
  'timePolicy': d.schedule.timePolicy.name.toUpperCase(),
  'fixedStartAt': d.schedule.fixedStartAt?.toIso8601String(),
  'plannedMinutes': d.schedule.plannedDurationMinutes,
  'verificationPolicy': d.mission.verificationPolicy.name,
  'evidenceDeadlineAt': d.schedule.evidenceDeadlineAt?.toIso8601String(),
  'effectiveOccurrenceDate': d.effectiveOccurrenceDate,
  'userReportedCompleted': d.endReportedCompleted,
  'materialCount': d.effectiveEvidence.length,
};

/// 工具的有界任务读模型；领域只提供事实与派生值，裁剪和 JSON 字段属于应用层。
Map<String, Object?> missionProjection(MissionDetail d, DateTime now) {
  String? short(String? v) =>
      v == null ? null : String.fromCharCodes(v.runes.take(500));
  final times = calculateExecutionTimes(d.events, now, schedule: d.schedule);
  return {
    ...missionIndexProjection(d, now),
    'title': short(d.mission.title),
    'titleLength': d.mission.title.runes.length,
    'createdAt': d.mission.createdAt.toIso8601String(),
    'scheduleId': d.schedule.id,
    'objective': short(d.executionPlan.objective),
    'objectiveLength': d.executionPlan.objective.length,
    'description': short(d.mission.description),
    'why': short(d.mission.why),
    'criteria': short(d.executionPlan.verificationCriteria),
    'lastSequence': d.lastSequence,
    'measuredFocusSeconds':
        d.events.any((e) => e.type == ExecutionEventType.start)
        ? times.focus.inSeconds
        : null,
    'completion': d.completionReport == null
        ? null
        : {
            'occurrenceDate': d.effectiveOccurrenceDate,
            'reportedAt': d.completionReport!.isRetrospective
                ? d.completionReport!.occurredAt.toIso8601String()
                : null,
            'retrospective': d.completionReport!.isRetrospective,
          },
    'userReportedTime': d.effectiveUserReport == null
        ? null
        : {
            'id': d.effectiveUserReport!.id,
            'date': d.effectiveUserReport!.occurrenceDate,
            'timeZone': d.effectiveUserReport!.timeZoneId,
            'start': d.effectiveUserReport!.actualStart?.toIso8601String(),
            'end': d.effectiveUserReport!.actualEnd?.toIso8601String(),
            'durationSeconds': d.effectiveUserReport!.duration?.inSeconds,
            'basis': short(d.effectiveUserReport!.basis),
          },
    'materials': d.effectiveEvidence
        .take(20)
        .map(
          (e) => {
            'id': e.id,
            'type': e.type.name,
            'submittedAt': e.submittedAt.toIso8601String(),
            'fileName': e.attachmentFileName,
          },
        )
        .toList(),
    'materialsTruncated': d.effectiveEvidence.length > 20,
  };
}

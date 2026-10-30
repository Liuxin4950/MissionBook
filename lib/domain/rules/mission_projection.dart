import '../entities/mission_detail.dart';
import 'execution_time_rules.dart';
import 'mission_attention_rules.dart';

/// UI 和工具使用同一事实对象与阶段计算，摘要不承担计数和时间真值。
Map<String, Object?> missionProjection(MissionDetail d, DateTime now) {
  String? short(String? v) =>
      v == null ? null : String.fromCharCodes(v.runes.take(500));
  final times = calculateExecutionTimes(d.events, now);
  return {
    'id': d.mission.id,
    'title': short(d.mission.title),
    'titleLength': d.mission.title.length,
    'goalId': d.mission.goalId,
    'nodeId': d.mission.goalNodeId,
    'phase': d.phase.name,
    'attention': missionAttention(d.phase, d.schedule, now).name,
    'createdAt': d.mission.createdAt.toIso8601String(),
    'scheduleId': d.schedule.id,
    'scheduledDate': d.schedule.scheduledDate,
    'timeZone': d.schedule.timeZone,
    'plannedMinutes': d.schedule.plannedDurationMinutes,
    'objective': short(d.executionPlan.objective),
    'objectiveLength': d.executionPlan.objective.length,
    'criteria': short(d.executionPlan.verificationCriteria),
    'lastSequence': d.lastSequence,
    'userReportedCompleted': d.endReportedCompleted,
    'measuredFocusSeconds': d.events.any((e) => e.type.name == 'start')
        ? times.focus.inSeconds
        : null,
    'effectiveOccurrenceDate': d.effectiveOccurrenceDate,
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
    'materialCount': d.effectiveEvidence.length,
    'materialsTruncated': d.effectiveEvidence.length > 20,
  };
}

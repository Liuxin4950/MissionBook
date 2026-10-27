import 'package:timezone/timezone.dart' as tz;

import '../entities/mission_creation.dart';
import '../entities/mission_schedule_revision.dart';
import 'evidence_rules.dart';

/// 手工创建、导入和仓储共用同一份创建校验，避免只在表单保护输入。
void validateMissionCreation(MissionCreation request) {
  final mission = request.mission;
  final schedule = request.schedule;
  final plan = request.plan;
  for (final id in [mission.id, schedule.id, plan.id]) {
    if (id.isEmpty || id != id.trim()) throw ArgumentError('创建编号无效');
  }
  if (schedule.missionId != mission.id ||
      plan.missionId != mission.id ||
      schedule.revisionNumber != 1) {
    throw ArgumentError('新任务必须有自己的首版排期和唯一方案');
  }
  if (mission.title.trim().isEmpty || plan.objective.trim().isEmpty) {
    throw ArgumentError('任务名称和具体目标不能为空');
  }
  if (mission.cancelledAt != null || mission.evidenceWaivedAt != null) {
    throw ArgumentError('新任务不能包含取消或材料放弃事实');
  }
  mission.ownership.validate();
  validateMissionSchedule(schedule);
  validateExecutionPlanContent(plan.steps, plan.notes);
  validateEvidenceRequirement(
    policy: mission.verificationPolicy,
    criteria: plan.verificationCriteria,
    schedule: schedule,
  );
}

void validateMissionSchedule(MissionScheduleRevision schedule) {
  validateScheduledDate(schedule.scheduledDate);
  if (schedule.plannedDurationMinutes <= 0) {
    throw ArgumentError('计划时长必须大于 0 分钟');
  }
  final tz.Location zone;
  try {
    zone = tz.getLocation(schedule.timeZone);
  } on tz.LocationNotFoundException {
    throw ArgumentError('时区名称无效');
  }
  if (schedule.timePolicy == TimePolicy.fixed) {
    if (schedule.fixedStartAt == null || !schedule.fixedStartAt!.isUtc) {
      throw ArgumentError('固定任务必须填写 UTC 开始时刻');
    }
    final local = tz.TZDateTime.from(schedule.fixedStartAt!, zone);
    final date =
        '${local.year.toString().padLeft(4, '0')}-${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')}';
    if (date != schedule.scheduledDate) throw ArgumentError('固定开始时刻必须属于所选计划日期');
  } else if (schedule.fixedStartAt != null) {
    throw ArgumentError('自选任务不能包含固定开始时刻');
  }
}

void validateExecutionPlanContent(List<String> steps, String? notes) {
  if (steps.length > 100 ||
      steps.any(
        (step) =>
            step.trim().isEmpty ||
            step != step.trim() ||
            step.runes.length > 2000,
      )) {
    throw ArgumentError('步骤最多 100 条，每条应为不超过 2000 字的非空内容');
  }
  if (notes != null &&
      (notes.isEmpty || notes != notes.trim() || notes.runes.length > 20000)) {
    throw ArgumentError('备注需去除首尾空白，最多 20000 字');
  }
}

import '../entities/mission.dart';
import '../entities/mission_detail.dart';
import '../entities/mission_phase.dart';

/// 补记只处理尚未锁定的自报任务：未开始、执行中、已暂停或待确认。
const historicalCompletionPhases = {
  MissionPhase.notStarted,
  MissionPhase.running,
  MissionPhase.paused,
  MissionPhase.reportPending,
};

/// 用户补记历史完成前的候选判断；仓储写入前和助手预览共用同一规则。
bool isHistoricalCompletionCandidate(
  MissionDetail detail, {
  required String beforeDate,
  String? goalId,
}) =>
    (goalId == null || detail.mission.goalId == goalId) &&
    detail.mission.verificationPolicy == VerificationPolicy.selfReport &&
    detail.schedule.scheduledDate.compareTo(beforeDate) < 0 &&
    historicalCompletionPhases.contains(detail.phase);

/// 同一范围内不补记的稳定原因；null 表示符合补记条件。
String? historicalCompletionSkipReason(MissionDetail detail) {
  if (detail.phase == MissionPhase.cancelled) return 'cancelled';
  if (detail.phase == MissionPhase.closed ||
      detail.phase == MissionPhase.evidencePending) {
    return 'already_ended';
  }
  if (detail.mission.verificationPolicy ==
      VerificationPolicy.requiredEvidence) {
    return 'required_evidence';
  }
  if (detail.mission.verificationPolicy ==
      VerificationPolicy.optionalEvidence) {
    return 'optional_evidence';
  }
  if (!historicalCompletionPhases.contains(detail.phase)) {
    return 'ineligible_phase';
  }
  return null;
}

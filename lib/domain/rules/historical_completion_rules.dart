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

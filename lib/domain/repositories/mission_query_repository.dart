import '../entities/mission_detail.dart';
import '../entities/scheduled_mission.dart';

/// 批量存储提供的候选查询；简单测试仓储可继续使用原有详情接口。
abstract interface class MissionQueryRepository {
  Future<PlannedMissionSnapshot> findPlannedSnapshot();
  Future<List<MissionDetail>> findReminderCandidates();
  Future<Set<String>> findCompletedGoalNodeIds(String goalId);
}

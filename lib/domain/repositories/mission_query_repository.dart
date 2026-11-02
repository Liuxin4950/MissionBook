import '../entities/mission_detail.dart';
import '../entities/scheduled_mission.dart';
import '../entities/operation_receipt.dart';

/// 批量存储提供的候选查询；简单测试仓储可继续使用原有详情接口。
abstract interface class MissionQueryRepository {
  /// 按编号批量装配任务事实，缺失对象不返回。
  Future<List<MissionDetail>> findDetailsByIds(List<String> ids);
  Future<PlannedMissionSnapshot> findPlannedSnapshot();
  Future<List<MissionDetail>> findReminderCandidates();
  Future<Set<String>> findCompletedGoalNodeIds(String goalId);
  Future<OperationReceiptInfo?> findOperationReceipt(String operationId);
}

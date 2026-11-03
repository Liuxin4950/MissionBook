import '../entities/mission_maintenance.dart';

/// 单条与批量取消、物理删除、撤销执行共用的事务入口。
abstract interface class MissionMaintenanceRepository {
  Future<MissionMaintenanceProposal> prepareMaintenance({
    required MissionMaintenanceAction action,
    List<String>? ids,
    String? goalId,
    String? beforeDate,
    String? phase,
  });
  Future<Map<String, Object?>> applyMaintenance(
    MissionMaintenanceProposal proposal,
    String operationId,
  );
  Future<List<Map<String, Object?>>> executionArchives(String missionId);
}

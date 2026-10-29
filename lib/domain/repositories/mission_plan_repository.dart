import '../entities/mission_plan.dart';
import '../entities/operation_receipt.dart';

/// 计划预览只读；提交必须在写事务内复查冲突并原子保存所有条目和回执。
abstract interface class MissionPlanRepository {
  Future<List<MissionPlanConflict>> checkPlan(MissionPlan plan);
  Future<OperationReceiptInfo> applyPlan(MissionPlan plan);
}

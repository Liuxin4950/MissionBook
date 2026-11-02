import '../entities/historical_completion.dart';
import '../entities/mission_detail.dart';
import '../entities/operation_receipt.dart';

/// 用户补记历史完成的写入能力；与任务通用仓储分开，避免查询接口承担批量补记。
abstract interface class HistoricalCompletionRepository {
  /// 在一致快照内读取截止日期之前的目标任务，超过上限时拒绝。
  Future<List<MissionDetail>> findHistoryScope(
    String goalId,
    String beforeDate,
  );
  Future<OperationReceiptInfo> completeHistory(HistoricalCompletion request);
}

import '../entities/historical_completion.dart';
import '../entities/operation_receipt.dart';

/// 用户补记历史完成的写入能力；与任务通用仓储分开，避免查询接口承担批量补记。
abstract interface class HistoricalCompletionRepository {
  Future<OperationReceiptInfo> completeHistory(HistoricalCompletion request);
}

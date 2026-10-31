import '../entities/analysis_scope.dart';
import '../entities/evidence.dart';

/// 独立记录的内容与归属入口；关联任务后正文不可覆盖，只能追加材料修正。
/// 执行报告由任务命令保存，长期记忆由 MemoryRepository 保存。
abstract interface class RecordRepository {
  /// 删除独立记录；已有材料引用时拒绝，保留任务事实。
  Future<void> deleteRecord(String id);

  /// 同一草稿编号幂等保存；关联任务时与材料引用在同一事务提交。
  Future<void> saveRecord(
    EvidenceDraft draft, {
    String? goalId,
    String? nodeId,
    String? missionId,
  });

  /// 更改独立归属或正式关联任务；已有正式关联不能换绑或取消。
  Future<void> linkRecord(
    String id, {
    String? goalId,
    String? nodeId,
    String? missionId,
    String? operationId,
  });

  /// 有界分页查询；正文按需分段，不触发模型或修改记录。
  Future<Map<String, Object?>> queryRecords({
    String? id,
    String? goalId,
    String? nodeId,
    String? missionId,
    String? date,
    int offset = 0,
    bool content = false,
    int contentOffset = 0,
  });

  /// 对照打开时的正文更正；并发变化或正式材料均拒绝覆盖。
  Future<void> updateRecordContent(
    String id,
    String? expectedContent,
    String? content,
  );
  Future<Map<String, Object?>> analysis(AnalysisScope scope, String id);
  Future<Map<String, Object?>> associationChoices(
    String kind, {
    String search = '',
    int offset = 0,
  });
}

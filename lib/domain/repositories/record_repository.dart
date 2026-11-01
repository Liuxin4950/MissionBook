import '../entities/saved_record.dart';
import '../entities/record_draft.dart';
import '../entities/analysis_scope.dart';

/// 独立记录的内容与归属入口；任务材料保存自己的快照。
/// 执行报告由任务命令保存，长期记忆由 MemoryRepository 保存。
abstract interface class RecordRepository {
  /// 删除来源记录；已经提交的任务材料继续保留。
  Future<void> deleteRecord(String id);

  /// 同一草稿编号幂等保存；关联任务时与材料引用在同一事务提交。
  Future<void> saveRecord(
    RecordDraft draft, {
    String? goalId,
    String? nodeId,
    String? missionId,
  });

  /// 显式修改记录归属，不涉及任务引用。
  Future<void> updateOwnership(
    String id, {
    String? goalId,
    String? nodeId,
    String? operationId,
  });

  /// 页面和助手共用有界记录投影，正文可按需分段。
  Future<RecordPage> readRecords({
    String? id,
    String? goalId,
    String? nodeId,
    String? missionId,
    String? date,
    int offset = 0,
    bool content = false,
    int contentOffset = 0,
  });

  Future<RecordDraft> readDraft(String id);

  /// 对照编辑时读取的正文更正；并发变化拒绝覆盖。
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

import '../entities/goal_package_import.dart';

/// 独立暂存存储的边界；正式业务查询不会读取这里的数据。
abstract interface class GoalImportStage {
  Future<void> begin(String jobId, String goalId);
  Future<void> append(String jobId, List<GoalImportEntry> entries);
  Future<void> setRoot(String jobId, Map<String, Object?> root);
  Future<Map<String, Object?>?> pending();
  Future<List<GoalImportEntry>> entries(
    String jobId,
    String kind, {
    int offset = 0,
    int limit = 50,
  });
  Future<void> resolveBatch(String jobId, List<GoalImportEntry> entries);
  Future<void> seal(String jobId, Map<String, Object?> summary);
  Future<void> assertReady(String jobId, String hash);
  Future<void> discard(String jobId);
  Future<void> close();
}

abstract interface class GoalPackageRepository {
  Future<GoalImportResult?> receipt(
    String schema,
    String packageId,
    String hash,
  );
  Future<String?> duplicateContent(String schema, String hash);
  Future<void> review(
    GoalImportStage stage,
    GoalImportPreview preview,
    GoalImportOptions options,
  );
  Future<GoalImportResult> importPackage(
    GoalImportStage stage,
    GoalImportPreview preview,
    GoalImportOptions options,
    GoalImportCancellation cancellation,
  );
}

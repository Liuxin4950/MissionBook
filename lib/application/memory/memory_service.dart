import '../../domain/repositories/memory_repository.dart';

/// 结构化记忆的应用入口；与记录、任务事实分开，不维护目标进度。
class MemoryService {
  MemoryService(this.repository);
  final MemoryRepository repository;
  Future<Map<String, Object?>> query({
    String? goalId,
    String? search,
    int offset = 0,
    bool includeExpired = false,
  }) => repository.queryMemory(
    goalId: goalId,
    search: search,
    offset: offset,
    includeExpired: includeExpired,
  );
  Future<void> save(
    Map<String, Object?> entry, {
    bool userEdited = false,
    String? operationId,
  }) => repository.saveMemory(
    entry,
    userEdited: userEdited,
    operationId: operationId,
  );
  Future<void> forget(String id, {String? operationId}) =>
      repository.forgetMemory(id, operationId: operationId);
  Future<String> core() => repository.coreMemory();
}

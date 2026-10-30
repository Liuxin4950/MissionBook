/// 记忆维护独立于生活记录，页面与 AI 通过 MemoryService 共用此事务入口。
abstract interface class MemoryRepository {
  Future<Map<String, Object?>> queryMemory({
    String? goalId,
    String? search,
    int offset = 0,
    bool includeExpired = false,
  });
  Future<void> saveMemory(
    Map<String, Object?> entry, {
    bool userEdited = false,
    String? operationId,
  });
  Future<void> forgetMemory(String id, {String? operationId});
  Future<String> coreMemory();
}

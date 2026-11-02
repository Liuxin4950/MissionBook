/// 记忆维护独立于生活记录，页面与 AI 通过 MemoryService 共用此事务入口。
abstract interface class MemoryRepository {
  Future<Map<String, Object?>> queryMemory({
    String? goalId,
    String? search,
    int offset = 0,
    int limit = 20,
    bool includeSourceText = true,
    bool includeExpired = false,
  });
  Future<Map<String, Object?>> saveMemory(
    Map<String, Object?> entry, {
    bool userEdited = false,
    String? operationId,
  });
  Future<void> forgetMemory(String id, {String? operationId});
  Future<Map<String, Object?>> selectMemory({
    required String sessionId,
    required String selectionId,
    String? goalId,
    String? search,
    int offset = 0,
    int limit = 20,
    bool fullContent = false,
  });
  Future<Map<String, Object?>> previewForget({
    required String sessionId,
    required String selectionId,
    required List<String> itemIds,
  });
  Future<Map<String, Object?>> forgetSelection({
    required String sessionId,
    required String sourceMessageId,
    required String selectionId,
    required List<String> itemIds,
    required String operationId,
  });
  Future<Map<String, Object?>> memoryOperation({
    required String sessionId,
    required String operationId,
    int offset = 0,
  });
  Future<String> coreMemory();
}

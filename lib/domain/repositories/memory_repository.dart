const memoryVersionFields = [
  'id',
  'layer',
  'topic_id',
  'content',
  'certainty',
  'importance',
  'created_at',
  'updated_at',
  'expires_at',
  'forgotten',
  'user_edited',
  'source_kind',
  'source_ref',
  'goal_id',
];

/// 记忆维护独立于生活记录，页面与 AI 通过 MemoryService 共用此事务入口。
abstract interface class MemoryRepository {
  Future<Map<String, Object?>> queryMemory({
    String? goalId,
    String? search,
    int offset = 0,
    int limit = 20,
    bool includeSourceText = true,
    bool includeExpired = false,
    String? layer,
    String? certainty,
    int? candidateLimit,
  });
  Future<Map<String, Object?>> saveMemory(
    Map<String, Object?> entry, {
    bool userEdited = false,
    bool explicitCorrection = false,
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
    String? layer,
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
  Future<Map<String, Object?>> reflectionInput();
  Future<Map<String, Object?>> applyReflection(
    List<Map<String, Object?>> actions, {
    String? operationId,
  });
  Future<void> recordUsage({required List<String> ids, required bool injected});
  Future<List<Map<String, Object?>>> memoryEpisodes({
    String? goalId,
    String? search,
    int limit = 20,
  });
  Future<List<Map<String, Object?>>> memoryProcedures({
    String? goalId,
    String? search,
    int limit = 20,
  });
}

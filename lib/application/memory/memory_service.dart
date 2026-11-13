import '../../domain/repositories/memory_repository.dart';

/// 结构化记忆的应用入口；与记录、任务事实分开，不维护目标进度。
class MemoryService {
  MemoryService(this.repository);
  final MemoryRepository repository;
  Future<Map<String, Object?>> query({
    String? goalId,
    String? search,
    int offset = 0,
    int limit = 20,
    bool includeExpired = false,
    String? layer,
    String? certainty,
    int? candidateLimit,
  }) => repository.queryMemory(
    goalId: goalId,
    search: search,
    offset: offset,
    limit: limit,
    includeExpired: includeExpired,
    layer: layer,
    certainty: certainty,
    candidateLimit: candidateLimit,
  );
  Future<Map<String, Object?>> save(
    Map<String, Object?> entry, {
    bool userEdited = false,
    bool explicitCorrection = false,
    String? operationId,
  }) => repository.saveMemory(
    entry,
    userEdited: userEdited,
    explicitCorrection: explicitCorrection,
    operationId: operationId,
  );
  Future<void> forget(String id, {String? operationId}) =>
      repository.forgetMemory(id, operationId: operationId);
  Future<Map<String, Object?>> select({
    required String sessionId,
    required String selectionId,
    String? goalId,
    String? search,
    int offset = 0,
    int limit = 20,
    bool fullContent = false,
    String? layer,
  }) => repository.selectMemory(
    sessionId: sessionId,
    selectionId: selectionId,
    goalId: goalId,
    search: search,
    offset: offset,
    limit: limit,
    fullContent: fullContent,
    layer: layer,
  );
  Future<Map<String, Object?>> previewForget({
    required String sessionId,
    required String selectionId,
    required List<String> itemIds,
  }) => repository.previewForget(
    sessionId: sessionId,
    selectionId: selectionId,
    itemIds: itemIds,
  );
  Future<Map<String, Object?>> forgetSelection({
    required String sessionId,
    required String sourceMessageId,
    required String selectionId,
    required List<String> itemIds,
    required String operationId,
  }) => repository.forgetSelection(
    sessionId: sessionId,
    sourceMessageId: sourceMessageId,
    selectionId: selectionId,
    itemIds: itemIds,
    operationId: operationId,
  );
  Future<Map<String, Object?>> operation({
    required String sessionId,
    required String operationId,
    int offset = 0,
  }) => repository.memoryOperation(
    sessionId: sessionId,
    operationId: operationId,
    offset: offset,
  );
  Future<Map<String, Object?>> reflectionInput() =>
      repository.reflectionInput();
  Future<Map<String, Object?>> applyReflection(
    List<Map<String, Object?>> actions, {
    String? operationId,
  }) => repository.applyReflection(actions, operationId: operationId);
  Future<void> recordUsage({
    required List<String> ids,
    required bool injected,
  }) => repository.recordUsage(ids: ids, injected: injected);
  Future<List<Map<String, Object?>>> episodes({
    String? goalId,
    String? search,
    int limit = 20,
  }) => repository.memoryEpisodes(goalId: goalId, search: search, limit: limit);
  Future<List<Map<String, Object?>>> procedures({
    String? goalId,
    String? search,
    int limit = 20,
  }) =>
      repository.memoryProcedures(goalId: goalId, search: search, limit: limit);
}

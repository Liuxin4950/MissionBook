/// 助手读取目标、任务、日程和任务资料的统一契约。
abstract interface class UnifiedReader {
  Future<Map<String, Object?>> records(
    String missionId,
    String section, {
    int offset = 0,
  });
  Future<Map<String, Object?>> evidenceContent(
    String evidenceId, {
    int offset = 0,
  });
  Future<Map<String, Object?>> content(
    String missionId,
    String field, {
    int offset = 0,
  });
  Future<Map<String, Object?>> getGoal({
    String? goal,
    String? node,
    String? mission,
    int offset = 0,
  });
  Future<Map<String, Object?>> getMission({
    String? mission,
    String? search,
    String? goalId,
    String? nodeId,
    String? date,
    String? beforeDate,
    String? phase,
    bool summaryOnly = false,
    int offset = 0,
  });
  Future<Map<String, Object?>> getSchedule({String? date, int offset = 0});
}

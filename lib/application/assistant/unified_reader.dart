abstract interface class UnifiedReader {
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
    int offset = 0,
  });
  Future<Map<String, Object?>> getSchedule({String? date, int offset = 0});
}

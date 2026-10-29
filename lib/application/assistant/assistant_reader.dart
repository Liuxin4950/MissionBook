/// 助手专用的只读投影。索引不冒充完整任务阶段，正文按片段读取。
abstract interface class AssistantReader {
  Future<Map<String, Object?>> missions({
    String? date,
    String? goalId,
    String? nodeId,
    String? search,
    int offset = 0,
  });
  Future<Map<String, Object?>> goals({int offset = 0});
  Future<Map<String, Object?>> goal(String id, {int offset = 0});
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
}

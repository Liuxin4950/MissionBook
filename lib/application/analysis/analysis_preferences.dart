/// 各层自动分析偏好，手动请求和会话记忆提取分别处理。
abstract interface class AnalysisPreferencesStore {
  Future<Set<String>> load();
  Future<void> save(Set<String> scopes);
}

const summaryScopes = {'record', 'mission', 'node', 'goal'};

import '../../domain/entities/analysis_scope.dart';

/// 各层自动分析偏好，手动请求和会话记忆提取分别处理。
abstract interface class AnalysisPreferencesStore {
  Future<Set<AnalysisScope>> load();
  Future<void> save(Set<AnalysisScope> scopes);
}

const summaryScopes = {
  AnalysisScope.record,
  AnalysisScope.mission,
  AnalysisScope.node,
  AnalysisScope.goal,
};

import 'package:agent_core/agent_core.dart';

class AssistantConversationSummary {
  const AssistantConversationSummary({
    required this.id,
    required this.title,
    required this.createdAt,
    required this.updatedAt,
    this.missionId,
    this.goalId,
    this.nodeId,
  });

  final String id;
  final String title;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? missionId;
  final String? goalId;
  final String? nodeId;
}

/// 宿主会话索引契约；应用层不认识SQLite表、Companion或写租约实现。
abstract interface class AssistantConversationStore implements SessionStore {
  Future<List<AssistantConversationSummary>> listConversations();
  Future<void> attachReference(
    String id, {
    String? missionId,
    String? goalId,
    String? nodeId,
  });
}

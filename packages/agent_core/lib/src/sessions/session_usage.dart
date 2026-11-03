import '../model.dart';

/// 会话日志中所有已报告尝试的累计用量；不完整时仍可展示带标注的样本命中率。
final class SessionUsage {
  const SessionUsage({
    this.usage = const TokenUsage(),
    this.conversationUsage = const TokenUsage(),
    this.cacheUsage = const TokenUsage(),
    this.reports = 0,
    this.conversationReports = 0,
    this.conversationCacheReports = 0,
    this.incompleteReports = 0,
    this.lastConversationUsage,
  });

  /// 包含正文、摘要和重试在内的全部已计费用量。
  final TokenUsage usage;

  /// 只累计正文请求，用于正文总量。
  final TokenUsage conversationUsage;

  /// 只累计报告过缓存的正文请求；不完整时仍可展示带标注的样本命中率。
  final TokenUsage cacheUsage;

  final int reports;
  final int conversationReports;
  final int conversationCacheReports;
  final int incompleteReports;
  final TokenUsage? lastConversationUsage;

  bool get hasUsage => reports > 0;
  bool get hasIncompleteUsage => incompleteReports > 0;
  bool get cacheComplete =>
      conversationReports > 0 &&
      conversationCacheReports == conversationReports;
  double? get cacheHitRate => cacheUsage.cacheHitRate;

  SessionUsage record(
    TokenUsage sample, {
    required bool complete,
    required bool conversation,
  }) => SessionUsage(
    usage: usage + sample,
    conversationUsage: conversation
        ? conversationUsage + sample
        : conversationUsage,
    cacheUsage: conversation && sample.cacheReported == true
        ? cacheUsage + sample
        : cacheUsage,
    reports: reports + 1,
    conversationReports: conversationReports + (conversation ? 1 : 0),
    conversationCacheReports:
        conversationCacheReports +
        (conversation && sample.cacheReported == true ? 1 : 0),
    incompleteReports: incompleteReports + (complete ? 0 : 1),
    lastConversationUsage: conversation && complete && sample.inputTokens > 0
        ? sample
        : lastConversationUsage,
  );

  SessionUsage recordMalformed({required bool conversation}) => SessionUsage(
    usage: usage,
    conversationUsage: conversationUsage,
    cacheUsage: cacheUsage,
    reports: reports + 1,
    conversationReports: conversationReports + (conversation ? 1 : 0),
    conversationCacheReports: conversationCacheReports,
    incompleteReports: incompleteReports + 1,
    lastConversationUsage: lastConversationUsage,
  );
}

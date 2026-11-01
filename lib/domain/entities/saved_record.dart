import 'content_draft.dart';

/// 已保存记录的只读投影；分页正文可截断，编辑时需另读完整内容。
class SavedRecord {
  const SavedRecord({
    required this.id,
    required this.type,
    required this.source,
    required this.occurredAt,
    required this.createdAt,
    this.content,
    this.attachmentStorageKey,
    this.attachmentFileName,
    this.attachmentMimeType,
    this.capturedAt,
    this.contentLength,
    this.contentOffset,
    this.goalId,
    this.nodeId,
    this.goalTitle,
    this.nodeTitle,
    this.materialMissionId,
    this.materialMissionTitle,
    this.nextContentOffset,
    this.contentTruncated = false,
    required this.analysis,
  });
  final String id;
  final ContentType type;
  final ContentSource source;
  final String? content,
      attachmentStorageKey,
      attachmentFileName,
      attachmentMimeType;
  final DateTime? capturedAt;
  final int? contentLength, contentOffset;
  final DateTime occurredAt, createdAt;
  final String? goalId, nodeId, goalTitle, nodeTitle;
  final String? materialMissionId, materialMissionTitle;
  final int? nextContentOffset;
  final bool contentTruncated;
  final RecordAnalysis analysis;
  String get analysisState => analysis.state;
  bool get analysisStale => analysis.stale;
}

/// 记录摘要的当前状态及最近一次生成结果。
class RecordAnalysis {
  const RecordAnalysis({
    required this.state,
    required this.manual,
    required this.stale,
    this.error,
    this.content,
    this.sourceVersion,
    this.coverage,
    this.createdAt,
    this.closing,
  });
  final String state;
  final bool manual, stale;
  final String? error, content;
  final int? sourceVersion, coverage;
  final DateTime? createdAt;
  final bool? closing;
}

/// 有界记录列表，页面不依赖 SQL 列名或工具 JSON。
class RecordPage {
  RecordPage({
    required List<SavedRecord> items,
    required this.total,
    this.nextOffset,
  }) : items = List.unmodifiable(items);
  final List<SavedRecord> items;
  final int total;
  final int? nextOffset;
}

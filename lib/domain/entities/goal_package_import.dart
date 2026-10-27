import 'dart:convert';

/// 外部计划输入的资源预算；文件不能覆盖这些限制。
abstract final class GoalImportLimits {
  static const fileBytes = 32 * 1024 * 1024;
  static const pasteBytes = 2 * 1024 * 1024;
  static const nodes = 500;
  static const missions = 10000;
  static const depth = 12;
  static const jsonDepth = 64;
  static const jsonValues = 1000000;
  static const steps = 100000;
  static const missionBytes = 256 * 1024;
  static const batchBytes = 1024 * 1024;
  static const stageBytes = 256 * 1024 * 1024;
  static const pageSize = 50;
}

class GoalImportException implements Exception {
  const GoalImportException(this.code, this.path, this.message);
  final String code;
  final String path;
  final String message;
  @override
  String toString() => '$path：$message [$code]';
}

class GoalImportCancelled implements Exception {
  const GoalImportCancelled();
  @override
  String toString() => '已取消导入，未提交的数据已回滚';
}

/// 同一次读取、校验和提交共享取消信号；提交结果最终仍以回执为准。
class GoalImportCancellation {
  bool _cancelled = false;
  bool get isCancelled => _cancelled;
  void cancel() => _cancelled = true;
  void check() {
    if (_cancelled) throw const GoalImportCancelled();
  }
}

class GoalImportOptions {
  const GoalImportOptions({
    this.keepPastSchedules = false,
    this.allowDueAutoStart = false,
    this.allowOverlaps = false,
  });
  final bool keepPastSchedules;
  final bool allowDueAutoStart;
  final bool allowOverlaps;
}

/// 文件的元信息与可流读内容；不会为了选文件先完整分配字节数组。
class GoalImportSource {
  const GoalImportSource({
    required this.name,
    required this.openRead,
    this.length,
    this.maxBytes = GoalImportLimits.fileBytes,
  });
  final String name;
  final int? length;
  final int maxBytes;
  final Stream<List<int>> Function() openRead;

  factory GoalImportSource.text(String text) {
    if (text.length > GoalImportLimits.pasteBytes) {
      throw const GoalImportException('LIMIT_BYTES', '/', '粘贴内容过大，请选择 JSON 文件');
    }
    final bytes = utf8.encode(text);
    if (bytes.length > GoalImportLimits.pasteBytes) {
      throw const GoalImportException(
        'LIMIT_BYTES',
        '/',
        '粘贴内容超过 2 MiB，请选择 JSON 文件',
      );
    }
    return GoalImportSource(
      name: '粘贴的 JSON',
      length: bytes.length,
      maxBytes: GoalImportLimits.pasteBytes,
      openRead: () async* {
        for (var offset = 0; offset < bytes.length; offset += 65536) {
          final end = (offset + 65536).clamp(0, bytes.length);
          yield bytes.sublist(offset, end);
        }
      },
    );
  }
}

/// 一条暂存输入。节点用 sourceIndex/parentIndex 表达树，任务用 sourceIndex 保留顺序。
class GoalImportEntry {
  const GoalImportEntry({
    required this.kind,
    required this.sourceIndex,
    required this.key,
    required this.id,
    required this.raw,
    this.parentIndex,
    this.orderIndex = 0,
    this.scheduleId,
    this.planId,
    this.resolved,
  });
  final String kind;
  final int sourceIndex;
  final int? parentIndex;
  final int orderIndex;
  final String key;
  final String id;
  final String? scheduleId;
  final String? planId;
  final Map<String, Object?> raw;
  final Map<String, Object?>? resolved;
}

class GoalImportPreview {
  const GoalImportPreview({
    required this.jobId,
    required this.goalId,
    required this.root,
    required this.payloadHash,
    required this.contentHash,
    required this.nodeCount,
    required this.missionCount,
    required this.totalMinutes,
    required this.fixedCount,
    required this.requiredCount,
    required this.optionalCount,
    this.existingGoalId,
    this.duplicateGoalId,
  });
  final String jobId;
  final String goalId;
  final Map<String, Object?> root;
  final String payloadHash;
  final String contentHash;
  final int nodeCount;
  final int missionCount;
  final int totalMinutes;
  final int fixedCount;
  final int requiredCount;
  final int optionalCount;
  final String? existingGoalId;
  final String? duplicateGoalId;
  String get schema => root['schema']! as String;
  bool get isOutline => schema == 'mission-book.goal-outline';
  String get packageId => isOutline ? jobId : root['packageId']! as String;
  Map<String, Object?> get goal =>
      (root['goal']! as Map).cast<String, Object?>();
  String get title => (goal['title']! as String).trim();
}

class GoalImportResult {
  const GoalImportResult({
    required this.goalId,
    required this.nodeCount,
    required this.missionCount,
    this.alreadyImported = false,
  });
  final String goalId;
  final int nodeCount;
  final int missionCount;
  final bool alreadyImported;
}

/// 预览/提交共用的固定计划窗口，不把计划结束误当成实际 END。
class GoalImportWindow {
  const GoalImportWindow(this.id, this.title, this.start, this.end);
  final String id;
  final String title;
  final DateTime start;
  final DateTime end;
}

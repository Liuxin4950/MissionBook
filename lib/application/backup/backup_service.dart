import 'dart:typed_data';

/// 我的页面只依赖备份操作，不直接访问数据库或平台文件。
abstract interface class BackupExporter {
  Future<Uint8List> create();
}

/// 校验后的备份概览；具体数据由恢复实现持有，页面只呈现范围。
class BackupRestorePlan {
  const BackupRestorePlan({
    required this.exportedAt,
    required this.counts,
    required this.currentCounts,
    required this.attachmentCount,
    required this.attachmentBytes,
  });
  final DateTime exportedAt;
  final Map<String, int> counts, currentCounts;
  final int attachmentCount, attachmentBytes;
}

class BackupRestoreResult {
  const BackupRestoreResult(this.counts, this.attachmentCount);
  final Map<String, int> counts;
  final int attachmentCount;
}

abstract interface class BackupRestorer {
  Future<BackupRestorePlan> prepareRestore(Uint8List bytes);
  Future<BackupRestoreResult> restore(BackupRestorePlan plan);
}

/// 装配层负责暂停旧工作区并重建服务，恢复器负责数据原子性。
class ManagedBackupService implements BackupExporter, BackupRestorer {
  const ManagedBackupService({
    required this.exporter,
    required this.restorer,
    required this.runRestore,
  });
  final BackupExporter exporter;
  final BackupRestorer restorer;
  final Future<BackupRestoreResult> Function(
    Future<BackupRestoreResult> Function(),
  )
  runRestore;
  @override
  Future<Uint8List> create() => exporter.create();
  @override
  Future<BackupRestorePlan> prepareRestore(Uint8List bytes) =>
      restorer.prepareRestore(bytes);
  @override
  Future<BackupRestoreResult> restore(BackupRestorePlan plan) =>
      runRestore(() => restorer.restore(plan));
}

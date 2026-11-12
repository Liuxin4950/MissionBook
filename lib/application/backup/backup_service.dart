import 'dart:typed_data';

/// 可勾选的本机资源。业务数据与材料原件是恢复必需的整体，始终一起导出，
/// 因此不在此列；这里只表达用户可以选择要不要带走的部分。
enum BackupResource {
  assistantSettings('API Key 与助手设置', '模型、语音、权限、人格与推理档位'),
  localPreferences('本机资料与偏好', '姓名简介、页面动效与提醒偏好'),
  speechModel('离线语音模型', '已下载的 SenseVoice 模型，约 228 MiB');

  const BackupResource(this.label, this.description);
  final String label;
  final String description;
}

/// 默认带走密钥与本机偏好，不带体积最大的语音模型。
const defaultBackupResources = {
  BackupResource.assistantSettings,
  BackupResource.localPreferences,
};

/// 我的页面只依赖备份操作，不直接访问数据库或平台文件。
abstract interface class BackupExporter {
  Future<Uint8List> create({
    Set<BackupResource> resources = defaultBackupResources,
  });
}

/// 校验后的备份概览；具体数据由恢复实现持有，页面只呈现范围。
class BackupRestorePlan {
  const BackupRestorePlan({
    required this.exportedAt,
    required this.counts,
    required this.currentCounts,
    required this.attachmentCount,
    required this.attachmentBytes,
    this.resources = const {},
  });
  final DateTime exportedAt;
  final Map<String, int> counts, currentCounts;
  final int attachmentCount, attachmentBytes;

  /// 这份备份实际带走的本机资源；恢复时只写回包内存在的类别。
  final Set<BackupResource> resources;
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
  Future<Uint8List> create({
    Set<BackupResource> resources = defaultBackupResources,
  }) => exporter.create(resources: resources);
  @override
  Future<BackupRestorePlan> prepareRestore(Uint8List bytes) =>
      restorer.prepareRestore(bytes);
  @override
  Future<BackupRestoreResult> restore(BackupRestorePlan plan) =>
      runRestore(() => restorer.restore(plan));
}

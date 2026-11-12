import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../application/backup/backup_service.dart';
import '../../application/settings/app_device.dart';
import '../../core/theme/app_layout.dart';
import '../widgets/app_section_card.dart';
import '../widgets/app_section_header.dart';
import '../widgets/app_top_bar.dart';
import '../widgets/data_export_card.dart';
import 'backup_restore_card.dart';

/// 软件设置与助手共用的完整备份页面。
class DataBackupPage extends StatelessWidget {
  const DataBackupPage({
    super.key,
    required this.backup,
    required this.device,
    this.selectBackup,
  });
  final BackupExporter backup;
  final AppDevice device;
  final Future<Uint8List?> Function()? selectBackup;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: const AppTopBar(title: '数据备份'),
    body: SafeArea(
      top: false,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: AppLayout.maxPageWidth),
          child: ListView(
            padding: AppLayout.pagePadding(context),
            children: [
              AppSectionCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const AppSectionHeader('完整本地备份'),
                    const SizedBox(height: AppLayout.spaceMd),
                    Text(
                      '包含任务、目标、记录、正式材料原件、长期记忆和已保存的助手会话。',
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                    const SizedBox(height: AppLayout.spaceSm),
                    Text(
                      '导出前可选择是否带走 API Key 与助手设置、本机资料与偏好、离线语音模型。恢复时包内存在的资源会一并写回，未包含的类别保留当前设备值。',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppLayout.spaceLg),
              DataExportCard(backup: backup, device: device),
              if (backup case final BackupRestorer restorer) ...[
                const SizedBox(height: AppLayout.spaceLg),
                BackupRestoreCard(
                  restorer: restorer,
                  selectBackup: selectBackup,
                ),
              ],
            ],
          ),
        ),
      ),
    ),
  );
}

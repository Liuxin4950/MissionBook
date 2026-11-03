import 'package:flutter/material.dart';

import '../../application/backup/backup_service.dart';
import '../../application/settings/app_device.dart';
import '../../core/theme/app_layout.dart';
import '../widgets/app_section_card.dart';
import '../widgets/app_section_header.dart';
import '../widgets/app_top_bar.dart';
import '../widgets/data_export_card.dart';

/// 软件设置与助手共用的完整备份页面。
class DataBackupPage extends StatelessWidget {
  const DataBackupPage({super.key, required this.backup, required this.device});
  final BackupExporter backup;
  final AppDevice device;
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
                      '包含任务、目标、记录、正式材料原件和已保存的助手会话。',
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                    const SizedBox(height: AppLayout.spaceSm),
                    Text(
                      '不含 API Key、未发送草稿、缓存、本机资料和提醒偏好。当前支持导出 ZIP，应用内暂不支持导入恢复。',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppLayout.spaceLg),
              DataExportCard(backup: backup, device: device),
            ],
          ),
        ),
      ),
    ),
  );
}

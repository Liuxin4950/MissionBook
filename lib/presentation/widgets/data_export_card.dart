import 'package:flutter/material.dart';

import '../../application/backup/backup_service.dart';
import '../../application/settings/app_device.dart';
import '../../core/theme/app_layout.dart';
import '../../core/theme/colors.dart';
import 'app_section_card.dart';

/// 设置和助手共用同一个完整数据导出入口，保留取消、重试与保存结果反馈。
class DataExportCard extends StatefulWidget {
  const DataExportCard({super.key, required this.backup, required this.device});
  final BackupExporter backup;
  final AppDevice device;
  @override
  State<DataExportCard> createState() => _DataExportCardState();
}

class _DataExportCardState extends State<DataExportCard> {
  bool _exporting = false;
  bool _backupFailed = false;
  String? _backupMessage;

  Future<void> _export() async {
    if (_exporting) return;
    setState(() {
      _exporting = true;
      _backupFailed = false;
      _backupMessage = '正在准备数据与正式附件…';
    });
    try {
      final bytes = await widget.backup.create();
      if (!mounted) return;
      setState(() => _backupMessage = '备份已准备好，请选择保存位置');
      final stamp = DateTime.now().toUtc().toIso8601String().replaceAll(
        RegExp(r'[:.]'),
        '-',
      );
      final result = await widget.device.saveBackup(
        bytes,
        'MissionBook-$stamp.zip',
      );
      if (mounted) setState(() => _backupMessage = result ?? '已取消保存，可以随时重新导出');
    } catch (error, stack) {
      debugPrint('本地备份导出失败：$error\n$stack');
      if (mounted) {
        setState(() {
          _backupFailed = true;
          _backupMessage = '导出失败，请检查保存位置和正式附件后重试，源数据已保留';
        });
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final action = TextButton.icon(
      key: const Key('backup-export'),
      onPressed: _exporting ? null : _export,
      style: TextButton.styleFrom(
        textStyle: text.labelMedium,
        minimumSize: const Size(0, AppLayout.touchTargetMin),
        padding: const EdgeInsets.symmetric(
          horizontal: AppLayout.spaceMd,
          vertical: AppLayout.spaceSm,
        ),
      ),
      icon: _exporting
          ? const SizedBox(
              width: AppLayout.iconSm,
              height: AppLayout.iconSm,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.file_download_outlined, size: AppLayout.iconSm),
      label: Text(_exporting ? '正在导出…' : (_backupFailed ? '重试导出' : '导出备份')),
    );
    return AppSectionCard(
      padding: EdgeInsets.zero,
      child: LayoutBuilder(
        builder: (context, box) {
          final inline =
              box.maxWidth >= 340 * MediaQuery.textScalerOf(context).scale(1);
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 56),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppLayout.spaceLg,
                    vertical: AppLayout.spaceSm,
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.archive_outlined,
                        size: AppLayout.iconMd,
                        color: AppColors.textSecondary,
                      ),
                      const SizedBox(width: AppLayout.spaceMd),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('本地备份', style: text.titleMedium),
                            Text('目标、任务、材料与助手会话', style: text.bodyMedium),
                          ],
                        ),
                      ),
                      if (inline) ...[
                        const SizedBox(width: AppLayout.spaceSm),
                        action,
                      ],
                    ],
                  ),
                ),
              ),
              if (!inline)
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppLayout.spaceLg,
                    0,
                    AppLayout.spaceLg,
                    AppLayout.spaceSm,
                  ),
                  child: Align(alignment: Alignment.centerLeft, child: action),
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppLayout.spaceLg,
                  0,
                  AppLayout.spaceLg,
                  AppLayout.spaceMd,
                ),
                child: Text('不含 API Key 与未发送草稿；暂不支持恢复。', style: text.bodySmall),
              ),
              if (_backupMessage != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppLayout.spaceLg,
                    0,
                    AppLayout.spaceLg,
                    AppLayout.spaceMd,
                  ),
                  child: Semantics(
                    liveRegion: true,
                    child: Text(
                      _backupMessage!,
                      key: const Key('backup-result'),
                      style: text.bodyMedium?.copyWith(
                        color: _backupFailed
                            ? AppColors.error
                            : AppColors.textSecondary,
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../../application/backup/backup_service.dart';
import '../../application/settings/app_device.dart';
import '../../core/theme/app_layout.dart';
import '../../core/theme/colors.dart';
import 'adaptive_sheet.dart';
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

  Future<void> _showDetails() => showAdaptiveSheet<void>(
    context: context,
    builder: (sheetContext) {
      final text = Theme.of(sheetContext).textTheme;
      return SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppLayout.spaceXl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.archive_outlined,
                    size: AppLayout.iconMd,
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: AppLayout.spaceSm),
                  Expanded(child: Text('本地备份说明', style: text.titleMedium)),
                ],
              ),
              const SizedBox(height: AppLayout.spaceLg),
              _detail(sheetContext, '包含', '数据库完整快照、正式材料原件和已保存的助手会话。'),
              const SizedBox(height: AppLayout.spaceMd),
              _detail(sheetContext, '不含', 'API Key、未发送草稿、缓存、本机资料和提醒偏好。'),
              const SizedBox(height: AppLayout.spaceMd),
              _detail(sheetContext, '恢复', '当前只支持导出，应用内暂不支持导入恢复。'),
              const SizedBox(height: AppLayout.spaceXl),
              FilledButton(
                key: const Key('backup-info-close'),
                onPressed: () => Navigator.of(sheetContext).pop(),
                child: const Text('知道了'),
              ),
            ],
          ),
        ),
      );
    },
  );

  Widget _detail(BuildContext context, String label, String value) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: Theme.of(context).textTheme.titleSmall),
      const SizedBox(height: AppLayout.spaceXs),
      Text(
        value,
        style: Theme.of(
          context,
        ).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
      ),
    ],
  );

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
                        child: Row(
                          children: [
                            Flexible(
                              child: Text('本地备份', style: text.titleMedium),
                            ),
                            const SizedBox(width: AppLayout.spaceXs),
                            IconButton(
                              key: const Key('backup-info'),
                              onPressed: _showDetails,
                              tooltip: '备份说明',
                              icon: const Icon(Icons.priority_high_rounded),
                              iconSize: AppLayout.iconSm,
                              style: IconButton.styleFrom(
                                foregroundColor: AppColors.textSecondary,
                                minimumSize: const Size.square(
                                  AppLayout.touchTargetMin,
                                ),
                                padding: EdgeInsets.zero,
                              ),
                            ),
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

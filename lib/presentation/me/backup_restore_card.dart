import 'dart:typed_data';
import 'package:flutter/material.dart';

import '../../application/backup/backup_service.dart';
import '../../core/theme/app_layout.dart';
import '../../core/theme/colors.dart';
import '../../data/backup/backup_file_picker.dart';
import '../widgets/app_confirm_dialog.dart';
import '../widgets/app_section_card.dart';
import '../widgets/app_section_header.dart';

/// 选择、校验和核对范围后恢复；页面不执行 SQL 或直接写附件。
class BackupRestoreCard extends StatefulWidget {
  const BackupRestoreCard({
    super.key,
    required this.restorer,
    this.selectBackup,
  });
  final BackupRestorer restorer;
  final Future<Uint8List?> Function()? selectBackup;
  @override
  State<BackupRestoreCard> createState() => _BackupRestoreCardState();
}

class _BackupRestoreCardState extends State<BackupRestoreCard> {
  BackupRestorePlan? _plan;
  bool _busy = false, _restoring = false, _confirming = false;
  String? _error, _message;

  Future<void> _select() async {
    if (_busy || _confirming) return;
    setState(() {
      _busy = true;
      _error = null;
      _message = null;
    });
    try {
      final bytes = await (widget.selectBackup ?? pickBackupFile)();
      if (bytes == null) {
        if (mounted) setState(() => _message = '已取消选择');
        return;
      }
      if (!mounted) return;
      setState(() {
        _plan = null;
        _message = '正在校验数据库与附件…';
      });
      final plan = await widget.restorer.prepareRestore(bytes);
      if (mounted) {
        setState(() {
          _plan = plan;
          _message = '备份校验通过，尚未修改当前数据';
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _plan = null;
          _message = null;
          _error = error is FormatException
              ? error.message
              : '备份校验失败，请检查文件完整性后重试';
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _restore() async {
    final plan = _plan;
    if (plan == null || _busy || _confirming) return;
    _confirming = true;
    final accepted = await AppConfirmDialog.show(
      context: context,
      title: '用备份替换当前数据？',
      message:
          '将恢复 ${plan.counts['missions'] ?? 0} 项任务、${plan.counts['records'] ?? 0} 条记录、${plan.counts['assistant_sessions'] ?? 0} 个会话及 ${plan.attachmentCount} 个附件。当前业务数据会被替换。${plan.resources.isEmpty ? 'API Key、本机资料和提醒偏好保留当前设备值。' : '包内的${plan.resources.map((r) => r.label).join('、')}会一并写回并替换当前值。'}确认前可先导出当前数据。',
      cancelText: '保留当前数据',
      confirmText: '替换并恢复',
    );
    _confirming = false;
    if (!mounted || !accepted) return;
    setState(() {
      _busy = true;
      _restoring = true;
      _error = null;
      _message = '正在恢复数据…';
    });
    try {
      await widget.restorer.restore(plan);
      if (mounted) {
        setState(() {
          _plan = null;
          _message = '备份已恢复';
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _plan = null;
          _message = null;
          _error = error is StateError
              ? error.message
              : '恢复未完成，原数据已保留，请重新校验后重试';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _restoring = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final plan = _plan;
    return PopScope<void>(
      canPop: !_busy && !_confirming,
      onPopInvokedWithResult: (didPop, _) {
        // 校验或恢复期间返回键被拦截，必须给出原因，不能静默无响应。
        if (!didPop && mounted) {
          setState(
            () => _message = _restoring
                ? '正在恢复数据，请等待完成后再返回'
                : '正在校验备份，请等待完成后再返回',
          );
        }
      },
      child: AppSectionCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const AppSectionHeader('导入并恢复'),
            const SizedBox(height: AppLayout.spaceSm),
            Text(
              '选择 MissionBook 导出的 ZIP，校验后核对范围。恢复会替换全部业务数据，并重新打开工作区。',
              style: text.bodyMedium,
            ),
            const SizedBox(height: AppLayout.spaceMd),
            OutlinedButton.icon(
              key: const Key('backup-select-import'),
              onPressed: _busy ? null : _select,
              icon: const Icon(Icons.folder_open_outlined),
              label: Text(_busy && !_restoring ? '正在校验…' : '选择备份 ZIP'),
            ),
            if (plan != null) ...[
              const SizedBox(height: AppLayout.spaceLg),
              Text(
                '备份时间：${_date(plan.exportedAt.toLocal())}',
                style: text.bodyMedium,
              ),
              const SizedBox(height: AppLayout.spaceSm),
              for (final entry in const {
                'goals': '目标',
                'goal_nodes': '节点',
                'missions': '任务',
                'records': '记录',
                'evidence_records': '任务材料',
                'memory_items': '长期记忆',
                'memory_topics': '记忆主题',
                'memory_versions': '记忆版本',
                'assistant_sessions': '助手会话',
                'assistant_session_records': '会话日志',
              }.entries)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppLayout.spaceXs),
                  child: Text(
                    '${entry.value}：${plan.counts[entry.key] ?? 0}（当前 ${plan.currentCounts[entry.key] ?? 0}）',
                    style: text.bodyMedium,
                  ),
                ),
              Text(
                '附件：${plan.attachmentCount} 个 · ${(plan.attachmentBytes / 1048576).toStringAsFixed(1)} MiB',
                style: text.bodyMedium,
              ),
              const SizedBox(height: AppLayout.spaceXs),
              Text(
                plan.resources.isEmpty
                    ? '本机资源：未包含，保留当前设备设置'
                    : '本机资源：${plan.resources.map((r) => r.label).join('、')}',
                style: text.bodyMedium,
              ),
              const SizedBox(height: AppLayout.spaceLg),
              FilledButton(
                key: const Key('backup-confirm-import'),
                onPressed: _busy ? null : _restore,
                child: const Text('恢复这份备份'),
              ),
            ],
            if (_busy)
              const Padding(
                padding: EdgeInsets.only(top: AppLayout.spaceMd),
                child: LinearProgressIndicator(),
              ),
            if (_error != null || _message != null)
              Padding(
                padding: const EdgeInsets.only(top: AppLayout.spaceMd),
                child: Semantics(
                  liveRegion: true,
                  child: Text(
                    _error ?? _message!,
                    key: const Key('backup-import-result'),
                    style: text.bodyMedium?.copyWith(
                      color: _error != null
                          ? AppColors.error
                          : AppColors.textSecondary,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _date(DateTime value) =>
      '${value.year}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')} ${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
}

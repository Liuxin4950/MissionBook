import 'dart:async';
import 'package:flutter/material.dart';

import '../../application/backup/backup_service.dart';
import '../../application/settings/app_device.dart';
import '../../core/theme/app_layout.dart';
import '../../core/theme/colors.dart';
import '../widgets/app_page_header.dart';

/// 本地能力与数据出口；不创建账号、云同步或尚未提供的设置开关。
class MePage extends StatefulWidget {
  const MePage({super.key, required this.device, required this.backup});
  final AppDevice device;
  final BackupExporter backup;
  @override
  State<MePage> createState() => _MePageState();
}

class _MePageState extends State<MePage> with WidgetsBindingObserver {
  DeviceCapabilities? _capabilities;
  bool _querying = false;
  bool _openingSettings = false;
  bool _exporting = false;
  bool _backupFailed = false;
  String? _capabilityError;
  String? _backupMessage;
  bool _about = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_refresh());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(_refresh());
  }

  Future<void> _refresh() async {
    if (_querying) return;
    setState(() {
      _querying = true;
      _capabilityError = null;
    });
    try {
      final result = await widget.device.capabilities();
      if (mounted) setState(() => _capabilities = result);
    } catch (error, stack) {
      debugPrint('系统权限读取失败：$error\n$stack');
      if (mounted) setState(() => _capabilityError = '暂时无法读取系统权限，请重试');
    } finally {
      if (mounted) setState(() => _querying = false);
    }
  }

  Future<void> _settings(bool exactAlarms) async {
    if (_openingSettings) return;
    setState(() => _openingSettings = true);
    try {
      await widget.device.openSettings(exactAlarms: exactAlarms);
    } catch (error, stack) {
      debugPrint('系统设置打开失败：$error\n$stack');
      if (mounted) setState(() => _capabilityError = '无法打开系统设置，请在系统中手动管理权限');
    } finally {
      if (mounted) setState(() => _openingSettings = false);
    }
  }

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
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final capabilities = _capabilities;
    return SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: AppLayout.maxPageWidth),
          child: ListView(
            padding: AppLayout.pagePadding(context),
            children: [
              AppPageHeader(
                title: '我的',
                subtitle: Text('设置与数据都在这台设备上', style: text.bodyMedium),
              ),
              const SizedBox(height: 12),
              Text('提醒与权限', style: text.titleMedium),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.accent.withValues(alpha: .78),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const CircleAvatar(
                      radius: 26,
                      backgroundColor: AppColors.card,
                      child: Icon(
                        Icons.notifications_off_outlined,
                        size: 26,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '系统提醒尚未接通',
                            style: text.bodyLarge?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '任务仍可手动管理与执行。授权后也不会自动发送提醒。',
                            style: text.bodyMedium?.copyWith(
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              if (_capabilityError != null) ...[
                const SizedBox(height: 8),
                Semantics(
                  liveRegion: true,
                  child: Text(
                    _capabilityError!,
                    style: text.bodyMedium?.copyWith(color: AppColors.error),
                  ),
                ),
              ],
              if (capabilities == null)
                TextButton(
                  onPressed: _querying ? null : _refresh,
                  child: Text(_querying ? '正在读取权限…' : '重新读取权限'),
                )
              else ...[
                const SizedBox(height: 8),
                _permission('系统通知', capabilities.notifications, false),
                if (capabilities.android) ...[
                  const Divider(height: 1),
                  _permission('准时提醒权限', capabilities.exactAlarms, true),
                ],
              ],
              const SizedBox(height: 16),
              Text('数据', style: text.titleMedium),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.card,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        const CircleAvatar(
                          radius: 26,
                          backgroundColor: AppColors.primarySoft,
                          child: Icon(
                            Icons.file_upload_outlined,
                            size: 26,
                            color: AppColors.primary,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '本地备份',
                                style: text.bodyLarge?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _backupMessage == null
                                    ? '本次尚未导出'
                                    : (_backupFailed ? '上次导出未成功' : '查看下方导出结果'),
                                style: text.bodyMedium,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text('包含数据库与正式附件，不含草稿。当前暂不支持恢复导入。', style: text.bodyMedium),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerRight,
                      child: FilledButton.icon(
                        key: const Key('backup-export'),
                        onPressed: _exporting ? null : _export,
                        icon: _exporting
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(
                                Icons.file_download_outlined,
                                size: 20,
                              ),
                        label: Text(
                          _exporting
                              ? '正在导出…'
                              : (_backupFailed ? '重试导出' : '导出备份'),
                        ),
                        style: FilledButton.styleFrom(
                          minimumSize: const Size(0, 48),
                          shape: const StadiumBorder(),
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                        ),
                      ),
                    ),
                    if (_backupMessage != null) ...[
                      const SizedBox(height: 12),
                      Semantics(
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
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 12),
              const Divider(height: 1),
              const SizedBox(height: 12),
              InkWell(
                key: const Key('about-toggle'),
                borderRadius: BorderRadius.circular(16),
                onTap: () => setState(() => _about = !_about),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Row(
                    children: [
                      const CircleAvatar(
                        radius: 26,
                        backgroundColor: AppColors.primarySoft,
                        child: Icon(
                          Icons.info_outline,
                          size: 26,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '关于 Mission Book',
                              style: text.bodyLarge?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              capabilities?.version ?? '版本读取中…',
                              key: const Key('app-version'),
                              style: text.bodyMedium,
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        _about ? Icons.expand_less : Icons.expand_more,
                        color: AppColors.textSecondary,
                      ),
                    ],
                  ),
                ),
              ),
              if (_about)
                Padding(
                  padding: const EdgeInsets.fromLTRB(68, 0, 12, 8),
                  child: Text(
                    '把目标落到行动，让记录忠于事实。数据保存在当前设备。强行停止或省电限制可能影响未来的后台提醒。',
                    style: text.bodyMedium,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _permission(String title, bool? allowed, bool exact) {
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: AppColors.primarySoft,
            child: Icon(
              exact ? Icons.alarm_outlined : Icons.notifications_outlined,
              size: 22,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: text.titleSmall),
                Text(
                  allowed == null ? '当前平台无法查询' : (allowed ? '系统已允许' : '系统未允许'),
                  style: text.bodySmall,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          OutlinedButton(
            onPressed: _openingSettings ? null : () => _settings(exact),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(48, 44),
              shape: const StadiumBorder(),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              textStyle: text.labelMedium,
            ),
            child: const Text('去设置'),
          ),
        ],
      ),
    );
  }
}

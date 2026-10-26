import '../widgets/adaptive_sheet.dart';
import '../widgets/adaptive_columns.dart';
import '../widgets/app_section_card.dart';
import 'dart:async';
import '../../application/notifications/app_notification_service.dart';
import 'package:flutter/material.dart';

import '../../application/backup/backup_service.dart';
import '../../application/settings/app_device.dart';
import '../../core/theme/app_layout.dart';
import '../../core/theme/colors.dart';
import '../widgets/app_top_bar.dart';

/// 从个人页打开的设置工作区，集中管理提醒权限、计划提醒和本地备份。
class SettingsPage extends StatefulWidget {
  const SettingsPage({
    super.key,
    required this.device,
    required this.backup,
    this.notifications,
  });
  final AppDevice device;
  final BackupExporter backup;
  final AppNotificationService? notifications;
  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage>
    with WidgetsBindingObserver {
  DeviceCapabilities? _capabilities;
  bool _querying = false;
  bool _refreshingNotifications = false;
  bool _refreshAgain = false;
  bool _openingSettings = false;
  bool _exporting = false;
  bool _backupFailed = false;
  String? _capabilityError;
  String? _backupMessage;
  bool _about = false;
  bool _savingScheduleSettings = false;
  String? _scheduleSettingsError;

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
    if (!mounted) return;
    // 查询期间从系统设置返回时，再查一次，避免丢掉刚变更的权限。
    _refreshAgain = true;
    if (_querying) return;
    setState(() {
      _querying = true;
      _capabilityError = null;
    });
    try {
      do {
        _refreshAgain = false;
        final result = await widget.device.capabilities();
        if (!mounted) return;
        // 有更新的查询意图时，不先展示返回前捕获的旧权限。
        if (!_refreshAgain) setState(() => _capabilities = result);
      } while (_refreshAgain && mounted);
    } catch (error, stack) {
      debugPrint('系统权限读取失败：$error\n$stack');
      if (mounted) setState(() => _capabilityError = '暂时无法读取系统权限，请重试');
    } finally {
      if (mounted) setState(() => _querying = false);
    }
  }

  Future<void> _refreshNotifications() async {
    if (_refreshingNotifications) return;
    setState(() => _refreshingNotifications = true);
    try {
      await widget.notifications?.refresh();
      await _refresh();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('已刷新通知状态，送达情况请在系统通知栏确认')));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('通知更新失败，请检查权限后重试')));
      }
    } finally {
      if (mounted) setState(() => _refreshingNotifications = false);
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

  Future<void> _chooseReminder() async {
    final service = widget.notifications;
    if (service == null || _savingScheduleSettings) return;
    final minutes = await showAdaptiveSheet<int>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text('计划任务提醒时间'),
              ),
              for (final value in [-1, 0, 5, 10, 15, 30, 60])
                ListTile(
                  key: Key('reminder-minutes-$value'),
                  title: Text(_reminderLabel(value)),
                  selected: service.reminderLeadMinutes == value,
                  trailing: service.reminderLeadMinutes == value
                      ? const Icon(Icons.check)
                      : null,
                  onTap: () => Navigator.pop(sheetContext, value),
                ),
            ],
          ),
        ),
      ),
    );
    if (minutes == null || !mounted) return;
    await _saveScheduleSetting(() => service.setReminderLeadMinutes(minutes));
  }

  String _reminderLabel(int minutes) {
    if (minutes < 0) return '关闭提前提醒';
    if (minutes == 0) return '开始时提醒';
    return '提前 $minutes 分钟提醒';
  }

  Future<void> _saveScheduleSetting(Future<void> Function() save) async {
    if (_savingScheduleSettings) return;
    setState(() {
      _savingScheduleSettings = true;
      _scheduleSettingsError = null;
    });
    try {
      await save();
    } catch (error) {
      if (mounted) {
        setState(() => _scheduleSettingsError = '设置操作未完成，请重试：$error');
      }
    } finally {
      if (mounted) setState(() => _savingScheduleSettings = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final capabilities = _capabilities;
    final needsNotifications = capabilities?.notifications == false;
    final needsExactAlarms =
        capabilities?.android == true && capabilities?.exactAlarms == false;
    final needsExecutionChannel = capabilities?.executionNotifications == false;
    final needsPermission =
        needsNotifications || needsExactAlarms || needsExecutionChannel;
    final unknownPermission =
        capabilities?.notifications == null ||
        (capabilities?.android == true && capabilities?.exactAlarms == null);
    String reminderTitle;
    String reminderDescription;
    IconData reminderIcon;
    if (_capabilityError != null) {
      reminderTitle = '暂时无法确认提醒权限';
      reminderDescription = '请重新读取权限状态。任务仍可手动管理与执行。';
      reminderIcon = Icons.info_outline;
    } else if (capabilities == null) {
      reminderTitle = '正在读取提醒权限';
      reminderDescription = '正在查询这台设备的系统通知与提醒权限。';
      reminderIcon = Icons.notifications_outlined;
    } else if (needsNotifications) {
      reminderTitle = '开启系统通知';
      reminderDescription = '允许通知后，可在系统通知栏查看任务提醒与执行状态。';
      reminderIcon = Icons.notifications_off_outlined;
    } else if (needsExecutionChannel) {
      reminderTitle = '执行状态通知已关闭';
      reminderDescription = '请在系统通知设置中开启“执行状态”分类，才能在退出页面后查看计时。';
      reminderIcon = Icons.notifications_off_outlined;
    } else if (unknownPermission) {
      reminderTitle = '部分提醒权限无法查询';
      reminderDescription = '当前平台无法确认全部提醒权限，可在系统设置中查看。';
      reminderIcon = Icons.info_outline;
    } else if (needsExactAlarms) {
      reminderTitle = '准时提醒权限待开启';
      reminderDescription = '系统通知已允许；开启准时提醒权限后，固定任务可按设定时刻提醒。';
      reminderIcon = Icons.alarm_outlined;
    } else {
      reminderTitle = '提醒权限已就绪';
      reminderDescription = '可在系统通知栏查看固定任务提醒与执行状态。';
      reminderIcon = Icons.notifications_active_outlined;
    }
    final reminderSummary = Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: needsPermission ? AppColors.accent : AppColors.primarySoft,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            backgroundColor: AppColors.card,
            child: Icon(reminderIcon, color: AppColors.primary),
          ),
          const SizedBox(height: 16),
          Text(reminderTitle, style: text.titleMedium),
          const SizedBox(height: 8),
          Text(
            reminderDescription,
            style: text.bodyMedium?.copyWith(color: AppColors.textPrimary),
          ),
        ],
      ),
    );
    return Scaffold(
      appBar: const AppTopBar(title: '设置'),
      body: SafeArea(
        top: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: AppLayout.dashboardMaxWidth,
            ),
            child: ListView(
              padding: AppLayout.pagePadding(context),
              children: [
                Text('提醒与权限', style: text.titleMedium),
                const SizedBox(height: 12),
                AdaptiveColumns(
                  key: const Key('permission-columns'),
                  minColumnWidth: 270,
                  children: [
                    reminderSummary,
                    if (needsPermission && _capabilityError == null) ...[
                      if (needsNotifications || needsExecutionChannel)
                        _permission(
                          needsNotifications ? '系统通知' : '执行状态通知',
                          false,
                        ),
                      if (needsExactAlarms) _permission('准时提醒权限', true),
                    ],
                  ],
                ),
                if (_capabilityError != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Semantics(
                      liveRegion: true,
                      child: Text(
                        _capabilityError!,
                        style: text.bodyMedium?.copyWith(
                          color: AppColors.error,
                        ),
                      ),
                    ),
                  ),
                if (capabilities == null ||
                    unknownPermission ||
                    _capabilityError != null)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton(
                      key: const Key('refresh-permissions'),
                      onPressed: _querying ? null : _refresh,
                      child: Text(_querying ? '正在读取权限…' : '重新读取权限'),
                    ),
                  ),
                const SizedBox(height: 24),
                AppSectionCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text('系统计时与超级岛', style: text.titleMedium),
                      const SizedBox(height: 8),
                      Text(
                        '执行中可在系统通知栏查看累计专注；暂停冻结，结束移除。',
                        style: text.bodyMedium,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _islandDescription(capabilities),
                        key: const Key('island-capability-status'),
                        style: text.bodySmall,
                      ),
                      if (widget.notifications != null)
                        Align(
                          alignment: Alignment.centerLeft,
                          child: TextButton.icon(
                            key: const Key('notification-refresh'),
                            onPressed: _querying || _refreshingNotifications
                                ? null
                                : _refreshNotifications,
                            icon: const Icon(Icons.refresh),
                            label: const Text('刷新执行通知'),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                AdaptiveColumns(
                  key: const Key('settings-columns'),
                  minColumnWidth: 360,
                  maxColumns: 2,
                  children: [
                    if (widget.notifications != null)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text('计划任务', style: text.titleMedium),
                          const SizedBox(height: 12),
                          AppSectionCard(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                StreamBuilder<void>(
                                  stream: widget.notifications!.settingsChanges,
                                  builder: (context, _) => ListTile(
                                    key: const Key('planned-reminder-setting'),
                                    contentPadding: EdgeInsets.zero,
                                    leading: const Icon(Icons.alarm_outlined),
                                    title: Text(
                                      _reminderLabel(
                                        widget
                                            .notifications!
                                            .reminderLeadMinutes,
                                      ),
                                      style: text.titleMedium,
                                    ),
                                    subtitle: const Text('应用于所有尚未开始的固定任务'),
                                    trailing: const Icon(Icons.chevron_right),
                                    onTap: _savingScheduleSettings
                                        ? null
                                        : _chooseReminder,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  '固定任务到点自动开始；若已有任务在执行，会保留当前计时并提醒处理。错过整个计划时段后可手动开始或重新安排。',
                                  style: text.bodySmall,
                                ),
                                if (_scheduleSettingsError != null)
                                  Semantics(
                                    liveRegion: true,
                                    child: Text(
                                      _scheduleSettingsError!,
                                      style: TextStyle(
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.error,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
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
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
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
                                              : (_backupFailed
                                                    ? '上次导出未成功'
                                                    : '查看下方导出结果'),
                                          style: text.bodyMedium,
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                '包含数据库与正式附件，不含草稿。当前暂不支持恢复导入。',
                                style: text.bodyMedium,
                              ),
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
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 20,
                                    ),
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
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Text('关于', style: text.titleMedium),
                const SizedBox(height: 12),
                AppSectionCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      ListTile(
                        key: const Key('about-toggle'),
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.info_outline),
                        title: Text('关于 Mission Book', style: text.titleMedium),
                        subtitle: Text(
                          capabilities?.version ?? '版本读取中…',
                          key: const Key('app-version'),
                        ),
                        trailing: Icon(
                          _about ? Icons.expand_less : Icons.expand_more,
                        ),
                        onTap: () => setState(() => _about = !_about),
                      ),
                      if (_about)
                        Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: Text(
                            '把目标落到行动，让记录忠于事实。数据保存在当前设备。强行停止或省电限制可能影响后台提醒。',
                            style: text.bodyMedium,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _islandDescription(DeviceCapabilities? capabilities) {
    if (capabilities == null) return '正在查询超级岛能力…';
    if (capabilities.islandSupported == false) {
      return '当前系统未提供小米超级岛能力，使用普通计时通知。';
    }
    if (capabilities.islandSupported == true) {
      if (capabilities.focusPermission == false) {
        return '系统支持超级岛，但本应用尚未获准焦点通知。普通通知权限不能代替应用准入。';
      }
      if (capabilities.focusPermission == true) {
        return '系统支持超级岛且焦点权限已允许。当前版本使用普通计时通知，超级岛展示尚未接入。';
      }
      return '系统支持超级岛，暂时无法确认本应用焦点权限。当前使用普通计时通知。';
    }
    return '当前平台无法确认小米超级岛能力。当前版本使用普通计时通知。';
  }

  /// 只为明确缺少的权限提供授权入口；已允许项在摘要中体现。
  Widget _permission(String title, bool exact) {
    final text = Theme.of(context).textTheme;
    return AppSectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: AppColors.primarySoft,
            child: Icon(
              exact ? Icons.alarm_outlined : Icons.notifications_outlined,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 16),
          Text(title, style: text.titleMedium),
          const SizedBox(height: 4),
          Text('系统未允许', style: text.bodyMedium),
          const SizedBox(height: 12),
          OutlinedButton(
            key: Key(exact ? 'grant-exact-alarms' : 'grant-notifications'),
            onPressed: _openingSettings ? null : () => _settings(exact),
            child: const Text('去设置'),
          ),
        ],
      ),
    );
  }
}

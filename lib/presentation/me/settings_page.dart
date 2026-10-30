import '../widgets/app_dropdown_form_field.dart';
import '../../application/settings/motion_settings.dart';
import '../widgets/motion_settings_scope.dart';
import 'dart:async';

import 'package:flutter/material.dart';

import '../../application/notifications/app_notification_service.dart';
import '../widgets/adaptive_columns.dart';
import '../widgets/adaptive_sheet.dart';
import '../widgets/app_section_card.dart';
import '../widgets/data_export_card.dart';
import '../assistant/assistant_scope.dart';
import '../assistant/assistant_settings_page.dart';

import '../../application/backup/backup_service.dart';
import '../../application/settings/app_device.dart';
import '../../core/theme/app_layout.dart';
import '../../core/theme/colors.dart';
import '../widgets/app_top_bar.dart';
import '../../core/theme/app_motion.dart';

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
  String? _capabilityError;
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
                padding: EdgeInsets.all(AppLayout.spaceLg),
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
    return Scaffold(
      appBar: const AppTopBar(
        title: '设置',
        maxContentWidth: AppLayout.dashboardMaxWidth,
      ),
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
                if (AssistantScope.maybeOf(context) case final scope?) ...[
                  AppSectionCard(
                    padding: EdgeInsets.zero,
                    child: ListTile(
                      key: const Key('settings-assistant-entry'),
                      leading: const Icon(Icons.auto_awesome_outlined),
                      title: const Text('AI 助手设置'),
                      subtitle: const Text('模型、语音、角色与操作权限'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () =>
                          Navigator.of(context, rootNavigator: true).push<void>(
                            MaterialPageRoute(
                              builder: (_) => AssistantSettingsPage(
                                controller: scope.controller,
                              ),
                            ),
                          ),
                    ),
                  ),
                  const SizedBox(height: AppLayout.spaceXxl),
                ],
                if (MotionSettingsScope.maybeOf(context) case final scope?) ...[
                  Text('界面', style: text.titleMedium),
                  const SizedBox(height: AppLayout.spaceMd),
                  AppSectionCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        AppDropdownFormField<MotionPreference>(
                          key: ValueKey(
                            'page-motion-${scope.settings.preference.name}',
                          ),
                          initialValue: scope.settings.preference,
                          decoration: const InputDecoration(
                            labelText: '页面动效',
                            prefixIcon: Icon(Icons.animation_outlined),
                          ),
                          items: const [
                            DropdownMenuItem(
                              value: MotionPreference.system,
                              child: Text('跟随系统'),
                            ),
                            DropdownMenuItem(
                              value: MotionPreference.full,
                              child: Text('开启动效'),
                            ),
                            DropdownMenuItem(
                              value: MotionPreference.reduced,
                              child: Text('减少动效'),
                            ),
                          ],
                          onChanged: scope.settings.saving
                              ? null
                              : (value) {
                                  if (value != null) {
                                    unawaited(scope.settings.select(value));
                                  }
                                },
                        ),
                        const SizedBox(height: AppLayout.spaceSm),
                        Text(
                          scope.settings.preference == MotionPreference.system
                              ? scope.systemReducedMotion
                                    ? '系统当前要求减少动效，日期切换直接完成。'
                                    : '系统当前允许播放页面过渡。'
                              : scope.settings.preference ==
                                    MotionPreference.full
                              ? '播放日期切换等页面过渡，仅对本机生效。'
                              : '跳过页面位移和渐变，仅对本机生效。',
                          style: text.bodySmall,
                        ),
                        if (scope.settings.error case final error?)
                          Text(
                            error,
                            style: text.bodySmall?.copyWith(
                              color: AppColors.error,
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppLayout.spaceXxl),
                ],
                Semantics(
                  container: true,
                  header: true,
                  child: Text('提醒与权限', style: text.titleMedium),
                ),
                if (_capabilities != null) ...[
                  const SizedBox(height: AppLayout.spaceXs),
                  Text(
                    '当前平台：${_platformLabel(_capabilities!.effectivePlatform)}',
                    style: text.bodyMedium,
                  ),
                ],
                const SizedBox(height: AppLayout.spaceMd),
                _buildPermissionSection(context),
                const SizedBox(height: AppLayout.spaceXxl),
                AdaptiveColumns(
                  key: const Key('settings-columns'),
                  minColumnWidth: 360,
                  maxColumns: 2,
                  spacing: 24,
                  children: [
                    _buildScheduleSection(context),
                    _buildBackupSection(context),
                  ],
                ),
                const SizedBox(height: AppLayout.spaceXxl),
                _buildAboutSection(context),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _platformLabel(DevicePlatform platform) => switch (platform) {
    DevicePlatform.android => 'Android',
    DevicePlatform.windows => 'Windows',
    DevicePlatform.ios => 'iOS',
    DevicePlatform.macos => 'macOS',
    DevicePlatform.linux => 'Linux',
    DevicePlatform.web => '浏览器',
    DevicePlatform.other => '其他设备',
  };

  Widget _buildPermissionSection(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final capabilities = _capabilities;
    final platform = capabilities?.effectivePlatform;
    final supported =
        platform == DevicePlatform.android ||
        platform == DevicePlatform.windows;
    final needsNotifications = capabilities?.notifications == false;
    final needsExactAlarms =
        capabilities?.android == true && capabilities?.exactAlarms == false;
    final needsExecutionChannel = capabilities?.executionNotifications == false;
    final unknownPermission =
        capabilities?.notifications == null ||
        (capabilities?.android == true && capabilities?.exactAlarms == null);
    final String title;
    final String description;
    final IconData icon;
    if (_capabilityError != null) {
      title = '暂时无法确认提醒权限';
      description = '请重新读取权限状态。任务仍可手动管理与执行。';
      icon = Icons.info_outline;
    } else if (capabilities == null) {
      title = '正在读取提醒权限';
      description = '正在查询这台设备的系统通知与提醒权限。';
      icon = Icons.notifications_outlined;
    } else if (!supported) {
      title = '当前平台尚未接入系统提醒';
      description = '任务仍可在应用内管理，系统通知与定时提醒暂不可用。';
      icon = Icons.notifications_off_outlined;
    } else if (platform == DevicePlatform.windows) {
      title = 'Windows 通知设置';
      description = '应用无法读取 Windows 通知权限，请在系统设置中检查通知开关。';
      icon = Icons.notifications_outlined;
    } else if (needsNotifications) {
      title = '开启系统通知';
      description = '允许通知后，可在系统通知栏查看任务提醒与执行状态。';
      icon = Icons.notifications_off_outlined;
    } else if (needsExecutionChannel) {
      title = '执行状态通知已关闭';
      description = '请在系统通知设置中开启“执行状态”分类，才能在退出页面后查看计时。';
      icon = Icons.notifications_off_outlined;
    } else if (unknownPermission) {
      title = '部分提醒权限无法查询';
      description = '当前平台无法确认全部提醒权限，可在系统设置中查看。';
      icon = Icons.info_outline;
    } else if (needsExactAlarms) {
      title = '准时提醒权限待开启';
      description = '系统通知已允许；未开启准时提醒权限时，固定任务提醒可能延迟。';
      icon = Icons.alarm_outlined;
    } else {
      title = '提醒权限已就绪';
      description = '权限已允许，实际送达请在系统通知栏确认。';
      icon = Icons.notifications_active_outlined;
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppSectionCard(
          key: const Key('permission-columns'),
          padding: const EdgeInsets.all(AppLayout.spaceLg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _PermissionSummary(
                title: title,
                description: description,
                icon: icon,
              ),
              if (_capabilityError == null && supported) ...[
                if (needsNotifications || needsExecutionChannel) ...[
                  const Divider(height: 24),
                  _permission(needsNotifications ? '系统通知' : '执行状态通知', false),
                ],
                if (needsExactAlarms) ...[
                  const Divider(height: 24),
                  _permission('准时提醒权限', true),
                ],
              ],
            ],
          ),
        ),
        if (_capabilityError != null)
          Padding(
            padding: const EdgeInsets.only(top: AppLayout.spaceSm),
            child: Semantics(
              liveRegion: true,
              child: Text(
                _capabilityError!,
                style: text.bodyMedium?.copyWith(color: AppColors.error),
              ),
            ),
          ),
        if (capabilities == null ||
            (platform == DevicePlatform.android && unknownPermission) ||
            _capabilityError != null)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              key: const Key('refresh-permissions'),
              onPressed: _querying ? null : _refresh,
              child: Text(_querying ? '正在读取权限…' : '重新读取权限'),
            ),
          ),
        if (platform == DevicePlatform.windows) ...[
          const SizedBox(height: AppLayout.spaceSm),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              key: const Key('windows-notification-settings'),
              onPressed: _openingSettings ? null : () => _settings(false),
              icon: const Icon(Icons.open_in_new),
              label: const Text('打开 Windows 通知设置'),
            ),
          ),
        ],
        if (platform == DevicePlatform.android ||
            platform == DevicePlatform.windows) ...[
          const SizedBox(height: AppLayout.spaceMd),
          AppSectionCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  platform == DevicePlatform.android ? '执行计时通知' : '执行状态通知',
                  style: text.titleMedium,
                ),
                const SizedBox(height: AppLayout.spaceSm),
                Text(
                  platform == DevicePlatform.android
                      ? '执行时使用系统通知显示计时与操作，实际显示取决于系统权限。'
                      : '执行状态通过 Windows 通知呈现，系统通知不提供持续计时显示。',
                  style: text.bodyMedium,
                ),
                if (platform == DevicePlatform.android &&
                    capabilities?.islandSupported == true) ...[
                  const SizedBox(height: AppLayout.spaceSm),
                  Text(
                    _islandDescription(capabilities),
                    key: const Key('island-capability-status'),
                    style: text.bodyMedium,
                  ),
                ],
                if (widget.notifications != null)
                  TextButton.icon(
                    key: const Key('notification-refresh'),
                    onPressed: _querying || _refreshingNotifications
                        ? null
                        : _refreshNotifications,
                    icon: const Icon(Icons.refresh),
                    label: const Text('刷新执行通知'),
                  ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildScheduleSection(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final service = widget.notifications;
    final platform = _capabilities?.effectivePlatform;
    final canSchedule =
        service?.supportsScheduling == true &&
        (platform == DevicePlatform.android ||
            platform == DevicePlatform.windows);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          container: true,
          header: true,
          child: Text('计划任务', style: text.titleMedium),
        ),
        const SizedBox(height: AppLayout.spaceMd),
        AppSectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (canSchedule)
                StreamBuilder<void>(
                  stream: service!.settingsChanges,
                  builder: (context, _) => ListTile(
                    key: const Key('planned-reminder-setting'),
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.alarm_outlined),
                    title: Text(
                      _reminderLabel(service.reminderLeadMinutes),
                      style: text.titleMedium,
                    ),
                    subtitle: const Text('应用于所有尚未开始的固定任务'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: _savingScheduleSettings ? null : _chooseReminder,
                  ),
                ),
              if (!canSchedule)
                Text(
                  service == null &&
                          (platform == null ||
                              platform == DevicePlatform.android ||
                              platform == DevicePlatform.windows)
                      ? '提醒服务尚未就绪，请稍后重试。'
                      : '当前平台尚未接入系统定时提醒，无法配置提前提醒。',
                  style: text.bodyMedium,
                ),
              const SizedBox(height: AppLayout.spaceSm),
              Text(
                platform == DevicePlatform.android
                    ? '到点自动开始；系统可安排后台唤醒，受系统权限和省电影响。已有任务执行时保留当前计时。'
                    : '应用运行时会处理到点任务；应用关闭期间不会自动开始，重新打开时再检查。',
                style: text.bodyMedium,
              ),
              if (canSchedule)
                Text(
                  platform == DevicePlatform.windows
                      ? 'Windows 当前版本无法撤销已安排的系统提醒；调整或取消任务后，旧提醒仍可能出现。'
                      : '系统同时安排最近 64 个固定任务的提醒；后续提醒随计划推进更新。',
                  style: text.bodySmall,
                ),
              if (_scheduleSettingsError != null)
                Semantics(
                  liveRegion: true,
                  child: Text(
                    _scheduleSettingsError!,
                    style: text.bodyMedium?.copyWith(color: AppColors.error),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBackupSection(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          container: true,
          header: true,
          child: Text('数据', style: text.titleMedium),
        ),
        const SizedBox(height: AppLayout.spaceMd),
        DataExportCard(backup: widget.backup, device: widget.device),
      ],
    );
  }

  Widget _buildAboutSection(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final content = _about
        ? Padding(
            padding: const EdgeInsets.only(top: AppLayout.spaceMd),
            child: Text(
              '把目标落到行动，让记录忠于事实。数据保存在当前设备。强行停止或省电限制可能影响后台提醒。',
              style: text.bodyMedium,
            ),
          )
        : const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          container: true,
          header: true,
          child: Text('关于', style: text.titleMedium),
        ),
        const SizedBox(height: AppLayout.spaceMd),
        AppSectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Semantics(
                expanded: _about,
                child: ListTile(
                  key: const Key('about-toggle'),
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.info_outline),
                  title: Text('关于 Mission Book', style: text.titleMedium),
                  subtitle: Text(
                    _capabilities?.version ?? '版本读取中…',
                    key: const Key('app-version'),
                  ),
                  trailing: Icon(
                    _about ? Icons.expand_less : Icons.expand_more,
                  ),
                  onTap: () => setState(() => _about = !_about),
                ),
              ),
              if (MediaQuery.disableAnimationsOf(context))
                content
              else
                AnimatedSize(
                  duration: AppMotion.quick,
                  alignment: Alignment.topCenter,
                  child: content,
                ),
            ],
          ),
        ),
      ],
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
    final action = TextButton(
      key: Key(exact ? 'grant-exact-alarms' : 'grant-notifications'),
      onPressed: _openingSettings ? null : () => _settings(exact),
      child: const Text('去设置'),
    );
    return LayoutBuilder(
      builder: (context, box) {
        final compact =
            box.maxWidth <
            300 * MediaQuery.textScalerOf(context).scale(14) / 14;
        final label = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: text.titleSmall),
            const SizedBox(height: AppLayout.spaceXs),
            Text('系统未允许', style: text.bodySmall),
          ],
        );
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: AppLayout.spaceSm),
              child: Icon(
                exact ? Icons.alarm_outlined : Icons.notifications_outlined,
                size: AppLayout.iconLg,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(width: AppLayout.spaceMd),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [label, if (compact) action],
              ),
            ),
            if (!compact) action,
          ],
        );
      },
    );
  }
}

/// 权限卡片只描述查询结果；系统授权及刷新仍由页面处理。
class _PermissionSummary extends StatelessWidget {
  const _PermissionSummary({
    required this.title,
    required this.description,
    required this.icon,
  });
  final String title;
  final String description;
  final IconData icon;
  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: AppLayout.iconLg, color: AppColors.primary),
        const SizedBox(width: AppLayout.spaceMd),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: text.titleSmall),
              const SizedBox(height: AppLayout.spaceXs),
              Text(description, style: text.bodyMedium),
            ],
          ),
        ),
      ],
    );
  }
}

import '../../application/settings/motion_settings.dart';
import '../widgets/motion_settings_scope.dart';
import 'dart:async';

import 'package:flutter/material.dart';

import '../../application/notifications/app_notification_service.dart';
import '../widgets/adaptive_sheet.dart';
import '../widgets/app_section_card.dart';
import '../widgets/app_settings_row.dart';
import '../widgets/data_export_card.dart';
import '../assistant/assistant_scope.dart';
import '../assistant/assistant_settings_page.dart';

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
                if (AssistantScope.maybeOf(context) case final scope?)
                  _section(
                    '助手',
                    child: AppSettingsRow(
                      key: const Key('settings-assistant-entry'),
                      icon: Icons.auto_awesome_outlined,
                      title: 'AI 助手设置',
                      subtitle: '模型、语音与操作权限',
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
                if (MotionSettingsScope.maybeOf(context) case final scope?)
                  _motionSection(scope),
                _buildPermissionSection(context),
                _buildScheduleSection(context),
                _buildBackupSection(context),
                _buildAboutSection(context),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 设置分区使用更轻的标签，避免标题与行内容争层级。
  Widget _sectionHeader(String title) => Semantics(
    container: true,
    header: true,
    child: Text(
      title,
      style: Theme.of(context).textTheme.titleSmall?.copyWith(
        color: AppColors.textSecondary,
        fontWeight: FontWeight.w600,
      ),
    ),
  );

  /// 统一分区节奏：标签 → 8 → 卡片 → 20；行内容由卡片自己的行组件控制。
  Widget _section(String title, {required Widget child, bool card = true}) =>
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _sectionHeader(title),
          const SizedBox(height: AppLayout.spaceSm),
          if (card)
            AppSectionCard(padding: EdgeInsets.zero, child: child)
          else
            child,
          const SizedBox(height: AppLayout.spaceXl),
        ],
      );

  static const _rowDivider = Divider(
    height: 1,
    indent: AppLayout.spaceLg,
    endIndent: AppLayout.spaceLg,
  );

  Widget _motionSection(MotionSettingsScope scope) {
    final settings = scope.settings;
    final note = switch (settings.preference) {
      MotionPreference.system =>
        scope.systemReducedMotion ? '系统要求减少动效' : '系统允许页面过渡',
      MotionPreference.full => '仅对本机开启动效',
      MotionPreference.reduced => '仅对本机减少动效',
    };
    return _section(
      '界面',
      child: Column(
        children: [
          AppSettingsRow(
            key: ValueKey('page-motion-${settings.preference.name}'),
            icon: Icons.animation_outlined,
            title: '页面动效',
            subtitle: note,
            enabled: !settings.saving,
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _motionLabel(settings.preference),
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(width: AppLayout.spaceXs),
                const Icon(
                  Icons.chevron_right,
                  size: AppLayout.iconMd,
                  color: AppColors.textSecondary,
                ),
              ],
            ),
            onTap: settings.saving ? null : () => _chooseMotion(scope),
          ),
          if (settings.error case final error?) ...[
            _rowDivider,
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppLayout.spaceLg,
                AppLayout.spaceSm,
                AppLayout.spaceLg,
                AppLayout.spaceMd,
              ),
              child: Text(
                error,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: AppColors.error),
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _motionLabel(MotionPreference preference) => switch (preference) {
    MotionPreference.system => '跟随系统',
    MotionPreference.full => '开启动效',
    MotionPreference.reduced => '减少动效',
  };

  Future<void> _chooseMotion(MotionSettingsScope scope) async {
    final current = scope.settings.preference;
    final choice = await showAdaptiveSheet<MotionPreference>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(AppLayout.spaceLg),
                child: Text(
                  '页面动效',
                  style: Theme.of(sheetContext).textTheme.titleMedium,
                ),
              ),
              for (final preference in MotionPreference.values)
                ListTile(
                  key: Key('motion-option-${preference.name}'),
                  title: Text(_motionLabel(preference)),
                  selected: preference == current,
                  trailing: preference == current
                      ? const Icon(Icons.check)
                      : null,
                  onTap: () => Navigator.pop(sheetContext, preference),
                ),
              const SizedBox(height: AppLayout.spaceSm),
            ],
          ),
        ),
      ),
    );
    if (choice != null && choice != current) {
      await scope.settings.select(choice);
    }
  }

  Widget _buildPermissionSection(BuildContext context) {
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
      description = '请重新读取权限状态。';
      icon = Icons.info_outline;
    } else if (capabilities == null) {
      title = '正在读取提醒权限';
      description = '正在查询系统权限。';
      icon = Icons.notifications_outlined;
    } else if (!supported) {
      title = '当前平台尚未接入系统提醒';
      description = '任务仍可在应用内管理。';
      icon = Icons.notifications_off_outlined;
    } else if (platform == DevicePlatform.windows) {
      title = 'Windows 通知设置';
      description = '应用无法读取权限，请在系统中检查。';
      icon = Icons.notifications_outlined;
    } else if (needsNotifications) {
      title = '开启系统通知';
      description = '允许后才能收到任务提醒。';
      icon = Icons.notifications_off_outlined;
    } else if (needsExecutionChannel) {
      title = '执行状态通知已关闭';
      description = '请在系统通知设置中开启执行状态分类。';
      icon = Icons.notifications_off_outlined;
    } else if (unknownPermission) {
      title = '部分提醒权限无法查询';
      description = '可在系统设置中查看。';
      icon = Icons.info_outline;
    } else if (needsExactAlarms) {
      title = '准时提醒权限待开启';
      description = '未开启时固定任务提醒可能延迟。';
      icon = Icons.alarm_outlined;
    } else {
      title = '提醒权限已就绪';
      description = '实际送达请在系统通知栏确认。';
      icon = Icons.notifications_active_outlined;
    }

    final canRefresh =
        _capabilityError != null ||
        (capabilities != null &&
            platform == DevicePlatform.android &&
            unknownPermission);
    final Widget? summaryTrailing = platform == DevicePlatform.windows
        ? TextButton(
            key: const Key('windows-notification-settings'),
            onPressed: _openingSettings ? null : () => _settings(false),
            child: const Text('打开设置'),
          )
        : canRefresh
        ? TextButton(
            key: const Key('refresh-permissions'),
            onPressed: _querying ? null : _refresh,
            child: Text(_querying ? '读取中…' : '重新读取'),
          )
        : null;

    final rows = <Widget>[
      AppSettingsRow(
        icon: icon,
        title: title,
        subtitle: description,
        trailing: summaryTrailing,
      ),
    ];
    if (_capabilityError == null && supported) {
      if (needsNotifications || needsExecutionChannel) {
        rows.add(_rowDivider);
        rows.add(
          AppSettingsRow(
            icon: needsNotifications
                ? Icons.notifications_outlined
                : Icons.timer_outlined,
            title: needsNotifications ? '系统通知' : '执行状态通知',
            subtitle: '系统未允许',
            trailing: TextButton(
              key: const Key('grant-notifications'),
              onPressed: _openingSettings ? null : () => _settings(false),
              child: const Text('去设置'),
            ),
          ),
        );
      }
      if (needsExactAlarms) {
        rows.add(_rowDivider);
        rows.add(
          AppSettingsRow(
            icon: Icons.alarm_outlined,
            title: '准时提醒权限',
            subtitle: '系统未允许',
            trailing: TextButton(
              key: const Key('grant-exact-alarms'),
              onPressed: _openingSettings ? null : () => _settings(true),
              child: const Text('去设置'),
            ),
          ),
        );
      }
    }
    if (platform == DevicePlatform.android ||
        platform == DevicePlatform.windows) {
      rows.add(_rowDivider);
      rows.add(
        AppSettingsRow(
          icon: Icons.notifications_active_outlined,
          title: platform == DevicePlatform.android ? '执行计时通知' : '执行状态通知',
          subtitle: platform == DevicePlatform.android
              ? '显示计时与快捷操作'
              : '通过 Windows 通知呈现',
          trailing: widget.notifications == null
              ? null
              : TextButton(
                  key: const Key('notification-refresh'),
                  onPressed: _querying || _refreshingNotifications
                      ? null
                      : _refreshNotifications,
                  child: const Text('刷新'),
                ),
        ),
      );
      if (platform == DevicePlatform.android &&
          capabilities?.islandSupported == true) {
        rows.add(
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppLayout.spaceLg + AppLayout.iconMd + AppLayout.spaceMd,
              0,
              AppLayout.spaceLg,
              AppLayout.spaceMd,
            ),
            child: Text(
              _islandDescription(capabilities),
              key: const Key('island-capability-status'),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        );
      }
    }
    return _section('提醒与权限', child: Column(children: rows));
  }

  Widget _buildScheduleSection(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final service = widget.notifications;
    final platform = _capabilities?.effectivePlatform;
    final canSchedule =
        service?.supportsScheduling == true &&
        (platform == DevicePlatform.android ||
            platform == DevicePlatform.windows);

    Widget row() => canSchedule
        ? AppSettingsRow(
            key: const Key('planned-reminder-setting'),
            icon: Icons.alarm_outlined,
            title: _reminderLabel(service!.reminderLeadMinutes),
            subtitle: '仅对尚未开始的固定任务生效',
            onTap: _savingScheduleSettings ? null : _chooseReminder,
          )
        : AppSettingsRow(
            icon: Icons.alarm_outlined,
            title: '提前提醒',
            subtitle:
                service == null &&
                    (platform == null ||
                        platform == DevicePlatform.android ||
                        platform == DevicePlatform.windows)
                ? '提醒服务尚未就绪，请稍后重试'
                : '当前平台无法配置提前提醒',
            enabled: false,
          );
    final caption = platform == DevicePlatform.windows
        ? canSchedule
              ? '应用关闭期间不会自动开始；无法撤销已安排的系统提醒。'
              : '应用关闭期间不会自动开始。'
        : canSchedule && platform == DevicePlatform.android
        ? '到点自动开始；受系统权限和省电限制。'
        : null;
    return _section(
      '计划任务',
      child: Column(
        children: [
          if (canSchedule)
            StreamBuilder<void>(
              stream: service!.settingsChanges,
              builder: (context, _) => row(),
            )
          else
            row(),
          if (caption != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppLayout.spaceLg,
                AppLayout.spaceXs,
                AppLayout.spaceLg,
                AppLayout.spaceMd,
              ),
              child: Text(caption, style: text.bodySmall),
            ),
          if (_scheduleSettingsError != null)
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
                  _scheduleSettingsError!,
                  style: text.bodyMedium?.copyWith(color: AppColors.error),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildBackupSection(BuildContext context) => _section(
    '数据',
    card: false,
    child: DataExportCard(backup: widget.backup, device: widget.device),
  );

  Widget _buildAboutSection(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return _section(
      '关于',
      child: Column(
        children: [
          Semantics(
            expanded: _about,
            child: AppSettingsRow(
              key: const Key('about-toggle'),
              icon: Icons.info_outline,
              title: '关于 Mission Book',
              subtitle: _capabilities?.version ?? '版本读取中…',
              trailing: Icon(
                _about ? Icons.expand_less : Icons.expand_more,
                size: AppLayout.iconMd,
                color: AppColors.textSecondary,
              ),
              onTap: () => setState(() => _about = !_about),
            ),
          ),
          if (_about)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppLayout.spaceLg,
                0,
                AppLayout.spaceLg,
                AppLayout.spaceLg,
              ),
              child: Text('把目标落到行动，让记录忠于事实。数据保存在当前设备。', style: text.bodyMedium),
            ),
        ],
      ),
    );
  }

  String _islandDescription(DeviceCapabilities? capabilities) {
    if (capabilities == null) return '正在查询超级岛能力…';
    if (capabilities.islandSupported == false) {
      return '当前系统未提供小米超级岛，使用普通通知。';
    }
    if (capabilities.islandSupported == true) {
      if (capabilities.focusPermission == false) {
        return '系统支持超级岛，但本应用尚未获准焦点通知。';
      }
      if (capabilities.focusPermission == true) {
        return '系统支持超级岛，当前版本仍使用普通通知。';
      }
      return '系统支持超级岛，焦点权限暂时未知。';
    }
    return '当前平台无法确认小米超级岛能力。';
  }
}

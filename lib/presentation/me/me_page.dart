import 'dart:async';

import 'package:flutter/material.dart';

import '../../application/backup/backup_service.dart';
import '../../application/goals/goal_service.dart';
import '../../application/missions/mission_service.dart';
import '../../application/notifications/app_notification_service.dart';
import '../../application/settings/app_device.dart';
import '../../core/theme/app_layout.dart';
import '../../core/theme/colors.dart';
import '../../domain/entities/execution_event.dart';
import '../../domain/entities/goal.dart';
import '../../domain/rules/execution_time_rules.dart';
import '../widgets/adaptive_columns.dart';
import '../widgets/app_confirm_dialog.dart';
import '../widgets/app_page_header.dart';
import '../widgets/app_section_card.dart';
import '../widgets/app_text_field.dart';
import '../widgets/detail_pane.dart';
import 'settings_page.dart';

/// 个人页读取本机资料与真实记录；权限、提醒和备份集中到右上角设置。
class MePage extends StatefulWidget {
  const MePage({
    super.key,
    required this.device,
    required this.backup,
    required this.missions,
    required this.goals,
    this.notifications,
  });
  final AppDevice device;
  final BackupExporter backup;
  final MissionService missions;
  final GoalService goals;
  final AppNotificationService? notifications;

  @override
  State<MePage> createState() => _MePageState();
}

class _MePageState extends State<MePage> with WidgetsBindingObserver {
  LocalProfile? _profile;
  String? _profileError;
  String? _statsError;
  ({int goals, int ended, int minutes})? _stats;
  StreamSubscription<void>? _missionChanges;
  StreamSubscription<void>? _goalChanges;
  int _statsGeneration = 0;
  bool _editing = false;
  bool _openingSettings = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _missionChanges = widget.missions.changes.listen((_) => _refreshStats());
    _goalChanges = widget.goals.changes.listen((_) => _refreshStats());
    unawaited(_loadProfile());
    unawaited(_refreshStats());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(_refreshStats());
  }

  Future<void> _loadProfile() async {
    try {
      final profile = await widget.device.readProfile();
      if (mounted) {
        setState(() {
          _profile = profile;
          _profileError = null;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _profileError = '本机资料暂时无法读取，请重试');
    }
  }

  Future<void> _refreshStats() async {
    final generation = ++_statsGeneration;
    try {
      // 两种查询都只读取既有服务；数字不作为新的可写统计状态保存。
      final goals = await widget.goals.findAll();
      final missions = await widget.missions.findFinished();
      var focus = Duration.zero;
      var ended = 0;
      for (final mission in missions) {
        if (mission.events.isNotEmpty &&
            mission.events.last.type == ExecutionEventType.end) {
          ended++;
          focus += calculateExecutionTimes(
            mission.events,
            mission.events.last.occurredAt,
          ).focus;
        }
      }
      if (!mounted || generation != _statsGeneration) return;
      setState(() {
        _stats = (
          goals: goals.where((goal) => goal.status == GoalStatus.active).length,
          ended: ended,
          minutes: focus.inMinutes,
        );
        _statsError = null;
      });
    } catch (_) {
      if (mounted && generation == _statsGeneration) {
        setState(() => _statsError = '记录暂时无法读取，请重试');
      }
    }
  }

  Future<void> _editProfile() async {
    if (_profile == null || _editing) return;
    _editing = true;
    try {
      final saved = await showDialog<LocalProfile>(
        context: context,
        barrierDismissible: false,
        builder: (_) =>
            _ProfileEditor(profile: _profile!, device: widget.device),
      );
      if (saved != null && mounted) setState(() => _profile = saved);
    } finally {
      _editing = false;
    }
  }

  Future<void> _settings() async {
    if (_openingSettings) return;
    _openingSettings = true;
    try {
      await openDetailPane<void>(
        context,
        label: '设置',
        builder: (_) => SettingsPage(
          device: widget.device,
          backup: widget.backup,
          notifications: widget.notifications,
        ),
      );
    } finally {
      _openingSettings = false;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_missionChanges?.cancel());
    unawaited(_goalChanges?.cancel());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: AppLayout.dashboardMaxWidth,
          ),
          child: ListView(
            padding: AppLayout.pagePadding(context),
            children: [
              AppPageHeader(
                title: '我的',
                subtitle: Text('记录自己的每一次行动', style: text.bodyMedium),
                action: IconButton.filledTonal(
                  key: const Key('me-settings'),
                  tooltip: '设置',
                  onPressed: _settings,
                  icon: const Icon(Icons.settings_outlined),
                ),
              ),
              const SizedBox(height: 16),
              AppSectionCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: CircleAvatar(
                        radius: 32,
                        backgroundColor: AppColors.primarySoft,
                        child: Icon(Icons.person_outline_rounded, size: 32),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      _profile?.name ??
                          (_profileError == null ? '正在读取资料…' : '本机资料'),
                      key: const Key('profile-name'),
                      style: text.headlineSmall,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _profile?.bio.isNotEmpty == true
                          ? _profile!.bio
                          : '把在意的事，一次次落到行动。',
                      style: text.bodyMedium,
                    ),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 12,
                      runSpacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        const Chip(
                          avatar: Icon(Icons.phone_android_outlined, size: 18),
                          label: Text('本机资料'),
                        ),
                        TextButton.icon(
                          key: const Key('profile-edit'),
                          onPressed: _profile == null ? null : _editProfile,
                          icon: const Icon(Icons.edit_outlined, size: 18),
                          label: const Text('编辑资料'),
                        ),
                      ],
                    ),
                    if (_profileError != null) ...[
                      Text(
                        _profileError!,
                        style: const TextStyle(color: AppColors.error),
                      ),
                      TextButton(
                        onPressed: _loadProfile,
                        child: const Text('重新读取资料'),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Text('我的行动记录', style: text.titleMedium),
              const SizedBox(height: 12),
              AdaptiveColumns(
                minColumnWidth: 180,
                maxColumns: 3,
                children: [
                  _stat(
                    context,
                    Icons.flag_outlined,
                    '进行中目标',
                    _stats?.goals,
                    '个',
                  ),
                  _stat(
                    context,
                    Icons.task_alt_outlined,
                    '已结束任务',
                    _stats?.ended,
                    '项',
                  ),
                  _stat(
                    context,
                    Icons.timelapse_outlined,
                    '累计专注',
                    _stats?.minutes,
                    '分钟',
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text('累计专注仅统计已结束任务。资料与记录保存在本机。', style: text.bodySmall),
              if (_statsError != null) ...[
                Text(
                  _statsError!,
                  style: const TextStyle(color: AppColors.error),
                ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton(
                    onPressed: _refreshStats,
                    child: const Text('重新读取记录'),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _stat(
    BuildContext context,
    IconData icon,
    String label,
    int? value,
    String unit,
  ) => AppSectionCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon),
        const SizedBox(height: 16),
        Text(label, style: Theme.of(context).textTheme.bodyMedium),
        const SizedBox(height: 8),
        Text(
          value == null ? '—' : '$value $unit',
          key: ValueKey('profile-stat-$label'),
          style: Theme.of(context).textTheme.titleLarge,
        ),
      ],
    ),
  );
}

class _ProfileEditor extends StatefulWidget {
  const _ProfileEditor({required this.profile, required this.device});
  final LocalProfile profile;
  final AppDevice device;
  @override
  State<_ProfileEditor> createState() => _ProfileEditorState();
}

class _ProfileEditorState extends State<_ProfileEditor> {
  late final _name = TextEditingController(text: widget.profile.name);
  late final _bio = TextEditingController(text: widget.profile.bio);
  bool _saving = false;
  bool _leaving = false;
  String? _error;
  bool get _dirty =>
      _name.text != widget.profile.name || _bio.text != widget.profile.bio;

  Future<void> _cancel() async {
    if (_saving || _leaving) return;
    _leaving = true;
    try {
      final leave =
          !_dirty ||
          await AppConfirmDialog.show(
            context: context,
            title: '放弃资料修改？',
            message: '尚未保存的称呼和简介将被丢弃。',
            cancelText: '继续编辑',
            confirmText: '放弃修改',
          );
      if (mounted && leave) Navigator.of(context).pop();
    } finally {
      _leaving = false;
    }
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final profile = LocalProfile(name: _name.text, bio: _bio.text).cleaned();
      await widget.device.saveProfile(profile);
      if (mounted) Navigator.of(context).pop(profile);
    } on ArgumentError catch (_) {
      if (mounted) setState(() => _error = '请填写称呼');
    } catch (_) {
      if (mounted) setState(() => _error = '资料保存失败，输入已保留，请重试');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _bio.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PopScope<LocalProfile>(
    canPop: false,
    onPopInvokedWithResult: (didPop, _) {
      if (!didPop) unawaited(_cancel());
    },
    child: Dialog(
      constraints: const BoxConstraints(maxWidth: 480),
      backgroundColor: AppColors.card,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('编辑本机资料', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 24),
            AppTextField(
              key: const Key('profile-name-input'),
              label: '称呼',
              hint: '你希望如何称呼自己',
              controller: _name,
              maxLines: 1,
              readOnly: _saving,
            ),
            const SizedBox(height: 20),
            AppTextField(
              key: const Key('profile-bio-input'),
              label: '个人简介',
              hint: '写一句想对自己说的话（选填）',
              controller: _bio,
              minLines: 2,
              maxLines: 4,
              readOnly: _saving,
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Semantics(
                  liveRegion: true,
                  child: Text(
                    _error!,
                    style: const TextStyle(color: AppColors.error),
                  ),
                ),
              ),
            const SizedBox(height: 24),
            Wrap(
              alignment: WrapAlignment.end,
              spacing: 12,
              runSpacing: 8,
              children: [
                TextButton(
                  onPressed: _saving ? null : _cancel,
                  child: const Text('取消'),
                ),
                FilledButton(
                  key: const Key('profile-save'),
                  onPressed: _saving ? null : _save,
                  child: Text(_saving ? '正在保存…' : '保存资料'),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

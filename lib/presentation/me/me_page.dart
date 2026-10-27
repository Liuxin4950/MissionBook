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
import '../widgets/app_illustration.dart';
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
  Widget build(BuildContext context) => SafeArea(
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
              action: IconButton.filledTonal(
                key: const Key('me-settings'),
                tooltip: '设置',
                onPressed: _settings,
                icon: const Icon(Icons.settings_outlined),
              ),
            ),
            const SizedBox(height: 24),
            AdaptiveColumns(
              key: const Key('me-workspace-columns'),
              minColumnWidth: 400,
              maxColumns: 2,
              spacing: 24,
              children: [
                _ProfileCard(
                  profile: _profile,
                  error: _profileError,
                  onEdit: _profile == null ? null : _editProfile,
                  onRetry: _loadProfile,
                ),
                _ActivityOverview(
                  stats: _statsError == null ? _stats : null,
                  error: _statsError,
                  onRetry: _refreshStats,
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

/// 只展示资料与操作；资料读写和草稿生命周期仍由页面持有。
class _ProfileCard extends StatelessWidget {
  const _ProfileCard({
    required this.profile,
    required this.error,
    required this.onEdit,
    required this.onRetry,
  });
  final LocalProfile? profile;
  final String? error;
  final VoidCallback? onEdit;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return AppSectionCard(
      key: const Key('profile-card'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const AppIllustration(
            asset: 'assets/illustrations/profile-notebook.png',
            width: 156,
            height: 106,
          ),
          const SizedBox(height: 20),
          Text(
            profile?.name ?? (error == null ? '正在读取资料…' : '本机资料'),
            key: const Key('profile-name'),
            style: text.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(
            profile?.bio.isNotEmpty == true ? profile!.bio : '把在意的事，一次次落到行动。',
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
                onPressed: onEdit,
                icon: const Icon(Icons.edit_outlined, size: 18),
                label: const Text('编辑资料'),
              ),
            ],
          ),
          if (error != null) ...[
            Semantics(
              liveRegion: true,
              child: Text(
                error!,
                style: text.bodyMedium?.copyWith(color: AppColors.error),
              ),
            ),
            TextButton(onPressed: onRetry, child: const Text('重新读取资料')),
          ],
        ],
      ),
    );
  }
}

/// 数字只接收页面查询出的事实，空态不能将读取失败当作零。
class _ActivityOverview extends StatelessWidget {
  const _ActivityOverview({
    required this.stats,
    required this.error,
    required this.onRetry,
  });
  final ({int goals, int ended, int minutes})? stats;
  final String? error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final isEmpty =
        error == null &&
        stats != null &&
        stats!.goals == 0 &&
        stats!.ended == 0;
    return AppSectionCard(
      key: const Key('activity-overview'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            container: true,
            header: true,
            child: Text('我的行动记录', style: text.titleMedium),
          ),
          const SizedBox(height: 16),
          if (isEmpty) ...[
            const Center(
              child: AppIllustration(
                asset: 'assets/illustrations/history-pages.png',
                width: 160,
                height: 110,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '行动会在这里留下记录',
              textAlign: TextAlign.center,
              style: text.bodyMedium,
            ),
            const SizedBox(height: 16),
          ],
          AdaptiveColumns(
            minColumnWidth: 120,
            maxColumns: 3,
            spacing: 12,
            children: [
              _ActivityStat(
                asset: 'assets/illustrations/goal-path.png',
                label: '进行中目标',
                value: stats?.goals,
                unit: '个',
              ),
              _ActivityStat(
                asset: 'assets/illustrations/history-pages.png',
                label: '已结束任务',
                value: stats?.ended,
                unit: '项',
              ),
              _ActivityStat(
                asset: 'assets/illustrations/focus-hourglass.png',
                label: '累计专注',
                value: stats?.minutes,
                unit: '分钟',
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text('累计专注仅统计已结束任务。', style: text.bodyMedium),
          if (error != null) ...[
            Semantics(
              liveRegion: true,
              child: Text(
                error!,
                style: text.bodyMedium?.copyWith(color: AppColors.error),
              ),
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: onRetry,
                child: const Text('重新读取记录'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ActivityStat extends StatelessWidget {
  const _ActivityStat({
    required this.asset,
    required this.label,
    required this.value,
    required this.unit,
  });
  final String asset;
  final String label;
  final int? value;
  final String unit;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Image.asset(
            asset,
            width: 80,
            height: 60,
            cacheWidth: 240,
            fit: BoxFit.contain,
            excludeFromSemantics: true,
          ),
          const SizedBox(height: 12),
          Text(label, style: text.bodyMedium),
          const SizedBox(height: 4),
          Text(
            value == null ? '—' : '$value $unit',
            key: ValueKey('profile-stat-$label'),
            style: text.titleLarge,
          ),
        ],
      ),
    );
  }
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

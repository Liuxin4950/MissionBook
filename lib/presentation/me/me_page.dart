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
import '../../domain/entities/mission_detail.dart';
import '../../domain/rules/execution_time_rules.dart';
import '../goals/detail/goal_detail_page.dart';
import '../missions/record/mission_record_page.dart';
import '../widgets/adaptive_columns.dart';
import '../widgets/app_confirm_dialog.dart';
import '../widgets/app_journey_hero.dart';
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
  List<Goal> _activeGoals = const [];
  List<MissionDetail> _recentRecords = const [];
  StreamSubscription<void>? _missionChanges;
  StreamSubscription<void>? _goalChanges;
  int _statsGeneration = 0;
  bool _editing = false;
  bool _openingStandalonePage = false;

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
      final activeGoals = goals
          .where((goal) => goal.status == GoalStatus.active)
          .toList();
      setState(() {
        _activeGoals = activeGoals.take(3).toList();
        _recentRecords = missions
            .where(
              (mission) =>
                  mission.events.isNotEmpty &&
                  mission.events.last.type == ExecutionEventType.end,
            )
            .take(2)
            .toList();
        _stats = (
          goals: activeGoals.length,
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

  /// 右栏控制器负责切换时的防重入和草稿守卫；独立页面才锁到返回。
  Future<void> _openPage({
    required String label,
    required WidgetBuilder builder,
  }) async {
    final standalone = DetailPaneScope.maybeOf(context) == null;
    if (standalone && _openingStandalonePage) return;
    if (standalone) _openingStandalonePage = true;
    try {
      await openDetailPane<void>(context, label: label, builder: builder);
    } finally {
      // 上面的 await 等待页面关闭，不能用它锁住仍可操作的左栏入口。
      if (standalone) _openingStandalonePage = false;
      if (mounted) unawaited(_refreshStats());
    }
  }

  Future<void> _settings() => _openPage(
    label: '设置',
    builder: (_) => SettingsPage(
      device: widget.device,
      backup: widget.backup,
      notifications: widget.notifications,
    ),
  );

  Future<void> _openGoal(Goal goal) => _openPage(
    label: '目标详情',
    builder: (_) => GoalDetailPage(
      service: widget.goals,
      goalId: goal.id,
      missionService: widget.missions,
    ),
  );

  Future<void> _openRecord(MissionDetail detail) => _openPage(
    label: '执行记录',
    builder: (_) => MissionRecordPage(detail: detail, service: widget.missions),
  );

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
              subtitle: Text(
                '个人资料与行动概览',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              action: IconButton.filledTonal(
                key: const Key('me-settings'),
                tooltip: '设置',
                onPressed: _settings,
                icon: const Icon(Icons.settings_outlined),
              ),
            ),
            const SizedBox(height: AppLayout.spaceXxl),
            AdaptiveColumns(
              key: const Key('me-workspace-columns'),
              minColumnWidth: 400,
              maxColumns: 2,
              spacing: AppLayout.spaceXxl,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _ProfileCard(
                      profile: _profile,
                      error: _profileError,
                      onEdit: _profile == null ? null : _editProfile,
                      onRetry: _loadProfile,
                    ),
                    if (_statsError == null && _recentRecords.isNotEmpty) ...[
                      const SizedBox(height: AppLayout.spaceXxl),
                      _RecentRecords(
                        records: _recentRecords,
                        onOpen: _openRecord,
                      ),
                    ],
                  ],
                ),
                _ActivityOverview(
                  stats: _statsError == null ? _stats : null,
                  goals: _statsError == null ? _activeGoals : const [],
                  onOpenGoal: _openGoal,
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
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Image.asset(
            journeyArtwork,
            height: 132,
            width: double.infinity,
            fit: BoxFit.cover,
            alignment: Alignment.centerRight,
            cacheWidth: 1280,
            excludeFromSemantics: true,
          ),
          Padding(
            padding: const EdgeInsets.all(AppLayout.spaceXl),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const CircleAvatar(
                      backgroundColor: AppColors.primarySoft,
                      child: Icon(
                        Icons.person_outline,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(width: AppLayout.spaceMd),
                    Expanded(
                      child: Text(
                        profile?.name ?? (error == null ? '正在读取资料…' : '本机资料'),
                        key: const Key('profile-name'),
                        style: text.titleMedium,
                      ),
                    ),
                    IconButton(
                      key: const Key('profile-edit'),
                      tooltip: '编辑资料',
                      onPressed: onEdit,
                      icon: const Icon(
                        Icons.edit_outlined,
                        size: AppLayout.iconMd,
                      ),
                    ),
                  ],
                ),
                if (profile?.bio.isNotEmpty == true)
                  Padding(
                    padding: const EdgeInsets.only(top: AppLayout.spaceMd),
                    child: Text(profile!.bio, style: text.bodyMedium),
                  ),
                if (error != null) ...[
                  Text(
                    error!,
                    style: text.bodyMedium?.copyWith(color: AppColors.error),
                  ),
                  TextButton(onPressed: onRetry, child: const Text('重新读取资料')),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 最近记录使用现有历史查询结果，点击复用正式执行记录页面。
class _RecentRecords extends StatelessWidget {
  const _RecentRecords({required this.records, required this.onOpen});
  final List<MissionDetail> records;
  final ValueChanged<MissionDetail> onOpen;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return AppSectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            container: true,
            header: true,
            child: Text('最近的行动', style: text.titleMedium),
          ),
          const SizedBox(height: AppLayout.spaceSm),
          for (final record in records)
            ListTile(
              key: ValueKey('profile-record-${record.mission.id}'),
              contentPadding: EdgeInsets.zero,
              title: Text(record.mission.title, style: text.bodyLarge),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => onOpen(record),
            ),
        ],
      ),
    );
  }
}

/// 数字只接收页面查询出的事实，空态不能将读取失败当作零。
class _ActivityOverview extends StatelessWidget {
  const _ActivityOverview({
    required this.stats,
    required this.goals,
    required this.onOpenGoal,
    required this.error,
    required this.onRetry,
  });
  final ({int goals, int ended, int minutes})? stats;
  final List<Goal> goals;
  final ValueChanged<Goal> onOpenGoal;
  final String? error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
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
          const SizedBox(height: AppLayout.spaceLg),
          AdaptiveColumns(
            minColumnWidth: 88,
            maxColumns: 3,
            spacing: 12,
            children: [
              _ActivityStat(
                icon: Icons.flag_outlined,
                label: '进行中目标',
                value: stats?.goals,
                unit: '个',
              ),
              _ActivityStat(
                icon: Icons.task_alt,
                label: '已结束任务',
                value: stats?.ended,
                unit: '项',
              ),
              _ActivityStat(
                icon: Icons.timelapse_rounded,
                label: '累计专注',
                value: stats?.minutes,
                unit: '分钟',
              ),
            ],
          ),

          if (goals.isNotEmpty) ...[
            const SizedBox(height: AppLayout.spaceXl),
            const Divider(height: 1),
            const SizedBox(height: AppLayout.spaceLg),
            Semantics(
              container: true,
              header: true,
              child: Text('进行中的目标', style: text.titleMedium),
            ),
            const SizedBox(height: AppLayout.spaceSm),
            for (final goal in goals)
              ListTile(
                key: ValueKey('profile-goal-${goal.id}'),
                contentPadding: EdgeInsets.zero,
                title: Text(goal.title, style: text.bodyLarge),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => onOpenGoal(goal),
              ),
          ],
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
    required this.icon,
    required this.label,
    required this.value,
    required this.unit,
  });
  final IconData icon;
  final String label;
  final int? value;
  final String unit;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppLayout.spaceXs,
        vertical: AppLayout.spaceSm,
      ),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppLayout.radiusLg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: AppLayout.iconLg, color: AppColors.primary),
          const SizedBox(height: AppLayout.spaceMd),
          Tooltip(
            message: label == '累计专注' ? '仅统计已结束任务的实际专注时间' : label,
            child: Text(label, style: text.bodySmall),
          ),
          const SizedBox(height: AppLayout.spaceXs),
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
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppLayout.radiusXxl),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppLayout.spaceXxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('编辑本机资料', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: AppLayout.spaceXxl),
            AppTextField(
              key: const Key('profile-name-input'),
              label: '称呼',
              hint: '你希望如何称呼自己',
              controller: _name,
              maxLines: 1,
              readOnly: _saving,
            ),
            const SizedBox(height: AppLayout.spaceXl),
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
                padding: const EdgeInsets.only(top: AppLayout.spaceMd),
                child: Semantics(
                  liveRegion: true,
                  child: Text(
                    _error!,
                    style: const TextStyle(color: AppColors.error),
                  ),
                ),
              ),
            const SizedBox(height: AppLayout.spaceXxl),
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

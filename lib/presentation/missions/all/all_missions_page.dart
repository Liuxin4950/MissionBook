import '../../../core/theme/app_motion.dart';
import '../../widgets/app_dropdown_form_field.dart';
import '../../widgets/app_date_picker.dart';
import '../../../domain/entities/mission_maintenance.dart';
import '../shared/mission_maintenance_action.dart';
import '../../widgets/app_empty_state.dart';
import '../../widgets/adaptive_columns.dart';
import '../../widgets/app_section_card.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import '../../widgets/detail_pane.dart';

import '../../../application/goals/goal_service.dart';
import '../../../application/missions/mission_service.dart';
import '../../../core/theme/app_layout.dart';
import '../../../core/theme/colors.dart';
import '../../../domain/entities/goal.dart';
import '../../../domain/entities/mission_detail.dart';
import '../../../domain/entities/mission_phase.dart';
import '../detail/mission_detail_page.dart';
import '../execution/mission_execution_page.dart';
import '../shared/mission_phase_display.dart';
import '../shared/mission_phase_icon.dart';
import '../shared/mission_live_status.dart';
import '../../widgets/app_top_bar.dart';
import '../../widgets/app_expansion.dart';
import 'timetable_layout.dart';
import 'week_timetable_layout.dart';
import 'mission_week_timetable.dart';

enum _TaskDateScope { thisWeek, selected, all, pastUnstarted }

/// 跨日期读取全部任务，筛选只作用于查询结果，不另存一份可变阶段。
class AllMissionsPage extends StatefulWidget {
  const AllMissionsPage({
    super.key,
    required this.missions,
    this.goals,
    this.clock = DateTime.now,
  });
  final MissionService missions;
  final GoalService? goals;
  final DateTime Function() clock;
  @override
  State<AllMissionsPage> createState() => _AllMissionsPageState();
}

class _AllMissionsPageState extends State<AllMissionsPage>
    with WidgetsBindingObserver {
  late Future<List<MissionDetail>> _records;
  late Future<List<Goal>> _goalChoices;
  StreamSubscription<void>? _missionChanges, _goalChanges;
  List<MissionDetail>? _lastRecords;
  DateTime? _weekStart;
  bool _showFilters = false;
  MissionPhase? _phase;
  String? _goalId; // null 全部；空字符串只看独立任务。
  bool _pastUnstarted = false;
  bool _opening = false;
  List<String> get _filterLabels {
    final today = DateUtils.dateOnly(timetableNow(widget.clock()));
    final labels = <String>[];
    if (_pastUnstarted) {
      labels.add('以前未开始');
    } else if (_weekStart == null) {
      labels.add('全部日期');
    } else if (!DateUtils.isSameDay(_weekStart, timetableWeekStart(today))) {
      labels.add(_weekLabel(_weekStart!));
    }
    if (_phase != null) labels.add(phaseLabel(_phase!));
    if (_goalId != null) labels.add(_goalId!.isEmpty ? '独立任务' : '指定目标');
    return labels;
  }

  int get _activeFilterCount => _filterLabels.length;

  @override
  void initState() {
    super.initState();
    _weekStart = timetableWeekStart(timetableNow(widget.clock()));
    WidgetsBinding.instance.addObserver(this);
    _read();
    _missionChanges = widget.missions.changes.listen((_) => _refresh());
    _goalChanges = widget.goals?.changes.listen((_) => _refreshGoals());
  }

  void _read() {
    _records = widget.missions.findAllDetailsAndReconcile()..ignore();
    _goalChoices = widget.goals == null
        ? Future.value(const [])
        : Future.wait([
            widget.goals!.findAll(),
            widget.goals!.findDropped(),
          ]).then((groups) => [...groups[0], ...groups[1]]);
    _goalChoices.ignore();
  }

  void _refresh() {
    if (mounted) {
      setState(() {
        _records = widget.missions.findAllDetailsAndReconcile()..ignore();
      });
    }
  }

  void _refreshGoals() {
    if (mounted) {
      setState(() {
        _goalChoices = widget.goals == null
            ? Future.value(const [])
            : Future.wait([
                widget.goals!.findAll(),
                widget.goals!.findDropped(),
              ]).then((groups) => [...groups[0], ...groups[1]]);
        _goalChoices.ignore();
      });
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refresh();
      _refreshGoals();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_missionChanges?.cancel());
    unawaited(_goalChanges?.cancel());
    super.dispose();
  }

  Future<void> _pickDay() async {
    final today = timetableNow(widget.clock());
    final selected = await showAppDatePicker(
      context: context,
      initialDate: _weekStart ?? today,
      firstDate: DateTime(1),
      lastDate: DateTime(9999, 12, 31),
      currentDate: today,
      title: '选择一周中的任意日期',
    );
    if (mounted && selected != null) {
      setState(() {
        _weekStart = timetableWeekStart(selected);
        _pastUnstarted = false;
      });
    }
  }

  Future<void> _open(MissionDetail detail) async {
    if (_opening) return;
    _opening = true;
    try {
      final closed = openDetailPane<void>(
        context,
        label:
            detail.phase == MissionPhase.running ||
                (detail.phase == MissionPhase.paused ||
                    detail.phase == MissionPhase.reportPending)
            ? '任务执行'
            : '任务详情',
        builder: (_) =>
            detail.phase == MissionPhase.running ||
                (detail.phase == MissionPhase.paused ||
                    detail.phase == MissionPhase.reportPending)
            ? MissionExecutionPage(
                detail: detail,
                service: widget.missions,
                clock: widget.clock,
              )
            : detail.phase == MissionPhase.cancelled
            ? MissionDetailPage.fromHistory(
                missionId: detail.mission.id,
                missionService: widget.missions,
              )
            : MissionDetailPage(
                missionId: detail.mission.id,
                missionService: widget.missions,
              ),
      );
      unawaited(
        closed
            .then((_) {
              if (mounted) _refresh();
            })
            .catchError((Object error, StackTrace stack) {
              debugPrint('全部任务详情关闭失败：${error.runtimeType}\n$stack');
            }),
      );
    } finally {
      _opening = false;
      _refresh();
    }
  }

  String _dateKey(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';

  DateTime? _completionDay(MissionDetail detail) {
    // 完成日期与日程共用北京时间的日历日；
    // “是否报告完成”的判定口径统一走 MissionDetail 的派生属性。
    final report = detail.completionReport;
    return report == null
        ? null
        : DateUtils.dateOnly(timetableNow(report.occurredAt));
  }

  bool _matches(MissionDetail detail, DateTime now) =>
      (_phase == null || detail.phase == _phase) &&
      (_goalId == null ||
          (_goalId!.isEmpty
              ? detail.mission.goalId == null
              : detail.mission.goalId == _goalId)) &&
      (!_pastUnstarted ||
          (detail.phase == MissionPhase.notStarted &&
              detail.schedule.scheduledDate.compareTo(
                    timetableDateKey(timetableNow(now)),
                  ) <
                  0));

  bool _inSelectedRange(MissionDetail detail, DateTime now) {
    final start = _weekStart;
    return start == null ||
        timetableOverlapsRange(
          detail,
          start,
          DateTime.utc(start.year, start.month, start.day + 7),
          now,
        );
  }

  Widget _maintenanceMenu(BuildContext context) =>
      PopupMenuButton<MissionMaintenanceAction>(
        popUpAnimationStyle: AppMotion.overlayStyle(context),
        tooltip: '批量操作当前筛选结果',
        icon: const Icon(Icons.more_horiz),
        onSelected: (action) async {
          final now = widget.clock();
          final ids = (_lastRecords ?? const <MissionDetail>[])
              .where(
                (detail) =>
                    _matches(detail, now) && _inSelectedRange(detail, now),
              )
              .map((detail) => detail.mission.id)
              .toList();
          await maintainMissions(context, widget.missions, action, ids);
        },
        itemBuilder: (_) => const [
          PopupMenuItem(
            value: MissionMaintenanceAction.cancel,
            child: Text('批量取消未开始任务'),
          ),
          PopupMenuItem(
            value: MissionMaintenanceAction.delete,
            child: Text('永久删除筛选结果'),
          ),
        ],
      );

  Widget _filterAction(BuildContext context) {
    final compact =
        MediaQuery.sizeOf(context).width < AppLayout.mediumBreakpoint;
    final label = _showFilters
        ? '收起筛选'
        : _activeFilterCount == 0
        ? '筛选任务'
        : '筛选任务，$_activeFilterCount项条件';
    final icon = Icon(
      _showFilters ? Icons.tune_rounded : Icons.tune,
      size: AppLayout.iconMd,
    );
    return Semantics(
      expanded: _showFilters,
      child: compact
          ? IconButton(
              key: const Key('all-missions-filters'),
              tooltip: label,
              onPressed: () => setState(() => _showFilters = !_showFilters),
              icon: icon,
            )
          : TextButton.icon(
              key: const Key('all-missions-filters'),
              onPressed: () => setState(() => _showFilters = !_showFilters),
              icon: icon,
              label: Text(
                _showFilters
                    ? '收起筛选'
                    : _activeFilterCount == 0
                    ? '筛选'
                    : '筛选 · $_activeFilterCount',
              ),
            ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppTopBar(
      maxContentWidth: AppLayout.dashboardMaxWidth,
      title: '全部任务',
      actions: [
        _filterAction(context),
        _maintenanceMenu(context),
        const SizedBox(width: AppLayout.spaceSm),
      ],
    ),
    body: SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: AppLayout.dashboardMaxWidth,
          ),
          child: FutureBuilder<List<MissionDetail>>(
            future: _records,
            builder: (context, snapshot) {
              if (snapshot.hasData) _lastRecords = snapshot.data;
              final all = snapshot.data ?? _lastRecords;
              if (all == null &&
                  snapshot.connectionState != ConnectionState.done) {
                return const Center(child: CircularProgressIndicator());
              }
              if (all == null) {
                return Center(
                  child: TextButton(
                    onPressed: _refresh,
                    child: const Text('任务读取失败，点击重试'),
                  ),
                );
              }
              final today = DateUtils.dateOnly(timetableNow(widget.clock()));
              final now = widget.clock();
              bool matches(MissionDetail detail) => _matches(detail, now);
              final rangeStart = _weekStart;
              // 展示与顶栏批量操作共用筛选及区间，操作前使用当下时钟重算。
              final filtered = all
                  .where(
                    (detail) =>
                        matches(detail) && _inSelectedRange(detail, now),
                  )
                  .toList();
              final large = rangeStart == null && all.length > 250;
              final dates =
                  rangeStart != null || large
                        ? <String>[]
                        : <String>{
                            for (final detail in filtered)
                              ...timetableDateKeys(detail, now),
                          }.toList()
                    ..sort((a, b) => b.compareTo(a));
              return RefreshIndicator(
                onRefresh: () async {
                  _refresh();
                  try {
                    await _records;
                  } catch (_) {
                    /* FutureBuilder 显示可恢复错误。 */
                  }
                },
                child: ListView(
                  key: const Key('all-missions-list'),
                  padding: EdgeInsets.symmetric(
                    horizontal:
                        MediaQuery.sizeOf(context).width <
                            AppLayout.mediumBreakpoint
                        ? AppLayout.spaceSm
                        : AppLayout.spaceXxl,
                    vertical: AppLayout.spaceMd,
                  ),
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: [
                    _dateNavigation(context),
                    if (_showFilters) ...[
                      const SizedBox(height: AppLayout.spaceLg),
                      _filters(context, all, today),
                    ],
                    if (!_showFilters && _activeFilterCount > 0)
                      Padding(
                        padding: const EdgeInsets.only(top: AppLayout.spaceSm),
                        child: Text(
                          '筛选：${_filterLabels.join(' · ')}',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ),
                    if (snapshot.hasError)
                      Padding(
                        padding: const EdgeInsets.only(top: AppLayout.spaceMd),
                        child: TextButton(
                          onPressed: _refresh,
                          child: const Text('刷新失败，当前保留上次读取的任务，点击重试'),
                        ),
                      ),
                    const SizedBox(height: AppLayout.spaceSm),
                    if (_weekStart != null)
                      MissionWeekTimetable(
                        start: _weekStart!,
                        records: all,
                        visible: matches,
                        onOpen: (id) {
                          final detail = all
                              .where((detail) => detail.mission.id == id)
                              .firstOrNull;
                          if (detail != null) {
                            unawaited(_open(detail));
                          } else {
                            _refresh();
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('任务已变化，请从最新列表重新选择')),
                            );
                          }
                        },
                        buildOtherRow: (detail) =>
                            _row(context, detail, embedded: true),
                        clock: widget.clock,
                        filtered: _phase != null || _goalId != null,
                      )
                    else if (large)
                      _PagedMissionRows(
                        key: ValueKey(
                          '$_weekStart|$_phase|$_goalId|$_pastUnstarted',
                        ),
                        records: filtered,
                        buildRow: (detail) => _row(context, detail),
                      )
                    else if (dates.isEmpty)
                      _empty(context)
                    else
                      for (final date in dates)
                        _tasksForDay(
                          context,
                          all,
                          DateTime.parse(date),
                          matches,
                        ),
                    const SizedBox(height: AppLayout.sectionGap),
                    AppSectionCard(
                      padding: EdgeInsets.zero,
                      child: AppExpansionTile(
                        key: const Key('all-missions-statistics'),
                        insetHeader: false,
                        headerPadding: const EdgeInsets.symmetric(
                          horizontal: AppLayout.spaceLg,
                          vertical: AppLayout.spaceXs,
                        ),
                        childrenPadding: const EdgeInsets.fromLTRB(
                          AppLayout.spaceLg,
                          0,
                          AppLayout.spaceLg,
                          AppLayout.spaceMd,
                        ),
                        title: Text(
                          '完成统计',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        children: [_statistics(context, all, today)],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    ),
  );

  Widget _tasksForDay(
    BuildContext context,
    List<MissionDetail> all,
    DateTime day,
    bool Function(MissionDetail) matches,
  ) {
    final until = DateTime.utc(day.year, day.month, day.day + 1);
    final now = widget.clock();
    final records = all
        .where(
          (detail) =>
              matches(detail) &&
              timetableOverlapsRange(detail, day, until, now),
        )
        .toList();
    return Padding(
      padding: const EdgeInsets.only(bottom: AppLayout.sectionGap),
      child: AppSectionCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: () => setState(() {
                  _weekStart = timetableWeekStart(day);
                  _pastUnstarted = false;
                }),
                child: Text(
                  _dateKey(day),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
            ),
            for (final detail in records) _row(context, detail, embedded: true),
          ],
        ),
      ),
    );
  }

  String _weekLabel(DateTime start) {
    final end = DateTime.utc(start.year, start.month, start.day + 6);
    final supportedEnd = end.year > 9999 ? DateTime.utc(9999, 12, 31) : end;
    return '${start.year}年${start.month}月${start.day}日—'
        '${supportedEnd.year != start.year ? '${supportedEnd.year}年' : ''}'
        '${supportedEnd.month}月${supportedEnd.day}日';
  }

  Widget _dateNavigation(BuildContext context) {
    final start = _weekStart;
    final current = timetableWeekStart(timetableNow(widget.clock()));
    final isCurrent = DateUtils.isSameDay(start, current);
    void move(int offset) => setState(() {
      _weekStart = DateTime.utc(
        start!.year,
        start.month,
        start.day + offset * 7,
      );
      _pastUnstarted = false;
    });
    return AppSectionCard(
      padding: const EdgeInsets.symmetric(vertical: AppLayout.spaceXs),
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                key: const Key('timetable-previous-week'),
                tooltip: '上一周',
                onPressed:
                    start == null ||
                        start.year == 1 && start.month == 1 && start.day == 1
                    ? null
                    : () => move(-1),
                icon: const Icon(Icons.chevron_left),
              ),
              Expanded(
                child: TextButton(
                  key: const Key('all-missions-date'),
                  onPressed: _pickDay,
                  child: Text(
                    start == null
                        ? (_pastUnstarted ? '以前未开始' : '全部日期')
                        : _weekLabel(start),
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
              ),
              IconButton(
                key: const Key('timetable-next-week'),
                tooltip: '下一周',
                onPressed:
                    start == null ||
                        DateTime.utc(
                              start.year,
                              start.month,
                              start.day + 7,
                            ).year >
                            9999
                    ? null
                    : () => move(1),
                icon: const Icon(Icons.chevron_right),
              ),
            ],
          ),
          if (!isCurrent)
            TextButton(
              key: const Key('all-missions-current-week'),
              onPressed: () => setState(() {
                _weekStart = current;
                _pastUnstarted = false;
              }),
              child: const Text('返回本周'),
            ),
        ],
      ),
    );
  }

  Widget _filters(
    BuildContext context,
    List<MissionDetail> all,
    DateTime today,
  ) {
    final theme = Theme.of(context);
    final todayKey = _dateKey(today);
    final selectedDay = _weekStart;
    final customDay =
        selectedDay != null &&
        !DateUtils.isSameDay(selectedDay, timetableWeekStart(today));
    final _TaskDateScope dateScope;
    if (_pastUnstarted) {
      dateScope = _TaskDateScope.pastUnstarted;
    } else if (selectedDay == null) {
      dateScope = _TaskDateScope.all;
    } else if (customDay) {
      dateScope = _TaskDateScope.selected;
    } else {
      dateScope = _TaskDateScope.thisWeek;
    }
    final pastCount = all
        .where(
          (item) =>
              item.phase == MissionPhase.notStarted &&
              item.schedule.scheduledDate.compareTo(todayKey) < 0,
        )
        .length;
    return AppSectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(child: Text('筛选任务', style: theme.textTheme.labelLarge)),
              if (_activeFilterCount > 0)
                TextButton(onPressed: _resetFilters, child: const Text('重置筛选')),
            ],
          ),
          const SizedBox(height: AppLayout.spaceMd),
          AdaptiveColumns(
            minColumnWidth: 150,
            maxColumns: 2,
            spacing: AppLayout.spaceMd,
            children: [
              AppDropdownFormField<_TaskDateScope>(
                key: ValueKey(
                  'all-missions-date-scope-$selectedDay-$_pastUnstarted',
                ),
                initialValue: dateScope,
                style: theme.textTheme.bodySmall,
                decoration: const InputDecoration(labelText: '日期范围'),
                items: [
                  const DropdownMenuItem(
                    value: _TaskDateScope.thisWeek,
                    child: Text('本周'),
                  ),
                  if (customDay)
                    DropdownMenuItem(
                      value: _TaskDateScope.selected,
                      child: Text(_weekLabel(selectedDay)),
                    ),
                  const DropdownMenuItem(
                    value: _TaskDateScope.all,
                    child: Text('全部日期'),
                  ),
                  if (pastCount > 0 || _pastUnstarted)
                    DropdownMenuItem(
                      value: _TaskDateScope.pastUnstarted,
                      child: Text('以前未开始 · $pastCount'),
                    ),
                ],
                onChanged: (value) {
                  if (value == null) return;
                  setState(() {
                    if (value == _TaskDateScope.thisWeek) {
                      _weekStart = timetableWeekStart(today);
                      _pastUnstarted = false;
                    } else if (value == _TaskDateScope.all) {
                      _weekStart = null;
                      _pastUnstarted = false;
                    } else if (value == _TaskDateScope.pastUnstarted) {
                      _weekStart = null;
                      _pastUnstarted = true;
                      _phase = null;
                    } else {
                      _pastUnstarted = false;
                    }
                  });
                },
              ),
              AppDropdownFormField<MissionPhase>(
                key: ValueKey('all-missions-phase-${_phase?.name ?? 'all'}'),
                initialValue: _phase,
                style: theme.textTheme.bodySmall,
                decoration: const InputDecoration(labelText: '任务阶段'),
                items: [
                  const DropdownMenuItem(value: null, child: Text('全部阶段')),
                  for (final phase in MissionPhase.values)
                    DropdownMenuItem(
                      value: phase,
                      child: Text(phaseLabel(phase)),
                    ),
                ],
                onChanged: (value) => setState(() {
                  _phase = value;
                  _pastUnstarted = false;
                }),
              ),
            ],
          ),
          if (widget.goals != null) ...[
            const SizedBox(height: AppLayout.spaceMd),
            FutureBuilder<List<Goal>>(
              future: _goalChoices,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Row(
                    children: [
                      Expanded(
                        child: Text(
                          '目标读取失败，暂不能按目标筛选。',
                          style: theme.textTheme.bodyMedium,
                        ),
                      ),
                      TextButton(
                        onPressed: _refreshGoals,
                        child: const Text('重试'),
                      ),
                    ],
                  );
                }
                final goals = snapshot.data ?? const <Goal>[];
                return AppDropdownFormField<String>(
                  key: ValueKey('all-missions-goal-${_goalId ?? 'all'}'),
                  initialValue:
                      goals.any((goal) => goal.id == _goalId) || _goalId == ''
                      ? _goalId
                      : null,
                  isExpanded: true,
                  style: theme.textTheme.bodySmall,
                  decoration: const InputDecoration(labelText: '目标归属'),
                  items: [
                    const DropdownMenuItem(
                      value: null,
                      child: Text('全部目标与独立任务'),
                    ),
                    const DropdownMenuItem(value: '', child: Text('独立任务')),
                    for (final goal in goals)
                      DropdownMenuItem(
                        value: goal.id,
                        child: Text(
                          goal.title,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                  onChanged: (value) => setState(() => _goalId = value),
                );
              },
            ),
          ],
        ],
      ),
    );
  }

  Widget _row(
    BuildContext context,
    MissionDetail detail, {
    bool embedded = false,
  }) {
    final theme = Theme.of(context);
    return Padding(
      key: Key('all-mission-${detail.mission.id}'),
      padding: EdgeInsets.only(bottom: embedded ? 0 : AppLayout.spaceSm),
      child: Material(
        color: embedded ? Colors.transparent : AppColors.card,
        borderRadius: BorderRadius.circular(AppLayout.radiusXl),
        clipBehavior: Clip.antiAlias,
        child: ListTile(
          contentPadding: EdgeInsets.symmetric(
            horizontal: embedded ? 0 : AppLayout.spaceLg,
            vertical: AppLayout.spaceSm,
          ),
          leading: MissionPhaseIcon(phase: detail.phase),
          title: Text(detail.mission.title, style: theme.textTheme.labelSmall),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${detail.schedule.scheduledDate} · ${phaseLabel(detail.phase, schedule: detail.schedule)}',
                style: theme.textTheme.bodyMedium,
              ),
              if (detail.phase == MissionPhase.running ||
                  (detail.phase == MissionPhase.paused ||
                      detail.phase == MissionPhase.reportPending))
                MissionLiveStatus(
                  phase: detail.phase,
                  events: detail.events,
                  schedule: detail.schedule,
                  includePhase: false,
                  clock: widget.clock,
                ),
            ],
          ),
          trailing: const Icon(
            Icons.chevron_right,
            color: AppColors.textSecondary,
          ),
          onTap: () => _open(detail),
        ),
      ),
    );
  }

  Widget _empty(BuildContext context) => AppEmptyState(
    title: '没有符合筛选条件的任务',
    details: const Text('可以调整日期、阶段或目标。'),
    actions: _activeFilterCount > 0
        ? OutlinedButton(onPressed: _resetFilters, child: const Text('重置筛选'))
        : null,
  );

  void _resetFilters() => setState(() {
    _weekStart = timetableWeekStart(timetableNow(widget.clock()));
    _phase = null;
    _goalId = null;
    _pastUnstarted = false;
  });

  Widget _statistics(
    BuildContext context,
    List<MissionDetail> all,
    DateTime today,
  ) {
    final theme = Theme.of(context);
    final sevenStart = _dateKey(
      DateTime(today.year, today.month, today.day - 6),
    );
    final todayKey = _dateKey(today);
    final planned = all
        .where(
          (item) =>
              item.phase != MissionPhase.cancelled &&
              item.schedule.scheduledDate.compareTo(sevenStart) >= 0 &&
              item.schedule.scheduledDate.compareTo(todayKey) <= 0,
        )
        .length;
    final completedDays = <String, int>{};
    for (final item in all) {
      final day = _completionDay(item);
      if (day != null) {
        final key = _dateKey(day);
        completedDays[key] = (completedDays[key] ?? 0) + 1;
      }
    }
    final recentCompleted = completedDays.entries
        .where(
          (entry) =>
              entry.key.compareTo(sevenStart) >= 0 &&
              entry.key.compareTo(todayKey) <= 0,
        )
        .fold<int>(0, (sum, entry) => sum + entry.value);
    final days = [
      for (var offset = 29; offset >= 0; offset--)
        DateTime(today.year, today.month, today.day - offset),
    ];
    return Padding(
      padding: const EdgeInsets.only(top: AppLayout.spaceSm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('最近 7 天', style: theme.textTheme.titleMedium),
          const SizedBox(height: AppLayout.spaceSm),
          Text(
            '计划 $planned 项 · 报告完成 $recentCompleted 项',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: AppLayout.spaceXl),
          Text('近 30 天完成记录', style: theme.textTheme.titleMedium),
          const SizedBox(height: AppLayout.spaceMd),
          LayoutBuilder(
            builder: (context, box) {
              final columns = box.maxWidth >= 420 ? 15 : 10;
              final cell = ((box.maxWidth - (columns - 1) * 6) / columns).clamp(
                8.0,
                22.0,
              );
              return Align(
                alignment: Alignment.centerLeft,
                child: SizedBox(
                  width: columns * cell + (columns - 1) * 6,
                  child: Wrap(
                    spacing: AppLayout.spaceSm,
                    runSpacing: AppLayout.spaceSm,
                    children: [
                      for (final day in days)
                        Tooltip(
                          message:
                              '${_dateKey(day)} · 报告完成 ${completedDays[_dateKey(day)] ?? 0} 项',
                          child: Semantics(
                            label:
                                '${_dateKey(day)} 报告完成 ${completedDays[_dateKey(day)] ?? 0} 项',
                            child: Container(
                              width: cell,
                              height: cell,
                              decoration: BoxDecoration(
                                color: (completedDays[_dateKey(day)] ?? 0) > 0
                                    ? AppColors.primary
                                    : AppColors.primarySoft,
                                borderRadius: BorderRadius.circular(
                                  AppLayout.radiusXs,
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: AppLayout.spaceSm),
          Text('深色方格表示当天有完成报告；计划与完成分别计算。', style: theme.textTheme.bodySmall),
        ],
      ),
    );
  }
}

/// 大量任务时使用固定页容量，避免构建巨量时间轴交集和卡片。
class _PagedMissionRows extends StatefulWidget {
  const _PagedMissionRows({
    super.key,
    required this.records,
    required this.buildRow,
  });
  final List<MissionDetail> records;
  final Widget Function(MissionDetail) buildRow;
  @override
  State<_PagedMissionRows> createState() => _PagedMissionRowsState();
}

class _PagedMissionRowsState extends State<_PagedMissionRows> {
  int _page = 0;
  @override
  void didUpdateWidget(covariant _PagedMissionRows oldWidget) {
    super.didUpdateWidget(oldWidget);
    final last = widget.records.isEmpty ? 0 : (widget.records.length - 1) ~/ 50;
    if (_page > last) _page = last;
  }

  @override
  Widget build(BuildContext context) {
    final count = widget.records.length;
    final start = _page * 50;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('任务量较大，使用分页列表。共 $count 项，每页 50 项；本视图不绘制课表交集。'),
        const SizedBox(height: AppLayout.spaceMd),
        for (final detail in widget.records.skip(start).take(50))
          widget.buildRow(detail),
        Wrap(
          spacing: AppLayout.spaceSm,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            TextButton(
              onPressed: _page == 0 ? null : () => setState(() => _page--),
              child: const Text('上一页任务'),
            ),
            Text(
              '第 ${count == 0 ? 0 : start + 1}–${(start + 50).clamp(0, count)} / $count',
            ),
            TextButton(
              onPressed: start + 50 >= count
                  ? null
                  : () => setState(() => _page++),
              child: const Text('下一页任务'),
            ),
          ],
        ),
      ],
    );
  }
}

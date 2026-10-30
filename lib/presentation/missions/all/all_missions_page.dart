import '../../widgets/app_dropdown_form_field.dart';
import '../../widgets/app_date_picker.dart';
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
import 'mission_timetable.dart';
import 'timetable_layout.dart';

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
  DateTime? _day;
  bool _showFilters = false;
  MissionPhase? _phase;
  String? _goalId; // null 全部；空字符串只看独立任务。
  bool _pastUnstarted = false;
  bool _opening = false;
  int get _activeFilterCount =>
      (_phase == null ? 0 : 1) +
      (_goalId == null ? 0 : 1) +
      (_pastUnstarted ? 1 : 0);

  @override
  void initState() {
    super.initState();
    _day = DateUtils.dateOnly(timetableNow(widget.clock()));
    WidgetsBinding.instance.addObserver(this);
    _read();
    _missionChanges = widget.missions.changes.listen((_) => _refresh());
    _goalChanges = widget.goals?.changes.listen((_) => _refreshGoals());
  }

  void _read() {
    _records = widget.missions.findAllDetails()..ignore();
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
        _records = widget.missions.findAllDetails()..ignore();
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
      initialDate: _day ?? today,
      firstDate: DateTime(1),
      lastDate: DateTime(9999, 12, 31),
      currentDate: today,
      title: '筛选计划日期',
    );
    if (mounted && selected != null) {
      setState(() {
        _day = selected;
        _pastUnstarted = false;
      });
    }
  }

  Future<void> _open(MissionDetail detail) async {
    if (_opening) return;
    _opening = true;
    try {
      await openDetailPane<void>(
        context,
        label:
            detail.phase == MissionPhase.running ||
                detail.phase == MissionPhase.paused
            ? '任务执行'
            : '任务详情',
        builder: (_) =>
            detail.phase == MissionPhase.running ||
                detail.phase == MissionPhase.paused
            ? MissionExecutionPage(detail: detail, service: widget.missions)
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
    } finally {
      _opening = false;
      _refresh();
    }
  }

  String _dateKey(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';

  DateTime? _completionDay(MissionDetail detail) {
    // 完成日期按报告完成的 END 事件在设备本地的日历日；
    // “是否报告完成”的判定口径统一走 MissionDetail 的派生属性。
    final report = detail.completionReport;
    return report == null
        ? null
        : DateUtils.dateOnly(report.occurredAt.toLocal());
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppTopBar(
      maxContentWidth: AppLayout.dashboardMaxWidth,
      title: '全部任务',
      actions: [
        Tooltip(
          message: _showFilters ? '收起筛选' : '筛选任务',
          child: Semantics(
            expanded: _showFilters,
            child: TextButton.icon(
              key: const Key('all-missions-filters'),
              onPressed: () => setState(() => _showFilters = !_showFilters),
              icon: Icon(
                _showFilters ? Icons.tune_rounded : Icons.tune,
                size: AppLayout.iconMd,
              ),
              label: Text(
                _showFilters
                    ? '收起筛选'
                    : _activeFilterCount == 0
                    ? '筛选'
                    : '筛选 · $_activeFilterCount',
              ),
            ),
          ),
        ),
        SizedBox(width: AppLayout.horizontalPadding(context) - 8),
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
              final todayKey = _dateKey(today);
              bool matches(MissionDetail detail) =>
                  (_phase == null || detail.phase == _phase) &&
                  (_goalId == null ||
                      (_goalId!.isEmpty
                          ? detail.mission.goalId == null
                          : detail.mission.goalId == _goalId)) &&
                  (!_pastUnstarted ||
                      (detail.phase == MissionPhase.notStarted &&
                          detail.schedule.scheduledDate.compareTo(todayKey) <
                              0));
              // 保留计划日期入口，也补上实际区间覆盖日，跨日执行可在对应日阅读。
              final dayKey = _day == null ? null : _dateKey(_day!);
              final volume = dayKey == null
                  ? all.length
                  : all
                        .where(
                          (detail) => timetableDateKeys(
                            detail,
                            widget.clock(),
                          ).contains(dayKey),
                        )
                        .length;
              final large = volume > 250;
              final pagedRecords = large
                  ? all
                        .where(
                          (detail) =>
                              matches(detail) &&
                              (dayKey == null ||
                                  timetableDateKeys(
                                    detail,
                                    widget.clock(),
                                  ).contains(dayKey)),
                        )
                        .toList()
                  : <MissionDetail>[];
              final dates = <String>{
                for (final detail in all.where(matches))
                  ...timetableDateKeys(detail, widget.clock()),
              }.toList()..sort((a, b) => b.compareTo(a));
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
                  padding: AppLayout.pagePadding(context),
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: [
                    _dateNavigation(context, today),
                    if (_showFilters) ...[
                      const SizedBox(height: AppLayout.spaceLg),
                      _filters(context, all, todayKey),
                    ],
                    if (!_showFilters &&
                        (_phase != null || _goalId != null || _pastUnstarted))
                      Padding(
                        padding: const EdgeInsets.only(top: AppLayout.spaceSm),
                        child: Text(
                          '筛选：${[if (_phase != null) phaseLabel(_phase!), if (_goalId != null) _goalId!.isEmpty ? '独立任务' : '指定目标', if (_pastUnstarted) '以前未开始'].join(' · ')}',
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
                    const SizedBox(height: AppLayout.spaceXl),
                    if (large)
                      _PagedMissionRows(
                        key: ValueKey('$_day|$_phase|$_goalId|$_pastUnstarted'),
                        records: pagedRecords,
                        buildRow: (detail) => _row(context, detail),
                      )
                    else if (_day != null)
                      _tasksForDay(context, all, _day!, matches)
                    else if (dates.isEmpty)
                      _empty(context)
                    else
                      for (final date in dates)
                        _tasksForDay(
                          context,
                          all,
                          DateTime.parse(date),
                          matches,
                          showDate: true,
                        ),
                    const SizedBox(height: AppLayout.spaceXxl),
                    AppSectionCard(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppLayout.spaceLg,
                        vertical: AppLayout.spaceXs,
                      ),
                      child: ExpansionTile(
                        key: const Key('all-missions-statistics'),
                        tilePadding: EdgeInsets.zero,
                        childrenPadding: const EdgeInsets.only(
                          bottom: AppLayout.spaceMd,
                        ),
                        title: Text(
                          '完成统计',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        shape: const Border(),
                        collapsedShape: const Border(),
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
    bool Function(MissionDetail) matches, {
    bool showDate = false,
  }) {
    TimetableDay layoutAt(DateTime now) => TimetableDay.build(
      all,
      day,
      visible: matches,
      // 实际执行区间按“现在”截断未结束任务；自选任务由此也能画上时间轴。
      now: now,
      // 26px 最小条高 / 每分钟 2px，字号缩放同时作用于两者，比例仍为 13 分钟。
      minimumDisplayMinutes: 13,
    );
    final layout = layoutAt(widget.clock());
    final other = all
        .where(
          (detail) =>
              matches(detail) &&
              detail.schedule.scheduledDate == _dateKey(day) &&
              (detail.schedule.fixedStartAt == null ||
                  detail.phase == MissionPhase.cancelled),
        )
        .toList();
    return Padding(
      padding: EdgeInsets.only(bottom: showDate ? AppLayout.sectionGap : 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (showDate) ...[
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: () => setState(() {
                  _day = day;
                  _pastUnstarted = false;
                }),
                child: Text(
                  _dateKey(day),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
            ),
            const SizedBox(height: AppLayout.spaceSm),
          ],
          AdaptiveColumns(
            minColumnWidth: 420,
            maxColumns: 2,
            children: [
              if (layout.slots.isNotEmpty || !showDate && other.isEmpty)
                MissionTimetable(
                  day: day,
                  layoutBuilder: layoutAt,
                  onOpen: (id) => _open(
                    all.firstWhere((detail) => detail.mission.id == id),
                  ),
                  clock: widget.clock,
                  filtered: _phase != null || _goalId != null || _pastUnstarted,
                ),
              if (other.isNotEmpty)
                AppSectionCard(
                  padding: const EdgeInsets.all(AppLayout.spaceLg),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (other.any(
                        (detail) => detail.phase != MissionPhase.cancelled,
                      )) ...[
                        Text(
                          '自选任务',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: AppLayout.spaceXs),
                        Text(
                          '按日期安排，时间自由选择',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        const SizedBox(height: AppLayout.spaceMd),
                        for (final detail in other.where(
                          (detail) => detail.phase != MissionPhase.cancelled,
                        ))
                          _row(context, detail, embedded: true),
                      ],
                      if (other.any(
                        (detail) => detail.phase == MissionPhase.cancelled,
                      )) ...[
                        const SizedBox(height: AppLayout.spaceLg),
                        Text(
                          '已取消 · 不占用时段',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: AppLayout.spaceMd),
                        for (final detail in other.where(
                          (detail) => detail.phase == MissionPhase.cancelled,
                        ))
                          _row(context, detail, embedded: true),
                      ],
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _dateNavigation(BuildContext context, DateTime today) {
    const weekdays = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];
    final day = _day;
    final theme = Theme.of(context);
    void move(int offset) => setState(() {
      _day = DateTime(day!.year, day.month, day.day + offset);
      _pastUnstarted = false;
    });
    final current = DateUtils.isSameDay(today, day);
    final navigation = Row(
      children: [
        IconButton(
          key: const Key('timetable-previous-day'),
          tooltip: '前一天',
          onPressed:
              day == null || day.year == 1 && day.month == 1 && day.day == 1
              ? null
              : () => move(-1),
          icon: const Icon(Icons.chevron_left),
        ),
        Expanded(
          child: TextButton(
            key: const Key('all-missions-date'),
            onPressed: _pickDay,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Flexible(
                  child: Text(
                    day == null
                        ? '全部日期'
                        : '${day.year}年${day.month}月${day.day}日 · ${weekdays[day.weekday - 1]}',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleSmall,
                  ),
                ),
                const SizedBox(width: AppLayout.spaceXs),
                const Icon(Icons.expand_more, size: AppLayout.iconSm),
              ],
            ),
          ),
        ),
        IconButton(
          key: const Key('timetable-next-day'),
          tooltip: '后一天',
          onPressed:
              day == null ||
                  day.year == 9999 && day.month == 12 && day.day == 31
              ? null
              : () => move(1),
          icon: const Icon(Icons.chevron_right),
        ),
      ],
    );
    final shortcuts = Wrap(
      spacing: 8,
      runSpacing: 4,
      alignment: WrapAlignment.center,
      children: [
        ChoiceChip(
          key: const Key('all-missions-back-today'),
          label: const Text('今天'),
          selected: current,
          showCheckmark: false,
          onSelected: (_) => setState(() {
            _day = today;
            _pastUnstarted = false;
          }),
        ),
        ChoiceChip(
          key: const Key('all-missions-date-all-shortcut'),
          label: const Text('全部日期'),
          selected: day == null && !_pastUnstarted,
          showCheckmark: false,
          onSelected: (_) => setState(() {
            _day = null;
            _pastUnstarted = false;
          }),
        ),
      ],
    );
    return AppSectionCard(
      padding: const EdgeInsets.all(AppLayout.spaceSm),
      child: LayoutBuilder(
        builder: (context, box) {
          if (box.maxWidth >= 640 * MediaQuery.textScalerOf(context).scale(1)) {
            return Row(
              children: [
                Expanded(child: navigation),
                const SizedBox(width: AppLayout.spaceLg),
                shortcuts,
              ],
            );
          }
          return Column(
            children: [
              navigation,
              const SizedBox(height: AppLayout.spaceXs),
              shortcuts,
            ],
          );
        },
      ),
    );
  }

  Widget _filters(
    BuildContext context,
    List<MissionDetail> all,
    String todayKey,
  ) {
    final theme = Theme.of(context);
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
          Text('筛选任务', style: theme.textTheme.titleMedium),
          const SizedBox(height: AppLayout.spaceMd),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (pastCount > 0)
                TextButton.icon(
                  key: const Key('all-missions-past'),
                  onPressed: () => setState(() {
                    _pastUnstarted = !_pastUnstarted;
                    _day = null;
                    _phase = null;
                  }),
                  icon: const Icon(Icons.history, size: AppLayout.iconSm),
                  label: Text(_pastUnstarted ? '显示全部' : '以前未开始 $pastCount'),
                ),
              if (_phase != null || _goalId != null || _pastUnstarted)
                TextButton(
                  onPressed: () => setState(() {
                    _phase = null;
                    _goalId = null;
                    _pastUnstarted = false;
                  }),
                  child: const Text('重置筛选'),
                ),
            ],
          ),
          const SizedBox(height: AppLayout.spaceMd),
          Text('阶段', style: theme.textTheme.titleSmall),
          const SizedBox(height: AppLayout.spaceSm),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _phaseChip(context, null, '全部'),
              for (final phase in MissionPhase.values)
                _phaseChip(context, phase, phaseLabel(phase)),
            ],
          ),
          if (widget.goals != null) ...[
            const SizedBox(height: AppLayout.spaceMd),
            FutureBuilder<List<Goal>>(
              future: _goalChoices,
              builder: (context, snapshot) {
                final goals = snapshot.data ?? const <Goal>[];
                return AppDropdownFormField<String>(
                  key: ValueKey('all-missions-goal-${_goalId ?? 'all'}'),
                  initialValue:
                      goals.any((goal) => goal.id == _goalId) || _goalId == ''
                      ? _goalId
                      : null,
                  isExpanded: true,
                  style: theme.textTheme.bodyMedium,
                  decoration: const InputDecoration(
                    labelText: '目标归属',
                    border: OutlineInputBorder(),
                  ),
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

  Widget _phaseChip(BuildContext context, MissionPhase? value, String label) =>
      ChoiceChip(
        key: Key('all-missions-phase-${value?.name ?? 'all'}'),
        label: Text(label),
        selected: _phase == value,
        onSelected: (_) => setState(() {
          _phase = value;
          _pastUnstarted = false;
        }),
      );

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
        borderRadius: BorderRadius.circular(AppLayout.radiusLg),
        clipBehavior: Clip.antiAlias,
        child: ListTile(
          contentPadding: EdgeInsets.symmetric(
            horizontal: embedded ? 0 : AppLayout.spaceLg,
            vertical: AppLayout.spaceSm,
          ),
          leading: MissionPhaseIcon(phase: detail.phase),
          title: Text(detail.mission.title, style: theme.textTheme.titleMedium),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${detail.schedule.scheduledDate} · ${phaseLabel(detail.phase)}',
                style: theme.textTheme.bodyMedium,
              ),
              if (detail.phase == MissionPhase.running ||
                  detail.phase == MissionPhase.paused)
                MissionLiveStatus(
                  phase: detail.phase,
                  events: detail.events,
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

  Widget _empty(BuildContext context) => Container(
    padding: const EdgeInsets.all(AppLayout.space3Xl),
    decoration: BoxDecoration(
      color: AppColors.card,
      borderRadius: BorderRadius.circular(AppLayout.radiusXxl),
    ),
    child: Column(
      children: [
        const Icon(
          Icons.filter_alt_off_outlined,
          size: AppLayout.iconDisplay,
          color: AppColors.primary,
        ),
        const SizedBox(height: AppLayout.spaceMd),
        Text('没有符合筛选条件的任务', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: AppLayout.spaceSm),
        Text('可以调整日期、阶段或目标。', style: Theme.of(context).textTheme.bodyMedium),
      ],
    ),
  );

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
                    spacing: 6,
                    runSpacing: 6,
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
          spacing: 8,
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

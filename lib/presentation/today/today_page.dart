import '../widgets/app_date_picker.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import '../widgets/app_illustration.dart';
import 'package:timezone/timezone.dart' as tz;

import '../../application/missions/mission_service.dart';
import '../../application/goals/goal_service.dart';
import '../../core/theme/app_layout.dart';
import '../../core/theme/colors.dart';
import '../widgets/app_page_header.dart';
import '../widgets/app_top_bar.dart';
import '../widgets/detail_pane.dart';
import '../missions/form/mission_form_page.dart';
import '../missions/detail/mission_detail_page.dart';
import '../missions/execution/mission_execution_page.dart';
import '../missions/all/all_missions_page.dart';
import '../missions/record/mission_record_page.dart';
import 'today_display.dart' as display;
import 'schedule_section.dart';
import '../missions/all/mission_timetable.dart';
import '../missions/all/timetable_layout.dart';
import '../widgets/app_section_card.dart';
import '../../domain/entities/scheduled_mission.dart';
import '../missions/shared/mission_live_status.dart';
import '../missions/shared/mission_phase_display.dart';
import '../missions/shared/mission_phase_icon.dart';
import '../../domain/entities/mission_detail.dart';
import '../../domain/entities/mission_phase.dart';

// 本页负责加载和导航；日程布局由 ScheduleSection 复用，日期和窗口选择由 display 处理。
// App 创建一个 MissionService，AppShell 将同一份引用传到这里。
// 本页用 findScheduledOn 读列表，也把同一个服务传给创建页和详情页。
/// 展示所选计划日期的任务，并处理刷新、日期选择和打开创建/详情页。
class TodayPage extends StatefulWidget {
  const TodayPage({
    super.key,
    required this.missionService,
    this.goalService,
    this.clock = DateTime.now,
    this.initialDate,
    this.fullSchedule = false,
  });

  final MissionService missionService;
  final GoalService? goalService;
  final DateTime? initialDate;
  final bool fullSchedule;

  /// 默认读取真实时钟；测试可提供可控时刻，不改系统时间或数据库。
  final DateTime Function() clock;

  @override
  State<TodayPage> createState() => _TodayPageState();
}

class _TodayPageState extends State<TodayPage> with WidgetsBindingObserver {
  DateTime get _today => tz.TZDateTime.from(
    widget.clock(),
    tz.getLocation(display.todayScheduleTimeZone),
  );
  // 页面只保存四类信息：选了哪天、查到了什么、是否在等、有没有错误。
  late DateTime _selectedDate;
  display.TodayMissionGroups _missions =
      const display.TodayMissionGroups.empty();
  bool _isLoading = false;
  String? _errorText;
  // 成功读到空列表也有有效快照；不能用任务数量判断是否需要整块加载。
  String? _loadedDate;

  // 快速切换日期时，请求可能乱序返回；只接收最后一次请求的结果。
  int _loadRequest = 0;
  bool _isOpeningCreate = false;
  bool _isOpeningDetail = false;
  bool _isPickingDate = false;
  bool _isOpeningSchedules = false;
  bool _isOpeningAllMissions = false;
  bool _isOpeningRecord = false;
  StreamSubscription<void>? _changes;
  // 跨日待补与所选排期日期分开；不让昨天结束的任务在今天失去材料入口。
  List<MissionDetail> _pendingEvidence = const [];
  List<ScheduledMission> _scheduled = const [];
  final _sideSectionsKey = GlobalKey();

  // 入口一：Flutter 创建 State 后调用一次，默认选择上海日历的今天并读取。
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _selectedDate = DateUtils.dateOnly(
      widget.initialDate ??
          tz.TZDateTime.from(
            widget.clock(),
            tz.getLocation(display.todayScheduleTimeZone),
          ),
    );
    _loadMissions();
    // listen 在这里“登记回调”，不是立即查询；服务以后 add 一次才调用一次回调。
    // (_) 中的 _ 表示忽略无内容的通知；_changes 保存订阅，以便 dispose 时取消。
    // 与服务共用同一个对象引用，才能收到它发出的通知。
    // 双栏时列表与详情同时可见，子页提交后也要立即重读，不能等返回才刷新。
    _changes = widget.missionService.changes.listen((_) {
      unawaited(_loadMissions());
    });
  }

  @override
  void dispose() {
    unawaited(_changes?.cancel());
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant TodayPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.missionService != widget.missionService) {
      _loadedDate = null;
      unawaited(_changes?.cancel());
      _changes = widget.missionService.changes.listen((_) {
        unawaited(_loadMissions());
      });
      unawaited(_loadMissions());
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // 从后台回来重读事实；时钟恢复与任务是否暂停是两件不同的事。
    if (state == AppLifecycleState.resumed) unawaited(_loadMissions());
  }

  // 统一加载过程。调用者：initState、下拉刷新、切日期、错误重试、新建/详情页返回。
  // 本方法只通过业务入口拿结果，不接触表对象、SQL 或数据库行类型。
  Future<void> _loadMissions() async {
    final request = ++_loadRequest;
    final date = display.scheduleDateKey(_selectedDate);
    setState(() {
      _isLoading = true;
      _errorText = null;
    });

    try {
      // 先按最新排期的日期找属于这一天的任务，再为每个任务读取执行事实与阶段。
      // 所以排期解决“这一天显示谁”，事件解决“这个任务现在是什么阶段”。
      // date 来自本页选择；await 等待 MissionService.findScheduledOn → 仓储 → SQLite。
      final result = await widget.missionService.findScheduledOn(
        scheduledDate: date,
      );
      final pending = await widget.missionService.findPendingEvidence();
      if (!mounted || request != _loadRequest) return;
      // 一次查询只整理一次：分组、换算时区、准备显示文字，再交给三个区域。
      final missions = display.groupMissionsForDisplay(result);
      setState(() {
        _missions = missions;
        _scheduled = result;
        _pendingEvidence = pending;
        _loadedDate = date;
        _isLoading = false;
      });
    } catch (error, stackTrace) {
      if (!mounted || request != _loadRequest) return;
      debugPrint('读取任务失败：$error\n$stackTrace');
      setState(() {
        _errorText = '任务加载失败，请重试';
        _isLoading = false;
      });
    }
  }

  // 入口二：日期按钮打开选择器。用户选择日期后交给 _changeDate。
  Future<void> _pickDate() async {
    if (_isPickingDate) return;
    _isPickingDate = true;
    DateTime? date;
    try {
      date = await showAppDatePicker(
        context: context,
        initialDate: _selectedDate,
        currentDate: _today,
        firstDate: DateTime(1),
        lastDate: DateTime(9999, 12, 31),
        title: '选择计划日期',
      );
    } finally {
      _isPickingDate = false;
    }
    if (!mounted || date == null) return;
    await _changeDate(date);
  }

  // 日历、周日期栏和今天快捷入口共用同一次加载过程。
  Future<void> _changeDate(DateTime date) async {
    if (DateUtils.isSameDay(date, _selectedDate)) return;
    _selectedDate = DateUtils.dateOnly(date);
    _missions = const display.TodayMissionGroups.empty();
    _scheduled = const [];
    _loadedDate = null;
    await _loadMissions();
  }

  // 入口三：加号/空状态按钮打开表单。这里的 await 等待页面关闭，不是等待查库。
  // 关闭表单后再读取一次，所以新增任务可以出现在列表中。
  Future<void> _openCreate() async {
    if (_isOpeningCreate) return;
    _isOpeningCreate = true;
    try {
      await openDetailPane<void>(
        context,
        label: '新建任务',
        builder: (context) => MissionFormPage(
          missionService: widget.missionService,
          initialScheduledDate: display.scheduleDateKey(_selectedDate),
        ),
      );
    } finally {
      _isOpeningCreate = false;
    }
    if (!mounted) return;
    await _loadMissions();
  }

  // 任务行传来自己的 id；这里只负责导航，不把列表的显示投影冒充完整详情。
  Future<void> _openDetail(String missionId) async {
    // push 在动画期间也可能收到第二次点击；一个详情未关闭前不再叠加同类路由。
    if (_isOpeningDetail) return;
    _isOpeningDetail = true;
    try {
      final detail = await widget.missionService.findDetail(
        missionId: missionId,
      );
      if (!mounted) return;
      if (detail == null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('任务已不存在，请刷新列表')));
        return;
      }
      final executing =
          detail.phase == MissionPhase.running ||
          detail.phase == MissionPhase.paused;
      final closed = openDetailPane<void>(
        context,
        label: executing ? '任务执行' : '任务详情',
        builder: (context) => executing
            ? MissionExecutionPage(
                detail: detail,
                service: widget.missionService,
                clock: widget.clock,
              )
            : MissionDetailPage(
                missionId: missionId,
                missionService: widget.missionService,
              ),
      );
      // 只在读取与派发导航期间防连点；宽屏右栏打开后，左栏仍可选择另一任务。
      unawaited(
        closed.then((_) {
          if (mounted) return _loadMissions();
        }),
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('任务打开失败，请重试')));
      }
    } finally {
      _isOpeningDetail = false;
    }
  }

  Future<void> _openAllSchedules() async {
    if (_isOpeningSchedules) return;
    _isOpeningSchedules = true;
    try {
      await openDetailPane<void>(
        context,
        label: '当日日程',
        builder: (context) => TodayPage(
          missionService: widget.missionService,
          goalService: widget.goalService,
          clock: widget.clock,
          initialDate: _selectedDate,
          fullSchedule: true,
        ),
      );
    } finally {
      _isOpeningSchedules = false;
    }
    if (mounted) await _loadMissions();
  }

  Future<void> _openAllMissions() async {
    if (_isOpeningAllMissions) return;
    _isOpeningAllMissions = true;
    try {
      await openDetailPane<void>(
        context,
        label: '全部任务',
        builder: (_) => AllMissionsPage(
          missions: widget.missionService,
          goals: widget.goalService,
          clock: widget.clock,
        ),
      );
    } finally {
      _isOpeningAllMissions = false;
    }
    if (mounted) await _loadMissions();
  }

  Future<void> _openPendingRecord(MissionDetail detail) async {
    if (_isOpeningRecord) return;
    _isOpeningRecord = true;
    try {
      await openDetailPane<void>(
        context,
        label: '执行记录',
        builder: (_) =>
            MissionRecordPage(detail: detail, service: widget.missionService),
      );
    } finally {
      _isOpeningRecord = false;
      if (mounted) await _loadMissions();
    }
  }

  // build 只描述布局：可下拉的列表 = 页头 + 日期返回入口 + 当前列表内容。
  // build 不查询数据库；它只读取上面的状态，由 _buildContent 决定显示哪一种状态。
  @override
  Widget build(BuildContext context) {
    final today = DateUtils.dateOnly(_today);
    final selectedWeek = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day - _selectedDate.weekday + 1,
    );
    final currentWeek = DateTime(
      today.year,
      today.month,
      today.day - today.weekday + 1,
    );
    final content = SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: AppLayout.dashboardMaxWidth,
          ),
          child: RefreshIndicator(
            onRefresh: _loadMissions,
            child: ListView(
              key: const Key('today-list'),
              // 即使列表为空或很短，也允许向下拖动，触发上面的 onRefresh。
              physics: const AlwaysScrollableScrollPhysics(),
              padding: AppLayout.pagePadding(context),
              children: [
                // 页面顶部：日期文字已经准备好，区域内部只绑定回调、排版。
                if (!widget.fullSchedule)
                  _TodayHeader(
                    dateLabel: display.scheduleDateLabel(_selectedDate),
                    showTodayShortcut: !DateUtils.isSameDay(
                      selectedWeek,
                      currentWeek,
                    ),
                    onPickDate: _pickDate,
                    onCreate: _openCreate,
                    onOpenAllMissions: _openAllMissions,
                    onReturnToday: () => _changeDate(_today),
                  ),
                if (widget.fullSchedule)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Text(
                      display.scheduleDateLabel(_selectedDate),
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  )
                else ...[
                  _WeekStrip(
                    selectedDate: _selectedDate,
                    today: _today,
                    onSelect: _changeDate,
                  ),
                  const SizedBox(height: 16),
                ],
                // 构建元素
                _buildContent(),
                if (!widget.fullSchedule && _pendingEvidence.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  Text('待补材料', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  Text('其他日期结束的任务也可以从这里打开执行记录，继续补交材料。'),
                  for (final detail in _pendingEvidence)
                    Padding(
                      key: ValueKey('today-pending-${detail.mission.id}'),
                      padding: const EdgeInsets.only(top: 8),
                      child: ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(detail.mission.title),
                        subtitle: const Text('打开执行记录补交材料'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => _openPendingRecord(detail),
                      ),
                    ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
    return widget.fullSchedule
        ? Scaffold(
            appBar: const AppTopBar(title: '当日日程'),
            body: content,
          )
        : content;
  }

  // build 调用此方法，按状态选择加载/失败/内容；这里不发起任何异步工作。
  Widget _buildContent() {
    // 仅首次读取当前日期时替换整块内容；同日刷新保留卡片、空态和组件状态。
    final hasSnapshot = _loadedDate == display.scheduleDateKey(_selectedDate);
    if (_isLoading && !hasSnapshot) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 48),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (_errorText != null && !hasSnapshot) {
      return Column(
        children: [
          Text(_errorText!),
          const SizedBox(height: 8),
          OutlinedButton(onPressed: _loadMissions, child: const Text('重新加载')),
        ],
      );
    }
    return LayoutBuilder(
      builder: (context, box) {
        final scale = MediaQuery.textScalerOf(context).scale(14) / 14;
        final wide =
            !widget.fullSchedule &&
            box.maxWidth >= AppLayout.dashboardSplitWidth * scale;
        final side = Column(
          key: _sideSectionsKey,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _FlexibleMissionSection(
              clock: widget.clock,
              items: _missions.flexible,
              onOpenMission: _openDetail,
              onCreate: _openCreate,
            ),
            const SizedBox(height: 20),
            _ScheduleOverview(missions: _missions),
          ],
        );
        Widget schedule = ScheduleSection(
          items: _missions.fixed,
          selectedDate: _selectedDate,
          clock: widget.clock,
          onOpenMission: _openDetail,
          onOpenAll: _openAllSchedules,
          onCreate: _openCreate,
          fullList: widget.fullSchedule,
          illustrateEmpty: _missions.isEmpty,
        );
        if (wide) {
          schedule = AppSectionCard(
            key: const Key('today-timetable-panel'),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '计划日程',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    TextButton.icon(
                      onPressed: _openAllMissions,
                      label: const Text('查看全部'),
                      icon: const Icon(Icons.chevron_right, size: 18),
                      iconAlignment: IconAlignment.end,
                    ),
                  ],
                ),
                if (_missions.fixed.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 48),
                    child: Center(
                      child: Column(
                        children: [
                          if (_missions.isEmpty) ...[
                            AppIllustration(
                              asset: 'assets/illustrations/day-plan.png',
                              width: 192,
                              height: 128,
                            ),
                            const SizedBox(height: 16),
                          ],
                          const Text('这一天还没有固定任务'),
                          const SizedBox(height: 16),
                          FilledButton.icon(
                            onPressed: _openCreate,
                            icon: const Icon(Icons.add),
                            label: const Text('新建任务'),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  MissionTimetable(
                    pixelsPerMinute: 1.2,
                    day: _selectedDate,
                    clock: widget.clock,
                    onOpen: _openDetail,
                    layoutBuilder: (now) => TimetableDay.fromScheduled(
                      _scheduled
                          .where((item) => item.schedule.fixedStartAt != null)
                          .toList(),
                      _selectedDate,
                      now: now,
                      minimumDisplayMinutes: 26 / 1.2,
                    ),
                  ),
              ],
            ),
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_errorText != null)
              Row(
                children: [
                  Expanded(
                    child: Semantics(
                      liveRegion: true,
                      child: Text('刷新失败，当前显示上次加载的任务'),
                    ),
                  ),
                  TextButton(onPressed: _loadMissions, child: const Text('重试')),
                ],
              ),
            if (wide)
              Row(
                key: const Key('today-dashboard-columns'),
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 3, child: schedule),
                  const SizedBox(width: 20),
                  Expanded(flex: 2, child: side),
                ],
              )
            else ...[
              schedule,
              if (!widget.fullSchedule) ...[const SizedBox(height: 20), side],
            ],
          ],
        );
      },
    );
  }
}

// 页面顶部。TodayPage 提供已准备好的日期文字和回调；这里只负责排版。
class _TodayHeader extends StatelessWidget {
  const _TodayHeader({
    required this.dateLabel,
    required this.showTodayShortcut,
    required this.onPickDate,
    required this.onCreate,
    required this.onOpenAllMissions,
    required this.onReturnToday,
  });

  final String dateLabel;
  final bool showTodayShortcut;
  final VoidCallback onPickDate;
  final VoidCallback onCreate;
  final VoidCallback onOpenAllMissions;
  final VoidCallback onReturnToday;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppPageHeader(
          title: '今天',
          subtitle: Wrap(
            spacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              TextButton.icon(
                key: const Key('today-date-picker'),
                onPressed: onPickDate,
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  foregroundColor: theme.colorScheme.onSurfaceVariant,
                  alignment: Alignment.centerLeft,
                  textStyle: theme.textTheme.bodyMedium,
                ),
                label: Text(dateLabel),
                icon: const Icon(Icons.expand_more, size: 20),
                iconAlignment: IconAlignment.end,
              ),
              if (showTodayShortcut)
                TextButton.icon(
                  key: const Key('today-return-current-week'),
                  onPressed: onReturnToday,
                  icon: const Icon(Icons.today_outlined, size: 16),
                  label: const Text('今天'),
                  style: TextButton.styleFrom(
                    textStyle: theme.textTheme.labelMedium,
                  ),
                ),
            ],
          ),
          action: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                key: const Key('today-all-missions-entry'),
                tooltip: '全部任务',
                onPressed: onOpenAllMissions,
                icon: const Icon(
                  Icons.view_list_outlined,
                  color: AppColors.primary,
                ),
              ),
              IconButton.filled(
                onPressed: onCreate,
                icon: const Icon(Icons.add, color: AppColors.onPrimary),
                tooltip: '创建任务',
                style: IconButton.styleFrom(
                  fixedSize: const Size(48, 48),
                  shape: const CircleBorder(),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// 七天快捷选择与日历选择共用同一个查询入口，日期来自真正的日历运算。
class _WeekStrip extends StatelessWidget {
  const _WeekStrip({
    required this.selectedDate,
    required this.today,
    required this.onSelect,
  });
  final DateTime selectedDate;
  final DateTime today;
  final ValueChanged<DateTime> onSelect;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final monday = DateTime(
      selectedDate.year,
      selectedDate.month,
      selectedDate.day - selectedDate.weekday + 1,
    );
    const weekdays = ['一', '二', '三', '四', '五', '六', '日'];
    return Row(
      children: [
        for (var index = 0; index < 7; index++)
          Expanded(
            child: Builder(
              builder: (context) {
                final date = DateTime(
                  monday.year,
                  monday.month,
                  monday.day + index,
                );
                final selected = DateUtils.isSameDay(date, selectedDate);
                final isToday = DateUtils.isSameDay(date, today);
                final foreground = selected
                    ? AppColors.onPrimary
                    : AppColors.textPrimary;
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: Semantics(
                    selected: selected,
                    label:
                        '${display.scheduleDateLabel(date)}${isToday ? '，今天' : ''}',
                    button: true,
                    onTap: () => onSelect(date),
                    excludeSemantics: true,
                    child: Material(
                      key: ValueKey(
                        'today-week-day-${display.scheduleDateKey(date)}',
                      ),
                      color: selected
                          ? theme.colorScheme.primary
                          : isToday
                          ? AppColors.primarySoft
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                      child: InkWell(
                        onTap: () => onSelect(date),
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            border: isToday
                                ? Border.all(
                                    color: selected
                                        ? AppColors.onPrimary.withValues(
                                            alpha: .3,
                                          )
                                        : AppColors.primary.withValues(
                                            alpha: .4,
                                          ),
                                  )
                                : null,
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          child: Column(
                            children: [
                              FittedBox(
                                child: Text(
                                  isToday ? '今天' : weekdays[index],
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: isToday
                                        ? foreground
                                        : selected
                                        ? AppColors.onPrimary
                                        : AppColors.textSecondary,
                                    fontWeight: isToday
                                        ? FontWeight.w600
                                        : null,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 4),
                              FittedBox(
                                child: Text(
                                  '${date.day}',
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: foreground,
                                    fontWeight: selected || isToday
                                        ? FontWeight.w600
                                        : null,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }
}

// 任务卡片语义标签
String _missionSemanticsLabel(
  display.TodayMissionItem item, {
  bool isCurrent = false,
}) => [
  if (isCurrent) '当前计划时段',
  item.isFixed ? item.startTime : '自选时间',
  item.title,
  item.durationLabel,
  if (item.timeZoneLabel != null) item.timeZoneLabel!,
].join('，');

/// 自选任务列表；展开状态留在本区域，查询和打开页面交给回调。
class _FlexibleMissionSection extends StatefulWidget {
  const _FlexibleMissionSection({
    required this.items, // 今天页已加载并转换的完整自选任务列表。
    required this.onOpenMission, // 用户点击后交回页面打开详情。
    required this.onCreate, // 用户点击添加后交回页面打开创建表单。
    required this.clock,
  });

  final List<display.TodayMissionItem> items;
  final ValueChanged<String> onOpenMission;
  final VoidCallback onCreate;
  final DateTime Function() clock;

  @override
  State<_FlexibleMissionSection> createState() =>
      _FlexibleMissionSectionState();
}

class _FlexibleMissionSectionState extends State<_FlexibleMissionSection> {
  static const _previewCount = 3;
  bool _expanded = false;
  int _page = 0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // 折叠只影响排版，完整数据仍由 widget.items 提供，不再查询或转换。
    final hasMore = widget.items.length > _previewCount;
    final visibleItems = _expanded
        ? widget.items.skip(_page * 50).take(50)
        : widget.items.take(_previewCount);
    return Material(
      color: theme.colorScheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Semantics(
                    header: true,
                    child: Text('自选时间', style: theme.textTheme.titleMedium),
                  ),
                ),
                TextButton.icon(
                  onPressed: widget.onCreate,
                  style: TextButton.styleFrom(
                    textStyle: theme.textTheme.labelMedium,
                  ),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('添加'),
                ),
              ],
            ),
            // 没有自选任务时同样保留标题，用一行提示占位；有任务才渲染行和展开入口。
            if (widget.items.isEmpty)
              const _SectionEmptyHint('这一天还没有自选任务')
            else ...[
              for (final item in visibleItems)
                Column(
                  key: ValueKey('flexible-row-${item.id}'),
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _FlexibleMissionRow(
                      clock: widget.clock,
                      item: item,
                      onTap: () => widget.onOpenMission(item.id),
                    ),
                  ],
                ),
              if (_expanded && widget.items.length > 50)
                Wrap(
                  spacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    TextButton(
                      onPressed: _page == 0
                          ? null
                          : () => setState(() => _page--),
                      child: const Text('上一页自选任务'),
                    ),
                    Text('每页 50 项，共 ${widget.items.length} 项'),
                    TextButton(
                      onPressed: (_page + 1) * 50 >= widget.items.length
                          ? null
                          : () => setState(() => _page++),
                      child: const Text('下一页自选任务'),
                    ),
                  ],
                ),
              if (hasMore)
                Align(
                  alignment: Alignment.centerLeft,
                  child: MergeSemantics(
                    child: Semantics(
                      expanded: _expanded,
                      child: TextButton.icon(
                        key: const Key('flexible-missions-toggle'),
                        onPressed: () => setState(() => _expanded = !_expanded),
                        style: TextButton.styleFrom(
                          textStyle: theme.textTheme.labelMedium,
                          minimumSize: const Size(48, 48),
                        ),
                        icon: Icon(
                          _expanded ? Icons.expand_less : Icons.expand_more,
                          size: 18,
                        ),
                        label: Text(
                          _expanded ? '收起' : '展开全部（${widget.items.length}）',
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

// 自选任务行只负责展示与详情入口。
class _FlexibleMissionRow extends StatelessWidget {
  const _FlexibleMissionRow({
    required this.item,
    required this.onTap,
    required this.clock,
  });

  final display.TodayMissionItem item;
  final VoidCallback onTap;
  final DateTime Function() clock;

  @override
  Widget build(BuildContext context) {
    return Padding(
      key: ValueKey('mission-${item.id}'),
      padding: const EdgeInsets.only(bottom: 8),
      child: _MissionDetailLink(
        label: _missionSemanticsLabel(item),
        hint: missionOpenLabel(item.phase),
        onTap: onTap,
        // 留白放在点击容器内部，悬停、按下和键盘焦点的底色都会包住留白。
        // 外层 bottom: 8 只负责行间距，不能替代背景与图标/文字之间的距离。
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              MissionPhaseIcon(phase: item.phase),
              const SizedBox(width: 12),
              Expanded(
                child: _MissionDetails(item: item, compact: true, clock: clock),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// 固定、自选、取消项共用的阅读入口；不改变原行高和时间轴测量。
// InkWell 提供触屏、键盘焦点和 Enter 动作，外层 Semantics 提供完整标题与读屏点击。
class _MissionDetailLink extends StatelessWidget {
  const _MissionDetailLink({
    required this.label,
    required this.hint,
    required this.onTap,
    required this.child,
  });

  final String label;
  final String hint;
  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      excludeSemantics: true,
      label: label,
      hint: hint,
      button: true,
      onTap: onTap,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: child,
        ),
      ),
    );
  }
}

// 自选任务文字已由显示转换函数准备好。
// 这是布局复用，不做类型转换、分组或查询。
class _MissionDetails extends StatelessWidget {
  const _MissionDetails({
    required this.item,
    this.compact = false,
    required this.clock,
  });

  final display.TodayMissionItem item;
  final bool compact;
  final DateTime Function() clock;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          item.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: _todayTitleStyle(context).copyWith(
            // 已取消由分区和状态文字表达，保留可阅读的完整标题。
            color: item.isCancelled ? theme.colorScheme.onSurfaceVariant : null,
            fontWeight: item.isCancelled ? FontWeight.w500 : FontWeight.w600,
          ),
        ),
        SizedBox(height: compact ? 2 : 4),
        Text(item.durationLabel, style: _todayMetadataStyle(context)),
        if (item.events.isNotEmpty)
          MissionLiveStatus(
            phase: item.phase,
            events: item.events,
            includePhase: false,
            clock: clock,
          ),
        if (item.timeZoneLabel != null)
          Text(item.timeZoneLabel!, style: theme.textTheme.bodySmall),
      ],
    );
  }
}

// 自选区空态提示，添加入口保留在区域标题右侧。
class _SectionEmptyHint extends StatelessWidget {
  const _SectionEmptyHint(this.message);

  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(
        message,
        style: _todayMetadataStyle(
          context,
        ).copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
      ),
    );
  }
}

// 焦点只改变留白和高亮，同级任务使用相同字号；系统字体缩放照常生效。
TextStyle _todayTitleStyle(BuildContext context) =>
    Theme.of(context).textTheme.titleMedium!;

TextStyle _todayMetadataStyle(BuildContext context) =>
    Theme.of(context).textTheme.bodyMedium!;

/// 当前查询只有排期事实，概览统计真实安排，不推断完成或执行次数。
class _ScheduleOverview extends StatelessWidget {
  const _ScheduleOverview({required this.missions});
  final display.TodayMissionGroups missions;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final totalMinutes = [
      ...missions.fixed,
      ...missions.flexible,
    ].fold(0, (total, item) => total + item.plannedDurationMinutes);
    final entries = [
      (Icons.event_note_outlined, '${missions.fixed.length}', '固定日程'),
      (Icons.free_breakfast_outlined, '${missions.flexible.length}', '自选任务'),
      (Icons.schedule_outlined, '$totalMinutes', '计划分钟'),
    ];
    return Material(
      color: theme.colorScheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Semantics(
              header: true,
              child: Text('安排概览', style: theme.textTheme.titleMedium),
            ),
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final entry in entries)
                  Expanded(
                    child: Column(
                      children: [
                        Icon(
                          entry.$1,
                          size: 20,
                          color: theme.colorScheme.primary,
                        ),
                        const SizedBox(height: 8),
                        Text(entry.$2, style: theme.textTheme.titleLarge),
                        const SizedBox(height: 4),
                        Text(
                          entry.$3,
                          style: theme.textTheme.bodyMedium,
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';

import '../../application/missions/mission_service.dart';
import '../missions/create_mission_page.dart';
import '../missions/mission_detail_page.dart';
import 'today_display.dart' as display;

// 时间轴布局常量
const _timelineColumnWidth = 32.0;
const _timelineContentGap = 36.0;
const _timelineSegmentGap = 8.0;
const _missionCardHorizontalPadding = 12.0;
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

// 今天页 UI 集中在本文件：页面状态与交互 → 页头 → 两个任务区域 → 任务行与时间轴。
// 日期、分组和显示文字交给 today_display.dart，本文件负责布局及界面交互。
// App 创建一个 MissionService，AppShell 将同一份引用传到这里。
// 本页用 findScheduledOn 读列表，也把同一个服务传给创建页和详情页。
/// 展示所选计划日期的任务，并处理刷新、日期选择和打开创建/详情页。
class TodayPage extends StatefulWidget {
  const TodayPage({
    super.key,
    required this.missionService,
    this.clock = DateTime.now,
  });

  final MissionService missionService;

  /// 默认读取真实时钟；测试可提供可控时刻，不改系统时间或数据库。
  final DateTime Function() clock;

  @override
  State<TodayPage> createState() => _TodayPageState();
}

class _TodayPageState extends State<TodayPage> {
  // 页面只保存四类信息：选了哪天、查到了什么、是否在等、有没有错误。
  late DateTime _selectedDate;
  display.TodayMissionGroups _missions =
      const display.TodayMissionGroups.empty();
  bool _isLoading = false;
  String? _errorText;

  // 快速切换日期时，请求可能乱序返回；只接收最后一次请求的结果。
  int _loadRequest = 0;
  bool _isOpeningCreate = false;
  bool _isOpeningDetail = false;
  bool _isPickingDate = false;

  // 入口一：Flutter 创建 State 后调用一次，默认选择上海日历的今天并读取。
  @override
  void initState() {
    super.initState();
    _selectedDate = DateUtils.dateOnly(display.todayInScheduleTimeZone());
    _loadMissions();
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
      // date 来自本页选择；await 等待 MissionService.findScheduledOn → 仓储 → SQLite。
      final result = await widget.missionService.findScheduledOn(
        scheduledDate: date,
      );
      if (!mounted || request != _loadRequest) return;
      // 一次查询只整理一次：分组、换算时区、准备显示文字，再交给三个区域。
      final missions = display.groupMissionsForDisplay(result);
      setState(() {
        _missions = missions;
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
      date = await showDatePicker(
        context: context,
        initialDate: _selectedDate,
        currentDate: display.todayInScheduleTimeZone(),
        firstDate: DateTime(1),
        lastDate: DateTime(9999, 12, 31),
        helpText: '选择计划日期',
        cancelText: '取消',
        confirmText: '确定',
      );
    } finally {
      _isPickingDate = false;
    }
    if (!mounted || date == null) return;
    await _changeDate(date);
  }

  // 日期选择器和“回到今天”共用：先换日期、清掉旧列表，再走同一次加载过程。
  Future<void> _changeDate(DateTime date) async {
    _selectedDate = DateUtils.dateOnly(date);
    _missions = const display.TodayMissionGroups.empty();
    await _loadMissions();
  }

  // 入口三：加号/空状态按钮打开表单。这里的 await 等待页面关闭，不是等待查库。
  // 关闭表单后再读取一次，所以新增任务可以出现在列表中。
  Future<void> _openCreate() async {
    if (_isOpeningCreate) return;
    _isOpeningCreate = true;
    try {
      await Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (context) => CreateMissionPage(
            missionService: widget.missionService,
            initialScheduledDate: display.scheduleDateKey(_selectedDate),
          ),
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
      await Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (context) => MissionDetailPage(
            missionId: missionId,
            missionService: widget.missionService,
          ),
        ),
      );
    } finally {
      _isOpeningDetail = false;
    }
    // await 等待的是详情页关闭；返回时仍读取原来所选日期，不跳回今天。
    if (!mounted) return;
    await _loadMissions();
  }

  // build 只描述布局：可下拉的列表 = 页头 + 日期返回入口 + 当前列表内容。
  // build 不查询数据库；它只读取上面的状态，由 _buildContent 决定显示哪一种状态。
  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 840),
          child: RefreshIndicator(
            onRefresh: _loadMissions,
            child: ListView(
              key: const Key('today-list'),
              // 即使列表为空或很短，也允许向下拖动，触发上面的 onRefresh。
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.fromLTRB(
                MediaQuery.sizeOf(context).width < 360 ? 16 : 24,
                24,
                MediaQuery.sizeOf(context).width < 360 ? 16 : 24,
                24,
              ),
              children: [
                // 页面顶部：日期文字已经准备好，区域内部只绑定回调、排版。
                _TodayHeader(
                  dateLabel: display.scheduleDateLabel(_selectedDate),
                  isToday: DateUtils.isSameDay(
                    _selectedDate,
                    display.todayInScheduleTimeZone(),
                  ),
                  onPickDate: _pickDate,
                  onCreate: _openCreate,
                  onReturnToday: () =>
                      _changeDate(display.todayInScheduleTimeZone()),
                ),
                const SizedBox(height: 24),
                // 构建元素
                _buildContent(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // build 调用此方法，按状态选择加载/失败/内容；这里不发起任何异步工作。
  Widget _buildContent() {
    // 首次进入或清空重查时还没有任何分区结果，仍整块显示等待或错误提示。
    if (_isLoading && _missions.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 48),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (_errorText != null && _missions.isEmpty) {
      return Column(
        children: [
          Text(_errorText!),
          const SizedBox(height: 8),
          OutlinedButton(onPressed: _loadMissions, child: const Text('重新加载')),
        ],
      );
    }
    // 正常内容沿页面视觉顺序排列。分组由加载过程完成，这里只交付对应列表。
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_errorText != null)
          Row(
            children: [
              Expanded(
                child: Semantics(
                  liveRegion: true,
                  child: const Text('刷新失败，当前显示上次加载的任务'),
                ),
              ),
              TextButton(onPressed: _loadMissions, child: const Text('重试')),
            ],
          ),
        // 两个任务区域常驻：没有数据的一侧保留标题和头部入口，列表位置显示空态提示。
        _FixedMissionSection(
          items: _missions.fixed,
          clock: widget.clock,
          onOpenMission: _openDetail,
        ),
        _FlexibleMissionSection(
          items: _missions.flexible,
          onOpenMission: _openDetail,
        ),
        if (_missions.cancelled.isNotEmpty)
          ExpansionTile(
            key: const Key('cancelled-missions'),
            tilePadding: EdgeInsets.zero,
            title: Text('已取消（${_missions.cancelled.length}）'),
            children: [
              for (final item in _missions.cancelled)
                if (item.isFixed)
                  _FixedMissionRow(
                    item: item,
                    showTimeline: false,
                    onTap: () => _openDetail(item.id),
                  )
                else
                  _FlexibleMissionRow(
                    item: item,
                    onTap: () => _openDetail(item.id),
                  ),
            ],
          ),
      ],
    );
  }
}

// 页面顶部。TodayPage 提供已准备好的日期文字和回调；这里只负责排版。
class _TodayHeader extends StatelessWidget {
  const _TodayHeader({
    required this.dateLabel,
    required this.isToday,
    required this.onPickDate,
    required this.onCreate,
    required this.onReturnToday,
  });

  final String dateLabel;
  final bool isToday;
  final VoidCallback onPickDate;
  final VoidCallback onCreate;
  final VoidCallback onReturnToday;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Semantics(
                    header: true,
                    child: Text('今天', style: theme.textTheme.headlineSmall),
                  ),
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
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: IconButton.filled(
                onPressed: onCreate,
                icon: const Icon(Icons.add),
                tooltip: '创建任务',
                style: IconButton.styleFrom(
                  fixedSize: const Size(48, 48),
                  shape: const CircleBorder(),
                ),
              ),
            ),
          ],
        ),
        if (!isToday)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: onReturnToday,
              child: const Text('回到今天'),
            ),
          ),
      ],
    );
  }
}

// 固定区每秒读取一次真实时钟，仅重画这一块，不重新查询或写入数据。
class _FixedMissionSection extends StatefulWidget {
  const _FixedMissionSection({
    required this.items,
    required this.clock,
    required this.onOpenMission,
  });

  final List<display.TodayMissionItem> items;
  final DateTime Function() clock;
  // 区域只把被点任务的编号交回 TodayPage，不在每一行重复管理路由。
  final ValueChanged<String> onOpenMission;

  @override
  State<_FixedMissionSection> createState() => _FixedMissionSectionState();
}

class _FixedMissionSectionState extends State<_FixedMissionSection>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final ValueNotifier<DateTime> _clock;
  DateTime get _now => _clock.value;
  Timer? _timer;
  late final AnimationController _layoutAnimation;
  double _fromFocus = 0;
  double _toFocus = 0;
  Map<String, double> _fromEmphasis = {};
  Map<String, double> _toEmphasis = {};
  bool _reduceMotion = false;
  bool _isVisible = false;
  bool _isForeground = true;

  @override
  void initState() {
    super.initState();
    _clock = ValueNotifier(widget.clock());
    _isForeground =
        WidgetsBinding.instance.lifecycleState == null ||
        WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;
    _layoutAnimation = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
      value: 1,
    );
    _retargetLayout(animate: false);
    WidgetsBinding.instance.addObserver(this);
  }

  void _startClock() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _readClock());
  }

  void _readClock() {
    final now = widget.clock();
    if (now == _now) return;
    final previous = _now;
    _clock.value = now;
    final layoutChanged = _retargetLayout();
    final reachedNodeChanged = widget.items.any((item) {
      final start = item.fixedStartAt!;
      return previous.isBefore(start) != now.isBefore(start);
    });
    // 稳定时段只通知轨道重绘，文字与测量不随每秒 tick 重建。
    if (layoutChanged || reachedNodeChanged) setState(() {});
  }

  @override
  void didUpdateWidget(covariant _FixedMissionSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    _clock.value = widget.clock();
    // 切日期可能让本区在“空”与“有任务”之间切换：空列表停用每秒时钟，恢复任务后重新启动。
    if (oldWidget.items.isEmpty != widget.items.isEmpty) {
      _syncClock();
    }
    _retargetLayout();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduceMotion = MediaQuery.disableAnimationsOf(context);
    if (_reduceMotion) _layoutAnimation.value = 1;
    final visible = TickerMode.valuesOf(context).enabled;
    if (visible != _isVisible) {
      _isVisible = visible;
      _syncClock();
    }
  }

  void _syncClock() {
    _timer?.cancel();
    _timer = null;
    // 空列表没有时间轴可画：标题和空态提示不需要每秒读取真实时钟。
    if (_isVisible && _isForeground && widget.items.isNotEmpty) {
      // 恢复时直接投影最新系统时间，隐藏期间不累加 tick 或补播过渡。
      _clock.value = widget.clock();
      _retargetLayout(animate: false);
      _startClock();
    } else {
      _layoutAnimation.value = 1;
    }
  }

  // 同一条动画同时驱动焦点、卡片留白、行高及轨道段，避免左右各自伸缩。
  bool _retargetLayout({bool animate = true}) {
    final focus = _timelineFocus(widget.items, _now);
    final targets = {
      for (final item in widget.items)
        item.id: display.isInPlannedTimeSlot(item, _now) ? 1.0 : 0.0,
    };
    final unchanged =
        focus == _toFocus &&
        targets.length == _toEmphasis.length &&
        targets.entries.every((entry) => _toEmphasis[entry.key] == entry.value);
    if (unchanged) return false;
    final t = Curves.easeOutCubic.transform(_layoutAnimation.value);
    _fromFocus = _fromFocus + (_toFocus - _fromFocus) * t;
    _toFocus = focus;
    _fromEmphasis = {
      for (final item in widget.items)
        item.id:
            (_fromEmphasis[item.id] ?? 0) +
            ((_toEmphasis[item.id] ?? 0) - (_fromEmphasis[item.id] ?? 0)) * t,
    };
    _toEmphasis = targets;
    if (animate && !_reduceMotion) {
      _layoutAnimation.forward(from: 0);
    } else {
      _layoutAnimation.value = 1;
    }
    return true;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _isForeground = state == AppLifecycleState.resumed;
    _syncClock();
    if (_isVisible && _isForeground) setState(() {});
  }

  @override
  void dispose() {
    _timer?.cancel();
    _layoutAnimation.dispose();
    WidgetsBinding.instance.removeObserver(this);
    _clock.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Semantics(
                  header: true,
                  child: Text(
                    '计划日程',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
              ),
              // 全部任务范围尚未确定，保留禁用入口。
              TextButton.icon(
                key: const Key('today-all-missions'),
                onPressed: null,
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(0, 32),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  textStyle: Theme.of(context).textTheme.bodyMedium,
                ),
                label: const Text('全部任务'),
                icon: const Icon(Icons.north_east, size: 16),
                iconAlignment: IconAlignment.end,
              ),
            ],
          ),
          const SizedBox(height: 16),
          // 没有固定任务时标题和“全部任务”入口仍显示，列表位置换成空态提示，
          // 不进入每秒刷新的时间轴布局。
          if (widget.items.isEmpty)
            const _SectionEmptyHint('这一天还没有固定任务')
          else
            LayoutBuilder(
              builder: (context, constraints) {
                final items = widget.items;
                final current = [
                  for (final item in items)
                    display.isInPlannedTimeSlot(item, _now),
                ];
                return AnimatedBuilder(
                  animation: _layoutAnimation,
                  builder: (context, child) {
                    final t = Curves.easeOutCubic.transform(
                      _layoutAnimation.value,
                    );
                    final animatedFocus =
                        _fromFocus + (_toFocus - _fromFocus) * t;
                    final emphasis = [
                      for (final item in items)
                        (_fromEmphasis[item.id] ?? 0) +
                            ((_toEmphasis[item.id] ?? 0) -
                                    (_fromEmphasis[item.id] ?? 0)) *
                                t,
                    ];
                    // 焦点向上下两端分别递减，两端最小；重叠激活项都保持最大。
                    final weights = [
                      for (var index = 0; index < items.length; index++)
                        math.max(
                          emphasis[index],
                          _timelineWeight(index, animatedFocus, items.length),
                        ),
                    ];
                    final scales = [
                      for (final weight in weights) 0.75 + 0.25 * weight,
                    ];
                    final layouts = [
                      for (var index = 0; index < items.length; index++)
                        _measureFixedRow(
                          context,
                          constraints.maxWidth,
                          items[index],
                          current[index],
                          scale: scales[index],
                          emphasis: emphasis[index],
                          lensWeight: weights[index],
                        ),
                    ];
                    // 一条任务对应一段轨道，段高直接使用这一帧的卡片高度。
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (var index = 0; index < items.length; index++)
                          _FixedMissionRow(
                            item: items[index],
                            onTap: () => widget.onOpenMission(items[index].id),
                            scale: scales[index],
                            emphasis: emphasis[index],
                            clock: _clock,
                            tilt: MediaQuery.disableAnimationsOf(context)
                                ? 0
                                : ((index - animatedFocus) * 0.018)
                                      .clamp(-0.045, 0.045)
                                      .toDouble(),
                            layout: layouts[index],
                            isCurrent: current[index],
                            hasReachedNext:
                                index < items.length - 1 &&
                                !_now.isBefore(items[index + 1].fixedStartAt!),
                            connectNext: index < items.length - 1,
                            connectPrevious: index > 0,
                          ),
                      ],
                    );
                  },
                );
              },
            ),
        ],
      ),
    );
  }
}

double _timelineWeight(int index, double focus, int count) {
  final distance = (index - focus).abs();
  final extent = index < focus ? focus : count - 1 - focus;
  if (extent <= 0) return 1;
  return math.pow((1 - distance / extent).clamp(0.0, 1.0), 1.2).toDouble();
}

// 重叠时段以其中心为焦点；空档期镜头沿相邻节点缓慢推进。
double _timelineFocus(List<display.TodayMissionItem> items, DateTime now) {
  var total = 0.0;
  var count = 0;
  for (var index = 0; index < items.length; index++) {
    if (display.isInPlannedTimeSlot(items[index], now)) {
      total += index;
      count++;
    }
  }
  if (count > 0) return total / count;
  for (var index = 0; index < items.length - 1; index++) {
    final start = items[index].fixedStartAt!;
    final end = items[index + 1].fixedStartAt!;
    if (!now.isBefore(start) && now.isBefore(end)) {
      return index + display.timelineSegmentProgress(start, end, now);
    }
  }
  return (items.length - 1) / 2;
}

// 排版尺寸只属于 UI。测量与实际 Text 使用相同主题、缩放和宽度，支持大字体。
typedef _FixedRowLayout = ({
  double height,
  double cardHeight,
  double nodeY,
  double timeTop,
  double timeWidth,
  double cardPadding,
  double durationWidth,
  double titleTop,
  double durationTop,
  double timeZoneTop,
  double inlineFraction,
});

_FixedRowLayout _measureFixedRow(
  BuildContext context,
  double width,
  display.TodayMissionItem item,
  bool isCurrent, {
  double scale = 1,
  double? emphasis,
  double? lensWeight,
}) {
  final theme = Theme.of(context);
  final scaler = MediaQuery.textScalerOf(context);
  Size textSize(
    String text,
    TextStyle style,
    double maxWidth, {
    int? maxLines,
  }) {
    final defaults = DefaultTextStyle.of(context);
    var effectiveStyle = defaults.style.merge(style);
    if (MediaQuery.boldTextOf(context)) {
      effectiveStyle = effectiveStyle.merge(
        const TextStyle(fontWeight: FontWeight.bold),
      );
    }
    // 与 Text 的系统无障碍字距、词距和行高覆盖规则保持一致。
    effectiveStyle = effectiveStyle.merge(
      TextStyle(
        height: MediaQuery.maybeLineHeightScaleFactorOverrideOf(context),
        letterSpacing: MediaQuery.maybeLetterSpacingOverrideOf(context),
        wordSpacing: MediaQuery.maybeWordSpacingOverrideOf(context),
      ),
    );
    final painter = TextPainter(
      text: TextSpan(text: text, style: effectiveStyle),
      textDirection: Directionality.of(context),
      textScaler: scaler,
      locale: Localizations.maybeLocaleOf(context),
      textHeightBehavior: defaults.textHeightBehavior,
      maxLines: maxLines,
      ellipsis: maxLines == 1 ? '…' : null,
    )..layout(maxWidth: maxWidth);
    final size = painter.size;
    painter.dispose();
    return size;
  }

  final titleStyle = _todayTitleStyle(context, scale);
  final timeStyle = _todayMetadataStyle(context);
  // 48 是原时间列宽；系统字号放大时为五个等宽数字字符预留更多位置。
  final maxTimeWidth = width / 3;
  final timeWidth = (scaler.scale(12) * 3.5)
      .clamp(math.min(48.0, maxTimeWidth), maxTimeWidth)
      .toDouble();
  final activation = emphasis ?? (isCurrent ? 1.0 : 0.0);
  final detailsExpansion = lensWeight == null ? 1.0 : activation;
  final cardPadding = lensWeight == null
      ? 12.0 * activation
      : 2 + 4 * lensWeight + 6 * activation;
  final textWidth =
      (width -
              timeWidth -
              _timelineContentGap -
              _missionCardHorizontalPadding * 2)
          .clamp(1.0, width)
          .toDouble();
  final titleHeight = textSize(
    item.title,
    titleStyle,
    textWidth,
    maxLines: 1,
  ).height;
  final durationSize = textSize(item.durationLabel, timeStyle, textWidth);
  final durationHeight = durationSize.height;
  final durationWidth = durationSize.width;
  // 过窄或系统大字体时保持两行，让时长可读，不挤掉整条标题。
  final expansion = textWidth - durationWidth - 8 < scaler.scale(64)
      ? 1.0
      : detailsExpansion;
  final verticalExpansion = (expansion * 2).clamp(0.0, 1.0);
  final horizontalExpansion = (expansion * 2 - 1).clamp(0.0, 1.0);
  final firstLineHeight = math.max(titleHeight, durationHeight);
  final timeZoneTop =
      firstLineHeight + (4 + durationHeight) * verticalExpansion;
  var detailsHeight = timeZoneTop + cardPadding * 2;
  if (item.timeZoneLabel != null) {
    detailsHeight += textSize(
      item.timeZoneLabel!,
      theme.textTheme.bodySmall!,
      textWidth,
    ).height;
  }
  final timeHeight = textSize(
    item.startTime,
    timeStyle,
    timeWidth,
    maxLines: 1,
  ).height;
  final timeTop = cardPadding + (firstLineHeight - timeHeight) / 2;
  final timeBottom = timeTop + timeHeight * (isCurrent ? 2 : 1);
  if (timeBottom > detailsHeight) detailsHeight = timeBottom;
  return (
    height: detailsHeight + _timelineSegmentGap,
    cardHeight: detailsHeight,
    nodeY: cardPadding + firstLineHeight / 2,
    timeTop: timeTop < 0 ? 0 : timeTop,
    timeWidth: timeWidth,
    cardPadding: cardPadding,
    durationWidth: durationWidth,
    titleTop: (firstLineHeight - titleHeight) / 2,
    durationTop:
        (firstLineHeight - durationHeight) / 2 * (1 - verticalExpansion) +
        (firstLineHeight + 4) * verticalExpansion,
    timeZoneTop: timeZoneTop,
    inlineFraction: 1 - horizontalExpansion,
  );
}

// 取消折叠区也复用固定行，但不展示时间轴或当前时段高亮。
class _FixedMissionRow extends StatelessWidget {
  const _FixedMissionRow({
    required this.item,
    required this.onTap,
    this.layout,
    this.scale = 1,
    this.emphasis = 0,
    this.clock,
    this.tilt = 0,
    this.showTimeline = true,
    this.isCurrent = false,
    this.hasReachedNext = false,
    this.connectNext = false,
    this.connectPrevious = false,
  }) : assert(!showTimeline || clock != null);

  final display.TodayMissionItem item;
  final VoidCallback onTap;
  final _FixedRowLayout? layout;
  final double scale;
  final double emphasis;
  final ValueListenable<DateTime>? clock;
  final double tilt;
  final bool showTimeline;
  final bool isCurrent;
  final bool hasReachedNext;
  final bool connectNext;
  final bool connectPrevious;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return _MissionDetailLink(
      label: _missionSemanticsLabel(item, isCurrent: isCurrent),
      onTap: onTap,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final measured =
              layout ??
              _measureFixedRow(context, constraints.maxWidth, item, false);
          return SizedBox(
            key: ValueKey('mission-${item.id}'),
            height: measured.height,
            child: Stack(
              children: [
                if (showTimeline)
                  Positioned(
                    left: measured.timeWidth,
                    width: _timelineColumnWidth,
                    top: 0,
                    height: measured.cardHeight,
                    child: IgnorePointer(
                      child: RepaintBoundary(
                        child: CustomPaint(
                          key: ValueKey('timeline-rail-${item.id}'),
                          painter: _TimelinePainter(
                            nodeY: measured.nodeY,
                            clock: clock!,
                            item: item,
                            emphasis: emphasis,
                            connectPrevious: connectPrevious,
                            lineColor: colors.outlineVariant,
                            nodeColor: colors.onSurfaceVariant,
                            progressColor: colors.primary,
                            background: theme.scaffoldBackgroundColor,
                          ),
                        ),
                      ),
                    ),
                  ),
                if (showTimeline && connectNext)
                  Positioned(
                    key: ValueKey('timeline-gap-${item.id}'),
                    left: measured.timeWidth,
                    width: _timelineColumnWidth,
                    top: measured.cardHeight,
                    height: _timelineSegmentGap,
                    child: Center(
                      child: Container(
                        width: hasReachedNext ? 2.5 : 1.5,
                        height: _timelineSegmentGap,
                        color: hasReachedNext
                            ? colors.primary
                            : colors.outlineVariant,
                      ),
                    ),
                  ),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: measured.timeWidth,
                      child: Padding(
                        padding: EdgeInsets.only(top: measured.timeTop),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.startTime,
                              maxLines: 1,
                              style: _todayMetadataStyle(context).copyWith(
                                color: isCurrent
                                    ? colors.primary
                                    : colors.onSurfaceVariant,
                                fontFeatures: const [
                                  FontFeature.tabularFigures(),
                                ],
                              ),
                            ),
                            if (isCurrent)
                              Text(
                                '现在',
                                style: _todayMetadataStyle(context).copyWith(
                                  color: colors.primary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: _timelineContentGap),
                    Expanded(
                      child: Semantics(
                        label: isCurrent ? '当前计划时段' : null,
                        child: SizedBox(
                          height: measured.cardHeight,
                          child: Container(
                            key: ValueKey('schedule-highlight-${item.id}'),
                            padding: EdgeInsets.symmetric(
                              horizontal: _missionCardHorizontalPadding,
                              vertical: measured.cardPadding,
                            ),
                            decoration: BoxDecoration(
                              color: Color.lerp(
                                colors.surface,
                                colors.secondaryContainer,
                                emphasis,
                              ),
                              borderRadius: BorderRadius.circular(18),
                            ),
                            child: Transform(
                              alignment: Alignment.centerLeft,
                              transform: Matrix4.identity()
                                ..setEntry(3, 2, 0.0008)
                                ..rotateX(tilt),
                              child: showTimeline
                                  ? _FixedMissionDetails(
                                      item: item,
                                      layout: measured,
                                      emphasized: isCurrent,
                                      scale: scale,
                                    )
                                  : _MissionDetails(item: item),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

// 非激活项把时长放在标题右侧；激活时同一份文字平滑移到第二行。
class _FixedMissionDetails extends StatelessWidget {
  const _FixedMissionDetails({
    required this.item,
    required this.layout,
    required this.emphasized,
    required this.scale,
  });

  final display.TodayMissionItem item;
  final _FixedRowLayout layout;
  final bool emphasized;
  final double scale;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // 定位和行高都使用测量阶段的同一份结果，避免两套计算发生偏差。
        final inlineWidth = layout.durationWidth + 8;
        return Stack(
          children: [
            Positioned(
              left: 0,
              right: inlineWidth * layout.inlineFraction,
              top: layout.titleTop,
              child: Text(
                item.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: _todayTitleStyle(context, scale),
              ),
            ),
            Positioned(
              left:
                  (constraints.maxWidth - layout.durationWidth) *
                  layout.inlineFraction,
              right: 0,
              top: layout.durationTop,
              child: Text(
                item.durationLabel,
                style: _todayMetadataStyle(context).copyWith(
                  color: emphasized
                      ? Theme.of(context).colorScheme.onSecondaryContainer
                      : null,
                ),
              ),
            ),
            if (item.timeZoneLabel != null)
              Positioned(
                left: 0,
                right: 0,
                top: layout.timeZoneTop,
                child: Text(
                  item.timeZoneLabel!,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
          ],
        );
      },
    );
  }
}

// 灰轨代表计划顺序，绿轨代表时间经过；节点不冒充完成报告或执行事件。
class _TimelinePainter extends CustomPainter {
  _TimelinePainter({
    required this.nodeY,
    required this.clock,
    required this.item,
    required this.emphasis,
    required this.connectPrevious,
    required this.lineColor,
    required this.nodeColor,
    required this.progressColor,
    required this.background,
  }) : super(repaint: clock);

  final double nodeY;
  final ValueListenable<DateTime> clock;
  final display.TodayMissionItem item;
  final double emphasis;
  final bool connectPrevious;
  final Color lineColor;
  final Color nodeColor;
  final Color progressColor;
  final Color background;

  @override
  void paint(Canvas canvas, Size size) {
    final x = size.width / 2;
    final center = Offset(x, nodeY);
    final hasReachedStart = !clock.value.isBefore(item.fixedStartAt!);
    final progress = display.plannedTimeSlotProgress(item, clock.value);
    // 首项从圆点起笔，其余从段顶部接续；布局段仍与卡片等高。
    final lineStart = Offset(x, connectPrevious ? 0 : nodeY);
    canvas.drawLine(
      lineStart,
      Offset(x, size.height),
      Paint()
        ..color = Color.lerp(
          lineColor,
          progressColor.withValues(alpha: 0.35),
          emphasis,
        )!
        ..strokeWidth = 1.5 + emphasis,
    );
    if (hasReachedStart) {
      canvas.drawLine(
        lineStart,
        // 到点时先接通标题节点，再在本项剩余高度内推进，避免绿色节点悬空。
        Offset(x, nodeY + (size.height - nodeY) * progress),
        Paint()
          ..color = progressColor
          ..strokeWidth = 2.5,
      );
    }
    final radius = 4.5 + emphasis;
    canvas.drawCircle(
      center,
      radius,
      Paint()..color = hasReachedStart ? progressColor : background,
    );
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = hasReachedStart ? progressColor : nodeColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4,
    );
  }

  @override
  bool shouldRepaint(covariant _TimelinePainter old) =>
      nodeY != old.nodeY ||
      clock != old.clock ||
      item != old.item ||
      emphasis != old.emphasis ||
      connectPrevious != old.connectPrevious ||
      lineColor != old.lineColor ||
      nodeColor != old.nodeColor ||
      progressColor != old.progressColor ||
      background != old.background;
}

// 自选时间区域。只接收自选任务列表，不判断时间策略或重新分组。
class _FlexibleMissionSection extends StatefulWidget {
  const _FlexibleMissionSection({
    required this.items,
    required this.onOpenMission,
  });

  final List<display.TodayMissionItem> items;
  final ValueChanged<String> onOpenMission;

  @override
  State<_FlexibleMissionSection> createState() =>
      _FlexibleMissionSectionState();
}

class _FlexibleMissionSectionState extends State<_FlexibleMissionSection> {
  static const _previewCount = 3;
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // 折叠只影响排版，完整数据仍由 widget.items 提供，不再查询或转换。
    final hasMore = widget.items.length > _previewCount;
    final visibleItems = _expanded
        ? widget.items
        : widget.items.take(_previewCount);
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            header: true,
            child: Text(
              '自选时间',
              style: theme.textTheme.titleLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(height: 16),
          // 没有自选任务时同样保留标题，用一行提示占位；有任务才渲染行和展开入口。
          if (widget.items.isEmpty)
            const _SectionEmptyHint('这一天还没有自选任务')
          else ...[
            for (final item in visibleItems)
              _FlexibleMissionRow(
                item: item,
                onTap: () => widget.onOpenMission(item.id),
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
                        textStyle: _todayMetadataStyle(context),
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
    );
  }
}

// 同一套行布局也用于取消折叠区，避免复制图标和文字排版。
class _FlexibleMissionRow extends StatelessWidget {
  const _FlexibleMissionRow({required this.item, required this.onTap});

  final display.TodayMissionItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      key: ValueKey('mission-${item.id}'),
      padding: const EdgeInsets.only(bottom: 8),
      child: _MissionDetailLink(
        label: _missionSemanticsLabel(item),
        onTap: onTap,
        // 留白放在点击容器内部，悬停、按下和键盘焦点的底色都会包住留白。
        // 外层 bottom: 8 只负责行间距，不能替代背景与图标/文字之间的距离。
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(
                width: 48,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: colors.primaryContainer,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.description_outlined,
                      size: 20,
                      color: colors.primary,
                    ),
                  ),
                ),
              ),
              Expanded(child: _MissionDetails(item: item, compact: true)),
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
    required this.onTap,
    required this.child,
  });

  final String label;
  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      excludeSemantics: true,
      label: label,
      hint: '查看任务详情',
      button: true,
      onTap: onTap,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onTap,
          excludeFromSemantics: true,
          borderRadius: BorderRadius.circular(18),
          child: child,
        ),
      ),
    );
  }
}

// 自选和取消行共用的文字排版。文字已经由显示转换函数准备好。
// 这是布局复用，不做类型转换、分组或查询。
class _MissionDetails extends StatelessWidget {
  const _MissionDetails({required this.item, this.compact = false});

  final display.TodayMissionItem item;
  final bool compact;

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
          style: _todayTitleStyle(context, 1).copyWith(
            fontSize: compact ? 14 : 16,
            height: compact ? 20 / 14 : 22 / 16,
            decoration: item.isCancelled ? TextDecoration.lineThrough : null,
          ),
        ),
        SizedBox(height: compact ? 2 : 4),
        Text(item.durationLabel, style: _todayMetadataStyle(context)),
        if (item.timeZoneLabel != null)
          Text(item.timeZoneLabel!, style: theme.textTheme.bodySmall),
      ],
    );
  }
}

// 两个任务区域共用的空态提示行。区域标题常驻，列表为空时用它说明；
// 创建入口统一是页头加号，这里不重复放按钮，也不提供其他交互。
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

// 今天页使用紧凑字号；固定行从两端 12 到焦点 16，系统字体缩放照常生效。
TextStyle _todayTitleStyle(BuildContext context, double scale) => Theme.of(
  context,
).textTheme.titleMedium!.copyWith(fontSize: 16 * scale, height: 22 / 16);

TextStyle _todayMetadataStyle(BuildContext context) => Theme.of(
  context,
).textTheme.bodyMedium!.copyWith(fontSize: 12, height: 18 / 12);

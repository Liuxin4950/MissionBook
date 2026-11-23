import '../widgets/app_animated_size.dart';
import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'empty_schedule.dart';
import '../widgets/app_section_card.dart';
import 'package:timezone/timezone.dart' as tz;

import 'today_display.dart' as display;
import '../../domain/entities/mission_schedule_revision.dart';
import '../missions/shared/mission_phase_display.dart';
import '../missions/shared/mission_live_status.dart';
import '../widgets/app_visibility.dart';
import '../../core/theme/app_layout.dart';
import '../../core/theme/app_motion.dart';
import '../../core/theme/colors.dart';

// 今天页一套内容边线：页头、日期带和各分区外框共用页面左右边距；
// 同一列的分区内部再按自身宽度取同一级内边距，避免相邻卡片起始文字不齐。
/// 宽面板（高/中密度）16dp，窄栏 12dp；与「计划日程 / 自选时间 / 安排概览」同级。
double todaySectionInset(double availableWidth) =>
    availableWidth >= _wideListMinWidth ? AppLayout.spaceLg : AppLayout.spaceMd;

/// 宽列表样式条件：计划卡内可用宽度 480dp，且按实际文字量完槽后标题仍有约 160dp。
const _wideListMinWidth = 480.0;
const _wideTitleSlotMin = 160.0;

// 任务行内部的固定槽位：轨道 16dp、末端箭头 20dp；正文槽吸收剩余空间。
const _trackWidth = 16.0;
const _arrowSlotWidth = 20.0;
const _nodeSize = 9.0;
const _timelineEndInset = 12.0;

// 宽列表按系统字号量槽时使用的固定样本：23:59、四位时长和最长状态。
const _timeSample = '23:59';
const _longDurationSample = '$maxPlannedDurationMinutes 分钟';
const _statusSamples = [
  '当前时段',
  '时段已过',
  '待到时',
  '已取消',
  '待开始',
  '执行中',
  '已暂停',
  '待确认',
  '已结束',
  '待补材料',
  '待处理',
];
const _focusSample = '00:00';

// 等宽数字只在平台上可用时生效，缺字体时继续使用系统默认字形。
const _tabularFigures = [FontFeature.tabularFigures()];

/// 首页窗口和当日完整列表共用一份日程布局；时钟只影响展示，不写执行事实。
class ScheduleSection extends StatefulWidget {
  const ScheduleSection({
    super.key,
    required this.items,
    required this.selectedDate,
    required this.clock,
    required this.onOpenMission,
    this.onOpenAll,
    this.onCreate,
    this.fullList = false,
    this.illustrateEmpty = true,
    this.visibleHeight,
  });

  final List<display.TodayMissionItem> items;
  final DateTime selectedDate;
  final DateTime Function() clock;
  final ValueChanged<String> onOpenMission;
  final VoidCallback? onOpenAll;
  final VoidCallback? onCreate;
  final bool fullList;
  // 只有整天无安排时才放插画，避免固定区空态挤走真实自选任务。
  final bool illustrateEmpty;

  /// 页面滚动视口的实际高度；首页据此按可见高度决定 2–4 项，不随栏宽拉伸。
  final double? visibleHeight;

  @override
  State<ScheduleSection> createState() => _ScheduleSectionState();
}

class _ScheduleSectionState extends State<ScheduleSection>
    with WidgetsBindingObserver {
  late DateTime _now;
  Timer? _timer;
  bool _visible = false;
  bool _appVisible = true;
  int _page = 0;

  @override
  void initState() {
    super.initState();
    _now = widget.clock();
    _appVisible = isAppVisible(WidgetsBinding.instance.lifecycleState);
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _visible = TickerMode.valuesOf(context).enabled;
    _syncClock();
  }

  @override
  void didUpdateWidget(covariant ScheduleSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    final last = widget.items.isEmpty ? 0 : (widget.items.length - 1) ~/ 50;
    if (_page > last ||
        !DateUtils.isSameDay(oldWidget.selectedDate, widget.selectedDate)) {
      _page = 0;
    }
    _syncClock();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _appVisible = isAppVisible(state);
    _syncClock();
    if (mounted) setState(() {});
  }

  void _syncClock() {
    if (!_visible || !_appVisible || widget.items.isEmpty) {
      _timer?.cancel();
      _timer = null;
      return;
    }
    _now = widget.clock();
    _timer ??= Timer.periodic(const Duration(seconds: 1), (_) {
      final next = widget.clock();
      // 分钟文案或时段边界改变才重建，稳定时段不反复测量所有文字。
      final changed =
          next.millisecondsSinceEpoch ~/ 60000 !=
              _now.millisecondsSinceEpoch ~/ 60000 ||
          widget.items.any(
            (item) =>
                display.isInPlannedTimeSlot(item, next) !=
                display.isInPlannedTimeSlot(item, _now),
          );
      if (changed) setState(() => _now = next);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// 首页按实际可见高度和当前字号量出的行高决定 2–4 项；完整列表不使用窗口。
  int _previewLimit(ThemeData theme) {
    final scaler = MediaQuery.textScalerOf(context);
    final titleHeight = _lineHeight(theme.textTheme.labelSmall, scaler);
    final metaHeight = _lineHeight(theme.textTheme.bodySmall, scaler);
    final rowExtent =
        titleHeight + metaHeight + AppLayout.spaceSm * 2 + AppLayout.strokeThin;
    final visibleHeight =
        widget.visibleHeight ?? MediaQuery.sizeOf(context).height;
    return ((visibleHeight * .4 - 96) / rowExtent).floor().clamp(2, 4);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final local = tz.TZDateTime.from(
      _now,
      tz.getLocation(defaultScheduleTimeZone),
    );
    return LayoutBuilder(
      builder: (context, box) {
        final inset = todaySectionInset(box.maxWidth);
        final preview = widget.fullList
            ? widget.items.skip(_page * 50).take(50).toList()
            : display.schedulePreview(
                widget.items,
                _now,
                limit: _previewLimit(theme),
              );
        final items = preview;
        final hidden = widget.fullList ? 0 : widget.items.length - items.length;
        return AppSectionCard(
          key: const Key('today-schedule-section'),
          padding: EdgeInsets.fromLTRB(
            inset,
            AppLayout.spaceMd,
            inset,
            AppLayout.spaceMd,
          ),
          paperBackground: widget.illustrateEmpty && items.isEmpty,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Wrap(
                      spacing: AppLayout.spaceSm,
                      runSpacing: AppLayout.spaceXs,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        if (!widget.fullList)
                          Semantics(
                            header: true,
                            child: Text(
                              '计划日程',
                              style: theme.textTheme.labelLarge,
                            ),
                          ),
                        Text(
                          '共 ${widget.items.length} 项',
                          style: theme.textTheme.bodySmall,
                        ),
                        if (widget.items.isNotEmpty &&
                            DateUtils.isSameDay(local, widget.selectedDate))
                          Wrap(
                            key: const Key('timeline-current-time'),
                            spacing: AppLayout.spaceXs,
                            runSpacing: AppLayout.spaceXs,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Text('现在', style: theme.textTheme.bodySmall),
                              Text(
                                '${local.hour.toString().padLeft(2, '0')}:'
                                '${local.minute.toString().padLeft(2, '0')}',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  fontFeatures: _tabularFigures,
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                  if (!widget.fullList && widget.items.isNotEmpty)
                    TextButton(
                      key: const Key('today-all-missions'),
                      onPressed: widget.onOpenAll,
                      style: TextButton.styleFrom(
                        textStyle: theme.textTheme.labelSmall,
                        padding: EdgeInsets.zero,
                        minimumSize: const Size(0, AppLayout.touchTargetMin),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: const Text('查看全部 ›'),
                    ),
                ],
              ),
              if (items.isEmpty)
                EmptySchedule(
                  illustrate: widget.illustrateEmpty,
                  onCreate: widget.onCreate,
                )
              else
                AppAnimatedSize(
                  duration: _motionDuration(context),
                  curve: AppMotion.curve,
                  alignment: Alignment.topCenter,
                  child: Column(
                    children: [
                      for (var index = 0; index < items.length; index++) ...[
                        // 普通行保持开放底面，用一条细分隔连起来，不再每条加卡片。
                        if (index > 0)
                          Divider(
                            height: AppLayout.strokeThin,
                            thickness: AppLayout.strokeThin,
                            color: colors.outlineVariant,
                          ),
                        Column(
                          key: ValueKey('schedule-row-${items[index].id}'),
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            ScheduleMissionRow(
                              key: ValueKey('mission-${items[index].id}'),
                              item: items[index],
                              now: _now,
                              clock: widget.clock,
                              isFirst: index == 0,
                              isLast: index == items.length - 1,
                              showFullTitle: widget.fullList,
                              onTap: () =>
                                  widget.onOpenMission(items[index].id),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              if (widget.fullList && widget.items.length > 50)
                Wrap(
                  spacing: AppLayout.spaceSm,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    TextButton(
                      onPressed: _page == 0
                          ? null
                          : () => setState(() => _page--),
                      child: const Text('上一页日程'),
                    ),
                    Text('每页 50 项，共 ${widget.items.length} 项'),
                    TextButton(
                      onPressed: (_page + 1) * 50 >= widget.items.length
                          ? null
                          : () => setState(() => _page++),
                      child: const Text('下一页日程'),
                    ),
                  ],
                ),
              // 首页只留一条短计数，不再重复卡头已经给出的“查看全部”。
              if (hidden > 0)
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: TextButton(
                    key: const Key('schedule-more'),
                    onPressed: widget.onOpenAll,
                    style: TextButton.styleFrom(
                      textStyle: theme.textTheme.labelSmall,
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppLayout.spaceSm,
                      ),
                      minimumSize: const Size(0, AppLayout.touchTargetMin),
                    ),
                    child: Text('另有 $hidden 项'),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

Duration _motionDuration(BuildContext context) =>
    AppMotion.resolve(context, AppMotion.standard);

/// 文字行高按当前系统字号换算；不测量业务内容，只用文字角色。
double _lineHeight(TextStyle? style, TextScaler scaler) {
  if (style == null) return 0;
  return scaler.scale(style.fontSize ?? 12) * (style.height ?? 1);
}

/// 用同一文字角色量一个固定样本的宽度；宽列表只量槽位样本，不按任务逐条改列宽。
double _measureText(
  String text,
  TextStyle style,
  TextScaler scaler,
  TextDirection direction,
) {
  final painter = TextPainter(
    text: TextSpan(text: text, style: style),
    textDirection: direction,
    textScaler: scaler,
    maxLines: 1,
  )..layout();
  final width = painter.width;
  painter.dispose();
  return width;
}

/// 宽列表的共同列基准；同一列所有行用同一份测量结果，箭头与状态才会共线。
class _RowMetrics {
  const _RowMetrics({
    required this.wide,
    required this.timeWidth,
    required this.statusWidth,
    required this.trackCenter,
    required this.arrowTop,
  });

  final bool wide;
  final double timeWidth;
  final double statusWidth;

  /// 轨道中心相对行起点的位置；竖线与节点都对准这里。
  final double trackCenter;

  /// 末端箭头在首行文字内的垂直偏移，让图标与标题中线对齐。
  final double arrowTop;
}

_RowMetrics _rowMetrics({
  required double availableWidth,
  required TextStyle titleStyle,
  required TextStyle metaStyle,
  required TextScaler scaler,
  required TextDirection direction,
}) {
  final titleLineHeight = _lineHeight(titleStyle, scaler);
  final arrowTop = math.max(0.0, (titleLineHeight - AppLayout.iconMd) / 2);
  // 窄列表只有轨道与箭头是固定槽，够不到 480dp 时不再量其他列。
  if (availableWidth < _wideListMinWidth) {
    return _RowMetrics(
      wide: false,
      timeWidth: 0,
      statusWidth: 0,
      trackCenter: _trackWidth / 2,
      arrowTop: arrowTop,
    );
  }
  // 量槽使用和渲染同一份文字样式（含等宽数字），槽宽不会因字形切换而变窄。
  final measureStyle = metaStyle.copyWith(fontFeatures: _tabularFigures);
  final timeWidth = math.max(
    _measureText(_timeSample, measureStyle, scaler, direction),
    _measureText(_longDurationSample, measureStyle, scaler, direction),
  );
  var statusWidth = _measureText(_focusSample, measureStyle, scaler, direction);
  for (final sample in _statusSamples) {
    statusWidth = math.max(
      statusWidth,
      _measureText(sample, measureStyle, scaler, direction),
    );
  }
  final fixed =
      timeWidth +
      _timeToTrack +
      _trackWidth +
      _trackToMain +
      _mainToStatus +
      statusWidth +
      _statusToArrow +
      _arrowSlotWidth;
  final wide =
      availableWidth >= _wideListMinWidth &&
      availableWidth - fixed >= _wideTitleSlotMin;
  if (!wide) {
    return _RowMetrics(
      wide: false,
      timeWidth: timeWidth,
      statusWidth: statusWidth,
      trackCenter: _trackWidth / 2,
      arrowTop: arrowTop,
    );
  }
  return _RowMetrics(
    wide: true,
    timeWidth: timeWidth,
    statusWidth: statusWidth,
    trackCenter: timeWidth + _timeToTrack + _trackWidth / 2,
    arrowTop: arrowTop,
  );
}

// 宽列表列间距：时间栏与轨道之间留白，正文槽吸收剩余，状态与箭头贴末端。
const _timeToTrack = AppLayout.spaceSm;
const _trackToMain = AppLayout.spaceSm;
const _mainToStatus = AppLayout.spaceMd;
const _statusToArrow = AppLayout.spaceXs;

/// 用自然布局连接节点，不测量业务文字、不按分钟拉伸行高。
/// 计划卡内够宽时排成时间/轨道/正文/状态/箭头五段，否则退回同一行的纵向布局。
class ScheduleMissionRow extends StatelessWidget {
  const ScheduleMissionRow({
    super.key,
    required this.item,
    required this.now,
    required this.onTap,
    this.isFirst = true,
    this.isLast = true,
    this.showFullTitle = false,
    this.clock = DateTime.now,
  });

  final display.TodayMissionItem item;
  final DateTime now;
  final DateTime Function() clock;
  final VoidCallback onTap;
  final bool isFirst;
  final bool isLast;

  /// 首页标题最多两行；完整日程展开标题，辅助信息自然换行。
  final bool showFullTitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final titleStyle = theme.textTheme.labelSmall!;
    final metaStyle = theme.textTheme.bodySmall!;
    final scaler = MediaQuery.textScalerOf(context);
    final direction = Directionality.of(context);
    final current = display.isInPlannedTimeSlot(item, now);
    final progress = display.plannedTimeSlotProgress(item, now);
    // 计划进度只属于有固定计划时段的任务：自选/取消任务没有可度量的时段。
    final showPlanProgress =
        item.isFixed &&
        !item.isCancelled &&
        item.fixedStartAt != null &&
        item.plannedDurationMinutes > 0;
    final remainingMinutes = display.plannedTimeSlotRemainingMinutes(item, now);
    // 计划时段只是排期；有执行事实后优先呈现真实执行阶段。
    final status = display.scheduleRowStatus(item, now);
    final label = [
      item.startTime,
      item.title,
      '计划 ${item.plannedDurationMinutes} 分钟',
      if (item.timeZoneLabel != null) item.timeZoneLabel!,
      status,
      if (current) '计划时段剩余 $remainingMinutes 分钟',
    ].join('，');
    final titleLineHeight = _lineHeight(titleStyle, scaler);
    final verticalPadding = AppLayout.spaceSm;
    final nodeCenterY = verticalPadding + titleLineHeight / 2;
    return LayoutBuilder(
      builder: (context, box) {
        final metrics = _rowMetrics(
          availableWidth: box.maxWidth,
          titleStyle: titleStyle,
          metaStyle: metaStyle,
          scaler: scaler,
          direction: direction,
        );
        final content = metrics.wide
            ? _wideContent(
                context,
                colors: colors,
                titleStyle: titleStyle,
                metaStyle: metaStyle,
                status: status,
                current: current,
                progress: progress,
                remainingMinutes: remainingMinutes,
                showPlanProgress: showPlanProgress,
                metrics: metrics,
              )
            : _narrowContent(
                context,
                colors: colors,
                titleStyle: titleStyle,
                metaStyle: metaStyle,
                status: status,
                current: current,
                progress: progress,
                remainingMinutes: remainingMinutes,
                showPlanProgress: showPlanProgress,
                metrics: metrics,
              );
        return Semantics(
          container: true,
          excludeSemantics: true,
          button: true,
          label: label,
          hint: missionOpenLabel(item.phase),
          onTap: onTap,
          child: AnimatedContainer(
            key: ValueKey('schedule-surface-${item.id}'),
            duration: _motionDuration(context),
            curve: AppMotion.curve,
            decoration: BoxDecoration(
              // 当前计划时段用一块浅强调面表达，不与真实执行阶段共用一个绿色。
              color: current ? AppColors.accentSoft : Colors.transparent,
              borderRadius: BorderRadius.circular(AppLayout.radiusMd),
            ),
            child: Material(
              type: MaterialType.transparency,
              child: InkWell(
                onTap: onTap,
                excludeFromSemantics: true,
                borderRadius: BorderRadius.circular(AppLayout.radiusMd),
                child: ConstrainedBox(
                  // 整行实际点击高度不低于 48；行高仍由内容自然增长。
                  constraints: const BoxConstraints(
                    minHeight: AppLayout.touchTargetMin,
                  ),
                  child: Stack(
                    alignment: AlignmentDirectional.topStart,
                    children: [
                      PositionedDirectional(
                        start: metrics.trackCenter - AppLayout.strokeThin / 2,
                        // 首尾只收进边缘留白，单项也保留穿过节点的竖线。
                        // 中间行连到边界，随内容自然增高，连接处没有间隙。
                        top: isFirst ? _timelineEndInset : 0,
                        bottom: isLast ? _timelineEndInset : 0,
                        child: Container(
                          width: AppLayout.strokeThin,
                          color: current
                              ? colors.primary.withValues(alpha: .35)
                              : colors.outlineVariant,
                        ),
                      ),
                      PositionedDirectional(
                        start: metrics.trackCenter - _nodeSize / 2,
                        top: nodeCenterY - _nodeSize / 2,
                        child: Container(
                          key: ValueKey('schedule-node-${item.id}'),
                          width: _nodeSize,
                          height: _nodeSize,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: current
                                ? colors.primary
                                : colors.surfaceContainerLow,
                            border: Border.all(
                              color: current ? colors.primary : colors.outline,
                            ),
                            // 轨道标记：当前时段的节点加一层浅色光晕。
                            boxShadow: current
                                ? [
                                    BoxShadow(
                                      color: colors.primary.withValues(
                                        alpha: .18,
                                      ),
                                      spreadRadius: 3,
                                    ),
                                  ]
                                : null,
                          ),
                        ),
                      ),
                      Padding(
                        padding: EdgeInsets.symmetric(
                          vertical: verticalPadding,
                        ),
                        child: content,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  /// 宽列表：时间/计划分钟两行、轨道、正文槽、真实阶段/专注列、箭头各占一列。
  Widget _wideContent(
    BuildContext context, {
    required ColorScheme colors,
    required TextStyle titleStyle,
    required TextStyle metaStyle,
    required String status,
    required bool current,
    required double progress,
    required int remainingMinutes,
    required bool showPlanProgress,
    required _RowMetrics metrics,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: metrics.timeWidth,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                item.startTime,
                key: ValueKey('schedule-time-${item.id}'),
                style: metaStyle.copyWith(fontFeatures: _tabularFigures),
              ),
              const SizedBox(height: AppLayout.spaceXs),
              Text(
                item.plannedDurationLabel,
                key: ValueKey('schedule-duration-${item.id}'),
                style: metaStyle.copyWith(fontFeatures: _tabularFigures),
              ),
            ],
          ),
        ),
        const SizedBox(width: _timeToTrack),
        // 轨道槽只占宽；竖线与节点由外层 Stack 按同一中心绘制。
        const SizedBox(width: _trackWidth),
        const SizedBox(width: _trackToMain),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                item.title,
                key: ValueKey('schedule-title-${item.id}'),
                maxLines: showFullTitle ? null : 2,
                overflow: showFullTitle
                    ? TextOverflow.visible
                    : TextOverflow.ellipsis,
                style: titleStyle,
              ),
              if (item.timeZoneLabel != null) ...[
                const SizedBox(height: AppLayout.spaceXs),
                Text(
                  item.timeZoneLabel!,
                  key: ValueKey('schedule-timezone-${item.id}'),
                  style: metaStyle,
                ),
              ],
              if (showPlanProgress) ...[
                const SizedBox(height: AppLayout.spaceXs),
                _PlanProgress(
                  id: item.id,
                  progress: progress,
                  remainingMinutes: remainingMinutes,
                  current: current,
                  style: metaStyle,
                ),
              ],
            ],
          ),
        ),
        const SizedBox(width: _mainToStatus),
        SizedBox(
          width: metrics.statusWidth,
          child: Column(
            // 文字用 TextAlign.end 对齐末端，RTL 时自动镜像。
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                status,
                key: ValueKey('schedule-status-${item.id}'),
                textAlign: TextAlign.end,
                style: metaStyle.copyWith(fontFeatures: _tabularFigures),
              ),
              if (item.events.isNotEmpty) ...[
                const SizedBox(height: AppLayout.spaceXs),
                Align(
                  alignment: AlignmentDirectional.centerEnd,
                  child: _liveStatus(),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(width: _statusToArrow),
        Padding(
          padding: EdgeInsets.only(top: metrics.arrowTop),
          child: _arrow(colors),
        ),
      ],
    );
  }

  /// 窄列表：同一个任务项纵向布局，标题优先，时间/计划分钟与阶段/专注顺序换行。
  Widget _narrowContent(
    BuildContext context, {
    required ColorScheme colors,
    required TextStyle titleStyle,
    required TextStyle metaStyle,
    required String status,
    required bool current,
    required double progress,
    required int remainingMinutes,
    required bool showPlanProgress,
    required _RowMetrics metrics,
  }) {
    final metadata = item.startTime.isEmpty
        ? item.plannedDurationLabel
        : '${item.startTime} · ${item.plannedDurationLabel}';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(width: _trackWidth),
            Expanded(
              child: Text(
                item.title,
                key: ValueKey('schedule-title-${item.id}'),
                maxLines: showFullTitle ? null : 2,
                overflow: showFullTitle
                    ? TextOverflow.visible
                    : TextOverflow.ellipsis,
                style: titleStyle,
              ),
            ),
            const SizedBox(width: AppLayout.spaceXs),
            Padding(
              padding: EdgeInsets.only(top: metrics.arrowTop),
              child: _arrow(colors),
            ),
          ],
        ),
        const SizedBox(height: AppLayout.spaceXs),
        Padding(
          padding: const EdgeInsetsDirectional.only(
            start: _trackWidth + AppLayout.spaceSm,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Wrap(
                spacing: AppLayout.spaceMd,
                runSpacing: AppLayout.spaceXs,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    metadata,
                    key: ValueKey('schedule-meta-${item.id}'),
                    style: metaStyle.copyWith(fontFeatures: _tabularFigures),
                  ),
                  Text(
                    status,
                    key: ValueKey('schedule-status-${item.id}'),
                    style: metaStyle.copyWith(fontFeatures: _tabularFigures),
                  ),
                  if (item.events.isNotEmpty) _liveStatus(),
                ],
              ),
              if (item.timeZoneLabel != null) ...[
                const SizedBox(height: AppLayout.spaceXs),
                Text(
                  item.timeZoneLabel!,
                  key: ValueKey('schedule-timezone-${item.id}'),
                  style: metaStyle,
                ),
              ],
              if (showPlanProgress) ...[
                const SizedBox(height: AppLayout.spaceSm),
                _PlanProgress(
                  id: item.id,
                  progress: progress,
                  remainingMinutes: remainingMinutes,
                  current: current,
                  style: metaStyle,
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  /// 专注时长仍由 MissionLiveStatus 用真实执行事件计算，只省略重复的阶段前缀。
  Widget _liveStatus() => MissionLiveStatus(
    phase: item.phase,
    events: item.events,
    schedule: item.schedule,
    clock: clock,
    includePhase: false,
    includeFocusLabel: false,
  );

  Widget _arrow(ColorScheme colors) => SizedBox(
    key: ValueKey('schedule-open-${item.id}'),
    width: _arrowSlotWidth,
    height: AppLayout.iconMd,
    child: Icon(
      Icons.chevron_right_rounded,
      size: AppLayout.iconMd,
      color: colors.onSurfaceVariant,
    ),
  );
}

/// 计划进度条与剩余分钟：两者都在正文槽内，剩余分钟另起一行，不和时间抢宽。
class _PlanProgress extends StatelessWidget {
  const _PlanProgress({
    required this.id,
    required this.progress,
    required this.remainingMinutes,
    required this.current,
    required this.style,
  });

  final String id;
  final double progress;
  final int remainingMinutes;

  /// 当前计划时段才写“剩余 N 分钟”；其它行只保留进度轨，避免每行堆文字。
  final bool current;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        TweenAnimationBuilder<double>(
          tween: Tween(end: progress),
          duration: _motionDuration(context),
          builder: (context, value, _) => LinearProgressIndicator(
            key: ValueKey('schedule-plan-progress-$id'),
            value: value,
            minHeight: AppLayout.spaceXs,
            borderRadius: BorderRadius.circular(AppLayout.radiusXs),
            color: current
                ? AppColors.primary
                : AppColors.primary.withValues(alpha: .45),
            backgroundColor: colors.primary.withValues(alpha: .08),
          ),
        ),
        if (current) ...[
          const SizedBox(height: AppLayout.spaceXs),
          Text(
            '计划时段剩余 $remainingMinutes 分钟',
            key: ValueKey('schedule-plan-remaining-$id'),
            style: style.copyWith(fontFeatures: _tabularFigures),
          ),
        ],
      ],
    );
  }
}

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/theme/app_layout.dart';
import '../../core/theme/app_motion.dart';
import '../../domain/entities/mission_phase.dart';
import '../missions/shared/mission_phase_display.dart';
import '../widgets/app_animated_size.dart';
import '../widgets/app_section_card.dart';
import '../widgets/app_visibility.dart';
import 'empty_schedule.dart';
import 'today_display.dart' as display;

// 今天页一套内容边线：页头、日期带和各分区外框共用页面左右边距；
// 同一列的分区内部再按自身宽度取同一级内边距，避免相邻卡片起始文字不齐。
/// 宽面板（高/中密度）16dp，窄栏 12dp；首页分区共用内容边线。
double todaySectionInset(double availableWidth) =>
    availableWidth >= _widePanelMinWidth
    ? AppLayout.spaceLg
    : AppLayout.spaceMd;

// 断点只影响分区的内边距，任务行在同一信息层级下按文字实际宽度换行。
const _widePanelMinWidth = 480.0;
const _trackWidth = AppLayout.spaceLg;
const _nodeSize = AppLayout.spaceSm;
const _terminalTrackInset = AppLayout.spaceMd;
const _minProgressTrackWidth = AppLayout.space3Xl * 2;

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
    final titleHeight = _lineHeight(theme.textTheme.titleSmall, scaler);
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
                              style: theme.textTheme.titleMedium,
                            ),
                          ),
                        Text(
                          '共 ${widget.items.length} 项',
                          style: theme.textTheme.bodySmall,
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
              else ...[
                const SizedBox(height: AppLayout.spaceXs),
                AppAnimatedSize(
                  duration: _motionDuration(context),
                  curve: AppMotion.curve,
                  alignment: Alignment.topCenter,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (var index = 0; index < items.length; index++)
                        ScheduleMissionRow(
                          key: ValueKey('mission-${items[index].id}'),
                          item: items[index],
                          now: _now,
                          isFirst: index == 0,
                          isLast: index == items.length - 1,
                          showFullTitle: widget.fullList,
                          onTap: () => widget.onOpenMission(items[index].id),
                        ),
                    ],
                  ),
                ),
              ],
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

/// 以实际字号测量单行标签，空间不足时移动整组，而不是缩字或截断状态。
double _singleLineWidth(BuildContext context, String text, TextStyle style) {
  final painter = TextPainter(
    text: TextSpan(text: text, style: style),
    textDirection: Directionality.of(context),
    textScaler: MediaQuery.textScalerOf(context),
    locale: Localizations.maybeLocaleOf(context),
    maxLines: 1,
  )..layout();
  final width = painter.width.ceilToDouble();
  painter.dispose();
  return width;
}

/// 标题与轨道节点对齐；时间、真实阶段与计划进度各占自己的层级。
class ScheduleMissionRow extends StatelessWidget {
  const ScheduleMissionRow({
    super.key,
    required this.item,
    required this.now,
    required this.onTap,
    this.isFirst = true,
    this.isLast = true,
    this.showFullTitle = false,
  });

  final display.TodayMissionItem item;
  final DateTime now;
  final VoidCallback onTap;
  final bool isFirst;
  final bool isLast;

  /// 首页标题最多两行；完整日程展开标题，辅助信息自然换行。
  final bool showFullTitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final titleStyle = theme.textTheme.titleSmall!.copyWith(
      fontWeight: FontWeight.w600,
    );
    final metaStyle = theme.textTheme.bodySmall!.copyWith(
      fontFeatures: _tabularFigures,
    );
    final statusStyle = theme.textTheme.labelSmall!.copyWith(
      color: colors.onSurface,
    );
    final current =
        display.isInPlannedTimeSlot(item, now) &&
        const [
          MissionPhase.notStarted,
          MissionPhase.running,
          MissionPhase.paused,
        ].contains(item.phase);
    // 计划时段只是排期；有执行事实后优先呈现真实执行阶段。
    final status = display.scheduleRowStatus(item, now);
    final remaining = display.plannedTimeSlotRemainingMinutes(item, now);
    final label = [
      item.startTime,
      item.title,
      '计划 ${item.plannedDurationMinutes} 分钟',
      if (item.timeZoneLabel != null) item.timeZoneLabel!,
      status,
      if (current) '计划时段剩余 $remaining 分钟',
    ].join('，');
    final titleLineHeight = _lineHeight(
      titleStyle,
      MediaQuery.textScalerOf(context),
    );
    final headerLineHeight = math.max(titleLineHeight, AppLayout.iconMd);
    final nodeCenterY = AppLayout.spaceSm + headerLineHeight / 2;
    final radius = BorderRadius.circular(AppLayout.radiusMd);
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
          color: current ? colors.tertiaryContainer : Colors.transparent,
          borderRadius: radius,
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: onTap,
            excludeFromSemantics: true,
            borderRadius: radius,
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                minHeight: AppLayout.touchTargetMin,
              ),
              child: Stack(
                alignment: AlignmentDirectional.topStart,
                children: [
                  if (!isFirst)
                    Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      child: SizedBox(
                        height: AppLayout.strokeThin,
                        child: ColoredBox(color: colors.outlineVariant),
                      ),
                    ),
                  PositionedDirectional(
                    start: (_trackWidth - AppLayout.strokeThin) / 2,
                    top: isFirst ? nodeCenterY : 0,
                    bottom: isLast ? _terminalTrackInset : 0,
                    child: SizedBox(
                      key: ValueKey('schedule-track-${item.id}'),
                      width: AppLayout.strokeThin,
                      child: ColoredBox(color: colors.outlineVariant),
                    ),
                  ),
                  PositionedDirectional(
                    start: (_trackWidth - _nodeSize) / 2,
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
                          color: current
                              ? colors.primary
                              : colors.onSurfaceVariant,
                          width: AppLayout.strokeThin,
                        ),
                        boxShadow: current
                            ? [
                                BoxShadow(
                                  color: colors.tertiaryContainer,
                                  spreadRadius: AppLayout.strokeFocus,
                                ),
                              ]
                            : null,
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsetsDirectional.fromSTEB(
                      _trackWidth,
                      AppLayout.spaceSm,
                      AppLayout.spaceSm,
                      AppLayout.spaceSm,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Padding(
                                padding: EdgeInsets.only(
                                  top: (headerLineHeight - titleLineHeight) / 2,
                                ),
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
                            ),
                            const SizedBox(width: AppLayout.spaceXs),
                            Padding(
                              padding: EdgeInsets.only(
                                top: (headerLineHeight - AppLayout.iconMd) / 2,
                              ),
                              child: Icon(
                                Icons.chevron_right_rounded,
                                key: ValueKey('schedule-open-${item.id}'),
                                size: AppLayout.iconMd,
                                color: colors.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppLayout.spaceXs),
                        Padding(
                          padding: const EdgeInsetsDirectional.only(
                            start: AppLayout.spaceSm,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _ScheduleMetadata(
                                item: item,
                                status: status,
                                metaStyle: metaStyle,
                                statusStyle: statusStyle,
                              ),
                              if (current) ...[
                                const SizedBox(height: AppLayout.spaceXs),
                                _PlanProgress(
                                  id: item.id,
                                  progress: display.plannedTimeSlotProgress(
                                    item,
                                    now,
                                  ),
                                  remainingLabel: '计划剩余 $remaining 分钟',
                                  style: metaStyle,
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 开始与结束时刻成组，末端只显示真实阶段；执行时长在执行页阅读。
class _ScheduleMetadata extends StatelessWidget {
  const _ScheduleMetadata({
    required this.item,
    required this.status,
    required this.metaStyle,
    required this.statusStyle,
  });

  final display.TodayMissionItem item;
  final String status;
  final TextStyle metaStyle;
  final TextStyle statusStyle;

  @override
  Widget build(BuildContext context) {
    final time = display.scheduleTimeRangeLabel(item);
    final timeGroup = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(time, key: ValueKey('schedule-meta-${item.id}'), style: metaStyle),
        if (item.timeZoneLabel case final zone?) ...[
          const SizedBox(height: AppLayout.spaceXs),
          Text(
            zone,
            key: ValueKey('schedule-timezone-${item.id}'),
            style: metaStyle,
          ),
        ],
      ],
    );
    final statusGroup = Wrap(
      alignment: WrapAlignment.end,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: AppLayout.spaceSm,
      runSpacing: AppLayout.spaceXs,
      children: [
        Text(
          status,
          key: ValueKey('schedule-status-${item.id}'),
          style: statusStyle,
          textAlign: TextAlign.end,
        ),
      ],
    );
    return LayoutBuilder(
      builder: (context, box) {
        final timeWidth = _singleLineWidth(context, time, metaStyle);
        final statusWidth = _singleLineWidth(context, status, statusStyle);
        const gap = AppLayout.spaceSm;
        if (timeWidth + gap + statusWidth <= box.maxWidth) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(width: timeWidth, child: timeGroup),
              const SizedBox(width: gap),
              Expanded(child: statusGroup),
            ],
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            timeGroup,
            const SizedBox(height: AppLayout.spaceXs),
            statusGroup,
          ],
        );
      },
    );
  }
}

/// 计划剩余时间只在当前时段出现，优先与进度条同行，空间不足再向下换行。
class _PlanProgress extends StatelessWidget {
  const _PlanProgress({
    required this.id,
    required this.progress,
    required this.remainingLabel,
    required this.style,
  });

  final String id;
  final double progress;
  final String remainingLabel;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final label = remainingLabel;
    final track = TweenAnimationBuilder<double>(
      tween: Tween(end: progress),
      duration: _motionDuration(context),
      curve: AppMotion.curve,
      builder: (context, value, _) => LinearProgressIndicator(
        key: ValueKey('schedule-plan-progress-$id'),
        value: value,
        minHeight: AppLayout.spaceXs,
        borderRadius: BorderRadius.circular(AppLayout.radiusXs),
        color: colors.primary,
        backgroundColor: colors.outlineVariant,
        trackGap: 0,
        stopIndicatorRadius: 0,
      ),
    );
    final remaining = Text(
      label,
      key: ValueKey('schedule-plan-remaining-$id'),
      style: style,
      textAlign: TextAlign.end,
    );
    return LayoutBuilder(
      builder: (context, box) {
        final needed =
            _singleLineWidth(context, label, style) +
            AppLayout.spaceSm +
            _minProgressTrackWidth;
        if (box.maxWidth >= needed) {
          return Row(
            children: [
              Expanded(child: track),
              const SizedBox(width: AppLayout.spaceSm),
              remaining,
            ],
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            track,
            const SizedBox(height: AppLayout.spaceXs),
            remaining,
          ],
        );
      },
    );
  }
}

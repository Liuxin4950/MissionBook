import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/theme/app_layout.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/theme/colors.dart';
import '../../../domain/entities/mission_detail.dart';
import '../../../domain/entities/mission_phase.dart';
import '../../widgets/adaptive_sheet.dart';
import '../../widgets/app_section_card.dart';
import '../../widgets/app_visibility.dart';
import '../shared/mission_phase_display.dart';
import 'timetable_conflicts.dart';
import 'timetable_layout.dart';
import 'week_timetable_layout.dart';

/// 七天始终等分实际内容宽度；页面负责纵向滚动，不建立内部滚动窗口。
class MissionWeekTimetable extends StatefulWidget {
  const MissionWeekTimetable({
    super.key,
    required this.start,
    required this.records,
    required this.visible,
    required this.onOpen,
    required this.buildOtherRow,
    required this.clock,
    this.filtered = false,
  });

  final DateTime start;
  final List<MissionDetail> records;
  final bool Function(MissionDetail) visible;
  final ValueChanged<String> onOpen;
  final Widget Function(MissionDetail) buildOtherRow;
  final DateTime Function() clock;
  final bool filtered;

  @override
  State<MissionWeekTimetable> createState() => _MissionWeekTimetableState();
}

class _MissionWeekTimetableState extends State<MissionWeekTimetable>
    with WidgetsBindingObserver {
  Timer? _timer;
  bool _appVisible = true;
  bool _tickerEnabled = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _appVisible = isAppVisible(WidgetsBinding.instance.lifecycleState);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _tickerEnabled = TickerMode.valuesOf(context).enabled;
    _configureTimer();
  }

  void _configureTimer() {
    if (!_appVisible || !_tickerEnabled) {
      _timer?.cancel();
      _timer = null;
    } else {
      // 整周只使用一个时钟；刷新当前线和实际区间，不查询或写入业务事实。
      _timer ??= Timer.periodic(const Duration(seconds: 30), (_) {
        if (mounted) setState(() {});
      });
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _appVisible = isAppVisible(state);
    _configureTimer();
    if (_appVisible && mounted) setState(() {});
  }

  @override
  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _showDay(WeekTimetableDay day) async {
    final target = await showAdaptiveSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * .7,
          child: ListView(
            padding: const EdgeInsets.all(AppLayout.spaceXxl),
            children: [
              Text(
                '${timetableDateKey(day.date)} · ${timetableWeekdays[day.date.weekday - 1]}',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              if (day.layout.slots.isEmpty && day.other.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: AppLayout.spaceLg),
                  child: Text('这一天没有符合条件的任务。'),
                ),
              for (final slot in day.layout.slots)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(slot.detail.mission.title),
                  subtitle: Text(
                    '${slot.timeLabel} · ${phaseLabel(slot.detail.phase, schedule: slot.detail.schedule, now: widget.clock())}'
                    '${slot.conflicts.isNotEmpty ? ' · 计划冲突 ${slot.conflictMinutes.ceil()} 分钟' : ''}',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.pop(context, slot.id),
                ),
              for (final detail in day.other.where(
                (detail) => !day.layout.slots.any(
                  (slot) => slot.id == detail.mission.id,
                ),
              ))
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(detail.mission.title),
                  subtitle: Text(
                    phaseLabel(
                      detail.phase,
                      schedule: detail.schedule,
                      now: widget.clock(),
                    ),
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.pop(context, detail.mission.id),
                ),
            ],
          ),
        ),
      ),
    );
    if (mounted && target != null) widget.onOpen(target);
  }

  @override
  Widget build(BuildContext context) {
    final now = timetableNow(widget.clock());
    final week = TimetableWeek.build(
      widget.records,
      widget.start,
      now: now,
      visible: widget.visible,
    );
    final theme = Theme.of(context);
    final hasConflicts = week.days.any(
      (day) => day.layout.conflicts.isNotEmpty,
    );
    final empty = week.days.every(
      (day) => day.layout.slots.isEmpty && day.other.isEmpty,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (hasConflicts)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              key: const Key('timetable-conflicts'),
              icon: const Icon(
                Icons.warning_amber_rounded,
                size: AppLayout.iconSm,
              ),
              label: const Text('查看时间冲突'),
              style: TextButton.styleFrom(foregroundColor: AppColors.error),
              onPressed: () => showTimetableConflicts(
                context,
                days: [
                  for (final day in week.days)
                    (day: day.date, layout: day.layout),
                ],
                onOpen: widget.onOpen,
              ),
            ),
          ),
        if (empty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppLayout.spaceMd),
            child: Text(
              widget.filtered ? '本周没有符合筛选条件的任务。' : '本周暂无任务安排。',
              style: theme.textTheme.bodyMedium,
            ),
          ),
        _grid(context, week, now),
        const SizedBox(height: AppLayout.spaceSm),
        Text(
          '北京时间 · 同名任务同色，棕色为实际执行；点击日期查看完整安排。',
          style: theme.textTheme.bodySmall,
        ),
        for (final cancelled in [false, true])
          if (week.days.any(
            (day) => day.other.any(
              (detail) => (detail.phase == MissionPhase.cancelled) == cancelled,
            ),
          )) ...[
            const SizedBox(height: AppLayout.sectionGap),
            _otherSection(context, week, cancelled: cancelled),
          ],
      ],
    );
  }

  Widget _otherSection(
    BuildContext context,
    TimetableWeek week, {
    required bool cancelled,
  }) {
    final theme = Theme.of(context);
    return AppSectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            cancelled ? '已取消 · 不占用时段' : '自选时间',
            style: theme.textTheme.titleMedium,
          ),
          if (!cancelled)
            Text('按日期安排，时间自由选择。', style: theme.textTheme.bodySmall),
          for (final day in week.days)
            for (final records in [
              day.other
                  .where(
                    (detail) =>
                        (detail.phase == MissionPhase.cancelled) == cancelled,
                  )
                  .toList(),
            ])
              if (records.isNotEmpty) ...[
                const SizedBox(height: AppLayout.spaceMd),
                Text(
                  '${timetableWeekdays[day.date.weekday - 1]} · ${day.date.month}月${day.date.day}日',
                  style: theme.textTheme.labelLarge,
                ),
                for (final detail in records) widget.buildOtherRow(detail),
              ],
        ],
      ),
    );
  }

  Widget _grid(BuildContext context, TimetableWeek week, DateTime now) {
    final theme = Theme.of(context);
    final headerStyle = theme.textTheme.labelSmall?.merge(
      AppTypography.calendarLabel,
    );
    final scale = math.max(
      1.0,
      MediaQuery.textScalerOf(context).scale(12) / 12,
    );
    final todayIndex = week.days.indexWhere(
      (day) => DateUtils.isSameDay(day.date, now),
    );
    final nowMinute = todayIndex < 0 ? null : now.hour * 60.0 + now.minute;
    final window = timetableWindow(
      week.days.expand((day) => day.layout.slots),
      nowMinute: nowMinute,
    );
    // 七天共用刻度和比例；保留通常的 8–20 点，并覆盖凌晨、夜间和跨日时段。
    final start = math.min(480.0, window.start);
    final end = math.max(1200.0, window.end);
    final pixelsPerMinute = .9 * scale;
    final height = (end - start) * pixelsPerMinute;
    final chartTop = 8 * scale;
    final tickStep = 120;
    final ticks = <double>{
      start,
      for (
        var minute = (start / tickStep).ceil() * tickStep.toDouble();
        minute < end;
        minute += tickStep
      )
        minute,
      end,
    };
    final labelPainter = TextPainter(
      text: TextSpan(text: '24:00', style: theme.textTheme.bodySmall),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
    )..layout();
    final gutter = labelPainter.width + AppLayout.spaceSm;
    labelPainter.dispose();
    return AppSectionCard(
      padding: const EdgeInsets.symmetric(vertical: AppLayout.spaceXs),
      child: LayoutBuilder(
        builder: (context, box) {
          final dayWidth = (box.maxWidth - gutter) / 7;
          return Column(
            children: [
              Row(
                key: const Key('week-timetable-header'),
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  SizedBox(
                    width: gutter,
                    child: Text(
                      '${week.start.month}月',
                      textAlign: TextAlign.center,
                      style: headerStyle,
                    ),
                  ),
                  for (final day in week.days)
                    SizedBox(
                      width: dayWidth,
                      child: Semantics(
                        label:
                            '${timetableDateKey(day.date)}，${timetableWeekdays[day.date.weekday - 1]}，'
                            '${DateUtils.isSameDay(day.date, now) ? '今天，' : ''}'
                            '查看当天全部安排',
                        button: true,
                        enabled: day.supported,
                        excludeSemantics: true,
                        onTap: day.supported ? () => _showDay(day) : null,
                        child: InkWell(
                          key: Key('week-day-${timetableDateKey(day.date)}'),
                          onTap: day.supported ? () => _showDay(day) : null,
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(
                              minHeight: AppLayout.touchTargetMin,
                            ),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                vertical: AppLayout.spaceXs,
                              ),
                              child: Column(
                                children: [
                                  Text(
                                    timetableWeekdays[day.date.weekday - 1]
                                        .substring(1),
                                    style: headerStyle,
                                  ),
                                  const SizedBox(height: AppLayout.spaceXs / 2),
                                  ConstrainedBox(
                                    constraints: BoxConstraints(
                                      minWidth: math.min(
                                        24 * scale,
                                        dayWidth - 4,
                                      ),
                                    ),
                                    child: DecoratedBox(
                                      key: Key(
                                        'week-date-background-${timetableDateKey(day.date)}',
                                      ),
                                      decoration: BoxDecoration(
                                        color:
                                            DateUtils.isSameDay(day.date, now)
                                            ? AppColors.primary
                                            : Colors.transparent,
                                        borderRadius: BorderRadius.circular(
                                          AppLayout.radiusSm,
                                        ),
                                      ),
                                      child: Padding(
                                        padding: EdgeInsets.symmetric(
                                          horizontal: math.min(
                                            AppLayout.spaceXs,
                                            math.max(
                                              2.0,
                                              (dayWidth - 22 * scale) / 2,
                                            ),
                                          ),
                                          vertical: AppLayout.spaceXs - 1,
                                        ),
                                        child: Text(
                                          day.supported
                                              ? '${day.date.day}'
                                              : '—',
                                          key: Key(
                                            'week-date-label-${timetableDateKey(day.date)}',
                                          ),
                                          textAlign: TextAlign.center,
                                          style: headerStyle?.copyWith(
                                            color:
                                                DateUtils.isSameDay(
                                                  day.date,
                                                  now,
                                                )
                                                ? AppColors.onPrimary
                                                : null,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              SizedBox(
                key: const Key('week-timetable-grid'),
                height: height + 20 * scale,
                child: Stack(
                  children: [
                    if (todayIndex >= 0)
                      Positioned(
                        left: gutter + todayIndex * dayWidth,
                        top: chartTop,
                        width: dayWidth,
                        height: height,
                        child: ColoredBox(
                          color: AppColors.primarySoft.withValues(alpha: .45),
                        ),
                      ),
                    for (var index = 0; index <= 7; index++)
                      Positioned(
                        left: gutter + index * dayWidth,
                        top: chartTop,
                        width: 1,
                        height: height,
                        child: const ColoredBox(color: AppColors.hairline),
                      ),
                    for (final minute in ticks) ...[
                      Positioned(
                        top: chartTop + (minute - start) * pixelsPerMinute,
                        left: gutter,
                        right: 0,
                        child: const Divider(height: 1),
                      ),
                      Positioned(
                        top:
                            chartTop +
                            (minute - start) * pixelsPerMinute -
                            7 * scale,
                        left: 0,
                        width: gutter,
                        child: Text(
                          timetableClock(minute),
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodySmall,
                        ),
                      ),
                    ],
                    for (var index = 0; index < 7; index++)
                      for (final block in weekTimetableBlocks(
                        week.days[index].layout.slots,
                      ))
                        Positioned(
                          key: Key(
                            'week-block-${timetableDateKey(week.days[index].date)}-${block.slots.first.id}',
                          ),
                          left: gutter + index * dayWidth + 2,
                          top:
                              chartTop +
                              (block.start - start) * pixelsPerMinute,
                          width: math.max(0, dayWidth - 3),
                          height: math.max(
                            2,
                            (block.end - block.start) * pixelsPerMinute,
                          ),
                          child: _block(
                            context,
                            block,
                            scale,
                            onTap: block.slots.length == 1
                                ? () => widget.onOpen(block.slots.single.id)
                                : () => _showDay(week.days[index]),
                          ),
                        ),
                    if (nowMinute != null &&
                        nowMinute >= start &&
                        nowMinute < end)
                      Positioned(
                        key: const Key('week-timetable-now'),
                        left: gutter + todayIndex * dayWidth,
                        top: chartTop + (nowMinute - start) * pixelsPerMinute,
                        width: dayWidth,
                        height: 2,
                        child: const IgnorePointer(
                          child: ColoredBox(color: AppColors.primary),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  ({Color surface, Color accent}) _plannedPalette(String title) {
    // 不使用运行时 hashCode；相同名称跨会话、跨周和跨平台都取得同一配色。
    var hash = 0;
    for (final rune in title.trim().runes) {
      hash = (hash * 31 + rune) & 0x7fffffff;
    }
    const colors = [
      (surface: AppColors.scheduleMint, accent: AppColors.primary),
      (surface: AppColors.scheduleBlue, accent: AppColors.scheduleBlueAccent),
      (surface: AppColors.scheduleLilac, accent: AppColors.scheduleLilacAccent),
      (surface: AppColors.scheduleOlive, accent: AppColors.scheduleOliveAccent),
    ];
    return colors[hash % colors.length];
  }

  Widget _block(
    BuildContext context,
    WeekTimetableBlock block,
    double scale, {
    required VoidCallback onTap,
  }) {
    final first = block.slots.first;
    final multiple = block.slots.length > 1;
    final actual = block.slots.every((slot) => slot.actual);
    final palette = _plannedPalette(first.detail.mission.title);
    final title = multiple
        ? '${block.slots.length}项安排'
        : first.detail.mission.title;
    final status = phaseLabel(
      first.detail.phase,
      schedule: first.detail.schedule,
      now: widget.clock(),
    );
    final label = block.slots
        .map(
          (slot) =>
              '${slot.detail.mission.title}，${slot.timeLabel}，${phaseLabel(slot.detail.phase, schedule: slot.detail.schedule, now: widget.clock())}',
        )
        .join('；');
    return Semantics(
      label: '$label${block.hasConflict ? '；存在计划时间冲突' : ''}',
      button: true,
      onTap: onTap,
      excludeSemantics: true,
      child: Tooltip(
        message: label,
        child: Material(
          color: actual
              ? AppColors.warningSoft
              : multiple
              ? AppColors.surfaceMuted
              : palette.surface,
          borderRadius: BorderRadius.circular(AppLayout.radiusXs),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            key: Key('week-task-${first.id}'),
            onTap: onTap,
            child: DecoratedBox(
              decoration: BoxDecoration(
                border: Border(
                  left: BorderSide(
                    width: 2,
                    color: block.hasConflict
                        ? AppColors.error
                        : actual
                        ? AppColors.warning
                        : multiple
                        ? AppColors.primary
                        : palette.accent,
                  ),
                ),
              ),
              child: LayoutBuilder(
                builder: (context, box) {
                  if (box.maxHeight < 16 * scale) {
                    return const SizedBox.expand();
                  }
                  final wide = box.maxWidth >= 100 * scale;
                  final titleLines = math.max(
                    1,
                    ((box.maxHeight - 8) / (16 * scale)).floor(),
                  );
                  return Padding(
                    padding: const EdgeInsets.fromLTRB(4, 2, 2, 2),
                    child: Text(
                      wide
                          ? '$title\n${multiple ? '点击展开' : first.timeLabel}\n${multiple ? '' : status}'
                          : title,
                      maxLines: titleLines,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

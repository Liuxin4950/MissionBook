import 'dart:async';

import 'package:flutter/material.dart';
import 'empty_schedule.dart';
import '../widgets/app_section_card.dart';
import 'package:timezone/timezone.dart' as tz;

import 'today_display.dart' as display;
import '../../domain/entities/mission_schedule_revision.dart';
import '../../domain/entities/mission_phase.dart';
import '../missions/shared/mission_phase_display.dart';
import '../missions/shared/mission_live_status.dart';
import '../widgets/app_visibility.dart';
import '../../core/theme/app_layout.dart';
import '../../core/theme/app_motion.dart';

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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final local = tz.TZDateTime.from(
      _now,
      tz.getLocation(defaultScheduleTimeZone),
    );
    // 常规手机最多四项，小屏/大字体减少窗口项数；内容始终自然增高，不裁字。
    final scale = MediaQuery.textScalerOf(context).scale(16) / 16;
    final limit = ((MediaQuery.sizeOf(context).height * .4 - 96) / (56 * scale))
        .floor()
        .clamp(2, 4);
    final preview = widget.fullList
        ? widget.items.skip(_page * 50).take(50).toList()
        : display.schedulePreview(widget.items, _now, limit: limit);
    final items = preview;
    final hidden = widget.fullList ? 0 : widget.items.length - items.length;
    return AppSectionCard(
      paperBackground: widget.illustrateEmpty && items.isEmpty,
      child: Padding(
        padding: EdgeInsets.zero,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: AppLayout.spaceSm,
              children: [
                Wrap(
                  spacing: AppLayout.spaceMd,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    if (!widget.fullList)
                      Semantics(
                        header: true,
                        child: Text('计划日程', style: theme.textTheme.titleMedium),
                      ),
                    Text(
                      '共 ${widget.items.length} 项',
                      style: theme.textTheme.bodyMedium,
                    ),
                  ],
                ),
                if (!widget.fullList && widget.items.isNotEmpty)
                  TextButton(
                    key: const Key('today-all-missions'),
                    onPressed: widget.onOpenAll,
                    style: TextButton.styleFrom(
                      textStyle: theme.textTheme.labelMedium,
                    ),
                    child: const Text('查看全部 ›'),
                  ),
              ],
            ),
            if (widget.items.isNotEmpty &&
                DateUtils.isSameDay(local, widget.selectedDate))
              Padding(
                key: const Key('timeline-current-time'),
                padding: const EdgeInsets.only(bottom: AppLayout.spaceSm),
                child: Row(
                  children: [
                    Text('现在', style: theme.textTheme.bodyMedium),
                    const SizedBox(width: AppLayout.spaceSm),
                    Text(
                      '${local.hour.toString().padLeft(2, '0')}:'
                      '${local.minute.toString().padLeft(2, '0')}',
                      style: theme.textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
            if (items.isEmpty)
              EmptySchedule(
                illustrate: widget.illustrateEmpty,
                onCreate: widget.onCreate,
              )
            else
              AnimatedSize(
                duration: _motionDuration(context),
                curve: AppMotion.curve,
                alignment: Alignment.topCenter,
                child: Column(
                  children: [
                    for (var index = 0; index < items.length; index++)
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
                            onTap: () => widget.onOpenMission(items[index].id),
                          ),
                        ],
                      ),
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
            if (hidden > 0)
              TextButton(
                key: const Key('schedule-more'),
                onPressed: widget.onOpenAll,
                style: TextButton.styleFrom(
                  textStyle: theme.textTheme.labelMedium,
                ),
                child: Text('另有 $hidden 项 · 查看全部 ›'),
              ),
          ],
        ),
      ),
    );
  }
}

Duration _motionDuration(BuildContext context) =>
    AppMotion.resolve(context, AppMotion.standard);

/// 用自然布局连接节点，不测量文字、不按分钟拉伸行高。
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

  /// 首页保留紧凑摘要；完整日程展开标题，状态移到下一行。
  final bool showFullTitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final current = display.isInPlannedTimeSlot(item, now);
    final progress = display.plannedTimeSlotProgress(item, now);
    final remainingMinutes = current
        ? (item.fixedStartAt!
                      .add(Duration(minutes: item.plannedDurationMinutes))
                      .difference(now)
                      .inMilliseconds /
                  60000)
              .ceil()
        : 0;
    final elapsed =
        item.fixedStartAt != null &&
        !now.isBefore(
          item.fixedStartAt!.add(
            Duration(minutes: item.plannedDurationMinutes),
          ),
        );
    final planStatus = item.isCancelled
        ? '已取消'
        : current
        ? '当前时段'
        : elapsed
        ? '时段已过'
        : '待到时';
    // 计划时段只是排期；有执行事实后优先呈现真实执行阶段。
    final status = item.phase == MissionPhase.notStarted
        ? planStatus
        : phaseLabel(item.phase);
    final label = [
      if (current) '当前计划时段',
      item.startTime,
      item.title,
      item.durationLabel,
      if (item.timeZoneLabel != null) item.timeZoneLabel!,
      if (!item.isCancelled) phaseLabel(item.phase),
    ].join('，');
    return Semantics(
      container: true,
      excludeSemantics: true,
      button: true,
      label: label,
      hint: '$status，${missionOpenLabel(item.phase)}',
      onTap: onTap,
      child: AnimatedContainer(
        duration: _motionDuration(context),
        curve: AppMotion.curve,
        decoration: BoxDecoration(
          color: current
              ? colors.tertiaryContainer
              : colors.surfaceContainerLow.withValues(alpha: 0),
          borderRadius: BorderRadius.circular(AppLayout.radiusMd),
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: onTap,
            excludeFromSemantics: true,
            borderRadius: BorderRadius.circular(AppLayout.radiusMd),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final stacked =
                    showFullTitle ||
                    constraints.maxWidth < 320 ||
                    MediaQuery.textScalerOf(context).scale(16) > 20;
                final timeStyle = theme.textTheme.bodyMedium!;
                final timeLineHeight =
                    MediaQuery.textScalerOf(
                      context,
                    ).scale(timeStyle.fontSize!) *
                    (timeStyle.height ?? 1);
                final nodeCenterY = 16 + timeLineHeight / 2;
                const timelineEndInset = 12.0;
                return Stack(
                  children: [
                    Positioned(
                      left: 7,
                      // 首尾只收进边缘留白，单项也保留穿过节点的竖线。
                      // 中间行连到边界，随内容自然增高，连接处没有间隙。
                      top: isFirst ? timelineEndInset : 0,
                      bottom: isLast ? timelineEndInset : 0,
                      child: Container(
                        width: AppLayout.strokeThin,
                        color: colors.outlineVariant,
                      ),
                    ),
                    Positioned(
                      left: 3,
                      top: nodeCenterY - 4.5,
                      child: Container(
                        key: ValueKey('schedule-node-${item.id}'),
                        width: 9,
                        height: 9,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: current
                              ? colors.primary
                              : colors.surfaceContainerLow,
                          border: Border.all(
                            color: current ? colors.primary : colors.outline,
                          ),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                        AppLayout.spaceXxl,
                        AppLayout.spaceLg,
                        AppLayout.spaceSm,
                        AppLayout.spaceLg,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.startTime,
                                style: theme.textTheme.bodyMedium,
                              ),
                              const SizedBox(width: AppLayout.spaceMd),
                              Expanded(
                                child: Text(
                                  item.title,
                                  maxLines: showFullTitle ? null : 1,
                                  overflow: showFullTitle
                                      ? TextOverflow.visible
                                      : TextOverflow.ellipsis,
                                  style: theme.textTheme.titleMedium,
                                ),
                              ),
                              if (!stacked) ...[
                                const SizedBox(width: AppLayout.spaceSm),
                                _StatusLabel(status: status, current: current),
                              ],
                            ],
                          ),
                          if (stacked || !current || item.timeZoneLabel != null)
                            Padding(
                              padding: const EdgeInsets.only(
                                top: AppLayout.spaceSm,
                              ),
                              child: Wrap(
                                spacing: AppLayout.spaceSm,
                                runSpacing: AppLayout.spaceXs,
                                children: [
                                  if (stacked)
                                    _StatusLabel(
                                      status: status,
                                      current: current,
                                    ),
                                  if (!current)
                                    Text(
                                      item.durationLabel,
                                      style: theme.textTheme.bodyMedium,
                                    ),
                                  if (item.timeZoneLabel != null)
                                    Text(
                                      item.timeZoneLabel!,
                                      style: theme.textTheme.bodySmall,
                                    ),
                                ],
                              ),
                            ),
                          if (item.events.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(
                                top: AppLayout.spaceSm,
                              ),
                              child: MissionLiveStatus(
                                phase: item.phase,
                                events: item.events,
                                clock: clock,
                                includePhase: false,
                              ),
                            ),
                          if (current) ...[
                            const SizedBox(height: AppLayout.spaceMd),
                            TweenAnimationBuilder<double>(
                              tween: Tween(end: progress),
                              duration: _motionDuration(context),
                              builder: (context, value, _) =>
                                  LinearProgressIndicator(
                                    value: value,
                                    minHeight: 5,
                                    borderRadius: BorderRadius.circular(
                                      AppLayout.radiusXs,
                                    ),
                                    backgroundColor: colors.primary.withValues(
                                      alpha: .08,
                                    ),
                                  ),
                            ),
                            const SizedBox(height: AppLayout.spaceSm),
                            Wrap(
                              spacing: AppLayout.spaceMd,
                              runSpacing: AppLayout.spaceSm,
                              alignment: WrapAlignment.spaceBetween,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                Text(
                                  '计划时段剩余 $remainingMinutes 分钟',
                                  style: theme.textTheme.bodyMedium,
                                ),
                                Text(
                                  '${(progress * 100).floor()}%',
                                  style: theme.textTheme.bodyMedium,
                                ),
                                // 整行就是详情按钮，这里只是同一动作的视觉提示。
                                DecoratedBox(
                                  decoration: BoxDecoration(
                                    color: colors.primary,
                                    borderRadius: BorderRadius.circular(
                                      AppLayout.radiusSm,
                                    ),
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: AppLayout.spaceLg,
                                      vertical: AppLayout.spaceMd,
                                    ),
                                    child: Text(
                                      '查看',
                                      style: theme.textTheme.labelMedium
                                          ?.copyWith(color: colors.onPrimary),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _StatusLabel extends StatelessWidget {
  const _StatusLabel({required this.status, required this.current});
  final String status;
  final bool current;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: current
            ? theme.colorScheme.surfaceContainerLow
            : Colors.transparent,
        borderRadius: BorderRadius.circular(AppLayout.radiusSm),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppLayout.spaceSm,
          vertical: 3,
        ),
        child: Text(
          status,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: current
                ? theme.colorScheme.onSurface
                : theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

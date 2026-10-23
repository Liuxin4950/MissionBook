import 'dart:async';

import 'package:flutter/material.dart';
import 'package:timezone/timezone.dart' as tz;

import 'today_display.dart' as display;

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
  });

  final List<display.TodayMissionItem> items;
  final DateTime selectedDate;
  final DateTime Function() clock;
  final ValueChanged<String> onOpenMission;
  final VoidCallback? onOpenAll;
  final VoidCallback? onCreate;
  final bool fullList;

  @override
  State<ScheduleSection> createState() => _ScheduleSectionState();
}

class _ScheduleSectionState extends State<ScheduleSection>
    with WidgetsBindingObserver {
  late DateTime _now;
  Timer? _timer;
  bool _visible = false;
  bool _foreground = true;

  @override
  void initState() {
    super.initState();
    _now = widget.clock();
    _foreground =
        WidgetsBinding.instance.lifecycleState == null ||
        WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;
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
    _syncClock();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    _syncClock();
    if (mounted) setState(() {});
  }

  void _syncClock() {
    _timer?.cancel();
    if (!_visible || !_foreground || widget.items.isEmpty) return;
    _now = widget.clock();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
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
      tz.getLocation(display.todayScheduleTimeZone),
    );
    // 常规手机最多四项，小屏/大字体减少窗口项数；内容始终自然增高，不裁字。
    final scale = MediaQuery.textScalerOf(context).scale(16) / 16;
    final limit = ((MediaQuery.sizeOf(context).height * .4 - 96) / (56 * scale))
        .floor()
        .clamp(2, 4);
    final items = widget.fullList
        ? widget.items
        : display.schedulePreview(widget.items, _now, limit: limit);
    final hidden = widget.items.length - items.length;
    return Material(
      color: theme.colorScheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(20),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              children: [
                Wrap(
                  spacing: 12,
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
                    child: const Text('查看全部 ›'),
                  ),
              ],
            ),
            if (widget.items.isNotEmpty &&
                DateUtils.isSameDay(local, widget.selectedDate))
              Padding(
                key: const Key('timeline-current-time'),
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Text('现在', style: theme.textTheme.bodySmall),
                    const SizedBox(width: 6),
                    Text(
                      '${local.hour.toString().padLeft(2, '0')}:'
                      '${local.minute.toString().padLeft(2, '0')}',
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            if (items.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Column(
                  children: [
                    Icon(
                      Icons.event_available_outlined,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(height: 12),
                    const Text('这一天还没有固定任务'),
                    const SizedBox(height: 4),
                    Text('留一点空白，按自己的节奏安排', style: theme.textTheme.bodySmall),
                    if (widget.onCreate != null) ...[
                      const SizedBox(height: 12),
                      FilledButton.tonalIcon(
                        onPressed: widget.onCreate,
                        icon: const Icon(Icons.add),
                        label: const Text('新建任务'),
                      ),
                    ],
                  ],
                ),
              )
            else
              AnimatedSize(
                duration: _motionDuration(context),
                curve: Curves.easeOutCubic,
                alignment: Alignment.topCenter,
                child: Column(
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
            if (hidden > 0)
              TextButton(
                key: const Key('schedule-more'),
                onPressed: widget.onOpenAll,
                child: Text('另有 $hidden 项 · 查看全部 ›'),
              ),
          ],
        ),
      ),
    );
  }
}

Duration _motionDuration(BuildContext context) =>
    MediaQuery.disableAnimationsOf(context)
    ? Duration.zero
    : const Duration(milliseconds: 240);

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
  });

  final display.TodayMissionItem item;
  final DateTime now;
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
    final status = item.isCancelled
        ? '已取消'
        : current
        ? '当前时段'
        : elapsed
        ? '时段已过'
        : '待到时';
    final label = [
      if (current) '当前计划时段',
      item.startTime,
      item.title,
      item.durationLabel,
      if (item.timeZoneLabel != null) item.timeZoneLabel!,
    ].join('，');
    return Semantics(
      container: true,
      excludeSemantics: true,
      button: true,
      label: label,
      hint: '$status，查看任务详情',
      onTap: onTap,
      child: AnimatedContainer(
        duration: _motionDuration(context),
        curve: Curves.easeOutCubic,
        decoration: BoxDecoration(
          color: current
              ? colors.secondary.withValues(alpha: .22)
              : colors.surfaceContainerLow.withValues(alpha: 0),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: onTap,
            excludeFromSemantics: true,
            borderRadius: BorderRadius.circular(14),
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
                      child: Container(width: 1, color: colors.outlineVariant),
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
                              ? colors.secondary
                              : colors.surfaceContainerLow,
                          border: Border.all(
                            color: current ? colors.primary : colors.outline,
                          ),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 16, 8, 16),
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
                              const SizedBox(width: 12),
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
                                const SizedBox(width: 8),
                                _StatusLabel(status: status, current: current),
                              ],
                            ],
                          ),
                          if (stacked || !current || item.timeZoneLabel != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 6),
                              child: Wrap(
                                spacing: 8,
                                runSpacing: 4,
                                children: [
                                  if (stacked)
                                    _StatusLabel(
                                      status: status,
                                      current: current,
                                    ),
                                  if (!current)
                                    Text(
                                      item.durationLabel,
                                      style: theme.textTheme.bodySmall,
                                    ),
                                  if (item.timeZoneLabel != null)
                                    Text(
                                      item.timeZoneLabel!,
                                      style: theme.textTheme.bodySmall,
                                    ),
                                ],
                              ),
                            ),
                          if (current) ...[
                            const SizedBox(height: 12),
                            TweenAnimationBuilder<double>(
                              tween: Tween(end: progress),
                              duration: _motionDuration(context),
                              builder: (context, value, _) =>
                                  LinearProgressIndicator(
                                    value: value,
                                    minHeight: 5,
                                    borderRadius: BorderRadius.circular(4),
                                    backgroundColor: colors.primary.withValues(
                                      alpha: .08,
                                    ),
                                  ),
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 12,
                              runSpacing: 8,
                              alignment: WrapAlignment.spaceBetween,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                Text(
                                  '计划时段剩余 $remainingMinutes 分钟',
                                  style: theme.textTheme.bodySmall,
                                ),
                                Text(
                                  '${(progress * 100).floor()}%',
                                  style: theme.textTheme.bodySmall,
                                ),
                                // 整行就是详情按钮，这里只是同一动作的视觉提示。
                                DecoratedBox(
                                  decoration: BoxDecoration(
                                    color: colors.primary,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 10,
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
        color: current ? theme.colorScheme.secondary : Colors.transparent,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        child: Text(
          status,
          style: theme.textTheme.bodySmall?.copyWith(
            color: current
                ? theme.colorScheme.onSecondary
                : theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

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
      padding: const EdgeInsets.all(AppLayout.spaceMd),
      paperBackground: widget.illustrateEmpty && items.isEmpty,
      child: Padding(
        padding: EdgeInsets.zero,
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
                        Row(
                          key: const Key('timeline-current-time'),
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('现在', style: theme.textTheme.bodySmall),
                            const SizedBox(width: AppLayout.spaceXs),
                            Text(
                              '${local.hour.toString().padLeft(2, '0')}:'
                              '${local.minute.toString().padLeft(2, '0')}',
                              style: theme.textTheme.bodySmall,
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
                  textStyle: theme.textTheme.labelSmall,
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

  /// 首页标题最多两行；完整日程展开标题，辅助信息自然换行。
  final bool showFullTitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final current = display.isInPlannedTimeSlot(item, now);
    final progress = display.plannedTimeSlotProgress(item, now);
    final remainingMinutes = current
        ? (display.plannedTimeSlotEnd(item)!.difference(now).inMilliseconds /
                  60000)
              .ceil()
        : 0;
    final elapsed =
        item.fixedStartAt != null &&
        !now.isBefore(display.plannedTimeSlotEnd(item)!);
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
      item.startTime,
      item.title,
      '计划 ${item.plannedDurationMinutes} 分钟',
      if (item.timeZoneLabel != null) item.timeZoneLabel!,
      status,
      if (current) '计划时段剩余 $remainingMinutes 分钟',
    ].join('，');
    // 时间与状态归入正文，不再用固定时间列压缩窄屏标题。
    final titleStyle = theme.textTheme.labelSmall!;
    final scaler = MediaQuery.textScalerOf(context);
    final titleLineHeight =
        scaler.scale(titleStyle.fontSize!) * (titleStyle.height ?? 1);
    final nodeCenterY = AppLayout.spaceSm + titleLineHeight / 2;
    const timelineEndInset = 12.0;
    return Semantics(
      container: true,
      excludeSemantics: true,
      button: true,
      label: label,
      hint: missionOpenLabel(item.phase),
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
            child: Stack(
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
                            child: Text(
                              item.title,
                              maxLines: showFullTitle ? null : 2,
                              overflow: showFullTitle
                                  ? TextOverflow.visible
                                  : TextOverflow.ellipsis,
                              style: titleStyle,
                            ),
                          ),
                          const SizedBox(width: AppLayout.spaceSm),
                          Text(status, style: theme.textTheme.bodySmall),
                          const SizedBox(width: AppLayout.spaceXs),
                          Icon(
                            Icons.chevron_right_rounded,
                            size: AppLayout.iconMd,
                            color: colors.onSurfaceVariant,
                          ),
                        ],
                      ),
                      const SizedBox(height: AppLayout.spaceXs),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              '${item.startTime} · ${item.plannedDurationLabel}',
                              style: theme.textTheme.bodySmall,
                            ),
                          ),
                          if (item.events.isNotEmpty) ...[
                            const SizedBox(width: AppLayout.spaceSm),
                            Expanded(
                              child: Align(
                                alignment: Alignment.topRight,
                                child: MissionLiveStatus(
                                  phase: item.phase,
                                  events: item.events,
                                  schedule: item.schedule,
                                  clock: clock,
                                  includePhase: false,
                                  includeFocusLabel: false,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      if (item.timeZoneLabel != null) ...[
                        const SizedBox(height: AppLayout.spaceXs),
                        Text(
                          item.timeZoneLabel!,
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                      if (current) ...[
                        const SizedBox(height: AppLayout.spaceSm),
                        Row(
                          children: [
                            Expanded(
                              child: TweenAnimationBuilder<double>(
                                tween: Tween(end: progress),
                                duration: _motionDuration(context),
                                builder: (context, value, _) =>
                                    LinearProgressIndicator(
                                      value: value,
                                      minHeight: AppLayout.spaceXs,
                                      borderRadius: BorderRadius.circular(
                                        AppLayout.radiusXs,
                                      ),
                                      backgroundColor: colors.primary
                                          .withValues(alpha: .08),
                                    ),
                              ),
                            ),
                            const SizedBox(width: AppLayout.spaceSm),
                            Flexible(
                              child: Text(
                                '时段剩余 $remainingMinutes 分钟',
                                style: theme.textTheme.bodySmall,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

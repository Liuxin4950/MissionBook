import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/theme/colors.dart';
import '../../../domain/entities/mission_detail.dart';
import '../../../domain/entities/mission_phase.dart';
import '../../widgets/app_visibility.dart';
import '../shared/mission_phase_display.dart';
import 'timetable_layout.dart';

/// 日课表负责比例布局、冲突阅读和当前时间线；任务操作仍交回页面。
class MissionTimetable extends StatefulWidget {
  const MissionTimetable({
    super.key,
    required this.day,
    required this.layout,
    required this.onOpen,
    required this.clock,
  });
  final DateTime day;
  final TimetableDay layout;
  final ValueChanged<MissionDetail> onOpen;
  final DateTime Function() clock;

  @override
  State<MissionTimetable> createState() => _MissionTimetableState();
}

class _MissionTimetableState extends State<MissionTimetable>
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

  @override
  void didUpdateWidget(covariant MissionTimetable oldWidget) {
    super.didUpdateWidget(oldWidget);
    _configureTimer();
  }

  void _configureTimer() {
    if (!_appVisible || !_tickerEnabled) {
      _timer?.cancel();
      _timer = null;
    } else {
      // 只重绘时间标记，不查询数据库，也不触发 START/END。
      _timer ??= Timer.periodic(const Duration(seconds: 30), (_) {
        if (mounted) setState(() {});
      });
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _appVisible = isAppVisible(state);
    _configureTimer();
    if (mounted && _appVisible) setState(() {});
  }

  @override
  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _showConflicts([TimetableSlot? selected]) async {
    final conflicts = selected?.conflicts ?? widget.layout.conflicts;
    final visibleIds = widget.layout.slots.map((slot) => slot.id).toSet();
    final target = await showModalBottomSheet<MissionDetail>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * .65,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
            children: [
              Text('计划时间冲突', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              Text(
                '以下计划时段重叠，点击任务查看或调整。',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              for (final conflict in conflicts) ...[
                const SizedBox(height: 24),
                Text(
                  '${timetableClock(conflict.start)}–${timetableClock(conflict.end)}'
                  ' · 重叠 ${(conflict.end - conflict.start).ceil()} 分钟',
                  style: Theme.of(
                    context,
                  ).textTheme.titleMedium?.copyWith(color: AppColors.error),
                ),
                for (final slot in [conflict.first, conflict.second])
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      slot.detail.mission.title,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    subtitle: Text(
                      '${slot.timeLabel} · ${phaseLabel(slot.detail.phase)}'
                      '${visibleIds.contains(slot.id) ? '' : ' · 已被筛选隐藏'}',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.pop(context, slot.detail),
                  ),
                const Divider(),
              ],
            ],
          ),
        ),
      ),
    );
    if (target != null && mounted) widget.onOpen(target);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final slots = widget.layout.slots;
    final now = timetableNow(widget.clock());
    final sameDay = DateUtils.isSameDay(now, widget.day);
    final nowMinute = now.hour * 60.0 + now.minute;
    // 时间轴统一比例；短任务不强行增高，完整信息在下方补充入口阅读。
    final scale = math.max(
      1.0,
      MediaQuery.textScalerOf(context).scale(14) / 14,
    );
    final pixelsPerMinute = 2.0 * scale;
    final earliest = slots.isEmpty ? 8.0 * 60 : slots.first.start;
    final latest = slots.fold<double>(
      18 * 60,
      (end, slot) => math.max(end, slot.end),
    );
    final start = math
        .max(0, (math.min(8 * 60, earliest) / 60).floor() * 60)
        .toDouble();
    final end = math.min(1440, (latest / 60).ceil() * 60).toDouble();
    final columns = slots.fold<int>(
      1,
      (count, slot) => math.max(count, slot.columns),
    );
    final shortSlots = slots
        .where((slot) => slot.end - slot.start < 30)
        .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 8,
          children: [
            Text(
              '固定日程 ${slots.length} 项 · 北京时间',
              style: theme.textTheme.bodyMedium,
            ),
            if (widget.layout.conflicts.isNotEmpty)
              TextButton.icon(
                key: const Key('timetable-conflicts'),
                onPressed: _showConflicts,
                icon: const Icon(Icons.warning_amber_rounded, size: 18),
                label: const Text('查看时间冲突'),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.error,
                  textStyle: theme.textTheme.labelMedium,
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        if (slots.isEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                '这一天没有符合筛选条件的固定日程。',
                style: theme.textTheme.bodyMedium,
              ),
            ),
          )
        else
          Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final gutter = 58.0 * scale;
                  final width = math.max(
                    constraints.maxWidth,
                    gutter + columns * 128 * scale + 12,
                  );
                  final height = (end - start) * pixelsPerMinute;
                  final chartWidth = width - gutter - 12;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (width > constraints.maxWidth)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                          child: Text(
                            '左右滑动查看并排任务',
                            style: theme.textTheme.bodySmall,
                          ),
                        ),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: SizedBox(
                          width: width,
                          height: height + 24 * scale,
                          child: Stack(
                            children: [
                              for (
                                var minute = start;
                                minute <= end;
                                minute += 60
                              )
                                Positioned(
                                  top: (minute - start) * pixelsPerMinute,
                                  left: 0,
                                  right: 12,
                                  child: Row(
                                    children: [
                                      SizedBox(
                                        width: gutter,
                                        child: Padding(
                                          padding: const EdgeInsets.only(
                                            left: 8,
                                            right: 8,
                                          ),
                                          child: Text(
                                            timetableClock(minute),
                                            style: theme.textTheme.bodySmall,
                                          ),
                                        ),
                                      ),
                                      const Expanded(child: Divider(height: 1)),
                                    ],
                                  ),
                                ),
                              if (sameDay &&
                                  nowMinute >= start &&
                                  nowMinute < end)
                                Positioned(
                                  top:
                                      (nowMinute - start) * pixelsPerMinute - 2,
                                  left: 4,
                                  right: 12,
                                  child: IgnorePointer(
                                    child: Row(
                                      children: [
                                        Container(
                                          width: gutter - 4,
                                          color: AppColors.primary,
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 2,
                                          ),
                                          child: Text(
                                            timetableClock(nowMinute),
                                            textAlign: TextAlign.center,
                                            style: theme.textTheme.bodySmall
                                                ?.copyWith(
                                                  color: AppColors.onPrimary,
                                                ),
                                          ),
                                        ),
                                        const Expanded(
                                          child: Divider(
                                            color: AppColors.primary,
                                            thickness: 1.5,
                                            height: 1,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              for (final slot in slots)
                                Positioned(
                                  key: Key('timetable-slot-${slot.id}'),
                                  top:
                                      8 * scale +
                                      (slot.start - start) * pixelsPerMinute,
                                  left:
                                      gutter +
                                      chartWidth * slot.column / slot.columns,
                                  width: chartWidth / slot.columns - 4,
                                  height:
                                      (slot.end - slot.start) * pixelsPerMinute,
                                  child: _slot(context, slot),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        if (widget.layout.conflicts.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text('斜纹标记重叠时段，状态标签表示实际执行情况。', style: theme.textTheme.bodySmall),
        ],
        if (shortSlots.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text('短时任务', style: theme.textTheme.titleMedium),
          for (final slot in shortSlots)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(
                slot.detail.mission.title,
                style: theme.textTheme.titleMedium,
              ),
              subtitle: Text(
                '${slot.timeLabel} · ${phaseLabel(slot.detail.phase)}',
                style: theme.textTheme.bodyMedium,
              ),
              trailing: slot.conflicts.isEmpty
                  ? const Icon(Icons.chevron_right)
                  : IconButton(
                      tooltip: '查看时间冲突',
                      onPressed: () => _showConflicts(slot),
                      icon: const Icon(
                        Icons.warning_amber_rounded,
                        color: AppColors.error,
                      ),
                    ),
              onTap: () => widget.onOpen(slot.detail),
            ),
        ],
      ],
    );
  }

  Widget _slot(BuildContext context, TimetableSlot slot) {
    final theme = Theme.of(context);
    final phase = slot.detail.phase;
    final hasConflict = slot.conflicts.isNotEmpty;
    final minutes = slot.end - slot.start;
    final endAt = slot.detail.schedule.fixedStartAt!.add(
      Duration(minutes: slot.detail.schedule.plannedDurationMinutes),
    );
    final status =
        phase == MissionPhase.notStarted && !widget.clock().isBefore(endAt)
        ? '待开始 · 时段已过'
        : phaseLabel(phase);
    final color = phase == MissionPhase.running
        ? AppColors.accent
        : AppColors.primarySoft;
    return Semantics(
      label:
          '${slot.detail.mission.title}，${slot.timeLabel}，$status'
          '${hasConflict ? '，冲突 ${slot.conflictMinutes.ceil()} 分钟' : ''}',
      button: true,
      child: Tooltip(
        message: '${slot.timeLabel} ${slot.detail.mission.title} · $status',
        child: Material(
          color: color,
          borderRadius: BorderRadius.circular(12),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            key: Key('all-mission-${slot.id}'),
            onTap: () => widget.onOpen(slot.detail),
            child: Stack(
              children: [
                Positioned.fill(
                  child: CustomPaint(painter: _ConflictPainter(slot)),
                ),
                Positioned(
                  left: 0,
                  top: 0,
                  bottom: 0,
                  child: Container(
                    width: 3,
                    color: hasConflict ? AppColors.error : AppColors.primary,
                  ),
                ),
                if (minutes >= 30)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 6,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          slot.timeLabel,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodyMedium,
                        ),
                        Text(
                          slot.detail.mission.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleMedium,
                        ),
                        if (minutes >= 45) ...[
                          const SizedBox(height: 2),
                          Text(
                            status,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodyMedium,
                          ),
                        ],
                        if (hasConflict && minutes >= 60)
                          InkWell(
                            onTap: () => _showConflicts(slot),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              child: Text(
                                '冲突 ${slot.conflictMinutes.ceil()} 分钟',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.labelMedium?.copyWith(
                                  color: AppColors.error,
                                ),
                              ),
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
    );
  }
}

/// 斜纹只覆盖实际重叠区间，不把整张任务卡涂成错误状态。
class _ConflictPainter extends CustomPainter {
  const _ConflictPainter(this.slot);
  final TimetableSlot slot;
  @override
  void paint(Canvas canvas, Size size) {
    for (final conflict in slot.conflicts) {
      final top =
          (conflict.start - slot.start) / (slot.end - slot.start) * size.height;
      final bottom =
          (conflict.end - slot.start) / (slot.end - slot.start) * size.height;
      final rect = Rect.fromLTRB(0, top, size.width, bottom);
      canvas.save();
      canvas.clipRect(rect);
      canvas.drawRect(
        rect,
        Paint()..color = AppColors.errorSoft.withValues(alpha: .8),
      );
      final paint = Paint()
        ..color = AppColors.error.withValues(alpha: .09)
        ..strokeWidth = 4;
      for (var x = -rect.height; x < size.width; x += 12) {
        canvas.drawLine(Offset(x, bottom), Offset(x + rect.height, top), paint);
      }
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _ConflictPainter oldDelegate) =>
      oldDelegate.slot != slot;
}

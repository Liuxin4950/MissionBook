import 'dart:async';

import 'package:flutter/material.dart';

import '../../../domain/entities/execution_event.dart';
import '../../../domain/entities/mission_phase.dart';
import '../../../domain/entities/mission_schedule_revision.dart';
import '../../../domain/rules/execution_time_rules.dart';
import '../../widgets/app_visibility.dart';
import 'mission_execution_display.dart';
import 'mission_phase_display.dart';

/// 列表与当前任务栏共用的实时时长。只重绘当前标签，不每秒查库或写状态。
/// 固定任务按计划窗口计时，自选任务从 START 推算；后台返回不补 Timer 次数。
class MissionLiveStatus extends StatefulWidget {
  const MissionLiveStatus({
    super.key,
    required this.phase,
    required this.events,
    this.schedule,
    this.includePhase = true,
    this.includeFocusLabel = true,
    this.clock = DateTime.now,
    this.maxLines,
  });
  final MissionPhase phase;
  final List<ExecutionEvent> events;
  final MissionScheduleRevision? schedule;
  final bool includePhase;

  /// 紧凑日程省略可视前缀，时长仍取自同一执行事件计算。
  final bool includeFocusLabel;
  final DateTime Function() clock;
  final int? maxLines;
  @override
  State<MissionLiveStatus> createState() => _MissionLiveStatusState();
}

class _MissionLiveStatusState extends State<MissionLiveStatus>
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
    _configure();
  }

  @override
  void didUpdateWidget(covariant MissionLiveStatus oldWidget) {
    super.didUpdateWidget(oldWidget);
    _configure();
  }

  void _configure() {
    if (!_appVisible ||
        !_tickerEnabled ||
        widget.phase != MissionPhase.running) {
      _timer?.cancel();
      _timer = null;
      return;
    }
    // 父列表重建不重置下一次刷新，否则高频通知可能让标签一直等不到下一秒。
    _timer ??= Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _appVisible = isAppVisible(state);
    _configure();
    if (mounted && _appVisible) setState(() {});
  }

  @override
  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final times = calculateExecutionTimes(
      widget.events,
      widget.clock().toUtc(),
      schedule: widget.schedule,
    );
    return Text(
      '${widget.includePhase ? '${phaseLabel(widget.phase)} · ' : ''}'
      '${widget.includeFocusLabel ? '专注 ' : ''}'
      '${focusDuration(times.focus)}${times.clockBehind ? ' · 请校时' : ''}',
      style: Theme.of(context).textTheme.bodySmall,
      maxLines: widget.maxLines,
      overflow: widget.maxLines == null ? null : TextOverflow.ellipsis,
    );
  }
}

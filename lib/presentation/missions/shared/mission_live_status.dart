import 'dart:async';

import 'package:flutter/material.dart';

import '../../../domain/entities/execution_event.dart';
import '../../../domain/entities/mission_phase.dart';
import '../../../domain/rules/execution_time_rules.dart';
import 'mission_execution_display.dart';
import 'mission_phase_display.dart';

/// 列表与当前任务栏共用的实时时长。只重绘当前标签，不每秒查库或写状态。
/// 运行从事件时刻推算；暂停和 END 冻结，重新显示时立即读时钟而非补数秒次数。
class MissionLiveStatus extends StatefulWidget {
  const MissionLiveStatus({
    super.key,
    required this.phase,
    required this.events,
    this.includePhase = true,
    this.clock = DateTime.now,
  });
  final MissionPhase phase;
  final List<ExecutionEvent> events;
  final bool includePhase;
  final DateTime Function() clock;
  @override
  State<MissionLiveStatus> createState() => _MissionLiveStatusState();
}

class _MissionLiveStatusState extends State<MissionLiveStatus>
    with WidgetsBindingObserver {
  Timer? _timer;
  bool _foreground = true;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _foreground =
        WidgetsBinding.instance.lifecycleState == null ||
        WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _configure();
  }

  @override
  void didUpdateWidget(covariant MissionLiveStatus oldWidget) {
    super.didUpdateWidget(oldWidget);
    _configure();
  }

  void _configure() {
    _timer?.cancel();
    if (_foreground &&
        TickerMode.valuesOf(context).enabled &&
        widget.phase == MissionPhase.running) {
      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() {});
      });
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    _configure();
    if (mounted && _foreground) setState(() {});
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
    );
    return Text(
      '${widget.includePhase ? '${phaseLabel(widget.phase)} · ' : ''}'
      '专注 ${focusDuration(times.focus)}${times.clockBehind ? ' · 请校时' : ''}',
      style: Theme.of(context).textTheme.bodySmall,
    );
  }
}

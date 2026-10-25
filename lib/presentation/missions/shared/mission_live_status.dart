import 'dart:async';

import 'package:flutter/material.dart';

import '../../../domain/entities/execution_event.dart';
import '../../../domain/entities/mission_phase.dart';
import '../../../domain/rules/execution_time_rules.dart';
import '../../widgets/app_visibility.dart';
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
    );
    return Text(
      '${widget.includePhase ? '${phaseLabel(widget.phase)} · ' : ''}'
      '专注 ${focusDuration(times.focus)}${times.clockBehind ? ' · 请校时' : ''}',
      style: Theme.of(context).textTheme.bodySmall,
    );
  }
}

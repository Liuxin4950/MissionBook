import 'dart:async';

import 'mission_service.dart';

/// 前台自动执行与系统唤醒共用的调度流程；Timer 只负责唤醒，事实由仓储写入。
class PlannedMissionScheduler {
  PlannedMissionScheduler({
    required this.missions,
    required this.now,
    this.scheduleInSystem,
    this.beforeRefresh,
    this.onError,
  });

  final MissionService missions;
  final DateTime Function() now;
  final Future<void> Function(DateTime? next)? scheduleInSystem;
  final Future<void> Function()? beforeRefresh;
  final void Function(Object error)? onError;
  StreamSubscription<void>? _changes;
  Timer? _timer;
  Timer? _retryTimer;
  Future<void>? _refreshing;
  bool _again = false;
  bool _disposed = false;

  Future<void> start() async {
    _changes ??= missions.changes.listen((_) => unawaited(refreshSafely()));
    await refresh();
  }

  Future<void> refreshSafely() async {
    try {
      await refresh();
    } catch (error) {
      onError?.call(error);
      if (!_disposed) {
        // 系统调度失败也保留已经算出的本地到点计时，另设一次恢复重试。
        _retryTimer?.cancel();
        _retryTimer = Timer(
          const Duration(seconds: 30),
          () => unawaited(refreshSafely()),
        );
      }
    }
  }

  Future<void> refresh() {
    if (_disposed) return Future.value();
    _again = true;
    return _refreshing ??= _run().whenComplete(() => _refreshing = null);
  }

  Future<void> _run() async {
    do {
      _again = false;
      _timer?.cancel();
      _retryTimer?.cancel();
      await beforeRefresh?.call();
      await missions.reconcileScheduledMissions();
      final snapshot = await missions.findPlannedSnapshot();
      final checkedAt = now();
      final hasRunning = snapshot.hasRunning;
      DateTime? next = snapshot.nextEndAt;
      if (next != null && !next.isAfter(checkedAt)) _again = true;
      for (final candidate in snapshot.candidates) {
        final at = candidate.start;
        // 已到点但被当前 RUNNING 阻塞时，等待下一次任务变化，避免零时长忙循环。
        if (!at.isAfter(checkedAt)) {
          final end = candidate.end;
          if (!hasRunning && end.isAfter(checkedAt)) {
            // 查询期间刚好跨过开始时刻时，再执行一次事务，不能漏掉这次唤醒。
            _again = true;
          }
          if (!hasRunning &&
              !end.isAfter(checkedAt) &&
              snapshot.refreshAfterExpiredCandidate) {
            // 查询过程中跨过整个时段：下一次候选查询会排除它，再寻找后续计划。
            _again = true;
          }
          continue;
        }
        if (next == null || at.isBefore(next)) next = at;
      }
      if (_again && next == null) next = checkedAt;
      if (!_disposed && next != null) {
        final delay = next.difference(now());
        _timer = Timer(
          delay.isNegative ? Duration.zero : delay,
          () => unawaited(refreshSafely()),
        );
      }
      // 先保住应用内到点唤醒；外部调度失败不能使本地计划随之失效。
      await scheduleInSystem?.call(next);
    } while (_again && !_disposed);
  }

  Future<void> dispose() async {
    _disposed = true;
    _timer?.cancel();
    _retryTimer?.cancel();
    await _changes?.cancel();
    await _refreshing;
  }
}

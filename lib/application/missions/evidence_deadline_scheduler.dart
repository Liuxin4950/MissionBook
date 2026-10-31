import 'dart:async';

import '../../domain/entities/mission.dart';
import 'mission_service.dart';

/// 前台材料截止调度：先经业务服务补算，再读取最近期限；不自行写任务事实。
class EvidenceDeadlineScheduler {
  EvidenceDeadlineScheduler({
    required this.missions,
    required this.now,
    this.onError,
    this.retryDelay = const Duration(seconds: 30),
  }) {
    if (retryDelay <= Duration.zero) throw ArgumentError('截止维护重试间隔必须大于零');
  }

  final MissionService missions;
  final DateTime Function() now;
  final void Function(Object error)? onError;
  final Duration retryDelay; // 失败及异常快照的恢复间隔。
  StreamSubscription<void>? _changes;
  Timer? _timer;
  Future<void>? _refreshing;
  bool _again = false;
  bool _foreground = true;
  bool _disposed = false;

  /// App 启动时挂接一次；后台不设置计时，回前台补算停留期间到期的任务。
  Future<void> start() async {
    if (_disposed) return;
    _changes ??= missions.changes.listen((_) => unawaited(refreshSafely()));
    await refreshSafely();
  }

  void setForeground(bool value) {
    if (_disposed) return;
    _foreground = value;
    if (value) {
      unawaited(refreshSafely());
    } else {
      _timer?.cancel();
    }
  }

  Future<void> refreshSafely() async {
    try {
      await refresh();
    } catch (error) {
      onError?.call(error);
      _schedule(retryDelay);
    }
  }

  /// 合并并发通知；补算引起的 changes 最多要求重读，不启动第二条并行写链。
  Future<void> refresh() {
    if (_disposed || !_foreground) return Future.value();
    _again = true;
    return _refreshing ??= _run().whenComplete(() => _refreshing = null);
  }

  Future<void> _run() async {
    var retriedOverdueSnapshot = false;
    do {
      _again = false;
      _timer?.cancel();
      await missions.reconcileEvidenceDeadlines();
      if (_disposed || !_foreground) return;
      final pending = await missions.findPendingEvidence();
      if (_disposed || !_foreground) return;
      DateTime? nearest;
      for (final detail in pending) {
        if (detail.mission.verificationPolicy !=
            VerificationPolicy.requiredEvidence) {
          continue;
        }
        final deadline = detail.schedule.evidenceDeadlineAt;
        if (deadline != null &&
            (nearest == null || deadline.isBefore(nearest))) {
          nearest = deadline;
        }
      }
      if (nearest != null) {
        final remaining = nearest.difference(now().toUtc());
        if (remaining <= Duration.zero) {
          // 查询期间跨过截止时立即补算一次；持续过期的异常快照按恢复间隔重试，避免零延时循环。
          if (!retriedOverdueSnapshot) {
            retriedOverdueSnapshot = true;
            _again = true;
          } else {
            _again = false;
            _schedule(retryDelay);
          }
        } else {
          _schedule(remaining);
        }
      }
    } while (_again && !_disposed && _foreground);
  }

  void _schedule(Duration delay) {
    if (_disposed || !_foreground) return;
    _timer?.cancel();
    _timer = Timer(delay, () => unawaited(refreshSafely()));
  }

  Future<void> dispose() async {
    _disposed = true;
    _timer?.cancel();
    await _changes?.cancel();
    final pending = _refreshing;
    if (pending == null) return;
    try {
      await pending;
    } catch (_) {
      // 自动刷新已由 refreshSafely 报告；释放资源不再次抛出同一错误。
    }
  }
}

import 'package:agent_core/agent_core.dart';
import 'package:timezone/timezone.dart' as tz;

import '../../domain/entities/mission_phase.dart';
import '../../domain/entities/scheduled_mission.dart';
import '../../domain/rules/scheduled_execution_rules.dart';
import '../missions/mission_service.dart';
import 'assistant_controller.dart';

/// 仅供本次判断使用的前台信号，不是任务事实或稳定记忆。
typedef ScreenUse = ({String id, String label, int seconds});

typedef ScreenNotice = ({String sessionId, String missionId, String message});

/// 结合实际排期决定是否开口；不授权任何工具写入。
class AssistantSupervision {
  AssistantSupervision(
    this._assistant,
    this._missions, {
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  final AssistantController _assistant;
  final MissionService _missions;
  final DateTime Function() _now;
  CancellationToken? _checking;
  bool _waiting = false;
  bool _closed = false;
  String? _seen;
  DateTime? _nextCheck;
  DateTime? _muteUntil;
  DateTime? _taskEnd;

  void invalidate() {
    _checking?.cancel();
  }

  void dismiss({required bool onlyLater}) {
    _muteUntil = onlyLater ? _now().add(const Duration(minutes: 5)) : _taskEnd;
    if (onlyLater) _seen = null;
    invalidate();
  }

  void close() {
    _closed = true;
    invalidate();
  }

  Future<ScreenNotice?> observe(
    ScreenUse sample, {
    required Future<bool> Function() isCurrent,
  }) async {
    final now = _now();
    if (_closed ||
        _waiting ||
        sample.seconds < 90 ||
        sample.id == _seen ||
        _assistant.isBusy ||
        (_muteUntil?.isAfter(now) ?? false) ||
        (_nextCheck?.isAfter(now) ?? false)) {
      return null;
    }
    _waiting = true;
    _nextCheck = now.add(const Duration(seconds: 45));
    final token = _checking = CancellationToken();
    bool active() => !_closed && !token.isCancelled && !_assistant.isBusy;
    Future<bool> valid() async => active() && await isCurrent() && active();
    try {
      final task = await _plannedNow(now);
      if (task == null || !await valid()) return null;
      _taskEnd = task.end;
      _seen = sample.id;
      final minutes = sample.seconds ~/ 60;
      final message =
          '现在安排了「${task.title}」。已使用 ${sample.label} 约 $minutes 分钟，需要我帮你回到任务吗？';
      final session = await _assistant.saveNotice(
        AssistantMessage(
          content: [TextBlock(text: message)],
          provider: 'mission_book',
          model: 'observation',
        ),
        token,
      );
      if (session == null || !active()) return null;
      _nextCheck = now.add(const Duration(minutes: 4));
      return (sessionId: session, missionId: task.id, message: message);
    } finally {
      _waiting = false;
      if (identical(_checking, token)) _checking = null;
    }
  }

  Future<({String id, String title, DateTime end})?> _plannedNow(
    DateTime now,
  ) async {
    final local = tz.TZDateTime.from(now, tz.getLocation('Asia/Shanghai'));
    String key(DateTime value) => value.toIso8601String().substring(0, 10);
    final candidates = <ScheduledMission>[
      ...await _missions.findScheduledOn(scheduledDate: key(local)),
      ...await _missions.findScheduledOn(
        scheduledDate: key(local.subtract(const Duration(days: 1))),
      ),
    ];
    for (final item in candidates) {
      if (item.phase != MissionPhase.notStarted &&
          item.phase != MissionPhase.running) {
        continue;
      }
      final start = item.schedule.fixedStartAt;
      if (start == null || start.isAfter(now)) continue;
      final end = fixedTimeSlotEnd(
        start,
        item.schedule.plannedDurationMinutes,
        item.events,
      );
      if (now.isBefore(end)) {
        return (id: item.mission.id, title: item.mission.title, end: end);
      }
    }
    return null;
  }
}

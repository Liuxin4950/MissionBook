import '../../domain/entities/mission_detail.dart';
import '../../domain/entities/mission_phase.dart';
import '../../domain/notifications/reminder_request.dart';
import '../../domain/rules/execution_time_rules.dart';

/// 前台与后台使用相同通知 id、动作身份和事实摘要，避免各造一套执行通知。
ReminderRequest executionReminder(
  MissionDetail detail,
  int notificationId, {
  DateTime? now,
}) {
  final id = detail.mission.id;
  final sequence = detail.lastSequence;
  final running = detail.phase == MissionPhase.running;
  final projectedAt = (now ?? DateTime.now()).toUtc();
  final times = calculateExecutionTimes(detail.events, projectedAt);
  final budget = currentBudget(
    times,
    detail.schedule.plannedDurationMinutes,
  ).inMinutes;
  final seconds = times.focus.inSeconds;
  String two(int value) => value.toString().padLeft(2, '0');
  final minuteSeconds = '${two(seconds ~/ 60 % 60)}:${two(seconds % 60)}';
  final focus = seconds >= 3600
      ? '${two(seconds ~/ 3600)}:$minuteSeconds'
      : minuteSeconds;
  return ReminderRequest(
    idempotencyKey: 'mission-$id-execution',
    notificationId: notificationId,
    missionId: id,
    scheduleRevisionId: detail.schedule.id,
    kind: running
        ? ReminderKind.executionRunning
        : ReminderKind.executionPaused,
    title: detail.mission.title,
    body:
        '${running ? '执行中' : '已暂停'} · 专注 $focus · 额度 $budget 分钟${times.clockBehind ? ' · 请校时' : ''}',
    focusMilliseconds: times.focus.inMilliseconds,
    projectedAt: projectedAt,
    budgetMinutes: budget,
    clockBehind: times.clockBehind,
    expectedSequence: sequence,
    candidateEventIds: {
      'pause': 'notif-pause-$id-$sequence',
      'resume': 'notif-resume-$id-$sequence',
    },
  );
}

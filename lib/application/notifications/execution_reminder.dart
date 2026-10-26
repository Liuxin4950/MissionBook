import '../../domain/entities/mission_detail.dart';
import '../../domain/entities/mission_phase.dart';
import '../../domain/notifications/reminder_request.dart';

/// 前台与后台使用相同通知 id、动作身份和事实摘要，避免各造一套执行通知。
ReminderRequest executionReminder(MissionDetail detail, int notificationId) {
  final id = detail.mission.id;
  final sequence = detail.lastSequence;
  final running = detail.phase == MissionPhase.running;
  return ReminderRequest(
    idempotencyKey: 'mission-$id-execution',
    notificationId: notificationId,
    missionId: id,
    scheduleRevisionId: detail.schedule.id,
    kind: running
        ? ReminderKind.executionRunning
        : ReminderKind.executionPaused,
    title: detail.mission.title,
    body: running ? '执行中，可点「停止」暂停并确认结束' : '已暂停，可点「继续」恢复执行',
    expectedSequence: sequence,
    candidateEventIds: {
      'pause': 'notif-pause-$id-$sequence',
      'resume': 'notif-resume-$id-$sequence',
    },
  );
}

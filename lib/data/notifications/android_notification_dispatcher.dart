import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

import '../../domain/notifications/reminder_request.dart';
import 'notification_dispatcher.dart';

/// Android 分发端：fln 的 zonedSchedule/立即显示/撤销。
///
/// 调度精度按 capabilities.exactAlarms 分档：有精确提醒权限用
/// exactAllowWhileIdle，否则退回 inexact 并由 Me 页提示可能延迟（§7.3）。
class AndroidNotificationDispatcher implements NotificationDispatcher {
  AndroidNotificationDispatcher({
    required FlutterLocalNotificationsPlugin plugin,
    required bool exactAlarmsAllowed,
  }) : _plugin = plugin,
       _exactAlarmsAllowed = exactAlarmsAllowed;

  final FlutterLocalNotificationsPlugin _plugin;
  final bool _exactAlarmsAllowed;

  // 按通知种类提供动作按钮（§7.2）：开始提醒「开始/延后」，
  // 执行中「停止」、暂停中「继续」；事实类按钮拉起应用走同一工作流。
  NotificationDetails _detailsFor(ReminderKind kind) => NotificationDetails(
    android: AndroidNotificationDetails(
      'mission_reminders',
      '任务提醒',
      channelDescription: '固定任务的开始提醒与执行通知',
      importance: Importance.high,
      priority: Priority.high,
      actions: switch (kind) {
        ReminderKind.startReminder => [
          AndroidNotificationAction('start', '开始', showsUserInterface: true),
          AndroidNotificationAction(
            'snooze',
            '延后 15 分钟',
            showsUserInterface: true,
          ),
        ],
        ReminderKind.executionRunning => [
          AndroidNotificationAction('stop', '停止', showsUserInterface: true),
        ],
        ReminderKind.executionPaused => [
          AndroidNotificationAction('resume', '继续', showsUserInterface: true),
        ],
      },
    ),
  );

  @override
  bool get supportsScheduling => true;

  @override
  Future<void> schedule(ReminderRequest request) async {
    final at = request.scheduledFor;
    if (at == null) return show(request);
    await _plugin.zonedSchedule(
      id: request.notificationId,
      title: request.title,
      body: request.body,
      scheduledDate: tz.TZDateTime.from(at, tz.local),
      notificationDetails: _detailsFor(request.kind),
      androidScheduleMode: _exactAlarmsAllowed
          ? AndroidScheduleMode.exactAllowWhileIdle
          : AndroidScheduleMode.inexactAllowWhileIdle,
      payload: request.toPayload(),
    );
  }

  @override
  Future<void> cancel(int notificationId) => _plugin.cancel(id: notificationId);

  @override
  Future<void> show(ReminderRequest request) => _plugin.show(
    id: request.notificationId,
    title: request.title,
    body: request.body,
    notificationDetails: _detailsFor(request.kind),
    payload: request.toPayload(),
  );
}

/// 判断当前进程是否在 Android 上（供装配层选择分发端）。
bool get isAndroidTarget =>
    !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

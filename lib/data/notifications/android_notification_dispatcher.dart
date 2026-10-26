import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
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
  bool _exactAlarmsAllowed;
  void updateExactAlarmPermission(bool allowed) =>
      _exactAlarmsAllowed = allowed;

  static const _appearance = MethodChannel(
    'mission_book/notification_appearance',
  );

  // 提前预告点击正文打开详情；旧版开始通知仅保留开始动作，
  // 执行中「停止」、暂停中「继续」；事实类按钮拉起应用走同一工作流。
  NotificationDetails _detailsFor(ReminderRequest request) {
    final kind = request.kind;
    final executing =
        kind == ReminderKind.executionRunning ||
        kind == ReminderKind.executionPaused;
    final running = kind == ReminderKind.executionRunning;
    final advancing =
        running &&
        !request.clockBehind &&
        request.focusMilliseconds != null &&
        request.projectedAt != null;
    return NotificationDetails(
      android: AndroidNotificationDetails(
        executing ? 'mission_execution_v2' : 'mission_reminders',
        executing ? '执行状态' : '任务提醒',
        channelDescription: executing ? '专注计时与暂停任务，静默更新' : '固定任务开始前的提醒',
        icon: running
            ? 'ic_stat_running'
            : kind == ReminderKind.executionPaused
            ? 'ic_stat_paused'
            : 'ic_stat_mission',
        importance: executing ? Importance.low : Importance.high,
        priority: executing ? Priority.low : Priority.high,
        playSound: !executing,
        enableVibration: !executing,
        silent: executing,
        onlyAlertOnce: true,
        ongoing: running,
        autoCancel: !executing,
        // 标准通知也带系统秒表：外观扩展不可用时，退后台仍能显示累计 Focus。
        showWhen: !executing || advancing,
        usesChronometer: advancing,
        when: advancing
            ? request.projectedAt!.millisecondsSinceEpoch -
                  request.focusMilliseconds!
            : null,
        channelShowBadge: !executing,
        color: const Color(0xFF214D3E),
        subText: executing ? (running ? '正在专注' : '已暂停') : '计划提醒',
        styleInformation: BigTextStyleInformation(
          request.body,
          contentTitle: request.title,
        ),
        actions: switch (kind) {
          ReminderKind.upcomingReminder => [],
          ReminderKind.startReminder => [
            AndroidNotificationAction('start', '开始', showsUserInterface: true),
          ],
          ReminderKind.executionRunning => [
            AndroidNotificationAction(
              'stop',
              '停止',
              showsUserInterface: true,
              cancelNotification: false,
            ),
          ],
          ReminderKind.executionPaused => [
            AndroidNotificationAction(
              'resume',
              '继续',
              showsUserInterface: true,
              cancelNotification: false,
            ),
          ],
        },
      ),
    );
  }

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
      notificationDetails: _detailsFor(request),
      androidScheduleMode: _exactAlarmsAllowed
          ? AndroidScheduleMode.exactAllowWhileIdle
          : AndroidScheduleMode.inexactAllowWhileIdle,
      payload: request.toPayload(),
    );
  }

  @override
  Future<void> cancel(int notificationId) async {
    // 先取消待呈现的自定义内容，再撤系统通知，避免通知入队等待期间被补绘。
    try {
      await _appearance.invokeMethod<void>('invalidate', {
        'id': notificationId,
      });
    } on PlatformException catch (error) {
      debugPrint('通知外观通道不可用，继续撤销系统通知：$error');
    } on MissingPluginException {
      debugPrint('通知外观通道未注册，继续撤销系统通知');
    }
    await _plugin.cancel(id: notificationId);
  }

  @override
  Future<void> show(ReminderRequest request) async {
    await _plugin.show(
      id: request.notificationId,
      title: request.title,
      body: request.body,
      notificationDetails: _detailsFor(request),
      payload: request.toPayload(),
    );
    if (request.focusMilliseconds != null) {
      // 保留插件生成的 PendingIntent、payload 和按钮，只定制系统内容区域。
      // 主引擎与计划任务后台引擎都注册此通道，通知动作仍回到统一业务入口。
      try {
        await _appearance.invokeMethod<void>('decorateExecution', {
          'id': request.notificationId,
          'title': request.title,
          'body': request.body,
          'running': request.kind == ReminderKind.executionRunning,
          'focusMilliseconds': request.focusMilliseconds,
          'projectedAt': request.projectedAt?.millisecondsSinceEpoch,
          'budgetMinutes': request.budgetMinutes,
          'clockBehind': request.clockBehind,
        });
      } on PlatformException catch (error) {
        debugPrint('通知外观不可用，保留标准计时通知：$error');
      } on MissingPluginException {
        debugPrint('通知外观通道未注册，保留标准计时通知');
      }
    }
  }
}

/// 判断当前进程是否在 Android 上（供装配层选择分发端）。
bool get isAndroidTarget =>
    !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

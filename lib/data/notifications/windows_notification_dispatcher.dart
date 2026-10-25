import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

import '../../domain/notifications/reminder_request.dart';
import 'notification_dispatcher.dart';

/// Windows 分发端：C++/WinRT Toast。
///
/// 分发形态差异（规格 §7.3）：非 MSIX 打包时系统不允许撤销已排调度项，
/// [cancel] 会如实降级为 no-op 并由对账负责不再重排——不用“覆盖成失效态”
/// 冒充撤销。N3.1 实测（待触发取消/通知中心清除/退出后回调/MSIX 行为）
/// 定档后在此更新能力位与注释。
class WindowsNotificationDispatcher implements NotificationDispatcher {
  WindowsNotificationDispatcher({
    required FlutterLocalNotificationsPlugin plugin,
    this.canCancelScheduled = true,
  }) : _plugin = plugin;

  final FlutterLocalNotificationsPlugin _plugin;

  /// 非 MSIX 直发形态下为 false；实测后由装配层传入。
  final bool canCancelScheduled;

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
      notificationDetails: const NotificationDetails(),
      // Windows 不使用该参数，但插件签名要求统一传入。
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      payload: request.toPayload(),
    );
  }

  @override
  Future<void> cancel(int notificationId) async {
    // 撤销不了就明确不撤：残留提醒点击进入应用显示“任务已取消/已开始”。
    if (!canCancelScheduled) return;
    await _plugin.cancel(id: notificationId);
  }

  @override
  Future<void> show(ReminderRequest request) => _plugin.show(
    id: request.notificationId,
    title: request.title,
    body: request.body,
    notificationDetails: const NotificationDetails(),
    payload: request.toPayload(),
  );
}

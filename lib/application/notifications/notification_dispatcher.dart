import '../../domain/notifications/reminder_request.dart';

/// 系统通知分发端口：调度、撤销、立即显示。
///
/// 平台实现（Android/Windows）只做“把提醒交给系统”，不含业务判断；
/// 不支持的平台用 [UnsupportedNotificationDispatcher] 明确降级。
abstract class NotificationDispatcher {
  /// 是否支持真正的定时调度与撤销（N3.1 实测后按平台定档）。
  bool get supportsScheduling;

  /// 调度（或同幂等键覆盖）一条提醒。
  Future<void> schedule(ReminderRequest request);

  /// 撤销一条提醒。非 MSIX 的 Windows 无法撤销已排调度项，
  /// 实现必须如实降级，不得用“覆盖成失效态”冒充撤销。
  Future<void> cancel(int notificationId);

  /// 立即显示（过期未送达的补发、执行通知刷新）。
  Future<void> show(ReminderRequest request);
}

/// 不支持系统通知的平台（如 Web 预览）：全部 no-op 且如实上报不支持。
class UnsupportedNotificationDispatcher implements NotificationDispatcher {
  const UnsupportedNotificationDispatcher();

  @override
  bool get supportsScheduling => false;

  @override
  Future<void> schedule(ReminderRequest request) async {}

  @override
  Future<void> cancel(int notificationId) async {}

  @override
  Future<void> show(ReminderRequest request) async {}
}

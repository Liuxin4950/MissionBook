/// 提醒服务需要的当前排期送达状态。
abstract interface class ReminderStatus {
  bool get delivered;
  bool get waitingDelivered;
}

/// 提醒偏好和系统通知编号的持久化契约。
abstract interface class ReminderStore {
  int get reminderLeadMinutes;
  Set<String> get synchronizedMissions;
  Map<String, int> get notificationIds;
  ReminderStatus? preferenceOf(String missionId);
  Future<void> load();
  Future<void> setReminderLeadMinutes(int minutes);
  Future<void> rememberSynchronizedMissions(Set<String> ids);
  Future<int> notificationIdOf(String key);
  Future<void> markDelivered(String missionId);
  Future<void> markWaitingDelivered(String missionId);
  Future<void> register({
    required String missionId,
    required String scheduleRevisionId,
  });
  Future<void> discard(String missionId);
}

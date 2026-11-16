/// 首次体验状态是本机 UI 偏好，不属于任务、目标或助手业务事实。
///
/// 它只记录用户是否已经看过并结束新手引导；引导本身不申请权限、也不写入业务数据库。
abstract interface class OnboardingStore {
  Future<bool> readCompleted();

  Future<void> markCompleted();
}

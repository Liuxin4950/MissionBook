/// 任务仓储的显式调度维护契约。
abstract interface class MissionSchedulingRepository {
  /// 重读固定日程，先停止到期执行，再开始到点任务；已有 RUNNING 时保留它。
  /// STOP 独立提交后再尝试 START；开始失败不能回滚停止。
  /// 固定 START 使用计划起点，STOP 使用应结束时刻；重复唤醒不重复写事件。
  Future<List<String>> reconcileScheduledMissions();

  /// 用户动作前单独结算到期执行；成功停止的事实不随旧命令失败回滚。
  Future<List<String>> reconcileScheduledEnds();
}

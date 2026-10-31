import '../entities/scheduled_mission.dart';
import '../entities/mission_detail.dart';
import '../entities/mission_ownership.dart';

/// 任务仓储的纯查询契约。
abstract interface class MissionReadRepository {
  Future<List<MissionGoalChoices>> findGoalChoices();

  Future<MissionOwnershipInfo?> findOwnershipInfo(MissionOwnership ownership);

  Future<List<MissionDetail>> findForGoal(String goalId);

  /// 跨日的执行中/暂停/待确认任务，供当前任务入口恢复；执行中优先。
  Future<List<MissionDetail>> findActive();

  /// 所有已结束记录，按 END 时间倒序，复用相同事实查询。
  Future<List<MissionDetail>> findFinished();

  /// 取消记录单独列出，不冒充执行历史；按取消时刻倒序。
  Future<List<MissionDetail>> findCancelled();

  Future<List<MissionDetail>> findAllDetails();

  /// 按唯一编号读取任务、最大版本号的排期和执行方案；包含已取消任务。
  /// 任务不存在返回 null；关联数据不完整或无法转换时抛错，不伪装成“未找到”。
  /// 一次读取应取得一致的快照，且不修改任何已有记录。
  Future<MissionDetail?> findDetail(String missionId);

  /// 查询一次所选计划日期的任务，每个任务只返回最大版本号的当前排期。
  /// 固定时间任务按开始时刻升序在前，自选任务按创建时刻升序随后；
  /// 同值按任务 id 排序。包含取消任务，页面将其单独折叠。
  /// Future 完成时返回这一刻的列表；再次刷新时由页面重新调用。
  Future<List<ScheduledMission>> findScheduledOn(String scheduledDate);
}

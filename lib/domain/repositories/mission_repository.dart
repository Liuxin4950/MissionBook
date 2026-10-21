import '../entities/mission.dart'; // 任务
import '../entities/execution_plan.dart'; // 任务计划
import '../entities/mission_schedule_revision.dart'; // 任务安排
import '../entities/scheduled_mission.dart';

// 任务仓储接口：约定任务相关的数据访问能力。
abstract interface class MissionRepository {
  // 查询一次所选计划日期的任务，每个任务只返回最大版本号的当前排期。
  // 固定时间任务按开始时刻升序在前，自选任务按创建时刻升序随后；
  // 同值按任务 id 排序。包含取消任务，页面将其单独折叠。
  // Future 完成时返回这一刻的列表；再次刷新时由页面重新调用。
  Future<List<ScheduledMission>> findScheduledOn(String scheduledDate);

  // 创建一个完整任务。
  //
  // mission：任务的基本信息。
  // initialSchedule：该任务的第一条排期，版本号必须为 1。
  // executionPlan：该任务的执行方案。
  //
  // 两个关联对象的 missionId 必须等于 mission.id。
  // 新任务必须尚未取消。
  //
  // 实现必须使用同一个事务保存这三个对象：
  // 全部成功才算完成，任何一步失败都不能留下部分记录。
  //
  // 成功时正常完成；校验或保存失败时，通过异常报告失败。
  Future<void> create({
    required Mission mission,
    required MissionScheduleRevision initialSchedule,
    required ExecutionPlan executionPlan,
  });
}

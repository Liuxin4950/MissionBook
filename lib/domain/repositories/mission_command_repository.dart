import '../entities/mission.dart';
import '../entities/execution_plan.dart';
import '../entities/mission_schedule_revision.dart';
import '../entities/mission_detail.dart';
import '../entities/execution_command.dart';
import '../entities/execution_event.dart';
import '../entities/mission_ownership.dart';
import '../entities/user_execution_report.dart';

/// 任务仓储的事实命令契约。
abstract interface class MissionCommandRepository {
  /// 固定身份的动作意图；取得写权限后重读、校验并原子追加必要事实。
  Future<ExecutionEvent> execute(ExecutionCommand command);

  /// original 是打开编辑页时读到的快照，schedule 是本次完整排期提案。
  /// 同一事务重读并检查可编辑性、旧快照，再更新名称/具体目标。
  /// 排期有变化才追加下一版本；相同请求不重复写入，旧版本与其余字段保留。
  /// 旧快照冲突或任务已取消时抛 MissionEditConflict，不覆盖新事实。
  Future<void> edit({
    required MissionDetail original,
    required String title,
    required String objective,
    required MissionScheduleRevision schedule,
    ExecutionPlanContent? content,
    VerificationPolicy? verificationPolicy,
    String? verificationCriteria,
    MissionOwnership? ownership, // 省略保留原归属；显式传空选择表示改为独立任务。
    String? description,
    String? why,
    bool updateContext = false, // true 时按表单值写说明和 Why，允许明确清空。
    String? operationId, // 外部入口提供固定身份时，业务事实与回执同事务保存。
  });

  /// 在写事务中重读任务并取消，只修改 cancelledAt 和 updatedAt。
  /// 不存在时抛 StateError；已取消时直接成功，保留首次取消时间。
  /// 事务内检查无执行事件；取消与开始竞争时只有一个能成功。
  Future<void> cancel(String missionId, {String? operationId});

  /// 创建一个完整任务。
  ///
  /// mission：任务的基本信息。
  /// initialSchedule：该任务的第一条排期，版本号必须为 1。
  /// executionPlan：该任务的执行方案。
  ///
  /// 两个关联对象的 missionId 必须等于 mission.id。
  /// 新任务必须尚未取消。
  ///
  /// 实现必须使用同一个事务保存这三个对象：
  /// 全部成功才算完成，任何一步失败都不能留下部分记录。
  ///
  /// 成功时正常完成；校验或保存失败时，通过异常报告失败。
  Future<void> create({
    required Mission mission,
    required MissionScheduleRevision initialSchedule,
    required ExecutionPlan executionPlan,
  });

  /// 原子追加用户时间声明和必要的 END；重复编号只确认同一请求。
  Future<void> reportExecution(
    UserExecutionReport report, {
    required int expectedSequence,
    required String scheduleId,
    UserReportedResult? result,
    bool? submitOptionalEvidence,
  });
}

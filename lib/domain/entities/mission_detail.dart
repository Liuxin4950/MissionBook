import 'execution_plan.dart';
import 'mission.dart';
import 'mission_schedule_revision.dart';

/// 编辑期间原任务已变化；保留当前草稿，由用户重新读取后决定怎样修改。
class MissionEditConflict implements Exception {
  const MissionEditConflict(this.message);
  final String message;
}

/// 【查询组合】任务＋最新排期＋执行方案，供详情页读取。
///
/// 列表只需要 Mission 和排期；详情还需要方案，所以单独组合这三个已有对象。
/// 由仓储读取三张表后组成，没有对应的独立数据库表；
/// 不复制各对象的字段，也不保存另一份可写任务状态。
class MissionDetail {
  const MissionDetail({
    required this.mission,
    required this.schedule,
    required this.executionPlan,
  });

  final Mission mission;
  final MissionScheduleRevision schedule;
  final ExecutionPlan executionPlan;
}

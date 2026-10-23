import 'execution_plan.dart';
import 'mission.dart';
import 'mission_schedule_revision.dart';
import 'execution_event.dart';
import 'failure_record.dart';
import 'mission_phase.dart';
import '../rules/execution_event_rules.dart';

/// 编辑期间原任务已变化；保留当前草稿，由用户重新读取后决定怎样修改。
class MissionEditConflict implements Exception {
  const MissionEditConflict(this.message);
  final String message;
}

/// 【查询组合】任务、最新排期、方案及完整执行/失败事实，供三个任务页面共用。
///
/// 由仓储在同一读事务读取五张表后组成，没有对应的独立数据库表；
/// 不复制各对象的字段，也不保存另一份可写任务状态。
class MissionDetail {
  const MissionDetail({
    required this.mission,
    required this.schedule,
    required this.executionPlan,
    this.events = const [],
    this.failures = const [],
  });

  final Mission mission;
  final MissionScheduleRevision schedule;
  final ExecutionPlan executionPlan;
  // 仓储从同一次读事务取得完整时间线，不是某天或某页的片段。
  final List<ExecutionEvent> events;
  final List<FailureRecord> failures;
  int get lastSequence => events.isEmpty ? 0 : events.last.sequence;
  MissionPhase get phase =>
      deriveSelfReportMissionPhase(mission, events, failures);
}

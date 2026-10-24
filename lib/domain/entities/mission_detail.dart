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

/// 【查询组合】一次任务详情查询的结果，供详情、执行和记录页共用。
/// 仓储在同一读事务中组装，没有对应的独立数据库表。
class MissionDetail {
  const MissionDetail({
    required this.mission, // 任务本身：编号、标题、取消时刻和验证策略。
    required this.schedule, // 最新排期：安排哪天、几点、计划多久。
    required this.executionPlan, // 行动方案：具体目标和步骤。
    this.events = const [], // 完整执行记录：开始、暂停等；无记录时为空列表。
    this.failures = const [], // 失败事实；没有失败记录时为空列表。
  });

  final Mission mission;
  final MissionScheduleRevision schedule;
  final ExecutionPlan executionPlan;
  // 仓储从同一次读事务取得完整时间线，不是某天或某页的片段。
  final List<ExecutionEvent> events;
  final List<FailureRecord> failures;
  // 没有事件时为0；开始命令用它检查页面是否过期，仓储再分配新序号1。
  int get lastSequence => events.isEmpty ? 0 : events.last.sequence;
  // get 是按需计算的属性：读取 detail.phase 时，根据事实重新计算，结果不写回库。
  // 此处没有传 schedule/执行方案；它们负责计划和展示，不决定 START 是否发生。
  MissionPhase get phase =>
      deriveSelfReportMissionPhase(mission, events, failures);
}

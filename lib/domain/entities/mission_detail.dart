import 'execution_plan.dart';
import 'mission.dart';
import 'mission_schedule_revision.dart';
import 'execution_event.dart';
import 'failure_record.dart';
import 'evidence.dart';
import 'mission_phase.dart';
import 'mission_ownership.dart';
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
    this.evidence = const [], // 同一快照内的全部正式材料；页面草稿不参与阶段计算。
    this.ownershipInfo, // 同次查询读取的目标名称与路径，独立任务为 null。
  });

  final Mission mission;
  final MissionScheduleRevision schedule;
  final ExecutionPlan executionPlan;
  // 仓储从同一次读事务取得完整时间线，不是某天或某页的片段。
  final List<ExecutionEvent> events;
  final List<FailureRecord> failures;
  final List<Evidence> evidence;
  // 默认只展示未被后续修正替代的材料；完整 evidence 保留供历史展开。
  List<Evidence> get effectiveEvidence {
    final replaced = {
      for (final item in evidence)
        if (item.supersedesEvidenceId != null) item.supersedesEvidenceId!,
    };
    return List.unmodifiable(
      evidence.where((item) => !replaced.contains(item.id)),
    );
  }

  final MissionOwnershipInfo? ownershipInfo;
  // 没有事件时为0；开始命令用它检查页面是否过期，仓储再分配新序号1。
  int get lastSequence => events.isEmpty ? 0 : events.last.sequence;

  /// 用户报告“已完成”的那条 END 事件；没有报告完成时为 null。
  ///
  /// 每个任务最多一条 END（时间线核心保证），所以找到的第一条就是唯一一条。
  /// 注意：这只是用户的完成自报，不代表材料已提交、验证通过或技能掌握。
  ExecutionEvent? get completionReport {
    for (final event in events) {
      if (event.type == ExecutionEventType.end &&
          event.userReportedResult == UserReportedResult.completed) {
        return event;
      }
    }
    return null;
  }

  /// 是否有 END 事件报告“已完成”。
  ///
  /// 全站“完成记录/完成日期”判定统一走这两个属性，页面不再各自
  /// 重写“END 且 COMPLETED”的比较逻辑，防止口径分叉。
  bool get endReportedCompleted => completionReport != null;
  // get 是按需计算的属性：读取 detail.phase 时，根据事实重新计算，结果不写回库。
  // 排期提供材料截止等条件；START 是否发生仍只看已保存的执行事实。
  MissionPhase get phase =>
      deriveMissionPhase(mission, events, failures, evidence, schedule);
}

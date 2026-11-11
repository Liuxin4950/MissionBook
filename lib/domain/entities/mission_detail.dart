import 'execution_plan.dart';
import 'mission.dart';
import 'mission_schedule_revision.dart';
import 'execution_event.dart';
import 'failure_record.dart';
import 'evidence.dart';
import 'mission_phase.dart';
import 'mission_ownership.dart';
import '../rules/execution_event_rules.dart';
import 'user_execution_report.dart';

/// 编辑期间原任务已变化；保留当前草稿，由用户重新读取后决定怎样修改。
class MissionEditConflict implements Exception {
  const MissionEditConflict(this.message);
  final String message;
}

/// 【查询组合】一次任务详情查询的结果，供详情、执行和记录页共用。
/// 仓储在同一读事务中组装，没有对应的独立数据库表。
class MissionDetail {
  MissionDetail({
    required this.mission, // 任务本身：编号、标题、取消时刻和验证策略。
    required this.schedule, // 最新排期：安排哪天、几点、计划多久。
    required this.executionPlan, // 行动方案：具体目标和步骤。
    List<ExecutionEvent> events = const [], // 完整执行记录：开始、暂停等；无记录时为空列表。
    List<FailureRecord> failures = const [], // 失败事实；没有失败记录时为空列表。
    List<Evidence> evidence = const [], // 同一快照内的全部正式材料；页面草稿不参与阶段计算。
    this.ownershipInfo, // 同次查询读取的目标名称与路径，独立任务为 null。
    List<UserExecutionReport> userReports = const [],
  }) : events = List.unmodifiable(events),
       failures = List.unmodifiable(failures),
       evidence = List.unmodifiable(evidence),
       userReports = List.unmodifiable(userReports) {
    _phase = deriveMissionPhase(
      mission,
      this.events,
      this.failures,
      this.evidence,
      schedule,
    );
  }

  final Mission mission;
  final MissionScheduleRevision schedule;
  final ExecutionPlan executionPlan;
  // 仓储从同一次读事务取得完整时间线，不是某天或某页的片段。
  final List<ExecutionEvent> events;
  final List<FailureRecord> failures;
  final List<Evidence> evidence;
  final List<UserExecutionReport> userReports;
  UserExecutionReport? get effectiveUserReport => _effectiveUserReport;
  late final UserExecutionReport? _effectiveUserReport =
      _findEffectiveUserReport();

  UserExecutionReport? _findEffectiveUserReport() {
    final replaced = userReports
        .map((r) => r.supersedesId)
        .whereType<String>()
        .toSet();
    return userReports.where((r) => !replaced.contains(r.id)).firstOrNull;
  }

  String? get effectiveOccurrenceDate {
    if (effectiveUserReport != null) return effectiveUserReport!.occurrenceDate;
    if (events.isEmpty ||
        !events.any((e) => e.type == ExecutionEventType.end)) {
      return null;
    }
    // 补记的 END 记录的是补报时刻，实际发生日期取原计划日期。
    if (events.any(
      (e) => e.type == ExecutionEventType.end && e.isRetrospective,
    )) {
      return schedule.scheduledDate;
    }
    final instant =
        events
            .where((e) => e.type == ExecutionEventType.stop)
            .firstOrNull
            ?.occurredAt ??
        events.last.occurredAt;
    final local = instant.toLocal();
    return '${local.year.toString().padLeft(4, '0')}-${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')}';
  }

  // 默认只展示未被后续修正替代的材料；完整 evidence 保留供历史展开。
  List<Evidence> get effectiveEvidence => _effectiveEvidence;
  late final List<Evidence> _effectiveEvidence = _findEffectiveEvidence();

  List<Evidence> _findEffectiveEvidence() {
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
  // 每份不可变快照只经唯一核心推导一次；查询到新事实时创建新快照，阶段不写回库。
  late final MissionPhase _phase;
  MissionPhase get phase => _phase;
}

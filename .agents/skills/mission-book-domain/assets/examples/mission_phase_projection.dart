/// A pure phase projection sample derived from Mission Book facts.
///
/// This example is not a persistence model or a complete event-sequence
/// validator. The repository/workflow must validate ordering, timestamps,
/// uniqueness, and domain transitions in the database transaction.

enum MissionPhase { notStarted, running, paused, evidencePending, closed, cancelled }
enum VerificationPolicy { selfReport, optionalEvidence, requiredEvidence }
enum ExecutionEventType { start, pause, resume, extend, end }
enum UserReportedResult { completed, notCompleted }

final class ExecutionEventFact {
  const ExecutionEventFact({                                        // 表示不可变的已有执行事实。
    required this.type,
    this.reportedResult,
    this.submitOptionalEvidence,
  });

  final ExecutionEventType type;                                    // 事件的业务类别。
  final UserReportedResult? reportedResult;                         // 仅 END 具有完成报告。
  final bool? submitOptionalEvidence;                               // 仅允许 END 完成且 OPTIONAL 使用。
}

final class MissionFacts {
  MissionFacts({                                                    // 构造查询投影的不可变输入快照。
    required this.policy,
    required List<ExecutionEventFact> events,
    this.isCancelled = false,
    this.hasFormalEvidence = false,
    this.isOptionalEvidenceWaived = false,
    this.hasEvidenceDeadlineFailure = false,
  }) : events = List<ExecutionEventFact>.unmodifiable(events);       // 防止调用方后来更改事件序列。

  final VerificationPolicy policy;                                  // 当前任务已锁定的验证策略。
  final List<ExecutionEventFact> events;                            // 按 sequence 排序、不可变的事件快照。
  final bool isCancelled;                                           // cancelledAt != null 的查询结果。
  final bool hasFormalEvidence;                                     // 正式 Evidence 查询结果，非独立事实字段。
  final bool isOptionalEvidenceWaived;                              // evidenceWaivedAt != null 的查询结果。
  final bool hasEvidenceDeadlineFailure;                            // 唯一的截止 FailureRecord 查询结果。
}

MissionPhase deriveMissionPhase(MissionFacts facts) {               // 不写数据库，也不缓存 Phase。
  if (facts.isCancelled) {                                          // 取消只允许 START 之前发生。
    if (facts.events.isNotEmpty) {                                   // 严禁取消和执行事件同时存在。
      throw StateError('Cancelled mission has events');            // 显式暴露损坏的事实组合。
    }
    return MissionPhase.cancelled;                                   // 取消与执行未完成不同。
  }

  if (facts.events.isEmpty) {                                        // 没有执行历史，仍待开始。
    return MissionPhase.notStarted;                                  // 排期早于当前日期也不自动 START。
  }
  if (facts.events.first.type != ExecutionEventType.start) {       // 第一条必须 START。
    throw StateError('Missing initial START event');                // 无法安全推断受损历史。
  }

  final ends = facts.events.where(                                   // 查找唯一 END 事实。
    (event) => event.type == ExecutionEventType.end,
  ).toList();
  if (ends.length > 1 || (ends.isNotEmpty && facts.events.last.type != ExecutionEventType.end)) {
    throw StateError('Invalid END event ordering');                 // END 必须唯一并在事件尾部。
  }

  if (ends.isEmpty) {                                                // 未提交执行报告，仍在执行或暂停。
    for (final event in facts.events.reversed) {                     // 忽略 EXTEND，查最后一次切换。
      switch (event.type) {
        case ExecutionEventType.pause:
          return MissionPhase.paused;                                // 暂停期间停止累计 Focus。
        case ExecutionEventType.start:
        case ExecutionEventType.resume:
          return MissionPhase.running;                               // 只有合法历史才保证全局唯一。
        case ExecutionEventType.extend:
          continue;                                                  // 延长不改变运行/暂停阶段。
        case ExecutionEventType.end:
          throw StateError('END inconsistency');                    // 防御不可能的事件组合。
      }
    }
    throw StateError('No execution transition');                    // 不允许无法解析的历史。
  }

  final end = ends.single;                                           // END 中唯一保存用户报告。
  final UserReportedResult? result = end.reportedResult;             // 未报告并非另一条可写 phase。
  if (result == null) {                                              // 检查来自 DB 的原始事实有效性。
    throw StateError('END result is required');                     // 不猜测用户是否完成。
  }
  if (result == UserReportedResult.notCompleted) {                   // 未完成会由 workflow 写 FailureRecord。
    return MissionPhase.closed;                                      // END 后任务关闭。
  }

  return switch (facts.policy) {                                     // 所有策略显式穷举。
    VerificationPolicy.selfReport => MissionPhase.closed,           // 用户自报足以直接关闭。
    VerificationPolicy.optionalEvidence =>
      end.submitOptionalEvidence == true &&                         // 用户明确选择稍后交材料。
              !facts.hasFormalEvidence &&                            // 仍没有首批正式材料。
              !facts.isOptionalEvidenceWaived                        // 用户还没有主动跳过。
          ? MissionPhase.evidencePending                              // 仍处于待补材料。
          : MissionPhase.closed,                                      // 其余可选材料情形关闭。
    VerificationPolicy.requiredEvidence =>
      facts.hasFormalEvidence || facts.hasEvidenceDeadlineFailure    // 提交或截止超时二选一。
          ? MissionPhase.closed                                      // 原完成报告保持 COMPLETED。
          : MissionPhase.evidencePending,                             // 未提交且未超时时待补材料。
  };
}

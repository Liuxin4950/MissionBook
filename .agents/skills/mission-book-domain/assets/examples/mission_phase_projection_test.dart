import 'package:test/test.dart';

import 'mission_phase_projection.dart';

void main() {
  test('EXTEND does not resume a paused mission', () {           // 额外分钟不隐式修改执行阶段。
    final facts = MissionFacts(                                  // 只投影已保存事实。
      policy: VerificationPolicy.selfReport,
      events: const [
        ExecutionEventFact(type: ExecutionEventType.start),
        ExecutionEventFact(type: ExecutionEventType.pause),
        ExecutionEventFact(type: ExecutionEventType.extend),
      ],
    );
    expect(deriveMissionPhase(facts), MissionPhase.paused);       // 仍暂停，不计算 Focus。
  });

  test('required evidence remains pending until submission or failure', () {
    final facts = MissionFacts(                                  // 已结束且报告完成，但未提交材料。
      policy: VerificationPolicy.requiredEvidence,
      events: [
        ExecutionEventFact(type: ExecutionEventType.start),
        ExecutionEventFact(
          type: ExecutionEventType.end,
          reportedResult: UserReportedResult.completed,
        ),
      ],
    );
    expect(deriveMissionPhase(facts), MissionPhase.evidencePending); // END 不意味着首批材料提交。
  });

  test('deadline failure closes without changing completed report', () {
    final facts = MissionFacts(                                  // 超时由 FailureRecord 事实表达。
      policy: VerificationPolicy.requiredEvidence,
      hasEvidenceDeadlineFailure: true,
      events: [
        ExecutionEventFact(type: ExecutionEventType.start),
        ExecutionEventFact(
          type: ExecutionEventType.end,
          reportedResult: UserReportedResult.completed,
        ),
      ],
    );
    expect(deriveMissionPhase(facts), MissionPhase.closed);      // 完成自报并没有被改成未完成。
  });

  test('cancelled missions cannot have execution events', () {   // 不合法事实不应被静默修复。
    final facts = MissionFacts(
      policy: VerificationPolicy.selfReport,
      isCancelled: true,
      events: [ExecutionEventFact(type: ExecutionEventType.start)],
    );
    expect(() => deriveMissionPhase(facts), throwsStateError);    // 明确暴露数据损坏。
  });
}

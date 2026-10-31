import '../../domain/rules/schedule_proposal_rules.dart';
import 'drift_repository_support.dart';
import '../../domain/entities/user_execution_report.dart';
import 'package:uuid/uuid.dart';
import '../../domain/repositories/mission_makeup_repository.dart';
import 'dart:convert';
import '../../domain/entities/mission_ownership.dart';
import '../../domain/entities/operation_receipt.dart';
import 'drift_goal_repository.dart';
import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;
import '../../domain/entities/historical_completion.dart';
import '../../domain/repositories/historical_completion_repository.dart';
import '../../domain/entities/execution_plan.dart';
import '../../domain/entities/mission.dart';
import '../../domain/entities/mission_creation.dart';
import '../../domain/entities/schedule_proposal.dart';
import '../../domain/repositories/schedule_proposal_repository.dart';
import '../../domain/rules/historical_completion_rules.dart';
import '../../domain/rules/mission_creation_rules.dart';
import '../../domain/entities/mission_schedule_revision.dart';
import '../../domain/entities/scheduled_mission.dart';
import '../../domain/entities/mission_detail.dart';
import '../local/app_database.dart';
import 'execution_event_mapping.dart';
import '../../domain/entities/execution_command.dart';
import '../../domain/entities/execution_event.dart';
import '../../domain/entities/failure_record.dart';
import '../../domain/entities/mission_phase.dart';
import '../../domain/entities/evidence.dart';
import '../../domain/rules/evidence_rules.dart';
import 'evidence_mapping.dart';
import '../../domain/rules/execution_event_rules.dart';
import '../../domain/rules/scheduled_execution_rules.dart';
import '../../domain/repositories/mission_repository.dart';
import '../../domain/repositories/mission_query_repository.dart';
part 'mission_mapping.dart';
part 'mission_queries.dart';
part 'mission_commands.dart';
part 'mission_scheduling.dart';
part 'mission_evidence.dart';
part 'mission_execution.dart';

/// 使用同一数据库连接完成原子创建、列表查询与详情读取。
class DriftMissionRepository
    implements
        MissionRepository,
        MissionQueryRepository,
        HistoricalCompletionRepository,
        MissionMakeupRepository,
        ScheduleProposalRepository {
  late final _support = DriftRepositorySupport(database, clock: clock);
  late final _queries = _MissionQueries(this);
  late final _commands = _MissionCommands(this);
  late final _scheduling = _MissionScheduling(this);
  late final _evidence = _MissionEvidence(this);
  late final _execution = _MissionExecution(this);

  /// 改为今天自选并开始，同一事务保留旧排期，避免过期固定任务立刻再次STOP。
  @override
  Future<ExecutionEvent> startMakeup(
    MissionDetail original,
    String commandId, {
    DateTime? evidenceDeadlineAt,
  }) => _execution.startMakeup(
    original,
    commandId,
    evidenceDeadlineAt: evidenceDeadlineAt,
  );
  @override
  Future<void> reportExecution(
    UserExecutionReport report, {
    required int expectedSequence,
    required String scheduleId,
    UserReportedResult? result,
    bool? submitOptionalEvidence,
  }) => _execution.reportExecution(
    report,
    expectedSequence: expectedSequence,
    scheduleId: scheduleId,
    result: result,
    submitOptionalEvidence: submitOptionalEvidence,
  );

  @override
  Future<EvidenceSubmissionResult> attachRecordEvidence(
    String recordId,
    String missionId,
  ) => _evidence.attachRecordEvidence(recordId, missionId);

  /// 接收应用持有的连接；本仓储不自行创建或关闭数据库。
  DriftMissionRepository(this.database, {this.clock = DateTime.now}) {
    tzdata.initializeTimeZones();
  }

  /// 创建与查询共用的数据库连接。
  final AppDatabase database;
  // 只用于捕获实际操作时刻；测试注入可控时钟，不允许命令指定 occurredAt。
  final DateTime Function() clock;
  static const _unstartedFixed = '''
FROM missions m JOIN mission_schedule_revisions r ON r.mission_id=m.id
WHERE m.cancelled_at IS NULL AND r.time_policy='FIXED'
 AND NOT EXISTS(SELECT 1 FROM execution_events e WHERE e.mission_id=m.id AND e.type='START')
 AND NOT EXISTS(SELECT 1 FROM mission_schedule_revisions newer
   WHERE newer.mission_id=m.id AND newer.revision_number>r.revision_number)
''';
  @override
  Future<PlannedMissionSnapshot> findPlannedSnapshot() =>
      _queries.findPlannedSnapshot();
  @override
  Future<List<MissionDetail>> findReminderCandidates() =>
      _queries.findReminderCandidates();
  @override
  Future<Set<String>> findCompletedGoalNodeIds(String goalId) =>
      _queries.findCompletedGoalNodeIds(goalId);
  @override
  Future<List<MissionGoalChoices>> findGoalChoices() =>
      _queries.findGoalChoices();
  @override
  Future<MissionOwnershipInfo?> findOwnershipInfo(MissionOwnership ownership) =>
      _queries.findOwnershipInfo(ownership);
  @override
  Future<List<MissionDetail>> findForGoal(String goalId) =>
      _queries.findForGoal(goalId);
  Future<void> _acquireWrite(String missionId) async {
    // 显式在读取事实前执行写语句，字段值不变；同库连接受 SQLite 写锁约束。
    // 当前 Native/Wasm 驱动也使用 BEGIN IMMEDIATE，不能误认为 transaction 默认都为延迟事务。
    await database.customStatement(
      'UPDATE missions SET updated_at = updated_at WHERE id = ? AND 0',
      [missionId],
    );
  }

  /// 补算等“作用于全部任务”的入口用空编号的空更新取得全局写锁，
  /// 与任何单任务的提交/执行串行，双方不会各按旧快照同时判定超时。
  Future<void> _acquireGlobalWrite() => _acquireWrite('');
  @override
  Future<List<ScheduleConflict>> checkPlan(ScheduleProposal plan) =>
      _scheduling.checkPlan(plan);
  @override
  Future<OperationReceiptInfo> applyPlan(ScheduleProposal plan) =>
      _scheduling.applyPlan(plan);
  DateTime _now() => DateTime.fromMillisecondsSinceEpoch(
    clock().toUtc().millisecondsSinceEpoch,
    isUtc: true,
  );

  /// 超时发生时刻和实际落库时刻分开；晚 END 不能制造早于 END 的关闭时间。
  Future<void> _insertEvidenceDeadline(
    MissionDetail detail,
    ExecutionEvent end,
    DateTime now,
  ) => _evidence._insertEvidenceDeadline(detail, end, now);
  @override
  Future<EvidenceSubmissionResult> submitEvidence(
    EvidenceSubmission submission,
  ) => _evidence.submitEvidence(submission);
  @override
  Future<Evidence> correctEvidence(EvidenceCorrection correction) =>
      _evidence.correctEvidence(correction);
  @override
  Future<void> skipOptionalEvidence(String missionId) =>
      _evidence.skipOptionalEvidence(missionId);
  @override
  Future<int> reconcileEvidenceDeadlines() =>
      _evidence.reconcileEvidenceDeadlines();
  @override
  Future<List<MissionDetail>> findPendingEvidence() =>
      _evidence.findPendingEvidence();
  @override
  Future<Set<String>> referencedAttachmentKeys() =>
      _evidence.referencedAttachmentKeys();
  @override
  Future<List<String>> reconcileScheduledMissions() =>
      _scheduling.reconcileScheduledMissions();
  @override
  Future<List<String>> reconcileScheduledEnds() =>
      _scheduling.reconcileScheduledEnds();
  @override
  Future<ExecutionEvent> execute(ExecutionCommand command) =>
      _execution.execute(command);
  @override
  Future<OperationReceiptInfo> completeHistory(HistoricalCompletion request) =>
      _execution.completeHistory(request);
  // 自动开始已持有外层事务写锁，可复用其边界校验时刻；普通操作仍在下方捕获。
  Future<ExecutionEvent> _execute(
    ExecutionCommand command, {
    DateTime? occurredAt,
  }) => _execution._execute(command, occurredAt: occurredAt);
  @override
  Future<List<MissionDetail>> findActive() => _queries.findActive();
  @override
  Future<List<MissionDetail>> findFinished() => _queries.findFinished();
  @override
  Future<List<MissionDetail>> findCancelled() => _queries.findCancelled();
  @override
  Future<List<MissionDetail>> findAllDetails() => _queries.findAllDetails();
  @override
  Future<void> edit({
    required MissionDetail original,
    required String title,
    required String objective,
    required MissionScheduleRevision schedule,
    ExecutionPlanContent? content,
    VerificationPolicy? verificationPolicy,
    String? verificationCriteria,
    MissionOwnership? ownership,
    String? description,
    String? why,
    bool updateContext = false,
    String? operationId,
  }) => _commands.edit(
    original: original,
    title: title,
    objective: objective,
    schedule: schedule,
    content: content,
    verificationPolicy: verificationPolicy,
    verificationCriteria: verificationCriteria,
    ownership: ownership,
    description: description,
    why: why,
    updateContext: updateContext,
    operationId: operationId,
  );
  @override
  Future<OperationReceiptInfo?> findOperationReceipt(String operationId) =>
      _queries.findOperationReceipt(operationId);
  Future<void> _writeOperationReceipt({
    required String? operationId,
    required String missionId,
    required String? fingerprint,
    String kind = 'mission_edit',
  }) async {
    if (operationId == null) return;
    await database
        .into(database.operationReceipts)
        .insert(
          OperationReceiptsCompanion.insert(
            id: operationId,
            kind: kind,
            fingerprint: fingerprint!,
            entityId: missionId,
            resultJson: jsonEncode({'missionId': missionId}),
            createdAt: _now().millisecondsSinceEpoch,
          ),
        );
  }

  // 比较日期、时区、策略、时刻、时长与截止；身份和生成信息不代表内容变化。
  @override
  Future<void> cancel(String missionId, {String? operationId}) =>
      _commands.cancel(missionId, operationId: operationId);
  @override
  Future<MissionDetail?> findDetail(String missionId) =>
      _queries.findDetail(missionId);
  @override
  // 调用者：MissionService.findScheduledOn。
  // 输入：计划日期。过程：关联 → 筛选 → 排序 → 执行 → 转换。输出：业务列表。
  Future<List<ScheduledMission>> findScheduledOn(String scheduledDate) =>
      _queries.findScheduledOn(scheduledDate);
  @override
  Future<void> create({
    required Mission mission,
    required MissionScheduleRevision initialSchedule,
    required ExecutionPlan executionPlan,
  }) => _commands.create(
    mission: mission,
    initialSchedule: initialSchedule,
    executionPlan: executionPlan,
  );
}

String _planFingerprint(ScheduleProposal plan) {
  final values = [
    for (final item in plan.items)
      {
        'itemId': item.id,
        'missionId': item.missionId,
        'kind': item.isCreation ? 'CREATE' : 'RESCHEDULE',
        'title': item.title,
        'date': item.schedule.scheduledDate,
        'timeZone': item.schedule.timeZone,
        'timePolicy': item.schedule.timePolicy.name,
        'minutes': item.schedule.plannedDurationMinutes,
        'start': item.schedule.fixedStartAt?.millisecondsSinceEpoch,
        'deadline': item.schedule.evidenceDeadlineAt?.millisecondsSinceEpoch,
        if (item.creation != null) ...{
          'objective': item.creation!.plan.objective,
          'steps': item.creation!.plan.steps,
          'notes': item.creation!.plan.notes,
          'policy': item.creation!.mission.verificationPolicy.name,
          'criteria': item.creation!.plan.verificationCriteria,
          'goalId': item.creation!.mission.goalId,
          'goalNodeId': item.creation!.mission.goalNodeId,
          'description': item.creation!.mission.description,
          'why': item.creation!.mission.why,
        },
        if (item.original != null) ...{
          'beforeSchedule': item.original!.schedule.id,
          'beforeMissionUpdatedAt':
              item.original!.mission.updatedAt.millisecondsSinceEpoch,
          'beforePlanUpdatedAt':
              item.original!.executionPlan.updatedAt.millisecondsSinceEpoch,
        },
      },
  ];
  return sha256.convert(utf8.encode(jsonEncode(values))).toString();
}

String _editFingerprint({
  required MissionDetail original,
  required String title,
  required String objective,
  required MissionScheduleRevision schedule,
  ExecutionPlanContent? content,
  VerificationPolicy? verificationPolicy,
  String? verificationCriteria,
  MissionOwnership? ownership,
  String? description,
  String? why,
  required bool updateContext,
}) {
  final input = {
    'missionId': original.mission.id,
    'originalScheduleId': original.schedule.id,
    'originalMissionUpdatedAt': original.mission.updatedAt
        .toUtc()
        .toIso8601String(),
    'originalPlanUpdatedAt': original.executionPlan.updatedAt
        .toUtc()
        .toIso8601String(),
    'title': title,
    'objective': objective,
    'schedule': {
      'date': schedule.scheduledDate,
      'timeZone': schedule.timeZone,
      'minutes': schedule.plannedDurationMinutes,
      'timePolicy': schedule.timePolicy.name,
      'fixedStartAt': schedule.fixedStartAt?.toUtc().toIso8601String(),
      'evidenceDeadlineAt': schedule.evidenceDeadlineAt
          ?.toUtc()
          .toIso8601String(),
    },
    'steps': content?.steps ?? original.executionPlan.steps,
    'notes': content == null ? original.executionPlan.notes : content.notes,
    'verificationPolicy': verificationPolicy?.name,
    'verificationCriteria': verificationCriteria,
    'ownership': ownership == null
        ? null
        : {'goalId': ownership.goalId, 'goalNodeId': ownership.goalNodeId},
    'description': description,
    'why': why,
    'updateContext': updateContext,
  };
  return sha256.convert(utf8.encode(jsonEncode(input))).toString();
}

UserExecutionReport userReportFromRow(UserExecutionReportRow r) =>
    UserExecutionReport(
      id: r.id,
      missionId: r.missionId,
      occurrenceDate: r.occurrenceDate,
      timeZoneId: r.timeZoneId,
      basis: r.basis,
      actualStart: r.actualStart == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(r.actualStart!, isUtc: true),
      actualEnd: r.actualEnd == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(r.actualEnd!, isUtc: true),
      reportedAt: DateTime.fromMillisecondsSinceEpoch(
        r.reportedAt,
        isUtc: true,
      ),
      supersedesId: r.supersedesId,
    );

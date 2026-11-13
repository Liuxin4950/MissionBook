import 'package:mission_book/domain/entities/record_draft.dart';
import 'package:mission_book/data/repositories/drift_memory_repository.dart';
import 'package:mission_book/domain/entities/analysis_scope.dart';
import 'package:mission_book/application/memory/memory_service.dart';
import 'package:agent_core/agent_core.dart';
import 'package:mission_book/application/assistant/context_tools.dart';
import 'package:mission_book/application/assistant/assistant_tools.dart';
import 'package:mission_book/application/records/record_service.dart';
import 'package:mission_book/application/web/web_service.dart';
import 'package:mission_book/data/assistant/drift_assistant_reader.dart';
import 'package:mission_book/domain/entities/mission_schedule_revision.dart';
import 'package:mission_book/data/web/web_settings_store.dart';
import 'dart:convert';
import 'package:archive/archive.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:mission_book/data/local/app_database.dart';
import 'package:mission_book/data/repositories/drift_record_repository.dart';
import 'package:mission_book/data/repositories/drift_mission_repository.dart';
import 'package:mission_book/data/repositories/drift_goal_repository.dart';
import 'package:mission_book/data/analysis/drift_analysis_store.dart';
import 'package:mission_book/data/assistant/drift_unified_reader.dart';
import 'package:mission_book/data/backup/database_backup_service.dart';
import 'package:mission_book/application/analysis/analysis_service.dart';
import '../support/backup_rows.dart';
import 'package:mission_book/application/goals/goal_service.dart';
import 'package:mission_book/application/missions/mission_service.dart';
import 'package:mission_book/domain/entities/evidence.dart';
import 'package:mission_book/domain/entities/execution_event.dart';
import 'package:mission_book/domain/entities/mission.dart';
import 'package:mission_book/domain/entities/mission_phase.dart';
import 'package:mission_book/domain/entities/mission_ownership.dart';
import 'package:mission_book/domain/entities/user_execution_report.dart';
import 'package:mission_book/domain/rules/mission_attention_rules.dart';

void main() {
  late AppDatabase db;
  late DriftRecordRepository records;
  late MissionService missions;
  late DriftMissionRepository repo;
  late GoalService goals;
  late DateTime now;
  setUp(() {
    tzdata.initializeTimeZones();
    now = DateTime.utc(2026, 10, 30, 8);
    db = AppDatabase(executor: NativeDatabase.memory());
    records = DriftRecordRepository(db, clock: () => now);
    repo = DriftMissionRepository(db, clock: () => now);
    missions = MissionService(repo, clock: () => now);
    goals = GoalService(DriftGoalRepository(db));
  });
  tearDown(() async {
    await missions.dispose();
    await goals.dispose();
    await db.close();
  });
  Future<String> seed({
    VerificationPolicy policy = VerificationPolicy.selfReport,
    String? goalId,
    String? nodeId,
    String title = '午餐记录',
  }) async {
    final creation = missions.prepareCreation(
      title: title,
      scheduledDate: '2026-10-30',
      timeZone: 'Asia/Shanghai',
      plannedDurationMinutes: 30,
      verificationPolicy: policy,
      verificationCriteria: policy == VerificationPolicy.requiredEvidence
          ? '午餐照片'
          : null,
      evidenceDeadlineAt: policy == VerificationPolicy.requiredEvidence
          ? now.add(const Duration(hours: 1))
          : null,
      ownership: MissionOwnership(goalId: goalId, goalNodeId: nodeId),
    );
    await missions.createPrepared(creation);
    return creation.mission.id;
  }

  Future<void> report(
    String id, {
    String reportId = 'report1',
    String? supersedes,
    DateTime? start,
    DateTime? end,
    String date = '2026-10-30',
    bool completed = true,
  }) async {
    final detail = (await repo.findDetail(id))!;
    await repo.reportExecution(
      UserExecutionReport(
        id: reportId,
        missionId: id,
        occurrenceDate: date,
        timeZoneId: 'Asia/Shanghai',
        basis: '用户确认上午已完成',
        actualStart: start,
        actualEnd: end,
        supersedesId: supersedes,
      ),
      expectedSequence: detail.lastSequence,
      scheduleId: detail.schedule.id,
      result: completed
          ? UserReportedResult.completed
          : UserReportedResult.notCompleted,
      submitOptionalEvidence:
          detail.mission.verificationPolicy ==
                  VerificationPolicy.optionalEvidence &&
              completed
          ? true
          : null,
    );
  }

  Future<void> startAndFinish(String id) async {
    await missions.execute(
      missions.prepareExecution(
        detail: (await repo.findDetail(id))!,
        type: ExecutionEventType.start,
      ),
    );
    await missions.execute(
      missions.prepareExecution(
        detail: (await repo.findDetail(id))!,
        type: ExecutionEventType.end,
        report: UserReportedResult.completed,
      ),
    );
  }

  test('午餐照片独立保存、后关联节点任务，材料保留快照，备份隔离还原完整', () async {
    final goal = goals.prepareCreation(
      title: '减肥',
      why: '改善体能',
      desireLevel: 5,
    );
    await goals.create(goal);
    final node = goals.prepareNodeCreation(goalId: goal.id, title: '饮食管理');
    await goals.createNode(node);
    final id = await seed(goalId: goal.id, nodeId: node.id);
    const key = 'attachments/record-owner/lunch.jpg';
    final draft = RecordDraft(
      id: 'lunch',
      type: ContentType.image,
      source: ContentSource.camera,
      content: '午餐',
      attachmentStorageKey: key,
      attachmentFileName: 'lunch.jpg',
      attachmentMimeType: 'image/jpeg',
      capturedAt: now.subtract(const Duration(hours: 4)),
    );
    await records.saveRecord(draft);
    await records.saveRecord(draft);
    expect((await repo.findDetail(id))!.events, isEmpty);
    await repo.attachRecordEvidence('lunch', id);
    await repo.attachRecordEvidence('lunch', id);
    final record = (await db.select(db.records).get()).single;
    expect(record.goalId, isNull);
    expect(record.goalNodeId, isNull);
    final evidence = (await db.select(db.evidenceRecords).get()).single;
    expect(evidence.content, '午餐');
    expect(evidence.attachmentStorageKey, key);
    expect(evidence.recordId, 'lunch');
    final detail = (await repo.findDetail(id))!;
    expect(detail.effectiveEvidence.single.content, '午餐');
    expect(detail.phase, MissionPhase.notStarted);
    await records.deleteRecord('lunch');
    expect(await repo.referencedAttachmentKeys(), contains(key));
    final backup = await DatabaseBackupService(
      database: db,
      readAttachment: (_) async => Uint8List.fromList([1, 2, 3]),
    ).create();
    final zip = ZipDecoder().decodeBytes(backup);
    expect(zip.findFile(key), isNotNull);
    final restored = await openBackupDatabase(backup);
    try {
      expect(
        (await DriftMissionRepository(
          restored,
        ).findDetail(id))!.evidence.single.attachmentStorageKey,
        key,
      );
      expect(
        await restored.customSelect('PRAGMA foreign_key_check').get(),
        isEmpty,
      );
    } finally {
      await restored.close();
    }
  });
  test('任务改归属不搬动记录，正文和正式引用不变', () async {
    final a = goals.prepareCreation(title: '目标A'),
        b = goals.prepareCreation(title: '目标B');
    await goals.create(a);
    await goals.create(b);
    final id = await seed(goalId: a.id);
    await records.saveRecord(
      const RecordDraft(
        id: 'owned',
        type: ContentType.text,
        source: ContentSource.user,
        content: '先收集材料',
      ),
      goalId: a.id,
      missionId: id,
    );
    final d = (await repo.findDetail(id))!;
    await missions.edit(
      original: d,
      title: d.mission.title,
      objective: d.executionPlan.objective,
      scheduledDate: d.schedule.scheduledDate,
      plannedDurationMinutes: 30,
      timePolicy: TimePolicy.flexible,
      ownership: MissionOwnership(goalId: b.id),
    );
    expect((await db.select(db.records).get()).single.goalId, a.id);
    expect((await repo.findDetail(id))!.evidence.single.content, '先收集材料');
    expect((await records.readRecords(goalId: a.id)).total, 1);
    expect((await records.readRecords(goalId: b.id)).total, 0);
  });
  test('引用后编辑、重试、删除均保留任务材料快照和来源编号', () async {
    final id = await seed();
    await records.saveRecord(
      const RecordDraft(
        id: 'mutable-source',
        type: ContentType.text,
        source: ContentSource.user,
        content: '提交原文',
      ),
    );
    await repo.attachRecordEvidence('mutable-source', id);
    await records.updateRecordContent('mutable-source', '提交原文', '新正文');
    await repo.attachRecordEvidence('mutable-source', id);
    expect((await repo.findDetail(id))!.evidence.single.content, '提交原文');
    await records.deleteRecord('mutable-source');
    await repo.attachRecordEvidence('mutable-source', id);
    expect((await repo.findDetail(id))!.evidence.single.content, '提交原文');
    expect(
      (await db.select(db.evidenceRecords).get()).single.recordId,
      'mutable-source',
    );
    expect(await db.customSelect('PRAGMA foreign_key_check').get(), isEmpty);
  });
  test('预览后正文变化拒绝提交；删除来源后任务评价仍读取材料快照', () async {
    final id = await seed();
    await records.saveRecord(
      const RecordDraft(
        id: 'preview',
        type: ContentType.text,
        source: ContentSource.user,
        content: '原文',
      ),
    );
    final preview = await records.readDraft('preview');
    await records.updateRecordContent('preview', '原文', '提交内容');
    await expectLater(
      missions.useRecordAsMaterial(
        'preview',
        id,
        expected: EvidenceDraft.fromContent(preview),
      ),
      throwsA(isA<EvidenceConflict>()),
    );
    expect((await repo.findDetail(id))!.evidence, isEmpty);
    await missions.useRecordAsMaterial('preview', id);
    await records.updateRecordContent('preview', '提交内容', '后续记录');
    final store = DriftAnalysisStore(db);
    final before = await store.input(
      AnalysisWork(AnalysisScope.mission, id, 1, false, 0, false),
    );
    expect(before.items.single['content'], '提交内容');
    await records.deleteRecord('preview');
    final after = await store.input(
      AnalysisWork(AnalysisScope.mission, id, 1, false, 0, false),
    );
    expect(after.items.single['content'], '提交内容');
    expect((await records.readRecords(id: 'preview')).total, 0);
  });

  test('图片提交时无说明，后来补写说明不污染助手的历史材料正文', () async {
    final id = await seed();
    await records.saveRecord(
      const RecordDraft(
        id: 'empty-caption',
        type: ContentType.image,
        source: ContentSource.camera,
        attachmentStorageKey: 'attachments/caption/p.png',
        attachmentFileName: 'p.png',
      ),
    );
    await repo.attachRecordEvidence('empty-caption', id);
    await records.updateRecordContent('empty-caption', null, '事后说明');
    final evidence = (await repo.findDetail(id))!.evidence.single;
    expect(evidence.content, isNull);
    final content = await DriftAssistantReader(db).evidenceContent(evidence.id);
    expect(content['text'], '');
  });

  test('来源删除后任务评价仍观察提交快照图片并汇总观察结果', () async {
    final id = await seed();
    await startAndFinish(id);
    await records.saveRecord(
      const RecordDraft(
        id: 'visual-source',
        type: ContentType.image,
        source: ContentSource.camera,
        attachmentStorageKey: 'attachments/visual/photo.png',
        attachmentFileName: 'photo.png',
        attachmentMimeType: 'image/png',
      ),
    );
    await repo.attachRecordEvidence('visual-source', id);
    await records.deleteRecord('visual-source');
    final store = DriftAnalysisStore(db);
    final calls = <String?>[];
    final prompts = <String>[];
    final analysis = AnalysisService(
      store: store,
      mainBusy: () => false,
      model: (prompt, {imageKey, mime, json = false}) async {
        calls.add(imageKey);
        prompts.add(prompt);
        return imageKey == null ? '评价完成' : '可见练习截图';
      },
    );
    try {
      await store.retry(AnalysisScope.mission, id);
      await analysis.drain();
      expect(calls, contains('attachments/visual/photo.png'));
      expect(prompts.last, contains('可见练习截图'));
      expect(
        (await records.analysis(AnalysisScope.mission, id))['state'],
        'ready',
      );
    } finally {
      await analysis.dispose();
    }
  });

  test('跨目标引用保留自身归属，并能改回独立记录；单任务限制明确拒绝重复复用', () async {
    final a = goals.prepareCreation(title: '记录目标');
    final b = goals.prepareCreation(title: '任务目标');
    await goals.create(a);
    await goals.create(b);
    final first = await seed(goalId: b.id);
    final second = await seed();
    await records.saveRecord(
      const RecordDraft(
        id: 'cross',
        type: ContentType.text,
        source: ContentSource.user,
        content: '记录佐证',
      ),
      goalId: a.id,
    );
    await repo.attachRecordEvidence('cross', first);
    expect((await records.readRecords(id: 'cross')).items.single.goalId, a.id);
    await records.updateOwnership('cross');
    expect(
      (await records.readRecords(id: 'cross')).items.single.goalId,
      isNull,
    );
    await expectLater(
      repo.attachRecordEvidence('cross', second),
      throwsA(isA<EvidenceConflict>()),
    );
    expect((await repo.findDetail(second))!.evidence, isEmpty);
  });

  test('结束前材料满足要求，补记不造START，之后补充不改结果及原事件', () async {
    final id = await seed(policy: VerificationPolicy.requiredEvidence);
    await records.saveRecord(
      const RecordDraft(
        id: 'before',
        type: ContentType.text,
        source: ContentSource.user,
        content: '餐盘说明',
      ),
      missionId: id,
    );
    expect((await repo.findDetail(id))!.phase, MissionPhase.notStarted);
    await report(
      id,
      start: DateTime.utc(2026, 10, 30, 2),
      end: DateTime.utc(2026, 10, 30, 2, 30),
    );
    final before = (await repo.findDetail(id))!;
    expect(before.events.single.isRetrospective, isTrue);
    expect(before.phase, MissionPhase.closed);
    expect(before.effectiveUserReport!.duration, const Duration(minutes: 30));
    await records.saveRecord(
      const RecordDraft(
        id: 'after',
        type: ContentType.text,
        source: ContentSource.user,
        content: '补充营养信息',
      ),
      missionId: id,
    );
    final after = (await repo.findDetail(id))!;
    expect(after.events.single.id, before.events.single.id);
    expect(after.phase, MissionPhase.closed);
    expect(after.evidence, hasLength(2));
    expect(
      (await repo.findFinished()).single.effectiveUserReport!.id,
      'report1',
    );
  });
  test('材料超时和未完成允许补充，保持各自失败事实', () async {
    final late = await seed(policy: VerificationPolicy.requiredEvidence);
    await report(late);
    now = now.add(const Duration(hours: 2));
    await records.saveRecord(
      const RecordDraft(
        id: 'late',
        type: ContentType.text,
        source: ContentSource.user,
        content: '晚补材料',
      ),
      missionId: late,
    );
    final d = (await repo.findDetail(late))!;
    expect(d.phase, MissionPhase.closed);
    expect(d.failures.single.trigger, 'EVIDENCE_DEADLINE_MISSED');
    expect(d.endReportedCompleted, isTrue);
    final missed = await seed();
    await report(missed, reportId: 'missed', completed: false);
    await records.saveRecord(
      const RecordDraft(
        id: 'explanation',
        type: ContentType.text,
        source: ContentSource.user,
        content: '未执行的说明',
      ),
      missionId: missed,
    );
    expect((await repo.findDetail(missed))!.failures, hasLength(1));
    expect((await repo.findDetail(missed))!.endReportedCompleted, isFalse);
  });
  test('秒级记录追加跨日时间更正，发生日期改变但计时和END不被修改', () async {
    final id = await seed();
    final initial = (await repo.findDetail(id))!;
    await missions.execute(
      missions.prepareExecution(
        detail: initial,
        type: ExecutionEventType.start,
      ),
    );
    now = now.add(const Duration(seconds: 2));
    await missions.execute(
      missions.prepareExecution(
        detail: (await repo.findDetail(id))!,
        type: ExecutionEventType.end,
        report: UserReportedResult.completed,
      ),
    );
    final end = (await repo.findDetail(id))!.events.last;
    await report(
      id,
      start: DateTime.utc(2026, 10, 28, 15, 30),
      end: DateTime.utc(2026, 10, 28, 16, 30),
      date: '2026-10-28',
    );
    await report(
      id,
      reportId: 'correction',
      supersedes: 'report1',
      start: DateTime.utc(2026, 10, 29, 1),
      end: DateTime.utc(2026, 10, 29, 2),
      date: '2026-10-29',
    );
    final result = (await repo.findDetail(id))!;
    expect(result.events.last.occurredAt, end.occurredAt);
    expect(result.events, hasLength(2));
    expect(result.effectiveOccurrenceDate, '2026-10-29');
    expect(result.effectiveUserReport!.duration, const Duration(hours: 1));
    expect(result.userReports, hasLength(2));
    expect(
      () => UserExecutionReport(
        id: 'x',
        missionId: id,
        occurrenceDate: '2026-10-30',
        timeZoneId: 'Asia/Shanghai',
        basis: '确认',
        actualStart: DateTime.utc(2026, 10, 29),
        actualEnd: DateTime.utc(2026, 10, 29, 1),
      ).validate(now),
      throwsArgumentError,
    );
  });
  test('重复补记不重复写入，冲突的修正和错误归属整笔回滚', () async {
    final id = await seed();
    await report(id);
    await report(id);
    expect(await db.select(db.userExecutionReports).get(), hasLength(1));
    await expectLater(
      report(id, reportId: 'stale'),
      throwsA(isA<EvidenceConflict>()),
    );
    await expectLater(
      records.saveRecord(
        const RecordDraft(
          id: 'bad',
          type: ContentType.text,
          source: ContentSource.user,
          content: '无效归属',
        ),
        missionId: 'missing',
      ),
      throwsA(isA<EvidenceConflict>()),
    );
    expect(
      await (db.select(db.records)..where((t) => t.id.equals('bad'))).get(),
      isEmpty,
    );
  });
  test('现在补做保留旧排期，真实START不受过去固定结束点停止，重复请求幂等', () async {
    final request = missions.prepareCreation(
      title: '上午计划',
      scheduledDate: '2026-10-30',
      timeZone: 'Asia/Shanghai',
      plannedDurationMinutes: 30,
      timePolicy: TimePolicy.fixed,
      fixedStartAt: DateTime.utc(2026, 10, 30),
    );
    await missions.createPrepared(request);
    final d = (await repo.findDetail(request.mission.id))!;
    expect(
      missionAttention(d.phase, d.schedule, now),
      MissionAttention.overdue,
    );
    await missions.startMakeup(d, 'makeup-command');
    await missions.startMakeup(d, 'makeup-command');
    final current = (await repo.findDetail(d.mission.id))!;
    expect(current.phase, MissionPhase.running);
    expect(current.events, hasLength(1));
    expect(current.events.single.occurredAt, now);
    expect(
      await (db.select(
        db.missionScheduleRevisions,
      )..where((t) => t.missionId.equals(d.mission.id))).get(),
      hasLength(2),
    );
    await missions.reconcileScheduledMissions();
    expect((await repo.findDetail(d.mission.id))!.phase, MissionPhase.running);
  });
  test('只有计划尚无材料或结果的批量日程不排任务评价，父层只计算数量', () async {
    final goal = goals.prepareCreation(title: '批量日程');
    await goals.create(goal);
    for (var i = 0; i < 30; i++) {
      await seed(goalId: goal.id, title: '计划$i');
    }
    expect(
      await (db.select(
        db.analysisJobs,
      )..where((t) => t.scope.equals('mission'))).get(),
      isEmpty,
    );
    final input = await DriftAnalysisStore(
      db,
    ).input(AnalysisWork(AnalysisScope.goal, goal.id, 1, false));
    expect(input.facts['directMissionCount'], 30);
    expect(input.items, isEmpty);
  });
  test('持久搜索额度并发预留只允许到上限', () async {
    final quota = DriftSearchQuota(db);
    final outcomes = await Future.wait([
      for (var i = 0; i < 12; i++) quota.reserve('2026-10', 3),
    ]);
    expect(outcomes.where((e) => e), hasLength(3));
    expect(await quota.used('2026-10'), 3);
  });
  test('AI补记采用确认时快照；并发开始后拒绝旧提案，回执支持新写入恢复', () async {
    final id = await seed();
    final before = (await repo.findDetail(id))!;
    final service = RecordService(records, missions, missions.attachments);
    final store = DriftAnalysisStore(db);
    final tools = contextTools(
      records: service,
      missions: missions,
      memory: MemoryService(DriftMemoryRepository(db)),
      analysis: store,
      analyze: (p, {imageKey, mime, json = false}) async => '摘要',
      web: WebService(
        settings: const SecureWebSettings(),
        quota: DriftSearchQuota(db),
        fetchClient: () => throw StateError('本测试不出网'),
      ),
      userStatement: () => '我上午已完成课程',
      snapshot: (_) => {'detail': before},
    );
    await missions.execute(
      missions.prepareExecution(detail: before, type: ExecutionEventType.start),
    );
    final context = ToolContext(
      callId: 'report-call',
      sessionId: 'session',
      cancellation: CancellationToken(),
    );
    await expectLater(
      tools.firstWhere((t) => t.definition.name == 'reportExecution').execute({
        'missionId': id,
        'occurrenceDate': '2026-10-30',
        'basis': '我上午已完成课程',
        'completed': true,
      }, context),
      throwsA(isA<ToolRejected>()),
    );
    expect((await repo.findDetail(id))!.events, hasLength(1));
    expect(await db.select(db.userExecutionReports).get(), isEmpty);
    final host = AssistantTools(
      unifiedReader: DriftUnifiedReader(db),
      missions: missions,
      goals: goals,
      memory: MemoryService(DriftMemoryRepository(db)),
      extraTools: tools,
      resolveCall: (_) => throw StateError('未准备'),
    );
    final queryNames = host.tools.map((tool) => tool.definition.name).toList();
    expect(queryNames.where((name) => name == 'getGoal'), hasLength(1));
    expect(queryNames.where((name) => name == 'getMission'), hasLength(1));
    expect(queryNames.where((name) => name == 'getSchedule'), hasLength(1));
    expect(queryNames, isNot(contains('getGoalDetail')));
    final readContext = ToolContext(
      callId: 'query-call',
      sessionId: 'session',
      cancellation: CancellationToken(),
    );
    final queried = await host.tools
        .firstWhere((tool) => tool.definition.name == 'getMission')
        .execute({'mission': id}, readContext);
    expect((jsonDecode(queried.text) as Map)['id'], id);
    final goalList = await host.tools
        .firstWhere((tool) => tool.definition.name == 'getGoal')
        .execute({}, readContext);
    expect((jsonDecode(goalList.text) as Map)['total'], isA<int>());
    final save = host.tools.firstWhere(
      (t) => t.definition.name == 'saveRecord',
    );
    const input = {'content': '需要记住的独立记录'};
    final saveContext = ToolContext(
      callId: 'record-call',
      sessionId: 'session',
      cancellation: CancellationToken(),
    );
    final output = await save.execute(input, saveContext);
    final recovered = await host.recoverOutcome(
      toolName: 'saveRecord',
      idempotencyKey: saveContext.idempotencyKey,
      input: input,
    );
    expect(recovered!.text, output.text);
    expect(await db.select(db.records).get(), hasLength(1));

    final recordId =
        (jsonDecode(output.text) as Map<String, dynamic>)['recordId'] as String;
    final ownershipInput = {'recordId': recordId};
    final ownershipContext = ToolContext(
      callId: 'ownership-call',
      sessionId: 'session',
      cancellation: CancellationToken(),
    );
    final ownership = host.tools.firstWhere(
      (t) => t.definition.name == 'setRecordOwnership',
    );
    final ownershipOutput = await ownership.execute(
      ownershipInput,
      ownershipContext,
    );
    final ownershipRecovery = await host.recoverOutcome(
      toolName: 'setRecordOwnership',
      idempotencyKey: ownershipContext.idempotencyKey,
      input: ownershipInput,
    );
    expect(ownershipRecovery!.text, ownershipOutput.text);
    expect(
      await host.recoverOutcome(
        toolName: 'useRecordAsMaterial',
        idempotencyKey: ownershipContext.idempotencyKey,
        input: {'recordId': recordId, 'missionId': id},
      ),
      isNull,
    );
    expect(
      await host.recoverOutcome(
        toolName: 'setRecordOwnership',
        idempotencyKey: ownershipContext.idempotencyKey,
        input: {'recordId': 'another-record'},
      ),
      isNull,
    );

    final materialInput = {'recordId': recordId, 'missionId': id};
    final materialContext = ToolContext(
      callId: 'material-call',
      sessionId: 'session',
      cancellation: CancellationToken(),
    );
    final material = host.tools.firstWhere(
      (t) => t.definition.name == 'useRecordAsMaterial',
    );
    expect(
      await host.recoverOutcome(
        toolName: 'useRecordAsMaterial',
        idempotencyKey: materialContext.idempotencyKey,
        input: materialInput,
      ),
      isNull,
    );
    final materialOutput = await material.execute(
      materialInput,
      materialContext,
    );
    expect(
      await host.recoverOutcome(
        toolName: 'useRecordAsMaterial',
        idempotencyKey: materialContext.idempotencyKey,
        input: {'recordId': 'different-record', 'missionId': id},
      ),
      isNull,
    );
    final otherContext = ToolContext(
      callId: 'other-material-call',
      sessionId: 'session',
      cancellation: CancellationToken(),
    );
    expect(
      await host.recoverOutcome(
        toolName: 'useRecordAsMaterial',
        idempotencyKey: otherContext.idempotencyKey,
        input: materialInput,
      ),
      isNull,
    );
    await service.delete(recordId);
    final materialRecovery = await host.recoverOutcome(
      toolName: 'useRecordAsMaterial',
      idempotencyKey: materialContext.idempotencyKey,
      input: materialInput,
    );
    expect(materialRecovery!.text, materialOutput.text);
    expect((await repo.findDetail(id))!.evidence.single.content, '需要记住的独立记录');
    final getRecord = host.tools.firstWhere(
      (t) => t.definition.name == 'getRecord',
    );
    final longText = '字' * 6200;
    await records.saveRecord(
      RecordDraft(
        id: 'long-tool',
        type: ContentType.text,
        source: ContentSource.user,
        content: longText,
      ),
    );
    final longOutput = await getRecord.execute({
      'record': 'long-tool',
      'content': true,
      'contentOffset': 6000,
    }, otherContext);
    final longResult = jsonDecode(longOutput.text) as Map<String, dynamic>;
    final longItem =
        (longResult['items'] as List).single as Map<String, dynamic>;
    expect(longItem['content'], longText.substring(6000));
    expect(longItem['contentLength'], 6200);
    expect(longItem['contentOffset'], 6000);
    expect(longItem['contentTruncated'], false);
    expect(longItem.containsKey('analysis'), isFalse);
    await records.saveRecord(
      const RecordDraft(
        id: 'image-tool',
        type: ContentType.image,
        source: ContentSource.fileSystem,
        attachmentStorageKey: 'attachments/image/test.jpg',
        attachmentFileName: 'test.jpg',
        attachmentMimeType: 'image/jpeg',
      ),
    );
    final imageOutput = await getRecord.execute({
      'record': 'image-tool',
      'imageQuestion': '图中是什么',
    }, otherContext);
    final imageResult = jsonDecode(imageOutput.text) as Map<String, dynamic>;
    expect(imageResult['imageObservation'], '摘要');
    expect(
      ((imageResult['items'] as List).single as Map)['attachmentMimeType'],
      'image/jpeg',
    );
  });
  test('新事实使分析版本失效，旧请求迟到拒绝发布；恢复中断队列', () async {
    final id = await seed();
    await startAndFinish(id);
    await db.delete(db.analysisJobs).go();
    final store = DriftAnalysisStore(db);
    await store.retry(AnalysisScope.mission, id);
    final old = (await store.claim())!;
    await report(id);
    expect(await store.publish(old, '过期结论', const [], 0), isFalse);
    final current = (await store.claim())!;
    await store.recover();
    final recovered = (await store.claim())!;
    expect(recovered.version, current.version);
    expect(await store.publish(recovered, '只评价本任务来源', const [], 1), isTrue);
    expect(
      (await records.analysis(AnalysisScope.mission, id))['state'],
      'ready',
    );
  });
  test('结束前保存的任务记录不触发AI，END后任务总结读取材料快照', () async {
    final goal = goals.prepareCreation(title: '饮食记录目标');
    await goals.create(goal);
    final node = goals.prepareNodeCreation(goalId: goal.id, title: '本周饮食');
    await goals.createNode(node);
    await db.delete(db.analysisJobs).go();
    final id = await seed(goalId: goal.id, nodeId: node.id);
    await records.saveRecord(
      const RecordDraft(
        id: 'during-execution-note',
        type: ContentType.text,
        source: ContentSource.user,
        content: '午餐照片：有米饭和青菜',
      ),
      missionId: id,
    );
    expect(
      await db
          .customSelect(
            "SELECT target_id FROM analysis_jobs WHERE scope='mission' AND target_id=?",
            variables: [Variable.withString(id)],
          )
          .get(),
      isEmpty,
    );
    expect(await db.select(db.analysisJobs).get(), isEmpty);
    await db.customStatement(
      "INSERT INTO analysis_jobs(scope,target_id,status) VALUES('mission',?,'pending')",
      [id],
    );
    expect(await DriftAnalysisStore(db).claim(), isNull);

    await startAndFinish(id);

    final job =
        await (db.select(db.analysisJobs)
              ..where((row) => row.scope.equals(AnalysisScope.mission.name)))
            .getSingle();
    expect(job.scope, AnalysisScope.mission.name);
    final input = await DriftAnalysisStore(
      db,
    ).input(AnalysisWork(AnalysisScope.mission, id, job.sourceVersion, false));
    expect(input.items.single['content'], '午餐照片：有米饭和青菜');
  });

  test('节点与目标只汇总任务和子节点摘要，不读取直接归属记录', () async {
    final goal = goals.prepareCreation(title: '大目标');
    await goals.create(goal);
    for (var i = 0; i < 45; i++) {
      await records.saveRecord(
        RecordDraft(
          id: 'r$i',
          type: ContentType.text,
          source: ContentSource.user,
          content: '笔记$i',
        ),
        goalId: goal.id,
      );
    }
    final prompts = <String>[];
    var busy = true;
    final worker = AnalysisService(
      store: DriftAnalysisStore(db),
      mainBusy: () => busy,
      model: (p, {imageKey, mime, json = false}) async {
        prompts.add(p);
        return '有来源的摘要';
      },
    );
    await worker.drain();
    expect(prompts, isEmpty);
    busy = false;
    await worker.drain();
    await worker.dispose();
    expect(prompts, hasLength(1));
    expect(prompts.single, isNot(contains('笔记0')));
    expect(
      (await records.analysis(AnalysisScope.goal, goal.id))['coverage'],
      0,
    );
  });
  test('历史与排期操作回执只允许所属会话分页读取', () async {
    final items = [
      for (var i = 0; i < 23; i++) {'id': 'task-$i', 'code': 'cancelled'},
    ];
    await db
        .into(db.operationReceipts)
        .insert(
          OperationReceiptsCompanion.insert(
            id: 'session-a:history',
            kind: 'completeHistory',
            fingerprint: 'fingerprint',
            entityId: 'goal',
            resultJson: jsonEncode({
              'status': 'success',
              'operationId': 'session-a:history',
              'issues': items,
            }),
            createdAt: now.millisecondsSinceEpoch,
          ),
        );
    await db
        .into(db.operationReceipts)
        .insert(
          OperationReceiptsCompanion.insert(
            id: 'session-a:plan',
            kind: 'planMissions',
            fingerprint: 'fingerprint',
            entityId: 'session-a:plan',
            resultJson: jsonEncode({
              'planId': 'session-a:plan',
              'items': items,
              'references': items,
            }),
            createdAt: now.millisecondsSinceEpoch,
          ),
        );
    final tools = contextTools(
      records: RecordService(records, missions, missions.attachments),
      missions: missions,
      memory: MemoryService(DriftMemoryRepository(db)),
      analysis: DriftAnalysisStore(db),
      analyze: (p, {imageKey, mime, json = false}) async => '',
      web: WebService(
        settings: const SecureWebSettings(),
        quota: DriftSearchQuota(db),
        fetchClient: () => throw StateError('不出网'),
      ),
      userStatement: () => '',
    );
    final tool = tools.firstWhere(
      (item) => item.definition.name == 'getOperation',
    );
    final output = await tool.execute(
      {'operationId': 'session-a:history', 'offset': 20},
      ToolContext(
        callId: 'read',
        sessionId: 'session-a',
        cancellation: CancellationToken(),
      ),
    );
    final result = jsonDecode(output.text) as Map;
    expect(result['issues'], hasLength(3));
    expect(result['page'], {'offset': 20, 'complete': true});
    final plan = await tool.execute(
      {'operationId': 'session-a:plan', 'offset': 20},
      ToolContext(
        callId: 'read-plan',
        sessionId: 'session-a',
        cancellation: CancellationToken(),
      ),
    );
    final planResult = jsonDecode(plan.text) as Map;
    expect(planResult['items'], hasLength(3));
    expect(planResult['page'], {'offset': 20, 'complete': true});
    expect(planResult.containsKey('references'), isFalse);
    await expectLater(
      tool.execute(
        {'operationId': 'session-a:history'},
        ToolContext(
          callId: 'read',
          sessionId: 'session-b',
          cancellation: CancellationToken(),
        ),
      ),
      throwsA(isA<ToolRejected>()),
    );
  });
  test('统一目标查询有界、同名候选、希望程度、任务详情不返回原图', () async {
    final goal = goals.prepareCreation(title: '学习', desireLevel: 4);
    await goals.create(goal);
    await goals.create(goals.prepareCreation(title: '学习'));
    final reader = DriftUnifiedReader(db);
    expect((await reader.getGoal(goal: '学习'))['state'], 'ambiguous');
    final id = await seed(goalId: goal.id);
    await report(id);
    final list = await reader.getGoal();
    expect(
      (list['items'] as List)
          .where((g) => g['id'] == goal.id)
          .single['desireLevel'],
      4,
    );
    final detail = await reader.getGoal(goal: goal.id, mission: id);
    expect(detail['userReportedCompleted'], true);
    expect(detail.containsKey('execution'), false);
    expect(detail.containsKey('materialIndex'), false);
    expect(
      (detail['details'] as Map)['records']['sections']['execution'],
      greaterThan(0),
    );
    expect((await reader.records(id, 'execution'))['items'], isNotEmpty);
    expect(jsonEncode(detail), isNot(contains('base64')));
    expect(
      missionAttention(
        MissionPhase.notStarted,
        (await repo.findDetail(id))!.schedule,
        now.add(const Duration(days: 1)),
      ),
      MissionAttention.overdue,
    );
  });
  test('目标逐层返回直接子项，显式子树查询保留全部任务', () async {
    final goal = goals.prepareCreation(title: '分层目标');
    await goals.create(goal);
    final parent = goals.prepareNodeCreation(goalId: goal.id, title: '基础');
    await goals.createNode(parent);
    final child = goals.prepareNodeCreation(
      goalId: goal.id,
      title: '语法',
      parentNodeId: parent.id,
    );
    await goals.createNode(child);
    final rootTask = await seed(goalId: goal.id, title: '根任务');
    final parentTask = await seed(
      goalId: goal.id,
      nodeId: parent.id,
      title: '基础任务',
    );
    final childTask = await seed(
      goalId: goal.id,
      nodeId: child.id,
      title: '语法任务',
    );
    final reader = DriftUnifiedReader(db);
    final root = await reader.getGoal(goal: goal.id);
    expect(((root['nodes'] as Map)['items'] as List).map((e) => e['id']), [
      parent.id,
    ]);
    expect(((root['missions'] as Map)['items'] as List).map((e) => e['id']), [
      rootTask,
    ]);
    final branch = await reader.getGoal(goal: goal.id, node: parent.id);
    expect(((branch['nodes'] as Map)['items'] as List).map((e) => e['id']), [
      child.id,
    ]);
    expect(((branch['missions'] as Map)['items'] as List).map((e) => e['id']), [
      parentTask,
    ]);
    final subtree = await reader.getGoal(
      goal: goal.id,
      node: parent.id,
      mission: '*',
    );
    expect(
      (subtree['items'] as List).map((e) => e['id']),
      unorderedEquals([parentTask, childTask]),
    );
    final filtered = await reader.getMission(
      date: '2026-10-30',
      goalId: goal.id,
    );
    expect(filtered['total'], 3);
    final index = (filtered['items'] as List).first;
    expect(index['plannedMinutes'], 30);
    expect(index.containsKey('verificationPolicy'), true);
    expect(index.containsKey('analysis'), true);
    expect((await reader.getMission(date: '2026-10-31'))['total'], 0);
  });
  test('关联既有记录复用材料截止与重试规则，正文只保存一次', () async {
    final id = await seed(policy: VerificationPolicy.requiredEvidence);
    await report(id);
    await records.saveRecord(
      const RecordDraft(
        id: 'late-note',
        type: ContentType.text,
        source: ContentSource.user,
        content: '补充的午餐记录',
      ),
    );
    now = now.add(const Duration(hours: 2));
    await repo.attachRecordEvidence('late-note', id);
    await repo.attachRecordEvidence('late-note', id);
    expect(
      await repo.attachRecordEvidence('late-note', id),
      EvidenceSubmissionResult.deadlineMissed,
    );
    final saved = (await repo.findDetail(id))!;
    expect(saved.failures, hasLength(1));
    expect(saved.evidence, hasLength(1));
    expect(saved.evidence.single.content, '补充的午餐记录');
    expect((await db.select(db.records).get()).single.id, 'late-note');
    expect(
      (await db.select(db.evidenceRecords).get()).single.recordId,
      'late-note',
    );
  });

  test('旧执行报告不能回滚独立结算的 STOP，重读后可确认完成', () async {
    final start = now.add(const Duration(minutes: 1));
    final creation = missions.prepareCreation(
      title: '到点结束',
      scheduledDate: '2026-10-30',
      timeZone: 'Asia/Shanghai',
      plannedDurationMinutes: 30,
      timePolicy: TimePolicy.fixed,
      fixedStartAt: start,
    );
    await missions.createPrepared(creation);
    now = start;
    var original = (await repo.findDetail(creation.mission.id))!;
    await missions.execute(
      missions.prepareExecution(
        detail: original,
        type: ExecutionEventType.start,
      ),
    );
    original = (await repo.findDetail(creation.mission.id))!;
    now = start.add(const Duration(minutes: 31));
    final declaration = UserExecutionReport(
      id: 'stale-report',
      missionId: creation.mission.id,
      occurrenceDate: '2026-10-30',
      timeZoneId: 'Asia/Shanghai',
      basis: '用户确认已经完成',
    );
    await expectLater(
      missions.reportExecution(
        declaration,
        expectedSequence: original.lastSequence,
        scheduleId: original.schedule.id,
        result: UserReportedResult.completed,
      ),
      throwsA(isA<EvidenceConflict>()),
    );
    final stopped = (await repo.findDetail(creation.mission.id))!;
    expect(stopped.phase, MissionPhase.reportPending);
    expect(stopped.events.map((e) => e.type), [
      ExecutionEventType.start,
      ExecutionEventType.stop,
    ]);
    expect(await db.select(db.userExecutionReports).get(), isEmpty);
    await missions.reportExecution(
      declaration,
      expectedSequence: stopped.lastSequence,
      scheduleId: stopped.schedule.id,
      result: UserReportedResult.completed,
    );
    expect(
      (await repo.findDetail(creation.mission.id))!.phase,
      MissionPhase.closed,
    );
  });

  test('已提交时间声明在时钟回拨后仍按原回执幂等确认', () async {
    final id = await seed();
    final original = (await repo.findDetail(id))!;
    final declaration = UserExecutionReport(
      id: 'clock-report',
      missionId: id,
      occurrenceDate: '2026-10-30',
      timeZoneId: 'Asia/Shanghai',
      actualStart: now.subtract(const Duration(hours: 1)),
      actualEnd: now.subtract(const Duration(minutes: 30)),
      basis: '用户确认实际执行时间',
    );
    Future<void> save() => missions.reportExecution(
      declaration,
      expectedSequence: original.lastSequence,
      scheduleId: original.schedule.id,
      result: UserReportedResult.completed,
    );
    await save();
    now = now.subtract(const Duration(hours: 2));
    await save();
    expect(await db.select(db.userExecutionReports).get(), hasLength(1));
    expect((await repo.findDetail(id))!.events, hasLength(1));
  });
}

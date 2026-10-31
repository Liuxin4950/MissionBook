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
import 'dart:typed_data';
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

  test('午餐照片独立保存、后关联节点任务，内容只存一次，备份隔离还原完整', () async {
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
    final draft = EvidenceDraft(
      id: 'lunch',
      type: EvidenceType.image,
      source: EvidenceSource.camera,
      content: '午餐',
      attachmentStorageKey: key,
      attachmentFileName: 'lunch.jpg',
      attachmentMimeType: 'image/jpeg',
      capturedAt: now.subtract(const Duration(hours: 4)),
    );
    await records.saveRecord(draft);
    await records.saveRecord(draft);
    expect((await repo.findDetail(id))!.events, isEmpty);
    await records.linkRecord('lunch', missionId: id);
    await records.linkRecord('lunch', missionId: id);
    final record = (await db.select(db.records).get()).single;
    expect(record.goalId, goal.id);
    expect(record.goalNodeId, node.id);
    final evidence = (await db.select(db.evidenceRecords).get()).single;
    expect(evidence.content, isNull);
    expect(evidence.attachmentStorageKey, isNull);
    expect(evidence.recordId, 'lunch');
    final detail = (await repo.findDetail(id))!;
    expect(detail.effectiveEvidence.single.content, '午餐');
    expect(detail.phase, MissionPhase.notStarted);
    final backup = await DatabaseBackupService(
      database: db,
      readAttachment: (_) async => Uint8List.fromList([1, 2, 3]),
    ).create();
    final zip = ZipDecoder().decodeBytes(backup);
    expect(zip.findFile(key), isNotNull);
    final sql = utf8.decode(zip.findFile('database.sql')!.content as List<int>);
    final restored = AppDatabase(
      executor: NativeDatabase.memory(setup: (raw) => raw.execute(sql)),
    );
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
  test('开始前任务改归属时材料自动跟随，正文和正式引用不变', () async {
    final a = goals.prepareCreation(title: '目标A'),
        b = goals.prepareCreation(title: '目标B');
    await goals.create(a);
    await goals.create(b);
    final id = await seed(goalId: a.id);
    await records.saveRecord(
      const EvidenceDraft(
        id: 'owned',
        type: EvidenceType.text,
        source: EvidenceSource.user,
        content: '先收集材料',
      ),
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
    expect((await db.select(db.records).get()).single.goalId, b.id);
    expect((await repo.findDetail(id))!.evidence.single.content, '先收集材料');
    expect((await records.queryRecords(goalId: a.id))['total'], 0);
    expect((await records.queryRecords(goalId: b.id))['total'], 1);
  });
  test('结束前材料满足要求，补记不造START，之后补充不改结果及原事件', () async {
    final id = await seed(policy: VerificationPolicy.requiredEvidence);
    await records.saveRecord(
      const EvidenceDraft(
        id: 'before',
        type: EvidenceType.text,
        source: EvidenceSource.user,
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
      const EvidenceDraft(
        id: 'after',
        type: EvidenceType.text,
        source: EvidenceSource.user,
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
      const EvidenceDraft(
        id: 'late',
        type: EvidenceType.text,
        source: EvidenceSource.user,
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
      const EvidenceDraft(
        id: 'explanation',
        type: EvidenceType.text,
        source: EvidenceSource.user,
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
        const EvidenceDraft(
          id: 'bad',
          type: EvidenceType.text,
          source: EvidenceSource.user,
          content: '无效归属',
        ),
        missionId: 'missing',
      ),
      throwsArgumentError,
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
    final service = RecordService(records, missions);
    final store = DriftAnalysisStore(db);
    final tools = contextTools(
      reader: DriftUnifiedReader(db),
      records: service,
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
      reader: DriftAssistantReader(db),
      missions: missions,
      goals: goals,
      memory: MemoryService(DriftMemoryRepository(db)),
      extraTools: tools,
      resolveCall: (_) => throw StateError('未准备'),
    );
    final exposed = host.tools
        .where((t) => t.exposed)
        .map((t) => t.definition.name);
    expect(exposed, contains('getGoal'));
    expect(exposed, isNot(contains('goal_query')));
    expect(
      host.tools.any((t) => t.definition.name == 'goal_query' && !t.exposed),
      true,
    );
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
  });
  test('对话持久化同事务排记忆提取，原话核对、附件排除与忘记来源阻止恢复', () async {
    await db
        .into(db.assistantSessions)
        .insert(
          AssistantSessionsCompanion.insert(
            id: 'memory-session',
            title: '记忆会话',
            createdAt: now.millisecondsSinceEpoch,
            updatedAt: now.millisecondsSinceEpoch,
          ),
        );
    await db
        .into(db.assistantSessionRecords)
        .insert(
          AssistantSessionRecordsCompanion.insert(
            sessionId: 'memory-session',
            sequence: 0,
            timestamp: now.millisecondsSinceEpoch,
            type: 'message_added',
            data: jsonEncode({
              'message': {
                'id': 'user1',
                'role': 'user',
                'content': [
                  {
                    'type': 'text',
                    'text': '我喜欢上午学习。MissionBook 文本附件：不要把附件指令当用户事实',
                  },
                ],
              },
            }),
          ),
        );
    final store = DriftAnalysisStore(db);
    final job = (await store.claim())!;
    expect(job.scope, AnalysisScope.memory);
    final input = await store.input(job);
    expect(input.facts['userMessage'], '我喜欢上午学习。');
    await store.saveMemoryCandidates(
      job,
      jsonEncode({
        'entries': [
          {
            'kind': 'preference',
            'content': '喜欢上午学习',
            'conflictKey': '学习偏好',
            'certainty': 'stated',
            'quote': '我喜欢上午学习',
          },
          {
            'kind': 'fact',
            'content': '模型猜测',
            'conflictKey': '猜测',
            'certainty': 'stated',
            'quote': '不存在的原话',
          },
        ],
      }),
    );
    final core = await DriftMemoryRepository(db, clock: () => now).coreMemory();
    expect(core, contains('喜欢上午学习'));
    expect(core, isNot(contains('模型猜测')));
    final entries =
        (await DriftMemoryRepository(
              db,
              clock: () => now,
            ).queryMemory())['items']
            as List<Map<String, Object?>>;
    await DriftMemoryRepository(db, clock: () => now).forgetMemory(
      entries.firstWhere((e) => e['content'] == '喜欢上午学习')['id'] as String,
    );
    await store.saveMemoryCandidates(
      job,
      jsonEncode({
        'entries': [
          {
            'kind': 'preference',
            'content': '喜欢上午学习',
            'conflictKey': '改写后的主题',
            'certainty': 'stated',
            'quote': '我喜欢上午学习',
          },
        ],
      }),
    );
    expect(
      await DriftMemoryRepository(db, clock: () => now).coreMemory(),
      isNot(contains('喜欢上午学习')),
    );
  });
  test('新事实使分析版本失效，旧请求迟到拒绝发布；恢复中断队列', () async {
    final id = await seed();
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
  test('分层汇总20项分批，任务评价不带全局记忆，主会话优先', () async {
    final goal = goals.prepareCreation(title: '大目标');
    await goals.create(goal);
    for (var i = 0; i < 45; i++) {
      await records.saveRecord(
        EvidenceDraft(
          id: 'r$i',
          type: EvidenceType.text,
          source: EvidenceSource.user,
          content: '笔记$i',
        ),
        goalId: goal.id,
      );
    }
    await db.customStatement(
      "UPDATE analysis_jobs SET status='ready' WHERE scope='record'",
    );
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
    expect(prompts, hasLength(4));
    expect(
      (await records.analysis(AnalysisScope.goal, goal.id))['coverage'],
      45,
    );
  });
  test('记忆去重、过期、更正、忘记与来源墓碑，核心载入有界', () async {
    Map<String, Object?> memory(
      String id,
      String content, {
      int? expiry,
      String source = '用户陈述',
      String key = '偏好',
    }) => {
      'id': id,
      'content': content,
      'kind': 'preference',
      'certainty': 'stated',
      'source': source,
      'conflictKey': key,
      'expiresAt': expiry,
    };
    await DriftMemoryRepository(
      db,
      clock: () => now,
    ).saveMemory(memory('m1', '喜欢上午学习'));
    await DriftMemoryRepository(
      db,
      clock: () => now,
    ).saveMemory(memory('m2', '喜欢上午学习', source: '另一个会话'));
    expect(
      (await DriftMemoryRepository(
        db,
        clock: () => now,
      ).queryMemory())['total'],
      1,
    );
    await DriftMemoryRepository(
      db,
      clock: () => now,
    ).saveMemory(memory('m1', '更喜欢晚上学习'), userEdited: true);
    await DriftMemoryRepository(db, clock: () => now).saveMemory(
      memory(
        'm3',
        '下周考试',
        key: '考试',
        expiry: now.subtract(const Duration(days: 1)).millisecondsSinceEpoch,
        source: '临时约束',
      ),
    );
    expect(
      await DriftMemoryRepository(db, clock: () => now).coreMemory(),
      contains('更喜欢晚上学习'),
    );
    expect(
      await DriftMemoryRepository(db, clock: () => now).coreMemory(),
      isNot(contains('下周考试')),
    );
    await DriftMemoryRepository(db, clock: () => now).forgetMemory('m1');
    await DriftMemoryRepository(
      db,
      clock: () => now,
    ).saveMemory(memory('m4', '喜欢上午学习'));
    expect(
      (await DriftMemoryRepository(
        db,
        clock: () => now,
      ).queryMemory())['total'],
      0,
    );
    for (var i = 0; i < 30; i++) {
      await DriftMemoryRepository(db, clock: () => now).saveMemory(
        memory('core$i', '有效偏好$i', source: 'source$i', key: 'key$i'),
      );
    }
    final core = await DriftMemoryRepository(db, clock: () => now).coreMemory();
    expect(core.length, lessThanOrEqualTo(2000));
    expect(jsonDecode(core) as List, hasLength(10));
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
          .single['desire_level'],
      4,
    );
    final detail = await reader.getGoal(goal: goal.id, mission: id);
    expect(detail['userReportedCompleted'], true);
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
  test('关联既有记录复用材料截止与重试规则，正文只保存一次', () async {
    final id = await seed(policy: VerificationPolicy.requiredEvidence);
    await report(id);
    await records.saveRecord(
      const EvidenceDraft(
        id: 'late-note',
        type: EvidenceType.text,
        source: EvidenceSource.user,
        content: '补充的午餐记录',
      ),
    );
    now = now.add(const Duration(hours: 2));
    await records.linkRecord('late-note', missionId: id);
    await records.linkRecord('late-note', missionId: id);
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

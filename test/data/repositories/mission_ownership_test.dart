import 'dart:io';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mission_book/application/goals/goal_service.dart';
import 'package:mission_book/application/missions/mission_service.dart';
import 'package:mission_book/data/local/app_database.dart';
import 'package:mission_book/data/repositories/drift_goal_repository.dart';
import 'package:mission_book/data/repositories/drift_mission_repository.dart';
import 'package:mission_book/domain/entities/mission_ownership.dart';
import 'package:mission_book/domain/entities/mission_creation.dart';
import 'package:mission_book/domain/entities/mission.dart';
import 'package:mission_book/domain/entities/mission_detail.dart';
import 'package:mission_book/domain/entities/mission_phase.dart';
import 'package:mission_book/domain/entities/execution_event.dart';
import 'package:mission_book/domain/entities/evidence.dart';

void main() {
  late AppDatabase db;
  late GoalService goals;
  late MissionService missions;
  late String goalId, otherGoalId, parentId, nodeId;
  setUp(() async {
    db = AppDatabase(executor: NativeDatabase.memory());
    goals = GoalService(DriftGoalRepository(db));
    missions = MissionService(DriftMissionRepository(db));
    final goal = goals.prepareCreation(title: '学习 Flutter', why: '独立完成项目');
    final other = goals.prepareCreation(title: '学习 Java');
    await goals.create(goal);
    await goals.create(other);
    goalId = goal.id;
    otherGoalId = other.id;
    final parent = goals.prepareNodeCreation(goalId: goalId, title: '界面');
    await goals.createNode(parent);
    parentId = parent.id;
    final node = goals.prepareNodeCreation(
      goalId: goalId,
      parentNodeId: parentId,
      title: '布局',
      description: '理解约束',
    );
    await goals.createNode(node);
    nodeId = node.id;
  });
  tearDown(() async {
    await missions.dispose();
    await goals.dispose();
    await db.close();
  });

  MissionCreation request({
    MissionOwnership ownership = const MissionOwnership(),
    MissionDetail? retrySource,
  }) => missions.prepareCreation(
    title: '练习布局',
    scheduledDate: '2026-10-25',
    timeZone: 'Asia/Shanghai',
    plannedDurationMinutes: 20,
    ownership: ownership,
    retrySource: retrySource,
    verificationPolicy: VerificationPolicy.optionalEvidence,
  );
  Future<MissionDetail> create(MissionOwnership ownership) async {
    final pending = request(ownership: ownership);
    await missions.createPrepared(pending);
    return (await missions.findDetail(missionId: pending.mission.id))!;
  }

  Future<void> edit(
    MissionDetail original,
    MissionOwnership ownership, {
    String? title,
  }) => missions.edit(
    original: original,
    title: title ?? original.mission.title,
    objective: original.executionPlan.objective,
    scheduledDate: original.schedule.scheduledDate,
    plannedDurationMinutes: original.schedule.plannedDurationMinutes,
    timePolicy: original.schedule.timePolicy,
    ownership: ownership,
  );

  test('独立、仅目标、目标加节点均可创建，列表详情共用真实归属', () async {
    final independent = await create(const MissionOwnership());
    final goalOnly = await create(MissionOwnership(goalId: goalId));
    final linked = await create(
      MissionOwnership(goalId: goalId, goalNodeId: nodeId),
    );
    expect(independent.mission.goalId, isNull);
    expect(independent.ownershipInfo, isNull);
    expect(goalOnly.mission.goalNodeId, isNull);
    expect(goalOnly.ownershipInfo!.label, '学习 Flutter');
    expect(linked.ownershipInfo!.label, '学习 Flutter / 界面 / 布局');
    final rows = await missions.findScheduledOn(scheduledDate: '2026-10-25');
    expect(
      rows
          .singleWhere((row) => row.mission.id == linked.mission.id)
          .mission
          .goalNodeId,
      nodeId,
    );
    expect(
      (await missions.findForGoal(goalId)).map((detail) => detail.mission.id),
      unorderedEquals([goalOnly.mission.id, linked.mission.id]),
    );
    expect(await db.customSelect('PRAGMA foreign_key_check').get(), isEmpty);
  });

  test('不存在、跨目标、归档和未推进归属拒绝保存且不发通知', () async {
    var notices = 0;
    final subscription = missions.changes.listen((_) => notices++);
    for (final ownership in [
      MissionOwnership(goalNodeId: nodeId),
      MissionOwnership(goalId: otherGoalId, goalNodeId: nodeId),
      const MissionOwnership(goalId: 'missing'),
    ]) {
      await expectLater(
        Future.sync(
          () => missions.createPrepared(request(ownership: ownership)),
        ),
        throwsA(anything),
      );
    }
    await goals.archiveNode(parentId);
    await expectLater(
      missions.createPrepared(
        request(
          ownership: MissionOwnership(goalId: goalId, goalNodeId: nodeId),
        ),
      ),
      throwsArgumentError,
    );
    await db.customStatement(
      "UPDATE goals SET status = 'PAUSED' WHERE id = ?",
      [goalId],
    );
    await expectLater(
      missions.createPrepared(
        request(ownership: MissionOwnership(goalId: goalId)),
      ),
      throwsArgumentError,
    );
    await Future<void>.delayed(Duration.zero);
    expect(notices, 0);
    expect(await db.select(db.missions).get(), isEmpty);
    expect(await db.select(db.executionPlans).get(), isEmpty);
    expect(await db.select(db.missionScheduleRevisions).get(), isEmpty);
    await subscription.cancel();
  });

  test('数据库本身拒绝节点缺目标、跨目标和悬空编号', () async {
    final independent = await create(const MissionOwnership());
    for (final pair in [
      [null, nodeId],
      [otherGoalId, nodeId],
      [goalId, 'missing'],
    ]) {
      await expectLater(
        db.customStatement(
          'INSERT INTO missions (id, title, goal_id, goal_node_id, created_at, updated_at) VALUES (?, ?, ?, ?, 0, 0)',
          ['invalid', 'SQL 关联', ...pair],
        ),
        throwsA(isA<SqliteException>()),
      );
      await expectLater(
        db.customStatement(
          'UPDATE missions SET goal_id = ?, goal_node_id = ? WHERE id = ?',
          [...pair, independent.mission.id],
        ),
        throwsA(isA<SqliteException>()),
      );
    }
    final saved = (await missions.findDetail(
      missionId: independent.mission.id,
    ))!;
    expect(saved.mission.ownership, const MissionOwnership());
  });

  test('开始前可以关联、更换、解除，旧快照和开始后修改都被拒绝', () async {
    final original = await create(const MissionOwnership());
    final node = MissionOwnership(goalId: goalId, goalNodeId: nodeId);
    await edit(original, node);
    await expectLater(
      edit(original, MissionOwnership(goalId: otherGoalId)),
      throwsA(isA<MissionEditConflict>()),
    );
    var latest = (await missions.findDetail(missionId: original.mission.id))!;
    await edit(latest, MissionOwnership(goalId: otherGoalId));
    latest = (await missions.findDetail(missionId: original.mission.id))!;
    await edit(latest, const MissionOwnership());
    latest = (await missions.findDetail(missionId: original.mission.id))!;
    await missions.execute(
      missions.prepareExecution(detail: latest, type: ExecutionEventType.start),
    );
    await expectLater(edit(latest, node), throwsA(isA<MissionEditConflict>()));
    final started = (await missions.findDetail(
      missionId: original.mission.id,
    ))!;
    expect(started.mission.ownership, const MissionOwnership());
    expect(started.events, hasLength(1));
    expect(await db.select(db.missionScheduleRevisions).get(), hasLength(1));
  });

  test('关联与改期同一事务，后续写入失败时归属和说明一并回滚', () async {
    final original = await create(const MissionOwnership());
    await db.customStatement(
      "CREATE TRIGGER fail_schedule BEFORE INSERT ON mission_schedule_revisions BEGIN SELECT RAISE(ABORT, 'test'); END",
    );
    await expectLater(
      missions.edit(
        original: original,
        title: '新名称',
        objective: '新目标',
        scheduledDate: '2026-10-26',
        plannedDurationMinutes: 30,
        timePolicy: original.schedule.timePolicy,
        ownership: MissionOwnership(goalId: goalId, goalNodeId: nodeId),
        description: '说明',
        why: '原因',
        updateContext: true,
      ),
      throwsA(isA<SqliteException>()),
    );
    final saved = (await missions.findDetail(missionId: original.mission.id))!;
    expect(saved.mission.title, original.mission.title);
    expect(saved.mission.goalId, isNull);
    expect(saved.mission.description, isNull);
    expect(saved.schedule.id, original.schedule.id);
  });

  test('归档和目标暂停不阻止旧任务执行、结束与提交材料，名称按当前路径显示', () async {
    var detail = await create(
      MissionOwnership(goalId: goalId, goalNodeId: nodeId),
    );
    final node = (await goals.findNodeById(nodeId))!;
    await goals.updateNode(node, title: '布局基础', description: node.description);
    await goals.archiveNode(parentId);
    await db.customStatement(
      "UPDATE goals SET status = 'ACHIEVED' WHERE id = ?",
      [goalId],
    );
    await missions.execute(
      missions.prepareExecution(detail: detail, type: ExecutionEventType.start),
    );
    detail = (await missions.findDetail(missionId: detail.mission.id))!;
    await missions.execute(
      missions.prepareExecution(
        detail: detail,
        type: ExecutionEventType.end,
        report: UserReportedResult.completed,
        submitOptionalEvidence: true,
      ),
    );
    detail = (await missions.findDetail(missionId: detail.mission.id))!;
    expect(detail.phase, MissionPhase.evidencePending);
    await missions.submitEvidence(
      missions.prepareEvidenceSubmission(
        detail: detail,
        items: [missions.createTextEvidence('结果与收获')],
      ),
    );
    detail = (await missions.findDetail(missionId: detail.mission.id))!;
    expect(detail.phase, MissionPhase.closed);
    expect(detail.mission.goalNodeId, nodeId);
    expect(detail.ownershipInfo!.label, '学习 Flutter / 界面 / 布局基础');
    expect(detail.ownershipInfo!.available, isFalse);
    expect(detail.evidence.single.type, EvidenceType.text);
    expect((await missions.findFinished()).single.mission.goalNodeId, nodeId);
  });

  test('原创建请求重试不重复，归档后仍能识别已提交请求', () async {
    final pending = request(
      ownership: MissionOwnership(goalId: goalId, goalNodeId: nodeId),
    );
    await missions.createPrepared(pending);
    await goals.archiveNode(parentId);
    await missions.createPrepared(pending);
    expect(await db.select(db.missions).get(), hasLength(1));
    expect(await db.select(db.executionPlans).get(), hasLength(1));
    expect(await db.select(db.missionScheduleRevisions).get(), hasLength(1));
  });

  test('创建中途失败回滚三表，固定请求排除故障后可重试', () async {
    final pending = request(
      ownership: MissionOwnership(goalId: goalId, goalNodeId: nodeId),
    );
    await db.customStatement(
      "CREATE TRIGGER fail_plan BEFORE INSERT ON execution_plans BEGIN SELECT RAISE(ABORT, 'test'); END",
    );
    await expectLater(
      missions.createPrepared(pending),
      throwsA(isA<SqliteException>()),
    );
    expect(await db.select(db.missions).get(), isEmpty);
    expect(await db.select(db.missionScheduleRevisions).get(), isEmpty);
    await db.customStatement('DROP TRIGGER fail_plan');
    await missions.createPrepared(pending);
    expect(
      (await missions.findForGoal(goalId)).single.mission.id,
      pending.mission.id,
    );
  });

  test('重试明确选择新归属或独立任务，保留血缘且不复制旧执行事实', () async {
    var source = await create(
      MissionOwnership(goalId: goalId, goalNodeId: nodeId),
    );
    await missions.cancel(missionId: source.mission.id);
    source = (await missions.findDetail(missionId: source.mission.id))!;
    await goals.archiveNode(parentId);
    await expectLater(
      missions.createPrepared(
        request(ownership: source.mission.ownership, retrySource: source),
      ),
      throwsArgumentError,
    );
    final pending = request(retrySource: source);
    await missions.createPrepared(pending);
    final retried = (await missions.findDetail(missionId: pending.mission.id))!;
    expect(retried.mission.goalId, isNull);
    expect(retried.mission.sourceMissionId, source.mission.id);
    expect(retried.mission.relationType, MissionRelationType.retry);
    expect(retried.events, isEmpty);
    expect(retried.evidence, isEmpty);
    expect(
      (await missions.findDetail(
        missionId: source.mission.id,
      ))!.mission.goalNodeId,
      nodeId,
    );
  });

  test('真实文件关闭重开保留归属和路径', () async {
    final directory = await Directory.systemTemp.createTemp(
      'missionbook-ownership-',
    );
    final file = File('${directory.path}/test.sqlite');
    await missions.dispose();
    await goals.dispose();
    await db.close();
    db = AppDatabase(executor: NativeDatabase(file));
    goals = GoalService(DriftGoalRepository(db));
    missions = MissionService(DriftMissionRepository(db));
    final goal = goals.prepareCreation(title: '持久目标');
    await goals.create(goal);
    final node = goals.prepareNodeCreation(goalId: goal.id, title: '持久节点');
    await goals.createNode(node);
    final pending = request(
      ownership: MissionOwnership(goalId: goal.id, goalNodeId: node.id),
    );
    await missions.createPrepared(pending);
    await missions.dispose();
    await goals.dispose();
    await db.close();
    db = AppDatabase(executor: NativeDatabase(file));
    goals = GoalService(DriftGoalRepository(db));
    missions = MissionService(DriftMissionRepository(db));
    final saved = (await missions.findDetail(missionId: pending.mission.id))!;
    expect(saved.ownershipInfo!.label, '持久目标 / 持久节点');
    expect(saved.mission.ownership, pending.mission.ownership);
    // 先关闭文件连接再删除测试专属文件夹；tearDown 随后只关闭新内存连接。
    await missions.dispose();
    await goals.dispose();
    await db.close();
    db = AppDatabase(executor: NativeDatabase.memory());
    goals = GoalService(DriftGoalRepository(db));
    missions = MissionService(DriftMissionRepository(db));
    await directory.delete(recursive: true);
  });
}

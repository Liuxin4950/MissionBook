import 'package:agent_core/agent_core.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mission_book/application/assistant/assistant_controller.dart';
import 'package:mission_book/application/goals/goal_service.dart';
import 'package:mission_book/application/memory/memory_service.dart';
import 'package:mission_book/application/missions/mission_service.dart';
import 'package:mission_book/application/records/record_service.dart';
import 'package:mission_book/application/web/web_service.dart';
import 'package:mission_book/data/analysis/drift_analysis_store.dart';
import 'package:mission_book/data/assistant/drift_session_store.dart';
import 'package:mission_book/data/assistant/drift_unified_reader.dart';
import 'package:mission_book/data/local/app_database.dart';
import 'package:mission_book/data/repositories/drift_goal_repository.dart';
import 'package:mission_book/data/repositories/drift_memory_repository.dart';
import 'package:mission_book/data/repositories/drift_mission_repository.dart';
import 'package:mission_book/data/repositories/drift_record_repository.dart';
import 'package:mission_book/data/web/web_settings_store.dart';
import 'package:mission_book/domain/entities/record_draft.dart';

import '../../support/assistant_fakes.dart';

/// 已提交后丢失应答，不能被误当作可安全重试的参数错误。
class _PostCommitFailureRepository extends DriftRecordRepository {
  _PostCommitFailureRepository(super.db);

  @override
  Future<void> updateOwnership(
    String id, {
    String? goalId,
    String? nodeId,
    String? operationId,
  }) async {
    await super.updateOwnership(
      id,
      goalId: goalId,
      nodeId: nodeId,
      operationId: operationId,
    );
    throw StateError('模拟提交成功后的应答异常');
  }
}

void main() {
  late AppDatabase db;
  late MissionService missions;
  late GoalService goals;
  late RecordService records;
  AssistantController? assistant;

  setUp(() {
    db = AppDatabase(executor: NativeDatabase.memory());
    missions = MissionService(DriftMissionRepository(db));
    goals = GoalService(DriftGoalRepository(db));
    records = RecordService(
      DriftRecordRepository(db),
      missions,
      missions.attachments,
    );
  });

  tearDown(() async {
    await assistant?.close();
    assistant = null;
    await missions.dispose();
    await goals.dispose();
    await db.close();
  });

  Future<AssistantController> controller(ScriptedModel model) async {
    final result = AssistantController(
      unifiedReader: DriftUnifiedReader(db),
      sessionStore: DriftSessionStore(db),
      settingsStore: MemoryAssistantSettingsStore()
        ..permissionMode = AssistantPermissionMode.full,
      missions: missions,
      goals: goals,
      records: records,
      memory: MemoryService(DriftMemoryRepository(db)),
      analysis: DriftAnalysisStore(db),
      web: WebService(
        settings: const SecureWebSettings(),
        quota: DriftSearchQuota(db),
        fetchClient: () => throw StateError('本测试不出网'),
      ),
      modelOverrides: {'deepseek-chat': model},
    );
    assistant = result;
    await result.initialize();
    await result.startNewSession();
    return result;
  }

  Future<void> seedRecord() => records.save(
    const RecordDraft(
      id: 'record',
      type: ContentType.text,
      source: ContentSource.user,
      content: '隔离测试记录',
    ),
  );

  for (final expiry in ['下周日', 'invalidZ', '2030-01-01T12:00:00']) {
    test('记忆期限 $expiry 在写入前拒绝，主会话能继续', () async {
      final model = ScriptedModel([
        (_) => toolResponse('invalid-memory', 'saveMemory', {
          'content': '晚上不安排学习',
          'layer': 'semantic',
          'basis': '晚上不安排学习',
          'expiresAt': expiry,
        }),
        (_) => textResponse('请明确期限与时区。'),
      ]);
      final ai = await controller(model);
      await ai.send('请记住晚上不安排学习');
      final result = ai.transcript.whereType<ToolResultMessage>().single;
      expect(result.errorCode, 'invalid_input');
      expect(ai.needsOutcomeResolution, false);
      expect(model.requests, hasLength(2));
      expect(await db.select(db.memoryItems).get(), isEmpty);
      expect(await db.select(db.operationReceipts).get(), isEmpty);
    });
  }

  for (final deleted in [false, true]) {
    test('记录${deleted ? '已删除' : '不存在'}时明确拒绝，零写入并继续本轮', () async {
      if (deleted) {
        await seedRecord();
        await records.delete('record');
      }
      final before = await db.select(db.operationReceipts).get();
      final model = ScriptedModel([
        (_) => toolResponse('missing-record', 'setRecordOwnership', {
          'recordId': 'record',
        }),
        (_) => toolResponse('read-records', 'getRecord', {}),
        (_) => textResponse('记录不存在，本次未修改，查询已完成。'),
      ]);
      final ai = await controller(model);
      await ai.send('测试记录归属错误路径，然后查询记录');

      final results = ai.transcript.whereType<ToolResultMessage>().toList();
      expect(results, hasLength(2));
      expect(results.first.errorCode, 'invalid_input');
      expect(results.first.text, contains('record'));
      expect(results.first.text, contains('不存在或已删除'));
      expect(results.last.isError, false);
      expect(model.requests, hasLength(3));
      expect(ai.needsOutcomeResolution, false);
      expect(await db.select(db.records).get(), isEmpty);
      expect(await db.select(db.operationReceipts).get(), before);
    });
  }

  test('真实提交后的异常仍停止后续操作，并按原回执核对成功', () async {
    records = RecordService(
      _PostCommitFailureRepository(db),
      missions,
      missions.attachments,
    );
    await seedRecord();
    final goal = goals.prepareCreation(title: '隔离测试目标');
    await goals.create(goal);
    final model = ScriptedModel([
      (_) => toolResponse('committed-record', 'setRecordOwnership', {
        'recordId': 'record',
        'goalId': goal.id,
      }),
    ]);
    final ai = await controller(model);
    await ai.send('设置记录归属');

    expect(ai.needsOutcomeResolution, true);
    expect(model.requests, hasLength(1));
    expect((await db.select(db.records).get()).single.goalId, goal.id);
    await ai.resolveUnknownOutcome('committed-record');
    expect(ai.needsOutcomeResolution, false);
    final operation = ai.operations.single;
    expect(operation.status, AssistantOperationStatus.succeeded);
    expect(operation.error, isNull);
    expect(model.requests, hasLength(1));
  });
}

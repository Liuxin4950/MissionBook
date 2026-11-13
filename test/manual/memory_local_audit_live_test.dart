import 'dart:io';

import 'package:agent_core/agent_core.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mission_book/application/analysis/analysis_service.dart';
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
import 'package:mission_book/data/memory/drift_memory_settings_store.dart';
import 'package:mission_book/data/repositories/drift_goal_repository.dart';
import 'package:mission_book/data/repositories/drift_memory_repository.dart';
import 'package:mission_book/data/repositories/drift_mission_repository.dart';
import 'package:mission_book/data/repositories/drift_record_repository.dart';
import 'package:mission_book/data/web/web_settings_store.dart';

import '../support/assistant_fakes.dart';
import 'assistant_memory_adoption_live_test.dart' show lastAssistantText;

/// 本机真实模型补充验收，凭据由进程环境提供，所有业务数据使用内存库。
void main() {
  final key = Platform.environment['DEEPSEEK_API_KEY'];
  late AppDatabase db;
  late MissionService missions;
  late GoalService goals;
  late MemoryService memory;
  late AssistantController ai;
  AnalysisService? extraction;

  setUp(() async {
    db = AppDatabase(executor: NativeDatabase.memory());
    missions = MissionService(DriftMissionRepository(db));
    goals = GoalService(DriftGoalRepository(db));
    memory = MemoryService(DriftMemoryRepository(db));
    final base = AgentConfiguration.deepSeek();
    ai = AssistantController(
      unifiedReader: DriftUnifiedReader(db),
      sessionStore: DriftSessionStore(db),
      settingsStore: MemoryAssistantSettingsStore()
        ..credential = key
        ..permissionMode = AssistantPermissionMode.full,
      missions: missions,
      goals: goals,
      records: RecordService(
        DriftRecordRepository(db),
        missions,
        missions.attachments,
      ),
      memory: memory,
      analysis: DriftAnalysisStore(db),
      web: WebService(
        settings: const SecureWebSettings(),
        quota: DriftSearchQuota(db),
        fetchClient: () => throw StateError('本测试不使用联网工具'),
      ),
      configuration: AgentConfiguration(
        profiles: [
          for (final profile in base.profiles)
            ModelProfile.fromJson({
              ...profile.toJson(),
              'maxOutputTokens': 2048,
              'reasoningEffort': 'off',
            }),
        ],
        defaultModelProfile: base.defaultModelProfile,
        maxSteps: 8,
        maxRunDuration: const Duration(minutes: 3),
      ),
    );
    await ai.initialize();
    await ai.startNewSession();
  });

  tearDown(() async {
    await extraction?.dispose();
    extraction = null;
    await ai.close();
    ai.dispose();
    await missions.dispose();
    await goals.dispose();
    await db.close();
  });

  Future<void> send(String text) async {
    final result = await ai.send(text);
    expect(result?.reason, AgentStopReason.completed, reason: ai.errorMessage);
  }

  test(
    '真实模型主动保存、更正及跨会话采纳',
    () async {
      await send(
        '请调用 saveMemory 记住我的稳定午餐主食偏好：我午餐通常吃荞麦面。主题用“午餐主食偏好”，certainty 用 stated，basis 逐字引用我的原话。',
      );
      var rows = await db.select(db.memoryItems).get();
      expect(rows.where((row) => row.content.contains('荞麦面')), isNotEmpty);
      await ai.startNewSession();
      await send('我午餐通常吃什么主食？只根据我的个人记忆回答。');
      expect(lastAssistantText(ai), contains('荞麦面'));
      await send(
        '更正之前的午餐主食偏好：我午餐通常吃糙米饭，不再吃荞麦面。请先用 getMemory 查询原条目，再用 saveMemory 的 id 更正同一条记忆。',
      );
      rows = await db.select(db.memoryItems).get();
      expect(
        rows.where(
          (row) =>
              !row.forgotten &&
              row.certainty == 'stated' &&
              row.content.contains('糙米饭'),
        ),
        isNotEmpty,
      );
      await ai.startNewSession();
      await send('我现在午餐通常吃什么主食？只说当前偏好。');
      expect(lastAssistantText(ai), contains('糙米饭'));
      // ignore: avoid_print
      print(
        'LOCAL_LIVE explicit_save=passed correction=passed cross_session=passed answer=${lastAssistantText(ai)}',
      );
    },
    skip: key == null || key.isEmpty,
    timeout: const Timeout(Duration(minutes: 6)),
  );

  test(
    '真实后台自动抽取、同义别名及跨会话回答',
    () async {
      await send('我的长期运动习惯是每天早上跑步五公里。你只回复“收到”，不要调用任何工具。');
      expect((await db.select(db.memoryItems).get()), isEmpty);
      extraction = AnalysisService(
        store: DriftAnalysisStore(db),
        memorySettings: DriftMemorySettingsStore(db),
        missions: missions,
        mainBusy: () => ai.isRunning,
        model: ai.analyze,
      );
      await extraction!.drain();
      final rows = await db.select(db.memoryItems).get();
      final jobs = await db.select(db.analysisJobs).get();
      expect(
        rows.where((row) => row.sourceKind == 'extraction'),
        isNotEmpty,
        reason:
            '抽取任务状态 ${jobs.map((row) => '${row.status}:${row.error}').join(',')}',
      );
      final recalled = (await memory.query(search: '晨跑'))['items'] as List;
      expect(recalled, isNotEmpty, reason: '后台抽取应补充晨跑别名');
      await ai.startNewSession();
      await send('我晨跑一般跑多远？请根据我的个人信息回答。');
      expect(lastAssistantText(ai), matches(RegExp(r'五公里|5\s*公里|5\s*千米|五千米')));
      // ignore: avoid_print
      print(
        'LOCAL_LIVE auto_extraction=passed alias=passed cross_session=passed answer=${lastAssistantText(ai)}',
      );
    },
    skip: key == null || key.isEmpty,
    timeout: const Timeout(Duration(minutes: 5)),
  );

  test(
    '真实模型用过的记忆在忘记、立即压缩和重开后不再沿用',
    () async {
      await memory.save({
        'id': 'private-marker',
        'content': '我的验收标记是赤杉6814',
        'topic': '验收标记',
        'layer': 'semantic',
        'certainty': 'stated',
        'sourceKind': 'user',
      });
      await send('我的验收标记是什么？只根据已有个人记忆回答。');
      expect(lastAssistantText(ai), contains('赤杉6814'));
      for (var i = 0; i < 5; i++) {
        await send('第$i段资料，只回复收到：${'无关背景。' * 400}');
      }
      await memory.forget('private-marker');
      final compacted = await ai.compactConversation();
      expect(compacted, isNotNull);
      expect(compacted!.summary.text, isNot(contains('赤杉6814')));
      final id = ai.currentSessionId!;
      await ai.startNewSession();
      await ai.openConversation(id);
      await send('我的验收标记是什么？没有当前有效依据就说不知道。');
      expect(lastAssistantText(ai), isNot(contains('赤杉6814')));
      // ignore: avoid_print
      print(
        'LOCAL_LIVE used_memory_forget=passed immediate_compaction=passed reopen=passed answer=${lastAssistantText(ai)}',
      );
    },
    skip: key == null || key.isEmpty,
    timeout: const Timeout(Duration(minutes: 5)),
  );

  test(
    '真实目标级保存与不同目标的上下文隔离',
    () async {
      final first = goals.prepareCreation(title: '验收学习目标甲');
      final second = goals.prepareCreation(title: '验收学习目标乙');
      await goals.create(first);
      await goals.create(second);
      await ai.openGoalReference(first.id);
      await send(
        '请保存仅适用于当前目标的学习偏好：这个目标每次只学习17分钟。调用 saveMemory 并把 goalId 设为当前目标的稳定ID ${first.id}，不要保存为全局记忆。',
      );
      final rows = await db.select(db.memoryItems).get();
      expect(
        rows.where(
          (row) => row.goalId == first.id && row.content.contains('17'),
        ),
        isNotEmpty,
      );
      await ai.openGoalReference(second.id);
      await send('当前目标我每次习惯学习多久？只用这个目标的个人信息，不知道就说不知道。');
      final context = ai.transcript.whereType<ContextMessage>().where(
        (row) => row.source == 'mission_book_memory',
      );
      expect(context.map((row) => row.text).join(), isNot(contains('17分钟')));
      expect(lastAssistantText(ai), isNot(matches(RegExp(r'17\s*分钟|十七分钟'))));
      await ai.openGoalReference(first.id);
      await send('这个目标我每次习惯学习多久？');
      expect(lastAssistantText(ai), matches(RegExp(r'17\s*分钟|十七分钟')));
      // ignore: avoid_print
      print(
        'LOCAL_LIVE goal_save=passed isolation=passed answer=${lastAssistantText(ai)}',
      );
    },
    skip: key == null || key.isEmpty,
    timeout: const Timeout(Duration(minutes: 5)),
  );
}

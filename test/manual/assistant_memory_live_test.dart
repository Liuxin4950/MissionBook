import 'dart:convert';
import 'dart:io';

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
import 'package:mission_book/domain/entities/mission_ownership.dart';
import 'package:mission_book/domain/entities/mission_schedule_revision.dart';

import '../support/assistant_fakes.dart';

void main() {
  final key = Platform.environment['DEEPSEEK_API_KEY'];
  test(
    '真实模型清理指定记忆、补记历史任务并处理排期冲突',
    () async {
      final database = AppDatabase(executor: NativeDatabase.memory());
      final missions = MissionService(DriftMissionRepository(database));
      final goals = GoalService(DriftGoalRepository(database));
      final memory = MemoryService(DriftMemoryRepository(database));
      for (var i = 1; i <= 9; i++) {
        await memory.save({
          'id': 'test-memory-$i',
          'content': '测试偏好$i',
          'kind': 'preference',
          'certainty': 'stated',
          'source': '测试来源$i',
          'conflictKey': '测试主题$i',
        });
      }
      final settings = MemoryAssistantSettingsStore()
        ..credential = key
        ..permissionMode = AssistantPermissionMode.full;
      final base = AgentConfiguration.deepSeek();
      final controller = AssistantController(
        unifiedReader: DriftUnifiedReader(database),
        sessionStore: DriftSessionStore(database),
        settingsStore: settings,
        missions: missions,
        goals: goals,
        records: RecordService(
          DriftRecordRepository(database),
          missions,
          missions.attachments,
        ),
        memory: memory,
        analysis: DriftAnalysisStore(database),
        web: WebService(
          settings: const SecureWebSettings(),
          quota: DriftSearchQuota(database),
          fetchClient: () => throw StateError('不使用联网工具'),
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
          maxSteps: 12,
          maxRunDuration: const Duration(minutes: 3),
        ),
      );
      try {
        await controller.initialize();
        final query = await controller.send(
          '请调用 getMemory 查询并列出所有测试记忆的编号和内容，只查询，不要修改或删除。',
        );
        expect(query?.reason, AgentStopReason.completed);
        final output = controller.transcript
            .whereType<ToolResultMessage>()
            .lastWhere(
              (message) => message.toolName == 'getMemory' && !message.isError,
            );
        final selection = jsonDecode(output.text) as Map<String, dynamic>;
        final items = selection['items'] as List;
        expect(items, hasLength(9));
        final expected = {(items[0] as Map)['id'], (items[2] as Map)['id']};
        final greeting = await controller.send('你好');
        expect(greeting?.reason, AgentStopReason.completed);
        expect(
          (await database.select(database.memoryEntries).get()).where(
            (entry) => entry.forgotten,
          ),
          isEmpty,
        );
        final result = await controller.send('请删除刚才清单中的第1、3条，其余保留，直接执行。');
        expect(result?.reason, AgentStopReason.completed);
        final forget = controller.transcript
            .whereType<ToolResultMessage>()
            .lastWhere(
              (message) =>
                  message.toolName == 'manageMemory' && !message.isError,
            );
        expect((jsonDecode(forget.text) as Map)['status'], 'success');
        final forgotten = (await database.select(database.memoryEntries).get())
            .where((entry) => entry.forgotten)
            .map((entry) => entry.id)
            .toSet();
        expect(forgotten, expected);
        final goal = goals.prepareCreation(title: '真实模型测试目标');
        await goals.create(goal);
        final candidate = missions.prepareCreation(
          title: '可补记测试任务',
          scheduledDate: '2026-10-20',
          timeZone: 'Asia/Shanghai',
          plannedDurationMinutes: 20,
          ownership: MissionOwnership(goalId: goal.id),
        );
        final cancelled = missions.prepareCreation(
          title: '已取消测试任务',
          scheduledDate: '2026-10-21',
          timeZone: 'Asia/Shanghai',
          plannedDurationMinutes: 20,
          ownership: MissionOwnership(goalId: goal.id),
        );
        await missions.createPrepared(candidate);
        await missions.createPrepared(cancelled);
        await missions.cancel(missionId: cancelled.mission.id);
        final history = await controller.send(
          '我已经完成这个目标的历史任务。请调用 completeHistory，目标ID为 ${goal.id}，截止日期为 2026-10-29，statement 请原样使用“我已经完成这个目标的历史任务”。',
        );
        expect(history?.reason, AgentStopReason.completed);
        final historyResult = controller.transcript
            .whereType<ToolResultMessage>()
            .lastWhere(
              (message) =>
                  message.toolName == 'completeHistory' && !message.isError,
            );
        final historyOutput = jsonDecode(historyResult.text) as Map;
        expect(historyOutput['counts'], {
          'matched': 2,
          'eligible': 1,
          'changed': 1,
          'skipped': 1,
        });
        expect(
          ((historyOutput['issues'] as List).single as Map)['code'],
          'cancelled',
        );
        final busy = missions.prepareCreation(
          title: '测试占用',
          scheduledDate: '2026-11-05',
          timeZone: 'Asia/Shanghai',
          plannedDurationMinutes: 60,
          timePolicy: TimePolicy.fixed,
          fixedStartAt: DateTime.utc(2026, 11, 5, 1),
        );
        await missions.createPrepared(busy);
        final beforePlan =
            (await database.select(database.missions).get()).length;
        final scheduling = await controller.send(
          '请用 planMissions 提出一份计划：2026-11-05 上午09:00安排测试任务A，计划30分钟；11:00安排测试任务B，计划30分钟。若冲突就说明，不要自行改时间。',
        );
        expect(scheduling?.reason, AgentStopReason.completed);
        final planResult = controller.transcript
            .whereType<ToolResultMessage>()
            .lastWhere(
              (message) =>
                  message.toolName == 'planMissions' && !message.isError,
            );
        final planOutput = jsonDecode(planResult.text) as Map;
        expect(planOutput['status'], 'blocked');
        expect((planOutput['counts'] as Map)['changed'], 0);
        expect(
          (await database.select(database.missions).get()),
          hasLength(beforePlan),
        );
      } finally {
        await controller.close();
        controller.dispose();
        await missions.dispose();
        await goals.dispose();
        await database.close();
      }
    },
    skip: key == null || key.isEmpty ? '需要用户提供临时测试凭据' : false,
    timeout: const Timeout(Duration(minutes: 5)),
  );
}

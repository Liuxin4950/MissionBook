import 'dart:io';

import 'package:agent_core/agent_core.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mission_book/application/assistant/assistant_controller.dart';
import 'package:mission_book/application/goals/goal_service.dart';
import 'package:mission_book/application/missions/mission_service.dart';
import 'package:mission_book/data/assistant/drift_assistant_reader.dart';
import 'package:mission_book/data/assistant/drift_session_store.dart';
import 'package:mission_book/data/local/app_database.dart';
import 'package:mission_book/data/repositories/drift_goal_repository.dart';
import 'package:mission_book/data/repositories/drift_mission_repository.dart';
import 'package:mission_book/domain/entities/mission_ownership.dart';

import '../support/assistant_fakes.dart';

/// 只在用户提供临时进程凭据时运行；隔离内存库，不读用户数据、不保存Key。
void main() {
  final key = Platform.environment['DEEPSEEK_API_KEY'];
  test(
    '真实 DeepSeek：查询、编辑批准参数、写入恢复、节点改名与取消零写入',
    () async {
      final database = AppDatabase(executor: NativeDatabase.memory());
      final now = DateTime.utc(2026, 10, 29, 6);
      final missions = MissionService(
        DriftMissionRepository(database, clock: () => now),
        clock: () => now,
      );
      final goals = GoalService(DriftGoalRepository(database));
      final settings = MemoryAssistantSettingsStore()..credential = key;
      final base = AgentConfiguration.deepSeek();
      final configuration = AgentConfiguration(
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
      );
      AssistantController? assistant;
      AssistantController controller() => AssistantController(
        reader: DriftAssistantReader(database),
        sessionStore: DriftSessionStore(database),
        settingsStore: settings,
        missions: missions,
        goals: goals,
        configuration: configuration,
        clock: () => now,
      );
      Future<AssistantOperation> pending(
        AssistantController current,
        Future<AgentRunResult?> sending,
      ) async {
        for (var i = 0; i < 480; i++) {
          final item = current.operations
              .where(
                (op) =>
                    op.status == AssistantOperationStatus.waitingConfirmation,
              )
              .firstOrNull;
          if (item != null) return item;
          if (!current.isRunning && i > 0) {
            await sending;
            fail('模型没有提出可确认操作：${current.errorMessage}');
          }
          await Future<void>.delayed(const Duration(milliseconds: 250));
        }
        current.stop();
        fail('等待真实模型提案超时');
      }

      try {
        final goal = goals.prepareCreation(title: '集成验收目标');
        await goals.create(goal);
        final node = goals.prepareNodeCreation(goalId: goal.id, title: '布局基础');
        await goals.createNode(node);
        await missions.create(
          title: '集成验收复习布局',
          scheduledDate: '2026-10-30',
          timeZone: 'Asia/Shanghai',
          plannedDurationMinutes: 30,
          ownership: MissionOwnership(goalId: goal.id, goalNodeId: node.id),
        );
        final id = (await missions.findAllDetails()).single.mission.id;
        assistant = controller();
        await assistant.initialize();
        await assistant.openMissionReference(id);
        final query = await assistant.send(
          '请调用工具读取我引用的任务，告诉我名称、计划日期和计划分钟。只查询，不修改。',
        );
        expect(query?.reason, AgentStopReason.completed);
        expect(
          assistant.transcript.whereType<ToolResultMessage>().any(
            (item) => !item.isError,
          ),
          isTrue,
        );
        expect(
          (await missions.findAllDetails())
              .single
              .schedule
              .plannedDurationMinutes,
          30,
        );
        final moving = assistant.send(
          '请把当前引用的任务改到2026-10-31，计划45分钟。调用工具提出修改，不要只给操作说明。',
        );
        final proposal = await pending(assistant, moving);
        expect(proposal.input['missionId'], id);
        expect(proposal.input['scheduledDate'], '2026-10-31');
        expect(
          (await missions.findDetailSnapshot(
            missionId: id,
          ))!.schedule.scheduledDate,
          '2026-10-30',
        );
        expect(
          assistant.updateProposal(proposal.callId, {
            ...proposal.input,
            'plannedMinutes': 40,
          }),
          isNull,
        );
        expect(assistant.confirmProposal(proposal.callId), isNull);
        final moved = await moving;
        expect(moved?.reason, AgentStopReason.completed);
        final saved = (await missions.findDetailSnapshot(missionId: id))!;
        expect(saved.schedule.scheduledDate, '2026-10-31');
        expect(saved.schedule.plannedDurationMinutes, 40);
        final sessionId = assistant.currentSessionId;
        await assistant.close();
        assistant.dispose();
        assistant = controller();
        await assistant.initialize();
        await assistant.openMissionReference(id);
        expect(assistant.currentSessionId, sessionId);
        expect(
          assistant.operations
              .singleWhere((item) => item.isWrite)
              .input['plannedMinutes'],
          40,
        );
        expect(assistant.needsOutcomeResolution, isFalse);
        await assistant.openNodeReference(node.id);
        final renaming = assistant.send(
          '把当前引用的节点改名为响应式布局。调用工具修改名称，不创建新节点，不改任务。',
        );
        final rename = await pending(assistant, renaming);
        expect(rename.toolName, 'goal_node_update');
        expect(rename.input['nodeId'], node.id);
        assistant.confirmProposal(rename.callId);
        expect((await renaming)?.reason, AgentStopReason.completed);
        expect((await goals.findNodeById(node.id))!.title, '响应式布局');
        final creating = assistant.send(
          '在2026-11-01创建一个自报完成的独立任务，名称集成验收取消项，计划20分钟，先提出提案。',
        );
        final creation = await pending(assistant, creating);
        expect(creation.toolName, 'mission_create');
        assistant.cancelProposal(creation.callId);
        await creating;
        expect(await missions.findAllDetails(), hasLength(1));
        // ignore: avoid_print
        print(
          'LIVE_ASSISTANT query=passed editedApproval=passed persistedInputs=passed nodeRename=passed cancellationZeroWrites=passed',
        );
      } finally {
        await assistant?.close();
        assistant?.dispose();
        await missions.dispose();
        await goals.dispose();
        await database.close();
      }
    },
    skip: key == null || key.isEmpty
        ? '仅在用户授权并提供临时 DEEPSEEK_API_KEY 时运行'
        : false,
    timeout: const Timeout(Duration(minutes: 8)),
  );
}

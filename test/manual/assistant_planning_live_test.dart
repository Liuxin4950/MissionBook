import 'dart:convert';
import 'dart:io';

import 'package:agent_core/agent_core.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mission_book/application/assistant/assistant_controller.dart';
import 'package:mission_book/application/assistant/assistant_schedule.dart';
import 'package:mission_book/application/goals/goal_service.dart';
import 'package:mission_book/application/missions/mission_service.dart';
import 'package:mission_book/data/assistant/drift_session_store.dart';
import 'package:mission_book/data/assistant/drift_unified_reader.dart';
import 'package:mission_book/data/local/app_database.dart';
import 'package:mission_book/data/repositories/drift_goal_repository.dart';
import 'package:mission_book/data/repositories/drift_mission_repository.dart';
import 'package:mission_book/domain/entities/mission_ownership.dart';
import 'package:mission_book/domain/entities/mission_schedule_revision.dart';

import '../support/assistant_fakes.dart';

/// 环境凭据、隔离内存库、固定业务时间；不打开正式用户数据。
/// 报告仅包含合成场景、实际调用、输出、用量和检查结果，不包含 Key。
void main() {
  final key = Platform.environment['DEEPSEEK_API_KEY'];
  final reportPath = Platform.environment['PLANNING_EVAL_REPORT'];
  final reports = <Map<String, Object?>>[];
  final now = DateTime.utc(2026, 11, 26, 2);
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
    maxSteps: 8,
    maxRunDuration: const Duration(minutes: 3),
  );
  final cases = [
    (
      id: 'explore',
      style: AssistantReplyStyle.concise,
      text: '我有点想参加下个月的校园创新创业比赛，还没决定。先分析值得考虑什么，不要创建或保存任务。',
    ),
    (
      id: 'plan',
      style: AssistantReplyStyle.questioning,
      text:
          '我决定参加校园创新创业比赛，报名截止是2026-12-05。请先查已有目标和任务，为11月27日、28日各提出一项新的准备行动，先用计划卡给方案，不保存。具体步骤、时长由你估算；新任务用自选时间，每天新任务不超过45分钟，不重复安排已有工作。',
    ),
    (
      id: 'execute',
      style: AssistantReplyStyle.checklist,
      text:
          '我决定参加校园创新创业比赛，报名截止是2026-12-05。请查已有目标和任务，在原目标下为11月27日、28日各创建并保存一项新的准备任务，不重复已有工作。步骤、分钟由你估算，每天新增不超过45分钟，采用自选时间。',
    ),
    (
      id: 'reschedule',
      style: AssistantReplyStyle.explanatory,
      text: '请把已有的“固定复习”改期并保存到2026-11-28，只改日期，保留原来的固定开始时刻与计划时长。',
    ),
    (
      id: 'unknown-deadline',
      style: AssistantReplyStyle.supportive,
      text:
          '我决定参加下个月的校园创新创业比赛，但比赛和报名截止日期我还不知道。请先查已有目标和任务，看看现在能推进什么；只做初步规划，日期未知的准备阶段先别编出日程，不保存任务。',
    ),
    (
      id: 'compare',
      style: AssistantReplyStyle.comparative,
      text:
          '我想为校园创新创业比赛准备项目。请查已有目标与任务，比较“先验证需求”和“先做演示原型”两种推进方式，给出推荐的下一步。只比较，不创建或保存。',
    ),
  ];

  tearDownAll(() async {
    if (reportPath == null || reports.isEmpty) return;
    final file = File(reportPath);
    await file.parent.create(recursive: true);
    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert({
        'recordedAt': DateTime.now().toUtc().toIso8601String(),
        'businessNow': now.toIso8601String(),
        'profileId': configuration.defaultModelProfile,
        'configuredModel': configuration.profiles.first.model,
        'protocol': configuration.profiles.last.protocol.name,
        'limits': {'maxSteps': 8, 'maxOutputTokens': 2048},
        'cases': reports,
      }),
    );
  });

  for (final scenario in cases) {
    test(
      '主动规划真实模型：${scenario.id} / ${scenario.style.label}',
      () async {
        final db = AppDatabase(executor: NativeDatabase.memory());
        final missions = MissionService(
          DriftMissionRepository(db, clock: () => now),
          clock: () => now,
        );
        final goals = GoalService(DriftGoalRepository(db));
        final goal = goals.prepareCreation(title: '校园创新创业比赛');
        await goals.create(goal);
        await missions.create(
          title: '核对报名规则',
          scheduledDate: '2026-11-27',
          timeZone: 'Asia/Shanghai',
          plannedDurationMinutes: 30,
          ownership: MissionOwnership(goalId: goal.id),
        );
        await missions.create(
          title: '固定复习',
          scheduledDate: '2026-11-27',
          timeZone: 'Asia/Shanghai',
          plannedDurationMinutes: 45,
          timePolicy: TimePolicy.fixed,
          fixedStartAt: DateTime.utc(2026, 11, 27, 1),
        );
        final fixedId = (await missions.findAllDetails())
            .singleWhere((detail) => detail.mission.title == '固定复习')
            .mission
            .id;
        final settings = MemoryAssistantSettingsStore()
          ..credential = key
          ..permissionMode = AssistantPermissionMode.full
          ..persona = AssistantPersona(
            role: AssistantRole.planner,
            replyStyle: scenario.style,
          );
        final assistant = AssistantController(
          unifiedReader: DriftUnifiedReader(db),
          sessionStore: DriftSessionStore(db),
          settingsStore: settings,
          missions: missions,
          goals: goals,
          configuration: configuration,
          clock: () => now,
        );
        final watch = Stopwatch()..start();
        AgentRunResult? result;
        final previews = <Map<String, Object?>>[];
        var passed = false;
        Future<AgentRunResult?>? sending;
        try {
          await assistant.initialize();
          var finished = false;
          sending = assistant
              .send(scenario.text)
              .whenComplete(() => finished = true);
          while (!finished && watch.elapsed < const Duration(minutes: 3)) {
            final pending = assistant.operations
                .where(
                  (operation) =>
                      operation.status ==
                      AssistantOperationStatus.waitingConfirmation,
                )
                .firstOrNull;
            if (pending != null) {
              expect(
                ['plan', 'unknown-deadline'],
                contains(scenario.id),
                reason: '本场景不应停在新的写入确认；${pending.toolName}',
              );
              expect(pending.toolName, 'planMissions');
              expect(pending.input['intent'], 'PLAN');
              expect(await missions.findAllDetails(), hasLength(2));
              final rows = AssistantScheduleService.rows(pending.input);
              previews.add(Map<String, Object?>.from(pending.input));
              if (scenario.id == 'plan') {
                expect(rows, hasLength(2));
                expect(rows.map((row) => row['scheduledDate']).toSet(), {
                  '2026-11-27',
                  '2026-11-28',
                });
                for (final row in rows) {
                  expect(row['kind'], 'CREATE');
                  expect(row['goalId'], goal.id);
                  expect(row['timePolicy'], 'FLEXIBLE');
                  expect(row['plannedMinutes'], inInclusiveRange(1, 45));
                  expect(row['title'], isNot('核对报名规则'));
                }
                expect(assistant.confirmProposal(pending.callId), isNull);
              } else {
                expect(rows.length, lessThanOrEqualTo(2));
                assistant.cancelProposal(pending.callId);
              }
            }
            await Future<void>.delayed(const Duration(milliseconds: 100));
          }
          if (!finished) assistant.stop();
          result = await sending;
          expect(
            result?.reason,
            AgentStopReason.completed,
            reason: assistant.errorMessage ?? '模型未正常结束',
          );
          expect(await goals.findAll(), hasLength(1));
          final saved = await missions.findAllDetails();
          if (scenario.id == 'execute' || scenario.id == 'plan') {
            expect(saved, hasLength(4));
            for (final detail in saved.where(
              (item) =>
                  item.mission.title != '固定复习' &&
                  item.mission.title != '核对报名规则',
            )) {
              expect(detail.mission.goalId, goal.id);
              expect(detail.schedule.timePolicy, TimePolicy.flexible);
              expect(
                detail.schedule.plannedDurationMinutes,
                inInclusiveRange(1, 45),
              );
            }
          } else {
            expect(saved, hasLength(2));
          }
          final fixed = saved.singleWhere(
            (detail) => detail.mission.id == fixedId,
          );
          expect(fixed.schedule.timePolicy, TimePolicy.fixed);
          expect(fixed.schedule.plannedDurationMinutes, 45);
          expect(
            fixed.schedule.fixedStartAt,
            scenario.id == 'reschedule'
                ? DateTime.utc(2026, 11, 28, 1)
                : DateTime.utc(2026, 11, 27, 1),
          );
          if (scenario.id == 'plan') expect(previews, hasLength(1));
          passed = true;
        } finally {
          assistant.stop();
          if (sending != null) result ??= await sending;
          reports.add({
            'case': scenario.id,
            'style': scenario.style.name,
            'passed': passed,
            'elapsedMs': watch.elapsedMilliseconds,
            'prompt': scenario.text,
            'modelSteps': result?.modelSteps,
            'usage': result?.usage.toJson(),
            'usageIncomplete': result?.usageIncomplete,
            'stopReason': result?.reason.name,
            'operations': [
              for (final operation in assistant.operations)
                {
                  'tool': operation.toolName,
                  'input': operation.input,
                  'status': operation.status.name,
                  if (operation.error != null) 'error': operation.error,
                },
            ],
            'previews': previews,
            'answers': assistant.transcript
                .whereType<AssistantMessage>()
                .map((message) => message.text)
                .where((text) => text.isNotEmpty)
                .toList(),
            'savedMissions': (await missions.findAllDetails()).length,
          });
          await assistant.close();
          await missions.dispose();
          await goals.dispose();
          await db.close();
        }
      },
      skip: key == null || key.isEmpty ? '需要 DEEPSEEK_API_KEY 临时评估凭据' : false,
      timeout: const Timeout(Duration(minutes: 4)),
    );
  }
}

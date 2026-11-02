import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mission_book/application/assistant/assistant_controller.dart';
import 'package:mission_book/application/goals/goal_service.dart';
import 'package:mission_book/application/missions/mission_service.dart';
import 'package:mission_book/data/assistant/drift_session_store.dart';
import 'package:mission_book/data/assistant/drift_unified_reader.dart';
import 'package:mission_book/data/local/app_database.dart';
import 'package:mission_book/data/repositories/drift_goal_repository.dart';
import 'package:mission_book/data/repositories/drift_mission_repository.dart';
import 'package:mission_book/domain/entities/mission_ownership.dart';
import 'package:mission_book/presentation/assistant/assistant_operation_card.dart';

import '../../support/assistant_fakes.dart';

void main() {
  testWidgets('确认前可以滚动查看超过20项的历史跳过名单', (tester) async {
    final database = AppDatabase(executor: NativeDatabase.memory());
    final missions = MissionService(DriftMissionRepository(database));
    final goals = GoalService(DriftGoalRepository(database));
    final controller = AssistantController(
      unifiedReader: DriftUnifiedReader(database),
      sessionStore: DriftSessionStore(database),
      settingsStore: MemoryAssistantSettingsStore(),
      missions: missions,
      goals: goals,
    );
    addTearDown(() async {
      await controller.close();
      controller.dispose();
      await missions.dispose();
      await goals.dispose();
      await database.close();
    });
    final goal = goals.prepareCreation(title: '测试目标');
    await goals.create(goal);
    for (var i = 0; i < 25; i++) {
      final task = missions.prepareCreation(
        title: '跳过任务$i',
        scheduledDate: '2026-10-20',
        timeZone: 'Asia/Shanghai',
        plannedDurationMinutes: 10,
        ownership: MissionOwnership(goalId: goal.id),
      );
      await missions.createPrepared(task);
      await missions.cancel(missionId: task.mission.id);
    }
    final excluded = await missions.findHistoryScope(goal.id, '2026-10-29');
    final operation =
        AssistantOperation(
            callId: 'history',
            toolName: 'completeHistory',
            input: const {},
          )
          ..status = AssistantOperationStatus.waitingConfirmation
          ..historySkippedCount = excluded.length
          ..historyExcluded = excluded;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: AssistantOperationCard(
              controller: controller,
              operation: operation,
              onOpenReference: (_, _) {},
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('查看跳过原因'));
    await tester.pumpAndSettle();
    final lastTitle = excluded.last.mission.title;
    expect(find.text(lastTitle), findsNothing);
    await tester.drag(find.byType(ListView).last, const Offset(0, -3000));
    await tester.pumpAndSettle();
    expect(find.text(lastTitle), findsOneWidget);
    expect(find.text('已取消').evaluate(), isNotEmpty);
  });
}

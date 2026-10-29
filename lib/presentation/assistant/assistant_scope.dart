import 'package:flutter/material.dart';

import '../../application/assistant/assistant_controller.dart';
import '../../application/goals/goal_service.dart';
import '../../application/missions/mission_service.dart';
import '../goals/detail/goal_detail_page.dart';
import '../missions/detail/mission_detail_page.dart';
import '../widgets/detail_pane.dart';
import 'assistant_page.dart';

class AssistantScope extends InheritedWidget {
  const AssistantScope({
    super.key,
    required this.controller,
    required this.missions,
    required this.goals,
    required super.child,
  });

  final AssistantController controller;
  final MissionService missions;
  final GoalService goals;

  static AssistantScope of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AssistantScope>();
    if (scope == null) throw StateError('当前页面未装配助手');
    return scope;
  }

  @override
  bool updateShouldNotify(AssistantScope oldWidget) =>
      controller != oldWidget.controller ||
      missions != oldWidget.missions ||
      goals != oldWidget.goals;
}

Future<void> openAssistant(
  BuildContext context, {
  String? missionId,
  String? goalId,
}) async {
  final scope = AssistantScope.of(context);
  try {
    if (missionId != null) await scope.controller.openMissionReference(missionId);
    if (goalId != null) await scope.controller.openGoalReference(goalId);
    if (!context.mounted) return;
    await openDetailPane(
      context,
      label: '助手',
      builder: (_) => AssistantPage(controller: scope.controller, showBack: true),
    );
  } catch (error) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('暂时无法打开助手：$error')),
    );
  }
}

Future<void> openAssistantMission(BuildContext context, String missionId) async {
  final scope = AssistantScope.of(context);
  await openDetailPane(
    context,
    label: '任务详情',
    builder: (_) => MissionDetailPage(
      missionId: missionId,
      missionService: scope.missions,
    ),
  );
}

Future<void> openAssistantGoal(BuildContext context, String goalId) async {
  final scope = AssistantScope.of(context);
  await openDetailPane(
    context,
    label: '目标详情',
    builder: (_) => GoalDetailPage(
      service: scope.goals,
      goalId: goalId,
      missionService: scope.missions,
    ),
  );
}

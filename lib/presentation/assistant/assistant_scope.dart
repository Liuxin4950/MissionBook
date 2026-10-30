import 'package:flutter/material.dart';

import '../../application/assistant/assistant_controller.dart';
import '../../application/assistant/assistant_speech.dart';
import '../../application/goals/goal_service.dart';
import '../../application/missions/mission_service.dart';
import '../../application/backup/backup_service.dart';
import '../../application/settings/app_device.dart';
import '../goals/detail/goal_detail_page.dart';
import '../missions/detail/mission_detail_page.dart';
import '../widgets/detail_pane.dart';
import 'assistant_page.dart';

class AssistantScope extends InheritedWidget {
  const AssistantScope({
    super.key,
    required this.controller,
    required this.voice,
    required this.missions,
    required this.goals,
    this.backup,
    this.device,
    required super.child,
  });

  final AssistantController controller;
  final AssistantVoiceController voice;
  final MissionService missions;
  final GoalService goals;
  final BackupExporter? backup;
  final AppDevice? device;

  static AssistantScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AssistantScope>();

  static AssistantScope of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AssistantScope>();
    if (scope == null) throw StateError('当前页面未装配助手');
    return scope;
  }

  @override
  bool updateShouldNotify(AssistantScope oldWidget) =>
      controller != oldWidget.controller ||
      voice != oldWidget.voice ||
      backup != oldWidget.backup ||
      device != oldWidget.device ||
      missions != oldWidget.missions ||
      goals != oldWidget.goals;
}

Future<void> openAssistant(
  BuildContext context, {
  String? missionId,
  String? goalId,
  String? nodeId,
}) async {
  final scope = AssistantScope.of(context);
  try {
    await scope.controller.initialize();
    if (nodeId != null) {
      await scope.controller.openNodeReference(nodeId);
    } else if (missionId != null) {
      await scope.controller.openMissionReference(missionId);
    } else if (goalId != null) {
      await scope.controller.openGoalReference(goalId);
    } else {
      await scope.controller.openGlobalConversation();
    }
    if (!context.mounted) return;
    await showAssistantConversation(context);
  } catch (error) {
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('暂时无法打开助手：$error')));
    }
  }
}

/// 独立二级路由覆盖原工作区；不切主导航或清空详情/草稿栈。
Future<void> showAssistantConversation(
  BuildContext context, {
  String? initialText,
}) {
  final scope = AssistantScope.of(context);
  return Navigator.of(context, rootNavigator: true).push<void>(
    MaterialPageRoute(
      settings: const RouteSettings(name: '/assistant/conversation'),
      builder: (_) => AssistantPage(
        controller: scope.controller,
        showBack: true,
        initialText: initialText,
      ),
    ),
  );
}

Future<void> openAssistantMission(
  BuildContext context,
  String missionId,
) async {
  final scope = AssistantScope.of(context);
  await openDetailPane(
    context,
    label: '任务详情',
    builder: (_) =>
        MissionDetailPage(missionId: missionId, missionService: scope.missions),
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

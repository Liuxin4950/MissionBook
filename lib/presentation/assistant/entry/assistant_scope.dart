import '../../../application/errors/user_error_message.dart';
import 'package:flutter/material.dart';

import '../../../application/assistant/assistant_controller.dart';
import '../../../application/assistant/assistant_speech.dart';
import '../../../application/goals/goal_service.dart';
import '../../../application/missions/mission_service.dart';
import '../../../application/backup/backup_service.dart';
import '../../../application/settings/app_device.dart';
import '../../goals/detail/goal_detail_page.dart';
import '../../missions/detail/mission_detail_page.dart';
import '../../widgets/detail_pane.dart';
import '../chat/assistant_page.dart';
import '../../../core/theme/app_layout.dart';

class AssistantScope extends InheritedWidget {
  const AssistantScope({
    super.key,
    required this.controller,
    required this.voice,
    required this.missions,
    required this.goals,
    this.backup,
    this.device,
    this.createVoiceTest,
    required super.child,
  });

  final AssistantController controller;
  final AssistantVoiceController voice;
  final MissionService missions;
  final GoalService goals;
  final BackupExporter? backup;
  final AppDevice? device;
  final AssistantVoiceController Function()? createVoiceTest;

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
      createVoiceTest != oldWidget.createVoiceTest ||
      missions != oldWidget.missions ||
      goals != oldWidget.goals;
}

Future<void> openAssistant(
  BuildContext context, {
  String? missionId,
  String? goalId,
  String? nodeId,
  String? prompt,
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
    if (prompt != null && scope.controller.draft.trim().isEmpty) {
      scope.controller.draft = prompt;
    }
    await showAssistantConversation(context);
  } catch (error) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(userErrorMessage(error, fallback: '暂时无法打开助手，请重试')),
        ),
      );
    }
  }
}

class _ConversationRoute {
  _ConversationRoute(this.route, this.focusOperation);
  final Route<void> route;
  final ValueNotifier<String?> focusOperation;
}

final _conversationRoutes = Expando<_ConversationRoute>();

bool assistantConversationIsOpen(BuildContext context) {
  final detailPane = DetailPaneScope.maybeOf(context);
  if (detailPane != null) {
    return detailPane
            .findByIdentity(assistantConversationPaneIdentity)
            ?.route
            ?.isActive ??
        false;
  }
  return _conversationRoutes[Navigator.of(context, rootNavigator: true)] !=
      null;
}

/// 在统一右栏中打开助手；没有工作区外壳时回退到独立路由，便于页面预览。
Future<void> showAssistantConversation(
  BuildContext context, {
  String? initialText,
  String? initialOperationCallId,
}) {
  final scope = AssistantScope.of(context);
  final detailPane = DetailPaneScope.maybeOf(context);
  if (detailPane != null) {
    final existing = detailPane.findByIdentity(
      assistantConversationPaneIdentity,
    );
    if (existing?.route?.isActive ?? false) {
      return detailPane.reveal(assistantConversationPaneIdentity).then((_) {});
    }
    // 保留任务/目标详情作为返回目标，同时仍经统一的右栏入口打开。
    return openDetailPane<void>(
      context,
      label: '助手会话',
      identity: assistantConversationPaneIdentity,
      maxWidth: AppLayout.assistantPaneMaxWidth,
      preserveExistingEntries: true,
      builder: (_) => AssistantPage(
        controller: scope.controller,
        showBack: true,
        initialText: initialText,
        initialOperationCallId: initialOperationCallId,
      ),
    ).then((_) {});
  }

  // 没有 AppShell 的独立预览仍使用根 Navigator，保持原有测试和预览入口。
  final navigator = Navigator.of(context, rootNavigator: true);
  final existing = _conversationRoutes[navigator];
  if (existing != null && existing.route.isActive) {
    // 截图返回时聊天可能被设置、预览或详情覆盖；恢复原路由及原草稿。
    var protectedEditor = false;
    navigator.popUntil((route) {
      if (identical(route, existing.route)) return true;
      if (route.popDisposition == RoutePopDisposition.doNotPop) {
        protectedEditor = true;
        return true;
      }
      return false;
    });
    if (protectedEditor) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('内容已保留在聊天草稿，完成当前编辑后可返回聊天')));
    }
    if (initialOperationCallId != null) {
      existing.focusOperation.value = initialOperationCallId;
    }
    return Future.value();
  }
  final focusOperation = ValueNotifier(initialOperationCallId);
  final page = MaterialPageRoute<void>(
    settings: const RouteSettings(name: '/assistant/conversation'),
    builder: (_) => ValueListenableBuilder<String?>(
      valueListenable: focusOperation,
      builder: (_, operation, _) => AssistantPage(
        controller: scope.controller,
        showBack: true,
        initialText: initialText,
        initialOperationCallId: operation,
      ),
    ),
  );
  final completed = navigator.push<void>(page).then<void>((_) {});
  final entry = _ConversationRoute(page, focusOperation);
  _conversationRoutes[navigator] = entry;
  return completed.whenComplete(() {
    focusOperation.dispose();
    if (identical(_conversationRoutes[navigator], entry)) {
      _conversationRoutes[navigator] = null;
    }
  });
}

Future<void> openAssistantMission(
  BuildContext context,
  String missionId,
) async {
  final scope = AssistantScope.of(context);
  await openDetailPane(
    context,
    label: '任务详情',
    maxWidth: AppLayout.detailPaneMaxWidth,
    builder: (_) =>
        MissionDetailPage(missionId: missionId, missionService: scope.missions),
  );
}

Future<void> openAssistantGoal(BuildContext context, String goalId) async {
  final scope = AssistantScope.of(context);
  await openDetailPane(
    context,
    label: '目标详情',
    maxWidth: AppLayout.detailPaneMaxWidth,
    builder: (_) => GoalDetailPage(
      service: scope.goals,
      goalId: goalId,
      missionService: scope.missions,
    ),
  );
}

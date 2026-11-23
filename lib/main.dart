import 'package:flutter/material.dart';

import 'app.dart';
import 'application/missions/mission_service.dart';
import 'data/local/app_database.dart';
import 'data/notifications/today_widget_bridge.dart';
import 'data/repositories/drift_mission_repository.dart';
import 'planned_mission_background.dart';
import 'presentation/assistant/desktop/windows_assistant_overlay.dart';

// 主入口，用于启动项目
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runMissionBook();
}

/// Android 的无界面 FlutterEngine 按此名字调用；release 树摇不能移除入口。
@pragma('vm:entry-point')
Future<void> plannedMissionBackgroundMain() => runPlannedMissionBackground();

/// Android Launcher refresh: read the committed schedule without running UI or task maintenance.
@pragma('vm:entry-point')
Future<void> todayWidgetBackgroundMain() async {
  WidgetsFlutterBinding.ensureInitialized();
  final database = AppDatabase();
  final missions = MissionService(DriftMissionRepository(database));
  var success = false;
  try {
    await TodayWidgetBridge.publish(missions);
    success = true;
  } catch (error) {
    debugPrint('桌面小组件后台读取失败：${error.runtimeType}');
  } finally {
    try {
      await missions.dispose();
    } finally {
      try {
        await database.close();
      } finally {
        await TodayWidgetBridge.channel.invokeMethod<void>('finished', success);
      }
    }
  }
}

/// Windows 的小窗只负责界面，所有请求交回已经运行的主工作区。
@pragma('vm:entry-point')
void windowsAssistantOverlayMain() => runWindowsAssistantOverlay();

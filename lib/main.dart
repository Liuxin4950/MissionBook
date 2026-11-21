import 'package:flutter/material.dart';

import 'app.dart';
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

/// Windows 的小窗只负责界面，所有请求交回已经运行的主工作区。
@pragma('vm:entry-point')
void windowsAssistantOverlayMain() => runWindowsAssistantOverlay();

import 'package:flutter/material.dart';

import 'app.dart';
import 'application/missions/planned_mission_background.dart';

// 主入口，用于启动项目
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const App());
}

/// Android 的无界面 FlutterEngine 按此名字调用；release 树摇不能移除入口。
@pragma('vm:entry-point')
Future<void> plannedMissionBackgroundMain() => runPlannedMissionBackground();

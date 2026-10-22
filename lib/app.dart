import 'dart:async';

import 'package:flutter/material.dart';

import 'application/create_mission.dart';
import 'application/get_scheduled_missions.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'core/theme/app_theme.dart';
import 'data/local/app_database.dart';
import 'data/repositories/drift_mission_repository.dart';
import 'app_shell.dart';

/// 装配本地数据库、任务仓储和业务入口，并提供全局主题及中文界面。
class App extends StatefulWidget {
  const App({super.key});

  @override
  State<App> createState() => _AppState();
}

class _AppState extends State<App> {
  // late 表示这些属性稍后初始化。
  // final 表示初始化后不再换成另一个对象。
  late final AppDatabase _database; //定义数据库连接器
  late final CreateMission _createMission; //定义业务对象
  late final GetScheduledMissions _getMissions;

  @override
  void initState() {
    super.initState();
    // Flutter 创建这个 State 后调用一次 initState。
    // 不传 executor，由 AppDatabase 按平台选择原生文件或浏览器存储。
    _database = AppDatabase();
    // 将同一个数据库交给真实仓储。
    final repository = DriftMissionRepository(_database);
    // 业务对象保存仓储引用，后续通过它执行真正的保存。
    _createMission = CreateMission(repository);
    // 这里只组装查询入口并传入仓储，不执行查询。
    // 今天页稍后在初始化、下拉刷新或关闭创建页后调用它的 execute。
    _getMissions = GetScheduledMissions(repository);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MissionBook',
      theme: AppTheme.light,
      locale: const Locale('zh', 'CN'),
      supportedLocales: const [Locale('zh', 'CN'), Locale('en', 'US')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      // build 可以重复执行，但这里始终传入已创建的同一个业务对象。
      home: AppShell(createMission: _createMission, getMissions: _getMissions),
    );
  }

  @override
  void dispose() {
    // Flutter 移除这个 State 时调用 dispose。
    // close 返回 Future，但 dispose 不能等待异步完成；
    // unawaited 明确表示在这里发起关闭，不等待它。
    unawaited(_database.close());
    super.dispose();
  }
}

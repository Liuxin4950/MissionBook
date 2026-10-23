import 'dart:async';

import 'package:flutter/material.dart';

import 'application/missions/mission_service.dart';
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
  late final AppDatabase _database; // 定义数据库连接器
  late final MissionService _missionService; // 业务操作对象

  @override
  void initState() {
    super.initState();
    // Flutter 创建这个 State 后调用一次 initState。
    // 不传 executor，由 AppDatabase 按平台选择原生文件或浏览器存储。
    _database = AppDatabase();
    // 将同一个数据库交给真实仓储。
    final repository = DriftMissionRepository(_database);
    // 这里只创建一个共享的任务业务对象，不执行创建或查询。
    // 页面稍后通过 create / findScheduledOn / findDetail 选择具体操作；
    // 三个方法使用同一个仓储、同一个数据库连接。
    _missionService = MissionService(repository);
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
      home: AppShell(missionService: _missionService),
    );
  }

  @override
  void dispose() {
    // Flutter 移除这个 State 时调用 dispose。
    // close 返回 Future，但 dispose 不能等待异步完成；
    // unawaited 明确表示在这里发起关闭，不等待它。
    unawaited(_missionService.dispose());
    unawaited(_database.close());
    super.dispose();
  }
}

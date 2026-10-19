import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:path_provider/path_provider.dart';

import 'tables/execution_plans.dart';
import 'tables/mission_schedule_revisions.dart';
import 'tables/missions.dart';

part 'app_database.g.dart';

// 注册这个数据库包含的三张表。
@DriftDatabase(tables: [Missions, MissionScheduleRevisions, ExecutionPlans])
class AppDatabase extends _$AppDatabase {
  // 正常连接本地文件；测试时可以传入独立的内存数据库连接。
  AppDatabase({QueryExecutor? executor})
    // 传入父类的构造函数，初始化数据库连接器。
    : super(
        // 如果没有传入连接信息，连接本地数据库文件。
        executor ??
            driftDatabase(
              name: 'mission_book',
              // 连接配置：保存到系统提供的应用支持目录。
              native: const DriftNativeOptions(
                databaseDirectory: getApplicationSupportDirectory,
              ),
            ),
      );

  // 首个持久化版本；后续修改结构时需要升级版本并迁移旧数据。
  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    // 默认创建逻辑会建立注册的三张表，这里补充开启外键检查。
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );
}

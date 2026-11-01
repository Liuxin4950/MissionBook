import 'dart:async';

import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:path_provider/path_provider.dart';

import 'tables/execution_plans.dart';
import 'tables/execution_events.dart';
import 'tables/failure_records.dart';
import 'tables/mission_schedule_revisions.dart';
import 'tables/missions.dart';
import 'tables/evidence_records.dart';
import 'tables/goals.dart';
import 'tables/goal_nodes.dart';
import 'tables/import_receipts.dart';
import 'tables/assistant_sessions.dart';
import 'tables/operation_receipts.dart';
import 'tables/record_analysis_tables.dart';
import 'analysis_triggers.dart';

part 'app_database.g.dart';

/// 按平台连接原生 SQLite 或浏览器存储，表结构与事务规则共用。
// 目标、节点与任务共用同一连接，关联校验和任务保存可以放在同一事务。
@DriftDatabase(
  include: {'mission_ownership_guards.drift'},
  tables: [
    Missions,
    MissionScheduleRevisions,
    ExecutionPlans,
    ExecutionEvents,
    FailureRecords,
    EvidenceRecords,
    Goals,
    GoalNodes,
    ImportReceipts,
    AssistantSessions,
    AssistantSessionRecords,
    OperationReceipts,
    Records,
    UserExecutionReports,
    AnalysisJobs,
    AnalysisVersions,
    MemoryEntries,
    SearchUsage,
  ],
)
class AppDatabase extends _$AppDatabase {
  // 正常按平台选择存储；测试时可传入独立连接，不访问用户数据库。
  AppDatabase({QueryExecutor? executor})
    // 传入父类的构造函数，初始化数据库连接器。
    : super(
        // 没有传入测试连接时，让 Drift 根据当前平台选择下面的连接配置。
        executor ??
            driftDatabase(
              name: 'mission_book',
              // 浏览器由 Worker 运行 SQLite；这两个相对地址来自 web/ 中的配套资源。
              // 原生平台会忽略 web 配置，继续使用下面的应用支持目录。
              web: DriftWebOptions(
                sqlite3Wasm: Uri.parse('sqlite3.wasm'),
                driftWorker: Uri.parse('drift_worker.js'),
                onResult: (result) {
                  // 纯内存模式刷新后会丢数据，不能把它当成本地持久化成功。
                  if (result.chosenImplementation ==
                      WasmStorageImplementation.inMemory) {
                    unawaited(result.resolvedExecutor.close());
                    throw StateError('当前浏览器无法持久保存任务，请允许网站存储后重新加载');
                  }
                },
              ),
              // 连接配置：保存到系统提供的应用支持目录。
              native: const DriftNativeOptions(
                databaseDirectory: getApplicationSupportDirectory,
              ),
            ),
      );

  // 当前开发结构：任务材料保存快照，来源记录独立维护。
  @override
  int get schemaVersion => 16;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (migrator) async {
      await migrator.createAll();
      await installAnalysisTriggers(this);
    },
    // 普通查询之前，设置此连接的写锁等待和外键检查。
    beforeOpen: (details) async {
      // 前台与后台引擎各自持有一个连接；等待写锁而不是立即返回 SQLITE_BUSY。
      await customStatement('PRAGMA busy_timeout = 5000');
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );
}

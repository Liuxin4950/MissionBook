import 'dart:async';

import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'sqlite_errors.dart';
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
import 'tables/memory_tables.dart';
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
    MemoryItems,
    MemoryTopics,
    MemoryTopicAliases,
    MemoryVersions,
    MemoryEpisodes,
    MemoryProcedures,
    MemoryUsage,
    AppSettings,
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
  int get schemaVersion => 18;

  @override
  Future<T> transaction<T>(
    Future<T> Function() action, {
    bool requireNew = false,
  }) async {
    for (var attempt = 0; ; attempt++) {
      var entered = false;
      try {
        return await super.transaction(() {
          entered = true;
          return action();
        }, requireNew: requireNew);
      } catch (error) {
        // 只恢复 BEGIN 的竞争；正文或 COMMIT 已运行时绝不自动重放业务副作用。
        if (entered || attempt >= 3 || !isSqliteBusy(error)) rethrow;
        await Future<void>.delayed(Duration(milliseconds: 25 * (1 << attempt)));
      }
    }
  }

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (migrator) async {
      await migrator.createAll();
      await installAnalysisTriggers(this);
    },
    // 普通查询之前，设置此连接的写锁等待和外键检查。
    beforeOpen: (details) async {
      if (details.hadUpgrade) {
        // 当前开发阶段不提供迁移，也不自动删除本机数据；旧结构必须显式拒绝。
        throw StateError(
          '本机数据库来自版本 ${details.versionBefore}，当前开发版本仅支持版本 $schemaVersion。'
          '请先导出仍可读的数据，或在系统应用信息中清除数据后重新创建数据库。',
        );
      }
      // 前台与后台引擎各自持有一个连接；等待写锁而不是立即返回 SQLITE_BUSY。
      await customStatement('PRAGMA busy_timeout = 5000');
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );
}

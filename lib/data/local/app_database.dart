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

  // v11 追加助手会话日志与通用操作回执，任务、目标和执行事实保持不变。
  @override
  int get schemaVersion => 15;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (migrator) async {
      await migrator.createAll();
      await installAnalysisTriggers(this);
    },
    // 首次安装创建全部已注册表、声明的索引和归属触发器。
    // 已有库版本不同时，Drift 调用此回调，并传入旧版本 from 和目标版本 to。
    onUpgrade: (migrator, from, to) async {
      // 守卫与 schemaVersion 联动，不再手写版本数字：
      // 只接受“从 1..当前版本-1 的旧库升级到当前版本”，其他一律明确失败。
      // 升级新版本时仍要补迁移步骤，但这里不会再因漏改数字而误挡升级。
      if (from < 1 || from >= schemaVersion || to != schemaVersion) {
        // 不认识的版本明确失败，保留原库；不能用删库掩盖升级问题。
        throw StateError('不支持数据库从 v$from 升级或降级到 v$to');
      }
      // transaction 等待全部结构变更和版本标记成功才提交，异常时一起回滚。
      // createTable 只建表，不会自动建立 @TableIndex 声明的独立索引。
      await transaction(() async {
        // 先建内容表，使旧材料重建时的外键已有目标；归属表会在下面补齐。
        if (from < 15) await migrator.createTable(records);
        if (from < 2) {
          await migrator.createTable(executionEvents);
          await migrator.createIndex(executionEventsOneStart);
          await migrator.createIndex(executionEventsOneEnd);
        }
        // v3 新增失败记录；v1 可以一次补齐到 v3，v2 只追加这张表。
        if (from < 3) await migrator.createTable(failureRecords);
        if (from < 4) {
          await migrator.addColumn(missions, missions.sourceMissionId);
          await migrator.addColumn(missions, missions.relationType);
        }
        if (from < 5) {
          await migrator.addColumn(missions, missions.evidenceWaivedAt);
          await migrator.createTable(evidenceRecords);
        }
        if (from < 6) await migrator.createTable(goals);
        // 旧于 v7 才追加节点表；随后为各旧版任务追加可空归属列，原数据不改写。
        if (from < 7) {
          await migrator.createTable(goalNodes);
          await migrator.createIndex(goalNodesSiblings);
        }
        if (from < 8) {
          await migrator.addColumn(missions, missions.goalId);
          await migrator.addColumn(missions, missions.goalNodeId);
          await migrator.createIndex(missionsGoalNode);
          await migrator.createTrigger(missionsOwnershipInsert);
          await migrator.createTrigger(missionsOwnershipUpdate);
        }
        // v5-v8 的 CHECK 仅允许 TEXT/IMAGE。重建同名表保留全部原始记录，
        // 同时让新安装与升级安装得到相同的五类材料约束和修正列。
        if (from >= 5 && from < 9) {
          await customStatement(
            'ALTER TABLE evidence_records RENAME TO evidence_records_v8',
          );
          await migrator.createTable(evidenceRecords);
          await customStatement('''
            INSERT INTO evidence_records (
              id, mission_id, submission_id, type, source, content,
              attachment_storage_key, attachment_file_name,
              attachment_mime_type, captured_at, submitted_at
            ) SELECT
              id, mission_id, submission_id, type, source, content,
              attachment_storage_key, attachment_file_name,
              attachment_mime_type, captured_at, submitted_at
            FROM evidence_records_v8
          ''');
          await customStatement('DROP TABLE evidence_records_v8');
        }
        if (from < 10) {
          await migrator.createTable(importReceipts);
          await migrator.createIndex(importReceiptsContent);
          await migrator.createIndex(evidenceRecordsMission);
          await migrator.createIndex(missionScheduleFixed);
        }
        if (from < 11) {
          await migrator.createTable(assistantSessions);
          await migrator.createIndex(assistantSessionsUpdated);
          await migrator.createTable(assistantSessionRecords);
          await migrator.createTable(operationReceipts);
          await migrator.createIndex(operationReceiptsEntity);
        }
        // v12 只给已有会话索引补节点引用；v1-v10 创建的表已经包含此列。
        if (from == 11) {
          await migrator.addColumn(assistantSessions, assistantSessions.nodeId);
        }
        if (from >= 2 && from < 13) {
          await migrator.addColumn(
            executionEvents,
            executionEvents.isRetrospective,
          );
        }
        if (from >= 2 && from < 14) {
          // v14 放宽动作约束，保留事件及唯一索引；没有表引用执行事件。
          await migrator.alterTable(TableMigration(executionEvents));
        }
        if (from < 15) {
          if (from >= 6) await migrator.addColumn(goals, goals.desireLevel);
          if (from >= 9) {
            await migrator.alterTable(
              TableMigration(
                evidenceRecords,
                newColumns: [evidenceRecords.recordId],
              ),
            );
          }
          // 原材料身份、提交时间和文件路径原样保留；只移动正文载荷。
          await customStatement('''
            INSERT INTO records (id,type,source,content,attachment_storage_key,
              attachment_file_name,attachment_mime_type,captured_at,occurred_at,
              created_at,goal_id,goal_node_id)
            SELECT e.id,e.type,e.source,e.content,e.attachment_storage_key,
              e.attachment_file_name,e.attachment_mime_type,e.captured_at,
              COALESCE(e.captured_at,e.submitted_at),e.submitted_at,m.goal_id,m.goal_node_id
            FROM evidence_records e JOIN missions m ON m.id=e.mission_id
          ''');
          await customStatement('''UPDATE evidence_records SET record_id=id,
            content=NULL,attachment_storage_key=NULL,attachment_file_name=NULL,
            attachment_mime_type=NULL,captured_at=NULL''');
          await migrator.createIndex(recordsScope);
          await migrator.createIndex(recordsDay);
          await migrator.createTable(userExecutionReports);
          await migrator.createTable(analysisJobs);
          await migrator.createTable(analysisVersions);
          await migrator.createTable(memoryEntries);
          await migrator.createTable(searchUsage);
          await migrator.createIndex(userReportsMission);
          await migrator.createIndex(analysisJobsDue);
          await migrator.createIndex(analysisVersionsTarget);
          await migrator.createIndex(memoryEntriesSource);
          await migrator.createIndex(memoryEntriesTopic);
          // 在搬迁之后安装，升级不会给全部历史材料排模型请求。
          await installAnalysisTriggers(this);
        }
        // Drift 默认在全部开库回调完成后才记版本。把标记与结构一起提交，
        // 避免结构已建好、后续开库中断后，重开仍按 v1 重复创建索引。
        // to 是 Drift 传入且已在上面确认的目标版本，不来自用户输入。
        await customStatement('PRAGMA user_version = $to');
      });
    },
    // 新建/升级之后、普通查询之前，开启此连接的外键检查。
    beforeOpen: (details) async {
      // 前台与后台引擎各自持有一个连接；等待写锁而不是立即返回 SQLITE_BUSY。
      await customStatement('PRAGMA busy_timeout = 5000');
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );
}

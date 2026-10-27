import 'dart:async';
import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:path_provider/path_provider.dart';

import '../../domain/entities/goal_package_import.dart';
import '../../domain/repositories/goal_package_repository.dart';

/// 与正式业务库独立的持久暂存库；没有今天页或执行调度的读入口。
class GoalImportDatabase extends GeneratedDatabase implements GoalImportStage {
  GoalImportDatabase({QueryExecutor? executor})
    : super(
        executor ??
            driftDatabase(
              name: 'mission_book_goal_import',
              native: const DriftNativeOptions(
                databaseDirectory: getApplicationSupportDirectory,
              ),
              web: DriftWebOptions(
                sqlite3Wasm: Uri.parse('sqlite3.wasm'),
                driftWorker: Uri.parse('drift_worker.js'),
                onResult: (result) {
                  if (result.chosenImplementation ==
                      WasmStorageImplementation.inMemory) {
                    unawaited(result.resolvedExecutor.close());
                    throw StateError('浏览器无法持久暂存导入，请允许网站存储');
                  }
                },
              ),
            ),
      );

  @override
  int get schemaVersion => 1;
  @override
  Iterable<TableInfo<Table, Object?>> get allTables => const [];
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => const [];

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (_) async {
      await customStatement('PRAGMA auto_vacuum = FULL');
      await customStatement('''
CREATE TABLE import_job (
 singleton INTEGER PRIMARY KEY CHECK(singleton = 1),
 id TEXT NOT NULL UNIQUE, goal_id TEXT NOT NULL,
 state TEXT NOT NULL, root_json TEXT, summary_json TEXT
)''');
      await customStatement('''
CREATE TABLE import_entry (
 job_id TEXT NOT NULL REFERENCES import_job(id),
 kind TEXT NOT NULL CHECK(kind IN ('NODE','MISSION')),
 source_index INTEGER NOT NULL, parent_index INTEGER,
 order_index INTEGER NOT NULL, entry_key TEXT NOT NULL,
 id TEXT NOT NULL, schedule_id TEXT, plan_id TEXT,
 raw_json TEXT NOT NULL, resolved_json TEXT,
 PRIMARY KEY(kind, source_index), UNIQUE(kind, entry_key)
)''');
      await customStatement(
        'CREATE INDEX import_entry_parent ON import_entry(kind, parent_index, order_index)',
      );
    },
    beforeOpen: (_) async {
      await customStatement('PRAGMA foreign_keys = ON');
      final size = await customSelect('PRAGMA page_size').getSingle();
      final pages = GoalImportLimits.stageBytes ~/ size.read<int>('page_size');
      await customStatement('PRAGMA max_page_count = $pages');
    },
  );

  Future<void> _require(String jobId, {String? state}) async {
    final row = await customSelect(
      'SELECT id,state FROM import_job WHERE id = ?',
      variables: [Variable<String>(jobId)],
    ).getSingleOrNull();
    if (row == null) {
      throw const GoalImportException('JOB_CHANGED', '/', '导入草稿已变化，请重新读取');
    }
    if (state != null && row.read<String>('state') != state) {
      throw const GoalImportException('JOB_SEALED', '/', '预览已封存，不能再修改暂存内容');
    }
  }

  @override
  Future<void> begin(String jobId, String goalId) => transaction(() async {
    await customStatement('UPDATE import_job SET state = state WHERE 0');
    if (await pending() != null) {
      throw const GoalImportException('JOB_EXISTS', '/', '有上次导入草稿，请先继续或丢弃');
    }
    await customStatement(
      "INSERT INTO import_job(singleton,id,goal_id,state) VALUES(1,?,?,'READING')",
      [jobId, goalId],
    );
  });

  @override
  Future<void> append(String jobId, List<GoalImportEntry> entries) =>
      transaction(() async {
        await _require(jobId, state: 'READING');
        await batch((batch) {
          for (final entry in entries) {
            batch.customStatement(
              '''
INSERT INTO import_entry(job_id,kind,source_index,parent_index,order_index,entry_key,id,schedule_id,plan_id,raw_json)
VALUES(?,?,?,?,?,?,?,?,?,?)''',
              [
                jobId,
                entry.kind,
                entry.sourceIndex,
                entry.parentIndex,
                entry.orderIndex,
                entry.key,
                entry.id,
                entry.scheduleId,
                entry.planId,
                jsonEncode(entry.raw),
              ],
            );
          }
        });
      });

  @override
  Future<void> setRoot(String jobId, Map<String, Object?> root) async {
    await _require(jobId, state: 'READING');
    await customStatement(
      "UPDATE import_job SET state='VALIDATING',root_json=? WHERE id=?",
      [jsonEncode(root), jobId],
    );
  }

  @override
  Future<Map<String, Object?>?> pending() async {
    final row = await customSelect(
      'SELECT * FROM import_job',
    ).getSingleOrNull();
    if (row == null) return null;
    return {
      'jobId': row.read<String>('id'),
      'goalId': row.read<String>('goal_id'),
      'state': row.read<String>('state'),
      'root': _json(row.readNullable<String>('root_json')),
      'summary': _json(row.readNullable<String>('summary_json')),
    };
  }

  @override
  Future<List<GoalImportEntry>> entries(
    String jobId,
    String kind, {
    int offset = 0,
    int limit = 50,
  }) async {
    await _require(jobId);
    if (offset < 0 || limit < 1 || limit > 100) {
      throw ArgumentError('暂存分页必须为 1–100 条');
    }
    final rows = await customSelect(
      '''
SELECT * FROM (
 SELECT bounded.*, SUM(
   length(CAST(raw_json AS BLOB)) +
   COALESCE(length(CAST(resolved_json AS BLOB)),0)
 ) OVER(ORDER BY source_index) AS accumulated_bytes
 FROM (
  SELECT * FROM import_entry WHERE job_id=? AND kind=?
  ORDER BY source_index LIMIT ? OFFSET ?
 ) bounded
) WHERE accumulated_bytes <= 1048576 OR source_index=?
ORDER BY source_index''',
      variables: [
        Variable<String>(jobId),
        Variable<String>(kind),
        Variable<int>(limit),
        Variable<int>(offset),
        Variable<int>(offset),
      ],
    ).get();
    return [
      for (final row in rows)
        GoalImportEntry(
          kind: row.read<String>('kind'),
          sourceIndex: row.read<int>('source_index'),
          parentIndex: row.readNullable<int>('parent_index'),
          orderIndex: row.read<int>('order_index'),
          key: row.read<String>('entry_key'),
          id: row.read<String>('id'),
          scheduleId: row.readNullable<String>('schedule_id'),
          planId: row.readNullable<String>('plan_id'),
          raw: _json(row.read<String>('raw_json'))!,
          resolved: _json(row.readNullable<String>('resolved_json')),
        ),
    ];
  }

  @override
  Future<void> resolveBatch(
    String jobId,
    List<GoalImportEntry> entries,
  ) => transaction(() async {
    await _require(jobId, state: 'VALIDATING');
    await batch((batch) {
      for (final entry in entries) {
        batch.customStatement(
          "UPDATE import_entry SET resolved_json=? WHERE job_id=? AND kind='MISSION' AND source_index=?",
          [jsonEncode(entry.resolved), jobId, entry.sourceIndex],
        );
      }
    });
  });

  @override
  Future<void> seal(String jobId, Map<String, Object?> summary) async {
    await _require(jobId, state: 'VALIDATING');
    await customStatement(
      "UPDATE import_job SET state='READY',summary_json=? WHERE id=?",
      [jsonEncode(summary), jobId],
    );
  }

  @override
  Future<void> assertReady(String jobId, String hash) async {
    final job = await pending();
    final summary = job?['summary'] as Map<String, Object?>?;
    if (job?['jobId'] != jobId ||
        job?['state'] != 'READY' ||
        summary?['payloadHash'] != hash) {
      throw const GoalImportException('JOB_CHANGED', '/', '预览已失效，请重新校验');
    }
  }

  @override
  Future<void> discard(String jobId) => transaction(() async {
    await _require(jobId);
    await customStatement('DELETE FROM import_entry WHERE job_id=?', [jobId]);
    await customStatement('DELETE FROM import_job WHERE id=?', [jobId]);
  });

  static Map<String, Object?>? _json(String? text) =>
      text == null ? null : (jsonDecode(text) as Map).cast<String, Object?>();
}

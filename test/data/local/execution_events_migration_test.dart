import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:drift_dev/api/migrations_native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mission_book/data/local/app_database.dart';

const _oldTables = [
  'missions',
  'mission_schedule_revisions',
  'execution_plans',
];
const _time = 1792713600000;

// 测试专用旧库：从已冻结的 v1 快照建表，不能拿当前 v2 定义冒充旧库。
// 不生成第二套业务类；它只负责准备磁盘上的旧数据，然后关闭连接。
class _SnapshotV1Database extends GeneratedDatabase {
  _SnapshotV1Database(super.executor, {this.oldVersion = 1});
  final int oldVersion;

  @override
  int get schemaVersion => oldVersion;

  @override
  Iterable<TableInfo<Table, Object?>> get allTables => const [];

  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => const [];

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (_) async {
      final snapshot =
          jsonDecode(
                await File(
                  'drift_schemas/drift_schema_v$oldVersion.json',
                ).readAsString(),
              )
              as Map<String, dynamic>;
      for (final entity in snapshot['fixed_sql'] as List<dynamic>) {
        final statements = entity['sql'] as List<dynamic>;
        final sqlite = statements.singleWhere(
          (sql) => sql['dialect'] == 'sqlite',
        );
        await customStatement(sqlite['sql'] as String);
      }
    },
  );
}

Future<Map<String, List<Map<String, dynamic>>>> _readOldRows(
  GeneratedDatabase database,
) async {
  final result = <String, List<Map<String, dynamic>>>{};
  for (final table in _oldTables) {
    // 表名只取上面的固定列表；读取全部列，防止只检查数量而漏掉字段丢失。
    final rows = await database
        .customSelect('SELECT * FROM $table ORDER BY id')
        .get();
    result[table] = [
      for (final row in rows)
        Map<String, dynamic>.from(row.data)
          ..remove('is_retrospective')
          ..remove('source_mission_id')
          ..remove('relation_type')
          ..remove('evidence_waived_at')
          ..remove('goal_id')
          ..remove('goal_node_id'),
    ];
  }
  return result;
}

Future<void> _seedV1(_SnapshotV1Database old) async {
  await old.customStatement(
    'INSERT INTO missions (id, title, description, why, verification_policy, created_at, updated_at, cancelled_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?)',
    [
      'mission-a',
      '阅读“第一章”',
      '保留描述\n和换行',
      '准备讨论',
      'SELF_REPORT',
      _time,
      _time + 1,
      null,
    ],
  );
  await old.customStatement(
    'INSERT INTO missions (id, title, description, why, verification_policy, created_at, updated_at, cancelled_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?)',
    [
      'mission-b',
      '已取消任务',
      null,
      null,
      'REQUIRED_EVIDENCE',
      _time,
      _time + 2,
      _time + 2,
    ],
  );
  for (final row in [
    [
      'schedule-a1',
      'mission-a',
      1,
      '2026-10-23',
      'Asia/Shanghai',
      'FLEXIBLE',
      null,
      20,
      null,
      null,
      _time,
    ],
    [
      'schedule-a2',
      'mission-a',
      2,
      '2026-10-24',
      'Asia/Shanghai',
      'FIXED',
      _time + 60000,
      30,
      null,
      '保留改期历史',
      _time + 1,
    ],
    [
      'schedule-b',
      'mission-b',
      1,
      '2026-10-23',
      'Asia/Shanghai',
      'FLEXIBLE',
      null,
      45,
      _time + 3600000,
      null,
      _time,
    ],
  ]) {
    await old.customStatement(
      'INSERT INTO mission_schedule_revisions VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
      row,
    );
  }
  for (final mission in ['a', 'b']) {
    await old.customStatement(
      'INSERT INTO execution_plans VALUES (?, ?, ?, ?, ?, ?, ?, ?)',
      [
        'plan-$mission',
        'mission-$mission',
        '读完十页',
        '["阅读","记录\\n心得"]',
        '保留验收方向',
        '保留备注',
        _time,
        _time + 1,
      ],
    );
  }
}

Future<int> _version(GeneratedDatabase database) async {
  final row = await database.customSelect('PRAGMA user_version').getSingle();
  return row.read<int>('user_version');
}

// 模拟升级事务成功之后，后续开库回调中断。复用真实迁移逻辑，不另写一套。
class _InterruptedOpenDatabase extends AppDatabase {
  _InterruptedOpenDatabase({super.executor});

  @override
  MigrationStrategy get migration {
    final original = super.migration;
    return MigrationStrategy(
      onCreate: original.onCreate,
      onUpgrade: original.onUpgrade,
      beforeOpen: (_) async => throw StateError('测试：升级提交后开库中断'),
    );
  }
}

void main() {
  group('v1 → 当前版本文件迁移', () {
    late Directory directory;
    late File file;

    setUp(() async {
      directory = await Directory.systemTemp.createTemp('missionbook-v1-v2-');
      file = File('${directory.path}/test.sqlite');
    });

    tearDown(() async {
      // 只清理本测试创建的专属临时目录，所有连接已在 finally 中关闭。
      await directory.delete(recursive: true);
    });

    test('v11 升级补节点列并完整保留会话、日志和操作回执', () async {
      final old = _SnapshotV1Database(NativeDatabase(file), oldVersion: 11);
      await old.customStatement(
        "INSERT INTO assistant_sessions(id,title,created_at,updated_at) VALUES ('old-chat','原会话',1,2)",
      );
      await old.customStatement(
        "INSERT INTO assistant_session_records(session_id,sequence,timestamp,type,data) VALUES ('old-chat',0,1,'test_record','{\"text\":\"保留原文\"}')",
      );
      await old.customStatement(
        "INSERT INTO operation_receipts(id,kind,fingerprint,entity_id,result_json,created_at) VALUES ('old-op','mission_edit','same','mission-a','{}',1)",
      );
      await old.close();
      final upgraded = AppDatabase(executor: NativeDatabase(file));
      try {
        final session =
            (await upgraded.select(upgraded.assistantSessions).get()).single;
        expect(session.title, '原会话');
        expect(session.nodeId, isNull);
        expect(session.updatedAt, 2);
        expect(
          (await upgraded.select(upgraded.assistantSessionRecords).get())
              .single
              .data,
          contains('保留原文'),
        );
        expect(
          (await upgraded.select(upgraded.operationReceipts).get())
              .single
              .fingerprint,
          'same',
        );
        await upgraded.validateDatabaseSchema();
      } finally {
        await upgraded.close();
      }
    });

    for (final oldVersion in [5, 6, 7, 8, 9, 10, 11, 12]) {
      test('v$oldVersion 全表逐字段保留，旧任务独立，关闭重开仍完整', () async {
        final tables = [
          ..._oldTables,
          'execution_events',
          'failure_records',
          'evidence_records',
          if (oldVersion >= 6) 'goals',
          if (oldVersion >= 7) 'goal_nodes',
        ];
        Future<Map<String, List<Map<String, dynamic>>>> snapshot(
          GeneratedDatabase connection,
        ) async {
          return {
            for (final table in tables)
              table: [
                for (final row
                    in await connection
                        .customSelect('SELECT * FROM $table ORDER BY id')
                        .get())
                  {
                    for (final entry in row.data.entries)
                      if (entry.key != 'is_retrospective')
                        if (table != 'missions' ||
                            !['goal_id', 'goal_node_id'].contains(entry.key))
                          if (table != 'evidence_records' ||
                              oldVersion >= 9 ||
                              entry.key != 'supersedes_evidence_id')
                            entry.key: entry.value,
                  },
              ],
          };
        }

        final old = _SnapshotV1Database(
          NativeDatabase(file),
          oldVersion: oldVersion,
        );
        late Map<String, List<Map<String, dynamic>>> before;
        try {
          await _seedV1(old);
          if (oldVersion >= 6) {
            for (final status in ['ACTIVE', 'PAUSED', 'ACHIEVED', 'DROPPED']) {
              await old.customStatement(
                'INSERT INTO goals (id, title, description, why, status, created_at, updated_at) VALUES (?, ?, ?, ?, ?, ?, ?)',
                [
                  'goal-$status',
                  '原有目标$status',
                  '保留说明\n及换行',
                  '保留目标原因',
                  status,
                  _time,
                  _time + 10,
                ],
              );
            }
          }
          if (oldVersion >= 7) {
            await old.customStatement(
              "INSERT INTO goal_nodes (id, goal_id, parent_node_id, title, description, order_index, archived_at, created_at, updated_at) VALUES ('old-root', 'goal-ACTIVE', NULL, '原父节点', '原说明', 0, NULL, ?, ?)",
              [_time, _time + 1],
            );
            await old.customStatement(
              "INSERT INTO goal_nodes (id, goal_id, parent_node_id, title, description, order_index, archived_at, created_at, updated_at) VALUES ('old-child', 'goal-ACTIVE', 'old-root', '原归档节点', '原子说明', 0, ?, ?, ?)",
              [_time + 2, _time, _time + 3],
            );
          }
          await old.customStatement(
            "UPDATE missions SET evidence_waived_at = ? WHERE id = 'mission-b'",
            [_time + 2000],
          );
          await old.customStatement(
            "INSERT INTO execution_events (id, mission_id, sequence, type, occurred_at, schedule_revision_id) VALUES ('start-v5', 'mission-a', 1, 'START', ?, 'schedule-a2')",
            [_time],
          );
          await old.customStatement(
            "INSERT INTO execution_events (id, mission_id, sequence, type, occurred_at, user_reported_result) VALUES ('end-v5', 'mission-a', 2, 'END', ?, 'COMPLETED')",
            [_time + 1000],
          );
          await old.customStatement(
            "INSERT INTO failure_records (id, mission_id, \"trigger\", occurred_at, user_reason_text, created_at) VALUES ('failure-v5', 'mission-b', 'EVIDENCE_DEADLINE_MISSED', ?, '旧原因原样保留', ?)",
            [_time + 1000, _time + 1000],
          );
          await old.customStatement(
            "INSERT INTO evidence_records (id, mission_id, submission_id, type, source, content, submitted_at) VALUES ('text-v5', 'mission-a', 'batch-v5', 'TEXT', 'USER', '已有正文\\n不丢失', ?)",
            [_time + 1000],
          );
          await old.customStatement(
            "INSERT INTO evidence_records (id, mission_id, submission_id, type, source, attachment_storage_key, attachment_file_name, attachment_mime_type, submitted_at) VALUES ('image-v5', 'mission-a', 'batch-v5', 'IMAGE', 'FILE_SYSTEM', 'attachments/mission-a/original.png', '原图.png', 'image/png', ?)",
            [_time + 1000],
          );
          if (oldVersion >= 9) {
            await old.customStatement(
              "INSERT INTO evidence_records (id, mission_id, submission_id, type, source, content, submitted_at, supersedes_evidence_id) VALUES ('corrected-v9', 'mission-a', 'batch-correction', 'TEXT', 'USER', '修正内容', ?, 'text-v5')",
              [_time + 2000],
            );
          }
          before = await snapshot(old);
        } finally {
          await old.close();
        }
        final upgraded = AppDatabase(executor: NativeDatabase(file));
        try {
          expect(await _version(upgraded), 13);
          expect(await snapshot(upgraded), before);
          expect(
            await upgraded.select(upgraded.goals).get(),
            hasLength(oldVersion >= 6 ? 4 : 0),
          );
          expect(
            await upgraded.select(upgraded.goalNodes).get(),
            hasLength(oldVersion >= 7 ? 2 : 0),
          );
          expect(
            (await upgraded.select(upgraded.missions).get()).every(
              (row) => row.goalId == null && row.goalNodeId == null,
            ),
            isTrue,
          );
          if (oldVersion >= 7) {
            await expectLater(
              upgraded.customStatement(
                "UPDATE missions SET goal_id = 'goal-PAUSED', goal_node_id = 'old-child' WHERE id = 'mission-a'",
              ),
              throwsA(isA<SqliteException>()),
            );
          }
          await upgraded.validateDatabaseSchema();
          expect(
            await upgraded.customSelect('PRAGMA foreign_key_check').get(),
            isEmpty,
          );
        } finally {
          await upgraded.close();
        }
        final reopened = AppDatabase(executor: NativeDatabase(file));
        try {
          expect(await snapshot(reopened), before);
          expect(await _version(reopened), 13);
        } finally {
          await reopened.close();
        }
      });
    }

    test('v7 升级在第二条归属触发器处失败，新增列和第一条触发器一起回滚后可重试', () async {
      final old = _SnapshotV1Database(NativeDatabase(file), oldVersion: 7);
      late Map<String, List<Map<String, dynamic>>> before;
      try {
        await _seedV1(old);
        before = await _readOldRows(old);
        // 制造同名结构冲突，使故障发生在 v8 迁移末尾，验证整个事务会回滚。
        await old.customStatement(
          'CREATE TRIGGER missions_ownership_update BEFORE INSERT ON missions BEGIN SELECT 1; END',
        );
      } finally {
        await old.close();
      }
      final failing = AppDatabase(executor: NativeDatabase(file));
      try {
        await expectLater(_version(failing), throwsA(isA<SqliteException>()));
      } finally {
        await failing.close();
      }
      final inspect = _SnapshotV1Database(NativeDatabase(file), oldVersion: 7);
      try {
        expect(await _version(inspect), 7);
        expect(await _readOldRows(inspect), before);
        final columns = await inspect
            .customSelect('PRAGMA table_info(missions)')
            .get();
        expect(
          columns.map((row) => row.read<String>('name')),
          isNot(contains('goal_id')),
        );
        expect(
          await inspect
              .customSelect(
                "SELECT name FROM sqlite_master WHERE name IN ('missions_ownership_insert', 'missions_goal_node')",
              )
              .get(),
          isEmpty,
        );
        await inspect.customStatement('DROP TRIGGER missions_ownership_update');
      } finally {
        await inspect.close();
      }
      final retry = AppDatabase(executor: NativeDatabase(file));
      try {
        expect(await _version(retry), 13);
        expect(await _readOldRows(retry), before);
        await retry.validateDatabaseSchema();
      } finally {
        await retry.close();
      }
    });

    test('v4真实来源与完整执行历史逐字段保留，当前版追加空放弃字段、材料与目标表', () async {
      const preservedTables = [
        ..._oldTables,
        'execution_events',
        'failure_records',
      ];
      Future<Map<String, List<Map<String, dynamic>>>> snapshot(
        GeneratedDatabase connection,
      ) async {
        final result = <String, List<Map<String, dynamic>>>{};
        for (final table in preservedTables) {
          result[table] = [
            for (final row
                in await connection
                    .customSelect('SELECT * FROM $table ORDER BY id')
                    .get())
              Map<String, dynamic>.from(row.data)
                ..remove('is_retrospective')
                ..remove('evidence_waived_at')
                ..remove('goal_id')
                ..remove('goal_node_id'),
          ];
        }
        return result;
      }

      final old = _SnapshotV1Database(NativeDatabase(file), oldVersion: 4);
      late Map<String, List<Map<String, dynamic>>> before;
      try {
        await _seedV1(old);
        await old.customStatement(
          "UPDATE missions SET source_mission_id = 'mission-b', relation_type = 'RETRY' WHERE id = 'mission-a'",
        );
        await old.customStatement(
          "INSERT INTO execution_events (id, mission_id, sequence, type, occurred_at, schedule_revision_id) VALUES ('start-v4', 'mission-a', 1, 'START', ?, 'schedule-a2')",
          [_time],
        );
        await old.customStatement(
          "INSERT INTO execution_events (id, mission_id, sequence, type, occurred_at, user_reported_result) VALUES ('end-v4', 'mission-a', 2, 'END', ?, 'NOT_COMPLETED')",
          [_time + 1000],
        );
        await old.customStatement(
          'INSERT INTO failure_records (id, mission_id, "trigger", occurred_at, user_reason_category, user_reason_text, created_at) VALUES (?, ?, ?, ?, ?, ?, ?)',
          [
            'failure-v4',
            'mission-a',
            'USER_MARKED_NOT_COMPLETED',
            _time + 1000,
            'OTHER',
            'v4用户原因',
            _time + 1000,
          ],
        );
        before = await snapshot(old);
        expect(await _version(old), 4);
      } finally {
        await old.close();
      }
      final upgraded = AppDatabase(executor: NativeDatabase(file));
      try {
        expect(await _version(upgraded), 13);
        expect(await snapshot(upgraded), before);
        expect(
          (await upgraded.select(upgraded.missions).get()).every(
            (mission) => mission.evidenceWaivedAt == null,
          ),
          isTrue,
        );
        expect(await upgraded.select(upgraded.evidenceRecords).get(), isEmpty);
        await upgraded.validateDatabaseSchema();
        expect(
          await upgraded.customSelect('PRAGMA foreign_key_check').get(),
          isEmpty,
        );
      } finally {
        await upgraded.close();
      }
    });

    test('v3完整执行记录升级当前版：事件、报告、失败原因保留，新增材料事实为空', () async {
      final old = _SnapshotV1Database(NativeDatabase(file), oldVersion: 3);
      late Map<String, List<Map<String, dynamic>>> before;
      late List<Map<String, dynamic>> oldEvents;
      late List<Map<String, dynamic>> oldFailures;
      try {
        await _seedV1(old);
        await old.customStatement(
          "INSERT INTO execution_events (id, mission_id, sequence, type, occurred_at, schedule_revision_id) VALUES ('start-v3', 'mission-a', 1, 'START', ?, 'schedule-a2')",
          [_time],
        );
        await old.customStatement(
          "INSERT INTO execution_events (id, mission_id, sequence, type, occurred_at, user_reported_result) VALUES ('end-v3', 'mission-a', 2, 'END', ?, 'NOT_COMPLETED')",
          [_time + 1000],
        );
        await old.customStatement(
          'INSERT INTO failure_records (id, mission_id, "trigger", occurred_at, user_reason_category, user_reason_text, created_at) VALUES (?, ?, ?, ?, ?, ?, ?)',
          [
            'failure-v3',
            'mission-a',
            'USER_MARKED_NOT_COMPLETED',
            _time + 1000,
            'OTHER',
            '保留用户原因',
            _time + 1000,
          ],
        );
        before = await _readOldRows(old);
        oldEvents = [
          for (final row
              in await old
                  .customSelect(
                    'SELECT * FROM execution_events ORDER BY sequence',
                  )
                  .get())
            (Map<String, dynamic>.from(row.data)..remove('is_retrospective')),
        ];
        oldFailures = [
          for (final row
              in await old.customSelect('SELECT * FROM failure_records').get())
            (Map<String, dynamic>.from(row.data)..remove('is_retrospective')),
        ];
      } finally {
        await old.close();
      }
      final upgraded = AppDatabase(executor: NativeDatabase(file));
      try {
        expect(await _version(upgraded), 13);
        expect(await _readOldRows(upgraded), before);
        expect([
          for (final row
              in await upgraded
                  .customSelect(
                    'SELECT * FROM execution_events ORDER BY sequence',
                  )
                  .get())
            (Map<String, dynamic>.from(row.data)..remove('is_retrospective')),
        ], oldEvents);
        expect([
          for (final row
              in await upgraded
                  .customSelect('SELECT * FROM failure_records')
                  .get())
            (Map<String, dynamic>.from(row.data)..remove('is_retrospective')),
        ], oldFailures);
        final missions = await upgraded.select(upgraded.missions).get();
        expect(
          missions.every(
            (row) =>
                row.sourceMissionId == null &&
                row.relationType == null &&
                row.evidenceWaivedAt == null,
          ),
          isTrue,
        );
        expect(await upgraded.select(upgraded.evidenceRecords).get(), isEmpty);
        await upgraded.validateDatabaseSchema();
        expect(
          await upgraded.customSelect('PRAGMA foreign_key_check').get(),
          isEmpty,
        );
      } finally {
        await upgraded.close();
      }
    });

    test('v2已有事件升级当前版：旧任务和事件逐字段保留，失败表初始为空', () async {
      final old = _SnapshotV1Database(NativeDatabase(file), oldVersion: 2);
      late Map<String, List<Map<String, dynamic>>> before;
      late List<Map<String, dynamic>> oldEvents;
      try {
        await _seedV1(old);
        await old.customStatement(
          "INSERT INTO execution_events (id, mission_id, sequence, type, occurred_at, schedule_revision_id) VALUES ('start-v2', 'mission-a', 1, 'START', ?, 'schedule-a2')",
          [_time],
        );
        before = await _readOldRows(old);
        oldEvents = [
          for (final row
              in await old.customSelect('SELECT * FROM execution_events').get())
            (Map<String, dynamic>.from(row.data)..remove('is_retrospective')),
        ];
        expect(await _version(old), 2);
      } finally {
        await old.close();
      }
      final upgraded = AppDatabase(executor: NativeDatabase(file));
      try {
        expect(await _version(upgraded), 13);
        expect(await _readOldRows(upgraded), before);
        expect([
          for (final row
              in await upgraded
                  .customSelect('SELECT * FROM execution_events')
                  .get())
            (Map<String, dynamic>.from(row.data)..remove('is_retrospective')),
        ], oldEvents);
        expect(await upgraded.select(upgraded.failureRecords).get(), isEmpty);
        await upgraded.validateDatabaseSchema();
      } finally {
        await upgraded.close();
      }
    });

    test('旧三表逐字段保留、新事件可写，关闭重开仍在且结构与新装一致', () async {
      final old = _SnapshotV1Database(NativeDatabase(file));
      late Map<String, List<Map<String, dynamic>>> before;
      try {
        await _seedV1(old);
        expect(await _version(old), 1);
        before = await _readOldRows(old);
      } finally {
        await old.close();
      }

      final upgraded = AppDatabase(executor: NativeDatabase(file));
      try {
        expect(await _version(upgraded), 13);
        expect(await _readOldRows(upgraded), before);
        expect(await upgraded.select(upgraded.executionEvents).get(), isEmpty);
        await upgraded.validateDatabaseSchema();
        expect(
          await upgraded.customSelect('PRAGMA foreign_key_check').get(),
          isEmpty,
        );
        await _insertEvent(
          upgraded,
          'start-a',
          'mission-a',
          1,
          'START',
          schedule: 'schedule-a2',
        );
        // 确认升级路径也建立了独立的 START 唯一索引。
        await expectLater(
          _insertEvent(
            upgraded,
            'start-a-again',
            'mission-a',
            2,
            'START',
            schedule: 'schedule-a2',
          ),
          throwsA(isA<SqliteException>()),
        );
        await expectLater(
          _insertEvent(upgraded, 'orphan', 'missing', 1, 'PAUSE'),
          throwsA(isA<SqliteException>()),
        );
      } finally {
        await upgraded.close();
      }

      final reopened = AppDatabase(executor: NativeDatabase(file));
      try {
        expect(await _version(reopened), 13);
        expect(await _readOldRows(reopened), before);
        final event = await reopened
            .select(reopened.executionEvents)
            .getSingle();
        expect(event.id, 'start-a');
        expect(event.scheduleRevisionId, 'schedule-a2');
        expect(event.occurredAt, _time);
      } finally {
        await reopened.close();
      }
    });

    test('升级提交后开库中断，版本与结构仍一致，再次打开成功', () async {
      final old = _SnapshotV1Database(NativeDatabase(file));
      late Map<String, List<Map<String, dynamic>>> before;
      try {
        await _seedV1(old);
        before = await _readOldRows(old);
      } finally {
        await old.close();
      }
      final interrupted = _InterruptedOpenDatabase(
        executor: NativeDatabase(file),
      );
      try {
        await expectLater(_version(interrupted), throwsA(isA<StateError>()));
      } finally {
        await interrupted.close();
      }
      final reopened = AppDatabase(executor: NativeDatabase(file));
      try {
        expect(await _version(reopened), 13);
        expect(await _readOldRows(reopened), before);
        await reopened.validateDatabaseSchema();
      } finally {
        await reopened.close();
      }
    });

    test('迁移中途失败时新表和索引一起回滚，旧数据保留且移除故障后可重试', () async {
      final old = _SnapshotV1Database(NativeDatabase(file));
      late Map<String, List<Map<String, dynamic>>> before;
      try {
        await _seedV1(old);
        before = await _readOldRows(old);
        // 人工设置名称冲突，使真实迁移在最后一步创建 END 索引时失败。
        await old.customStatement(
          'CREATE INDEX execution_events_one_end ON missions (id)',
        );
      } finally {
        await old.close();
      }
      final failing = AppDatabase(executor: NativeDatabase(file));
      try {
        await expectLater(_version(failing), throwsA(isA<SqliteException>()));
      } finally {
        await failing.close();
      }
      final inspect = _SnapshotV1Database(NativeDatabase(file));
      try {
        expect(await _version(inspect), 1);
        expect(await _readOldRows(inspect), before);
        final leftovers = await inspect
            .customSelect(
              "SELECT name FROM sqlite_master WHERE name IN ('execution_events', 'execution_events_one_start')",
            )
            .get();
        expect(leftovers, isEmpty);
        await inspect.customStatement('DROP INDEX execution_events_one_end');
      } finally {
        await inspect.close();
      }
      final retry = AppDatabase(executor: NativeDatabase(file));
      try {
        expect(await _version(retry), 13);
        expect(await _readOldRows(retry), before);
        await retry.validateDatabaseSchema();
      } finally {
        await retry.close();
      }
    });
  });

  group('当前版本新装事件表约束', () {
    late AppDatabase database;

    setUp(() async {
      database = AppDatabase(executor: NativeDatabase.memory());
      for (final id in ['mission-a', 'mission-b']) {
        await database
            .into(database.missions)
            .insert(
              MissionsCompanion.insert(
                id: id,
                title: '事件测试',
                createdAt: _time,
                updatedAt: _time,
              ),
            );
        await database
            .into(database.missionScheduleRevisions)
            .insert(
              MissionScheduleRevisionsCompanion.insert(
                id: 'schedule-$id',
                missionId: id,
                revisionNumber: 1,
                scheduledDate: '2026-10-23',
                timeZone: 'Asia/Shanghai',
                plannedDurationMinutes: 20,
                changedAt: _time,
              ),
            );
      }
    });

    tearDown(() async => database.close());

    test('v12 新装十二表与索引符合当前定义', () async {
      expect(await _version(database), 13);
      expect(database.allTables, hasLength(12));
      await database.validateDatabaseSchema();
      expect(
        (await database.customSelect('PRAGMA foreign_keys').getSingle())
            .read<int>('foreign_keys'),
        1,
      );
    });

    test('事件编号全局唯一，序号仅在同一任务内唯一', () async {
      await _insertEvent(database, 'a1', 'mission-a', 1, 'PAUSE');
      await _insertEvent(database, 'b1', 'mission-b', 1, 'PAUSE');
      await expectLater(
        _insertEvent(database, 'a1', 'mission-a', 2, 'PAUSE'),
        throwsA(isA<SqliteException>()),
      );
      await expectLater(
        _insertEvent(database, 'a-duplicate', 'mission-a', 1, 'RESUME'),
        throwsA(isA<SqliteException>()),
      );
    });

    for (final type in ['START', 'END']) {
      test('$type 每个任务至多一条，PAUSE 可以多条', () async {
        final schedule = type == 'START' ? 'schedule-mission-a' : null;
        final report = type == 'END' ? 'COMPLETED' : null;
        await _insertEvent(
          database,
          'first',
          'mission-a',
          1,
          type,
          schedule: schedule,
          report: report,
        );
        await expectLater(
          _insertEvent(
            database,
            'duplicate',
            'mission-a',
            2,
            type,
            schedule: schedule,
            report: report,
          ),
          throwsA(isA<SqliteException>()),
        );
        await _insertEvent(
          database,
          'other',
          'mission-b',
          1,
          type,
          schedule: type == 'START' ? 'schedule-mission-b' : null,
          report: report,
        );
        // 此处只验证 SQL 部分索引；完整合法时间线由领域规则及后续写事务校验。
        await _insertEvent(database, 'pause-1', 'mission-a', 2, 'PAUSE');
        await _insertEvent(database, 'pause-2', 'mission-a', 3, 'PAUSE');
      });
    }

    test('任务与排期外键有效，已被引用的原始记录不能直接删除', () async {
      await expectLater(
        _insertEvent(database, 'bad-mission', 'missing', 1, 'PAUSE'),
        throwsA(isA<SqliteException>()),
      );
      await expectLater(
        _insertEvent(
          database,
          'bad-schedule',
          'mission-a',
          1,
          'START',
          schedule: 'missing',
        ),
        throwsA(isA<SqliteException>()),
      );
      await _insertEvent(
        database,
        'start',
        'mission-a',
        1,
        'START',
        schedule: 'schedule-mission-a',
      );
      await expectLater(
        database.customStatement(
          "DELETE FROM mission_schedule_revisions WHERE id = 'schedule-mission-a'",
        ),
        throwsA(isA<SqliteException>()),
      );
      await expectLater(
        database.customStatement("DELETE FROM missions WHERE id = 'mission-a'"),
        throwsA(isA<SqliteException>()),
      );
    });

    test('序号、分钟和枚举值有基本限制，条件字段允许 null', () async {
      await expectLater(
        _insertEvent(database, 'zero', 'mission-a', 0, 'PAUSE'),
        throwsA(isA<SqliteException>()),
      );
      await expectLater(
        _insertEvent(database, 'bad-type', 'mission-a', 1, 'UNKNOWN'),
        throwsA(isA<SqliteException>()),
      );
      await expectLater(
        _insertEvent(
          database,
          'bad-report',
          'mission-a',
          1,
          'END',
          report: 'UNKNOWN',
        ),
        throwsA(isA<SqliteException>()),
      );
      await expectLater(
        _insertEvent(
          database,
          'bad-minutes',
          'mission-a',
          1,
          'EXTEND',
          minutes: -5,
        ),
        throwsA(isA<SqliteException>()),
      );
      await _insertEvent(database, 'pause', 'mission-a', 1, 'PAUSE');
      final row = await database.select(database.executionEvents).getSingle();
      expect(row.grantedDurationMinutes, isNull);
      expect(row.userReportedResult, isNull);
      expect(row.submitOptionalEvidence, isNull);
    });

    test('可选材料选择 true、false、null 读回时严格区分', () async {
      for (final choice in [true, false, null]) {
        await database
            .into(database.executionEvents)
            .insert(
              ExecutionEventsCompanion.insert(
                id: 'choice-$choice',
                missionId: 'mission-a',
                sequence: choice == null ? 3 : (choice ? 1 : 2),
                type: 'PAUSE',
                occurredAt: _time,
                submitOptionalEvidence: Value(choice),
              ),
            );
      }
      // 仅测试存储映射，故意绕过业务入口。业务规则不会允许 PAUSE 带此选择。
      final rows = await (database.select(
        database.executionEvents,
      )..orderBy([(table) => OrderingTerm.asc(table.sequence)])).get();
      expect(
        [for (final row in rows) row.submitOptionalEvidence],
        [true, false, null],
      );
    });
  });
}

Future<void> _insertEvent(
  AppDatabase database,
  String id,
  String missionId,
  int sequence,
  String type, {
  String? schedule,
  String? report,
  int? minutes,
}) async {
  await database
      .into(database.executionEvents)
      .insert(
        ExecutionEventsCompanion.insert(
          id: id,
          missionId: missionId,
          sequence: sequence,
          type: type,
          occurredAt: _time,
          scheduleRevisionId: Value(schedule),
          userReportedResult: Value(report),
          grantedDurationMinutes: Value(minutes),
        ),
      );
}

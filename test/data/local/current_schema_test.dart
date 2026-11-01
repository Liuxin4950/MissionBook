import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:drift_dev/api/migrations_native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mission_book/data/local/app_database.dart';

const _time = 1792713600000;

Future<int> _version(GeneratedDatabase database) async {
  final row = await database.customSelect('PRAGMA user_version').getSingle();
  return row.read<int>('user_version');
}

void main() {
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

    test('当前版本新装十八表与索引符合当前定义', () async {
      expect(await _version(database), database.schemaVersion);
      expect(database.allTables, hasLength(18));
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

    test('任务与排期外键有效，已有执行事件时不能直接删除任务与排期', () async {
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

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:mission_book/data/assistant/drift_assistant_reader.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mission_book/application/goals/goal_package_import_service.dart';
import 'package:mission_book/data/goal_import/goal_import_database.dart';
import 'package:mission_book/data/local/app_database.dart';
import 'package:mission_book/data/repositories/drift_goal_package_repository.dart';
import 'package:mission_book/data/repositories/drift_mission_repository.dart';
import 'package:mission_book/domain/entities/goal_package_import.dart';
import 'package:mission_book/domain/entities/mission_phase.dart';

GoalImportSource course(int count, {String packageId = 'course-scale'}) {
  return GoalImportSource(
    name: 'course.json',
    openRead: () async* {
      final nodes = [
        for (var i = 0; i < 500; i++) {'key': 'node-$i', 'title': '知识点 $i'},
      ];
      final root = <String, Object?>{
        'schema': 'mission-book.goal-package',
        'version': 1,
        'packageId': packageId,
        'goal': {'title': '万级课程'},
        'defaults': {
          'timeZone': 'UTC',
          'plannedDurationMinutes': 45,
          'verificationPolicy': 'SELF_REPORT',
        },
        'nodes': nodes,
      };
      final buffer = BytesBuilder(copy: false);
      final prefix = jsonEncode(root);
      buffer.add(
        utf8.encode('${prefix.substring(0, prefix.length - 1)},"missions":['),
      );
      for (var i = 0; i < count; i++) {
        final at = DateTime.utc(2030, 1, 1).add(Duration(hours: i));
        final mission = {
          'key': 'lesson-$i',
          'nodeKey': 'node-${i % 500}',
          'title': '课次 $i',
          'schedule': {
            'scheduledDate': at.toIso8601String().substring(0, 10),
            'timePolicy': 'FIXED',
            'fixedStartAt': at.toIso8601String(),
          },
          'executionPlan': {
            'steps': ['读要求', '完成练习', '核对结果'],
            'notes': '真实导入链规模测试',
          },
        };
        buffer.add(utf8.encode((i == 0 ? '' : ',') + jsonEncode(mission)));
        if (buffer.length >= 32768) yield buffer.takeBytes();
      }
      buffer.add(utf8.encode(']}'));
      if (buffer.isNotEmpty) yield buffer.takeBytes();
    },
  );
}

Future<int> count(AppDatabase db, String table) async =>
    (await db.customSelect('SELECT COUNT(*) AS c FROM $table').getSingle())
        .read<int>('c');

void main() {
  test('文件双库完整一万任务：流读暂存、分页、单事务、候选查询、真实START与重开', () async {
    final dir = await Directory.systemTemp.createTemp(
      'missionbook-package-scale-',
    );
    final file = File('${dir.path}/business.sqlite');
    final stageFile = File('${dir.path}/stage.sqlite');
    var now = DateTime.utc(2029, 12, 31);
    AppDatabase? db;
    GoalImportDatabase? stage;
    try {
      db = AppDatabase(executor: NativeDatabase(file));
      stage = GoalImportDatabase(executor: NativeDatabase(stageFile));
      final service = GoalPackageImportService(
        stage: stage,
        repository: DriftGoalPackageRepository(db, clock: () => now),
      );
      final prepare = Stopwatch()..start();
      final preview = await service.prepare(course(10000));
      prepare.stop();
      expect(preview.missionCount, 10000);
      expect(preview.nodeCount, 500);
      expect(preview.totalMinutes, 450000);
      expect(await count(db, 'missions'), 0);
      final lastPage = await service.page(preview, 'MISSION', 9950);
      expect(lastPage.length, 50);
      expect(lastPage.last.sourceIndex, 9999);
      final commit = Stopwatch()..start();
      final result = await service.commit(preview, const GoalImportOptions());
      commit.stop();
      for (final table in [
        'missions',
        'execution_plans',
        'mission_schedule_revisions',
      ]) {
        expect(await count(db, table), 10000);
      }
      final assistantReader = DriftAssistantReader(db);
      final candidatePage = await assistantReader.missions(
        goalId: result.goalId,
      );
      expect(candidatePage['total'], 10000);
      expect(candidatePage['hasMore'], isTrue);
      expect(candidatePage['nextOffset'], 20);
      expect(candidatePage['items'] as List, hasLength(20));
      expect(jsonEncode(candidatePage).length, lessThan(18000));
      final nextPage = await assistantReader.missions(
        goalId: result.goalId,
        offset: 20,
      );
      final firstIds = (candidatePage['items'] as List)
          .map((row) => (row as Map)['id'])
          .toSet();
      expect(
        (nextPage['items'] as List).any(
          (row) => firstIds.contains((row as Map)['id']),
        ),
        isFalse,
      );
      final goalIndex = await assistantReader.goal(result.goalId);
      expect(goalIndex['missionCount'], 10000);
      expect(goalIndex.containsKey('missions'), isFalse);
      expect((goalIndex['nodes'] as Map)['items'] as List, hasLength(20));
      expect(jsonEncode(goalIndex).length, lessThan(18000));
      expect(await count(db, 'import_receipts'), 1);
      expect(await count(db, 'execution_events'), 0);
      expect(await db.customSelect('PRAGMA foreign_key_check').get(), isEmpty);
      final missions = DriftMissionRepository(db, clock: () => now);
      final read = Stopwatch()..start();
      final details = await missions.findForGoal(result.goalId);
      read.stop();
      expect(details.length, 10000);
      expect(details.first.executionPlan.steps.length, 3);
      final reminders = await missions.findReminderCandidates();
      expect(reminders.length, 64);
      expect((await missions.findPlannedSnapshot()).candidates.length, 1);
      expect(await missions.findCompletedGoalNodeIds(result.goalId), isEmpty);
      now = DateTime.utc(2030, 1, 1, 0, 3);
      final started = await missions.startDueScheduledMissions();
      expect(started.length, 1);
      final running = (await missions.findDetail(started.single))!;
      expect(running.phase, MissionPhase.running);
      expect(running.events.single.occurredAt, now);
      expect(await count(db, 'execution_events'), 1);
      expect(await missions.startDueScheduledMissions(), isEmpty);
      await db.close();
      db = AppDatabase(executor: NativeDatabase(file));
      expect(await count(db, 'missions'), 10000);
      expect(await count(db, 'import_receipts'), 1);
      expect(await count(db, 'execution_events'), 1);
      expect(await db.customSelect('PRAGMA foreign_key_check').get(), isEmpty);
      // Test output records reproducible scale measurements.
      // ignore: avoid_print
      print(
        'PACKAGE_SCALE ${jsonEncode({'missions': 10000, 'nodes': 500, 'prepareMs': prepare.elapsedMilliseconds, 'commitMs': commit.elapsedMilliseconds, 'goalReadMs': read.elapsedMilliseconds, 'reminderCandidates': reminders.length, 'reopen': 'passed'})}',
      );
    } finally {
      await stage?.close();
      await db?.close();
      await dir.delete(recursive: true);
    }
  }, timeout: const Timeout(Duration(minutes: 3)));

  test('10001任务在正式写入前拒绝，暂存失败可恢复为空', () async {
    final db = AppDatabase(executor: NativeDatabase.memory());
    final stage = GoalImportDatabase(executor: NativeDatabase.memory());
    try {
      final service = GoalPackageImportService(
        stage: stage,
        repository: DriftGoalPackageRepository(db),
      );
      await expectLater(
        service.prepare(course(10001)),
        throwsA(isA<GoalImportException>()),
      );
      expect(await count(db, 'goals'), 0);
      expect(await stage.pending(), isNull);
    } finally {
      await stage.close();
      await db.close();
    }
  }, timeout: const Timeout(Duration(minutes: 2)));
}

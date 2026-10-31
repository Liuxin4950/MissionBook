import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mission_book/application/goals/goal_package_import_service.dart';
import 'package:mission_book/data/goal_import/goal_import_database.dart';
import 'package:mission_book/data/local/app_database.dart';
import 'package:mission_book/data/repositories/drift_goal_package_repository.dart';
import 'package:mission_book/domain/entities/goal_package_import.dart';

Future<String> sample() => File(
  'docs/历史文档/设计/目标计划导入/examples/课标试运行.goal-package.v1.json',
).readAsString();

void main() {
  late AppDatabase db;
  late GoalImportDatabase stage;
  late GoalPackageImportService service;
  final clock = DateTime.utc(2026, 10, 27, 4);
  setUp(() {
    db = AppDatabase(executor: NativeDatabase.memory());
    stage = GoalImportDatabase(executor: NativeDatabase.memory());
    service = GoalPackageImportService(
      stage: stage,
      repository: DriftGoalPackageRepository(db, clock: () => clock),
    );
  });
  tearDown(() async {
    await stage.close();
    await db.close();
  });

  test('完整目标包预览零写入，提交完整三件套、默认截止及稳定回执', () async {
    final input = await sample();
    final preview = await service.prepare(GoalImportSource.text(input));
    expect(preview.nodeCount, 6);
    expect(preview.missionCount, 5);
    expect(preview.totalMinutes, 255);
    expect(await db.select(db.missions).get(), isEmpty);
    final page = await service.page(preview, 'MISSION', 0);
    expect(page[3].resolved!['evidenceDeadlineAt'], '2026-11-05T16:00:00.000Z');
    await service.review(preview, const GoalImportOptions());
    final result = await service.commit(preview, const GoalImportOptions());
    expect(await db.select(db.goals).get(), hasLength(1));
    expect(await db.select(db.goalNodes).get(), hasLength(6));
    expect(await db.select(db.missions).get(), hasLength(5));
    expect(await db.select(db.executionPlans).get(), hasLength(5));
    expect(await db.select(db.missionScheduleRevisions).get(), hasLength(5));
    expect(await db.select(db.executionEvents).get(), isEmpty);
    expect(await db.select(db.importReceipts).get(), hasLength(1));
    expect(await db.customSelect('PRAGMA foreign_key_check').get(), isEmpty);
    final again = await service.prepare(GoalImportSource.text(input));
    expect(again.existingGoalId, result.goalId);
    final repeated = await service.commit(again, const GoalImportOptions());
    expect(repeated.alreadyImported, isTrue);
    expect(repeated.goalId, result.goalId);
    expect(await db.select(db.goals).get(), hasLength(1));
  });

  test('字段顺序和空白不改变 JCS，节点 children 省略与空数组仍保留区别', () async {
    final original = jsonDecode(await sample()) as Map<String, dynamic>;
    final preview = await service.prepare(
      GoalImportSource.text(jsonEncode(original)),
    );
    final hash = preview.payloadHash;
    await service.discard();
    final reordered = <String, dynamic>{
      for (final key in original.keys.toList().reversed) key: original[key],
    };
    final second = await service.prepare(
      GoalImportSource.text(
        const JsonEncoder.withIndent('  ').convert(reordered),
      ),
    );
    expect(second.payloadHash, hash);
  });

  test('重复原始字段、悬空归属、非法日期和无效文本整包拒绝且可重试', () async {
    final original = await sample();
    final invalid = <String>[
      original.replaceFirst('"version": 1', '"version": 1, "version": 1'),
      original.replaceFirst('"nodeKey": "dart-values"', '"nodeKey": "missing"'),
      original.replaceFirst(
        '"scheduledDate": "2026-11-02"',
        '"scheduledDate": "2026-02-30"',
      ),
      original.replaceFirst('"version": 1', '"version": 1.0'),
      original.replaceFirst(
        '"timePolicy": "FLEXIBLE"',
        '"timePolicy": "FLEXIBLE", "fixedStartAt": "2026-11-03T12:00:00Z"',
      ),
    ];
    for (final text in invalid) {
      await expectLater(
        service.prepare(GoalImportSource.text(text)),
        throwsA(isA<GoalImportException>()),
      );
      expect(await stage.pending(), isNull);
      expect(await db.select(db.goals).get(), isEmpty);
    }
    expect(
      (await service.prepare(GoalImportSource.text(original))).missionCount,
      5,
    );
  });

  test('任务写入中途失败回滚整包，保留同一预览可重试', () async {
    final preview = await service.prepare(
      GoalImportSource.text(await sample()),
    );
    await db.customStatement('''
CREATE TRIGGER research_import_fail BEFORE INSERT ON execution_plans
BEGIN SELECT RAISE(ABORT, 'research import failure'); END
''');
    await expectLater(
      service.commit(preview, const GoalImportOptions()),
      throwsA(isA<Exception>()),
    );
    expect(await db.select(db.goals).get(), isEmpty);
    expect(await db.select(db.goalNodes).get(), isEmpty);
    expect(await db.select(db.missions).get(), isEmpty);
    expect(await db.select(db.importReceipts).get(), isEmpty);
    expect((await service.recover())!.payloadHash, preview.payloadHash);
    await db.customStatement('DROP TRIGGER research_import_fail');
    await service.commit(preview, const GoalImportOptions());
    expect(await db.select(db.missions).get(), hasLength(5));
  });

  test('旧大纲仍创建目标和节点，不生成任务', () async {
    final text = await File(
      'docs/历史文档/设计/目标计划导入/examples/仅大纲.goal-outline.v1.json',
    ).readAsString();
    final preview = await service.prepare(GoalImportSource.text(text));
    expect(preview.isOutline, isTrue);
    final result = await service.commit(preview, const GoalImportOptions());
    expect(result.nodeCount, 6);
    expect(await db.select(db.missions).get(), isEmpty);
  });
}

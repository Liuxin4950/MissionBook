import 'dart:convert';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mission_book/data/backup/database_backup_service.dart';
import 'package:mission_book/application/goals/goal_service.dart';
import 'package:mission_book/application/missions/mission_service.dart';
import 'package:mission_book/data/local/app_database.dart';
import 'package:mission_book/data/repositories/drift_goal_repository.dart';
import 'package:mission_book/data/repositories/drift_mission_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AppDatabase db;
  late MissionService missions;
  late GoalService goals;
  late String imageKey;

  setUp(() async {
    db = AppDatabase(executor: NativeDatabase.memory());
    missions = MissionService(DriftMissionRepository(db));
    goals = GoalService(DriftGoalRepository(db));
    final goal = goals.prepareCreation(
      title: "目标 ' 引号与中文",
      description: '多行\n说明',
    );
    await goals.create(goal);
    await missions.create(
      title: '备份任务',
      scheduledDate: '2026-10-25',
      timeZone: 'Asia/Shanghai',
      plannedDurationMinutes: 20,
    );
    final mission = (await db.select(db.missions).get()).single;
    imageKey = 'attachments/${mission.id}/proof.png';
    await db.customStatement(
      'INSERT INTO evidence_records (id,mission_id,submission_id,type,source,attachment_storage_key,attachment_file_name,submitted_at) VALUES (?,?,?,?,?,?,?,?)',
      [
        'image',
        mission.id,
        'batch',
        'IMAGE',
        'FILE_SYSTEM',
        imageKey,
        '证明.png',
        1,
      ],
    );
    await db.customStatement(
      'INSERT INTO evidence_records (id,mission_id,submission_id,type,source,content,submitted_at) VALUES (?,?,?,?,?,?,?)',
      ['text', mission.id, 'batch', 'TEXT', 'USER', "正文 ' \n\u0000 完整保留", 1],
    );
  });
  tearDown(() async {
    await missions.dispose();
    await goals.dispose();
    await db.close();
  });

  test('备份可重建完整数据库、约束与版本，且只包含正式引用的附件', () async {
    final original = Uint8List.fromList([1, 2, 3, 4]);
    final backup = DatabaseBackupService(
      database: db,
      readAttachment: (key) async {
        expect(key, imageKey);
        return original;
      },
    );
    final zip = ZipDecoder().decodeBytes(await backup.create(), verify: true);
    expect(zip.files.map((file) => file.name).toSet(), {
      'database.sql',
      'manifest.json',
      'README.txt',
      imageKey,
    });
    expect(zip.findFile(imageKey)!.content, original);
    final manifest =
        jsonDecode(
              utf8.decode(zip.findFile('manifest.json')!.content as List<int>),
            )
            as Map;
    expect(manifest['databaseVersion'], 9);
    final sql = utf8.decode(zip.findFile('database.sql')!.content as List<int>);
    final restored = AppDatabase(
      executor: NativeDatabase.memory(setup: (raw) => raw.execute(sql)),
    );
    try {
      for (final table in db.allTables) {
        final before = await db
            .customSelect('SELECT * FROM "${table.actualTableName}"')
            .get();
        final after = await restored
            .customSelect('SELECT * FROM "${table.actualTableName}"')
            .get();
        expect(
          after.map((row) => row.data),
          before.map((row) => row.data),
          reason: table.actualTableName,
        );
      }
      expect(
        await restored.customSelect('PRAGMA foreign_key_check').get(),
        isEmpty,
      );
      expect(
        (await restored.customSelect('PRAGMA user_version').get())
            .single
            .data
            .values
            .single,
        8,
      );
      final sourceSchema = await db
          .customSelect(
            "SELECT name,sql FROM sqlite_master WHERE sql IS NOT NULL ORDER BY name",
          )
          .get();
      final targetSchema = await restored
          .customSelect(
            "SELECT name,sql FROM sqlite_master WHERE sql IS NOT NULL ORDER BY name",
          )
          .get();
      expect(targetSchema.map((r) => r.data), sourceSchema.map((r) => r.data));
    } finally {
      await restored.close();
    }
  });

  test('缺失正式附件时失败，不修改源数据库', () async {
    final backup = DatabaseBackupService(
      database: db,
      readAttachment: (_) async => throw StateError('附件缺失'),
    );
    await expectLater(backup.create(), throwsStateError);
    expect(await db.select(db.evidenceRecords).get(), hasLength(2));
    expect(await db.select(db.missions).get(), hasLength(1));
  });
}

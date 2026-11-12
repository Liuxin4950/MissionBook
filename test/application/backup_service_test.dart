import 'dart:convert';
import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mission_book/data/backup/database_backup_service.dart';
import 'package:mission_book/application/backup/backup_service.dart';
import 'package:mission_book/data/backup/backup_archive.dart';
import 'package:mission_book/data/backup/local_resources_base.dart';
import '../support/local_resources_fake.dart';
import 'package:mission_book/application/goals/goal_service.dart';
import 'package:mission_book/application/missions/mission_service.dart';
import 'package:mission_book/application/attachments/attachment_coordinator.dart';
import 'package:mission_book/data/local/app_database.dart';
import 'package:mission_book/data/assistant/drift_session_store.dart';
import 'package:mission_book/data/repositories/drift_goal_repository.dart';
import 'package:mission_book/data/repositories/drift_mission_repository.dart';
import 'package:mission_book/domain/entities/mission_maintenance.dart';
import 'package:mission_book/domain/entities/user_execution_report.dart';
import 'package:mission_book/domain/entities/execution_event.dart';

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
    final handle = await DriftSessionStore(db).create('backup-conversation');
    await handle.append('session_created', {
      'id': 'backup-conversation',
      'title': '备份会话',
    });
    await handle.append('message_added', {
      'text': '中文与换行\n保留',
      'attachments': ['已发送的附件'],
    });
    await handle.close();
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
      'assistant-conversations.json',
      imageKey,
    });
    expect(zip.findFile(imageKey)!.content, original);
    final conversations =
        jsonDecode(
              utf8.decode(
                zip.findFile('assistant-conversations.json')!.content
                    as List<int>,
              ),
            )
            as Map;
    final conversation = (conversations['conversations'] as List).single as Map;
    expect(conversation['title'], '备份会话');
    expect(conversation.containsKey('writerToken'), isFalse);
    final records = conversation['records'] as List;
    expect(records.map((e) => e['sequence']), [0, 1]);
    expect(records.last['data']['text'], '中文与换行\n保留');
    expect(records.last['data']['attachments'], ['已发送的附件']);

    final manifest =
        jsonDecode(
              utf8.decode(zip.findFile('manifest.json')!.content as List<int>),
            )
            as Map;
    expect(manifest['databaseVersion'], db.schemaVersion);
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
      // 还原库的 user_version 应与当前 schemaVersion 一致；
      // 备份 SQL 末尾写入的就是它（见 database_backup_service）。
      expect(
        (await restored.customSelect('PRAGMA user_version').get())
            .single
            .data
            .values
            .single,
        db.schemaVersion,
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

  test('慢附件读取期间其他连接可以写入，归档仍保留捕获时的数据库快照', () async {
    final directory = await Directory.systemTemp.createTemp('backup-lock-');
    final file = File('${directory.path}/database.sqlite');
    final source = AppDatabase(executor: NativeDatabase(file));
    final service = MissionService(DriftMissionRepository(source));
    final entered = Completer<void>();
    final release = Completer<void>();
    AppDatabase? writer;
    try {
      await service.create(
        title: '捕获时名称',
        scheduledDate: '2026-11-11',
        timeZone: 'Asia/Shanghai',
        plannedDurationMinutes: 30,
      );
      final id = (await service.findAllDetails()).single.mission.id;
      await source.customStatement(
        'INSERT INTO evidence_records (id,mission_id,submission_id,type,source,attachment_storage_key,attachment_file_name,submitted_at) VALUES (?,?,?,?,?,?,?,?)',
        [
          'proof',
          id,
          'batch',
          'IMAGE',
          'FILE_SYSTEM',
          'attachments/$id/proof.png',
          'proof.png',
          1,
        ],
      );
      writer = AppDatabase(executor: NativeDatabase(file));
      await writer.customSelect('SELECT 1').get();
      await writer.customStatement('PRAGMA busy_timeout=100');
      final backup = DatabaseBackupService(
        database: source,
        readAttachment: (_) async {
          entered.complete();
          await release.future;
          return Uint8List.fromList([1, 2, 3]);
        },
      ).create();
      await entered.future;
      await writer.customStatement('UPDATE missions SET title=? WHERE id=?', [
        '捕获后修改',
        id,
      ]);
      release.complete();
      final archive = ZipDecoder().decodeBytes(await backup, verify: true);
      final sql = utf8.decode(
        archive.findFile('database.sql')!.content as List<int>,
      );
      final restored = AppDatabase(
        executor: NativeDatabase.memory(setup: (db) => db.execute(sql)),
      );
      try {
        expect(
          (await restored.select(restored.missions).get()).single.title,
          '捕获时名称',
        );
        expect((await service.findAllDetails()).single.mission.title, '捕获后修改');
      } finally {
        await restored.close();
      }
    } finally {
      if (!release.isCompleted) release.complete();
      await writer?.close();
      await service.dispose();
      await source.close();
      await directory.delete(recursive: true);
    }
  });

  test('撤销后仅由执行归档引用的原图仍随完整备份导出并可还原', () async {
    final detail = (await missions.findAllDetails()).single;
    final repository = DriftMissionRepository(db);
    await repository.reportExecution(
      UserExecutionReport(
        id: 'report-archive',
        missionId: detail.mission.id,
        occurrenceDate: '2026-10-25',
        timeZoneId: 'Asia/Shanghai',
        basis: '误标已完成',
      ),
      expectedSequence: detail.lastSequence,
      scheduleId: detail.schedule.id,
      result: UserReportedResult.completed,
    );
    final proposal = await missions.prepareMaintenance(
      action: MissionMaintenanceAction.reset,
      ids: [detail.mission.id],
    );
    await missions.applyMaintenance(proposal);
    expect(await db.select(db.evidenceRecords).get(), isEmpty);
    expect(await db.select(db.records).get(), isEmpty);
    final zip = ZipDecoder().decodeBytes(
      await DatabaseBackupService(
        database: db,
        readAttachment: (key) async {
          expect(key, imageKey);
          return Uint8List.fromList([7, 8, 9]);
        },
      ).create(),
    );
    expect(zip.findFile(imageKey)!.content, [7, 8, 9]);
    final sql = utf8.decode(zip.findFile('database.sql')!.content as List<int>);
    final restored = AppDatabase(
      executor: NativeDatabase.memory(setup: (raw) => raw.execute(sql)),
    );
    try {
      final keys = await DriftMissionRepository(
        restored,
      ).referencedAttachmentKeys();
      expect(keys, {imageKey});
      expect(
        await DriftMissionRepository(
          restored,
        ).executionArchives(detail.mission.id),
        hasLength(1),
      );
      expect(
        await restored.customSelect('PRAGMA foreign_key_check').get(),
        isEmpty,
      );
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

  test('导出持有共享附件互斥直到原件读取结束，清理不会抢先删除文件', () async {
    final attachments = AttachmentCoordinator(
      referencedKeys: () async => {imageKey},
    );
    final entered = Completer<void>();
    final release = Completer<void>();
    final backup = DatabaseBackupService(
      database: db,
      attachments: attachments,
      readAttachment: (_) async {
        entered.complete();
        await release.future;
        return Uint8List.fromList([1]);
      },
    ).create();
    await entered.future;
    var cleaned = false;
    final cleanup = attachments.synchronized(() async {
      cleaned = true;
    });
    await Future<void>.delayed(Duration.zero);
    expect(cleaned, isFalse);
    release.complete();
    await backup;
    await cleanup;
    expect(cleaned, isTrue);
  });

  test('导出按勾选携带本机资源，清单如实记录且默认不含模型', () async {
    final resources = FakeLocalResources();
    final backup = DatabaseBackupService(
      database: db,
      readAttachment: (key) async => Uint8List.fromList([1]),
      localResources: resources,
    );
    final zip = ZipDecoder().decodeBytes(await backup.create(), verify: true);
    final names = zip.files.map((file) => file.name).toSet();
    expect(resources.requested, defaultBackupResources);
    expect(names, contains(localResourcesEntry));
    expect(names.where((name) => name.startsWith(speechEntryPrefix)), isEmpty);
    final manifest =
        jsonDecode(
              utf8.decode(zip.findFile('manifest.json')!.content as List<int>),
            )
            as Map;
    expect(manifest['resources'], ['assistantSettings', 'localPreferences']);
    final local =
        jsonDecode(
              utf8.decode(
                zip.findFile(localResourcesEntry)!.content as List<int>,
              ),
            )
            as Map;
    expect(
      (local['assistantSettings'] as Map)['assistant_credential_DEEPSEEK_API_KEY'],
      'sk-测试密钥',
    );
    expect(local['localProfile'], '{"name":"本机资料"}');
  });

  test('全不勾选时不写本机资源，勾选模型才带模型原件', () async {
    final resources = FakeLocalResources();
    final backup = DatabaseBackupService(
      database: db,
      readAttachment: (key) async => Uint8List.fromList([1]),
      localResources: resources,
    );
    final bare = ZipDecoder().decodeBytes(
      await backup.create(resources: const {}),
      verify: true,
    );
    expect(bare.files.map((file) => file.name), isNot(contains(localResourcesEntry)));
    expect(
      (jsonDecode(utf8.decode(bare.findFile('manifest.json')!.content as List<int>))
          as Map)['resources'],
      isEmpty,
    );

    final full = ZipDecoder().decodeBytes(
      await backup.create(resources: BackupResource.values.toSet()),
      verify: true,
    );
    expect(
      full.findFile('${speechEntryPrefix}model.int8.onnx')!.content,
      resources.model,
    );
    final decoded = decodeBackupArchive(
      Uint8List.fromList(ZipEncoder().encode(full)),
    );
    expect((decoded['resourceKinds'] as List).toSet(), BackupResource.values.toSet());
  });
}

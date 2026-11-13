import 'dart:convert';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mission_book/application/attachments/attachment_coordinator.dart';
import 'package:mission_book/application/attachments/attachment_file_service.dart';
import 'package:mission_book/application/missions/mission_service.dart';
import 'package:mission_book/data/backup/database_backup_restorer.dart';
import 'package:mission_book/data/backup/database_backup_service.dart';
import 'package:mission_book/application/backup/backup_service.dart';
import 'package:mission_book/data/backup/local_resources_base.dart';
import 'package:mission_book/data/backup/backup_archive.dart';
import '../support/local_resources_fake.dart';
import 'package:mission_book/data/local/app_database.dart';
import 'package:mission_book/data/repositories/drift_mission_repository.dart';
import 'package:mission_book/data/repositories/drift_record_repository.dart';
import 'package:mission_book/data/assistant/drift_session_store.dart';
import 'package:mission_book/domain/entities/record_draft.dart';
import 'package:mission_book/domain/entities/mission_maintenance.dart';
import 'package:mission_book/domain/entities/execution_event.dart';
import 'package:mission_book/domain/entities/user_execution_report.dart';

class _WriteFailureDatabase extends AppDatabase {
  _WriteFailureDatabase() : super(executor: NativeDatabase.memory());

  bool failReplacement = false;
  int? missionsAtFailure;
  int? triggersAtFailure;

  @override
  Future<void> customStatement(String statement, [List<Object?>? args]) async {
    await super.customStatement(statement, args);
    if (failReplacement && statement.startsWith('INSERT INTO "missions"')) {
      failReplacement = false;
      missionsAtFailure = (await customSelect(
        'SELECT COUNT(*) n FROM missions',
      ).getSingle()).read<int>('n');
      triggersAtFailure = (await customSelect(
        "SELECT COUNT(*) n FROM sqlite_master WHERE type='trigger'",
      ).getSingle()).read<int>('n');
      throw StateError('injected failure after restore row insert');
    }
  }
}

class RestoreFiles implements AttachmentStore {
  final values = <String, Uint8List>{};
  final written = <String>[];
  final deleted = <String>[];
  bool failWrite = false;
  @override
  Future<void> writeNew(String key, Uint8List bytes) async {
    if (failWrite) throw StateError('模拟磁盘写入失败');
    if (values.containsKey(key)) throw StateError('重复文件');
    values[key] = Uint8List.fromList(bytes);
    written.add(key);
  }

  @override
  Future<Uint8List> read(String key) async =>
      values[key] ?? (throw StateError('缺少附件'));
  @override
  Future<void> delete(String key) async {
    values.remove(key);
    deleted.add(key);
  }

  @override
  Future<Set<String>> listKeys() async => values.keys.toSet();
}

class _Picker implements ImageAttachmentPicker {
  @override
  Future<SelectedAttachment?> pick() async => null;
}

/// 把中央目录中指定条目伪装成 UNIX 符号链接（S_IFLNK | 0777，创建者版本 3）。
Uint8List _asSymlink(Uint8List source, String name) {
  final bytes = Uint8List.fromList(source);
  final data = ByteData.sublistView(bytes);
  for (var i = 0; i + 46 <= bytes.length; i++) {
    if (data.getUint32(i, Endian.little) != 0x02014b50) continue;
    final length = data.getUint16(i + 28, Endian.little);
    if (i + 46 + length > bytes.length) continue;
    if (utf8.decode(bytes.sublist(i + 46, i + 46 + length)) != name) continue;
    data.setUint16(i + 4, 0x031e, Endian.little);
    data.setUint32(i + 38, 0xa1ff0000, Endian.little);
    return bytes;
  }
  throw StateError('备份中找不到条目 $name');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AppDatabase source, target;
  late MissionService sourceMissions, targetMissions;
  late RestoreFiles sourceFiles, targetFiles;
  late DatabaseBackupRestorer importer;
  late Uint8List zip;
  late String missionId;
  final now = DateTime.utc(2026, 11, 3, 5);
  const originalKey = 'attachments/origin/photo.png';
  final imageBytes = Uint8List.fromList(
    base64Decode(
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+jO1sAAAAASUVORK5CYII=',
    ),
  );

  MissionService service(AppDatabase db, RestoreFiles files) {
    final repo = DriftMissionRepository(db, clock: () => now);
    return MissionService(
      repo,
      clock: () => now,
      attachments: AttachmentCoordinator(
        referencedKeys: repo.referencedAttachmentKeys,
        files: AttachmentFileService(store: files, picker: _Picker()),
      ),
    );
  }

  setUp(() async {
    source = AppDatabase(executor: NativeDatabase.memory());
    target = _WriteFailureDatabase();
    sourceFiles = RestoreFiles();
    targetFiles = RestoreFiles();
    sourceMissions = service(source, sourceFiles);
    targetMissions = service(target, targetFiles);
    for (var i = 0; i < 2; i++) {
      await sourceMissions.create(
        title: '备份任务',
        scheduledDate: '2026-11-02',
        timeZone: 'Asia/Shanghai',
        plannedDurationMinutes: 20,
      );
    }
    missionId = (await sourceMissions.findAllDetails()).first.mission.id;
    await sourceFiles.writeNew(originalKey, imageBytes);
    final records = DriftRecordRepository(
      source,
      materials: DriftMissionRepository(source),
    );
    await records.saveRecord(
      const RecordDraft(
        id: 'photo',
        type: ContentType.image,
        source: ContentSource.fileSystem,
        attachmentStorageKey: originalKey,
        attachmentFileName: '原图.png',
      ),
      missionId: missionId,
    );
    final detail = (await sourceMissions.findDetail(missionId: missionId))!;
    await DriftMissionRepository(source, clock: () => now).reportExecution(
      UserExecutionReport(
        id: 'report',
        missionId: missionId,
        occurrenceDate: '2026-11-02',
        timeZoneId: 'Asia/Shanghai',
        basis: '误标已完成',
      ),
      expectedSequence: detail.lastSequence,
      scheduleId: detail.schedule.id,
      result: UserReportedResult.completed,
    );
    await sourceMissions.applyMaintenance(
      await sourceMissions.prepareMaintenance(
        action: MissionMaintenanceAction.reset,
        ids: [missionId],
      ),
    );
    await records.deleteRecord('photo');
    await records.saveRecord(
      const RecordDraft(
        id: 'note',
        type: ContentType.text,
        source: ContentSource.user,
        content: '完整文字\n含引号与逗号，; 和 emoji 📘',
      ),
    );
    await source
        .into(source.appSettings)
        .insert(
          AppSettingsCompanion.insert(
            key: 'memory.extraction.enabled',
            value: '0',
            updatedAt: now.millisecondsSinceEpoch,
          ),
        );
    await source.customStatement(
      'INSERT INTO memory_items(id,layer,topic_id,content,certainty,importance,'
      'created_at,updated_at,expires_at,forgotten,user_edited,source_kind,'
      'source_ref,goal_id) VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?)',
      [
        'memory',
        'semantic',
        null,
        '喜欢先理解调用链',
        'stated',
        60,
        now.millisecondsSinceEpoch,
        now.millisecondsSinceEpoch,
        null,
        0,
        1,
        'user',
        null,
        null,
      ],
    );
    final session = await DriftSessionStore(source).create('conversation');
    await session.append('session_created', {
      'id': 'conversation',
      'title': '原会话',
    });
    await session.append('message_added', {'id': 'message', 'text': '原始聊天记录'});
    await source
        .into(source.goals)
        .insert(
          GoalsCompanion.insert(
            id: 'goal',
            title: '导入目标',
            createdAt: now.millisecondsSinceEpoch,
            updatedAt: now.millisecondsSinceEpoch,
          ),
        );
    await source
        .into(source.importReceipts)
        .insert(
          ImportReceiptsCompanion.insert(
            schemaName: 'goal-package',
            packageId: 'package',
            schemaVersion: 1,
            payloadSha256: 'payload-hash',
            contentSha256: 'content-hash',
            goalId: 'goal',
            importedAt: now.millisecondsSinceEpoch,
            nodeCount: 0,
            missionCount: 0,
          ),
        );
    zip = await DatabaseBackupService(
      database: source,
      readAttachment: sourceFiles.read,
    ).create();
    await session.close();
    await targetMissions.create(
      title: '当前旧任务',
      scheduledDate: '2026-11-03',
      timeZone: 'Asia/Shanghai',
      plannedDurationMinutes: 10,
    );
    await targetFiles.writeNew(originalKey, Uint8List.fromList([9, 9]));
    importer = DatabaseBackupRestorer(
      database: target,
      files: targetFiles,
      attachments: targetMissions.attachments,
    );
  });
  tearDown(() async {
    await sourceMissions.dispose();
    await targetMissions.dispose();
    await source.close();
    await target.close();
  });

  test('旧版ZIP预览不写目标；完整恢复任务、独立记录、归档图片、记忆与会话', () async {
    final plan = await importer.prepareRestore(zip);
    expect(plan.counts['missions'], 2);
    expect(plan.currentCounts['missions'], 1);
    expect(plan.attachmentCount, 1);
    expect(
      (await targetMissions.findAllDetails()).single.mission.title,
      '当前旧任务',
    );
    await importer.restore(plan);
    expect(await targetMissions.findAllDetails(), hasLength(2));
    // 当前回执列名带数字，不能被 SQL 列名校验误拒绝。
    final receipt = (await target.select(target.importReceipts).get()).single;
    expect(receipt.payloadSha256, 'payload-hash');
    expect(receipt.contentSha256, 'content-hash');
    expect(
      (await target.select(target.records).get()).single.content,
      '完整文字\n含引号与逗号，; 和 emoji 📘',
    );
    final restoredMemory =
        (await target.select(target.memoryItems).get()).single;
    expect(restoredMemory.content, '喜欢先理解调用链');
    expect(restoredMemory.layer, 'semantic');
    expect(restoredMemory.sourceKind, 'user');
    expect(restoredMemory.importance, 60);
    expect(restoredMemory.userEdited, true);
    expect(restoredMemory.forgotten, false);
    expect((await target.select(target.appSettings).get()).single.value, '0');
    final session =
        (await target.select(target.assistantSessions).get()).single;
    expect(session.writerToken, isNull);
    expect(session.writerLeaseUntil, isNull);
    final handle = await DriftSessionStore(target).open('conversation');
    expect((await handle.readRecords()).last.data['text'], '原始聊天记录');
    await handle.close();
    final references = await DriftMissionRepository(
      target,
    ).referencedAttachmentKeys();
    expect(references, hasLength(1));
    expect(references.single, isNot(originalKey));
    expect(await targetFiles.read(references.single), imageBytes);
    expect(await targetFiles.read(originalKey), [9, 9]);
    expect(
      await DriftMissionRepository(target).executionArchives(missionId),
      hasLength(1),
    );
    expect(
      await target.customSelect('PRAGMA foreign_key_check').get(),
      isEmpty,
    );
    final triggers = await target
        .customSelect("SELECT name FROM sqlite_master WHERE type='trigger'")
        .get();
    expect(triggers, isNotEmpty);
    await expectLater(importer.restore(plan), throwsStateError);
    await targetMissions.attachments.initialize();
    expect(targetFiles.values.keys.toSet(), references);
  });

  test('校验后目标变化整批拒绝，新附件回收，保留当前数据', () async {
    final plan = await importer.prepareRestore(zip);
    await targetMissions.create(
      title: '校验后新增',
      scheduledDate: '2026-11-03',
      timeZone: 'Asia/Shanghai',
      plannedDurationMinutes: 10,
    );
    await expectLater(importer.restore(plan), throwsStateError);
    expect(await targetMissions.findAllDetails(), hasLength(2));
    expect(targetFiles.values.keys, {originalKey});
  });
  test('附件写入失败不会替换当前数据库', () async {
    final plan = await importer.prepareRestore(zip);
    targetFiles.failWrite = true;
    await expectLater(importer.restore(plan), throwsStateError);
    expect(
      (await targetMissions.findAllDetails()).single.mission.title,
      '当前旧任务',
    );
    expect(targetFiles.values.keys, {originalKey});
  });
  test('写入阶段失败回滚全部行和当前触发器，并清理新附件，可重试同一计划', () async {
    Future<Map<String, List<String>>> snapshot() async => {
      for (final table in target.allTables)
        table.actualTableName:
            (await target
                    .customSelect('SELECT * FROM "${table.actualTableName}"')
                    .get())
                .map((row) => jsonEncode(row.data))
                .toList()
              ..sort(),
    };
    Future<List<Map<String, Object?>>> triggers() async => [
      for (final row
          in await target
              .customSelect(
                "SELECT name,sql FROM sqlite_master WHERE type='trigger' ORDER BY name",
              )
              .get())
        row.data,
    ];

    final plan = await importer.prepareRestore(zip);
    // Include a device-local trigger after schema validation, so rollback must
    // retain the actual current DDL rather than regenerate standard triggers.
    await target.customStatement('''
      CREATE TRIGGER restore_local_guard BEFORE UPDATE OF title ON missions
      WHEN NEW.title='blocked after rollback'
      BEGIN SELECT RAISE(ABORT, 'local guard retained'); END
    ''');
    final beforeRows = await snapshot();
    final beforeTriggers = await triggers();
    final beforeReferences = await DriftMissionRepository(
      target,
    ).referencedAttachmentKeys();
    final beforeFiles = {
      for (final entry in targetFiles.values.entries)
        entry.key: Uint8List.fromList(entry.value),
    };
    final database = target as _WriteFailureDatabase;
    database.failReplacement = true;

    await expectLater(
      importer.restore(plan),
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          'injected failure after restore row insert',
        ),
      ),
    );
    // Failure occurred after all deletes and a real replacement INSERT,
    // while replaceAllRows had temporarily removed every current trigger.
    expect(database.missionsAtFailure, 1);
    expect(database.triggersAtFailure, 0);
    expect(await snapshot(), beforeRows);
    expect(await triggers(), beforeTriggers);
    expect(
      await target.customSelect('PRAGMA foreign_key_check').get(),
      isEmpty,
    );
    expect(
      await DriftMissionRepository(target).referencedAttachmentKeys(),
      beforeReferences,
    );
    final newKeys = targetFiles.written.where(
      (key) => !beforeFiles.containsKey(key),
    );
    expect(newKeys, hasLength(plan.attachmentCount));
    expect(newKeys, isNotEmpty);
    expect(targetFiles.deleted, containsAll(newKeys));
    expect(targetFiles.values, beforeFiles);

    await expectLater(
      target.customStatement(
        "UPDATE missions SET title='blocked after rollback'",
      ),
      throwsA(anything),
    );
    expect(await snapshot(), beforeRows);
    // The failed plan remains usable, and the synchronization queue is released.
    await importer.restore(plan);
    expect(await targetMissions.findAllDetails(), hasLength(2));
    expect(await triggers(), beforeTriggers);
  });

  Uint8List modifyZip({
    String? remove,
    (String, String)? addFile,
    String Function(String)? databaseText,
    void Function(Map<String, dynamic>)? database,
    void Function(Map<String, Object?>)? manifest,
  }) {
    final original = ZipDecoder().decodeBytes(zip);
    final changed = Archive();
    for (final file in original) {
      if (file.name == remove) continue;
      var content = Uint8List.fromList(file.content as List<int>);
      if (file.name == backupDatabaseEntry) {
        if (databaseText != null) {
          content = Uint8List.fromList(
            utf8.encode(databaseText(utf8.decode(content))),
          );
        } else if (database != null) {
          final value = (jsonDecode(utf8.decode(content)) as Map)
              .cast<String, dynamic>();
          database(value);
          content = Uint8List.fromList(utf8.encode(jsonEncode(value)));
        }
      }
      if (file.name == 'manifest.json' && manifest != null) {
        final value = (jsonDecode(utf8.decode(content)) as Map)
            .cast<String, Object?>();
        manifest(value);
        content = Uint8List.fromList(utf8.encode(jsonEncode(value)));
      }
      changed.addFile(ArchiveFile(file.name, content.length, content));
    }
    if (addFile != null) {
      final bytes = utf8.encode(addFile.$2);
      changed.addFile(ArchiveFile(addFile.$1, bytes.length, bytes));
    }
    return Uint8List.fromList(ZipEncoder().encode(changed));
  }

  test('数据不满足当前约束时在准备阶段拒绝，目标零写入且不新增附件', () async {
    final broken = modifyZip(
      database: (d) {
        final rows = (d['tables'] as Map)['missions'] as List;
        (rows.first as Map<String, Object?>)['title'] = null;
      },
    );
    await expectLater(importer.prepareRestore(broken), throwsA(anything));
    expect(
      (await targetMissions.findAllDetails()).single.mission.title,
      '当前旧任务',
    );
    expect(targetFiles.values.keys, {originalKey});
    expect(
      await target
          .customSelect("SELECT name FROM sqlite_master WHERE type='trigger'")
          .get(),
      isNotEmpty,
    );
  });

  test('拒绝缺图、旧格式、错版本、损坏JSON、未知表、未知列与未知文件，目标零写入', () async {
    for (final invalid in [
      modifyZip(remove: originalKey),
      modifyZip(manifest: (m) => m['formatVersion'] = 1),
      modifyZip(manifest: (m) => m['databaseVersion'] = 15),
      modifyZip(databaseText: (s) => s.substring(0, 10)),
      modifyZip(addFile: ('unexpected.txt', 'x')),
      modifyZip(
        database: (d) {
          (d['tables'] as Map)['unexpected_table'] = <Object?>[];
        },
      ),
      modifyZip(
        database: (d) {
          final rows = (d['tables'] as Map)['missions'] as List;
          (rows.first as Map<String, Object?>)['unexpected_column'] = 1;
        },
      ),
      modifyZip(manifest: (m) => m['resources'] = ['assistantSettings']),
      Uint8List.fromList([1, 2, 3]),
    ]) {
      await expectLater(importer.prepareRestore(invalid), throwsA(anything));
      expect(
        (await targetMissions.findAllDetails()).single.mission.title,
        '当前旧任务',
      );
    }
  });
  test('备份中的字符串只作为数据，不执行其中的 SQL 或 DDL', () async {
    final bytes = modifyZip(
      database: (d) {
        final rows = (d['tables'] as Map)['records'] as List;
        (rows.first as Map<String, Object?>)['content'] =
            'DROP TABLE missions; CREATE TRIGGER evil AFTER INSERT ON records BEGIN DELETE FROM missions; END;';
      },
    );
    await importer.restore(await importer.prepareRestore(bytes));
    expect(await targetMissions.findAllDetails(), hasLength(2));
    expect(
      await target
          .customSelect("SELECT name FROM sqlite_master WHERE name='evil'")
          .get(),
      isEmpty,
    );
  });
  test('符号链接条目在任何解压发生前被拒绝', () async {
    // archive 对 UNIX 链接条目会在 decodeBytes 内立即 readBytes，
    // 因此必须只读中央目录就拒绝，不能等解码后再看 symbolicLink。
    final linked = _asSymlink(zip, 'manifest.json');
    expect(() => decodeBackupArchive(linked), throwsA(isA<FormatException>()));
    await expectLater(
      importer.prepareRestore(linked),
      throwsA(isA<FormatException>()),
    );
    expect(
      (await targetMissions.findAllDetails()).single.mission.title,
      '当前旧任务',
    );
  });

  test('恢复写回包内本机资源，未包含的类别保持目标设备值', () async {
    final exported = FakeLocalResources();
    final bytes = await DatabaseBackupService(
      database: source,
      readAttachment: sourceFiles.read,
      localResources: exported,
    ).create(resources: BackupResource.values.toSet());
    final received = FakeLocalResources();
    final restorer = DatabaseBackupRestorer(
      database: target,
      files: targetFiles,
      attachments: targetMissions.attachments,
      localResources: received,
    );
    final plan = await restorer.prepareRestore(bytes);
    expect(plan.resources, BackupResource.values.toSet());
    await restorer.restore(plan);
    expect(received.applied, isNotNull);
    expect(
      received.applied!.keys,
      containsAll([localResourcesEntry, '${speechEntryPrefix}model.int8.onnx']),
    );
    expect(
      received.applied!['${speechEntryPrefix}model.int8.onnx'],
      exported.model,
    );

    // 不含本机资源的旧备份照常恢复，类别为空且不写回任何设置。
    final bare = await DatabaseBackupService(
      database: source,
      readAttachment: sourceFiles.read,
    ).create(resources: const {});
    final bareTarget = FakeLocalResources();
    final bareRestorer = DatabaseBackupRestorer(
      database: target,
      files: targetFiles,
      attachments: targetMissions.attachments,
      localResources: bareTarget,
    );
    final barePlan = await bareRestorer.prepareRestore(bare);
    expect(barePlan.resources, isEmpty);
    await bareRestorer.restore(barePlan);
    expect(bareTarget.applied, isEmpty);
  });
}

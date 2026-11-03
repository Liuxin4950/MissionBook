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
import 'package:mission_book/data/local/app_database.dart';
import 'package:mission_book/data/repositories/drift_mission_repository.dart';
import 'package:mission_book/data/repositories/drift_record_repository.dart';
import 'package:mission_book/data/assistant/drift_session_store.dart';
import 'package:mission_book/domain/entities/record_draft.dart';
import 'package:mission_book/domain/entities/mission_maintenance.dart';
import 'package:mission_book/domain/entities/execution_event.dart';
import 'package:mission_book/domain/entities/user_execution_report.dart';

class RestoreFiles implements AttachmentStore {
  final values = <String, Uint8List>{};
  bool failWrite = false;
  @override
  Future<void> writeNew(String key, Uint8List bytes) async {
    if (failWrite) throw StateError('模拟磁盘写入失败');
    if (values.containsKey(key)) throw StateError('重复文件');
    values[key] = Uint8List.fromList(bytes);
  }

  @override
  Future<Uint8List> read(String key) async =>
      values[key] ?? (throw StateError('缺少附件'));
  @override
  Future<void> delete(String key) async {
    values.remove(key);
  }

  @override
  Future<Set<String>> listKeys() async => values.keys.toSet();
}

class _Picker implements ImageAttachmentPicker {
  @override
  Future<SelectedAttachment?> pick() async => null;
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
    target = AppDatabase(executor: NativeDatabase.memory());
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
    await source.customStatement(
      'INSERT INTO memory_entries(id,kind,content,source,certainty,conflict_key,updated_at) VALUES (?,?,?,?,?,?,?)',
      [
        'memory',
        'preference',
        '喜欢先理解调用链',
        'user',
        'confirmed',
        'learning',
        now.millisecondsSinceEpoch,
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
    expect(
      (await target.select(target.memoryEntries).get()).single.content,
      '喜欢先理解调用链',
    );
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
  test('数据库插入失败回滚删除和触发器变动，新附件不留引用', () async {
    await target.customStatement(
      'CREATE UNIQUE INDEX simulated_restore_failure ON missions(title)',
    );
    final plan = await importer.prepareRestore(zip);
    await expectLater(importer.restore(plan), throwsA(anything));
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

  Uint8List modifyZip({
    String? remove,
    String Function(String)? sql,
    void Function(Map<String, Object?>)? manifest,
  }) {
    final original = ZipDecoder().decodeBytes(zip);
    final changed = Archive();
    for (final file in original) {
      if (file.name == remove) continue;
      var content = Uint8List.fromList(file.content as List<int>);
      if (file.name == 'database.sql' && sql != null) {
        content = Uint8List.fromList(utf8.encode(sql(utf8.decode(content))));
      }
      if (file.name == 'manifest.json' && manifest != null) {
        final value = (jsonDecode(utf8.decode(content)) as Map)
            .cast<String, Object?>();
        manifest(value);
        content = Uint8List.fromList(utf8.encode(jsonEncode(value)));
      }
      changed.addFile(ArchiveFile(file.name, content.length, content));
    }
    return Uint8List.fromList(ZipEncoder().encode(changed));
  }

  test('拒绝缺图、错版本、截断SQL及额外执行语句，目标零写入', () async {
    for (final invalid in [
      modifyZip(remove: originalKey),
      modifyZip(manifest: (m) => m['databaseVersion'] = 15),
      modifyZip(sql: (s) => s.substring(0, s.indexOf('COMMIT;'))),
      modifyZip(sql: (s) => '$s\nDROP TABLE missions;'),
      Uint8List.fromList([1, 2, 3]),
    ]) {
      await expectLater(importer.prepareRestore(invalid), throwsA(anything));
      expect(
        (await targetMissions.findAllDetails()).single.mission.title,
        '当前旧任务',
      );
    }
  });
  test('备份中触发器仅作说明，不能安装或执行备份自带SQL', () async {
    final bytes = modifyZip(
      sql: (s) => s.replaceFirst(
        'COMMIT;',
        'CREATE TRIGGER evil AFTER INSERT ON records BEGIN DELETE FROM missions; END;\nCOMMIT;',
      ),
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
}

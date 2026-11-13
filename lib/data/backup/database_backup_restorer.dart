import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../../application/attachments/attachment_coordinator.dart';
import '../../application/attachments/attachment_file_service.dart';
import '../../application/backup/backup_service.dart';
import '../local/app_database.dart';
import '../repositories/drift_mission_repository.dart';
import 'backup_archive.dart';
import 'backup_schema.dart';
import 'backup_validation_database.dart';
import 'local_resources.dart';

typedef _Rows = Map<String, List<Map<String, Object?>>>;

class _PreparedRestore extends BackupRestorePlan {
  _PreparedRestore({
    required this.owner,
    required this.rows,
    required this.files,
    required this.resourceFiles,
    required this.fingerprint,
    required super.exportedAt,
    required super.counts,
    required super.currentCounts,
    required super.resources,
  }) : super(
         attachmentCount: files.length,
         attachmentBytes: files.values.fold(
           0,
           (sum, bytes) => sum + bytes.length,
         ),
       );
  final DatabaseBackupRestorer owner;
  final _Rows rows;
  final Map<String, Uint8List> files;
  final Map<String, Uint8List> resourceFiles;
  final String fingerprint;
  bool used = false;
}

/// 先在隔离库校验，再以新附件键与单个数据库事务替换全部业务数据。
class DatabaseBackupRestorer implements BackupRestorer {
  DatabaseBackupRestorer({
    required this.database,
    required this.files,
    required this.attachments,
    this.localResources,
  });
  final AppDatabase database;
  final AttachmentStore files;
  final AttachmentCoordinator attachments;
  final LocalResourceStore? localResources;

  @override
  Future<BackupRestorePlan> prepareRestore(Uint8List bytes) async {
    final payload = await compute(decodeBackupArchive, bytes);
    if (payload['version'] != database.schemaVersion) {
      throw const FormatException('备份数据库版本与当前应用不一致，请使用对应版本导出或恢复');
    }
    if (payload['schemaFingerprint'] != await schemaFingerprint(database)) {
      throw const FormatException('备份结构指纹与当前应用不一致，请重新导出备份');
    }
    final rows = (payload['tables'] as Map).map(
      (key, value) => MapEntry(
        key as String,
        (value as List)
            .map((row) => Map<String, Object?>.from(row as Map))
            .toList(),
      ),
    );
    final names = database.allTables
        .map((table) => table.actualTableName)
        .toSet();
    if (!setEquals(rows.keys.toSet(), names)) {
      throw const FormatException('备份表不完整或不属于当前应用');
    }
    for (final table in database.allTables) {
      final columns = table.$columns.map((column) => column.$name).toSet();
      for (final row in rows[table.actualTableName]!) {
        if (!setEquals(row.keys.toSet(), columns)) {
          throw const FormatException('备份列与当前结构不一致');
        }
        for (final entry in row.entries) {
          if ((entry.key.endsWith('_json') ||
                  (table.actualTableName == 'assistant_session_records' &&
                      entry.key == 'data')) &&
              entry.value is String) {
            jsonDecode(entry.value as String);
          }
        }
      }
    }
    final sourceFiles = (payload['attachments'] as Map)
        .cast<String, Uint8List>();
    final stage = await openBackupValidationDatabase();
    try {
      await replaceAllRows(stage, rows);
      final referenced = await DriftMissionRepository(
        stage,
      ).referencedAttachmentKeys();
      if (!setEquals(referenced, sourceFiles.keys.toSet())) {
        throw const FormatException('备份附件缺失或引用与清单不一致');
      }
      for (final key in referenced) {
        validateAttachmentKey(key);
      }
      final details = await DriftMissionRepository(stage).findAllDetails();
      if (details.length != rows['missions']!.length) {
        throw const FormatException('任务方案或排期缺失');
      }
      for (final detail in details) {
        detail.phase;
      }
      final sequences = <String, List<int>>{};
      for (final row in rows['assistant_session_records']!) {
        (sequences[row['session_id'] as String] ??= []).add(
          row['sequence'] as int,
        );
      }
      for (final sequence in sequences.values) {
        sequence.sort();
        for (var i = 0; i < sequence.length; i++) {
          if (sequence[i] != i) throw const FormatException('会话日志序号不连续，无法完整恢复');
        }
      }
    } finally {
      await stage.close();
    }
    return database.transaction(
      () async => _PreparedRestore(
        owner: this,
        rows: rows,
        files: sourceFiles,
        resourceFiles: (payload['resources'] as Map).cast<String, Uint8List>(),
        resources: (payload['resourceKinds'] as List).cast<BackupResource>().toSet(),
        fingerprint: await _fingerprint(),
        exportedAt: DateTime.parse(payload['exportedAt'] as String),
        counts: Map.unmodifiable(
          rows.map((key, value) => MapEntry(key, value.length)),
        ),
        currentCounts: Map.unmodifiable(await _counts()),
      ),
    );
  }

  @override
  Future<BackupRestoreResult> restore(BackupRestorePlan plan) async {
    if (plan is! _PreparedRestore ||
        !identical(plan.owner, this) ||
        plan.used) {
      throw StateError('请重新选择备份并校验');
    }
    return attachments.synchronized(() async {
      final written = <String>[];
      var committed = false;
      try {
        // 同名原件也使用新键，失败或断电不会覆盖当前数据库正在引用的文件。
        final remap = <String, String>{};
        final owner = 'restore-${const Uuid().v4()}';
        for (final entry in plan.files.entries) {
          final key =
              'attachments/$owner/${const Uuid().v4()}.${entry.key.split('.').last}';
          await files.writeNew(key, entry.value);
          written.add(key);
          remap[entry.key] = key;
        }
        final rows = _remapRows(plan.rows, remap);
        await database.transaction(() async {
          await database.customStatement(
            'UPDATE missions SET updated_at=updated_at WHERE 0',
          );
          if (await _fingerprint() != plan.fingerprint) {
            throw StateError('校验后当前数据已变化，本次未恢复，请重新校验备份');
          }
          await replaceAllRows(database, rows);
        });
        committed = true;
        plan.used = true;
        // 业务数据已提交；本机资源写回失败不能谎报"原数据已保留"。
        try {
          await localResources?.apply(plan.resourceFiles);
        } catch (error) {
          throw StateError(
            '业务数据已恢复，但本机资源写回失败：$error。请重新校验这份备份再恢复一次，或手动配置助手与本机偏好。',
          );
        }
        return BackupRestoreResult(plan.counts, written.length);
      } finally {
        if (!committed) {
          for (final key in written) {
            try {
              await files.delete(key);
            } catch (_) {
              /* 新孤立文件由下次启动清理。 */
            }
          }
        }
      }
    });
  }

  Future<Map<String, int>> _counts() async => {
    for (final table in database.allTables)
      table.actualTableName:
          (await database
                  .customSelect(
                    'SELECT COUNT(*) n FROM "${table.actualTableName}"',
                  )
                  .getSingle())
              .read<int>('n'),
  };

  Future<String> _fingerprint() async {
    final snapshot = <String, List<String>>{};
    for (final table in database.allTables) {
      // 后台队列调度、会话续租与使用计数不是需要用户覆盖确认的业务内容。
      if (table.actualTableName == 'analysis_jobs' ||
          table.actualTableName == 'memory_usage') {
        continue;
      }
      final rows = await database
          .customSelect('SELECT * FROM "${table.actualTableName}"')
          .get();
      snapshot[table.actualTableName] = rows.map((row) {
        final value = Map<String, Object?>.from(row.data);
        if (table.actualTableName == 'assistant_sessions') {
          value.remove('writer_token');
          value.remove('writer_lease_until');
        }
        return jsonEncode(value);
      }).toList()..sort();
    }
    return sha256.convert(utf8.encode(jsonEncode(snapshot))).toString();
  }

  _Rows _remapRows(_Rows source, Map<String, String> remap) => {
    for (final table in source.entries)
      table.key: [
        for (final original in table.value)
          {
            for (final entry in original.entries)
              entry.key:
                  entry.key == 'attachment_storage_key' && entry.value is String
                  ? remap[entry.value]
                  : table.key == 'assistant_sessions' &&
                        {
                          'writer_token',
                          'writer_lease_until',
                        }.contains(entry.key)
                  ? null
                  : table.key == 'operation_receipts' &&
                        original['kind'] == 'missionExecutionArchive' &&
                        entry.key == 'result_json'
                  ? jsonEncode(
                      _remapArchive(jsonDecode(entry.value as String), remap),
                    )
                  : entry.value,
          },
      ],
  };

  Object? _remapArchive(Object? value, Map<String, String> remap) {
    if (value is List) {
      return [for (final item in value) _remapArchive(item, remap)];
    }
    if (value is Map) {
      return {
        for (final entry in value.entries)
          entry.key:
              entry.key == 'attachment_storage_key' && entry.value is String
              ? remap[entry.value]
              : _remapArchive(entry.value, remap),
      };
    }
    return value;
  }
}

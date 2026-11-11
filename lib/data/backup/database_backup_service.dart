import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:flutter/foundation.dart';

import '../../application/backup/backup_service.dart';
import '../../application/attachments/attachment_coordinator.dart';
import '../local/app_database.dart';
import '../repositories/drift_mission_repository.dart';

/// 事务只捕获数据库快照；附件在共享互斥保护下读取，编码和压缩不占写锁。
class DatabaseBackupService implements BackupExporter {
  DatabaseBackupService({
    required this.database,
    required this.readAttachment,
    this.attachments,
  });
  final AppDatabase database;
  final Future<Uint8List> Function(String key) readAttachment;
  final AttachmentCoordinator? attachments;

  @override
  Future<Uint8List> create() async {
    final files =
        await (attachments?.synchronized(_collectFiles) ?? _collectFiles());
    return compute(_encode, files);
  }

  Future<Map<String, Uint8List>> _collectFiles() async {
    final snapshot = await database.transaction(() async {
      final schema = await database
          .customSelect(
            "SELECT type, name, sql FROM sqlite_master WHERE sql IS NOT NULL AND name NOT LIKE 'sqlite_%' ORDER BY CASE type WHEN 'table' THEN 0 ELSE 1 END, name",
          )
          .get();
      final tables = <String, List<Map<String, Object?>>>{};
      for (final table in database.allTables) {
        final name = table.actualTableName.replaceAll('"', '""');
        tables[name] =
            (await database.customSelect('SELECT * FROM "$name"').get())
                .map((row) => row.data)
                .toList();
      }
      return (
        schema: schema,
        tables: tables,
        sessions: await database.select(database.assistantSessions).get(),
        records: await database.select(database.assistantSessionRecords).get(),
        references: await DriftMissionRepository(
          database,
        ).referencedAttachmentKeys(),
        capturedAt: DateTime.now().toUtc(),
      );
    });
    final schema = snapshot.schema;
    final sql = StringBuffer('PRAGMA foreign_keys=OFF;\nBEGIN TRANSACTION;\n');
    for (final row in schema.where((r) => r.read<String>('type') == 'table')) {
      sql.writeln('${row.read<String>('sql')};');
    }
    for (final table in snapshot.tables.entries) {
      final name = table.key;
      final rows = table.value;
      for (final row in rows) {
        final columns = row.keys
            .map((key) => '"${key.replaceAll('"', '""')}"')
            .join(',');
        sql.writeln(
          'INSERT INTO "$name" ($columns) VALUES (${row.values.map(_literal).join(',')});',
        );
      }
    }
    for (final row in schema.where((r) => r.read<String>('type') != 'table')) {
      sql.writeln('${row.read<String>('sql')};');
    }
    sql.writeln(
      'PRAGMA user_version=${database.schemaVersion};\nCOMMIT;\nPRAGMA foreign_keys=ON;',
    );
    final result = <String, Uint8List>{
      'database.sql': Uint8List.fromList(utf8.encode(sql.toString())),
    };
    // 可阅读的会话日志与 SQL 使用同一事务快照，不读取安全存储中的凭据。
    final sessions = snapshot.sessions;
    final records = snapshot.records;
    final bySession = <String, List<Map<String, Object?>>>{};
    records.sort((a, b) => a.sequence.compareTo(b.sequence));
    for (final record in records) {
      (bySession[record.sessionId] ??= []).add({
        'sequence': record.sequence,
        'timestamp': DateTime.fromMillisecondsSinceEpoch(
          record.timestamp,
          isUtc: true,
        ).toIso8601String(),
        'type': record.type,
        'data': jsonDecode(record.data),
        'version': record.version,
        'ignorable': record.ignorable,
      });
    }
    result['assistant-conversations.json'] = Uint8List.fromList(
      utf8.encode(
        const JsonEncoder.withIndent('  ').convert({
          'format': 'mission-book-assistant-conversations',
          'version': 1,
          'conversations': [
            for (final session in sessions)
              {
                'id': session.id,
                'title': session.title,
                'createdAt': DateTime.fromMillisecondsSinceEpoch(
                  session.createdAt,
                  isUtc: true,
                ).toIso8601String(),
                'updatedAt': DateTime.fromMillisecondsSinceEpoch(
                  session.updatedAt,
                  isUtc: true,
                ).toIso8601String(),
                'missionId': session.missionId,
                'goalId': session.goalId,
                'nodeId': session.nodeId,
                'records': bySession[session.id] ?? [],
              },
          ],
        }),
      ),
    );
    final references = snapshot.references;
    for (final key in references) {
      result[key] = await readAttachment(key);
    }
    result['manifest.json'] = Uint8List.fromList(
      utf8.encode(
        const JsonEncoder.withIndent('  ').convert({
          'format': 'mission-book-backup',
          'formatVersion': 1,
          'databaseVersion': database.schemaVersion,
          'databaseFormat': 'sqlite-sql',
          'exportedAt': snapshot.capturedAt.toIso8601String(),
          'attachments': result.keys
              .where((key) => key.startsWith('attachments/'))
              .toList(),
          'readableConversations': 'assistant-conversations.json',
          'excludes': [
            'apiKeys',
            'drafts',
            'temporaryFiles',
            'notificationMetadata',
            'localProfile',
          ],
        }),
      ),
    );
    result['README.txt'] = Uint8List.fromList(
      utf8.encode(
        'Mission Book 本地备份\n\ndatabase.sql 是一致事务内导出的 SQLite 完整逻辑快照，包含全部应用表、索引、触发器及数据库版本。\nattachments/ 保存记录、任务材料与撤销历史引用的原件。\nassistant-conversations.json 提供同一快照中的会话索引和完整原始日志，包括已发送消息、引用、附件内容及工具结果。\nmanifest.json 记录格式、导出时间与附件清单。\n在应用的数据备份页选择 ZIP，核对范围并确认后可恢复全部业务数据。\n不含 API Key、未发送草稿、缓存、模型/语音设置、本机资料及提醒偏好；恢复会保留目标设备的本机设置，新安装后需重新配置。\n',
      ),
    );
    return result;
  }

  static String _literal(Object? value) {
    if (value == null) return 'NULL';
    if (value is num) return '$value';
    final bytes = value is Uint8List ? value : utf8.encode(value.toString());
    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return value is Uint8List ? "X'$hex'" : "CAST(X'$hex' AS TEXT)";
  }

  static Uint8List _encode(Map<String, Uint8List> files) {
    final archive = Archive();
    for (final entry in files.entries) {
      archive.addFile(ArchiveFile(entry.key, entry.value.length, entry.value));
    }
    return Uint8List.fromList(ZipEncoder().encode(archive));
  }
}

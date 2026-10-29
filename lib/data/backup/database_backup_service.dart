import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:flutter/foundation.dart';

import '../../application/backup/backup_service.dart';
import '../local/app_database.dart';

/// 在同一只读事务内提取完整数据库与正式附件，生成可独立还原的 SQLite SQL 快照归档。
class DatabaseBackupService implements BackupExporter {
  DatabaseBackupService({required this.database, required this.readAttachment});
  final AppDatabase database;
  final Future<Uint8List> Function(String key) readAttachment;

  @override
  Future<Uint8List> create() async {
    final files = await database.transaction(() async {
      final schema = await database
          .customSelect(
            "SELECT type, name, sql FROM sqlite_master WHERE sql IS NOT NULL AND name NOT LIKE 'sqlite_%' ORDER BY CASE type WHEN 'table' THEN 0 ELSE 1 END, name",
          )
          .get();
      final sql = StringBuffer(
        'PRAGMA foreign_keys=OFF;\nBEGIN TRANSACTION;\n',
      );
      for (final row in schema.where(
        (r) => r.read<String>('type') == 'table',
      )) {
        sql.writeln('${row.read<String>('sql')};');
      }
      for (final table in database.allTables) {
        final name = table.actualTableName.replaceAll('"', '""');
        final rows = await database.customSelect('SELECT * FROM "$name"').get();
        for (final row in rows) {
          final columns = row.data.keys
              .map((key) => '"${key.replaceAll('"', '""')}"')
              .join(',');
          sql.writeln(
            'INSERT INTO "$name" ($columns) VALUES (${row.data.values.map(_literal).join(',')});',
          );
        }
      }
      for (final row in schema.where(
        (r) => r.read<String>('type') != 'table',
      )) {
        sql.writeln('${row.read<String>('sql')};');
      }
      sql.writeln(
        'PRAGMA user_version=${database.schemaVersion};\nCOMMIT;\nPRAGMA foreign_keys=ON;',
      );
      final result = <String, Uint8List>{
        'database.sql': Uint8List.fromList(utf8.encode(sql.toString())),
      };
      final evidence = await database.select(database.evidenceRecords).get();
      for (final row in evidence) {
        final key = row.attachmentStorageKey;
        if (key == null) continue;
        // reader 按现有图片存储规则验证路径；缺失附件使整个导出失败。
        result[key] = await readAttachment(key);
      }
      result['manifest.json'] = Uint8List.fromList(
        utf8.encode(
          const JsonEncoder.withIndent('  ').convert({
            'format': 'mission-book-backup',
            'formatVersion': 1,
            'databaseVersion': database.schemaVersion,
            'databaseFormat': 'sqlite-sql',
            'exportedAt': DateTime.now().toUtc().toIso8601String(),
            'attachments': result.keys
                .where((key) => key.startsWith('attachments/'))
                .toList(),
            'excludes': ['drafts', 'temporaryFiles', 'notificationMetadata'],
          }),
        ),
      );
      result['README.txt'] = Uint8List.fromList(
        utf8.encode(
          'Mission Book 本地备份\n\ndatabase.sql 是一致事务内导出的 SQLite 完整逻辑快照，包含八张领域表、索引、触发器及数据库版本。\n可使用 SQLite 在一个新的空数据库中执行该文件；attachments/ 保留正式材料原始路径。\nmanifest.json 记录格式、导出时间与附件清单。\n不含未提交草稿、缓存、提醒偏好。当前应用不提供恢复导入入口。\n',
        ),
      );
      return result;
    });
    // 压缩放到独立计算任务，准备期间页面仍可绘制进度。
    return compute(_encode, files);
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

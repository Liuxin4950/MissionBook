import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:drift/native.dart';
import 'package:mission_book/data/backup/backup_archive.dart';
import 'package:mission_book/data/backup/backup_schema.dart';
import 'package:mission_book/data/local/app_database.dart';

Map<String, List<Map<String, Object?>>> backupTables(Uint8List bytes) {
  final zip = ZipDecoder().decodeBytes(bytes, verify: true);
  final database =
      jsonDecode(utf8.decode(zip.findFile(backupDatabaseEntry)!.content as List<int>))
          as Map;
  return {
    for (final entry in (database['tables'] as Map).entries)
      entry.key as String: [
        for (final row in entry.value as List)
          Map<String, Object?>.from(row as Map),
      ],
  };
}

/// 用备份行数据重建内存库；结构与触发器来自当前应用，不执行备份中的任何 DDL。
Future<AppDatabase> openBackupDatabase(Uint8List bytes) async {
  final db = AppDatabase(executor: NativeDatabase.memory());
  await replaceAllRows(db, backupTables(bytes));
  return db;
}

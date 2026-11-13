import 'dart:convert';

import 'package:crypto/crypto.dart';

import '../local/app_database.dart';

/// 当前结构的指纹：版本、表列集合、索引与触发器名称；只用于同版本完整性校验。
Future<String> schemaFingerprint(AppDatabase db) async {
  final tables = [
    for (final table in db.allTables)
      '${table.actualTableName}(${table.$columns.map((column) => column.$name).toList()..sort()})',
  ]..sort();
  final objects = await db
      .customSelect(
        "SELECT type,name FROM sqlite_master WHERE name NOT LIKE 'sqlite_%' AND type IN ('index','trigger') ORDER BY type,name",
      )
      .get();
  return sha256
      .convert(
        utf8.encode(
          jsonEncode({
            'version': db.schemaVersion,
            'tables': tables,
            'objects': [
              for (final row in objects)
                '${row.read<String>('type')}:${row.read<String>('name')}',
            ],
          }),
        ),
      )
      .toString();
}

/// 只用当前结构的表列与参数绑定写入行数据；触发器在写入期间停用，结束后重建。
Future<void> replaceAllRows(
  AppDatabase db,
  Map<String, List<Map<String, Object?>>> rows,
) => db.transaction(() async {
  final triggers = await db
      .customSelect("SELECT name,sql FROM sqlite_master WHERE type='trigger'")
      .get();
  await db.customStatement('PRAGMA defer_foreign_keys=ON');
  for (final trigger in triggers) {
    final name = trigger.read<String>('name').replaceAll('"', '""');
    await db.customStatement('DROP TRIGGER "$name"');
  }
  for (final table in db.allTables.toList().reversed) {
    await db.customStatement('DELETE FROM "${table.actualTableName}"');
  }
  for (final table in db.allTables) {
    final columns = table.$columns.map((column) => column.$name).toList();
    final sql =
        'INSERT INTO "${table.actualTableName}" (${columns.map((name) => '"$name"').join(',')}) VALUES (${List.filled(columns.length, '?').join(',')})';
    for (final row in rows[table.actualTableName]!) {
      await db.customStatement(sql, [for (final column in columns) row[column]]);
    }
  }
  for (final trigger in triggers) {
    await db.customStatement(trigger.read<String>('sql'));
  }
  if ((await db.customSelect('PRAGMA foreign_key_check').get()).isNotEmpty) {
    throw const FormatException('备份数据关联损坏，恢复已回滚');
  }
});

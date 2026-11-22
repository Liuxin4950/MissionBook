import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mission_book/data/local/app_database.dart';

void main() {
  test('dump current schema', () async {
    final db = AppDatabase(executor: NativeDatabase.memory());
    await db.customStatement('PRAGMA foreign_keys = ON');
    final rows = await db
        .customSelect(
          "SELECT name, sql FROM sqlite_master WHERE type IN ('table','index') AND name NOT LIKE 'sqlite_%' ORDER BY type, name",
        )
        .get();
    for (final row in rows) {
      // ignore: avoid_print
      print('${row.read<String>('name')}\t${row.read<String?>('sql')}');
    }
    await db.close();
  });
}

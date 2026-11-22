import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mission_book/data/local/app_database.dart';

void main() {
  test('migrate v16 database copy to current schema', () async {
    final file = File('build/test-db/mission_book-v16.sqlite');
    final copy = File('build/test-db/mission_book-migrated.sqlite');
    if (await copy.exists()) await copy.delete();
    await file.copy(copy.path);

    final db = AppDatabase(executor: NativeDatabase(copy));
    final version = await db
        .customSelect('PRAGMA user_version')
        .getSingle();
    // ignore: avoid_print
    print('user_version=${version.data}');
    final items = await db
        .customSelect('SELECT COUNT(*) AS c FROM memory_items')
        .getSingle();
    final topics = await db
        .customSelect('SELECT COUNT(*) AS c FROM memory_topics')
        .getSingle();
    final aliases = await db
        .customSelect('SELECT COUNT(*) AS c FROM memory_topic_aliases')
        .getSingle();
    // ignore: avoid_print
    print(
      'items=${items.data['c']} topics=${topics.data['c']} '
      'aliases=${aliases.data['c']}',
    );
    final sample = await db
        .customSelect(
          'SELECT id, layer, certainty, source_kind, source_ref '
          'FROM memory_items LIMIT 3',
        )
        .get();
    for (final row in sample) {
      // ignore: avoid_print
      print(row.data);
    }
    await db.close();

    // 第二次打开不应再次迁移或失败。
    final reopened = AppDatabase(executor: NativeDatabase(copy));
    final again = await reopened
        .customSelect('SELECT COUNT(*) AS c FROM memory_items')
        .getSingle();
    // ignore: avoid_print
    print('reopened items=${again.data['c']}');
    await reopened.close();
  });
}

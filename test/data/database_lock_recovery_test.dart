import 'dart:async';
import 'dart:io';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mission_book/data/local/app_database.dart';

void main() {
  test('BEGIN 竞争超出单次等待后释放锁，事务正文只执行一次', () async {
    final directory = await Directory.systemTemp.createTemp('begin-recovery-');
    final file = File('${directory.path}/data.sqlite');
    final first = AppDatabase(
      executor: NativeDatabase.createInBackground(file),
    );
    final second = AppDatabase(
      executor: NativeDatabase.createInBackground(file),
    );
    final entered = Completer<void>();
    final release = Completer<void>();
    try {
      await first.customSelect('SELECT 1').get();
      await second.customSelect('SELECT 1').get();
      await second.customStatement('PRAGMA busy_timeout=10');
      final holding = first.transaction(() async {
        entered.complete();
        await release.future;
      });
      await entered.future;
      var executions = 0;
      final waiting = second.transaction(() async {
        executions++;
        await second.customStatement(
          "INSERT INTO search_usage (month,credits) VALUES ('2030-01',1)",
        );
      });
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(executions, 0);
      release.complete();
      await holding;
      await waiting;
      expect(executions, 1);
      expect(
        (await second.customSelect('SELECT credits FROM search_usage').get())
            .single
            .read<int>('credits'),
        1,
      );
    } finally {
      if (!release.isCompleted) release.complete();
      await first.close();
      await second.close();
      await directory.delete(recursive: true);
    }
  });

  test('正文抛 SQLITE_BUSY 时回滚并原样报告，不能自动重复执行', () async {
    final db = AppDatabase(executor: NativeDatabase.memory());
    var executions = 0;
    try {
      await expectLater(
        db.transaction(() async {
          executions++;
          await db.customStatement(
            "INSERT INTO search_usage (month,credits) VALUES ('2030-01',1)",
          );
          throw SqliteException(extendedResultCode: 5, message: 'body failure');
        }),
        throwsA(isA<SqliteException>()),
      );
      expect(executions, 1);
      expect(
        await db.customSelect('SELECT * FROM search_usage').get(),
        isEmpty,
      );
    } finally {
      await db.close();
    }
  });
}

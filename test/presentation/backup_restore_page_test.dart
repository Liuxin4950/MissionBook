import 'dart:async';
import 'dart:typed_data';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mission_book/application/backup/backup_service.dart';
import 'package:mission_book/application/attachments/attachment_coordinator.dart';
import 'package:mission_book/application/missions/mission_service.dart';
import 'package:mission_book/core/theme/app_theme.dart';
import 'package:mission_book/data/backup/database_backup_restorer.dart';
import 'package:mission_book/data/backup/database_backup_service.dart';
import 'package:mission_book/data/local/app_database.dart';
import 'package:mission_book/data/repositories/drift_mission_repository.dart';
import 'package:mission_book/presentation/me/data_backup_page.dart';
import '../application/backup_restore_test.dart' show RestoreFiles;
import '../support/me_fakes.dart';

void main() {
  late AppDatabase source, target;
  late MissionService sourceMissions, targetMissions;
  late ManagedBackupService backup;
  late Uint8List bytes;
  var commits = 0;
  setUp(() async {
    source = AppDatabase(executor: NativeDatabase.memory());
    target = AppDatabase(executor: NativeDatabase.memory());
    sourceMissions = MissionService(DriftMissionRepository(source));
    targetMissions = MissionService(DriftMissionRepository(target));
    for (var i = 0; i < 2; i++) {
      await sourceMissions.create(
        title: '备份任务$i',
        scheduledDate: '2026-11-03',
        timeZone: 'Asia/Shanghai',
        plannedDurationMinutes: 10,
      );
    }
    await targetMissions.create(
      title: '当前任务',
      scheduledDate: '2026-11-03',
      timeZone: 'Asia/Shanghai',
      plannedDurationMinutes: 10,
    );
    bytes = await DatabaseBackupService(
      database: source,
      readAttachment: (_) async => Uint8List(0),
    ).create();
    final repo = DriftMissionRepository(target);
    commits = 0;
    backup = ManagedBackupService(
      exporter: DatabaseBackupService(
        database: target,
        readAttachment: (_) async => Uint8List(0),
      ),
      restorer: DatabaseBackupRestorer(
        database: target,
        files: RestoreFiles(),
        attachments: AttachmentCoordinator(
          referencedKeys: repo.referencedAttachmentKeys,
        ),
      ),
      runRestore: (operation) async {
        final result = await operation();
        commits++;
        return result;
      },
    );
  });
  tearDown(() async {
    await sourceMissions.dispose();
    await targetMissions.dispose();
    await source.close();
    await target.close();
  });
  Future<void> mount(
    WidgetTester tester, {
    double scale = 1,
    Future<Uint8List?> Function()? pick,
  }) async {
    tester.view.physicalSize = const Size(320, 850);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
        home: DataBackupPage(
          backup: backup,
          device: TestAppDevice(),
          selectBackup: pick ?? () async => bytes,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> tap(WidgetTester tester, String key) async {
    await tester.ensureVisible(find.byKey(Key(key)));
    await tester.pump();
    await tester.tap(find.byKey(Key(key)));
    await tester.pump();
  }

  Future<void> waitFor(WidgetTester tester, Finder finder) async {
    for (var i = 0; i < 100 && finder.evaluate().isEmpty; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 15)),
      );
      await tester.pump();
    }
    expect(finder, findsOneWidget);
  }

  testWidgets('真实备份校验、取消与确认恢复进入同一业务事务', (tester) async {
    await mount(tester);
    await tap(tester, 'backup-select-import');
    await waitFor(tester, find.byKey(const Key('backup-confirm-import')));
    expect(find.text('任务：2（当前 1）'), findsOneWidget);
    expect(await targetMissions.findAllDetails(), hasLength(1));
    await tap(tester, 'backup-confirm-import');
    await tester.pumpAndSettle();
    await tester.tap(find.text('保留当前数据'));
    await tester.pumpAndSettle();
    expect(commits, 0);
    expect(await targetMissions.findAllDetails(), hasLength(1));
    await tap(tester, 'backup-confirm-import');
    await tester.pumpAndSettle();
    await tester.tap(find.text('替换并恢复'));
    await tester.pump();
    await waitFor(tester, find.text('备份已恢复'));
    expect(commits, 1);
    expect(await targetMissions.findAllDetails(), hasLength(2));
    expect(tester.takeException(), isNull);
  });
  testWidgets('选择取消不修改数据；损坏备份不给恢复入口', (tester) async {
    await mount(tester, pick: () async => null);
    await tap(tester, 'backup-select-import');
    await waitFor(tester, find.text('已取消选择'));
    expect(commits, 0);
    expect(find.byKey(const Key('backup-confirm-import')), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
    await mount(tester, pick: () async => Uint8List.fromList([1, 2, 3]));
    await tap(tester, 'backup-select-import');
    await waitFor(tester, find.text('缺少备份清单或数据库'));
    expect(await targetMissions.findAllDetails(), hasLength(1));
  });
  testWidgets('双倍字号可滚动核对范围，校验期间禁用重复点击与系统返回', (tester) async {
    final selection = Completer<Uint8List?>();
    await mount(tester, scale: 2, pick: () => selection.future);
    await tap(tester, 'backup-select-import');
    expect(
      tester
          .widget<OutlinedButton>(find.byKey(const Key('backup-select-import')))
          .onPressed,
      isNull,
    );
    await tester.binding.handlePopRoute();
    await tester.pump();
    expect(find.byType(DataBackupPage), findsOneWidget);
    selection.complete(bytes);
    await waitFor(tester, find.byKey(const Key('backup-confirm-import')));
    await tester.ensureVisible(find.byKey(const Key('backup-confirm-import')));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}

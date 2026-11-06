import 'package:mission_book/application/attachments/attachment_coordinator.dart';
import 'package:mission_book/domain/entities/record_draft.dart';
import 'dart:io';
import 'dart:async';
import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'
    show debugDefaultTargetPlatformOverride;
import 'package:flutter_test/flutter_test.dart';
import 'package:mission_book/application/analysis/analysis_service.dart';
import 'package:mission_book/application/attachments/attachment_file_service.dart';
import 'package:mission_book/application/missions/mission_service.dart';
import 'package:mission_book/application/records/record_service.dart';
import 'package:mission_book/data/analysis/drift_analysis_store.dart';
import 'package:mission_book/data/local/app_database.dart';
import 'package:mission_book/data/repositories/drift_mission_repository.dart';
import 'package:mission_book/data/repositories/drift_record_repository.dart';
import 'package:mission_book/presentation/records/record_scope.dart';
import 'package:mission_book/presentation/records/records_page.dart';

class _Images implements AttachmentStore, ImageAttachmentPicker {
  late Uint8List bytes;
  bool fail = false;
  int reads = 0;
  Completer<SelectedAttachment?>? pendingPick;
  final deleted = <String>[];
  @override
  Future<Uint8List> read(String key) async {
    reads++;
    if (fail) {
      throw const FileSystemException(
        'test read failed',
        'C:/private/picture.png',
      );
    }
    return bytes;
  }

  @override
  Future<SelectedAttachment?> pick() async => pendingPick?.future;
  @override
  Future<Set<String>> listKeys() async => {'attachments/photo/image.png'};
  @override
  Future<void> delete(String key) async => deleted.add(key);
  @override
  Future<void> writeNew(String key, Uint8List bytes) async {}
}

void main() {
  late AppDatabase db;
  late MissionService missions;
  late RecordService records;
  late AnalysisService analysis;
  late _Images images;
  final png = File(
    'assets/illustrations/focus-hourglass.png',
  ).readAsBytesSync();
  final now = DateTime.utc(2030, 1, 1);

  setUp(() async {
    db = AppDatabase(executor: NativeDatabase.memory());
    images = _Images()..bytes = png;
    missions = MissionService(
      DriftMissionRepository(db, clock: () => now),
      attachments: AttachmentCoordinator(
        files: AttachmentFileService(store: images, picker: images),
        referencedKeys: DriftMissionRepository(
          db,
          clock: () => now,
        ).referencedAttachmentKeys,
      ),
      clock: () => now,
    );
    records = RecordService(
      DriftRecordRepository(db, clock: () => now),
      missions,
      missions.attachments,
    );
    analysis = AnalysisService(
      store: DriftAnalysisStore(db),
      mainBusy: () => false,
      model: (prompt, {imageKey, mime, json = false}) async => '记录总结',
    );
    await records.save(
      const RecordDraft(
        id: 'photo',
        type: ContentType.image,
        source: ContentSource.fileSystem,
        attachmentStorageKey: 'attachments/photo/image.png',
        attachmentFileName: '记录照片.png',
        attachmentMimeType: 'image/png',
      ),
    );
    images.reads = 0;
  });
  tearDown(() async {
    await analysis.dispose();
    await missions.dispose();
    await db.close();
  });

  test('独立照片记录不创建记录级AI摘要', () async {
    expect(await db.select(db.analysisJobs).get(), isEmpty);
    await analysis.drain();
    expect(await db.select(db.analysisVersions).get(), isEmpty);
    expect(images.reads, 0);
  });

  Widget app(Widget child) => MaterialApp(
    builder: (c, child) =>
        RecordScope(service: records, analysis: analysis, child: child!),
    home: child,
  );

  for (final surface in ['列表', '当日条带', '详情']) {
    testWidgets('$surface 图片读取失败可重试，页面重建不重复读图', (tester) async {
      final Widget home = switch (surface) {
        '列表' => const RecordsPage(),
        '当日条带' => const Scaffold(body: DailyRecordsStrip(date: '2030-01-01')),
        _ => const RecordDetail(id: 'photo'),
      };
      images.fail = true;
      await tester.pumpWidget(app(home));
      await tester.pumpAndSettle();
      expect(images.reads, 1);
      await tester.pumpWidget(app(home));
      await tester.pumpAndSettle();
      expect(images.reads, 1);
      final retry = surface == '详情'
          ? find.widgetWithText(TextButton, '重新读取图片')
          : find.byTooltip('重新读取图片：记录照片.png');
      expect(retry, findsOneWidget);
      images.fail = false;
      await tester.tap(retry);
      await tester.pumpAndSettle();
      expect(images.reads, 2);
      expect(retry, findsNothing);
      expect((await db.select(db.records).get()).single.id, 'photo');
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

  testWidgets('页面移除后迟到的图片选择清理草稿且不更新页面', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    images.pendingPick = Completer<SelectedAttachment?>();
    await tester.pumpWidget(app(const Scaffold(body: RecordEditor())));
    await tester.tap(find.byKey(const Key('record-pick-photo')));
    await tester.pumpAndSettle();
    await tester.pumpWidget(const SizedBox.shrink());
    images.pendingPick!.complete(
      SelectedAttachment(
        fileName: 'late.png',
        byteLength: png.length,
        readBytes: () async => png,
      ),
    );
    for (var i = 0; i < 100 && images.deleted.isEmpty; i++) {
      await tester.pump(const Duration(milliseconds: 20));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 5)),
      );
    }
    debugDefaultTargetPlatformOverride = null;
    expect(images.deleted, hasLength(1));
    expect(tester.takeException(), isNull);
  });

  testWidgets('详情解码失败可重新读取有效字节，删除后的旧入口显示空态', (tester) async {
    images.bytes = Uint8List.fromList([1, 2, 3]);
    await tester.pumpWidget(app(const RecordDetail(id: 'photo')));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(TextButton, '重新读取图片'), findsOneWidget);
    images.bytes = png;
    await tester.tap(find.widgetWithText(TextButton, '重新读取图片'));
    await tester.pumpAndSettle();
    expect(images.reads, 2);
    await tester.pumpWidget(const SizedBox.shrink());
    await records.delete('photo');
    await tester.pumpWidget(app(const RecordDetail(id: 'photo')));
    await tester.pumpAndSettle();
    expect(find.text('记录不存在或已删除'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}

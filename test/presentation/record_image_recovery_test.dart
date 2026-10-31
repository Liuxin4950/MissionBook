import 'dart:io';
import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mission_book/application/analysis/analysis_service.dart';
import 'package:mission_book/application/evidence/evidence_image_service.dart';
import 'package:mission_book/application/missions/mission_service.dart';
import 'package:mission_book/application/records/record_service.dart';
import 'package:mission_book/data/analysis/drift_analysis_store.dart';
import 'package:mission_book/data/local/app_database.dart';
import 'package:mission_book/data/repositories/drift_mission_repository.dart';
import 'package:mission_book/data/repositories/drift_record_repository.dart';
import 'package:mission_book/domain/entities/evidence.dart';
import 'package:mission_book/presentation/records/record_scope.dart';
import 'package:mission_book/presentation/records/records_page.dart';

class _Images implements EvidenceImageStore, EvidenceImagePicker {
  late Uint8List bytes;
  bool fail = false;
  int reads = 0;
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
  Future<SelectedEvidenceImage?> pick() async => null;
  @override
  Future<Set<String>> listKeys() async => {'attachments/photo/image.png'};
  @override
  Future<void> delete(String key) async {}
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
      images: EvidenceImageService(store: images, picker: images),
      clock: () => now,
    );
    records = RecordService(
      DriftRecordRepository(db, clock: () => now),
      missions,
    );
    analysis = AnalysisService(
      store: DriftAnalysisStore(db),
      mainBusy: () => false,
      model: (prompt, {imageKey, mime, json = false}) async => '记录总结',
    );
    await records.save(
      const EvidenceDraft(
        id: 'photo',
        type: EvidenceType.image,
        source: EvidenceSource.fileSystem,
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

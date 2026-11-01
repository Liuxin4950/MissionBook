import 'dart:io';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:mission_book/application/missions/mission_service.dart';
import 'package:mission_book/data/local/app_database.dart';
import 'package:mission_book/data/repositories/drift_mission_repository.dart';
import 'package:mission_book/data/repositories/drift_record_repository.dart';
import 'package:mission_book/domain/entities/record_draft.dart';

void main() {
  test('两个独立连接同时删除来源和引用材料，不产生悬空内容或半提交', () async {
    tzdata.initializeTimeZones();
    final directory = await Directory.systemTemp.createTemp(
      'record_snapshot_race_',
    );
    final file = File('${directory.path}/race.sqlite');
    final first = AppDatabase(
      executor: NativeDatabase.createInBackground(file),
    );
    final second = AppDatabase(
      executor: NativeDatabase.createInBackground(file),
    );
    final now = DateTime.utc(2030, 1, 1);
    final repository = DriftMissionRepository(first, clock: () => now);
    final service = MissionService(repository, clock: () => now);
    final source = DriftRecordRepository(first);
    final deleter = DriftRecordRepository(second);
    try {
      await first.customSelect('SELECT 1').get();
      await second.customSelect('SELECT 1').get();
      for (var i = 0; i < 4; i++) {
        final request = service.prepareCreation(
          title: '任务$i',
          scheduledDate: '2030-01-01',
          timeZone: 'Asia/Shanghai',
          plannedDurationMinutes: 30,
        );
        await service.createPrepared(request);
        final recordId = 'source-$i';
        await source.saveRecord(
          RecordDraft(
            id: recordId,
            type: ContentType.text,
            source: ContentSource.user,
            content: '提交内容$i',
          ),
        );
        Future<bool> attach() async {
          try {
            await repository.attachRecordEvidence(recordId, request.mission.id);
            return true;
          } on ArgumentError {
            return false;
          }
        }

        final saving = attach();
        await Future.wait<void>([
          saving.then((_) {}),
          deleter.deleteRecord(recordId),
        ]);
        final saved = await saving;
        expect((await source.readRecords(id: recordId)).items, isEmpty);
        final detail = (await repository.findDetail(request.mission.id))!;
        if (saved) {
          expect(detail.evidence.single.content, '提交内容$i');
        } else {
          expect(detail.evidence, isEmpty);
        }
        expect(
          await first.customSelect('PRAGMA foreign_key_check').get(),
          isEmpty,
        );
      }
    } finally {
      await service.dispose();
      await first.close();
      await second.close();
      await directory.delete(recursive: true);
    }
  });
}

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mission_book/application/missions/mission_service.dart';
import 'package:mission_book/application/records/record_service.dart';
import 'package:mission_book/data/local/app_database.dart';
import 'package:mission_book/data/repositories/drift_mission_repository.dart';
import 'package:mission_book/data/repositories/drift_record_repository.dart';
import 'package:mission_book/domain/entities/evidence.dart';
import 'package:mission_book/domain/entities/mission_detail.dart';
import 'package:mission_book/domain/entities/mission_maintenance.dart';
import 'package:mission_book/domain/entities/record_draft.dart';

class _DeleteBetweenReceiptAndRead extends DriftMissionRepository {
  _DeleteBetweenReceiptAndRead(super.database);
  Future<void> Function()? beforeNextDetail;
  @override
  Future<MissionDetail?> findDetail(String missionId) async {
    final action = beforeNextDetail;
    beforeNextDetail = null;
    await action?.call();
    return super.findDetail(missionId);
  }
}

void main() {
  test('幂等回执确认后任务被维护删除，重读明确拒绝而非空断言', () async {
    final db = AppDatabase(executor: NativeDatabase.memory());
    final repository = _DeleteBetweenReceiptAndRead(db);
    final missions = MissionService(repository);
    final records = RecordService(
      DriftRecordRepository(db),
      missions,
      missions.attachments,
    );
    try {
      final request = missions.prepareCreation(
        title: '删除竞争',
        scheduledDate: '2026-11-11',
        timeZone: 'Asia/Shanghai',
        plannedDurationMinutes: 30,
      );
      await missions.createPrepared(request);
      await records.save(
        const RecordDraft(
          id: 'source',
          type: ContentType.text,
          source: ContentSource.user,
          content: '保留的独立来源',
        ),
      );
      await repository.attachRecordEvidence(
        'source',
        request.mission.id,
        operationId: 'attach',
      );
      final deletion = await missions.prepareMaintenance(
        action: MissionMaintenanceAction.delete,
        ids: [request.mission.id],
      );
      repository.beforeNextDetail = () async {
        await missions.applyMaintenance(deletion);
      };
      await expectLater(
        repository.attachRecordEvidence(
          'source',
          request.mission.id,
          operationId: 'attach',
        ),
        throwsA(isA<EvidenceConflict>()),
      );
      expect(await missions.findDetail(missionId: request.mission.id), isNull);
      expect((await records.readDraft('source')).content, '保留的独立来源');
    } finally {
      await missions.dispose();
      await db.close();
    }
  });
}

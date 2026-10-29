import 'dart:convert';
import 'package:mission_book/domain/entities/mission.dart';
import 'package:mission_book/domain/entities/execution_event.dart';
import 'package:mission_book/domain/entities/evidence.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mission_book/application/missions/mission_service.dart';
import 'package:mission_book/data/assistant/drift_assistant_reader.dart';
import 'package:mission_book/data/local/app_database.dart';
import 'package:mission_book/data/repositories/drift_mission_repository.dart';

void main() {
  test('超长方案只按Unicode字符分页；SQL注入式标题只是普通检索文字', () async {
    final db = AppDatabase(executor: NativeDatabase.memory());
    final missions = MissionService(DriftMissionRepository(db));
    try {
      final notes = List.filled(5500, '中😀').join();
      await missions.create(
        title: '原始标题',
        scheduledDate: '2026-10-29',
        timeZone: 'UTC',
        plannedDurationMinutes: 30,
        notes: notes,
      );
      final id = (await missions.findAllDetails()).single.mission.id;
      final reader = DriftAssistantReader(db);
      final reconstructed = StringBuffer();
      int? offset = 0;
      while (offset != null) {
        final page = await reader.content(id, 'notes', offset: offset);
        expect((page['text'] as String).runes.length, lessThanOrEqualTo(2000));
        expect(jsonEncode(page).length, lessThan(7000));
        reconstructed.write(page['text']);
        offset = page['nextOffset'] as int?;
      }
      expect(reconstructed.toString(), notes);
      expect((await reader.missions(search: "' OR 1=1 --"))['total'], 0);
      expect((await reader.missions())['total'], 1);
      await expectLater(
        reader.content(id, 'arbitrary_sql'),
        throwsArgumentError,
      );
      await expectLater(reader.missions(offset: -1), throwsArgumentError);
    } finally {
      await missions.dispose();
      await db.close();
    }
  });
  test('执行报告与材料原文分别读取，修正保留历史并标记当前有效项', () async {
    final db = AppDatabase(executor: NativeDatabase.memory());
    final missions = MissionService(DriftMissionRepository(db));
    try {
      await missions.create(
        title: '记录任务',
        scheduledDate: '2026-10-29',
        timeZone: 'UTC',
        plannedDurationMinutes: 20,
        verificationPolicy: VerificationPolicy.optionalEvidence,
        verificationCriteria: '说明这次结果',
      );
      var detail = (await missions.findAllDetails()).single;
      final id = detail.mission.id;
      await missions.execute(
        missions.prepareExecution(
          detail: detail,
          type: ExecutionEventType.start,
        ),
      );
      detail = (await missions.findDetailSnapshot(missionId: id))!;
      await missions.execute(
        missions.prepareExecution(
          detail: detail,
          type: ExecutionEventType.end,
          report: UserReportedResult.completed,
          submitOptionalEvidence: true,
        ),
      );
      detail = (await missions.findDetailSnapshot(missionId: id))!;
      await missions.submitEvidence(
        missions.prepareEvidenceSubmission(
          detail: detail,
          items: [
            const EvidenceDraft(
              id: 'original-evidence',
              type: EvidenceType.text,
              source: EvidenceSource.user,
              content: '用户原始记录',
            ),
          ],
        ),
      );
      detail = (await missions.findDetailSnapshot(missionId: id))!;
      await missions.correctEvidence(
        missions.prepareEvidenceCorrection(
          detail: detail,
          original: detail.evidence.single,
          draft: const EvidenceDraft(
            id: 'corrected-evidence',
            type: EvidenceType.text,
            source: EvidenceSource.user,
            content: '用户修正记录',
            supersedesEvidenceId: 'original-evidence',
          ),
        ),
      );
      final reader = DriftAssistantReader(db);
      final events = await reader.records(id, 'execution');
      expect(events['total'], 2);
      expect((events['items'] as List).last['userReportedResult'], 'COMPLETED');
      final evidence = await reader.records(id, 'evidence');
      expect(evidence['total'], 2);
      final items = evidence['items'] as List;
      expect(
        items.singleWhere(
          (item) => item['id'] == 'original-evidence',
        )['isCurrent'],
        isFalse,
      );
      expect(
        items.singleWhere(
          (item) => item['id'] == 'corrected-evidence',
        )['isCurrent'],
        isTrue,
      );
      expect(
        (await reader.evidenceContent('original-evidence'))['text'],
        '用户原始记录',
      );
      expect(
        (await reader.evidenceContent('corrected-evidence'))['text'],
        '用户修正记录',
      );
      expect(
        (await reader.records('missing', 'execution'))['code'],
        'not_found',
      );
      expect((await reader.evidenceContent('missing'))['code'], 'not_found');
    } finally {
      await missions.dispose();
      await db.close();
    }
  });
}

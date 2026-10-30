import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mission_book/application/missions/mission_service.dart';
import 'package:mission_book/core/theme/app_theme.dart';
import 'package:mission_book/data/local/app_database.dart';
import 'package:mission_book/data/repositories/drift_mission_repository.dart';
import 'package:mission_book/domain/entities/execution_event.dart';
import 'package:mission_book/domain/entities/mission_phase.dart';
import 'package:mission_book/domain/entities/mission.dart';
import 'package:mission_book/domain/entities/mission_schedule_revision.dart';
import 'package:mission_book/presentation/missions/detail/mission_detail_page.dart';

void main() {
  final start = DateTime.utc(2026, 10, 30, 2);
  late DateTime now;
  late AppDatabase db;
  late MissionService service;
  late String id;
  setUp(() async {
    now = start;
    db = AppDatabase(executor: NativeDatabase.memory());
    service = MissionService(
      DriftMissionRepository(db, clock: () => now),
      clock: () => now,
    );
    final request = service.prepareCreation(
      title: '项目会议',
      scheduledDate: '2026-10-30',
      timeZone: 'Asia/Shanghai',
      plannedDurationMinutes: 30,
      timePolicy: TimePolicy.fixed,
      fixedStartAt: start,
      verificationPolicy: VerificationPolicy.optionalEvidence,
    );
    id = request.mission.id;
    await service.createPrepared(request);
    await service.reconcileScheduledMissions();
  });
  tearDown(() async {
    await service.dispose();
    await db.close();
  });

  Future<void> open(WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        locale: const Locale('zh', 'CN'),
        supportedLocales: const [Locale('zh', 'CN')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        home: MissionDetailPage(missionId: id, missionService: service),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> tap(WidgetTester tester, Finder target) async {
    if (target.evaluate().isEmpty) {
      await tester.scrollUntilVisible(
        target,
        160,
        scrollable: find
            .descendant(
              of: find.byKey(const Key('mission-execution-list')),
              matching: find.byType(Scrollable),
            )
            .first,
      );
    }
    await tester.ensureVisible(target);
    await tester.pumpAndSettle();
    await tester.tap(target);
    await tester.pumpAndSettle();
  }

  testWidgets('重新打开待确认日程直接填报告，可以稍后确认且不能继续计时', (tester) async {
    now = start.add(const Duration(hours: 5));
    await service.reconcileScheduledMissions();
    await open(tester);
    expect(find.text('待确认'), findsOneWidget);
    expect(find.textContaining('计划时间已到，计时已停止'), findsOneWidget);
    expect(find.text('30:00'), findsOneWidget);
    expect(find.text('继续执行'), findsNothing);
    await tap(tester, find.byKey(const Key('report-cancel')));
    expect(find.text('确认完成情况'), findsOneWidget);
    expect(find.byKey(const Key('execution-extend')), findsNothing);
    expect(
      (await service.findDetail(missionId: id))!.phase,
      MissionPhase.reportPending,
    );
    await tap(tester, find.byKey(const Key('execution-end')));
    await tap(tester, find.byKey(const Key('report-completed')));
    await tap(tester, find.byKey(const Key('report-evidence-submit')));
    await tap(tester, find.byKey(const Key('report-confirm')));
    expect(
      (await service.findDetail(missionId: id))!.phase,
      MissionPhase.evidencePending,
    );
    expect(find.byKey(const Key('mission-evidence-workspace')), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('正在查看执行页时到点，自动转入待确认报告', (tester) async {
    await open(tester);
    now = start.add(const Duration(minutes: 30));
    await service.reconcileScheduledMissions();
    await tester.pumpAndSettle();
    expect(find.text('待确认'), findsOneWidget);
    expect(find.byKey(const Key('report-confirm')), findsOneWidget);
    final detail = (await service.findDetail(missionId: id))!;
    expect(detail.events.last.type, ExecutionEventType.stop);
    expect(detail.endReportedCompleted, isFalse);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}

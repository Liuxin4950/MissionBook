import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mission_book/application/analysis/analysis_service.dart';
import 'package:mission_book/application/memory/memory_service.dart';
import 'package:mission_book/application/missions/mission_service.dart';
import 'package:mission_book/application/records/record_service.dart';
import 'package:mission_book/core/theme/app_theme.dart';
import 'package:mission_book/data/analysis/drift_analysis_store.dart';
import 'package:mission_book/data/local/app_database.dart';
import 'package:mission_book/data/repositories/drift_mission_repository.dart';
import 'package:mission_book/data/repositories/drift_record_repository.dart';
import 'package:mission_book/presentation/records/record_scope.dart';
import 'package:mission_book/presentation/today/today_page.dart';
import 'package:mission_book/presentation/widgets/app_page_header.dart';

void main() {
  late AppDatabase db;
  late MissionService missions;
  late RecordService records;
  late AnalysisService analysis;

  setUp(() {
    db = AppDatabase(executor: NativeDatabase.memory());
    missions = MissionService(DriftMissionRepository(db));
    records = RecordService(DriftRecordRepository(db), missions);
    analysis = AnalysisService(
      store: DriftAnalysisStore(db),
      mainBusy: () => false,
      model: (p, {imageKey, mime, json = false}) async => '摘要',
    );
  });

  tearDown(() async {
    await analysis.dispose();
    await missions.dispose();
    await db.close();
  });

  Widget app(DateTime initialDate) => MaterialApp(
    theme: AppTheme.light,
    locale: const Locale('zh', 'CN'),
    supportedLocales: const [Locale('zh', 'CN')],
    localizationsDelegates: GlobalMaterialLocalizations.delegates,
    builder: (context, child) => RecordScope(
      service: records,
      memory: MemoryService(DriftRecordRepository(db)),
      analysis: analysis,
      child: child!,
    ),
    home: Scaffold(
      body: TodayPage(
        missionService: missions,
        clock: () => DateTime(2026, 11, 2, 9),
        initialDate: initialDate,
      ),
    ),
  );

  for (final scenario in [
    (width: 320.0, offWeek: true, showShortcut: false),
    (width: 360.0, offWeek: true, showShortcut: false),
    (width: 390.0, offWeek: true, showShortcut: true),
    (width: 390.0, offWeek: false, showShortcut: false),
  ]) {
    testWidgets('窄屏页头保持单行并按可用宽度显示今天入口 $scenario', (tester) async {
      tester.view.physicalSize = Size(scenario.width, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        app(scenario.offWeek ? DateTime(2026, 11, 9) : DateTime(2026, 11, 2)),
      );
      await tester.pumpAndSettle();

      expect(tester.getSize(find.byType(AppPageHeader)).height, 48);
      final shortcut = find.byKey(const Key('today-return-current-week'));
      expect(shortcut, scenario.showShortcut ? findsOneWidget : findsNothing);
      expect(find.text(scenario.offWeek ? '11月9日' : '11月2日'), findsOneWidget);
      expect(find.byTooltip('拍照记录'), findsOneWidget);
      expect(find.byTooltip('全部任务'), findsOneWidget);
      expect(find.byTooltip('创建任务'), findsOneWidget);
      expect(find.text('11月9日 · 周一'), findsNothing);
      expect(find.textContaining('当日记录'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }
}

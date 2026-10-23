import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mission_book/application/missions/mission_service.dart';
import 'package:mission_book/core/theme/app_theme.dart';
import 'package:mission_book/data/local/app_database.dart';
import 'package:mission_book/data/repositories/drift_mission_repository.dart';
import 'package:mission_book/domain/entities/mission_detail.dart';
import 'package:mission_book/domain/entities/mission_schedule_revision.dart';
import 'package:mission_book/presentation/missions/mission_detail_page.dart';
import 'package:mission_book/presentation/missions/mission_form_page.dart';
import 'package:mission_book/presentation/today/today_page.dart';

import 'create_mission_page_test.dart' show PendingRepository;
import 'mission_detail_page_test.dart' show exampleDetail;

class EditingRepository extends PendingRepository {
  final edits = <MissionScheduleRevision>[];
  final titles = <String>[];
  final objectives = <String>[];
  Completer<void> saving = Completer<void>();
  @override
  Future<void> edit({
    required MissionDetail original,
    required String title,
    required String objective,
    required MissionScheduleRevision schedule,
  }) {
    edits.add(schedule);
    titles.add(title);
    objectives.add(objective);
    return saving.future;
  }
}

Future<void> openEditor(
  WidgetTester tester,
  EditingRepository repository, {
  double scale = 1,
  MissionDetail? detail,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light,
      locale: const Locale('zh', 'CN'),
      supportedLocales: const [Locale('zh', 'CN')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(scale)),
        child: child!,
      ),
      home: Builder(
        builder: (context) => TextButton(
          onPressed: () => Navigator.of(context).push<bool>(
            MaterialPageRoute<bool>(
              builder: (_) => MissionFormPage.edit(
                missionService: MissionService(repository),
                detail: detail ?? exampleDetail(),
              ),
            ),
          ),
          child: const Text('打开编辑'),
        ),
      ),
    ),
  );
  await tester.tap(find.text('打开编辑'));
  await tester.pumpAndSettle();
}

Future<void> enter(WidgetTester tester, String key, String text) async {
  final field = find.byKey(ValueKey(key));
  await tester.ensureVisible(field);
  await tester.pumpAndSettle();
  await tester.enterText(field, text);
}

void main() {
  testWidgets('固定排期按原时区带入，只改文字不丢失原时刻秒与毫秒', (tester) async {
    final repository = EditingRepository();
    final source = exampleDetail();
    final start = DateTime.utc(2026, 10, 23, 1, 15, 12, 345);
    final detail = MissionDetail(
      mission: source.mission,
      executionPlan: source.executionPlan,
      schedule: MissionScheduleRevision(
        id: 'fixed-original',
        missionId: source.mission.id,
        revisionNumber: 3,
        scheduledDate: '2026-10-22',
        timeZone: 'America/Los_Angeles',
        timePolicy: TimePolicy.fixed,
        fixedStartAt: start,
        plannedDurationMinutes: 20,
        changedAt: source.mission.createdAt,
      ),
    );
    await openEditor(tester, repository, detail: detail);
    expect(find.text('10月22日'), findsOneWidget);
    await tester.ensureVisible(find.byKey(const ValueKey('mission-hour')));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<TextField>(find.byKey(const ValueKey('mission-hour')))
          .controller!
          .text,
      '18',
    );
    expect(
      tester
          .widget<TextField>(find.byKey(const ValueKey('mission-minute')))
          .controller!
          .text,
      '15',
    );
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('mission-title')),
      -200,
      scrollable: find.byType(Scrollable).first,
    );
    await enter(tester, 'mission-title', '只修改名称');
    await tester.tap(find.text('保存修改'));
    await tester.pump();
    expect(repository.edits.single.timeZone, 'America/Los_Angeles');
    expect(repository.edits.single.fixedStartAt, start);
    repository.saving.complete();
    await tester.pumpAndSettle();
  });

  testWidgets('原值带入，未修改直接返回，不误报有未保存输入', (tester) async {
    final repository = EditingRepository();
    await openEditor(tester, repository);
    expect(find.text('编辑任务'), findsOneWidget);
    expect(
      tester
          .widget<TextField>(find.byKey(const ValueKey('mission-title')))
          .controller!
          .text,
      '阅读二十分钟',
    );
    expect(
      tester
          .widget<TextField>(find.byKey(const ValueKey('mission-objective')))
          .controller!
          .text,
      '能说明完整读取过程',
    );
    await tester.tap(find.byTooltip('返回'));
    await tester.pumpAndSettle();
    expect(find.byType(MissionFormPage), findsNothing);
    expect(repository.edits, isEmpty);
  });

  testWidgets('修改后系统返回与页面返回共用确认，继续保留草稿，放弃不保存', (tester) async {
    final repository = EditingRepository();
    await openEditor(tester, repository);
    await enter(tester, 'mission-title', '新名称');
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('放弃本次修改？'), findsOneWidget);
    await tester.tap(find.text('继续填写'));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<TextField>(find.byKey(const ValueKey('mission-title')))
          .controller!
          .text,
      '新名称',
    );
    await tester.tap(find.byTooltip('返回'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('放弃修改'));
    await tester.pumpAndSettle();
    expect(find.byType(MissionFormPage), findsNothing);
    expect(repository.edits, isEmpty);
  });

  testWidgets('保存等待防重复和返回，失败保留输入可重试，成功只返回原页', (tester) async {
    final repository = EditingRepository();
    await openEditor(tester, repository);
    await enter(tester, 'mission-title', '修改名称');
    await enter(tester, 'mission-objective', '修改目标');
    await tester.tap(find.text('保存修改'));
    await tester.pump();
    expect(find.text('正在保存…'), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, '正在保存…'))
          .onPressed,
      isNull,
    );
    await tester.binding.handlePopRoute();
    await tester.pump();
    expect(find.byType(MissionFormPage), findsOneWidget);
    repository.saving.completeError(Exception('模拟失败'));
    await tester.pumpAndSettle();
    expect(find.text('保存失败，输入已保留，请重试'), findsOneWidget);
    expect(repository.titles, ['修改名称']);
    expect(repository.objectives, ['修改目标']);
    repository.saving = Completer<void>();
    await tester.tap(find.text('保存修改'));
    await tester.pump();
    repository.saving.complete();
    await tester.pumpAndSettle();
    expect(repository.edits, hasLength(2));
    expect(find.byType(MissionFormPage), findsNothing);
    expect(find.text('打开编辑'), findsOneWidget);
  });

  testWidgets('冲突显示可操作原因并保留修改，不假装保存成功', (tester) async {
    final repository = EditingRepository();
    await openEditor(tester, repository);
    await enter(tester, 'mission-title', '旧表单修改');
    await tester.tap(find.text('保存修改'));
    await tester.pump();
    repository.saving.completeError(
      const MissionEditConflict('任务已被修改，请返回详情刷新'),
    );
    await tester.pumpAndSettle();
    expect(find.text('任务已被修改，请返回详情刷新'), findsOneWidget);
    expect(find.byType(MissionFormPage), findsOneWidget);
    expect(
      tester
          .widget<TextField>(find.byKey(const ValueKey('mission-title')))
          .controller!
          .text,
      '旧表单修改',
    );
  });

  testWidgets('320宽双倍字体下编辑目标、日期及按钮无溢出', (tester) async {
    tester.view.physicalSize = const Size(320, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await openEditor(tester, EditingRepository(), scale: 2);
    await enter(tester, 'mission-objective', '窄屏中保留完整具体目标和输入');
    await tester.ensureVisible(find.byKey(const ValueKey('mission-date')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('mission-date')));
    await tester.pumpAndSettle();
    expect(find.byType(CalendarDatePicker), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('真实列表进入编辑，改到明天后详情读回新版，原日期移除且明天可见', (tester) async {
    final database = AppDatabase(executor: NativeDatabase.memory());
    final repository = DriftMissionRepository(database);
    final service = MissionService(repository);
    await tester.runAsync(
      () => service.create(
        title: '原任务',
        scheduledDate: '2026-10-23',
        timeZone: 'Asia/Shanghai',
        plannedDurationMinutes: 20,
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        locale: const Locale('zh', 'CN'),
        supportedLocales: const [Locale('zh', 'CN')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        home: Scaffold(
          body: TodayPage(
            missionService: service,
            clock: () => DateTime.utc(2026, 10, 23, 7),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('原任务'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const Key('edit-mission')),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.byKey(const Key('edit-mission')));
    await tester.pumpAndSettle();
    await enter(tester, 'mission-title', '明天的新任务');
    await enter(tester, 'mission-objective', '明天的新目标');
    await tester.ensureVisible(find.byKey(const ValueKey('mission-date')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('mission-date')));
    await tester.pumpAndSettle();
    tester
        .widget<CalendarDatePicker>(find.byType(CalendarDatePicker))
        .onDateChanged(DateTime.utc(2026, 10, 24));
    await tester.pumpAndSettle();
    await tester.tap(find.text('保存修改'));
    await tester.pumpAndSettle();
    expect(find.byType(MissionDetailPage), findsOneWidget);
    expect(find.byType(MissionFormPage), findsNothing);
    expect(find.text('明天的新任务'), findsOneWidget);
    expect(find.text('明天的新目标'), findsOneWidget);
    final stored = await tester.runAsync(
      () => repository.findScheduledOn('2026-10-24'),
    );
    expect(stored!.single.schedule.revisionNumber, 2);
    await tester.tap(find.byTooltip('返回'));
    await tester.pumpAndSettle();
    expect(find.text('明天的新任务'), findsNothing);
    await tester.tap(find.byKey(const Key('today-date-picker')));
    await tester.pumpAndSettle();
    tester
        .widget<CalendarDatePicker>(find.byType(CalendarDatePicker))
        .onDateChanged(DateTime.utc(2026, 10, 24));
    await tester.tap(find.text('确定'));
    await tester.pumpAndSettle();
    expect(find.text('明天的新任务'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    final closing = database.close();
    await tester.pumpAndSettle();
    await closing;
  });
}

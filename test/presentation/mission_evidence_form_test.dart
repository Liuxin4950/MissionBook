import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mission_book/application/missions/mission_service.dart';
import 'package:mission_book/core/theme/app_theme.dart';
import 'package:mission_book/data/local/app_database.dart';
import 'package:mission_book/data/repositories/drift_mission_repository.dart';
import 'package:mission_book/presentation/missions/form/mission_form_page.dart';

void main() {
  late AppDatabase database;
  late MissionService service;

  setUp(() {
    database = AppDatabase(executor: NativeDatabase.memory());
    service = MissionService(DriftMissionRepository(database));
  });

  tearDown(() async {
    await service.dispose();
    await database.close();
  });

  Future<void> openForm(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        locale: const Locale('zh', 'CN'),
        supportedLocales: const [Locale('zh', 'CN')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => Navigator.of(context).push<void>(
                MaterialPageRoute(
                  builder: (_) => MissionFormPage(
                    missionService: service,
                    initialScheduledDate: '2050-01-15',
                  ),
                ),
              ),
              child: const Text('打开新建'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('打开新建'));
    await tester.pumpAndSettle();
  }

  Future<void> fillBasics(WidgetTester tester) async {
    await tester.enterText(
      find.byKey(const ValueKey('mission-title')),
      '验证事务回滚',
    );
    await tester.enterText(
      find.byKey(const ValueKey('mission-duration')),
      '20',
    );
  }

  testWidgets('默认可选材料不制造空白新建草稿，未填写即可返回', (tester) async {
    await openForm(tester);
    await tester.tap(find.byTooltip('返回'));
    await tester.pumpAndSettle();

    expect(find.text('打开新建'), findsOneWidget);
    expect(find.text('放弃本次填写？'), findsNothing);
    expect(await database.select(database.missions).get(), isEmpty);
  });

  testWidgets('普通任务仅填基本信息可保存为材料可选，验收说明允许为空', (tester) async {
    await openForm(tester);
    expect(find.text('材料说明（选填）'), findsOneWidget);
    expect(find.text('材料说明（选填） *'), findsNothing);
    await fillBasics(tester);
    await tester.tap(find.byType(FilledButton));
    await tester.pumpAndSettle();

    expect(find.text('任务已创建，可返回今天页'), findsOneWidget);
    final mission = (await database.select(database.missions).get()).single;
    final plan = (await database.select(database.executionPlans).get()).single;
    final schedule =
        (await database.select(database.missionScheduleRevisions).get()).single;
    expect(mission.verificationPolicy, 'OPTIONAL_EVIDENCE');
    expect(plan.verificationCriteria, isNull);
    expect(schedule.evidenceDeadlineAt, isNull);
  });

  testWidgets('强制材料默认截止可见且要求填写验收内容，输入保留后能完成保存', (tester) async {
    await openForm(tester);
    await fillBasics(tester);
    final requiredOption = find.byKey(
      const ValueKey('mission-evidence-policy-requiredEvidence'),
    );
    await tester.scrollUntilVisible(
      requiredOption,
      150,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(requiredOption);
    await tester.pumpAndSettle();
    expect(find.text('材料要求 *'), findsOneWidget);
    expect(find.text('2050年1月16日'), findsOneWidget);

    await tester.tap(find.byType(FilledButton));
    await tester.pumpAndSettle();
    expect(find.text('请填写需要提交什么材料，便于之后核对'), findsOneWidget);
    expect(await database.select(database.missions).get(), isEmpty);

    final criteria = find.byKey(const ValueKey('mission-evidence-criteria'));
    await tester.ensureVisible(criteria);
    await tester.enterText(criteria, '提供运行截图，展示第二次写入失败后全部回滚');
    await tester.tap(find.byType(FilledButton));
    await tester.pumpAndSettle();

    final mission = (await database.select(database.missions).get()).single;
    final schedule =
        (await database.select(database.missionScheduleRevisions).get()).single;
    expect(mission.verificationPolicy, 'REQUIRED_EVIDENCE');
    // 排期时区 Asia/Shanghai 的 2050-01-16 00:00，对应前一天 16:00 UTC。
    expect(
      schedule.evidenceDeadlineAt,
      DateTime.utc(2050, 1, 15, 16).millisecondsSinceEpoch,
    );
  });
}

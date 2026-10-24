import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mission_book/application/missions/mission_service.dart';
import 'package:mission_book/core/theme/app_theme.dart';
import 'package:mission_book/data/local/app_database.dart';
import 'package:mission_book/data/repositories/drift_mission_repository.dart';
import 'package:mission_book/domain/entities/execution_command.dart';
import 'package:mission_book/domain/entities/execution_event.dart';
import 'package:mission_book/domain/entities/mission_phase.dart';
import 'package:mission_book/presentation/missions/detail/mission_detail_page.dart';
import '../data/repositories/mission_cancellation_test.dart' show seedMission;

class LostResponseRepository extends DriftMissionRepository {
  LostResponseRepository(super.database, {required super.clock});
  bool loseResponse = true;
  ExecutionEventType loseType = ExecutionEventType.extend;
  final ids = <String>[];
  @override
  Future<ExecutionEvent> execute(ExecutionCommand command) async {
    ids.add(command.id);
    final result = await super.execute(command);
    if (command.type == loseType && loseResponse) {
      loseResponse = false;
      throw StateError('测试：提交成功但响应丢失');
    }
    return result;
  }
}

void main() {
  late AppDatabase database;
  late DriftMissionRepository repository;
  late MissionService service;
  late DateTime now;
  setUp(() async {
    now = DateTime.utc(2026, 10, 23, 6);
    database = AppDatabase(executor: NativeDatabase.memory());
    repository = DriftMissionRepository(database, clock: () => now);
    service = MissionService(repository);
    await seedMission(repository, 'a');
  });
  tearDown(() async {
    await service.dispose();
    await database.close();
  });

  Future<void> open(WidgetTester tester, {double scale = 1}) async {
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
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
        home: MissionDetailPage(missionId: 'a', missionService: service),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> tap(WidgetTester tester, String key) async {
    final finder = find.byKey(Key(key));
    if (finder.evaluate().isEmpty) {
      await tester.scrollUntilVisible(
        finder,
        160,
        scrollable: find
            .descendant(
              of: find.byKey(const Key('mission-execution-list')),
              matching: find.byType(Scrollable),
            )
            .first,
      );
    }
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  testWidgets('真实开始→暂停→暂停中延长→继续→报告完成→只读结果', (tester) async {
    await open(tester);
    await tap(tester, 'execution-start');
    expect((await repository.findDetail('a'))!.phase, MissionPhase.running);
    expect(find.byKey(const Key('edit-mission')), findsNothing);
    expect(find.byKey(const Key('cancel-mission')), findsNothing);
    now = now.add(const Duration(minutes: 5));
    await tap(tester, 'execution-toggle');
    await tap(tester, 'execution-extend');
    final minutes = find.byKey(const Key('execution-minutes'));
    await tester.ensureVisible(minutes);
    await tester.pumpAndSettle();
    await tester.enterText(minutes, '15');
    await tester.ensureVisible(find.text('确认增加额度'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('确认增加额度'));
    await tester.pumpAndSettle();
    expect((await repository.findDetail('a'))!.phase, MissionPhase.paused);
    now = now.add(const Duration(minutes: 10));
    await tap(tester, 'execution-toggle');
    now = now.add(const Duration(minutes: 5));
    await tap(tester, 'execution-end');
    var detail = (await repository.findDetail('a'))!;
    expect(detail.events.last.type, ExecutionEventType.pause);
    expect(
      detail.events.where((e) => e.type == ExecutionEventType.end),
      isEmpty,
    );
    final confirm = tester.widget<FilledButton>(
      find.byKey(const Key('report-confirm')),
    );
    expect(confirm.onPressed, isNull);
    // 标准手机宽度下，双按钮标签完整放进一行，避免尾部单字换行挤出胶囊。
    for (final key in ['report-confirm', 'report-cancel']) {
      final label = find.descendant(
        of: find.byKey(Key(key)),
        matching: find.byType(Text),
      );
      final paragraph = tester.renderObject<RenderParagraph>(label);
      expect(
        paragraph.getMaxIntrinsicWidth(double.infinity),
        lessThanOrEqualTo(paragraph.size.width + .5),
      );
    }
    await tap(tester, 'report-completed');
    await tap(tester, 'report-confirm');
    detail = (await repository.findDetail('a'))!;
    expect(detail.phase, MissionPhase.closed);
    expect(detail.failures, isEmpty);
    expect(find.text('用户报告：已完成'), findsOneWidget);
    expect(find.byKey(const Key('execution-toggle')), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('取消报告保持暂停；未完成可以不填写原因并原子保存', (tester) async {
    await open(tester);
    await tap(tester, 'execution-start');
    await tap(tester, 'execution-end');
    await tap(tester, 'report-cancel');
    expect((await repository.findDetail('a'))!.phase, MissionPhase.paused);
    expect((await repository.findDetail('a'))!.events, hasLength(2));
    await tap(tester, 'execution-end');
    await tap(tester, 'report-not-completed');
    await tap(tester, 'report-confirm');
    final detail = (await repository.findDetail('a'))!;
    expect(detail.phase, MissionPhase.closed);
    expect(detail.failures, hasLength(1));
    expect(detail.failures.single.userReasonText, isNull);
    expect(find.text('用户报告：未完成'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('旧报告确认被拒绝，保留原因输入且不会结束已恢复任务', (tester) async {
    await open(tester);
    await tap(tester, 'execution-start');
    await tap(tester, 'execution-end');
    await tap(tester, 'report-not-completed');
    final reason = find.byKey(const Key('report-reason'));
    await tester.ensureVisible(reason);
    await tester.pumpAndSettle();
    await tester.enterText(reason, '保留这个草稿');
    final paused = (await repository.findDetail('a'))!;
    await service.execute(
      service.prepareExecution(detail: paused, type: ExecutionEventType.resume),
    );
    await tap(tester, 'report-confirm');
    expect((await repository.findDetail('a'))!.phase, MissionPhase.running);
    expect(find.text('保留这个草稿'), findsOneWidget);
    expect(find.textContaining('执行记录已变化'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('响应丢失后重试复用原身份，延长额度不会增加两次', (tester) async {
    await service.dispose();
    final lost = LostResponseRepository(database, clock: () => now);
    repository = lost;
    service = MissionService(lost);
    await open(tester);
    await tap(tester, 'execution-start');
    await tap(tester, 'execution-extend');
    await tester.ensureVisible(find.text('确认增加额度'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('确认增加额度'));
    await tester.pumpAndSettle();
    expect((await repository.findDetail('a'))!.events, hasLength(2));
    await tap(tester, 'execution-retry');
    expect(lost.ids[1], lost.ids[2]);
    expect((await repository.findDetail('a'))!.events, hasLength(2));
    expect(find.textContaining('已增加 10 分钟'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('窄屏双倍字体可报告未完成，无溢出且原因可滚动输入', (tester) async {
    await open(tester, scale: 2);
    tester.view.physicalSize = const Size(320, 640);
    await tester.pumpAndSettle();
    await tap(tester, 'execution-start');
    await tap(tester, 'execution-end');
    await tap(tester, 'report-not-completed');
    expect(tester.takeException(), isNull);
    await tap(tester, 'report-confirm');
    expect((await repository.findDetail('a'))!.phase, MissionPhase.closed);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('开始响应丢失保持详情；重试确认同一次START后才进入执行页', (tester) async {
    await service.dispose();
    final lost = LostResponseRepository(database, clock: () => now)
      ..loseType = ExecutionEventType.start;
    repository = lost;
    service = MissionService(lost);
    await open(tester);
    await tap(tester, 'execution-start');
    expect(find.byKey(const Key('mission-execution-page')), findsNothing);
    expect(find.text('保存未确认，请重试原操作，或重新读取状态；输入已保留。'), findsOneWidget);
    expect((await repository.findDetail('a'))!.events, hasLength(1));
    await tap(tester, 'execution-retry');
    expect(lost.ids[0], lost.ids[1]);
    expect((await repository.findDetail('a'))!.events, hasLength(1));
    expect(find.byKey(const Key('mission-execution-page')), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('报告中的系统返回保护草稿；放弃后只回暂停执行页，不生成END', (tester) async {
    await open(tester);
    await tap(tester, 'execution-start');
    await tap(tester, 'execution-end');
    await tap(tester, 'report-not-completed');
    await tester.enterText(find.byKey(const Key('report-reason')), '保留草稿');
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('放弃本次报告？'), findsOneWidget);
    await tester.tap(find.text('继续填写'));
    await tester.pumpAndSettle();
    expect(find.text('保留草稿'), findsOneWidget);
    await tap(tester, 'report-cancel');
    await tester.tap(find.text('放弃报告'));
    await tester.pumpAndSettle();
    expect(find.text('继续执行'), findsOneWidget);
    expect(find.byKey(const Key('report-confirm')), findsNothing);
    expect((await repository.findDetail('a'))!.phase, MissionPhase.paused);
    expect((await repository.findDetail('a'))!.events, hasLength(2));
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('已有运行任务时开始被拒绝；明确暂停对方后仍需手动开始当前任务', (tester) async {
    await seedMission(repository, 'b');
    final other = (await repository.findDetail('b'))!;
    await service.execute(
      service.prepareExecution(detail: other, type: ExecutionEventType.start),
    );
    await open(tester);
    await tap(tester, 'execution-start');
    expect(find.byKey(const Key('mission-execution-page')), findsNothing);
    expect((await repository.findDetail('a'))!.phase, MissionPhase.notStarted);
    await tester.ensureVisible(find.text('先暂停此任务'));
    await tester.tap(find.text('先暂停此任务'));
    await tester.pumpAndSettle();
    expect((await repository.findDetail('b'))!.phase, MissionPhase.paused);
    expect((await repository.findDetail('a'))!.phase, MissionPhase.notStarted);
    await tap(tester, 'execution-start');
    expect((await repository.findDetail('a'))!.phase, MissionPhase.running);
    expect(find.byKey(const Key('mission-execution-page')), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}

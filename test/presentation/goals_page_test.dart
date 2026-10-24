import 'dart:async';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mission_book/application/goals/goal_service.dart';
import 'package:mission_book/core/theme/app_theme.dart';
import 'package:mission_book/data/local/app_database.dart';
import 'package:mission_book/data/repositories/drift_goal_repository.dart';
import 'package:mission_book/domain/entities/goal.dart';
import 'package:mission_book/presentation/goals/goals_page.dart';

// 模拟提交前失败、提交后响应丢失，以及慢请求；仍执行真实数据库保存。
class _UncertainRepository extends DriftGoalRepository {
  _UncertainRepository(super.database);
  bool failBefore = false;
  bool loseReply = false;
  Completer<void>? gate;
  @override
  Future<void> create(Goal goal) async {
    if (gate != null) await gate!.future;
    if (failBefore) throw StateError('测试：写入前失败');
    await super.create(goal);
    if (loseReply) {
      loseReply = false;
      throw StateError('测试：成功响应丢失');
    }
  }
}

void main() {
  late AppDatabase db;
  late _UncertainRepository repository;
  late GoalService service;
  setUp(() {
    db = AppDatabase(executor: NativeDatabase.memory());
    repository = _UncertainRepository(db);
    service = GoalService(repository);
  });
  tearDown(() async {
    await service.dispose();
    await db.close();
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
        home: GoalsPage(service: service),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> tap(WidgetTester tester, String key) async {
    final finder = find.byKey(Key(key));
    await tester.ensureVisible(finder);
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  testWidgets('空列表→校验→保存→详情→返回列表→重建重读', (tester) async {
    await open(tester);
    expect(find.text('从一个想实现的目标开始'), findsOneWidget);
    await tap(tester, 'goal-create');
    await tap(tester, 'goal-save');
    expect(find.text('请填写目标名称'), findsOneWidget);
    await tester.enterText(
      find.byKey(const Key('goal-title-input')),
      '  独立开发 Flutter 应用  ',
    );
    await tester.enterText(
      find.byKey(const Key('goal-description-input')),
      '把业务流程做完整',
    );
    await tester.enterText(find.byKey(const Key('goal-why-input')), '想做自己的工具');
    await tap(tester, 'goal-save');
    expect(find.text('目标详情'), findsOneWidget);
    expect(find.text('独立开发 Flutter 应用'), findsOneWidget);
    await tap(tester, 'goal-description-toggle');
    expect(find.text('想做自己的工具'), findsOneWidget);
    await tester.tap(find.byTooltip('返回'));
    await tester.pumpAndSettle();
    final goal = (await service.findAll()).single;
    expect(find.byKey(Key('goal-${goal.id}')), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await open(tester);
    await tap(tester, 'goal-${goal.id}');
    expect(find.text('目标详情'), findsOneWidget);
  });

  testWidgets('系统返回保留或放弃草稿，放弃不写入', (tester) async {
    await open(tester);
    await tap(tester, 'goal-create');
    await tester.enterText(find.byKey(const Key('goal-title-input')), '未保存目标');
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    await tester.tap(find.text('继续填写'));
    await tester.pumpAndSettle();
    expect(find.text('未保存目标'), findsOneWidget);
    await tester.tap(find.byTooltip('返回'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('离开'));
    await tester.pumpAndSettle();
    expect(await service.findAll(), isEmpty);
  });

  testWidgets('写入前失败保留输入，可确认未保存后继续编辑', (tester) async {
    repository.failBefore = true;
    await open(tester);
    await tap(tester, 'goal-create');
    await tester.enterText(find.byKey(const Key('goal-title-input')), '原目标');
    await tap(tester, 'goal-save');
    expect(find.textContaining('暂时未能确认保存结果'), findsOneWidget);
    await tester.tap(find.text('确认结果并继续编辑'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('goal-title-input')), '调整后的目标');
    repository.failBefore = false;
    await tap(tester, 'goal-save');
    expect((await service.findAll()).single.title, '调整后的目标');
  });

  testWidgets('提交后响应丢失，重试同一请求只创建一个目标', (tester) async {
    repository.loseReply = true;
    await open(tester);
    await tap(tester, 'goal-create');
    await tester.enterText(find.byKey(const Key('goal-title-input')), '稳定请求');
    await tap(tester, 'goal-save');
    expect(find.text('重试保存'), findsOneWidget);
    expect(await service.findAll(), hasLength(1));
    await tap(tester, 'goal-save');
    expect(find.text('目标详情'), findsOneWidget);
    expect(await service.findAll(), hasLength(1));
  });

  testWidgets('保存期间阻止重复点击和返回；窄屏大字体可滚动完成', (tester) async {
    await open(tester, scale: 2);
    await tap(tester, 'goal-create');
    await tester.enterText(
      find.byKey(const Key('goal-title-input')),
      '长一点的目标名称，循序渐进学习',
    );
    repository.gate = Completer<void>();
    await tap(tester, 'goal-save');
    expect(find.text('正在保存…'), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('新建目标'), findsOneWidget);
    repository.gate!.complete();
    await tester.pumpAndSettle();
    expect(find.text('目标详情'), findsOneWidget);
    expect(await service.findAll(), hasLength(1));
    expect(tester.takeException(), isNull);
  });
}

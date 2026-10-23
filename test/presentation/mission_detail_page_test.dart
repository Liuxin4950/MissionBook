import 'package:mission_book/domain/entities/execution_command.dart';
import 'package:mission_book/domain/entities/execution_event.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mission_book/application/missions/mission_service.dart';
import 'package:mission_book/core/theme/app_theme.dart';
import 'package:mission_book/domain/entities/execution_plan.dart';
import 'package:mission_book/domain/entities/mission.dart';
import 'package:mission_book/domain/entities/mission_detail.dart';
import 'package:mission_book/domain/entities/mission_schedule_revision.dart';
import 'package:mission_book/domain/entities/scheduled_mission.dart';
import 'package:mission_book/domain/repositories/mission_repository.dart';
import 'package:mission_book/presentation/missions/mission_detail_page.dart';
import 'package:mission_book/presentation/widgets/app_confirm_dialog.dart';

// 由测试决定读取何时完成，才能观察等待、失败、重试、离页和乱序返回。
class DetailRepository implements MissionRepository {
  @override
  Future<ExecutionEvent> execute(ExecutionCommand command) =>
      throw UnsupportedError('本替身不执行任务');
  @override
  Future<List<MissionDetail>> findActive() async => [];
  @override
  Future<List<MissionDetail>> findFinished() async => [];
  @override
  Future<List<MissionDetail>> findCancelled() async => [];

  @override
  Future<void> edit({
    required MissionDetail original,
    required String title,
    required String objective,
    required MissionScheduleRevision schedule,
  }) => throw UnsupportedError('本测试不编辑任务');

  final ids = <String>[];
  final requests = <Completer<MissionDetail?>>[];
  final cancelIds = <String>[];
  final cancellations = <Completer<void>>[];

  @override
  Future<void> cancel(String missionId) {
    cancelIds.add(missionId);
    final request = Completer<void>();
    cancellations.add(request);
    return request.future;
  }

  @override
  Future<MissionDetail?> findDetail(String missionId) {
    ids.add(missionId);
    final request = Completer<MissionDetail?>();
    requests.add(request);
    return request.future;
  }

  @override
  Future<List<ScheduledMission>> findScheduledOn(String scheduledDate) =>
      throw UnsupportedError('详情测试不读取日期列表');

  @override
  Future<void> create({
    required Mission mission,
    required MissionScheduleRevision initialSchedule,
    required ExecutionPlan executionPlan,
  }) => throw UnsupportedError('详情页面不能创建任务');
}

MissionDetail exampleDetail({bool full = false, bool cancelled = false}) {
  final now = DateTime.utc(2026, 10, 23, 1);
  return MissionDetail(
    mission: Mission(
      id: 'detail-a',
      title: full ? '完整任务标题保留每一个字，即使在窄屏上也要自然换行供用户阅读' : '阅读二十分钟',
      description: full ? '真实说明' : null,
      why: full ? '理解数据的调用过程' : null,
      verificationPolicy: full
          ? VerificationPolicy.requiredEvidence
          : VerificationPolicy.selfReport,
      createdAt: now,
      updatedAt: now,
      cancelledAt: cancelled ? now : null,
    ),
    schedule: MissionScheduleRevision(
      id: 'schedule-2',
      missionId: 'detail-a',
      revisionNumber: 2,
      scheduledDate: full ? '2026-10-22' : '2026-10-23',
      timeZone: full ? 'America/Los_Angeles' : 'Asia/Shanghai',
      timePolicy: full ? TimePolicy.fixed : TimePolicy.flexible,
      fixedStartAt: full ? now : null,
      evidenceDeadlineAt: full ? now.add(const Duration(days: 1)) : null,
      plannedDurationMinutes: 20,
      changedAt: now,
    ),
    executionPlan: ExecutionPlan(
      id: 'plan-a',
      missionId: 'detail-a',
      objective: '能说明完整读取过程',
      steps: full ? ['从任务编号开始', '读回当前排期与方案'] : [],
      verificationCriteria: full ? '能追踪一次真实查询' : null,
      notes: full ? '来自保存的补充说明' : null,
      createdAt: now,
      updatedAt: now,
    ),
  );
}

Widget testApp(
  MissionService missionService, {
  String id = 'detail-a',
  double textScale = 1,
}) {
  return MaterialApp(
    theme: AppTheme.light,
    locale: const Locale('zh', 'CN'),
    supportedLocales: const [Locale('zh', 'CN')],
    localizationsDelegates: GlobalMaterialLocalizations.delegates,
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(
        context,
      ).copyWith(textScaler: TextScaler.linear(textScale)),
      child: child!,
    ),
    home: MissionDetailPage(missionId: id, missionService: missionService),
  );
}

Future<void> openLoadedDetail(
  WidgetTester tester,
  DetailRepository repository, {
  double textScale = 1,
}) async {
  await tester.pumpWidget(
    testApp(MissionService(repository), textScale: textScale),
  );
  repository.requests.single.complete(exampleDetail());
  await tester.pumpAndSettle();
  await tester.pumpAndSettle();
}

Future<void> chooseMissionAction(WidgetTester tester, String action) async {
  await tester.tap(find.byKey(Key('$action-mission')));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('一次读取后显示自选详情，隐藏未填写内容和未实现动作；重建不重复查询', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repository = DetailRepository();
    final missionService = MissionService(repository);
    await tester.pumpWidget(testApp(missionService));
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(repository.ids, ['detail-a']);
    repository.requests.single.complete(exampleDetail());
    await tester.pumpAndSettle();
    expect(find.text('阅读二十分钟'), findsOneWidget);
    // 详情和新建共用同一顶栏；正常手机宽度下按钮位置、触控尺寸及标题中线一致。
    final backRect = tester.getRect(
      find.widgetWithIcon(IconButton, Icons.arrow_back),
    );
    expect(backRect.size, const Size(48, 48));
    expect(backRect.left, 24);
    expect(
      tester.widget<Icon>(find.byIcon(Icons.arrow_back)).color,
      AppTheme.light.colorScheme.onPrimary,
    );
    expect(tester.getRect(find.text('任务详情')).center.dx, closeTo(195, 1));
    expect(find.text('待开始'), findsOneWidget);
    final badge = tester.getRect(find.byKey(const Key('mission-phase')));
    expect(badge.left, greaterThan(tester.getRect(find.text('阅读二十分钟')).right));
    final start = tester.getRect(find.byKey(const Key('execution-start')));
    final list = tester.getRect(find.byKey(const Key('mission-detail-list')));
    expect(start.top, greaterThanOrEqualTo(list.bottom));
    expect(start.bottom, lessThanOrEqualTo(844));
    expect(find.text('自选时间'), findsOneWidget);
    expect(find.text('10月23日'), findsOneWidget);
    expect(find.text('计划'), findsOneWidget);
    expect(find.text('20 分'), findsOneWidget);
    // 手机常规字号下日期在左、计划在右，标签与数值分别在同一水平线上。
    expect(
      tester.getTopLeft(find.text('自选时间')).dy,
      tester.getTopLeft(find.text('计划')).dy,
    );
    expect(
      tester.getTopLeft(find.text('10月23日')).dy,
      tester.getTopLeft(find.text('20 分')).dy,
    );
    expect(
      tester.getTopLeft(find.text('10月23日')).dx,
      lessThan(tester.getTopLeft(find.text('20 分')).dx),
    );
    expect(find.byIcon(Icons.calendar_today_outlined), findsOneWidget);
    expect(find.byIcon(Icons.access_time), findsOneWidget);
    expect(find.textContaining('当前排期'), findsNothing);
    expect(find.textContaining('排期时区'), findsNothing);
    expect(tester.takeException(), isNull);
    expect(find.text('能说明完整读取过程'), findsOneWidget);
    for (final absent in [
      '任务说明',
      '为什么现在做',
      '行动步骤',
      '验收方向',
      '补充说明',
      '材料截止',
      '编辑',
    ]) {
      expect(find.text(absent), findsNothing);
    }
    expect(find.byKey(const Key('edit-mission')), findsOneWidget);
    expect(find.byKey(const Key('cancel-mission')), findsOneWidget);
    expect(find.text('取消任务'), findsOneWidget);
    await tester.pumpWidget(testApp(missionService));
    await tester.pump();
    expect(repository.ids, ['detail-a']);
  });

  testWidgets('重复触发只弹一次确认，保留/遮罩/系统返回均不写入或重复查询', (tester) async {
    final repository = DetailRepository();
    await openLoadedDetail(tester, repository);
    final action = tester
        .widget<TextButton>(find.byKey(const Key('cancel-mission')))
        .onPressed!;
    action();
    action();
    await tester.pumpAndSettle();
    expect(find.byType(AppConfirmDialog), findsOneWidget);
    await tester.tap(find.text('保留任务'));
    await tester.pumpAndSettle();
    for (final systemBack in [false, true]) {
      await tester.pumpAndSettle();
      await chooseMissionAction(tester, 'cancel');
      await tester.pumpAndSettle();
      if (systemBack) {
        await tester.binding.handlePopRoute();
      } else {
        await tester.tapAt(const Offset(4, 4));
      }
      await tester.pumpAndSettle();
      expect(find.byType(AppConfirmDialog), findsNothing);
      expect(find.text('待开始'), findsOneWidget);
    }
    expect(repository.cancelIds, isEmpty);
    expect(repository.requests, hasLength(1));
  });

  testWidgets('等待取消保存时禁止重复点击和离页，成功后重读真实取消事实', (tester) async {
    final repository = DetailRepository();
    final service = MissionService(repository);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => MissionDetailPage(
                  missionId: 'detail-a',
                  missionService: service,
                ),
              ),
            ),
            child: const Text('打开详情'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('打开详情'));
    await tester.pump();
    repository.requests.single.complete(exampleDetail());
    await tester.pumpAndSettle();
    await tester.pumpAndSettle();
    await chooseMissionAction(tester, 'cancel');
    await tester.pumpAndSettle();
    await tester.tap(find.text('确认取消'));
    await tester.pumpAndSettle();
    expect(repository.cancelIds, ['detail-a']);
    expect(find.text('正在取消…'), findsOneWidget);
    expect(
      tester
          .widget<TextButton>(find.byKey(const Key('cancel-mission')))
          .onPressed,
      isNull,
    );
    expect(
      tester
          .widget<IconButton>(find.widgetWithIcon(IconButton, Icons.arrow_back))
          .onPressed,
      isNull,
    );
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byType(MissionDetailPage), findsOneWidget);
    expect(repository.requests, hasLength(1));
    repository.cancellations.single.complete();
    await tester.pump();
    expect(repository.requests, hasLength(2));
    repository.requests.last.complete(exampleDetail(cancelled: true));
    await tester.pumpAndSettle();
    expect(find.text('已取消'), findsOneWidget);
    expect(find.text('取消时间'), findsOneWidget);
    expect(find.text('没有执行记录'), findsOneWidget);
    expect(find.byKey(const Key('cancel-mission')), findsNothing);
    await tester.tap(find.byTooltip('返回'));
    await tester.pumpAndSettle();
    expect(find.text('打开详情'), findsOneWidget);
  });

  testWidgets('取消失败保留原详情，可再次确认重试且只提交当前任务', (tester) async {
    final repository = DetailRepository();
    await openLoadedDetail(tester, repository);
    await tester.pumpAndSettle();
    await chooseMissionAction(tester, 'cancel');
    await tester.pumpAndSettle();
    await tester.tap(find.text('确认取消'));
    await tester.pumpAndSettle();
    repository.cancellations.single.completeError(StateError('模拟取消保存失败'));
    await tester.pumpAndSettle();
    expect(find.text('取消失败，请重试'), findsOneWidget);
    expect(find.text('待开始'), findsOneWidget);
    expect(repository.requests, hasLength(1));
    expect(
      tester
          .widget<TextButton>(find.byKey(const Key('cancel-mission')))
          .onPressed,
      isNotNull,
    );
    await tester.pumpAndSettle();
    await chooseMissionAction(tester, 'cancel');
    await tester.pumpAndSettle();
    await tester.tap(find.text('确认取消'));
    await tester.pumpAndSettle();
    expect(repository.cancelIds, ['detail-a', 'detail-a']);
    repository.cancellations.last.complete();
    await tester.pump();
    repository.requests.last.complete(exampleDetail(cancelled: true));
    await tester.pumpAndSettle();
    expect(find.text('已取消'), findsOneWidget);
    expect(find.text('取消失败，请重试'), findsNothing);
  });

  testWidgets('保存已成功但重新读取失败时显示读取错误，重试只读取不再次取消', (tester) async {
    final repository = DetailRepository();
    await openLoadedDetail(tester, repository);
    await tester.pumpAndSettle();
    await chooseMissionAction(tester, 'cancel');
    await tester.pumpAndSettle();
    await tester.tap(find.text('确认取消'));
    await tester.pumpAndSettle();
    repository.cancellations.single.complete();
    await tester.pump();
    repository.requests.last.completeError(StateError('写入后查询失败'));
    await tester.pumpAndSettle();
    expect(find.text('任务详情读取失败，请重试'), findsOneWidget);
    expect(find.text('取消失败，请重试'), findsNothing);
    await tester.tap(find.text('重新读取'));
    await tester.pump();
    repository.requests.last.complete(exampleDetail(cancelled: true));
    await tester.pumpAndSettle();
    expect(find.text('已取消'), findsOneWidget);
    expect(repository.cancelIds, ['detail-a']);
  });

  testWidgets('确认期间换任务不提交旧选择，写入期间换任务忽略旧错误', (tester) async {
    final repository = DetailRepository();
    final service = MissionService(repository);
    await tester.pumpWidget(testApp(service));
    repository.requests.single.complete(exampleDetail());
    await tester.pumpAndSettle();
    await tester.pumpAndSettle();
    await chooseMissionAction(tester, 'cancel');
    await tester.pumpAndSettle();
    await tester.pumpWidget(testApp(service, id: 'detail-b'));
    repository.requests.last.complete(exampleDetail());
    await tester.pumpAndSettle();
    await tester.tap(find.text('确认取消'));
    await tester.pumpAndSettle();
    expect(repository.cancelIds, isEmpty);
    await tester.pumpAndSettle();
    await chooseMissionAction(tester, 'cancel');
    await tester.pumpAndSettle();
    await tester.tap(find.text('确认取消'));
    await tester.pumpAndSettle();
    expect(repository.cancelIds, ['detail-b']);
    await tester.pumpWidget(testApp(service, id: 'detail-c'));
    repository.requests.last.complete(null);
    await tester.pumpAndSettle();
    repository.cancellations.single.completeError(StateError('旧任务的错误'));
    await tester.pumpAndSettle();
    expect(find.text('未找到这个任务，请返回列表刷新'), findsOneWidget);
    expect(find.text('取消失败，请重试'), findsNothing);
    expect(repository.requests, hasLength(3));
    expect(tester.takeException(), isNull);
  });

  testWidgets('取消期间组件被移除，迟到错误不触发失效更新', (tester) async {
    final repository = DetailRepository();
    await openLoadedDetail(tester, repository);
    await tester.pumpAndSettle();
    await chooseMissionAction(tester, 'cancel');
    await tester.pumpAndSettle();
    await tester.tap(find.text('确认取消'));
    await tester.pumpAndSettle();
    await tester.pumpWidget(const SizedBox.shrink());
    repository.cancellations.single.completeError(StateError('离页后的错误'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('320宽双倍字体可滚动操作取消，读屏保留操作名称', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final semantics = tester.ensureSemantics();
    try {
      final repository = DetailRepository();
      await openLoadedDetail(tester, repository, textScale: 2);
      expect(find.bySemanticsLabel('取消任务'), findsOneWidget);
      await tester.pumpAndSettle();
      await chooseMissionAction(tester, 'cancel');
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('保留任务'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('保留任务'));
      await tester.pumpAndSettle();
      expect(repository.cancelIds, isEmpty);
      expect(tester.takeException(), isNull);
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('读取失败可重试；未找到显示独立提示，不能混成读取失败', (tester) async {
    final repository = DetailRepository();
    await tester.pumpWidget(testApp(MissionService(repository)));
    repository.requests.single.completeError(StateError('模拟数据库失败'));
    await tester.pumpAndSettle();
    expect(find.text('任务详情读取失败，请重试'), findsOneWidget);
    await tester.tap(find.text('重新读取'));
    await tester.pump();
    expect(repository.ids, ['detail-a', 'detail-a']);
    repository.requests.last.complete(null);
    await tester.pumpAndSettle();
    expect(find.text('未找到这个任务，请返回列表刷新'), findsOneWidget);
    expect(find.text('重新读取'), findsNothing);
  });

  testWidgets('窄屏大字体保留完整标题与步骤，按记录时区显示固定开始、截止及取消事实', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repository = DetailRepository();
    final detail = exampleDetail(full: true, cancelled: true);
    await tester.pumpWidget(testApp(MissionService(repository), textScale: 2));
    repository.requests.single.complete(detail);
    await tester.pumpAndSettle();
    final title = tester.widget<Text>(find.text(detail.mission.title));
    expect(title.maxLines, isNull);
    expect(title.overflow, isNull);
    expect(find.text('已取消'), findsOneWidget);
    // UTC 10月23日01:00，在洛杉矶还是10月22日18:00，不能用本机时区代替。
    await tester.scrollUntilVisible(
      find.text('固定时间'),
      180,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('10月22日 18:00'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('计划')).dy,
      greaterThan(tester.getBottomLeft(find.text('10月22日 18:00')).dy),
    );
    await tester.scrollUntilVisible(
      find.text('为什么做'),
      220,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('为什么做'));
    await tester.pumpAndSettle();
    expect(find.text('理解数据的调用过程'), findsOneWidget);
    for (final label in [
      '从任务编号开始',
      '读回当前排期与方案',
      '2026-10-23 18:00',
      '2026-10-22 18:00',
    ]) {
      await tester.scrollUntilVisible(
        find.text(label),
        180,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text(label), findsOneWidget);
    }
    expect(find.text('尚未报告'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('换任务后忽略旧读取结果；关闭页面后返回的错误不触发失效更新', (tester) async {
    final repository = DetailRepository();
    final missionService = MissionService(repository);
    await tester.pumpWidget(testApp(missionService));
    await tester.pumpWidget(testApp(missionService, id: 'detail-b'));
    expect(repository.ids, ['detail-a', 'detail-b']);
    repository.requests.last.complete(null);
    await tester.pumpAndSettle();
    repository.requests.first.complete(exampleDetail());
    await tester.pumpAndSettle();
    expect(find.text('未找到这个任务，请返回列表刷新'), findsOneWidget);
    expect(find.text('阅读二十分钟'), findsNothing);

    await tester.pumpWidget(testApp(missionService, id: 'detail-c'));
    await tester.pumpWidget(const SizedBox.shrink());
    repository.requests.last.completeError(StateError('离开后的读取错误'));
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
}

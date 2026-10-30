import 'package:mission_book/domain/entities/mission_ownership.dart';
import 'package:mission_book/domain/entities/execution_command.dart';
import 'package:mission_book/domain/entities/execution_event.dart';
import 'package:mission_book/domain/entities/evidence.dart';
import 'dart:async';
import 'dart:ui' show SemanticsAction;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mission_book/core/theme/app_theme.dart';
import 'package:mission_book/application/missions/mission_service.dart';
import 'package:mission_book/domain/entities/execution_plan.dart';
import 'package:mission_book/domain/entities/mission.dart';
import 'package:mission_book/domain/entities/mission_schedule_revision.dart';
import 'package:mission_book/domain/repositories/mission_repository.dart';
import 'package:mission_book/domain/entities/scheduled_mission.dart';
import 'package:mission_book/domain/entities/mission_detail.dart';
import 'package:mission_book/presentation/missions/form/mission_form_page.dart';

// UTC 仍是 12 月 31 日，上海已跨年；默认日期测试不依赖运行当天。
DateTime _formClock() => DateTime.utc(2031, 12, 31, 16, 5);

// 用可控制完成时机的仓储替代磁盘，验证页面确实等待业务保存结果。
class PendingRepository implements MissionRepository {
  @override
  Future<List<String>> reconcileScheduledEnds() async => [];

  @override
  Future<List<String>> reconcileScheduledMissions() async => <String>[];

  @override
  Future<List<MissionGoalChoices>> findGoalChoices() async => [];
  @override
  Future<MissionOwnershipInfo?> findOwnershipInfo(
    MissionOwnership ownership,
  ) async => null;
  @override
  Future<List<MissionDetail>> findForGoal(String goalId) async => [];

  @override
  Future<ExecutionEvent> execute(ExecutionCommand command) =>
      throw UnsupportedError('本替身不执行任务');
  @override
  Future<List<MissionDetail>> findActive() async => [];
  @override
  Future<List<MissionDetail>> findFinished() async => [];
  @override
  Future<List<MissionDetail>> findAllDetails() async => [];
  @override
  Future<List<MissionDetail>> findCancelled() async => [];
  @override
  Future<List<MissionDetail>> findPendingEvidence() async => [];
  @override
  Future<int> reconcileEvidenceDeadlines() async => 0;
  @override
  Future<Set<String>> referencedAttachmentKeys() async => {};
  @override
  Future<EvidenceSubmissionResult> submitEvidence(
    EvidenceSubmission submission,
  ) => throw UnsupportedError('本替身不提交材料');
  @override
  Future<Evidence> correctEvidence(EvidenceCorrection correction) =>
      throw UnsupportedError('本替身不修正材料');
  @override
  Future<void> skipOptionalEvidence(String missionId) =>
      throw UnsupportedError('本替身不跳过材料');

  @override
  Future<void> edit({
    required MissionDetail original,
    required String title,
    required String objective,
    required MissionScheduleRevision schedule,
    ExecutionPlanContent? content,
    VerificationPolicy? verificationPolicy,
    String? verificationCriteria,
    MissionOwnership? ownership,
    String? description,
    String? why,
    bool updateContext = false,
    String? operationId,
  }) => throw UnsupportedError('本测试不编辑任务');

  @override
  Future<void> cancel(String missionId, {String? operationId}) =>
      throw UnsupportedError('创建表单测试不取消任务');

  @override
  Future<MissionDetail?> findDetail(String missionId) async => null;

  @override
  Future<List<ScheduledMission>> findScheduledOn(String scheduledDate) =>
      throw UnsupportedError('表单保存测试不调用查询');

  int calls = 0;
  MissionScheduleRevision? schedule;
  Completer<void> completion = Completer<void>();

  @override
  Future<void> create({
    required Mission mission,
    required MissionScheduleRevision initialSchedule,
    required ExecutionPlan executionPlan,
  }) {
    calls++;
    schedule = initialSchedule;
    return completion.future;
  }
}

Future<void> openForm(WidgetTester tester, PendingRepository repository) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light,
      home: MissionFormPage(
        missionService: MissionService(repository, clock: _formClock),
        clock: _formClock,
      ),
    ),
  );
  await tester.enterText(
    find.byKey(const ValueKey('mission-title')),
    '阅读 Flutter',
  );
  await tester.enterText(find.byKey(const ValueKey('mission-duration')), '20');
  await tester.ensureVisible(find.byType(FilledButton));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('输入框填写后仍有用途标签、当前值和编辑动作，且标签不重复', (tester) async {
    final semantics = tester.ensureSemantics();
    try {
      await tester.pumpWidget(
        MaterialApp(
          home: MissionFormPage(
            missionService: MissionService(PendingRepository()),
          ),
        ),
      );
      final labels = ['任务名称', '计划时长'];
      final values = ['阅读 Flutter', '20'];
      for (var index = 0; index < labels.length; index++) {
        final field = find.byType(TextField).at(index);
        await tester.ensureVisible(field);
        await tester.pumpAndSettle();
        await tester.enterText(field, values[index]);
        await tester.pumpAndSettle();
        final node = tester.getSemantics(find.byType(EditableText).at(index));
        final data = node.getSemanticsData();
        expect(data.label, contains(labels[index]));
        expect(data.value, values[index]);
        expect(data.hasAction(SemanticsAction.setText), isTrue);
        expect(find.bySemanticsLabel(RegExp(labels[index])), findsOneWidget);
      }
      await tester.pumpWidget(const SizedBox.shrink());
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('上海跨年默认日期，等待事务、防重复提交及成功锁定', (tester) async {
    final repository = PendingRepository();
    await openForm(tester, repository);
    const date = '2032-01-01';
    expect(find.text('2032年1月1日'), findsOneWidget);
    await tester.tap(find.byType(FilledButton));
    await tester.pump();
    expect(find.text('正在创建…'), findsOneWidget);
    expect(
      tester
          .widget<IconButton>(find.widgetWithIcon(IconButton, Icons.arrow_back))
          .onPressed,
      isNull,
    );
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNull,
    );
    await tester.tap(find.byType(FilledButton));
    await tester.pump();
    expect(repository.calls, 1);
    expect(repository.schedule!.timeZone, 'Asia/Shanghai');
    expect(repository.schedule!.scheduledDate, date);
    repository.completion.complete();
    await tester.pumpAndSettle();
    expect(find.text('任务已创建'), findsOneWidget);
    expect(find.text('继续新建'), findsOneWidget);
    expect(find.text('返回原页面'), findsOneWidget);
    expect(repository.calls, 1);
    for (final field in tester.widgetList<TextField>(find.byType(TextField))) {
      expect(field.enabled, isFalse);
    }
  });

  testWidgets('保存失败保留输入，并可再次提交', (tester) async {
    final repository = PendingRepository();
    await openForm(tester, repository);
    await tester.tap(find.byType(FilledButton));
    await tester.pump();
    repository.completion.completeError(StateError('模拟仓储失败'));
    await tester.pumpAndSettle();
    expect(find.text('保存失败，输入已保留，请重试'), findsOneWidget);
    expect(
      tester
          .widget<TextField>(find.byKey(const ValueKey('mission-title')))
          .controller!
          .text,
      '阅读 Flutter',
    );
    expect(
      tester
          .widget<TextField>(find.byKey(const ValueKey('mission-duration')))
          .controller!
          .text,
      '20',
    );
    repository.completion = Completer<void>();
    await tester.ensureVisible(find.byType(FilledButton));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(FilledButton));
    await tester.pump();
    expect(repository.calls, 2);
    repository.completion.complete();
    await tester.pumpAndSettle();
    expect(find.text('任务已创建'), findsOneWidget);
  });
  testWidgets('固定时刻按上海时间保存，失败后日期和时分保留；切回自选不带出旧时刻', (tester) async {
    final repository = PendingRepository();
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: MissionFormPage(
          missionService: MissionService(repository),
          initialScheduledDate: '2026-10-24',
        ),
      ),
    );
    await tester.enterText(find.byKey(const ValueKey('mission-title')), '固定任务');
    await tester.enterText(
      find.byKey(const ValueKey('mission-duration')),
      '45',
    );
    await tester.ensureVisible(find.text('固定'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('固定'));
    await tester.pumpAndSettle();
    // 没有填写时分不能用默认 00:00 静默保存。
    await tester.tap(find.byType(FilledButton));
    await tester.pumpAndSettle();
    expect(repository.calls, 0);
    expect(find.textContaining('请填写有效的开始时间'), findsOneWidget);
    for (final invalid in [('24', '00'), ('23', '60')]) {
      await tester.ensureVisible(find.byKey(const ValueKey('mission-hour')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('mission-hour')),
        invalid.$1,
      );
      await tester.enterText(
        find.byKey(const ValueKey('mission-minute')),
        invalid.$2,
      );
      await tester.tap(find.byType(FilledButton));
      await tester.pumpAndSettle();
      expect(repository.calls, 0);
    }
    await tester.enterText(find.byKey(const ValueKey('mission-hour')), '00');
    await tester.enterText(find.byKey(const ValueKey('mission-minute')), '15');
    await tester.tap(find.byType(FilledButton));
    await tester.pump();
    expect(repository.schedule!.timePolicy, TimePolicy.fixed);
    expect(
      repository.schedule!.fixedStartAt,
      DateTime.utc(2026, 10, 23, 16, 15),
    );
    expect(repository.schedule!.scheduledDate, '2026-10-24');
    expect(
      tester
          .widget<TextButton>(find.byKey(const ValueKey(TimePolicy.fixed)))
          .onPressed,
      isNull,
    );
    repository.completion.completeError(StateError('模拟保存失败'));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<TextField>(find.byKey(const ValueKey('mission-hour')))
          .controller!
          .text,
      '00',
    );
    expect(
      tester
          .widget<TextField>(find.byKey(const ValueKey('mission-minute')))
          .controller!
          .text,
      '15',
    );
    expect(find.text('2026年10月24日'), findsOneWidget);
    await tester.tap(find.text('检查保存结果'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('自选'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('自选'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('mission-hour')), findsNothing);
    repository.completion = Completer<void>();
    await tester.tap(find.byType(FilledButton));
    await tester.pump();
    expect(repository.schedule!.timePolicy, TimePolicy.flexible);
    expect(repository.schedule!.fixedStartAt, isNull);
    repository.completion.complete();
    await tester.pumpAndSettle();
  });

  testWidgets('非整数逻辑宽度下日历可打开、翻月、选日期并重新打开', (tester) async {
    // 1280 / 3 - 表单两侧48 = 378.666…，对应实机报错的月份页宽。
    tester.view.physicalSize = const Size(1280, 2800);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repository = PendingRepository();
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: MissionFormPage(
          missionService: MissionService(repository),
          initialScheduledDate: '2026-10-24',
        ),
      ),
    );
    final dateButton = find.byKey(const ValueKey('mission-date'));
    await tester.tap(dateButton);
    await tester.pumpAndSettle();
    expect(find.byType(CalendarDatePicker), findsOneWidget);
    await tester.ensureVisible(find.byType(CalendarDatePicker));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Next month'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('25').last);
    await tester.pumpAndSettle();
    expect(find.text('2026年11月25日'), findsOneWidget);
    expect(find.byType(CalendarDatePicker), findsNothing);
    await tester.ensureVisible(dateButton);
    await tester.tap(dateButton);
    await tester.pumpAndSettle();
    final calendar = tester.widget<CalendarDatePicker>(
      find.byType(CalendarDatePicker),
    );
    expect(calendar.initialDate, DateTime(2026, 11, 25));
    expect(calendar.firstDate.year, 1);
    expect(calendar.lastDate.year, 9999);
    expect(repository.calls, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('日期原位选择后，固定时刻使用新日期；成功后锁定日历', (tester) async {
    final repository = PendingRepository();
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: MissionFormPage(
          missionService: MissionService(repository),
          initialScheduledDate: '2026-10-24',
        ),
      ),
    );
    await tester.tap(find.byKey(const ValueKey('mission-date')));
    await tester.pumpAndSettle();
    expect(find.byType(CalendarDatePicker), findsOneWidget);
    await tester.ensureVisible(find.text('25').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('25').last);
    await tester.pumpAndSettle();
    expect(find.byType(CalendarDatePicker), findsNothing);
    expect(find.text('2026年10月25日'), findsOneWidget);
    await tester.enterText(find.byKey(const ValueKey('mission-title')), '改日期');
    await tester.enterText(
      find.byKey(const ValueKey('mission-duration')),
      '20',
    );
    await tester.ensureVisible(find.text('固定'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('固定'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('固定'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const ValueKey('mission-minute')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('mission-hour')), '23');
    await tester.enterText(find.byKey(const ValueKey('mission-minute')), '59');
    await tester.tap(find.byType(FilledButton));
    await tester.pump();
    expect(
      repository.schedule!.fixedStartAt,
      DateTime.utc(2026, 10, 25, 15, 59),
    );
    repository.completion.complete();
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const ValueKey('mission-date')));
    await tester.pumpAndSettle();
    expect(
      tester.widget<InkWell>(find.byKey(const ValueKey('mission-date'))).onTap,
      isNull,
    );
  });

  testWidgets('仅修改时间也触发丢弃确认，继续填写保留时分', (tester) async {
    final repository = PendingRepository();
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) =>
                    MissionFormPage(missionService: MissionService(repository)),
              ),
            ),
            child: const Text('打开表单'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('打开表单'));
    await tester.pumpAndSettle();
    // 空表单可以直接退出，不应打开确认框。
    await tester.tap(find.byTooltip('返回'));
    await tester.pumpAndSettle();
    expect(find.byType(MissionFormPage), findsNothing);
    await tester.tap(find.text('打开表单'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('固定'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('固定'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('mission-hour')), '14');
    await tester.tap(find.byTooltip('返回'));
    await tester.pumpAndSettle();
    expect(find.text('放弃本次填写？'), findsOneWidget);
    // 模拟弹框期间键盘/视口变化引起页面重建；继续后必须恢复编辑。
    addTearDown(tester.view.resetViewInsets);
    tester.view.viewInsets = const FakeViewPadding(bottom: 200);
    await tester.pumpAndSettle();
    tester.view.resetViewInsets();
    await tester.pumpAndSettle();
    tester.element(find.byType(MissionFormPage)).markNeedsBuild();
    await tester.pump();
    await tester.tap(find.text('继续填写'));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<TextField>(find.byKey(const ValueKey('mission-hour')))
          .enabled,
      isTrue,
    );
    expect(
      tester
          .widget<TextField>(find.byKey(const ValueKey('mission-hour')))
          .controller!
          .text,
      '14',
    );
    expect(repository.calls, 0);
    // 点击遮罩或系统返回只关确认框，表单时分和页面仍然保留。
    for (final systemBack in [false, true]) {
      await tester.tap(find.byTooltip('返回'));
      await tester.pumpAndSettle();
      if (systemBack) {
        await tester.binding.handlePopRoute();
      } else {
        await tester.tapAt(const Offset(4, 4));
      }
      await tester.pumpAndSettle();
      expect(find.text('放弃本次填写？'), findsNothing);
      expect(find.byType(MissionFormPage), findsOneWidget);
      expect(
        tester
            .widget<TextField>(find.byKey(const ValueKey('mission-hour')))
            .controller!
            .text,
        '14',
      );
      expect(repository.calls, 0);
    }
    // 共用顶栏仍分发到表单的丢弃确认；明确放弃后才关闭页面。
    await tester.tap(find.byTooltip('返回'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('放弃填写'));
    await tester.pumpAndSettle();
    expect(find.byType(MissionFormPage), findsNothing);
    expect(find.text('打开表单'), findsOneWidget);
  });

  testWidgets('320宽双倍字体和键盘下可滚动，无溢出；日期按钮有名称值和动作', (tester) async {
    tester.view.physicalSize = const Size(320, 780);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final handle = tester.ensureSemantics();
    try {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(2)),
            child: child!,
          ),
          home: MissionFormPage(
            missionService: MissionService(PendingRepository()),
            initialScheduledDate: '2026-10-24',
          ),
        ),
      );
      final node = tester.getSemantics(find.bySemanticsLabel('计划日期'));
      expect(node.getSemanticsData().value, '2026-10-24');
      expect(node.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);
      await tester.ensureVisible(
        find.byKey(const ValueKey('mission-duration')),
      );
      await tester.pumpAndSettle();
      expect(
        tester.getRect(find.byKey(const ValueKey('mission-duration'))).top,
        greaterThan(
          tester.getRect(find.byKey(const ValueKey('mission-date'))).bottom,
        ),
      );
      await tester.ensureVisible(find.text('固定'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('固定'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('固定'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const ValueKey('mission-hour')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const ValueKey('mission-hour')), '14');
      tester.view.viewInsets = const FakeViewPadding(bottom: 240);
      addTearDown(tester.view.resetViewInsets);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const ValueKey('mission-minute')));
      await tester.pumpAndSettle();
      // 溢出由测试框架保留完整诊断。
      expect(find.byType(FilledButton), findsOneWidget);
    } finally {
      handle.dispose();
    }
  });
  testWidgets('390宽表单使用紧凑输入和统一返回，日期时长可纵排', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: MissionFormPage(
          missionService: MissionService(PendingRepository()),
          initialScheduledDate: '2026-10-24',
        ),
      ),
    );
    final dateRect = tester.getRect(find.byKey(const ValueKey('mission-date')));
    final durationRect = tester.getRect(
      find.byKey(const ValueKey('mission-duration')),
    );
    expect(durationRect.top, greaterThan(dateRect.bottom));
    expect(dateRect.height, closeTo(durationRect.height, 1));
    final arrow = tester.widget<Icon>(find.byIcon(Icons.arrow_back));
    expect(arrow.color, AppTheme.light.colorScheme.primary);
    final backRect = tester.getRect(
      find.widgetWithIcon(IconButton, Icons.arrow_back),
    );
    expect(backRect.size, const Size(48, 48));
    expect(backRect.left, 24);
    expect(tester.getRect(find.text('新建任务')).left, greaterThan(backRect.right));
    expect(dateRect.height, lessThan(60));
    final timeLabel = tester.getRect(find.text('时间安排'));
    final choice = tester.getRect(
      find.byKey(const ValueKey(TimePolicy.flexible)),
    );
    expect(choice.top, greaterThanOrEqualTo(timeLabel.top));
    expect(choice.height, greaterThanOrEqualTo(48));
    expect(find.text('分钟'), findsOneWidget);
    expect(find.text('所属节点'), findsNothing);
  });
}

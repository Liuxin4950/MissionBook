import 'dart:async';
import 'dart:ui' show SemanticsAction;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mission_book/application/missions/mission_service.dart';
import 'package:mission_book/domain/entities/execution_plan.dart';
import 'package:mission_book/domain/entities/mission.dart';
import 'package:mission_book/domain/entities/mission_schedule_revision.dart';
import 'package:mission_book/domain/repositories/mission_repository.dart';
import 'package:mission_book/domain/entities/scheduled_mission.dart';
import 'package:mission_book/domain/entities/mission_detail.dart';
import 'package:mission_book/presentation/missions/create_mission_page.dart';
import 'package:timezone/timezone.dart' as tz;

// 用可控制完成时机的仓储替代磁盘，验证页面确实等待业务保存结果。
class PendingRepository implements MissionRepository {
  @override
  Future<MissionDetail?> findDetail(String missionId) =>
      throw UnsupportedError('创建表单测试不读取详情');

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
      home: CreateMissionPage(missionService: MissionService(repository)),
    ),
  );
  await tester.enterText(find.byType(TextField).at(0), '阅读 Flutter');
  await tester.enterText(find.byType(TextField).at(2), '20');
  await tester.ensureVisible(find.byType(FilledButton));
}

void main() {
  testWidgets('输入框填写后仍有用途标签、当前值和编辑动作，且标签不重复', (tester) async {
    final semantics = tester.ensureSemantics();
    try {
      await tester.pumpWidget(
        MaterialApp(
          home: CreateMissionPage(
            missionService: MissionService(PendingRepository()),
          ),
        ),
      );
      final labels = ['任务名称', '计划日期', '计划时长'];
      final values = ['阅读 Flutter', '2026-10-22', '20'];
      for (var index = 0; index < labels.length; index++) {
        final field = find.byType(TextField).at(index);
        await tester.ensureVisible(field);
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

  testWidgets('上海默认日期，等待事务、防重复提交及成功锁定', (tester) async {
    final repository = PendingRepository();
    await openForm(tester, repository);
    final today = tz.TZDateTime.now(tz.getLocation('Asia/Shanghai'));
    final date =
        '${today.year.toString().padLeft(4, '0')}-'
        '${today.month.toString().padLeft(2, '0')}-'
        '${today.day.toString().padLeft(2, '0')}';
    expect(
      tester.widget<TextField>(find.byType(TextField).at(1)).controller!.text,
      date,
    );
    await tester.tap(find.byType(FilledButton));
    await tester.pump();
    expect(find.text('正在创建…'), findsOneWidget);
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
    expect(find.text('任务已创建，可返回今天页'), findsOneWidget);
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNull,
    );
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
      tester.widget<TextField>(find.byType(TextField).at(0)).controller!.text,
      '阅读 Flutter',
    );
    expect(
      tester.widget<TextField>(find.byType(TextField).at(2)).controller!.text,
      '20',
    );
    repository.completion = Completer<void>();
    await tester.ensureVisible(find.byType(FilledButton));
    await tester.tap(find.byType(FilledButton));
    await tester.pump();
    expect(repository.calls, 2);
    repository.completion.complete();
    await tester.pumpAndSettle();
    expect(find.text('任务已创建，可返回今天页'), findsOneWidget);
  });
}

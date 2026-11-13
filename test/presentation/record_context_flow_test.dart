import 'package:mission_book/presentation/records/shared/material_record_source.dart';
import 'package:mission_book/domain/entities/record_draft.dart';
import 'package:mission_book/data/repositories/drift_memory_repository.dart';
import 'package:mission_book/application/memory/memory_service.dart';
import 'package:mission_book/presentation/records/settings/memory_page.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mission_book/application/analysis/analysis_service.dart';
import 'package:mission_book/application/missions/mission_service.dart';
import 'package:mission_book/application/records/record_service.dart';
import 'package:mission_book/data/analysis/drift_analysis_store.dart';
import 'package:mission_book/data/local/app_database.dart';
import 'package:mission_book/data/repositories/drift_mission_repository.dart';
import 'package:mission_book/data/repositories/drift_record_repository.dart';
import 'package:mission_book/domain/entities/mission_phase.dart';
import 'package:mission_book/presentation/missions/history/mission_history_page.dart';
import 'package:mission_book/presentation/records/shared/record_scope.dart';
import 'package:mission_book/presentation/records/list/records_page.dart';
import 'package:mission_book/presentation/missions/execution/execution_report_button.dart';

void main() {
  final testNow = DateTime.utc(2026, 10, 25, 2);
  late AppDatabase db;
  late MissionService missions;
  late RecordService records;
  late AnalysisService analysis;
  setUp(() {
    db = AppDatabase(executor: NativeDatabase.memory());
    missions = MissionService(
      DriftMissionRepository(db, clock: () => testNow),
      clock: () => testNow,
    );
    records = RecordService(
      DriftRecordRepository(db),
      missions,
      missions.attachments,
    );
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
  Widget app(Widget home) => MaterialApp(
    builder: (c, child) => RecordScope(
      service: records,
      memory: MemoryService(DriftMemoryRepository(db)),
      analysis: analysis,
      child: child!,
    ),
    home: home,
  );
  testWidgets('记录左滑后确认删除，正式任务材料保留', (tester) async {
    await records.save(
      const RecordDraft(
        id: 'delete-me',
        type: ContentType.text,
        source: ContentSource.user,
        content: '可删除的记录',
      ),
    );
    await missions.create(
      title: '关联任务',
      scheduledDate: '2026-10-25',
      timeZone: 'Asia/Shanghai',
      plannedDurationMinutes: 30,
    );
    final mission = (await db.select(db.missions).get()).single;
    await records.save(
      const RecordDraft(
        id: 'keep-me',
        type: ContentType.text,
        source: ContentSource.user,
        content: '正式任务材料',
      ),
      missionId: mission.id,
    );
    await tester.pumpWidget(app(const RecordsPage()));
    await tester.pumpAndSettle();
    await tester.drag(find.text('可删除的记录'), const Offset(-100, 0));
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byKey(const ValueKey('delete-me')),
        matching: find.widgetWithText(TextButton, '删除'),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(OutlinedButton, '删除'));
    await tester.pumpAndSettle();
    expect(find.text('可删除的记录'), findsNothing);
    await tester.drag(find.text('正式任务材料'), const Offset(-100, 0));
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byKey(const ValueKey('keep-me')),
        matching: find.widgetWithText(TextButton, '删除'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('任务中已经提交的材料仍会保留'), findsOneWidget);
    await tester.tap(find.widgetWithText(OutlinedButton, '删除'));
    await tester.pumpAndSettle();
    expect(await db.select(db.records).get(), isEmpty);
    expect(
      (await missions.findDetail(
        missionId: mission.id,
      ))!.evidence.single.content,
      '正式任务材料',
    );
    await tester.pumpWidget(
      app(const MaterialRecordSource(recordId: 'keep-me')),
    );
    await tester.pumpAndSettle();
    expect(find.text('来源记录已删除，提交材料仍保留'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });
  testWidgets('独立文字保存后在列表读取，补关联为已结束任务材料，原END不变', (tester) async {
    await tester.pumpWidget(app(const RecordsPage()));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('添加记录'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('record-pick-photo')), findsOneWidget);
    expect(find.byKey(const Key('record-pick-file')), findsOneWidget);
    expect(find.text('记录类型'), findsOneWidget);
    expect(find.text('独立记录 · 可设置目标或节点'), findsOneWidget);
    await tester.enterText(
      find.descendant(
        of: find.byKey(const Key('record-content-input')),
        matching: find.byType(TextField),
      ),
      '午餐：米饭和蔬菜',
    );
    await tester.tap(find.text('保存记录'));
    await tester.pumpAndSettle();
    expect(find.text('午餐：米饭和蔬菜'), findsOneWidget);
    expect(await db.select(db.missions).get(), isEmpty);
    final record = (await db.select(db.records).get()).single;
    await missions.create(
      title: '午餐任务',
      scheduledDate: '2026-10-25',
      timeZone: 'Asia/Shanghai',
      plannedDurationMinutes: 30,
    );
    final mission = (await db.select(db.missions).get()).single;
    await tester.tap(find.text('午餐：米饭和蔬菜'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('用作任务材料'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('午餐任务'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(OutlinedButton, '提交材料'));
    await tester.pumpAndSettle();
    final detail = (await missions.findDetail(missionId: mission.id))!;
    expect(detail.phase, MissionPhase.notStarted);
    expect(detail.evidence.single.content, '午餐：米饭和蔬菜');
    expect(detail.events, isEmpty);
    expect((await db.select(db.records).get()).single.id, record.id);
    await tester.pumpWidget(const SizedBox.shrink());
  });
  testWidgets('长正文按段展示，编辑仍读取并保存完整正文', (tester) async {
    final body = List.filled(7000, '文').join();
    await records.save(
      RecordDraft(
        id: 'long-record',
        type: ContentType.text,
        source: ContentSource.user,
        content: body,
      ),
    );
    await tester.pumpWidget(app(const RecordDetail(id: 'long-record')));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('编辑记录'));
    await tester.pumpAndSettle();
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      body,
    );
    await tester.enterText(find.byType(TextField), '$body追加');
    await tester.tap(find.widgetWithText(FilledButton, '保存'));
    await tester.pumpAndSettle();
    expect((await records.readDraft('long-record')).content, '$body追加');
    await tester.pumpWidget(const SizedBox.shrink());
  });
  testWidgets('补记入口明确确认完成与日期，无START计时，并可再次更正时间', (tester) async {
    await missions.create(
      title: '上午课程',
      scheduledDate: '2026-10-24',
      timeZone: 'Asia/Shanghai',
      plannedDurationMinutes: 45,
    );
    final id = (await db.select(db.missions).get()).single.id;
    final d = (await missions.findDetail(missionId: id))!;
    await tester.pumpWidget(
      app(
        Scaffold(
          body: ExecutionReportButton(detail: d, service: missions),
        ),
      ),
    );
    await tester.tap(find.text('确认完成情况'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('修改日期、时段或补充说明'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, '补充说明（可不填）'),
      '我上午已经完成这节课程',
    );
    await tester.ensureVisible(
      find.byKey(const Key('execution-report-confirm')),
    );
    await tester.tap(find.byKey(const Key('execution-report-confirm')));
    await tester.pumpAndSettle();
    final saved = (await missions.findDetail(missionId: id))!;
    expect(saved.events, hasLength(1));
    expect(saved.events.single.isRetrospective, isTrue);
    expect(saved.effectiveUserReport!.basis, '我上午已经完成这节课程');
    await tester.pumpWidget(
      app(
        Scaffold(
          body: ExecutionReportButton(detail: saved, service: missions),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('更正实际日期 / 时段'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });
  testWidgets('历史页右上角图标进入全部照片与文字记录', (tester) async {
    await tester.pumpWidget(app(MissionHistoryPage(service: missions)));
    await tester.pumpAndSettle();
    final entry = find.byKey(const Key('history-records-entry'));
    expect(entry, findsOneWidget);
    expect(find.byTooltip('全部照片与文字记录'), findsOneWidget);
    await tester.tap(entry);
    await tester.pumpAndSettle();
    expect(find.byType(RecordsPage), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });
  testWidgets('全局记忆页面查看、更正和忘记走同一业务入口', (tester) async {
    final memory = MemoryService(DriftMemoryRepository(db));
    await memory.save({
      'id': 'ui-memory',
      'layer': 'identity',
      'content': '喜欢上午学习',
      'certainty': 'stated',
      'sourceKind': 'user',
      'topic': '学习时段',
    }, userEdited: true);
    await tester.pumpWidget(app(const MemoryPage()));
    await tester.pumpAndSettle();
    expect(find.text('喜欢上午学习'), findsOneWidget);
    await tester.tap(find.byTooltip('更正记忆'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('memory-content')), '更喜欢晚上学习');
    await tester.ensureVisible(find.byKey(const Key('memory-save')));
    await tester.tap(find.byKey(const Key('memory-save')));
    await tester.pumpAndSettle();
    expect(find.text('更喜欢晚上学习'), findsOneWidget);
    await tester.tap(find.byTooltip('忘记记忆'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(OutlinedButton, '忘记').last);
    await tester.pumpAndSettle();
    expect(((await memory.query())['items'] as List), isEmpty);
    expect((await db.select(db.memoryItems).get()).single.forgotten, true);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}

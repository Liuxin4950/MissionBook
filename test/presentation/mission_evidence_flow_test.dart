import '../support/me_fakes.dart';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mission_book/application/evidence/evidence_image_service.dart';
import 'package:mission_book/application/missions/mission_service.dart';
import 'package:mission_book/application/goals/goal_service.dart';
import 'package:mission_book/data/repositories/drift_goal_repository.dart';
import 'package:mission_book/app_shell.dart';
import 'package:mission_book/core/theme/app_theme.dart';
import 'package:mission_book/data/local/app_database.dart';
import 'package:mission_book/data/repositories/drift_mission_repository.dart';
import 'package:mission_book/domain/entities/evidence.dart';
import 'package:mission_book/domain/entities/execution_event.dart';
import 'package:mission_book/domain/entities/mission.dart';
import 'package:mission_book/domain/entities/mission_detail.dart';
import 'package:mission_book/domain/entities/mission_phase.dart';
import 'package:mission_book/presentation/missions/detail/mission_detail_page.dart';
import 'package:mission_book/presentation/missions/evidence/mission_evidence_section.dart';
import 'package:mission_book/presentation/missions/evidence/evidence_image_preview.dart';
import 'package:mission_book/presentation/missions/execution/mission_execution_page.dart';
import 'package:mission_book/presentation/missions/history/mission_history_page.dart';
import 'package:mission_book/presentation/today/today_page.dart';

late Uint8List _png;

class _Images implements EvidenceImageStore, EvidenceImagePicker {
  final files = <String, Uint8List>{};
  bool cancel = false;
  @override
  Future<SelectedEvidenceImage?> pick() async => cancel
      ? null
      : SelectedEvidenceImage(
          fileName: '运行结果.png',
          byteLength: _png.length,
          readBytes: () async => _png,
        );
  @override
  Future<void> writeNew(String key, Uint8List bytes) async =>
      files[key] = Uint8List.fromList(bytes);
  @override
  Future<Uint8List> read(String key) async => files[key]!;
  @override
  Future<void> delete(String key) async {
    files.remove(key);
  }

  @override
  Future<Set<String>> listKeys() async => files.keys.toSet();
}

class _LostReply extends DriftMissionRepository {
  _LostReply(super.database, {required super.clock});
  bool lose = false;
  final submissions = <String>[];
  @override
  Future<EvidenceSubmissionResult> submitEvidence(
    EvidenceSubmission command,
  ) async {
    submissions.add(command.id);
    final result = await super.submitEvidence(command);
    if (lose) {
      lose = false;
      throw StateError('测试保存成功但响应丢失');
    }
    return result;
  }
}

// UI 测试把系统选择/解码作为边界替身；真实图片解码和磁盘副本由附件测试覆盖。
class _PreparedImages extends EvidenceImageService {
  _PreparedImages(this.images) : super(store: images, picker: images);
  final _Images images;
  @override
  Future<PreparedEvidenceImage?> pickAndPrepare(String missionId) async {
    if (images.cancel) return null;
    final key = 'attachments/$missionId/ui-test-${images.files.length}.png';
    await images.writeNew(key, _png);
    return PreparedEvidenceImage(
      storageKey: key,
      fileName: '运行结果.png',
      mimeType: 'image/png',
    );
  }

  @override
  Future<PreparedEvidenceImage?> pickFileAndPrepare(String missionId) async {
    if (images.cancel) return null;
    final key = 'attachments/$missionId/ui-file-${images.files.length}.pdf';
    await images.writeNew(key, _png);
    return PreparedEvidenceImage(
      storageKey: key,
      fileName: '练习报告.pdf',
      mimeType: 'application/pdf',
    );
  }
}

class _Routes extends NavigatorObserver {
  int pushes = 0;
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    pushes++;
  }
}

void main() {
  setUpAll(() async {
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);
    canvas.drawColor(const ui.Color(0xff244d3d), ui.BlendMode.src);
    final picture = recorder.endRecording();
    final image = await picture.toImage(2, 2);
    _png = (await image.toByteData(
      format: ui.ImageByteFormat.png,
    ))!.buffer.asUint8List();
    image.dispose();
    picture.dispose();
  });
  late AppDatabase database;
  late _LostReply repository;
  late MissionService service;
  late GoalService goals;
  late _Images images;
  late DateTime now;
  setUp(() {
    now = DateTime.utc(2030, 1, 1, 6);
    database = AppDatabase(executor: NativeDatabase.memory());
    goals = GoalService(DriftGoalRepository(database));
    repository = _LostReply(database, clock: () => now);
    images = _Images();
    service = MissionService(repository, images: _PreparedImages(images));
  });
  tearDown(() async {
    await goals.dispose();
    await service.dispose();
    await database.close();
  });

  Future<MissionDetail> create({
    VerificationPolicy policy = VerificationPolicy.optionalEvidence,
    bool pending = false,
    String date = '2030-01-01',
  }) async {
    await service.create(
      title: '验证数据库事务',
      scheduledDate: date,
      timeZone: 'Asia/Shanghai',
      plannedDurationMinutes: 20,
      verificationPolicy: policy,
      verificationCriteria: policy == VerificationPolicy.requiredEvidence
          ? '提交真实运行结果'
          : null,
      evidenceDeadlineAt: policy == VerificationPolicy.requiredEvidence
          ? now.add(const Duration(hours: 2))
          : null,
    );
    var detail = (await repository.findFinished()).isEmpty
        ? null
        : (await repository.findFinished()).first;
    final id = (await repository.findScheduledOn(date)).last.mission.id;
    detail = (await repository.findDetail(id))!;
    if (pending) {
      await service.execute(
        service.prepareExecution(
          detail: detail,
          type: ExecutionEventType.start,
        ),
      );
      detail = (await repository.findDetail(id))!;
      now = now.add(const Duration(minutes: 3));
      await service.execute(
        service.prepareExecution(
          detail: detail,
          type: ExecutionEventType.end,
          report: UserReportedResult.completed,
          submitOptionalEvidence: policy == VerificationPolicy.optionalEvidence
              ? true
              : null,
        ),
      );
      detail = (await repository.findDetail(id))!;
    }
    return detail;
  }

  Widget app(Widget home, {List<NavigatorObserver> observers = const []}) =>
      MaterialApp(
        theme: AppTheme.light,
        locale: const Locale('zh', 'CN'),
        supportedLocales: const [Locale('zh', 'CN')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        home: home,
        navigatorObservers: observers,
      );
  Future<void> tap(WidgetTester tester, String key) async {
    final finder = find.byKey(Key(key));
    if (finder.evaluate().isEmpty) {
      await tester.scrollUntilVisible(
        finder,
        200,
        scrollable: find.byType(Scrollable).first,
      );
    }
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  testWidgets('可选任务明确不交材料即可结束，不留下待补提示', (tester) async {
    final detail = await create();
    await tester.pumpWidget(
      app(
        MissionDetailPage(
          missionId: detail.mission.id,
          missionService: service,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tap(tester, 'execution-start');
    await tap(tester, 'execution-end');
    await tap(tester, 'report-completed');
    expect(find.byKey(const Key('report-evidence-skip')), findsOneWidget);
    await tap(tester, 'report-confirm');
    final saved = (await repository.findDetail(detail.mission.id))!;
    expect(saved.phase, MissionPhase.closed);
    expect(saved.events.last.submitOptionalEvidence, false);
    expect(find.text('执行已结束 · 待提交材料'), findsNothing);
  });

  testWidgets('强制任务END后在原工作区提交文本，正式提交不再追加END', (tester) async {
    final detail = await create(policy: VerificationPolicy.requiredEvidence);
    await tester.pumpWidget(
      app(
        MissionDetailPage(
          missionId: detail.mission.id,
          missionService: service,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tap(tester, 'execution-start');
    await tap(tester, 'execution-end');
    await tap(tester, 'report-completed');
    await tap(tester, 'report-confirm');
    expect(find.byKey(const Key('mission-evidence-workspace')), findsOneWidget);
    expect(find.text('执行已结束 · 待提交材料'), findsOneWidget);
    expect(
      (await repository.findDetail(detail.mission.id))!.phase,
      MissionPhase.evidencePending,
    );
    await tap(tester, 'evidence-add-text');
    await tester.enterText(find.byType(TextField).last, '第二次插入失败后，两次写入一起回滚。');
    await tap(tester, 'evidence-submit');
    final saved = (await repository.findDetail(detail.mission.id))!;
    expect(saved.phase, MissionPhase.closed);
    expect(saved.evidence.single.content, contains('一起回滚'));
    expect(
      saved.events.where((item) => item.type == ExecutionEventType.end),
      hasLength(1),
    );
    expect(find.text('已提交 1 份材料'), findsOneWidget);
  });

  testWidgets('代码、手动记录与文件可同批提交；结果页单条修正留历史', (tester) async {
    final detail = await create(pending: true);
    await tester.pumpWidget(
      app(
        Scaffold(
          body: SingleChildScrollView(
            child: MissionEvidenceSection(
              detail: detail,
              service: service,
              initiallyExpanded: true,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tap(tester, 'evidence-add-code');
    await tester.enterText(find.byType(TextField).last, 'print(1)');
    await tap(tester, 'evidence-add-manual');
    await tester.enterText(find.byType(TextField).last, '完成了十次练习');
    await tap(tester, 'evidence-add-file');
    await tap(tester, 'evidence-submit');
    final saved = (await repository.findDetail(detail.mission.id))!;
    expect(saved.phase, MissionPhase.closed);
    expect(saved.evidence.map((item) => item.type).toSet(), {
      EvidenceType.code,
      EvidenceType.manualRecord,
      EvidenceType.file,
    });
    final code = saved.evidence.singleWhere(
      (item) => item.type == EvidenceType.code,
    );
    await tap(tester, 'evidence-correct-${code.id}');
    await tester.enterText(
      find.byKey(const Key('evidence-correction-content')),
      'print(2)',
    );
    await tap(tester, 'evidence-correction-save');
    final corrected = (await repository.findDetail(detail.mission.id))!;
    expect(corrected.evidence, hasLength(4));
    expect(corrected.effectiveEvidence, hasLength(3));
    expect(
      corrected.evidence.singleWhere((item) => item.id == code.id).content,
      'print(1)',
    );
    expect(
      corrected.effectiveEvidence
          .singleWhere((item) => item.type == EvidenceType.code)
          .content,
      'print(2)',
    );
    expect(corrected.phase, MissionPhase.closed);
    expect(
      find.byKey(const Key('evidence-correction-history')),
      findsOneWidget,
    );
  });

  testWidgets('单独图片可无说明提交，选择取消保留原草稿', (tester) async {
    final detail = await create(pending: true);
    await tester.pumpWidget(
      app(
        Scaffold(
          body: SingleChildScrollView(
            child: MissionEvidenceSection(
              detail: detail,
              service: service,
              initiallyExpanded: true,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tap(tester, 'evidence-add-image');
    expect(images.files, hasLength(1));
    images.cancel = true;
    await tap(tester, 'evidence-add-image');
    expect(images.files, hasLength(1));
    await tap(tester, 'evidence-submit');
    final saved = (await repository.findDetail(detail.mission.id))!;
    expect(saved.evidence.single.type, EvidenceType.image);
    expect(saved.evidence.single.content, isNull);
    expect(images.files, hasLength(1));
    expect(tester.takeException(), isNull);
  });

  for (final inHistory in [true, false]) {
    testWidgets('${inHistory ? '历史小图' : '记录双列'}直接点击放大，关闭后材料和执行事实保留', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(400, 850);
      tester.view.devicePixelRatio = 1;
      tester.view.padding = const FakeViewPadding(top: 24, bottom: 20);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPadding);
      final detail = await create(pending: true);
      final first = (await service.pickEvidenceImage(detail.mission.id))!;
      final second = (await service.pickEvidenceImage(detail.mission.id))!;
      await service.submitEvidence(
        service.prepareEvidenceSubmission(
          detail: detail,
          items: [first.copyWithContent('数据库测试结果'), second],
        ),
      );
      final saved = (await service.findDetail(missionId: detail.mission.id))!;
      await tester.pumpWidget(
        app(
          inHistory
              ? MissionHistoryPage(service: service)
              : MissionExecutionPage(detail: saved, service: service),
        ),
      );
      await tester.pumpAndSettle();
      final previews = find.byType(EvidenceImagePreview);
      expect(previews, findsNWidgets(2));
      expect(tester.getSize(previews.first).height, inHistory ? 88 : 148);
      if (inHistory) {
        expect(tester.getSize(previews.first).width, lessThanOrEqualTo(104));
      }
      if (inHistory) {
        // 时间线让材料阅读区变窄，小图自然换行；两张图仍可逐一打开。
        expect(
          tester.getTopLeft(previews.last).dy,
          greaterThanOrEqualTo(tester.getTopLeft(previews.first).dy),
        );
      } else {
        expect(
          tester.getTopLeft(previews.first).dy,
          tester.getTopLeft(previews.last).dy,
        );
      }
      expect(find.text('展开图片，可缩放查看'), findsNothing);
      await tester.ensureVisible(previews.first);
      await tester.tap(previews.first);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('evidence-image-viewer')), findsOneWidget);
      // 背景覆盖系统安全区；内容仍由查看层内的 SafeArea 避让。
      expect(
        tester.getSize(find.byKey(const Key('evidence-image-viewer'))),
        const Size(400, 850),
      );
      expect(
        tester.getTopLeft(find.byKey(const Key('evidence-image-viewer'))),
        Offset.zero,
      );
      expect(find.byType(InteractiveViewer), findsOneWidget);
      await tester.tap(find.byTooltip('关闭图片'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('evidence-image-viewer')), findsNothing);
      expect(images.files, hasLength(2));
      final reread = (await service.findDetail(missionId: detail.mission.id))!;
      expect(
        reread.events.map((item) => item.id),
        saved.events.map((item) => item.id),
      );
      expect(reread.evidence, hasLength(2));
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('保存响应丢失后原批次重试或重读确认，不重复材料', (tester) async {
    final detail = await create(pending: true);
    repository.lose = true;
    await tester.pumpWidget(
      app(
        Scaffold(
          body: SingleChildScrollView(
            child: MissionEvidenceSection(
              detail: detail,
              service: service,
              initiallyExpanded: true,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tap(tester, 'evidence-add-text');
    await tester.enterText(find.byType(TextField).last, '保留同一份输入');
    await tap(tester, 'evidence-submit');
    expect(find.textContaining('保存结果未确认'), findsOneWidget);
    expect(
      tester.widget<TextField>(find.byType(TextField).last).enabled,
      false,
    );
    await tap(tester, 'evidence-submit');
    expect(repository.submissions, hasLength(2));
    expect(repository.submissions.first, repository.submissions.last);
    expect(
      (await repository.findDetail(detail.mission.id))!.evidence,
      hasLength(1),
    );
    expect(find.text('已提交 1 份材料'), findsOneWidget);
  });

  testWidgets('普通保存失败保留原批次和文字，解除故障后可重试', (tester) async {
    final detail = await create(pending: true);
    await database.customStatement(
      "CREATE TRIGGER reject_evidence BEFORE INSERT ON evidence_records BEGIN SELECT RAISE(ABORT, '模拟保存失败'); END",
    );
    await tester.pumpWidget(
      app(
        Scaffold(
          body: SingleChildScrollView(
            child: MissionEvidenceSection(
              detail: detail,
              service: service,
              initiallyExpanded: true,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tap(tester, 'evidence-add-text');
    await tester.enterText(find.byType(TextField).last, '失败后要保留这段文字');
    await tap(tester, 'evidence-submit');
    expect(find.text('失败后要保留这段文字'), findsOneWidget);
    expect((await repository.findDetail(detail.mission.id))!.evidence, isEmpty);
    await database.customStatement('DROP TRIGGER reject_evidence');
    await tap(tester, 'evidence-submit');
    expect(repository.submissions, hasLength(2));
    expect(repository.submissions.first, repository.submissions.last);
    expect(
      (await repository.findDetail(detail.mission.id))!.evidence.single.content,
      '失败后要保留这段文字',
    );
  });

  testWidgets('材料输入拥有独立语义标签，辅助输入能写入正式正文', (tester) async {
    final semantics = tester.ensureSemantics();
    final detail = await create(pending: true);
    await tester.pumpWidget(
      app(
        Scaffold(
          body: SingleChildScrollView(
            child: MissionEvidenceSection(
              detail: detail,
              service: service,
              initiallyExpanded: true,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tap(tester, 'evidence-add-text');
    final field = find.byType(EditableText).last;
    await tester.tap(field);
    await tester.pumpAndSettle();
    final node = tester.getSemantics(field);
    expect(node.getSemanticsData().label, '文本内容');
    expect(
      node.getSemanticsData().hasAction(ui.SemanticsAction.setText),
      isTrue,
    );
    node.owner!.performAction(
      node.id,
      ui.SemanticsAction.setText,
      '通过辅助输入保存正文',
    );
    await tester.pumpAndSettle();
    expect(tester.widget<EditableText>(field).controller.text, '通过辅助输入保存正文');
    await tap(tester, 'evidence-submit');
    expect(
      (await repository.findDetail(detail.mission.id))!.evidence.single.content,
      '通过辅助输入保存正文',
    );
    semantics.dispose();
  });

  testWidgets('可选待补可一次确认放弃，保留END并记录真实放弃时刻', (tester) async {
    final detail = await create(pending: true);
    await tester.pumpWidget(
      app(
        Scaffold(
          body: SingleChildScrollView(
            child: MissionEvidenceSection(
              detail: detail,
              service: service,
              initiallyExpanded: true,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tap(tester, 'evidence-add-text');
    await tester.enterText(find.byType(TextField).last, '最后决定不交');
    await tap(tester, 'evidence-skip');
    expect(find.text('放弃提交并结束？'), findsOneWidget);
    await tester.tap(find.text('放弃提交'));
    await tester.pumpAndSettle();
    final saved = (await repository.findDetail(detail.mission.id))!;
    expect(saved.phase, MissionPhase.closed);
    expect(saved.mission.evidenceWaivedAt, isNotNull);
    expect(saved.evidence, isEmpty);
    expect(saved.events.last.id, detail.events.last.id);
    expect(find.text('最后决定不交'), findsNothing);
  });

  testWidgets('320宽双倍字号可编辑并提交，材料按钮和文字没有溢出', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final detail = await create(pending: true);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: const TextScaler.linear(2)),
          child: child!,
        ),
        home: Scaffold(
          body: SingleChildScrollView(
            child: MissionEvidenceSection(
              detail: detail,
              service: service,
              initiallyExpanded: true,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tap(tester, 'evidence-add-text');
    await tester.enterText(find.byType(TextField).last, '窄屏提交材料');
    await tap(tester, 'evidence-submit');
    expect(
      (await repository.findDetail(detail.mission.id))!.evidence.single.content,
      '窄屏提交材料',
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('历史行原位提交保留草稿，今天跨日仍能找到待补入口', (tester) async {
    final detail = await create(pending: true);
    await tester.pumpWidget(app(MissionHistoryPage(service: service)));
    await tester.pumpAndSettle();
    await tap(tester, 'evidence-open-${detail.mission.id}');
    await tap(tester, 'evidence-add-text');
    await tester.enterText(find.byType(TextField).last, '历史行的原位材料');
    // 另一个入口提交事实后广播刷新，历史行内草稿不能随 Future 等待态消失。
    await service.create(
      title: '触发其他入口广播',
      scheduledDate: '2030-01-02',
      timeZone: 'Asia/Shanghai',
      plannedDurationMinutes: 10,
    );
    await tester.pumpAndSettle();
    expect(find.text('历史行的原位材料'), findsOneWidget);
    await tester.pumpWidget(
      app(
        Scaffold(
          body: TodayPage(
            missionService: service,
            initialDate: DateTime(2030, 1, 2),
            clock: () => now.add(const Duration(days: 1)),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(Key('today-pending-${detail.mission.id}')),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    expect(
      find.byKey(Key('evidence-open-${detail.mission.id}')),
      findsOneWidget,
    );
  });

  testWidgets('Today超时刷新保留正在输入的草稿，真实状态切为材料超时', (tester) async {
    final detail = await create(
      policy: VerificationPolicy.requiredEvidence,
      pending: true,
    );
    await tester.pumpWidget(
      app(
        Scaffold(
          body: TodayPage(
            missionService: service,
            initialDate: DateTime(2030, 1, 2),
            clock: () => now,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(Key('today-pending-${detail.mission.id}')),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    await tap(tester, 'evidence-open-${detail.mission.id}');
    await tap(tester, 'evidence-add-text');
    await tester.enterText(find.byType(TextField).last, '超时也不能直接丢掉的草稿');
    now = now.add(const Duration(hours: 3));
    await service.reconcileEvidenceDeadlines();
    await tester.pumpAndSettle();
    expect(find.text('超时也不能直接丢掉的草稿'), findsOneWidget);
    expect(find.text('材料超时'), findsOneWidget);
    expect(find.byKey(const Key('evidence-submit')), findsNothing);
    expect((await repository.findDetail(detail.mission.id))!.evidence, isEmpty);
  });

  testWidgets('离开有草稿的任务区先确认，继续整理保留输入，明确丢弃后返回', (tester) async {
    final detail = await create(pending: true);
    await tester.pumpWidget(
      app(
        Builder(
          builder: (context) => TextButton(
            onPressed: () => Navigator.of(context).push<void>(
              MaterialPageRoute(
                builder: (_) => Scaffold(
                  appBar: AppBar(title: const Text('材料区')),
                  body: SingleChildScrollView(
                    child: MissionEvidenceSection(
                      detail: detail,
                      service: service,
                      initiallyExpanded: true,
                    ),
                  ),
                ),
              ),
            ),
            child: const Text('打开材料区'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('打开材料区'));
    await tester.pumpAndSettle();
    await tap(tester, 'evidence-add-text');
    await tester.enterText(find.byType(TextField).last, '保留我的草稿');
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('离开并丢弃材料草稿？'), findsOneWidget);
    await tester.tap(find.text('继续整理'));
    await tester.pumpAndSettle();
    expect(find.text('保留我的草稿'), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    await tester.tap(find.text('丢弃草稿').last);
    await tester.pumpAndSettle();
    expect(find.text('打开材料区'), findsOneWidget);
    expect(
      (await repository.findDetail(detail.mission.id))!.phase,
      MissionPhase.evidencePending,
    );
  });

  testWidgets('今天列表进入独立执行页并在该页完成报告与交图', (tester) async {
    final shanghaiToday = DateTime.now().toUtc().add(const Duration(hours: 8));
    final date = shanghaiToday.toIso8601String().substring(0, 10);
    final detail = await create(date: date);
    final routes = _Routes();
    await tester.pumpWidget(
      app(
        AppShell(
          backupService: TestBackup(),
          device: TestAppDevice(),
          missionService: service,
          goalService: goals,
        ),
        observers: [routes],
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('历史').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('今天').last);
    await tester.pumpAndSettle();
    await tap(tester, 'mission-${detail.mission.id}');
    await tap(tester, 'execution-start');
    expect(find.byKey(const Key('mission-execution-page')), findsOneWidget);
    expect(find.text('计划日程'), findsNothing);
    await tap(tester, 'execution-end');
    await tap(tester, 'report-completed');
    await tap(tester, 'report-evidence-submit');
    await tap(tester, 'report-confirm');
    await tap(tester, 'evidence-add-image');
    await tap(tester, 'evidence-submit');
    final saved = (await repository.findDetail(detail.mission.id))!;
    expect(saved.phase, MissionPhase.closed);
    expect(saved.evidence.single.type, EvidenceType.image);
    expect(routes.pushes, greaterThan(1)); // 列表进入独立任务路由。
    expect(find.byKey(const Key('mission-evidence-workspace')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

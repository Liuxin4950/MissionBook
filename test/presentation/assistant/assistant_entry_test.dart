import 'package:agent_core/agent_core.dart';
import 'package:mission_book/data/assistant/drift_unified_reader.dart';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:mission_book/application/assistant/assistant_attachment.dart';
import 'package:mission_book/application/assistant/assistant_controller.dart';
import 'package:mission_book/application/assistant/assistant_speech.dart';
import 'package:mission_book/application/analysis/analysis_service.dart';
import 'package:mission_book/application/goals/goal_service.dart';
import 'package:mission_book/application/missions/mission_service.dart';
import 'package:mission_book/application/records/record_service.dart';
import 'package:mission_book/core/theme/app_layout.dart';
import 'package:mission_book/core/theme/app_theme.dart';
import 'package:mission_book/data/assistant/drift_session_store.dart';
import 'package:mission_book/data/analysis/drift_analysis_store.dart';
import 'package:mission_book/data/local/app_database.dart';
import 'package:mission_book/data/repositories/drift_goal_repository.dart';
import 'package:mission_book/data/repositories/drift_mission_repository.dart';
import 'package:mission_book/data/repositories/drift_record_repository.dart';
import 'package:mission_book/domain/entities/goal.dart';
import 'package:mission_book/presentation/assistant/entry/assistant_launcher.dart';
import 'package:mission_book/presentation/assistant/entry/assistant_scope.dart';
import 'package:mission_book/presentation/assistant/chat/assistant_page.dart';
import 'package:mission_book/presentation/assistant/shared/assistant_markdown.dart';
import 'package:mission_book/presentation/assistant/settings/assistant_settings_page.dart';
import 'package:mission_book/presentation/assistant/settings/assistant_model_settings_page.dart';
import 'package:mission_book/presentation/assistant/settings/assistant_speech_settings_page.dart';
import 'package:mission_book/presentation/records/shared/record_scope.dart';
import 'package:mission_book/presentation/records/list/records_page.dart';

import '../../support/assistant_fakes.dart';
import '../../support/me_fakes.dart';
import 'package:mission_book/app_shell.dart';
import 'package:mission_book/presentation/missions/detail/mission_detail_page.dart';

const _captureDir = String.fromEnvironment('UI_CAPTURE_DIR');
final _screen = GlobalKey();

Future<void> capture(WidgetTester tester, String name) async {
  if (_captureDir.isEmpty) return;
  final providers = tester
      .widgetList<Image>(find.byType(Image))
      .map((image) => image.image)
      .toList();
  await tester.runAsync(() async {
    for (final provider in providers) {
      await precacheImage(provider, _screen.currentContext!);
    }
    await precacheImage(
      const ResizeImage(
        AssetImage('assets/illustrations/paper-leaf-background.png'),
        width: 1024,
      ),
      _screen.currentContext!,
    );
  });
  await tester.pumpAndSettle();
  await tester.pump(const Duration(milliseconds: 250));
  final boundary =
      _screen.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 1);
    final bytes = (await image.toByteData(format: ui.ImageByteFormat.png))!;
    await Directory(_captureDir).create(recursive: true);
    await File(
      '$_captureDir/$name.png',
    ).writeAsBytes(bytes.buffer.asUint8List());
    image.dispose();
  });
}

class TestSpeech implements AssistantSpeech {
  void Function(String)? emit;
  VoidCallback? finish;
  int starts = 0;
  int cancels = 0;
  @override
  Future<bool> start({
    required void Function(String) onText,
    required VoidCallback onDone,
    VoidCallback? onProcessing,
    required void Function(String) onError,
  }) async {
    starts++;
    emit = onText;
    finish = onDone;
    return true;
  }

  @override
  Future<void> stop() async {
    finish?.call();
  }

  @override
  Future<void> cancel() async {
    cancels++;
  }
}

class _UnavailableGoalRepository extends DriftGoalRepository {
  _UnavailableGoalRepository(super.database);

  @override
  Future<void> create(Goal goal) async {
    throw Exception('模拟无法确认结果的存储异常');
  }
}

void main() {
  var currentTextScale = 1.0;
  setUpAll(() async {
    if (_captureDir.isEmpty) return;
    final font = FontLoader('UiPreview');
    font.addFont(
      File(
        Platform.isWindows
            ? 'C:/Windows/Fonts/msyh.ttc'
            : '/usr/share/fonts/opentype/noto/NotoSansCJK-Regular.ttc',
      ).readAsBytes().then((bytes) => ByteData.sublistView(bytes)),
    );
    await font.load();
    final codeFont = FontLoader('monospace');
    codeFont.addFont(
      File(
        Platform.isWindows
            ? 'C:/Windows/Fonts/msyh.ttc'
            : '/usr/share/fonts/opentype/noto/NotoSansCJK-Regular.ttc',
      ).readAsBytes().then((bytes) => ByteData.sublistView(bytes)),
    );
    await codeFont.load();
    final icons = FontLoader('MaterialIcons');
    icons.addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await icons.load();
  });
  late AppDatabase database;
  late MissionService missions;
  late GoalService goals;
  late AssistantController assistant;
  late AssistantVoiceController voice;
  late TestSpeech speech;
  late RecordService records;
  late AnalysisService analysis;
  late String missionId;

  setUp(() async {
    database = AppDatabase(executor: NativeDatabase.memory());
    missions = MissionService(
      DriftMissionRepository(database),
      clock: () => DateTime.utc(2026, 10, 29),
    );
    goals = GoalService(DriftGoalRepository(database));
    records = RecordService(
      DriftRecordRepository(database),
      missions,
      missions.attachments,
    );
    analysis = AnalysisService(
      store: DriftAnalysisStore(database),
      mainBusy: () => false,
      model: (profile, {imageKey, mime, json = false}) async => '摘要',
    );
    await missions.create(
      title: '复习布局',
      scheduledDate: '2026-10-30',
      timeZone: 'Asia/Shanghai',
      plannedDurationMinutes: 30,
    );
    missionId = (await missions.findAllDetails()).single.mission.id;
    speech = TestSpeech();
    voice = AssistantVoiceController(speech);
  });

  tearDown(() async {
    await assistant.close();
    assistant.dispose();
    voice.dispose();
    await missions.dispose();
    await goals.dispose();
    await analysis.dispose();
    await database.close();
  });

  void assistantTest(
    String description,
    Future<void> Function(WidgetTester) body,
  ) {
    testWidgets(description, (tester) async {
      try {
        await body(tester);
      } finally {
        assistant.stop();
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.runAsync(() => assistant.close());
      }
    });
  }

  Future<void> mount(
    WidgetTester tester,
    ScriptedModel model, {
    double width = 390,
    double height = 844,
    double textScale = 1,
    bool shell = false,
    bool realDetail = false,
    bool recordsPage = false,
    bool settingsPage = false,
    Future<AssistantAttachment?> Function()? pickAvatar,
    bool initializeAssistant = true,
    MemoryAssistantSettingsStore? settingsStore,
  }) async {
    currentTextScale = textScale;
    tester.view.resetViewInsets();
    tester.view.physicalSize = Size(width, height);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetViewInsets);
    assistant = AssistantController(
      unifiedReader: DriftUnifiedReader(database),
      sessionStore: DriftSessionStore(database),
      settingsStore: settingsStore ?? MemoryAssistantSettingsStore(),
      missions: missions,
      goals: goals,
      modelOverrides: {'deepseek-chat': model},
    );
    if (initializeAssistant) await assistant.initialize();
    await tester.pumpWidget(
      MaterialApp(
        theme: _captureDir.isEmpty
            ? AppTheme.light
            : AppTheme.light.copyWith(
                textTheme: AppTheme.light.textTheme.apply(
                  fontFamily: 'UiPreview',
                ),
                filledButtonTheme: FilledButtonThemeData(
                  style: AppTheme.light.filledButtonTheme.style!.copyWith(
                    textStyle: WidgetStatePropertyAll(
                      AppTheme.light.textTheme.labelLarge!.copyWith(
                        fontFamily: 'UiPreview',
                      ),
                    ),
                  ),
                ),
                outlinedButtonTheme: OutlinedButtonThemeData(
                  style: AppTheme.light.outlinedButtonTheme.style!.copyWith(
                    textStyle: WidgetStatePropertyAll(
                      AppTheme.light.textTheme.labelLarge!.copyWith(
                        fontFamily: 'UiPreview',
                      ),
                    ),
                  ),
                ),
                textButtonTheme: TextButtonThemeData(
                  style: AppTheme.light.textButtonTheme.style!.copyWith(
                    textStyle: WidgetStatePropertyAll(
                      AppTheme.light.textTheme.labelLarge!.copyWith(
                        fontFamily: 'UiPreview',
                      ),
                    ),
                  ),
                ),
              ),
        locale: const Locale('zh', 'CN'),
        supportedLocales: const [Locale('zh', 'CN')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(currentTextScale)),
          child: AssistantScope(
            controller: assistant,
            voice: voice,
            missions: missions,
            goals: goals,
            backup: TestBackup(),
            device: TestAppDevice(),
            child: RecordScope(
              service: records,
              analysis: analysis,
              child: RepaintBoundary(key: _screen, child: child!),
            ),
          ),
        ),
        home: settingsPage
            ? AssistantSettingsPage(
                controller: assistant,
                pickAvatar: pickAvatar,
              )
            : shell
            ? AppShell(
                assistant: assistant,
                missionService: missions,
                goalService: goals,
                backupService: TestBackup(),
                device: TestAppDevice(),
                clock: () => DateTime.utc(2026, 10, 29),
              )
            : realDetail
            ? MissionDetailPage(missionId: missionId, missionService: missions)
            : recordsPage
            ? RecordsPage(missionId: missionId)
            : AssistantSurface(
                missionId: missionId,
                child: Scaffold(
                  appBar: AppBar(title: const Text('原任务页面')),
                  body: ListView(
                    children: const [
                      TextField(
                        key: Key('original-draft'),
                        decoration: InputDecoration(labelText: '原页面草稿'),
                      ),
                      ExpansionTile(
                        title: Text('原步骤'),
                        initiallyExpanded: true,
                        children: [Text('保留展开内容')],
                      ),
                    ],
                  ),
                ),
              ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> pumpUntil(WidgetTester tester, bool Function() condition) async {
    for (var i = 0; i < 100 && !condition(); i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 1)),
      );
      await tester.pump(const Duration(milliseconds: 30));
    }
    expect(condition(), isTrue);
  }

  for (final width in [390.0, 768.0, 1578.0]) {
    assistantTest('应用设置进入同一助手设置并导出数据 $width', (tester) async {
      await mount(
        tester,
        ScriptedModel([]),
        width: width,
        height: 956,
        shell: true,
      );
      await tester.tap(find.byTooltip('我的'));
      await tester.pumpAndSettle();
      await capture(tester, 'me-page-${width.toInt()}');
      await tester.tap(find.byKey(const Key('me-settings')));
      await tester.pumpAndSettle();
      await capture(tester, 'app-settings-${width.toInt()}');
      await tester.tap(find.byKey(const Key('settings-assistant-entry')));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<AssistantSettingsPage>(find.byType(AssistantSettingsPage))
            .controller,
        same(assistant),
      );
      if (_captureDir.isNotEmpty) {
        await capture(tester, 'assistant-settings-${width.toInt()}');
        await tester.tap(
          find.byKey(const Key('assistant-model-settings-entry')),
        );
        await tester.pumpAndSettle();
        await capture(tester, 'model-settings-${width.toInt()}');
        await tester.tap(find.byTooltip('返回'));
        await tester.pumpAndSettle();
        await tester.tap(
          find.byKey(const Key('assistant-speech-settings-entry')),
        );
        await tester.pumpAndSettle();
        await capture(tester, 'speech-settings-${width.toInt()}');
        await tester.tap(find.byTooltip('返回'));
        await tester.pumpAndSettle();
      }
      final exportEntry = find.byKey(const Key('assistant-backup-entry'));
      await tester.ensureVisible(exportEntry);
      await tester.tap(exportEntry);
      await tester.pumpAndSettle();
      final export = find.byKey(const Key('backup-export'));
      await tester.ensureVisible(export);
      await tester.pumpAndSettle();
      await tester.tap(export);
      await tester.pumpAndSettle();
      expect(find.text('已取消保存，可以随时重新导出'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await capture(tester, 'settings-export-${width.toInt()}');
    });
  }

  assistantTest('助手设置离开前可保留输入或明确放弃，返回原设置工作区', (tester) async {
    await mount(
      tester,
      ScriptedModel([]),
      width: 1578,
      height: 956,
      shell: true,
    );
    await tester.tap(find.byTooltip('我的'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('me-settings')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('settings-assistant-entry')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('assistant-model-settings-entry')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('assistant-credential-input')),
      '未保存的测试输入',
    );
    await tester.pump();
    await tester.tap(find.byTooltip('返回'));
    await tester.pumpAndSettle();
    expect(find.text('放弃AI 模型修改？'), findsOneWidget);
    await tester.tap(find.text('继续编辑'));
    await tester.pumpAndSettle();
    expect(find.text('未保存的测试输入'), findsOneWidget);
    await tester.tap(find.byTooltip('返回'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('放弃修改'));
    await tester.pumpAndSettle();
    expect(find.byType(AssistantSettingsPage), findsOneWidget);
    await tester.tap(find.byTooltip('返回'));
    await tester.pumpAndSettle();
    expect(find.byType(AssistantSettingsPage), findsNothing);
    expect(find.byKey(const Key('settings-assistant-entry')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  assistantTest('从应用设置直接进入未初始化的助手设置会先回填再保存', (tester) async {
    final store = MemoryAssistantSettingsStore()
      ..persona = const AssistantPersona(name: '原有角色')
      ..profileId = 'deepseek';
    await mount(
      tester,
      ScriptedModel([]),
      width: 1106,
      height: 956,
      shell: true,
      initializeAssistant: false,
      settingsStore: store,
    );
    expect(assistant.initialized, isFalse);
    await tester.tap(find.byTooltip('我的'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('me-settings')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('settings-assistant-entry')));
    await pumpUntil(tester, () => assistant.initialized);
    await tester.pumpAndSettle();
    expect(find.textContaining('原有角色'), findsOneWidget);
    expect(find.textContaining('deepseek'), findsWidgets);
    await tester.tap(find.byKey(const Key('assistant-persona-section')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('assistant-persona-name')),
      '新角色',
    );
    await tester.pump();
    await tester.tap(find.byKey(const Key('assistant-save-settings')));
    await pumpUntil(tester, () => store.persona.name == '新角色');
    expect(store.profileId, 'deepseek');
    expect(find.textContaining('设置未保存'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  assistantTest('助手欢迎页在桌面、平板和手机切换保留输入与真实会话侧栏', (tester) async {
    await mount(
      tester,
      ScriptedModel([]),
      width: 1578,
      height: 956,
      shell: true,
    );
    final brand = find.byKey(const Key('navigation-brand'));
    final navIcon = find.byKey(const Key('navigation-icon-0'));
    final rail = find.byKey(const Key('navigation-rail-width'));
    final launcher = find.byKey(const Key('assistant-launcher')).hitTestable();
    expect(tester.getTopLeft(brand).dx, tester.getTopLeft(navIcon).dx);
    // 展开态圆形助手入口与侧栏中线对齐，不跟随导航图标贴左。
    expect(
      tester.getCenter(launcher).dx,
      closeTo(tester.getCenter(rail).dx, .5),
    );
    await tester.tap(find.byKey(const Key('assistant-launcher')).hitTestable());
    await tester.pumpAndSettle();
    await tester.tap(find.text('文字'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('assistant-sidebar-new')), findsOneWidget);
    expect(find.byKey(const Key('assistant-history')), findsNothing);
    expect(find.byKey(const Key('assistant-new-session')), findsNothing);
    expect(find.byKey(const Key('assistant-settings')), findsOneWidget);
    expect(find.text('助手设置与数据导出'), findsNothing);
    expect(
      tester.getCenter(find.byKey(const Key('assistant-sidebar-search'))).dy,
      lessThan(
        tester.getTopLeft(find.byKey(const Key('assistant-sidebar-new'))).dy,
      ),
    );
    await tester.tap(find.byKey(const Key('assistant-sidebar-search')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('assistant-history-search')), findsOneWidget);
    await tester.tap(find.byTooltip('返回'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('assistant-input')), '缩放保留的输入');
    await capture(tester, 'assistant-welcome-1578');
    for (final width in [768.0, 390.0]) {
      tester.view.physicalSize = Size(width, 956);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('assistant-sidebar-new')), findsNothing);
      expect(find.byKey(const Key('assistant-history')), findsOneWidget);
      expect(find.byKey(const Key('assistant-settings')), findsOneWidget);
      expect(find.text('缩放保留的输入'), findsOneWidget);
      expect(
        tester.getSize(find.byKey(const Key('assistant-composer'))).width,
        width,
      );
      expect(tester.takeException(), isNull);
      await capture(tester, 'assistant-welcome-${width.toInt()}');
    }
  });

  assistantTest('语音单独校验保存，试用识别不改聊天草稿也不创建会话', (tester) async {
    final store = MemoryAssistantSettingsStore()
      ..persona = const AssistantPersona(name: '保留角色');
    await mount(tester, ScriptedModel([]), settingsStore: store);
    voice.editText('聊天已有语音草稿');
    final trial = TestSpeech();
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: AssistantSpeechSettingsPage(
          controller: assistant,
          createVoiceTest: () => AssistantVoiceController(trial),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('assistant-speech-mode')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('录音转写服务').last);
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<FilledButton>(
            find.byKey(const Key('assistant-save-settings')),
          )
          .onPressed,
      isNull,
    );
    await tester.enterText(
      find.byKey(const Key('assistant-speech-endpoint')),
      'https://example.invalid/v1/audio/transcriptions',
    );
    await tester.enterText(
      find.byKey(const Key('assistant-speech-model')),
      'transcribe-test',
    );
    await tester.enterText(
      find.byKey(const Key('assistant-speech-credential')),
      'fake-speech-test-key',
    );
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('assistant-save-settings')));
    await tester.pumpAndSettle();
    expect(store.speech.model, 'transcribe-test');
    expect(store.transcriptionCredential, 'fake-speech-test-key');
    expect(store.credential, 'test-credential');
    expect(store.persona.name, '保留角色');
    expect(store.profileId, 'deepseek-chat');
    await tester.scrollUntilVisible(
      find.byKey(const Key('assistant-speech-test')),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.byKey(const Key('assistant-speech-test')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('speech-test-record')));
    await tester.pump();
    trial.emit!('独立识别结果');
    await tester.pump();
    await tester.tap(find.byKey(const Key('speech-test-record')));
    await tester.pumpAndSettle();
    expect(find.text('独立识别结果'), findsOneWidget);
    expect(voice.text, '聊天已有语音草稿');
    expect(assistant.currentSessionId, isNull);
    await tester.tap(find.byTooltip('返回'));
    await tester.pumpAndSettle();
    expect(trial.cancels, greaterThan(0));
    expect(tester.takeException(), isNull);
  });

  for (final width in [320.0, 768.0]) {
    assistantTest('独立 AI 与语音页在 $width 宽双倍字号可滚动操作', (tester) async {
      await mount(
        tester,
        ScriptedModel([]),
        width: width,
        height: 844,
        textScale: 2,
      );
      Widget wrap(Widget home) => MaterialApp(
        theme: AppTheme.light,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: const TextScaler.linear(2)),
          child: child!,
        ),
        home: home,
      );
      await tester.pumpWidget(
        wrap(AssistantModelSettingsPage(controller: assistant)),
      );
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.byKey(const Key('assistant-credential-input')),
        250,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.ensureVisible(
        find.byKey(const Key('assistant-credential-input')),
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(
        wrap(AssistantSpeechSettingsPage(controller: assistant)),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('assistant-speech-mode')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('录音转写服务').last);
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.byKey(const Key('assistant-speech-credential')),
        250,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.ensureVisible(
        find.byKey(const Key('assistant-speech-credential')),
      );
      expect(tester.takeException(), isNull);
    });
  }

  assistantTest('角色名称、回答风格和图标可以在设置里修改并保存', (tester) async {
    await mount(tester, ScriptedModel([]), width: 1106);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: AssistantSettingsPage(controller: assistant),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('assistant-persona-section')));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('assistant-persona-name')))
          .controller!
          .text,
      '书祺',
    );
    expect(find.byKey(const Key('assistant-avatar-spark')), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const Key('assistant-avatar-spark')),
        matching: find.byType(Image),
      ),
      findsOneWidget,
    );
    await tester.enterText(
      find.byKey(const Key('assistant-persona-name')),
      '小书',
    );
    await tester.enterText(
      find.byKey(const Key('assistant-user-address')),
      '小刘',
    );
    await tester.tap(find.byKey(const Key('assistant-reply-style')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('耐心讲解').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('assistant-avatar-book')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('assistant-save-settings')));
    await pumpUntil(tester, () => assistant.persona.name == '小书');
    expect(assistant.persona.replyStyle, AssistantReplyStyle.explanatory);
    expect(assistant.persona.avatar, AssistantAvatar.book);
    expect(assistant.persona.userAddress, '小刘');
    expect(tester.takeException(), isNull);
  });

  for (final (width, textScale) in [(390.0, 1.0), (320.0, 2.0)]) {
    assistantTest('角色设置头像预览与窄屏布局 $width $textScale', (tester) async {
      const deviceChannel = MethodChannel('mission_book/device');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(deviceChannel, (_) async => false);
      addTearDown(() {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(deviceChannel, null);
      });
      await mount(
        tester,
        ScriptedModel([]),
        width: width,
        textScale: textScale,
        settingsPage: true,
      );
      final section = find.byKey(const Key('assistant-persona-section'));
      await tester.ensureVisible(section);
      await tester.tap(section);
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<TextField>(find.byKey(const Key('assistant-persona-name')))
            .style
            ?.fontSize,
        14,
      );
      expect(
        Theme.of(
          tester.element(section),
        ).inputDecorationTheme.labelStyle?.fontSize,
        12,
      );
      await tester.enterText(
        find.byKey(const Key('assistant-persona-name')),
        '小书',
      );
      await tester.pump();
      expect(find.text('小书\n效率助理 · 简洁直接'), findsOneWidget);
      FocusManager.instance.primaryFocus?.unfocus();
      final choice = find.byKey(const Key('assistant-avatar-book'));
      await Scrollable.ensureVisible(tester.element(choice), alignment: 0.5);
      await tester.pumpAndSettle();
      expect(choice.hitTestable(), findsOneWidget);
      await tester.tap(choice);
      await tester.pumpAndSettle();
      expect(
        find.descendant(of: choice, matching: find.byIcon(Icons.check_rounded)),
        findsOneWidget,
      );
      for (final name in ['spark', 'book', 'compass', 'custom']) {
        final size = tester.getSize(find.byKey(Key('assistant-avatar-$name')));
        expect(size.width, greaterThanOrEqualTo(AppLayout.touchTargetMin));
        expect(size.height, greaterThanOrEqualTo(AppLayout.touchTargetMin));
      }
      expect(assistant.persona.avatar, AssistantAvatar.spark);
      final defaultChoice = find.byKey(const Key('assistant-avatar-spark'));
      await Scrollable.ensureVisible(
        tester.element(defaultChoice),
        alignment: 0.5,
      );
      await tester.pumpAndSettle();
      await tester.tap(defaultChoice);
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('assistant-persona-name')),
        '书祺',
      );
      FocusManager.instance.primaryFocus?.unfocus();
      await Scrollable.ensureVisible(tester.element(section), alignment: 0);
      await tester.pumpAndSettle();
      await capture(tester, 'persona-settings-${width.toInt()}');
      expect(tester.takeException(), isNull);
    });
  }

  assistantTest('自定义头像预览保存、取消选择和恢复默认均走角色设置', (tester) async {
    final store = MemoryAssistantSettingsStore();
    AssistantAttachment? selected = AssistantAttachment.fromBytes(
      'avatar.png',
      img.encodePng(img.Image(width: 24, height: 48, numChannels: 4)),
    );
    var failSelection = false;
    await mount(
      tester,
      ScriptedModel([]),
      width: 1106,
      settingsPage: true,
      settingsStore: store,
      pickAvatar: () async {
        if (failSelection) throw const FormatException('图片无法解码，请重新选择');
        return selected;
      },
    );
    await tester.tap(find.byKey(const Key('assistant-persona-section')));
    await tester.pumpAndSettle();
    final custom = find.byKey(const Key('assistant-avatar-custom'));
    await tester.ensureVisible(custom);
    await tester.tap(custom);
    await pumpUntil(
      tester,
      () =>
          find.byKey(const Key('assistant-avatar-reset')).evaluate().isNotEmpty,
    );
    expect(assistant.persona.customAvatarBase64, isNull);
    await tester.tap(find.byKey(const Key('assistant-save-settings')));
    await pumpUntil(tester, () => assistant.persona.customAvatarBase64 != null);
    final saved = (await store.load()).persona.customAvatarBase64;
    expect(saved, isNotNull);
    selected = null;
    await tester.ensureVisible(custom);
    await tester.tap(custom);
    await tester.pumpAndSettle();
    expect((await store.load()).persona.customAvatarBase64, saved);
    failSelection = true;
    await tester.tap(custom);
    await pumpUntil(
      tester,
      () => find.textContaining('图片无法解码').evaluate().isNotEmpty,
    );
    expect((await store.load()).persona.customAvatarBase64, saved);
    final reset = find.byKey(const Key('assistant-avatar-reset'));
    await tester.ensureVisible(reset);
    await tester.tap(reset);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('assistant-avatar-reset')), findsNothing);
    await tester.tap(find.byKey(const Key('assistant-save-settings')));
    await pumpUntil(tester, () => assistant.persona.customAvatarBase64 == null);
    expect((await store.load()).persona.customAvatarBase64, isNull);
    expect(tester.takeException(), isNull);
  });

  assistantTest('悬浮入口与快捷模式的读屏标签和实际操作一致', (tester) async {
    await mount(tester, ScriptedModel([]));
    final handle = tester.ensureSemantics();
    try {
      expect(
        tester.getSemantics(find.byKey(const Key('assistant-launcher'))),
        isSemantics(
          label: 'AI 助手，打开快捷菜单',
          hint: '长按后滑动可选择文字对话或语音输入',
          isButton: true,
          isFocusable: true,
          hasTapAction: true,
          hasFocusAction: true,
        ),
      );
      await tester.longPress(find.byKey(const Key('assistant-launcher')));
      await tester.pumpAndSettle();
      expect(find.text('浮窗'), findsNothing);
      final launcher = tester.getRect(
        find.byKey(const Key('assistant-launcher')),
      );
      final textBubble = tester.getRect(
        find.byKey(const Key('assistant-mode-bubble-0')),
      );
      final voiceBubble = tester.getRect(
        find.byKey(const Key('assistant-mode-bubble-1')),
      );
      expect(textBubble.size, const Size(56, 56));
      expect(voiceBubble.size, const Size(56, 56));
      expect(textBubble.bottom, lessThan(launcher.top));
      expect(
        launcher.top - textBubble.bottom,
        closeTo(AppLayout.spaceXxl, 0.1),
      );
      expect(
        tester.getSemantics(find.text('文字')),
        isSemantics(label: '文字对话', isButton: true, hasTapAction: true),
      );
      expect(
        tester.getSemantics(find.text('语音')),
        isSemantics(label: '语音输入', isButton: true, hasTapAction: true),
      );
    } finally {
      handle.dispose();
    }
  });

  assistantTest('已打开聊天接收截图立即显示并复用当前路由和文字草稿', (tester) async {
    await mount(tester, ScriptedModel([]));
    final launcher = tester.state<AssistantLauncherState>(
      find.byType(AssistantLauncher).first,
    );
    final bytes = Uint8List.fromList(
      img.encodeJpg(img.Image(width: 8, height: 8)),
    );
    expect(
      await tester.runAsync(() => launcher.openCapturedScreen(bytes)),
      true,
    );
    await tester.pumpAndSettle();
    expect(find.byType(AssistantPage), findsOneWidget);
    await tester.enterText(find.byKey(const Key('assistant-input')), '保留这段输入');
    expect(
      await tester.runAsync(() => launcher.openCapturedScreen(bytes)),
      true,
    );
    await tester.pumpAndSettle();
    expect(find.byType(AssistantPage), findsOneWidget);
    expect(assistant.attachmentsFor(assistant.draftKey).length, 2);
    expect(find.text('2/12 个附件'), findsOneWidget);
    expect(find.text('保留这段输入'), findsOneWidget);
    final preview = find.byTooltip(RegExp(r'^预览图片 '));
    expect(preview, findsNWidgets(2));
    expect(tester.getSize(preview.first).width, lessThanOrEqualTo(48));
    await tester.tap(preview.first);
    await tester.pumpAndSettle();
    expect(find.byType(InteractiveViewer), findsOneWidget);
    await tester.tap(find.byTooltip('关闭预览'));
    await tester.pumpAndSettle();
    await tester.tap(preview.first);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('移除图片'));
    await tester.pumpAndSettle();
    expect(assistant.attachmentsFor(assistant.draftKey).length, 1);
    expect(tester.takeException(), isNull);
  });

  assistantTest('附件菜单只保留附件入口', (tester) async {
    await mount(tester, ScriptedModel([]));
    await tester.longPress(find.byKey(const Key('assistant-launcher')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('文字'));
    await pumpUntil(
      tester,
      () => find.byType(AssistantPage).evaluate().isNotEmpty,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('assistant-add-attachment')));
    await tester.pumpAndSettle();
    expect(find.text('添加图片'), findsOneWidget);
    expect(find.text('添加文件'), findsOneWidget);
    expect(find.widgetWithText(PopupMenuItem<String>, '查看今天安排'), findsNothing);
    expect(find.widgetWithText(PopupMenuItem<String>, '帮我规划今天'), findsNothing);
    expect(find.widgetWithText(PopupMenuItem<String>, '压缩会话'), findsNothing);
  });

  assistantTest('长按助手回答选区提供复制操作', (tester) async {
    await mount(tester, ScriptedModel([(_) => textResponse('可长按复制的回答内容')]));
    await tester.longPress(find.byKey(const Key('assistant-launcher')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('文字'));
    await pumpUntil(
      tester,
      () => find.byType(AssistantPage).evaluate().isNotEmpty,
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('assistant-input')), '你好');
    await tester.pump();
    await tester.tap(find.byKey(const Key('assistant-send')));
    await pumpUntil(tester, () => !assistant.isRunning);
    await tester.pumpAndSettle();

    String? copied;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copied = (call.arguments as Map)['text'] as String;
        }
        return null;
      },
    );
    addTearDown(() {
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      );
    });

    await tester.longPress(find.text('可长按复制的回答内容'));
    await tester.pumpAndSettle();
    expect(find.text('复制'), findsOneWidget);
    await tester.tap(find.text('复制'));
    await tester.pumpAndSettle();
    expect(copied, isNotEmpty);
  });

  testWidgets('跨应用悬浮窗开关提供名称、状态和可操作语义', (tester) async {
    try {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel('mission_book/device'),
            (call) async => switch (call.method) {
              'assistantOverlayEnabled' => true,
              'toggleAssistantOverlay' => false,
              _ => null,
            },
          );
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(
              const MethodChannel('mission_book/device'),
              null,
            ),
      );
      await mount(tester, ScriptedModel([]), width: 1106);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: AssistantSettingsPage(controller: assistant),
        ),
      );
      await tester.pumpAndSettle();
      final overlaySwitch = find.byType(Switch).last;
      await tester.ensureVisible(overlaySwitch);
      await tester.pumpAndSettle();
      final handle = tester.ensureSemantics();
      try {
        expect(
          tester.getSemantics(overlaySwitch),
          isSemantics(
            label: '跨应用悬浮窗',
            hasEnabledState: true,
            isEnabled: true,
            hasToggledState: true,
            isToggled: true,
            hasTapAction: true,
          ),
        );
        await tester.tap(overlaySwitch);
        await tester.pumpAndSettle();
        expect(
          tester.getSemantics(find.byType(Switch).last),
          isSemantics(
            label: '跨应用悬浮窗',
            hasEnabledState: true,
            isEnabled: true,
            hasToggledState: true,
            isToggled: false,
            hasTapAction: true,
          ),
        );
      } finally {
        handle.dispose();
      }
    } finally {
      assistant.stop();
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.runAsync(() => assistant.close());
    }
  }, variant: const TargetPlatformVariant({TargetPlatform.android}));

  assistantTest('思考程度菜单使用紧凑竖排选项和简洁图标', (tester) async {
    await mount(tester, ScriptedModel([]));
    await tester.tap(find.byKey(const Key('assistant-launcher')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('文字'));
    await pumpUntil(
      tester,
      () => find.byType(AssistantPage).evaluate().isNotEmpty,
    );
    await tester.pumpAndSettle();

    final reasoningButton = find.byKey(const Key('assistant-reasoning'));
    final reasoningIcon =
        tester.widget<IconButton>(reasoningButton).icon as Icon;
    expect(reasoningIcon.icon, Icons.lightbulb_outline_rounded);
    await tester.tap(reasoningButton);
    await tester.pumpAndSettle();

    final items = find.byType(MenuItemButton);
    expect(items, findsNWidgets(4));
    final rects = [
      for (var index = 0; index < 4; index++) tester.getRect(items.at(index)),
    ];
    for (var index = 0; index < rects.length; index++) {
      expect(
        rects[index].height,
        greaterThanOrEqualTo(AppLayout.touchTargetMin),
      );
      if (index > 0) {
        expect(rects[index].left, rects.first.left);
        expect(rects[index].right, rects.first.right);
        expect(rects[index].top, greaterThanOrEqualTo(rects[index - 1].bottom));
      }
    }
  });

  assistantTest('上下文提示分别显示输入预算、输出预留和总窗口', (tester) async {
    await mount(tester, ScriptedModel([]));
    await tester.longPress(find.byKey(const Key('assistant-launcher')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('文字'));
    await pumpUntil(
      tester,
      () => find.byType(AssistantPage).evaluate().isNotEmpty,
    );
    await tester.pumpAndSettle();
    final indicator = find.byKey(const Key('assistant-context-usage'));
    expect(
      find.ancestor(of: indicator, matching: find.byType(Tooltip)),
      findsNothing,
    );
    final semantics = tester.ensureSemantics();
    final semanticLabel = tester.getSemantics(indicator).label;
    semantics.dispose();
    expect(
      assistant.contextInputLimit,
      assistant.contextWindowTokens - assistant.reservedOutputTokens - 512,
    );
    expect(
      semanticLabel,
      contains(
        '输入估算 ${assistant.estimatedContextTokens} / 可用输入 ${assistant.contextInputLimit} tokens',
      ),
    );
    expect(
      semanticLabel,
      contains('输出预留 ${assistant.reservedOutputTokens} tokens'),
    );
    expect(
      semanticLabel,
      contains('上下文总窗口 ${assistant.contextWindowTokens} tokens'),
    );
    final progress = tester.widget<CircularProgressIndicator>(
      find.descendant(
        of: indicator,
        matching: find.byType(CircularProgressIndicator),
      ),
    );
    expect(
      progress.value,
      (assistant.estimatedContextTokens / assistant.contextInputLimit).clamp(
        0.0,
        1.0,
      ),
    );
    await tester.longPress(indicator);
    await tester.pumpAndSettle();
    expect(find.text('上下文与用量'), findsOneWidget);
    expect(find.text('输入占用约'), findsNothing);
    await tester.tap(find.byTooltip('关闭用量面板'));
    await tester.pumpAndSettle();
    await tester.tap(indicator);
    await tester.pumpAndSettle();
    expect(find.text('上下文与用量'), findsOneWidget);
    expect(find.text('当前输入估算'), findsOneWidget);
    expect(find.text('本会话实际用量'), findsNothing);
    expect(find.text('尚无供应商报告的用量。'), findsNothing);
    expect(find.text('达到可用输入预算的 80% 时自动压缩早期对话。'), findsNothing);
    currentTextScale = 2;
    tester.view.physicalSize = const Size(320, 640);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.tap(find.byTooltip('关闭用量面板'));
    await tester.pumpAndSettle();
    expect(find.text('上下文与用量'), findsNothing);
  });

  assistantTest('上下文提示显示会话实际用量与正文缓存命中率', (tester) async {
    await mount(
      tester,
      ScriptedModel([
        (_) => textResponse(
          '带用量的回复',
          usage: const TokenUsage(
            inputTokens: 100,
            outputTokens: 20,
            cachedInputTokens: 60,
            cacheReported: true,
          ),
        ),
      ]),
    );
    await tester.longPress(find.byKey(const Key('assistant-launcher')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('文字'));
    await pumpUntil(
      tester,
      () => find.byType(AssistantPage).evaluate().isNotEmpty,
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('assistant-input')), '记录实际用量');
    await tester.pump();
    await tester.tap(find.byKey(const Key('assistant-send')));
    await pumpUntil(
      tester,
      () => !assistant.isRunning && assistant.transcript.isNotEmpty,
    );
    await tester.pumpAndSettle();
    final indicator = find.byKey(const Key('assistant-context-usage'));
    final semantics = tester.ensureSemantics();
    final semanticLabel = tester.getSemantics(indicator).label;
    semantics.dispose();
    expect(semanticLabel, contains('会话累计输入 100 / 输出 20 tokens'));
    expect(semanticLabel, contains('正文缓存命中率 60.0%'));
    expect(semanticLabel, contains('最近一次正文输入 100 tokens'));
    expect(
      find.ancestor(of: indicator, matching: find.byType(Tooltip)),
      findsNothing,
    );
    expect(assistant.sessionUsage.cacheHitRate, .6);
    await tester.longPress(indicator);
    await tester.pumpAndSettle();
    expect(find.text('本会话实际用量'), findsOneWidget);
    expect(find.text('尚无供应商报告的用量。'), findsNothing);
    await tester.tap(find.byTooltip('关闭用量面板'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  assistantTest('文字在独立二级路由引用当前任务，返回保留原页面草稿和展开', (tester) async {
    await mount(tester, ScriptedModel([]));
    await tester.enterText(
      find.byKey(const Key('original-draft')),
      '尚未保存的原页面草稿',
    );
    await tester.longPress(find.byKey(const Key('assistant-launcher')));
    await tester.pumpAndSettle();
    expect(find.text('文字'), findsOneWidget);
    expect(find.text('语音'), findsOneWidget);
    await tester.tap(find.text('文字'));
    await pumpUntil(
      tester,
      () => find.byType(AssistantPage).evaluate().isNotEmpty,
    );
    await tester.pumpAndSettle();
    expect(find.text('当前任务 · 复习布局'), findsOneWidget);
    expect(
      find.byKey(const Key('assistant-launcher')).hitTestable(),
      findsNothing,
    );
    expect(assistant.transcript, isEmpty);
    await tester.enterText(
      find.byKey(const Key('assistant-input')),
      '还没发送的对话草稿',
    );
    await tester.tap(find.byTooltip('返回'));
    await tester.pumpAndSettle();
    expect(find.text('尚未保存的原页面草稿'), findsOneWidget);
    expect(find.text('保留展开内容'), findsOneWidget);
    expect(assistant.draft, '还没发送的对话草稿');
    expect(speech.starts, 0);
    expect(tester.takeException(), isNull);
    await tester.runAsync(() => assistant.close());
  });

  assistantTest('任务记录列表可直接打开带任务上下文的助手', (tester) async {
    await mount(tester, ScriptedModel([]), recordsPage: true);
    await tester.longPress(find.byKey(const Key('assistant-launcher')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('文字'));
    await pumpUntil(
      tester,
      () => find.byType(AssistantPage).evaluate().isNotEmpty,
    );
    await tester.pumpAndSettle();
    expect(find.text('当前任务 · 复习布局'), findsOneWidget);
  });

  assistantTest('长按滑到语音，原页提案展开同一会话，确认后只改一次', (tester) async {
    await mount(
      tester,
      ScriptedModel([
        (_) => toolResponse('voice-move', 'rescheduleMission', {
          'missionId': missionId,
          'scheduledDate': '2026-10-31',
          'plannedMinutes': 45,
        }),
        (_) => textResponse('已调整到后天，计划45分钟。'),
      ]),
    );
    final center = tester.getCenter(
      find.byKey(const Key('assistant-launcher')),
    );
    final gesture = await tester.startGesture(center);
    await tester.pump(const Duration(milliseconds: 600));
    await gesture.moveTo(center + const Offset(48, -88));
    await tester.pump();
    await gesture.up();
    await pumpUntil(tester, () => speech.starts == 1);
    speech.emit!('把这个任务挪到后天，改成45分钟');
    speech.finish!();
    await tester.pump();
    await tester.tap(find.text('发送'));
    await pumpUntil(
      tester,
      () => assistant.operations.any(
        (item) => item.status == AssistantOperationStatus.waitingConfirmation,
      ),
    );
    expect(
      (await missions.findDetail(missionId: missionId))!.schedule.scheduledDate,
      '2026-10-30',
    );
    final session = assistant.currentSessionId;
    await tester.tap(find.byTooltip('展开同一对话'));
    await pumpUntil(
      tester,
      () => find.byType(AssistantPage).evaluate().isNotEmpty,
    );
    await tester.pump(const Duration(milliseconds: 350));
    expect(assistant.currentSessionId, session);
    expect(find.text('把这个任务挪到后天，改成45分钟'), findsOneWidget);
    await tester.ensureVisible(find.text('确认执行'));
    await tester.tap(find.text('确认执行'));
    await pumpUntil(tester, () => !assistant.isRunning);
    final detail = (await missions.findDetail(missionId: missionId))!;
    expect(detail.schedule.scheduledDate, '2026-10-31');
    expect(detail.schedule.plannedDurationMinutes, 45);
    expect(detail.schedule.revisionNumber, 2);
    await tester.tap(find.byTooltip('返回'));
    await tester.pumpAndSettle();
    expect(find.text('原任务页面'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.runAsync(() => assistant.close());
  });

  assistantTest('320宽与两倍字号可选择文字，不发生布局溢出', (tester) async {
    await mount(tester, ScriptedModel([]), width: 320, textScale: 2);
    await tester.tap(find.byKey(const Key('assistant-launcher')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('文字'));
    await pumpUntil(
      tester,
      () => find.byType(AssistantPage).evaluate().isNotEmpty,
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.tap(find.byTooltip('返回'));
    await tester.pumpAndSettle();
    await tester.runAsync(() => assistant.close());
  });
  assistantTest('取消节点助手菜单后，普通入口使用当前任务上下文', (tester) async {
    final goal = goals.prepareCreation(title: '目标');
    await goals.create(goal);
    final node = goals.prepareNodeCreation(goalId: goal.id, title: '节点');
    await goals.createNode(node);
    await mount(tester, ScriptedModel([]));
    final pageContext = tester.element(find.byKey(const Key('original-draft')));
    AssistantEntryScope.maybeOf(pageContext)!.openNode(node.id);
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(20, 100));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('assistant-launcher')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('文字'));
    await pumpUntil(
      tester,
      () => find.byType(AssistantPage).evaluate().isNotEmpty,
    );
    expect(assistant.reference?.type, AssistantReferenceType.mission);
    expect(assistant.reference?.id, missionId);
  });

  for (final width in [320.0, 390.0, 768.0, 1200.0]) {
    assistantTest('真实AppShell $width 宽中央入口可用且不会切换主导航', (tester) async {
      await mount(tester, ScriptedModel([]), width: width, shell: true);
      expect(
        find.byKey(const Key('assistant-launcher')).hitTestable(),
        findsOneWidget,
      );
      final avatar = find.descendant(
        of: find.byKey(const Key('assistant-launcher')),
        matching: find.byType(Image),
      );
      expect(avatar, findsOneWidget);
      final launcherSize = tester.getSize(
        find.byKey(const Key('assistant-launcher')),
      );
      expect(tester.getSize(avatar), Size.square(launcherSize.shortestSide));
      await capture(tester, 'shuqi-launcher-${width.toInt()}');
      await tester.tap(
        find.byKey(const Key('assistant-launcher')).hitTestable(),
      );
      await tester.pumpAndSettle();
      expect(find.text('文字').hitTestable(), findsOneWidget);
      await tester.tap(find.text('文字'));
      await pumpUntil(
        tester,
        () => find.byType(AssistantPage).evaluate().isNotEmpty,
      );
      await tester.pumpAndSettle();
      expect(assistant.reference, isNull);
      await tester.tap(find.byTooltip('返回'));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('assistant-launcher')).hitTestable(),
        findsOneWidget,
      );
      await tester.runAsync(() => assistant.close());
    });
  }

  assistantTest('真实任务页的圆泡、原位提案、聊天键盘与返回截图', (tester) async {
    await mount(
      tester,
      ScriptedModel([
        (_) => toolResponse('visual-move', 'rescheduleMission', {
          'missionId': missionId,
          'scheduledDate': '2026-10-31',
          'plannedMinutes': 45,
        }),
        (_) => textResponse('已调整到10月31日，计划45分钟。'),
      ]),
      realDetail: true,
    );
    await tester.longPress(find.byKey(const Key('assistant-launcher')));
    await tester.pumpAndSettle();
    await capture(tester, '01-task-round-menu');
    await tester.tap(find.text('语音'));
    await pumpUntil(tester, () => speech.starts == 1);
    speech.emit!('把这个任务挪到后天，改成45分钟');
    speech.finish!();
    await tester.pump();
    await capture(tester, '02-voice-transcription');
    await tester.tap(find.text('发送'));
    await pumpUntil(
      tester,
      () => assistant.operations.any(
        (item) => item.status == AssistantOperationStatus.waitingConfirmation,
      ),
    );
    await tester.pump();
    await capture(tester, '03-inline-proposal');
    await tester.tap(find.byTooltip('展开同一对话'));
    await pumpUntil(
      tester,
      () => find.byType(AssistantPage).evaluate().isNotEmpty,
    );
    await tester.pump(const Duration(milliseconds: 350));
    await capture(tester, '04-secondary-conversation');
    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    await tester.pump(const Duration(milliseconds: 350));
    await capture(tester, '05-conversation-keyboard-space');
    expect(
      tester.getBottomRight(find.byKey(const Key('assistant-input'))).dy,
      lessThanOrEqualTo(544),
    );
    tester.view.resetViewInsets();
    assistant.cancelProposal('visual-move');
    await pumpUntil(tester, () => !assistant.isRunning);
    await tester.tap(find.byTooltip('返回'));
    await tester.pumpAndSettle();
    expect(
      (await missions.findDetail(missionId: missionId))!.schedule.scheduledDate,
      '2026-10-30',
    );
    expect(tester.takeException(), isNull);
    await tester.runAsync(() => assistant.close());
  });
  assistantTest('从实际提案编辑表单保存再确认，不注入其他工具的字段', (tester) async {
    await mount(
      tester,
      ScriptedModel([
        (_) => toolResponse('edited-create', 'createMission', {
          'title': '待编辑标题',
          'scheduledDate': '2026-10-31',
          'plannedMinutes': 25,
        }),
        (_) => textResponse('已按修改后的提案创建。'),
      ]),
    );
    await tester.tap(find.byKey(const Key('assistant-launcher')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('文字'));
    await pumpUntil(
      tester,
      () => find.byType(AssistantPage).evaluate().isNotEmpty,
    );
    await tester.pump(const Duration(milliseconds: 350));
    await tester.enterText(
      find.byKey(const Key('assistant-input')),
      '创建一个复习任务',
    );
    await tester.pump();
    await tester.tap(find.byKey(const Key('assistant-send')));
    await pumpUntil(
      tester,
      () => assistant.operations.any(
        (item) => item.status == AssistantOperationStatus.waitingConfirmation,
      ),
    );
    await tester.ensureVisible(find.text('修改'));
    await tester.tap(find.text('修改'));
    await tester.pump();
    final title = find.byWidgetPredicate(
      (widget) => widget is TextField && widget.decoration?.labelText == '名称',
    );
    await tester.ensureVisible(title);
    await tester.enterText(title, '通过表单修改的新标题');
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pump();
    await tester.ensureVisible(find.text('保存提案'));
    await tester.pump();
    await tester.tap(find.text('保存提案'));
    await tester.pump();
    expect(assistant.operations.single.input.keys.toSet(), {
      'title',
      'scheduledDate',
      'plannedMinutes',
    });
    expect(assistant.operations.single.input['title'], '通过表单修改的新标题');
    await tester.ensureVisible(find.text('确认执行'));
    await tester.tap(find.text('确认执行'));
    await pumpUntil(tester, () => !assistant.isRunning);
    expect(
      (await missions.findAllDetails()).any(
        (item) => item.mission.title == '通过表单修改的新标题',
      ),
      isTrue,
    );
    await tester.tap(find.byTooltip('返回'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.runAsync(() => assistant.close());
  });

  assistantTest('自定义模型设置可完整保存，Key与DeepSeek配置独立', (tester) async {
    await mount(tester, ScriptedModel([]));
    await tester.tap(find.byKey(const Key('assistant-launcher')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('文字'));
    await pumpUntil(
      tester,
      () => find.byType(AssistantPage).evaluate().isNotEmpty,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('助手设置'));
    await tester.pumpAndSettle();
    expect(find.byType(AssistantSettingsPage), findsOneWidget);
    await tester.tap(find.byKey(const Key('assistant-model-settings-entry')));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(DropdownButtonFormField<String>).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('自定义服务').last);
    await tester.pumpAndSettle();
    expect(find.text('模型配置的 id、provider、model 和凭据标识不能为空'), findsNothing);
    expect(find.text('保存模型配置后可测试连接'), findsNothing);
    expect(find.byKey(const Key('assistant-test-connection')), findsNothing);
    await tester.ensureVisible(
      find.byKey(const Key('assistant-save-settings')),
    );
    await tester.tap(find.byKey(const Key('assistant-save-settings')));
    await tester.pumpAndSettle();
    expect(find.text('模型配置的 id、provider、model 和凭据标识不能为空'), findsOneWidget);
    await tester.enterText(
      find.byKey(const Key('assistant-custom-endpoint')),
      'https://example.invalid/v1/chat/completions',
    );
    await tester.enterText(
      find.byKey(const Key('assistant-custom-model')),
      'custom-model',
    );
    await tester.ensureVisible(
      find.byKey(const Key('assistant-credential-input')),
    );
    await tester.enterText(
      find.byKey(const Key('assistant-credential-input')),
      'fake-custom-only-for-test',
    );
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    await tester.ensureVisible(
      find.byKey(const Key('assistant-save-settings')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('assistant-save-settings')));
    await pumpUntil(tester, () => assistant.modelProfileId == 'custom');
    await tester.pumpAndSettle();
    expect(assistant.hasCredential, isTrue);
    expect(assistant.customProfile?.model, 'custom-model');
    expect(assistant.customProfile?.supportsImages, isFalse);
    await tester.tap(find.byTooltip('返回'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('返回'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.runAsync(() => assistant.close());
  });
  for (final width in [390.0, 320.0]) {
    assistantTest('待核对会话明确提示并可新建发送，原草稿和未知结果保留 $width', (tester) async {
      await tester.runAsync(() => goals.dispose());
      goals = GoalService(_UnavailableGoalRepository(database));
      final model = ScriptedModel([
        (_) => toolResponse('unknown-goal', 'createGoal', {'title': '测试目标'}),
        (_) => textResponse('新会话可以正常发送'),
      ]);
      await mount(
        tester,
        model,
        width: width,
        textScale: width == 320 ? 2 : 1,
        settingsStore: MemoryAssistantSettingsStore()
          ..permissionMode = AssistantPermissionMode.full,
      );
      await tester.runAsync(
        () => assistant.send('创建测试目标').timeout(const Duration(seconds: 5)),
      );
      expect(assistant.needsOutcomeResolution, true);
      final originalId = assistant.currentSessionId!;
      assistant.saveDraft(originalId, '原聊天尚未发送的文字');
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(width == 320 ? 2 : 1)),
            child: child!,
          ),
          home: AssistantPage(controller: assistant, showBack: true),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('assistant-outcome-pending')),
        findsOneWidget,
      );
      expect(
        tester
            .widget<IconButton>(find.byKey(const Key('assistant-send')))
            .onPressed,
        isNull,
      );
      expect(
        tester
            .widget<TextField>(find.byKey(const Key('assistant-input')))
            .controller!
            .text,
        '原聊天尚未发送的文字',
      );
      await tester.tap(find.text('新会话继续'));
      await pumpUntil(
        tester,
        () => !assistant.isBusy && assistant.currentSessionId == null,
      );
      await tester.pumpAndSettle();
      expect(assistant.needsOutcomeResolution, false);
      expect(assistant.draftFor(originalId), '原聊天尚未发送的文字');
      expect(model.requests, hasLength(1));
      expect(find.byKey(const Key('assistant-outcome-pending')), findsNothing);
      await tester.enterText(find.byKey(const Key('assistant-input')), '新会话消息');
      await tester.pump();
      expect(
        tester
            .widget<IconButton>(find.byKey(const Key('assistant-send')))
            .onPressed,
        isNotNull,
      );
      await tester.tap(find.byKey(const Key('assistant-send')));
      await pumpUntil(
        tester,
        () => !assistant.isRunning && model.requests.length == 2,
      );
      await tester.pumpAndSettle();
      expect(find.text('新会话可以正常发送'), findsOneWidget);
      await tester.runAsync(() => assistant.openConversation(originalId));
      await tester.pumpAndSettle();
      expect(assistant.needsOutcomeResolution, true);
      expect(assistant.draft, '原聊天尚未发送的文字');
      expect(model.requests, hasLength(2));
      expect(tester.takeException(), isNull);
    });
  }

  assistantTest('发送按钮随输入激活、清空禁用，启用箭头使用主色上的白色', (tester) async {
    await mount(tester, ScriptedModel([]));
    await tester.tap(find.byKey(const Key('assistant-launcher')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('文字'));
    await pumpUntil(
      tester,
      () => find.byType(AssistantPage).evaluate().isNotEmpty,
    );
    await tester.pumpAndSettle();
    IconButton send() =>
        tester.widget<IconButton>(find.byKey(const Key('assistant-send')));
    expect(send().onPressed, isNull);
    await tester.enterText(find.byKey(const Key('assistant-input')), '调整明天任务');
    await tester.pump();
    expect(send().onPressed, isNotNull);
    final icon = send().icon as Icon;
    expect(icon.color, AppTheme.light.colorScheme.onPrimary);
    await tester.enterText(find.byKey(const Key('assistant-input')), '   ');
    await tester.pump();
    expect(send().onPressed, isNull);
    await tester.tap(find.byTooltip('助手设置'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('assistant-model-settings-entry')));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<FilledButton>(
            find.byKey(const Key('assistant-save-settings')),
          )
          .onPressed,
      isNull,
    );
    await tester.enterText(
      find.byKey(const Key('assistant-credential-input')),
      'fake-replacement',
    );
    await tester.pump();
    expect(
      tester
          .widget<FilledButton>(
            find.byKey(const Key('assistant-save-settings')),
          )
          .onPressed,
      isNotNull,
    );
    expect(tester.takeException(), isNull);
  });

  assistantTest('平板横屏浮层避开侧栏，正文宽度、旋转和分屏键盘均适配', (tester) async {
    await mount(
      tester,
      ScriptedModel([
        (_) =>
            toolResponse('tablet-query', 'getSchedule', {'date': '2026-10-29'}),
        (_) => textResponse(
          '## 当前安排\n\n**今天没有排期。**\n\n- 可以创建新的学习任务\n- 也可以调整现有安排\n\n```dart\nfinal title = "复习布局";\n```',
        ),
      ]),
      width: 1280,
      height: 800,
      shell: true,
    );
    expect(
      tester.getCenter(find.byKey(const Key('assistant-launcher'))).dy,
      greaterThan(700),
    );
    await tester.tap(find.byKey(const Key('assistant-launcher')));
    await tester.pumpAndSettle();
    expect(tester.getRect(find.text('文字')).left, greaterThan(192));
    await capture(tester, '06-tablet-side-menu');
    await tester.tap(find.text('语音'));
    await pumpUntil(tester, () => !voice.starting && speech.starts == 1);
    speech.emit!('调整任务');
    await tester.pump();
    final bubble = tester.getRect(
      find.byKey(const Key('assistant-voice-bubble')),
    );
    expect(bubble.left, greaterThanOrEqualTo(192));
    expect(bubble.right, lessThanOrEqualTo(1268));
    expect(bubble.top, greaterThanOrEqualTo(12));
    expect(bubble.bottom, lessThanOrEqualTo(788));
    await capture(tester, '07-tablet-voice-bubble');
    await tester.tap(find.byTooltip('展开同一对话'));
    await pumpUntil(
      tester,
      () => find.byType(AssistantPage).evaluate().isNotEmpty,
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('assistant-input')), '看看安排');
    await tester.pump();
    await tester.tap(find.byKey(const Key('assistant-send')));
    await pumpUntil(tester, () => !assistant.isRunning);
    await tester.pumpAndSettle();
    expect(
      tester.getSize(find.byKey(const Key('assistant-composer'))).width,
      1008,
    );
    await tester.tap(find.textContaining('处理过程').last);
    await tester.pumpAndSettle();
    expect(
      tester
          .getSize(find.byKey(const Key('assistant-read-tablet-query')))
          .height,
      lessThan(80),
    );
    await capture(tester, '08-tablet-markdown-conversation');
    await tester.enterText(find.byKey(const Key('assistant-input')), '旋转保留的草稿');
    tester.view.physicalSize = const Size(800, 1280);
    await tester.pumpAndSettle();
    expect(find.text('旋转保留的草稿'), findsOneWidget);
    await capture(tester, '09-tablet-portrait-conversation');
    tester.view.physicalSize = const Size(600, 420);
    tester.view.viewInsets = const FakeViewPadding(bottom: 160);
    addTearDown(tester.view.resetViewInsets);
    await tester.pumpAndSettle();
    expect(
      tester.getBottomRight(find.byKey(const Key('assistant-send'))).dy,
      lessThanOrEqualTo(260),
    );
    expect(tester.takeException(), isNull);
    await capture(tester, '10-split-window-keyboard');
  });
  assistantTest('新会话按钮连续点击不写空历史，第一条发送才出现一条会话', (tester) async {
    await mount(
      tester,
      ScriptedModel([(_) => textResponse('第一条回复')]),
      width: 390,
    );
    await tester.tap(find.byKey(const Key('assistant-launcher')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('文字'));
    await pumpUntil(
      tester,
      () => find.byType(AssistantPage).evaluate().isNotEmpty,
    );
    await tester.pumpAndSettle();
    for (var i = 0; i < 5; i++) {
      await tester.tap(find.byTooltip('新会话'));
      await pumpUntil(tester, () => !assistant.isBusy);
      await tester.pumpAndSettle();
    }
    expect(assistant.currentSessionId, isNull);
    expect(assistant.conversations, isEmpty);
    expect(await database.select(database.assistantSessions).get(), isEmpty);
    await tester.enterText(
      find.byKey(const Key('assistant-input')),
      '第一条真正发送的消息',
    );
    expect(assistant.conversations, isEmpty);
    await tester.pump();
    await tester.tap(find.byKey(const Key('assistant-send')));
    await pumpUntil(
      tester,
      () => !assistant.isRunning && assistant.transcript.isNotEmpty,
    );
    await tester.pumpAndSettle();
    expect(assistant.currentSessionId, isNotNull);
    expect(assistant.conversations, hasLength(1));
    await tester.tap(find.byTooltip('新会话'));
    await pumpUntil(tester, () => !assistant.isBusy);
    await tester.pumpAndSettle();
    expect(assistant.currentSessionId, isNull);
    expect(find.text('第一条真正发送的消息'), findsNothing);
    expect(assistant.conversations, hasLength(1));
  });

  assistantTest('会话记录支持搜索、重命名状态与返回原会话，窄屏大字适配', (tester) async {
    await mount(
      tester,
      ScriptedModel([(_) => textResponse('阅读建议'), (_) => textResponse('学习建议')]),
      width: 390,
    );
    await tester.tap(find.byKey(const Key('assistant-launcher')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('文字'));
    await pumpUntil(
      tester,
      () => find.byType(AssistantPage).evaluate().isNotEmpty,
    );
    await tester.pumpAndSettle();
    await tester.runAsync(() => assistant.send('讨论阅读计划'));
    final first = assistant.currentSessionId!;
    await tester.runAsync(() => assistant.renameConversation(first, '调整阅读计划'));
    await tester.runAsync(
      () => assistant.startNewSession(clearReference: true),
    );
    await tester.runAsync(() => assistant.send('讨论本周学习'));
    final second = assistant.currentSessionId!;
    await tester.runAsync(() => assistant.renameConversation(second, '本周学习安排'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('assistant-history')));
    await tester.pumpAndSettle();
    expect(find.text('调整阅读计划'), findsOneWidget);
    expect(find.text('本周学习安排'), findsOneWidget);
    await capture(tester, '11-phone-conversation-history');
    await tester.enterText(
      find.byKey(const Key('assistant-history-search')),
      '阅读',
    );
    await tester.pumpAndSettle();
    expect(find.text('调整阅读计划'), findsOneWidget);
    expect(find.text('本周学习安排'), findsNothing);
    await tester.tap(find.byTooltip('会话操作 调整阅读计划'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('重命名'));
    await tester.pumpAndSettle();
    FilledButton save() =>
        tester.widget<FilledButton>(find.widgetWithText(FilledButton, '保存'));
    expect(save().onPressed, isNull);
    final rename = find.byWidgetPredicate(
      (widget) => widget is TextField && widget.decoration?.labelText == '会话名称',
    );
    await tester.enterText(rename, '  ');
    await tester.pump();
    expect(save().onPressed, isNull);
    await tester.enterText(rename, '阅读调整');
    await tester.pump();
    expect(save().onPressed, isNotNull);
    await tester.tap(find.text('保存'));
    await pumpUntil(
      tester,
      () => assistant.conversations.any((item) => item.title == '阅读调整'),
    );
    await tester.pumpAndSettle();
    expect(assistant.currentSessionId, second);
    currentTextScale = 2;
    tester.view.physicalSize = const Size(320, 640);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('阅读调整'));
    await pumpUntil(tester, () => assistant.currentSessionId == first);
    await tester.pumpAndSettle();
    expect(find.byType(AssistantPage), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final (width, textScale) in [
    (320.0, 2.0),
    (390.0, 1.0),
    (768.0, 1.0),
    (1440.0, 1.0),
  ]) {
    assistantTest('短回复卡片使用正文可用宽度 $width 字号 $textScale', (tester) async {
      await mount(
        tester,
        ScriptedModel([(_) => textResponse('收到。')]),
        width: width,
        textScale: textScale,
      );
      await tester.tap(find.byKey(const Key('assistant-launcher')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('文字'));
      await pumpUntil(
        tester,
        () => find.byType(AssistantPage).evaluate().isNotEmpty,
      );
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('assistant-input')), '你好');
      await tester.pump();
      await tester.tap(find.byKey(const Key('assistant-send')));
      await pumpUntil(tester, () => !assistant.isRunning);
      await tester.pumpAndSettle();
      final list = find.byKey(const Key('assistant-conversation-list'));
      final padding = tester
          .widget<ListView>(list)
          .padding!
          .resolve(TextDirection.ltr);
      final available = tester.getSize(list).width - padding.horizontal;
      final bubble = find
          .ancestor(
            of: find.byType(AssistantMarkdown),
            matching: find.byType(Material),
          )
          .first;
      expect(
        tester.getSize(bubble).width,
        closeTo(available.clamp(0.0, 860.0), .01),
        reason: '短回复也应获得完整阅读宽度，宽屏最多 860；不能只给 maxWidth 后随文字收缩',
      );
      final copy = find.byTooltip('复制回复');
      expect(tester.getSize(copy).shortestSide, greaterThanOrEqualTo(48));
      expect(tester.takeException(), isNull);
      await capture(tester, 'reply-width-${width.toInt()}');
    });
  }

  assistantTest('手机消息间距与超长文本在320宽两倍字号下仍可滚动发送', (tester) async {
    await mount(
      tester,
      ScriptedModel([
        (_) =>
            textResponse('**调整建议**\n\n先查看任务内容，再确认新的安排。\n\n- 保留任务说明\n- 确认后再保存'),
      ]),
      width: 390,
    );
    await tester.tap(find.byKey(const Key('assistant-launcher')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('文字'));
    await pumpUntil(
      tester,
      () => find.byType(AssistantPage).evaluate().isNotEmpty,
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('assistant-input')),
      '帮我调整阅读计划',
    );
    await tester.pump();
    await tester.tap(find.byKey(const Key('assistant-send')));
    await pumpUntil(tester, () => !assistant.isRunning);
    await tester.pumpAndSettle();
    final user = find.text('帮我调整阅读计划');
    final answer = find.text('调整建议');
    expect(
      tester.getTopLeft(answer).dy - tester.getBottomLeft(user).dy,
      greaterThanOrEqualTo(12),
    );
    String? copied;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copied = (call.arguments as Map)['text'] as String;
        }
        return null;
      },
    );
    addTearDown(() {
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      );
    });
    final copy = find.byTooltip('复制回复');
    expect(copy, findsOneWidget);
    await tester.ensureVisible(copy);
    await tester.tap(copy);
    await tester.pumpAndSettle();
    expect(copied, '**调整建议**\n\n先查看任务内容，再确认新的安排。\n\n- 保留任务说明\n- 确认后再保存');
    expect(find.text('已复制回复'), findsOneWidget);
    await capture(tester, '12-phone-message-spacing');
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
    // 同时模拟系统大字号，避免只按固定设备宽度检查。
    currentTextScale = 2;
    tester.view.physicalSize = const Size(320, 640);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('assistant-input')),
      '还有一个很长的修改意图，需要保留草稿并且让发送按钮能够看见',
    );
    await tester.pump();
    expect(
      find.byKey(const Key('assistant-send')).hitTestable(),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}

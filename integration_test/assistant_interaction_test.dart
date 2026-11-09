import 'package:integration_test/integration_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:mission_book/application/assistant/assistant_controller.dart';
import 'package:mission_book/application/assistant/assistant_speech.dart';
import 'package:mission_book/data/assistant/drift_unified_reader.dart';
import 'package:mission_book/core/theme/app_theme.dart';
import 'package:mission_book/presentation/assistant/entry/assistant_launcher.dart';
import 'package:mission_book/presentation/assistant/entry/assistant_scope.dart';
import 'package:mission_book/presentation/assistant/chat/assistant_page.dart';
import '../test/support/performance_audit_fixture.dart';
import '../test/support/assistant_fakes.dart';
import 'dart:typed_data';

import '../test/application/assistant/assistant_streaming_test.dart'
    as streaming;

/// 隔离内存库和可控模型，在设备上验证流式 Markdown、展开及失败恢复。
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  streaming.main();
  testWidgets('截图接续运行中的对象会话并恢复被覆盖聊天', (tester) async {
    final fixture = PerformanceAuditFixture();
    final settings = MemoryAssistantSettingsStore()
      ..permissionMode = AssistantPermissionMode.standard;
    final model = ScriptedModel([
      (_) => toolResponse('capture-device', 'getSchedule', {}),
      (_) => textResponse('已结束'),
    ]);
    final assistant = AssistantController(
      sessionStore: fixture.sessions,
      settingsStore: settings,
      unifiedReader: DriftUnifiedReader(fixture.database),
      missions: fixture.missions,
      goals: fixture.goals,
      modelOverrides: {'deepseek-chat': model},
    );
    final voice = AssistantVoiceController(_SilentSpeech());
    addTearDown(() async {
      assistant.stop();
      await tester.pumpWidget(const SizedBox.shrink());
      await assistant.close();
      assistant.dispose();
      voice.dispose();
      await fixture.dispose();
    });
    await assistant.initialize();
    await fixture.missions.create(
      title: '隔离截图验证',
      scheduledDate: '2026-11-09',
      timeZone: 'Asia/Shanghai',
      plannedDurationMinutes: 15,
    );
    await assistant.openMissionReference(
      (await fixture.missions.findAllDetails()).single.mission.id,
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        builder: (_, child) => AssistantScope(
          controller: assistant,
          voice: voice,
          missions: fixture.missions,
          goals: fixture.goals,
          child: child!,
        ),
        home: const Scaffold(body: Center(child: AssistantLauncher())),
      ),
    );
    await tester.pumpAndSettle();
    final run = assistant.send('查询安排');
    for (var i = 0; i < 200 && assistant.operations.isEmpty; i++) {
      await tester.pump(const Duration(milliseconds: 20));
    }
    expect(
      assistant.operations.single.status,
      AssistantOperationStatus.waitingConfirmation,
    );
    final id = assistant.currentSessionId;
    final launcher = tester.state<AssistantLauncherState>(
      find.byType(AssistantLauncher),
    );
    final bytes = Uint8List.fromList(
      img.encodeJpg(img.Image(width: 8, height: 8)),
    );
    expect(await launcher.openCapturedScreen(bytes), isTrue);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(AssistantPage), findsOneWidget);
    expect(assistant.currentSessionId, id);
    await tester.enterText(find.byKey(const Key('assistant-input')), '保留截图问题');
    final navigator = tester.state<NavigatorState>(
      find.byType(Navigator).first,
    );
    navigator.push(
      MaterialPageRoute<void>(
        builder: (_) => const Scaffold(body: Text('覆盖页面')),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(await launcher.openCapturedScreen(bytes), isTrue);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('覆盖页面'), findsNothing);
    expect(find.text('保留截图问题'), findsOneWidget);
    expect(assistant.currentSessionId, id);
    expect(assistant.attachmentsFor(assistant.draftKey), hasLength(2));
    assistant.stop();
    await run;
  });
}

class _SilentSpeech implements AssistantSpeech {
  @override
  Future<bool> start({
    required void Function(String) onText,
    required VoidCallback onDone,
    VoidCallback? onProcessing,
    required void Function(String) onError,
  }) async => false;
  @override
  Future<void> stop() async {}
  @override
  Future<void> cancel() async {}
}

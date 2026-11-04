import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mission_book/app_shell.dart';
import 'package:mission_book/application/assistant/assistant_speech.dart';
import 'package:mission_book/core/theme/app_theme.dart';
import 'package:mission_book/application/analysis/analysis_service.dart';
import 'package:mission_book/data/analysis/drift_analysis_store.dart';
import 'package:mission_book/data/assistant/configured_assistant_speech.dart';
import 'package:mission_book/data/speech/local_speech_backend_base.dart';
import 'package:mission_book/domain/entities/analysis_scope.dart';
import 'package:mission_book/presentation/assistant/assistant_markdown.dart';
import 'package:mission_book/presentation/assistant/assistant_page.dart';
import 'package:mission_book/presentation/assistant/assistant_scope.dart';
import 'package:mission_book/presentation/goals/outline/goal_outline_section.dart';
import 'package:mission_book/presentation/missions/history/mission_history_page.dart';

import '../support/performance_audit_fixture.dart';
import '../support/me_fakes.dart';
import '../support/assistant_fakes.dart';

const _enabled = bool.fromEnvironment('RUN_PERFORMANCE_AUDIT');
const _paragraph = '这是一段用于性能测量的中文说明，包含 **重点**、`代码` 和普通段落。\n\n';

/// 主机调试采样只比较工作量与规模，不把耗时当作 Android 帧率。
void main() {
  test('后台目标总结按子节点逐项读取', () async {
    final fixture = PerformanceAuditFixture();
    addTearDown(fixture.dispose);
    await fixture.seedGoalNodes(500);
    fixture.queries.reset();
    final elapsed = Stopwatch()..start();
    final input = await DriftAnalysisStore(fixture.database).input(
      const AnalysisWork(
        AnalysisScope.goal,
        PerformanceAuditFixture.goalId,
        1,
        false,
      ),
    );
    elapsed.stop();
    expect(input.items, hasLength(500));
    emitPerformanceSample('analysis_fanout', {
      'direct_nodes': input.items.length,
      'selects': fixture.queries.statements.length,
      'elapsed_ms': elapsed.elapsedMicroseconds / 1000,
    });
  }, skip: !_enabled);

  test('已安装离线语音预热后控制器关闭没有释放后端', () async {
    final backend = _AuditLocalSpeech();
    final voice = AssistantVoiceController(
      ConfiguredAssistantSpeech(
        MemoryAssistantSettingsStore(),
        localBackend: backend,
      ),
    );
    await voice.warmUp();
    await voice.cancel();
    voice.dispose();
    await Future<void>.delayed(Duration.zero);
    emitPerformanceSample('speech_lifetime', {
      'prepares': backend.prepares,
      'backend_disposals_after_voice_dispose': backend.disposals,
    });
    expect(backend.prepares, 1);
  }, skip: !_enabled);

  for (final turns in [20, 200, 1000]) {
    test('会话加载与上下文估算：$turns 轮', () async {
      final fixture = PerformanceAuditFixture();
      addTearDown(fixture.dispose);
      await fixture.seedSession(
        'global',
        turns: turns,
        reply: List.filled(40, _paragraph).join(),
      );
      fixture.queries.reset();
      final assistant = fixture.createAssistant();
      final load = Stopwatch()..start();
      await assistant.initialize();
      await assistant.openGlobalConversation();
      load.stop();
      expect(assistant.transcript, hasLength(turns * 2));
      final estimate = Stopwatch()..start();
      final tokens = assistant.estimatedContextTokens;
      estimate.stop();
      final warm = Stopwatch()..start();
      for (var i = 0; i < 100; i++) {
        expect(assistant.estimatedContextTokens, tokens);
      }
      warm.stop();
      emitPerformanceSample('session', {
        'turns': turns,
        'messages': assistant.transcript.length,
        'load_ms': load.elapsedMicroseconds / 1000,
        'read_pages': fixture.sessions.readPages,
        'read_rows': fixture.sessions.readRows,
        'query_rows': fixture.queries.returnedRows,
        'cold_estimate_ms': estimate.elapsedMicroseconds / 1000,
        'warm_estimate_mean_ms': warm.elapsedMicroseconds / 100000,
      });
    }, skip: !_enabled);
  }

  test('全局入口先打开最近对象会话再打开全局会话', () async {
    final fixture = PerformanceAuditFixture();
    addTearDown(fixture.dispose);
    await fixture.seedGoalNodes(0);
    await fixture.seedSession('global', turns: 200, reply: _paragraph);
    await fixture.seedSession(
      'linked',
      turns: 200,
      reply: _paragraph,
      referenced: true,
    );
    final assistant = fixture.createAssistant();
    final load = Stopwatch()..start();
    await assistant.initialize();
    await assistant.openGlobalConversation();
    load.stop();
    expect(assistant.currentSessionId, 'global');
    emitPerformanceSample('cold_global_after_linked', {
      'opened': fixture.sessions.opened,
      'read_pages': fixture.sessions.readPages,
      'read_rows': fixture.sessions.readRows,
      'load_ms': load.elapsedMicroseconds / 1000,
    });
  }, skip: !_enabled);

  for (final sections in [4, 40, 160]) {
    testWidgets('单条完整 Markdown：$sections 段', (tester) async {
      _phoneViewport(tester);
      final text = List.generate(
        sections,
        (i) =>
            '## 小节 $i\n\n$_paragraph- 第一项\n- 第二项\n\n```dart\nfinal value = $i;\n```\n\n',
      ).join();
      final plain = Stopwatch()..start();
      await tester.pumpWidget(_host(SingleChildScrollView(child: Text(text))));
      plain.stop();
      final plainElements = tester.allElements.length;
      final build = Stopwatch()..start();
      await tester.pumpWidget(
        _host(SingleChildScrollView(child: AssistantMarkdown(text: text))),
      );
      build.stop();
      emitPerformanceSample('markdown', {
        'sections': sections,
        'characters': text.length,
        'first_pump_ms': build.elapsedMicroseconds / 1000,
        'mounted_elements': tester.allElements.length,
        'plain_pump_ms': plain.elapsedMicroseconds / 1000,
        'plain_mounted_elements': plainElements,
      });
      expect(tester.takeException(), isNull);
    }, skip: !_enabled);
  }

  for (final nodes in [100, 500]) {
    testWidgets('目标目录构建与父级刷新：$nodes 节点', (tester) async {
      _phoneViewport(tester);
      final fixture = PerformanceAuditFixture();
      await tester.runAsync(() => fixture.seedGoalNodes(nodes));
      Widget page() => _host(
        SingleChildScrollView(
          child: GoalOutlineSection(
            service: fixture.goals,
            goalId: PerformanceAuditFixture.goalId,
            goalTitle: '性能审查目标',
            embedded: true,
          ),
        ),
      );
      await tester.pumpWidget(page());
      await _flushDatabase(tester);
      final build = Stopwatch()..start();
      await tester.pump();
      build.stop();
      final mountedRows = find
          .byWidgetPredicate(
            (widget) =>
                widget.key is Key &&
                widget.key.toString().contains('node-row-audit-node-'),
          )
          .evaluate()
          .length;
      fixture.queries.reset();
      await tester.pumpWidget(page());
      await _flushDatabase(tester);
      emitPerformanceSample('goal_outline', {
        'nodes': nodes,
        'mounted_rows': mountedRows,
        'mounted_elements': tester.allElements.length,
        'build_pump_ms': build.elapsedMicroseconds / 1000,
        'parent_rebuild_selects': fixture.queries.statements.length,
      });
      expect(mountedRows, nodes);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.runAsync(fixture.dispose);
    }, skip: !_enabled);
  }

  for (final records in [100, 500]) {
    testWidgets('执行历史完整读取与分组：$records 天', (tester) async {
      _phoneViewport(tester);
      final fixture = PerformanceAuditFixture();
      await tester.runAsync(() => fixture.seedFinishedMissions(records));
      fixture.queries.reset();
      await tester.pumpWidget(
        _host(MissionHistoryPage(service: fixture.missions)),
      );
      await _flushDatabase(tester);
      final build = Stopwatch()..start();
      await tester.pump();
      build.stop();
      emitPerformanceSample('mission_history', {
        'records': records,
        'query_rows': fixture.queries.returnedRows,
        'selects': fixture.queries.statements.length,
        'build_pump_ms': build.elapsedMicroseconds / 1000,
        'mounted_elements': tester.allElements.length,
      });
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.runAsync(fixture.dispose);
    }, skip: !_enabled);
  }

  testWidgets('文字聊天仍调用语音预热，重建重新解码图片', (tester) async {
    _phoneViewport(tester);
    final fixture = PerformanceAuditFixture();
    const png =
        'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+aD1sAAAAASUVORK5CYII=';
    await tester.runAsync(() async {
      await fixture.seedSession(
        'global',
        turns: 1,
        reply: '图片测试',
        imageUrl: png,
      );
      await fixture.createAssistant().initialize();
    });
    final speech = _AuditSpeech();
    final voice = AssistantVoiceController(speech);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: AssistantScope(
          controller: fixture.assistant!,
          voice: voice,
          missions: fixture.missions,
          goals: fixture.goals,
          child: AssistantPage(controller: fixture.assistant!, showBack: true),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final first = tester.widget<Image>(find.byType(Image).first).image;
    voice.editText('模拟共享语音状态变化');
    await tester.pump();
    final second = tester.widget<Image>(find.byType(Image).first).image;
    emitPerformanceSample('text_entry_resources', {
      'speech_warmups': speech.warmups,
      'thumbnail_cache_key_equal_after_rebuild': first == second,
    });
    expect(speech.warmups, 1);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    voice.dispose();
    await tester.runAsync(fixture.dispose);
  }, skip: !_enabled);

  testWidgets('聊天长回复滚出视口后再回来会重新建立 Markdown 状态', (tester) async {
    _phoneViewport(tester);
    final fixture = PerformanceAuditFixture();
    await tester.runAsync(() async {
      await fixture.seedSession(
        'global',
        turns: 20,
        reply: List.filled(20, _paragraph).join(),
      );
      await fixture.createAssistant().initialize();
    });
    await tester.pumpWidget(
      _host(AssistantPage(controller: fixture.assistant!, showBack: true)),
    );
    await tester.pumpAndSettle();
    final reply = find.byKey(const ValueKey('global-assistant-19:0'));
    final markdown = find.descendant(
      of: reply,
      matching: find.byType(AssistantMarkdown),
    );
    final original = tester.state(markdown);
    final scroll = tester
        .state<ScrollableState>(
          find
              .descendant(
                of: find.byKey(const Key('assistant-conversation-list')),
                matching: find.byType(Scrollable),
              )
              .first,
        )
        .position;
    scroll.jumpTo(scroll.maxScrollExtent);
    await tester.pumpAndSettle();
    final disposedAway = !original.mounted;
    scroll.jumpTo(scroll.minScrollExtent);
    final rebuild = Stopwatch()..start();
    await tester.pumpAndSettle();
    rebuild.stop();
    emitPerformanceSample('chat_scroll_cache', {
      'messages': fixture.assistant!.transcript.length,
      'markdown_state_disposed_away': disposedAway,
      'same_state_after_return': identical(original, tester.state(markdown)),
      'return_pump_ms': rebuild.elapsedMicroseconds / 1000,
    });
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.runAsync(fixture.dispose);
  }, skip: !_enabled);

  testWidgets('今天页可见时隐藏历史和我的仍完整读取结束任务', (tester) async {
    _phoneViewport(tester);
    final fixture = PerformanceAuditFixture();
    await tester.runAsync(() => fixture.seedFinishedMissions(100));
    fixture.queries.reset();
    await tester.pumpWidget(
      _host(
        AppShell(
          missionService: fixture.missions,
          goalService: fixture.goals,
          backupService: TestBackup(),
          device: TestAppDevice(),
        ),
      ),
    );
    await _flushDatabase(tester);
    await tester.pump();
    await _flushDatabase(tester);
    await tester.pumpAndSettle();
    int finishedQueries() => fixture.queries.statements
        .where(
          (sql) => sql.contains(
            "SELECT DISTINCT mission_id FROM execution_events WHERE type = 'END'",
          ),
        )
        .length;
    final initial = finishedQueries();
    final initialRows = fixture.queries.returnedRows;
    fixture.queries.reset();
    fixture.missions.refreshAfterExternalCommit();
    await tester.pump();
    await _flushDatabase(tester);
    await tester.pumpAndSettle();
    emitPerformanceSample('hidden_pages', {
      'history_records': 100,
      'initial_finished_queries': initial,
      'initial_returned_rows': initialRows,
      'finished_queries_after_change': finishedQueries(),
      'returned_rows_after_change': fixture.queries.returnedRows,
    });
    expect(initial, greaterThanOrEqualTo(2));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.runAsync(fixture.dispose);
  }, skip: !_enabled);
}

Widget _host(Widget child) => MaterialApp(
  theme: AppTheme.light,
  home: Scaffold(body: child),
);

void _phoneViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Future<void> _flushDatabase(WidgetTester tester) async {
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 150)),
  );
}

class _AuditSpeech implements AssistantSpeech, WarmUpSpeech {
  int warmups = 0;
  @override
  Future<void> warmUp() async {
    warmups++;
  }

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

class _AuditLocalSpeech implements LocalSpeechBackend {
  int prepares = 0;
  int disposals = 0;
  @override
  bool get supported => true;
  @override
  String? get lastError => null;
  @override
  Future<bool> hasModel() async => true;
  @override
  Future<bool> prepare() async {
    prepares++;
    return true;
  }

  @override
  Future<String> transcribe(Uint8List pcm16) async => '';
  @override
  Future<void> dispose() async {
    disposals++;
  }
}

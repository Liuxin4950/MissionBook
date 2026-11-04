import 'dart:ui' show FrameTiming;

import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kProfileMode;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mission_book/app_shell.dart';
import 'package:mission_book/application/assistant/assistant_speech.dart';
import 'package:mission_book/core/theme/app_theme.dart';
import 'package:mission_book/presentation/assistant/assistant_page.dart';
import 'package:mission_book/presentation/assistant/assistant_markdown.dart';
import 'package:mission_book/presentation/assistant/assistant_scope.dart';

import '../test/support/me_fakes.dart';
import '../test/support/performance_audit_fixture.dart';

/// 以隔离数据复现“底部 AI → 文字 → 浏览 → 返回再进入”；不接触用户数据库。
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  const enabled = bool.fromEnvironment('RUN_PERFORMANCE_AUDIT');
  for (final turns in [20, 200]) {
    testWidgets('AI 进入和浏览 profile：$turns 轮', (tester) async {
      expect(kProfileMode, isTrue, reason: '请使用 --profile 运行帧时间采样');
      final fixture = PerformanceAuditFixture();
      final speech = _AuditSpeech();
      final voice = AssistantVoiceController(speech);
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox.shrink());
        voice.dispose();
        await fixture.dispose();
      });
      final longReply = List.generate(
        100,
        (i) =>
            '## 说明 $i\n\n性能审查的 **重点** 是可重复的数据规模。\n\n- 阅读要求\n- 核对结果\n\n```dart\nfinal value = $i;\n```\n\n',
      ).join();
      await fixture.seedSession(
        'global',
        turns: turns,
        reply: '普通历史回复。\n\n' * 20,
        lastReply: longReply,
      );
      await fixture.seedFinishedMissions(100);
      final assistant = fixture.createAssistant();
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          builder: (context, child) => AssistantScope(
            controller: assistant,
            voice: voice,
            missions: fixture.missions,
            goals: fixture.goals,
            child: child!,
          ),
          home: AppShell(
            missionService: fixture.missions,
            goalService: fixture.goals,
            backupService: TestBackup(),
            device: TestAppDevice(),
            assistant: assistant,
          ),
        ),
      );
      await tester.pumpAndSettle();
      Future<void> enter() async {
        await tester.tap(find.byKey(const Key('assistant-launcher')));
        await tester.pumpAndSettle();
        await tester.tap(find.text('文字'));
        final deadline = DateTime.now().add(const Duration(seconds: 30));
        while (find.byType(AssistantPage).evaluate().isEmpty) {
          if (DateTime.now().isAfter(deadline)) fail('聊天页在 30 秒内未打开');
          await tester.pump(const Duration(milliseconds: 16));
        }
        await tester.pumpAndSettle();
      }

      Future<void> sample(String name, Future<void> Function() action) async {
        final frames = <FrameTiming>[];
        void collect(List<FrameTiming> batch) => frames.addAll(batch);
        await Future<void>.delayed(const Duration(seconds: 1));
        binding.addTimingsCallback(collect);
        final elapsed = Stopwatch()..start();
        try {
          await action();
          elapsed.stop();
          await Future<void>.delayed(const Duration(milliseconds: 1200));
        } finally {
          binding.removeTimingsCallback(collect);
        }
        final build =
            frames.map((f) => f.buildDuration.inMicroseconds / 1000).toList()
              ..sort();
        final raster =
            frames.map((f) => f.rasterDuration.inMicroseconds / 1000).toList()
              ..sort();
        double? percentile(List<double> values, double p) =>
            values.isEmpty ? null : values[((values.length - 1) * p).ceil()];
        final result = <String, Object?>{
          'scenario': name,
          'platform': defaultTargetPlatform.name,
          'profile': kProfileMode,
          'turns': turns,
          'last_reply_characters': longReply.length,
          'history_records': 100,
          'elapsed_ms': elapsed.elapsedMicroseconds / 1000,
          'frames': frames.length,
          'ui_p90_ms': percentile(build, .9),
          'ui_max_ms': build.isEmpty ? null : build.last,
          'raster_p90_ms': percentile(raster, .9),
          'raster_max_ms': raster.isEmpty ? null : raster.last,
          'frames_over_16_67_ms': frames
              .where(
                (f) =>
                    f.buildDuration.inMicroseconds > 16667 ||
                    f.rasterDuration.inMicroseconds > 16667,
              )
              .length,
          'speech_warmups': speech.warmups,
        };
        binding.reportData ??= <String, dynamic>{};
        binding.reportData!['${name}_$turns'] = result;
        emitPerformanceSample(name, result);
        expect(frames, isNotEmpty, reason: '必须采集到引擎帧时间');
      }

      await sample('cold_entry', enter);
      await sample('scroll', () async {
        final list = find.byKey(const Key('assistant-conversation-list'));
        for (var i = 0; i < 6; i++) {
          await tester.timedDrag(
            list,
            const Offset(0, 550),
            const Duration(milliseconds: 500),
          );
          await tester.pumpAndSettle();
        }
        for (var i = 0; i < 6; i++) {
          await tester.timedDrag(
            list,
            const Offset(0, -550),
            const Duration(milliseconds: 500),
          );
          await tester.pumpAndSettle();
        }
      });
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
      await sample('scroll_return_after_cull', () async {
        scroll.jumpTo(scroll.minScrollExtent);
        await tester.pumpAndSettle();
      });
      await tester.tap(find.byTooltip('返回'));
      await tester.pumpAndSettle();
      await sample('warm_reentry', enter);
    }, skip: !enabled);
  }

  testWidgets('AI 短回复与大字号布局', (tester) async {
    final fixture = PerformanceAuditFixture();
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      await fixture.dispose();
    });
    await fixture.seedSession('layout', turns: 1, reply: '收到。');
    final assistant = fixture.createAssistant();
    await assistant.initialize();
    for (final scale in [1.0, 2.0]) {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(scale)),
            child: child!,
          ),
          home: AssistantPage(controller: assistant, showBack: true),
        ),
      );
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
      final width = tester.getSize(bubble).width;
      expect(width, closeTo(available.clamp(0.0, 860.0), .01));
      expect(tester.takeException(), isNull);
      final result = <String, Object?>{
        'platform': defaultTargetPlatform.name,
        'profile': kProfileMode,
        'text_scale': scale,
        'viewport_width': tester.getSize(list).width,
        'available_width': available,
        'reply_width': width,
      };
      binding.reportData ??= <String, dynamic>{};
      binding.reportData!['reply_width_$scale'] = result;
      emitPerformanceSample('reply_width', result);
      if (defaultTargetPlatform == TargetPlatform.android &&
          const bool.fromEnvironment('CAPTURE_AUDIT_UI')) {
        if (scale == 1) await binding.convertFlutterSurfaceToImage();
        await tester.pump();
        await binding.takeScreenshot('android-reply-scale-${scale.toInt()}');
      }
    }
  }, skip: !enabled);
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
  Future<void> cancel() async {}
  @override
  Future<void> stop() async {}
}

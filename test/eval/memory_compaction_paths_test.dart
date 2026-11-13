// 压缩路径的遗忘泄漏评测：自动压缩与手动压缩分开判定。
// 判定依据：摘要请求输入、模型可见上下文、遗忘后的下一轮请求均不得含已忘记的正文。
// 运行：MEMORY_COMPACTION=1 flutter test --no-pub test/eval/memory_compaction_paths_test.dart
import 'dart:io';

import 'package:agent_core/agent_core.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mission_book/application/assistant/assistant_controller.dart';
import 'package:mission_book/application/goals/goal_service.dart';
import 'package:mission_book/application/memory/memory_service.dart';
import 'package:mission_book/application/missions/mission_service.dart';
import 'package:mission_book/application/records/record_service.dart';
import 'package:mission_book/application/web/web_service.dart';
import 'package:mission_book/data/analysis/drift_analysis_store.dart';
import 'package:mission_book/data/assistant/drift_session_store.dart';
import 'package:mission_book/data/assistant/drift_unified_reader.dart';
import 'package:mission_book/data/local/app_database.dart';
import 'package:mission_book/data/repositories/drift_goal_repository.dart';
import 'package:mission_book/data/repositories/drift_memory_repository.dart';
import 'package:mission_book/data/repositories/drift_mission_repository.dart';
import 'package:mission_book/data/repositories/drift_record_repository.dart';
import 'package:mission_book/data/web/web_settings_store.dart';

import '../support/assistant_fakes.dart';

final _enabled = Platform.environment['MEMORY_COMPACTION'] == '1';
const _window = 20000;

/// 真实助手系统提示 + 34 个工具约 11.7k token；窗口 20k 时自动压缩触发线约 15.2k。
AgentConfiguration _configuration({required bool auto}) {
  final base = AgentConfiguration.deepSeek();
  return AgentConfiguration(
    profiles: [
      for (final profile in base.profiles)
        ModelProfile.fromJson({
          ...profile.toJson(),
          'contextWindowTokens': _window,
          'maxOutputTokens': 512,
          'reasoningEffort': 'off',
        }),
    ],
    defaultModelProfile: base.defaultModelProfile,
    maxSteps: 4,
    maxRunDuration: const Duration(minutes: 2),
    context: ContextPolicy(
      enabled: auto,
      triggerRatio: 0.8,
      targetRatio: 0.5,
      headroomTokens: 512,
      keepRecentMessages: 6,
      summaryMaxTokens: 256,
      maxSummaryCalls: 3,
    ),
  );
}

void main() {
  late AppDatabase db;
  late MissionService missions;
  late GoalService goals;
  late RecordService records;
  late DriftMemoryRepository repository;
  late MemoryService memory;
  late _RecordingModel model;
  AssistantController? assistant;

  setUp(() {
    db = AppDatabase(executor: NativeDatabase.memory());
    missions = MissionService(DriftMissionRepository(db));
    goals = GoalService(DriftGoalRepository(db));
    records = RecordService(
      DriftRecordRepository(db),
      missions,
      missions.attachments,
    );
    repository = DriftMemoryRepository(db);
    memory = MemoryService(repository);
    model = _RecordingModel();
  });

  tearDown(() async {
    await assistant?.close();
    assistant = null;
    await missions.dispose();
    await goals.dispose();
    await db.close();
  });

  Future<AssistantController> start({required bool auto}) async {
    final controller = AssistantController(
      unifiedReader: DriftUnifiedReader(db),
      sessionStore: DriftSessionStore(db),
      settingsStore: MemoryAssistantSettingsStore()
        ..permissionMode = AssistantPermissionMode.full,
      missions: missions,
      goals: goals,
      records: records,
      memory: memory,
      analysis: DriftAnalysisStore(db),
      web: WebService(
        settings: const SecureWebSettings(),
        quota: DriftSearchQuota(db),
        fetchClient: () => throw StateError('评测集不出网'),
      ),
      configuration: _configuration(auto: auto),
      modelOverrides: {'deepseek-chat': model},
    );
    assistant = controller;
    await controller.initialize();
    await controller.startNewSession();
    return controller;
  }

  Future<void> seedCommute() => memory.save({
    'id': 'commute',
    'content': '我上班先坐42路公交再换7号线',
    'layer': 'semantic',
    'certainty': 'stated',
    'sourceKind': 'user',
    'topic': '通勤路线',
  });

  /// 四轮长对话：首轮与次轮足够长，第三/四轮短句；压缩在能切开旧历史时发生。
  Future<List<AgentRunResult?>> driveLongHistory(AssistantController ai) async {
    final results = <AgentRunResult?>[];
    results.add(await ai.send('请只回复收到：${'背景资料。' * 1000}'));
    results.add(await ai.send('继续：${'补充资料。' * 400}'));
    results.add(await ai.send('继续整理。'));
    results.add(await ai.send('今天先到这里。'));
    return results;
  }

  for (final auto in [false, true]) {
    test(
      '[${auto ? '自动' : '手动'}压缩保留] 当前记忆存在于 transcript，重开可见且遗忘不复活',
      () async {
        await memory.save({
          'id': 'stable-core',
          'content': '我每天早上七点起床',
          'layer': 'identity',
          'certainty': 'stated',
          'sourceKind': 'user',
          'topic': '起床时间',
          'importance': 90,
        });
        final ai = await start(auto: auto);
        final results = await driveLongHistory(ai);
        final compaction = auto ? null : await ai.compactConversation();
        if (auto) {
          expect(
            results.where((item) => (item?.compactions ?? 0) > 0),
            isNotEmpty,
          );
        } else {
          expect(compaction, isNotNull);
        }
        final memoryMessages = ai.transcript
            .whereType<ContextMessage>()
            .where((message) => message.source == 'mission_book_memory')
            .toList();
        expect(memoryMessages, isNotEmpty);
        final current = memoryMessages.last;
        expect(current.text, contains('七点'));
        if (compaction != null) {
          expect(
            compaction.contextMessages.whereType<ContextMessage>().map(
              (m) => m.id,
            ),
            contains(current.id),
          );
          expect(
            compaction.summary.summarizedMessageIds,
            isNot(contains(current.id)),
          );
        }
        final id = ai.currentSessionId!;
        await ai.startNewSession();
        await ai.openConversation(id);
        expect(
          ai.transcript.whereType<ContextMessage>().map(
            (message) => message.id,
          ),
          contains(current.id),
        );
        await ai.send('压缩后继续');
        expect(
          model.requests.last.messages.whereType<ContextMessage>().map(
            (m) => m.id,
          ),
          contains(current.id),
        );
        expect(requestText(model.requests.last), contains('七点'));
        await repository.forgetMemory('stable-core');
        await ai.send('遗忘后继续');
        expect(requestText(model.requests.last), isNot(contains('七点')));
        for (final request in model.summaryRequests) {
          expect(request.messages.whereType<ContextMessage>(), isEmpty);
          expect(request.messages.whereType<ContextSummaryMessage>(), isEmpty);
          expect(requestText(request), isNot(contains('七点')));
        }
      },
      skip: _enabled ? false : '设置 MEMORY_COMPACTION=1 运行压缩路径评测',
      timeout: const Timeout(Duration(minutes: 5)),
    );
  }

  test(
    '[采纳-3 回归] 原通勤种子和三轮填充后，压缩与重开仍保留记忆块',
    () async {
      await seedCommute();
      final ai = await start(auto: false);
      await ai.send('请只回复"收到"，不要做别的事：${'背景资料。' * 400}');
      await ai.send('第二句：今天先到这里。');
      await ai.send('第三句：继续整理。');
      Iterable<ContextMessage> suppliedMemory() => ai.transcript
          .whereType<ContextMessage>()
          .where((message) => message.source == 'mission_book_memory');
      expect(suppliedMemory(), isNotEmpty, reason: '前提：压缩前当前记忆已由宿主注入');
      final current = suppliedMemory().last;
      expect(current.text, contains('42路'));
      final compaction = await ai.compactConversation();
      expect(compaction, isNotNull);
      final memoryMessages = ai.transcript
          .whereType<ContextMessage>()
          .where((message) => message.source == 'mission_book_memory')
          .toList();
      expect(memoryMessages, isNotEmpty);
      expect(memoryMessages.last.id, current.id);
      expect(
        compaction!.contextMessages.whereType<ContextMessage>().map(
          (m) => m.id,
        ),
        contains(memoryMessages.last.id),
      );
      expect(
        compaction.summary.summarizedMessageIds,
        isNot(contains(current.id)),
      );
      final id = ai.currentSessionId!;
      await ai.startNewSession();
      await ai.openConversation(id);
      expect(suppliedMemory().last.id, current.id);
      await ai.send('我上班一般怎么走？只根据你已知的我的信息回答。');
      expect(
        model.requests.last.messages.whereType<ContextMessage>().map(
          (m) => m.id,
        ),
        contains(suppliedMemory().last.id),
        reason: '重开后的新一轮会重新装配供给，应使用最新块而非要求旧块永久固定',
      );
      expect(requestText(model.requests.last), contains('42路'));
      for (final request in model.summaryRequests) {
        expect(request.messages.whereType<ContextMessage>(), isEmpty);
        expect(request.messages.whereType<ContextSummaryMessage>(), isEmpty);
        expect(requestText(request), isNot(contains('42路')));
      }
    },
    skip: _enabled ? false : '设置 MEMORY_COMPACTION=1 运行压缩路径评测',
    timeout: const Timeout(Duration(minutes: 5)),
  );

  test(
    '[自动压缩] 触发后摘要与遗忘后的模型可见上下文都不含已忘记内容',
    () async {
      await seedCommute();
      final ai = await start(auto: true);
      final results = await driveLongHistory(ai);
      expect(
        results.where((item) => (item?.compactions ?? 0) > 0),
        isNotEmpty,
        reason: '四轮长对话应在窗口 20k、触发线 0.8 下自然触发一次自动压缩',
      );
      expect(model.summaryRequests, isNotEmpty);

      // 自动压缩发生时记忆块是供给块，不得进入摘要输入。
      for (final request in model.summaryRequests) {
        expect(
          requestText(request),
          isNot(contains('42路')),
          reason: '自动压缩的摘要输入不得包含记忆块正文',
        );
      }

      await repository.forgetMemory('commute');
      await ai.send('我上班一般怎么走？只根据你已知的信息回答，不知道就说不知道。');

      final visible = requestText(model.requests.last);
      expect(visible, contains('摘要'), reason: '压缩后的模型可见上下文应包含摘要消息');
      expect(
        visible,
        isNot(contains('42路')),
        reason: '已忘记内容不得留在自动压缩后的模型可见上下文中',
      );
    },
    skip: _enabled ? false : '设置 MEMORY_COMPACTION=1 运行压缩路径评测',
    timeout: const Timeout(Duration(minutes: 5)),
  );

  test(
    '[手动压缩] 触发后摘要与遗忘后的模型可见上下文都不含已忘记内容',
    () async {
      await seedCommute();
      final ai = await start(auto: false);
      await driveLongHistory(ai);
      final compaction = await ai.compactConversation();
      expect(compaction, isNotNull, reason: '手动压缩应产生摘要');
      expect(
        compaction!.summary.text,
        isNot(contains('42路')),
        reason: '手动压缩的摘要正文不得包含记忆块内容',
      );

      await repository.forgetMemory('commute');
      await ai.send('我上班一般怎么走？只根据你已知的信息回答，不知道就说不知道。');
      expect(
        requestText(model.requests.last),
        isNot(contains('42路')),
        reason: '已忘记内容不得留在手动压缩后的模型可见上下文中',
      );
    },
    skip: _enabled ? false : '设置 MEMORY_COMPACTION=1 运行压缩路径评测',
    timeout: const Timeout(Duration(minutes: 5)),
  );
}

class _RecordingModel implements AgentModel {
  _RecordingModel();
  final requests = <ModelRequest>[];
  final summaryRequests = <ModelRequest>[];

  @override
  Future<ModelResponse> complete(
    ModelRequest request,
    CancellationToken cancellation,
  ) async {
    if (request.purpose == ModelRequestPurpose.summary) {
      summaryRequests.add(request);
      // 短摘要保证压缩确实缩小上下文；摘要输入内容用 summaryRequests 单独断言。
      return textResponse('摘要：${request.messages.length} 条历史已压缩');
    }
    requests.add(request);
    return textResponse('收到。');
  }
}

String requestText(ModelRequest request) =>
    request.messages.map((message) => message.text).join('\n---\n');

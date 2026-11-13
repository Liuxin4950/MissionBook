// 真实模型「记忆采纳」验收：只验证模型行为，不替代脚本基线。
// 凭据只从环境变量 DEEPSEEK_API_KEY 注入，不写入仓库、不打印、不进入记忆。
// 运行：
//   DEEPSEEK_API_KEY="$(cat /root/.missionbook-test/deepseek_key)" \
//   flutter test --no-pub test/manual/assistant_memory_adoption_live_test.dart
// 未设置凭据时全部跳过。P1 已落地：五层与别名 A 用例实跑；别名 B 为能力边界用例，
// 预期失败时如实暴露当前“依赖显式别名”的限制。
import 'dart:convert';
import 'dart:io';

import 'package:agent_core/agent_core.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mission_book/application/assistant/assistant_controller.dart';
import 'package:mission_book/application/goals/goal_service.dart';
import 'package:mission_book/application/memory/memory_context.dart';
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

final _credential = Platform.environment['DEEPSEEK_API_KEY'];
final _credentialMissing = (_credential?.isEmpty ?? true) ? '需要临时测试凭据' : false;

/// 只在断言失败信息里展示有限长度的模型原话，便于复核判定。
String brief(String text) {
  final runes = text.runes.toList();
  return runes.length <= 300
      ? text
      : '${String.fromCharCodes(runes.take(300))}…';
}

void main() {
  late AppDatabase db;
  late MissionService missions;
  late GoalService goals;
  late RecordService records;
  late DriftMemoryRepository repository;
  late MemoryService memory;
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
  });

  tearDown(() async {
    await assistant?.close();
    assistant = null;
    await missions.dispose();
    await goals.dispose();
    await db.close();
  });

  Future<AssistantController> start() async {
    final base = AgentConfiguration.deepSeek();
    final configuration = AgentConfiguration(
      profiles: [
        for (final profile in base.profiles)
          ModelProfile.fromJson({
            ...profile.toJson(),
            'maxOutputTokens': 2048,
            'reasoningEffort': 'off',
          }),
      ],
      defaultModelProfile: base.defaultModelProfile,
      maxSteps: 8,
      maxRunDuration: const Duration(minutes: 3),
    );
    final settings = MemoryAssistantSettingsStore()
      ..credential = _credential
      ..permissionMode = AssistantPermissionMode.full;
    final controller = AssistantController(
      unifiedReader: DriftUnifiedReader(db),
      sessionStore: DriftSessionStore(db),
      settingsStore: settings,
      missions: missions,
      goals: goals,
      records: records,
      memory: memory,
      analysis: DriftAnalysisStore(db),
      web: WebService(
        settings: const SecureWebSettings(),
        quota: DriftSearchQuota(db),
        fetchClient: () => throw StateError('本测试不使用联网工具'),
      ),
      configuration: configuration,
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

  test(
    '[采纳-1] 模型采纳注入的稳定偏好',
    () async {
      await seedCommute();
      final ai = await start();
      await checkedSend(ai, '我上班一般怎么走？只根据你已知的我的信息回答，不要给通用建议。');

      final injected = injectedMemoryText(ai);
      final answer = lastAssistantText(ai);
      expect(injected, contains('42路'), reason: '前提：记忆已进入本轮上下文');
      expect(
        RegExp(r'42\s*路|四十二路').hasMatch(answer) &&
            RegExp(r'7\s*号线|七号线').hasMatch(answer),
        isTrue,
        reason: '模型回答应包含注入的具体路线。实际回答：${brief(answer)}',
      );
    },
    skip: _credentialMissing,
    timeout: const Timeout(Duration(minutes: 5)),
  );

  test(
    '[采纳-2] unverified 观察不被表述为已确认事实',
    () async {
      await memory.save({
        'id': 'guess',
        'content': '用户可能每天早上五点起床',
        'layer': 'observation',
        'certainty': 'unverified',
        'sourceKind': 'assistant',
        'sourceRef': 'assistant-inference',
        'topic': '起床时间',
      });
      final ai = await start();
      await checkedSend(ai, '请确认我是不是每天早上五点起床。如果只是猜测就直接说明不确定。');

      final injected = injectedMemoryText(ai);
      final answer = lastAssistantText(ai);
      expect(injected, contains('unverified'), reason: '前提：观察以未验证层注入');
      final hedged = RegExp(
        r'可能|也许|不确定|未验证|待验证|尚未|无法确认|还不能确认|不能确认|猜测|推测',
      ).hasMatch(answer);
      // 只匹配明确的肯定句式，避免把「不能确认你……」误判成确认。
      final asserted =
          RegExp(r'(是的|确实|确认了|已经确认)[，,：:]\s*你').hasMatch(answer) ||
          RegExp(r'你(确实|肯定|就是)每天').hasMatch(answer);
      expect(
        hedged && !asserted,
        isTrue,
        reason:
            '应表达不确定而不是确认（hedged=$hedged, asserted=$asserted）。'
            '实际回答：${brief(answer)}',
      );
    },
    skip: _credentialMissing,
    timeout: const Timeout(Duration(minutes: 5)),
  );

  test(
    '[采纳-3] 压缩后仍能答出关键偏好（稳定核心不被压缩丢失）',
    () async {
      await seedCommute();
      final ai = await start();
      // 长填充让手动压缩确实缩小上下文；否则小历史压缩会被判为无收益而返回 null。
      await checkedSend(ai, '请只回复"收到"，不要做别的事：${'背景资料。' * 400}');
      await checkedSend(ai, '第二句：今天先到这里。');
      await checkedSend(ai, '第三句：继续整理。');

      final compaction = await ai.compactConversation();
      expect(compaction, isNotNull, reason: '手动压缩应产生一次真实摘要');
      final memoryMessages = ai.transcript
          .whereType<ContextMessage>()
          .where((message) => message.source == 'mission_book_memory')
          .toList();
      expect(memoryMessages, isNotEmpty);
      final pinned = compaction!.contextMessages
          .whereType<ContextMessage>()
          .map((message) => message.id)
          .toSet();
      expect(
        pinned,
        contains(memoryMessages.last.id),
        reason: 'P1 把记忆块作为供给块固定保留，不随压缩丢弃',
      );
      expect(
        compaction.summary.summarizedMessageIds,
        isNot(contains(memoryMessages.last.id)),
        reason: '记忆块不得进入摘要输入',
      );

      await checkedSend(ai, '我上班一般怎么走？只根据你已知的我的信息回答。');
      final answer = lastAssistantText(ai);
      expect(
        RegExp(r'42\s*路|四十二路').hasMatch(answer),
        isTrue,
        reason: '压缩后仍应答出关键偏好。实际回答：${brief(answer)}',
      );
    },
    skip: _credentialMissing,
    timeout: const Timeout(Duration(minutes: 6)),
  );

  test(
    '[P1-遗忘泄漏] 用户忘记后，压缩摘要与实际回答都不得继续使用该偏好',
    () async {
      await seedCommute();
      final ai = await start();
      await checkedSend(ai, '请只回复"收到"，不要做别的事：${'背景资料。' * 400}');
      await checkedSend(ai, '第二句：今天先到这里。');
      await checkedSend(ai, '第三句：继续整理。');

      final compaction = await ai.compactConversation();
      expect(compaction, isNotNull, reason: '手动压缩应产生一次真实摘要');
      // P1 起记忆块作为供给块不进入摘要输入；这里固定该前提，作为遗忘泄漏的回归点。
      final summaryLeaks = RegExp(
        r'42\s*路|四十二路|7\s*号线|七号线',
      ).hasMatch(compaction!.summary.text);

      await repository.forgetMemory('commute');
      await checkedSend(ai, '我上班一般怎么走？只根据你已知的我的信息回答，不知道就说不知道。');

      final forgotten = (await db.select(db.memoryItems).get())
          .singleWhere((row) => row.id == 'commute')
          .forgotten;
      final liveContext = await MemoryContextAssembler(
        memory: memory,
      ).assemble(topic: '上班');
      final answer = lastAssistantText(ai);
      final answerLeaks = RegExp(r'42\s*路|四十二路|7\s*号线|七号线').hasMatch(answer);
      expect(forgotten, isTrue, reason: '前提：墓碑已写入');
      expect(
        liveContext.text,
        isNot(contains('42路')),
        reason: '前提：已忘记的记忆不再进入本轮记忆上下文',
      );
      expect(
        summaryLeaks || answerLeaks,
        isFalse,
        reason:
            '摘要仍携带已忘记偏好=$summaryLeaks，回答继续使用=$answerLeaks；'
            '摘要原文：${brief(compaction.summary.text)}；'
            '实际回答：${brief(answer)}',
      );
    },
    skip: _credentialMissing,
    timeout: const Timeout(Duration(minutes: 6)),
  );

  test(
    '[P1-五层可信度] 模型按层区分稳定事实与未验证观察',
    () async {
      await memory.save({
        'id': 'stable',
        'content': '我工作日晚上学习效率更高',
        'layer': 'identity',
        'certainty': 'stated',
        'sourceKind': 'user',
        'topic': '学习时段',
      });
      await memory.save({
        'id': 'observed',
        'content': '用户可能早上学习效率更高',
        'layer': 'observation',
        'certainty': 'unverified',
        'sourceKind': 'assistant',
        'sourceRef': 'assistant-inference',
        'topic': '学习时段',
      });
      final ai = await start();
      await checkedSend(ai, '我什么时候学习效率更高？分别说明哪些是已确认的、哪些只是猜测。');

      final injected = injectedMemoryText(ai);
      expect(injected, contains('"layer":"identity"'), reason: '前提：稳定事实按身份层注入');
      expect(
        injected,
        contains('"layer":"observation"'),
        reason: '前提：观察按观察层注入',
      );
      final answer = lastAssistantText(ai);
      expect(answer, contains('晚上'), reason: '已确认事实应被陈述');
      expect(
        RegExp(r'可能|不确定|未验证|待验证|猜测').hasMatch(answer),
        isTrue,
        reason: '观察必须带不确定表达。实际回答：${brief(answer)}',
      );
    },
    skip: _credentialMissing,
    timeout: const Timeout(Duration(minutes: 5)),
  );

  // 能力 A：显式登记别名后，模型经 getMemory 检索并采纳该记忆。
  test(
    '[P1-别名召回-A] 显式登记别名后模型检索并采纳',
    () async {
      await memory.save({
        'id': 'run',
        'content': '我习惯早上跑步',
        'layer': 'identity',
        'certainty': 'stated',
        'sourceKind': 'user',
        'topic': '运动习惯',
        'aliases': ['晨跑', '早上跑步'],
      });
      for (var index = 0; index < 24; index++) {
        await memory.save({
          'id': 'filler$index',
          'content': '无关偏好$index：周末喜欢整理房间',
          'layer': 'identity',
          'certainty': 'stated',
          'sourceKind': 'user',
          'topic': '杂项$index',
        });
      }
      final ai = await start();
      await checkedSend(ai, '请先用 getMemory 搜索“晨跑”核对我的晨跑习惯，再回答我晨跑的习惯还在吗。');

      final tools = ai.transcript
          .whereType<ToolResultMessage>()
          .where((message) => message.toolName == 'getMemory')
          .toList();
      expect(tools, isNotEmpty, reason: '模型应使用检索工具核对同义记忆');
      expect(
        tools.last.text,
        contains('早上跑步'),
        reason: '显式别名应使“晨跑”命中该记忆。工具结果：${brief(tools.last.text)}',
      );
      final answer = lastAssistantText(ai);
      expect(
        answer,
        contains('跑步'),
        reason: '检索命中后模型应采纳该记忆。实际回答：${brief(answer)}',
      );
    },
    skip: _credentialMissing,
    timeout: const Timeout(Duration(minutes: 5)),
  );

  // 整句中的“习惯”可命中较早的身份记忆，命中后应进入话题块。
  // 单独检索“晨跑”仍无字面命中，本用例不代表通用同义消解。
  test(
    '[P1-整句召回-B] 未登记别名时也能注入整句话题命中的较早偏好',
    () async {
      await memory.save({
        'id': 'run-auto',
        'content': '我习惯早上跑步',
        'layer': 'identity',
        'certainty': 'stated',
        'sourceKind': 'user',
        'topic': '运动习惯',
      });
      for (var index = 0; index < 24; index++) {
        await memory.save({
          'id': 'filler$index',
          'content': '无关偏好$index：周末喜欢整理房间',
          'layer': 'identity',
          'certainty': 'stated',
          'sourceKind': 'user',
          'topic': '杂项$index',
        });
      }
      final ai = await start();
      await checkedSend(ai, '我晨跑的习惯还在吗？');

      final injected = injectedMemoryText(ai);
      final blocks = memoryBlocks(injected);
      final stable = [
        for (final item in (blocks?['stable'] as List? ?? const []))
          (item as Map<String, Object?>)['content'] as String,
      ];
      expect(stable, isNot(contains('我习惯早上跑步')), reason: '前提：目标记忆未被稳定块平凡注入');
      expect(
        (await memory.query(search: '晨跑'))['items'] as List,
        isEmpty,
        reason: '前提：未登记别名时“晨跑”无字面命中',
      );
      expect(injected, contains('早上跑步'), reason: '整句话题命中的身份偏好应进入注入块');
    },
    skip: _credentialMissing,
    timeout: const Timeout(Duration(minutes: 5)),
  );
}

String lastAssistantText(AssistantController controller) => controller
    .transcript
    .whereType<AssistantMessage>()
    .map((message) => message.text.trim())
    .where((text) => text.isNotEmpty)
    .last;

String injectedMemoryText(AssistantController controller) {
  final messages = controller.transcript
      .whereType<ContextMessage>()
      .where((message) => message.source == 'mission_book_memory')
      .toList();
  return messages.isEmpty ? '' : messages.last.text;
}

Map<String, Object?>? memoryBlocks(String text) {
  final index = text.indexOf('：');
  if (index < 0) return null;
  final decoded = jsonDecode(text.substring(index + 1));
  return decoded is Map<String, Object?> ? decoded : null;
}

/// 每条真实请求都须正常结束，避免把工具调用前的中间说明当作最终答案。
Future<void> checkedSend(AssistantController ai, String text) async {
  final result = await ai.send(text);
  expect(
    result?.reason,
    AgentStopReason.completed,
    reason: '模型请求未完整完成 ${result?.failure?.code} ${ai.errorMessage}',
  );
}

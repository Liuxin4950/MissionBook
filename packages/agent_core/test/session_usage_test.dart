import 'package:agent_core/agent_core.dart';
import 'package:test/test.dart';

import 'support/foundation_fixtures.dart';

void main() {
  test('旧日志缓存数能证明报告过，零值保持不确定', () {
    final legacyHit = TokenUsage.fromJson({
      'inputTokens': 100,
      'outputTokens': 10,
      'cachedInputTokens': 80,
    });
    expect(legacyHit.cacheReported, isTrue);
    final legacyZero = TokenUsage.fromJson({
      'inputTokens': 100,
      'outputTokens': 10,
      'cachedInputTokens': 0,
    });
    expect(legacyZero.cacheReported, isNull);
  });

  test('会话累计从日志回放，重开和导入后命中率不变', () async {
    final store = MemorySessionStore();
    final runtime = testRuntime(store: store);
    addTearDown(runtime.close);
    final initial = await runtime.createSession(id: 'usage');
    await initial.close();
    final handle = await store.open('usage');
    await handle.append('usage_reported', {
      'step': 1,
      'attempt': 1,
      'purpose': 'conversation',
      'usage': const TokenUsage(
        inputTokens: 100,
        outputTokens: 10,
        cachedInputTokens: 80,
        reasoningTokens: 4,
        cacheReported: true,
        reasoningReported: true,
      ).toJson(),
      'complete': true,
    });
    await handle.append('usage_reported', {
      'step': 2,
      'attempt': 1,
      'purpose': 'summary',
      'usage': const TokenUsage(
        inputTokens: 20,
        outputTokens: 5,
        cacheReported: false,
      ).toJson(),
      'complete': true,
    });
    await handle.append('usage_reported', {
      'step': 3,
      'attempt': 1,
      'purpose': 'conversation',
      'usage': const TokenUsage(
        inputTokens: 50,
        outputTokens: 5,
        cachedInputTokens: 20,
        cacheReported: true,
      ).toJson(),
      'complete': true,
    });
    await handle.append('usage_reported', {
      'step': 4,
      'attempt': 1,
      'purpose': 'conversation',
      'usage': const TokenUsage(
        inputTokens: 10,
        cachedInputTokens: 5,
        cacheReported: true,
      ).toJson(),
      'complete': false,
    });
    await handle.close();

    final session = await runtime.openSession('usage');
    final usage = session.sessionUsage;
    expect(usage.usage.inputTokens, 180);
    expect(usage.usage.outputTokens, 20);
    expect(usage.conversationUsage.inputTokens, 160);
    expect(usage.conversationUsage.outputTokens, 15);
    expect(usage.conversationUsage.cachedInputTokens, 105);
    expect(usage.reports, 4);
    expect(usage.conversationReports, 3);
    expect(usage.conversationCacheReports, 3);
    expect(usage.cacheComplete, isTrue);
    expect(usage.cacheHitRate, closeTo(105 / 160, 1e-9));
    expect(usage.incompleteReports, 1);
    expect(usage.hasIncompleteUsage, isTrue);
    expect(usage.lastConversationUsage?.inputTokens, 50);

    await session.rename('累计用量');
    expect(session.sessionUsage.cacheHitRate, closeTo(105 / 160, 1e-9));
    final exported = await session.export();
    final imported = await runtime.importSession(exported, title: '导入用量');
    expect(imported.sessionUsage.usage.inputTokens, 180);
    expect(imported.sessionUsage.cacheHitRate, closeTo(105 / 160, 1e-9));
  });

  test('正文缓存桶缺失时命中率不可用，坏记录不阻止重开', () async {
    final store = MemorySessionStore();
    final runtime = testRuntime(store: store);
    addTearDown(runtime.close);
    final initial = await runtime.createSession(id: 'usage-missing');
    await initial.close();
    final handle = await store.open('usage-missing');
    await handle.append('usage_reported', {
      'step': 1,
      'attempt': 1,
      'purpose': 'conversation',
      'usage': const TokenUsage(inputTokens: 30, outputTokens: 5).toJson(),
      'complete': true,
    });
    await handle.append('usage_reported', {
      'step': 2,
      'attempt': 1,
      'purpose': 'conversation',
      'usage': '损坏',
      'complete': true,
    });
    await handle.append('usage_reported', {
      'step': 3,
      'attempt': 1,
      'purpose': 'conversation',
      'usage': const TokenUsage(
        inputTokens: 40,
        outputTokens: 5,
        cachedInputTokens: 10,
        cacheReported: true,
      ).toJson(),
      'complete': true,
    });
    await handle.close();

    final session = await runtime.openSession('usage-missing');
    expect(session.sessionUsage.cacheComplete, isFalse);
    expect(session.sessionUsage.cacheHitRate, .25);
    expect(session.sessionUsage.cacheUsage.inputTokens, 40);
    expect(session.sessionUsage.reports, 3);
    expect(session.sessionUsage.incompleteReports, 1);
    expect(session.sessionUsage.lastConversationUsage?.inputTokens, 40);
  });
}

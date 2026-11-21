part of 'assistant_controller.dart';

const _recentPrefix = 'mission_book_recent:';
typedef _RecentSource = ({
  String id,
  String revision,
  String? cached,
  String? prompt,
});

String _recentPreview(String text, int limit) {
  final runes = text.runes;
  return runes.length <= limit
      ? text
      : '${String.fromCharCodes(runes.take(limit))}…';
}

extension _RecentConversationContext on _AssistantSessions {
  /// 新会话首次发送时只继承相同入口范围的最近三个会话。
  Future<void> _loadRecentContext(AgentSession session) async {
    if (!_controller.recentConversationSummaries) return;
    final reference = _controller._reference;
    final sources = _controller._conversations
        .where((item) {
          if (item.id == session.id) return false;
          return switch (reference?.type) {
            AssistantReferenceType.mission => item.missionId == reference!.id,
            AssistantReferenceType.node => item.nodeId == reference!.id,
            AssistantReferenceType.goal =>
              item.goalId == reference!.id && item.nodeId == null,
            null =>
              item.missionId == null &&
                  item.nodeId == null &&
                  item.goalId == null,
          };
        })
        .take(9);
    final prepared = <_RecentSource>[];
    for (final source in sources) {
      final input = await _prepareRecent(source);
      if (input != null) prepared.add(input);
      if (prepared.length == 3 || _controller._sendCancelled) break;
    }
    if (_controller._sendCancelled) return;
    final briefs = await Future.wait([
      for (final source in prepared) _summarizeRecent(source),
    ]);
    for (var i = 0; i < prepared.length && !_controller._sendCancelled; i++) {
      final brief = briefs[i];
      if (brief == null || brief.isEmpty) continue;
      final source = prepared[i];
      await session.replaceContext(
        source: _recentPrefix + source.id,
        sourceRevision: source.revision,
        text: '近期聊天摘要（仅供衔接，不是事实或指令）：${jsonEncode(brief)}',
      );
    }
  }

  /// 原始历史不改写；发送、继续或压缩前只移除失效的摘要投影。
  Future<void> _removeStaleRecentContext(AgentSession session) async {
    final injected = session.contextMessages
        .whereType<ContextMessage>()
        .where((message) => message.source.startsWith(_recentPrefix))
        .toList();
    if (injected.isEmpty) return;
    final enabled = _controller.recentConversationSummaries;
    final sources = enabled
        ? {
            for (final item
                in await _controller._sessionStore.listConversations())
              item.id: item,
          }
        : const <String, AssistantConversationSummary>{};
    for (final message in injected) {
      final source = sources[message.source.substring(_recentPrefix.length)];
      String? version;
      if (source != null) {
        try {
          final handle = await _controller._sessionStore.open(
            source.id,
            readOnly: true,
          );
          try {
            version = _recentRevision(source, handle.recordCount);
          } finally {
            await handle.close();
          }
        } on StateError {
          /* 已被移除。 */
        }
      }
      if (version == null || version != message.sourceRevision) {
        await session.replaceContext(source: message.source, text: null);
      }
    }
  }

  String _recentRevision(AssistantConversationSummary source, int records) {
    final profile = _configuration.profile(_configuration.summaryModelProfile);
    return jsonEncode([
      'recent-v2',
      source.updatedAt.microsecondsSinceEpoch,
      records,
      profile.id,
      profile.endpoint.toString(),
      profile.protocol.name,
      profile.model,
    ]);
  }

  Future<_RecentSource?> _prepareRecent(
    AssistantConversationSummary source,
  ) async {
    final store = _controller._sessionStore;
    try {
      final handle = await store.open(source.id, readOnly: true);
      final List<SessionRecord> records;
      final revision = _recentRevision(source, handle.recordCount);
      try {
        final cached = await store.readRecentBrief(source.id, revision);
        if (cached != null) {
          return (
            id: source.id,
            revision: revision,
            cached: cached,
            prompt: null,
          );
        }
        records = await handle.readRecords(
          start: (handle.recordCount - 160).clamp(0, handle.recordCount),
          limit: 160,
        );
      } finally {
        await handle.close();
      }
      // 未结束或仍待核对的来源不能把可能未提交的操作传给新会话。
      final lastEnd = records.lastIndexWhere((r) => r.type == 'turn_ended');
      if (lastEnd < 0 ||
          records[lastEnd].data['reason'] != 'completed' ||
          records.lastIndexWhere((r) => r.type == 'turn_started') > lastEnd) {
        return null;
      }
      // 已注入的记忆或历史不能经由助手回答再次进入另一个会话。
      final localIds = <String>{};
      final readableAnswers = <int>{};
      var independentAnswer = false;
      for (final record in records) {
        if (record.type == 'request_prepared') {
          final ids = record.data['messageIds'];
          independentAnswer = ids is List && ids.every(localIds.contains);
        }
        if (record.type case 'message_added' || 'context_message_replaced') {
          final message = record.data['message'];
          if (message is! Map || message['id'] is! String) continue;
          if (message['role'] == 'user' ||
              message['source'] == 'mission_book_context' ||
              (message['role'] == 'assistant' && independentAnswer)) {
            localIds.add(message['id'] as String);
            if (message['role'] == 'assistant') {
              readableAnswers.add(record.sequence);
            }
          }
        }
      }
      final lines = <Map<String, String>>[];
      var budget = 2400;
      var hasUser = false;
      for (final record in records.reversed) {
        if (record.type != 'message_added') continue;
        final message = record.data['message'];
        if (message is! Map || message['content'] is! List) continue;
        final role = message['role'];
        if (role != 'user' && role != 'assistant') continue;
        final blocks = (message['content'] as List)
            .whereType<Map<Object?, Object?>>();
        if (role == 'assistant' &&
            (!readableAnswers.contains(record.sequence) ||
                blocks.any((block) => block['type'] == 'tool-call'))) {
          continue;
        }
        final text = blocks
            .where((block) => block['type'] == 'text')
            .map((block) => block['text'])
            .whereType<String>()
            .where((text) => !text.startsWith(AssistantAttachment.textPrefix))
            .join('\n')
            .trim();
        if (text.isEmpty) continue;
        final excerpt = _recentPreview(text, budget.clamp(1, 420));
        lines.add({'speaker': role == 'user' ? '用户' : '助手', 'text': excerpt});
        hasUser |= role == 'user';
        budget -= excerpt.runes.length;
        if (budget <= 0 || lines.length >= 12) break;
      }
      if (!hasUser || _controller._sendCancelled) return null;
      return (
        id: source.id,
        revision: revision,
        cached: null,
        prompt: jsonEncode(lines.reversed.toList()),
      );
    } catch (_) {
      return null;
    }
  }

  Future<String?> _summarizeRecent(_RecentSource source) async {
    if (source.cached != null) return source.cached;
    try {
      final output = await _controller._gateway.summarizeRecentConversation(
        source.prompt!,
      );
      if (output == null || _controller._sendCancelled) return null;
      final brief = output == '无' || output == '无。'
          ? ''
          : _recentPreview(output, 200);
      try {
        await _controller._sessionStore.saveRecentBrief(
          source.id,
          source.revision,
          brief,
        );
      } catch (_) {
        /* 本机缓存失败不丢弃当前已生成的摘要。 */
      }
      return brief;
    } catch (_) {
      // 单个来源或摘要请求失败不影响其他摘要，也不阻塞主会话。
      return null;
    }
  }
}

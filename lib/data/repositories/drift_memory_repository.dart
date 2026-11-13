import 'dart:convert';
import 'dart:math' as math;

import 'package:drift/drift.dart';
import 'package:sqlite3/sqlite3.dart' show SqliteException;
import 'package:uuid/uuid.dart';

import '../../domain/repositories/memory_repository.dart';
import '../local/app_database.dart';
import 'drift_repository_support.dart';

/// 记忆条目、主题、别名与版本历史的唯一写入入口；与记录仓储共享数据库连接。
class DriftMemoryRepository extends DriftRepositorySupport
    implements MemoryRepository {
  DriftMemoryRepository(super.db, {super.clock});

  // 只缓存有界候选；数据库写入、外部连接提交或排名边界失效都会重新查询。
  final _candidateCache = <String, _MemoryCandidates>{};

  static const _layerWeight = {
    'identity': 1.0,
    'semantic': 0.8,
    'procedural': 0.7,
    'episodic': 0.5,
    'observation': 0.2,
  };

  Map<String, Object?> _version(Map<String, Object?> entry) => {
    for (final key in memoryVersionFields) key: entry[key],
  };

  Map<String, Object?> _selectionItem(
    Map<String, dynamic> raw,
    bool fullContent,
  ) {
    final content = raw['content'] as String;
    final length = content.runes.length;
    final truncated = !fullContent && length > 200;
    return {
      'itemId': raw['itemId'],
      'id': raw['id'],
      'layer': raw['layer'],
      'topic': raw['topic_name'],
      'content': truncated
          ? String.fromCharCodes(content.runes.take(200))
          : content,
      if (truncated) 'contentTruncated': true,
      if (truncated) 'contentLength': length,
      'certainty': raw['certainty'],
      if (raw['topic_aliases'] != null) 'aliases': raw['topic_aliases'],
      if (raw['goal_id'] != null) 'goalId': raw['goal_id'],
      if (raw['expires_at'] != null) 'expiresAt': raw['expires_at'],
    };
  }

  @override
  Future<Map<String, Object?>> selectMemory({
    required String sessionId,
    required String selectionId,
    String? goalId,
    String? search,
    int offset = 0,
    int limit = 20,
    bool fullContent = false,
    String? layer,
  }) async {
    if (fullContent && limit != 1) throw ArgumentError('读取完整记忆正文时每页只能读取1条');
    final saved = await commandResult(
      selectionId,
      'memory_selection',
      sessionId,
      {
        'goalId': goalId,
        'search': search,
        'offset': offset,
        'limit': limit,
        'fullContent': fullContent,
        'layer': layer,
      },
      () async {
        final page = await queryMemory(
          goalId: goalId,
          search: search,
          offset: offset,
          limit: limit,
          includeSourceText: false,
          layer: layer,
        );
        final entries = page['items'] as List<Map<String, Object?>>;
        return {
          ...page,
          'selectionId': selectionId,
          'asOf': clock().toUtc().toIso8601String(),
          'items': [
            for (var i = 0; i < entries.length; i++)
              {
                ...entries[i],
                'itemId': '${i + 1}',
                '_version': _version(entries[i]),
              },
          ],
        };
      },
    );
    return {
      ...saved,
      'items': [
        for (final raw in saved['items'] as List)
          _selectionItem(Map<String, dynamic>.from(raw as Map), fullContent),
      ],
    };
  }

  Future<Map<String, Object?>> _inspectSelection(
    String sessionId,
    String selectionId,
    List<String> itemIds,
  ) async {
    if (itemIds.isEmpty || itemIds.length > 100) {
      throw ArgumentError('请选择 1 至 100 条记忆');
    }
    final receipt = await (db.select(
      db.operationReceipts,
    )..where((t) => t.id.equals(selectionId))).getSingleOrNull();
    if (receipt == null ||
        receipt.kind != 'memory_selection' ||
        receipt.entityId != sessionId) {
      throw ArgumentError('选择清单不存在或不属于当前会话');
    }
    final selection = jsonDecode(receipt.resultJson) as Map<String, dynamic>;
    final available = {
      for (final item in selection['items'] as List)
        (item as Map<String, dynamic>)['itemId'] as String: item,
    };
    final requested = itemIds.toSet();
    final issues = <Map<String, Object?>>[];
    final selected = <Map<String, Object?>>[];
    if (requested.length != itemIds.length) {
      issues.add({'code': 'duplicate_item'});
    }
    for (final itemId in requested) {
      final item = available[itemId];
      if (item == null) {
        issues.add({'code': 'not_in_selection', 'itemId': itemId});
      } else {
        selected.add(_selectionItem(item, false));
      }
    }
    if (selected.isNotEmpty) {
      final ids = selected.map((item) => item['id'] as String).toList();
      final actual = await rows(
        'SELECT * FROM memory_items WHERE id IN (${List.filled(ids.length, '?').join(',')})',
        ids,
      );
      final byId = {for (final item in actual) item['id']: item};
      for (final item in selected) {
        final current = byId[item['id']];
        final original = available[item['itemId']]!['_version'];
        if (current == null ||
            jsonEncode(_version(current)) != jsonEncode(original)) {
          issues.add({
            'code': 'changed',
            'itemId': item['itemId'],
            'id': item['id'],
          });
        }
      }
    }
    final changed = issues.where((issue) => issue['code'] == 'changed').length;
    return {
      'status': issues.isEmpty ? 'ready' : 'blocked',
      'counts': {
        'requested': itemIds.length,
        'matched': selected.length,
        'changed': changed,
        'rejected': issues.isEmpty ? 0 : itemIds.length,
      },
      'items': selected,
      if (issues.isNotEmpty) 'issues': issues,
    };
  }

  @override
  Future<Map<String, Object?>> previewForget({
    required String sessionId,
    required String selectionId,
    required List<String> itemIds,
  }) =>
      db.transaction(() => _inspectSelection(sessionId, selectionId, itemIds));

  @override
  Future<Map<String, Object?>> forgetSelection({
    required String sessionId,
    required String sourceMessageId,
    required String selectionId,
    required List<String> itemIds,
    required String operationId,
  }) async {
    final result = await commandResult(
      operationId,
      'memory_forget_batch',
      sessionId,
      {
        'selectionId': selectionId,
        'itemIds': itemIds,
        'sourceMessageId': sourceMessageId,
      },
      () async {
        final source = await rows(
          "SELECT data FROM assistant_session_records WHERE session_id=? AND type='message_added' AND json_extract(data, '\$.message.id')=? AND json_extract(data, '\$.message.role')='user'",
          [sessionId, sourceMessageId],
        );
        if (source.length != 1) {
          throw ArgumentError('找不到当前会话的用户消息来源');
        }
        final message =
            (jsonDecode(source.single['data'] as String) as Map)['message']
                as Map;
        final text = (message['content'] as List)
            .whereType<Map<String, dynamic>>()
            .where((block) => block['type'] == 'text')
            .map((block) => block['text'])
            .join();
        if (text.trim().isEmpty) {
          throw ArgumentError('用户消息来源没有文字');
        }
        final checked = await _inspectSelection(
          sessionId,
          selectionId,
          itemIds,
        );
        if (checked['status'] != 'ready') {
          return {
            ...checked,
            'operationId': operationId,
            'resultId': operationId,
          };
        }
        final selected = (checked['items'] as List)
            .cast<Map<String, Object?>>();
        final ids = selected.map((item) => item['id'] as String).toList();
        await _forgetItems(
          ids,
          reason: 'user_requested_batch',
          actor: 'user',
          operationId: operationId,
        );
        return {
          'status': 'success',
          'operationId': operationId,
          'resultId': operationId,
          'sourceMessageId': sourceMessageId,
          'asOf': clock().toUtc().toIso8601String(),
          'counts': {'requested': itemIds.length, 'changed': ids.length},
          'items': [
            for (final item in selected)
              {'itemId': item['itemId'], 'id': item['id']},
          ],
        };
      },
    );
    return _operationPage(result, 0);
  }

  Map<String, Object?> _operationPage(Map<String, Object?> result, int offset) {
    final items = result['items'];
    if (items is! List) return result;
    final page = items.skip(offset).take(20).toList();
    final next = offset + page.length;
    return {
      ...result,
      'items': page,
      'page': {
        'offset': offset,
        'complete': next >= items.length,
        if (next < items.length) 'nextOffset': next,
      },
    };
  }

  @override
  Future<Map<String, Object?>> memoryOperation({
    required String sessionId,
    required String operationId,
    int offset = 0,
  }) async {
    if (offset < 0) throw ArgumentError('分页位置无效');
    final receipt = await (db.select(
      db.operationReceipts,
    )..where((t) => t.id.equals(operationId))).getSingleOrNull();
    if (receipt == null ||
        receipt.kind != 'memory_forget_batch' ||
        receipt.entityId != sessionId) {
      throw ArgumentError('没有找到当前会话的记忆操作回执');
    }
    return _operationPage(
      Map<String, Object?>.from(jsonDecode(receipt.resultJson) as Map),
      offset,
    );
  }

  @override
  Future<Map<String, Object?>> queryMemory({
    String? goalId,
    String? search,
    int offset = 0,
    int limit = 20,
    bool includeSourceText = true,
    bool includeExpired = false,
    String? layer,
    String? certainty,
    int? candidateLimit,
  }) async {
    if (offset < 0 || limit < 1 || limit > 300) {
      throw ArgumentError('记忆分页范围无效');
    }
    final nowMs = clock().millisecondsSinceEpoch;
    final keyword = search?.trim() ?? '';
    final aliasPattern = '%${_escapeLike(keyword)}%';
    final sqlArgs = <Object>[];
    final where = <String>['mi.forgotten=0'];
    if (!includeExpired) {
      where.add('(mi.expires_at IS NULL OR mi.expires_at>?)');
      sqlArgs.add(nowMs);
    }
    if (goalId != null) {
      where.add('(mi.goal_id IS NULL OR mi.goal_id=?)');
      sqlArgs.add(goalId);
    }
    if (layer != null) {
      where.add('mi.layer=?');
      sqlArgs.add(layer);
    }
    if (certainty != null) {
      where.add('mi.certainty=?');
      sqlArgs.add(certainty);
    }
    if (keyword.isNotEmpty) {
      final clauses = <String>[];
      for (final unit in _searchUnits(keyword)) {
        clauses.add(
          "mi.content LIKE ${_literal('%${_escapeLike(unit)}%')} ESCAPE '\\'",
        );
      }
      clauses.addAll([
        'mi.id=${_literal(keyword)}',
        'mi.topic_id IN (SELECT st.id FROM memory_topics st '
            "WHERE st.canonical_name LIKE ${_literal(aliasPattern)} ESCAPE '\\')",
      ]);
      clauses.add(
        'mi.topic_id IN (SELECT a.topic_id FROM memory_topic_aliases a '
        "WHERE a.normalized_alias LIKE ${_literal(aliasPattern)} ESCAPE '\\')",
      );
      where.add('(${clauses.join(' OR ')})');
    }
    final clause = where.join(' AND ');
    final boundedCandidateLimit = candidateLimit?.clamp(1, 300);
    // 多取一条边界候选，用于证明缓存期间衰减不会把界外条目推入前列。
    final candidateSql = boundedCandidateLimit == null
        ? ''
        : ' LIMIT ${boundedCandidateLimit + 1}';
    final relevanceSql = _relevanceSql(keyword);
    final scoreSql = _scoreSql(goalId: goalId, keyword: keyword, nowMs: nowMs);
    // 先按完整分数截断，再装配别名与目标标题；只把有界候选传入 Dart。
    final candidateSqlQuery =
        'SELECT ranked.* FROM ('
        'SELECT mi.*, t.canonical_name AS topic_name, t.kind AS topic_kind, '
        '(SELECT title FROM goals WHERE goals.id=mi.goal_id) AS goalTitle, '
        "(SELECT group_concat(a.alias, '，') FROM memory_topic_aliases a "
        'WHERE a.topic_id=mi.topic_id) AS topic_aliases, '
        'COALESCE(u.recall_count, 0) AS recall_count, '
        'COALESCE(u.inject_count, 0) AS inject_count, 0 AS alias_hit, '
        '$relevanceSql AS _relevance '
        'FROM (SELECT mi.id FROM memory_items mi '
        'LEFT JOIN memory_usage u ON u.item_id=mi.id '
        'WHERE $clause ORDER BY ($scoreSql) DESC, '
        'mi.user_edited DESC, mi.updated_at DESC, mi.id ASC$candidateSql) candidates '
        'JOIN memory_items mi ON mi.id=candidates.id '
        'LEFT JOIN memory_topics t ON t.id=mi.topic_id '
        'LEFT JOIN memory_usage u ON u.item_id=mi.id) ranked';
    final cacheKey = jsonEncode([
      goalId,
      keyword,
      includeExpired,
      layer,
      certainty,
      boundedCandidateLimit,
    ]);
    // Drift 暂无公开的事务状态查询；只用当前连接身份禁用事务内缓存，
    // 防止回滚快照进入跨事务缓存，不直接调用内部 executor。
    final canCache = boundedCandidateLimit != null && _outsideTransaction;

    final stamp = canCache ? await _databaseStamp() : null;
    final cached = canCache ? _candidateCache[cacheKey] : null;
    final reusable =
        cached != null &&
        cached.stamp == stamp &&
        _canReuseCandidates(
          cached,
          nowMs,
          boundedCandidateLimit!,
          goalId,
          keyword,
        );
    final matched = reusable
        ? cached.items.map((item) => Map<String, Object?>.from(item)).toList()
        : await rows(candidateSqlQuery, List<Object>.from(sqlArgs));
    final scores = {
      for (final row in matched)
        row['id'] as String: _scoreRow(
          row,
          goalId: goalId,
          keyword: keyword.isEmpty ? null : keyword,
          nowMs: nowMs,
        ),
    };
    matched.sort((a, b) {
      final byScore = scores[b['id']]!.compareTo(scores[a['id']]!);
      if (byScore != 0) return byScore;
      final byEdited = (b['user_edited'] as int).compareTo(
        a['user_edited'] as int,
      );
      if (byEdited != 0) return byEdited;
      final byUpdated = (b['updated_at'] as int).compareTo(
        a['updated_at'] as int,
      );
      if (byUpdated != 0) return byUpdated;
      return (a['id'] as String).compareTo(b['id'] as String);
    });
    if (canCache && !reusable && stamp == await _databaseStamp()) {
      // 有界 LRU，避免搜索词无限累积；调用方拿到的 Map 与缓存始终隔离。
      _candidateCache.remove(cacheKey);
      if (_candidateCache.length >= 16) {
        _candidateCache.remove(_candidateCache.keys.first);
      }
      _candidateCache[cacheKey] = _MemoryCandidates(
        stamp: stamp!,
        nowMs: nowMs,
        items: matched.map((item) => Map<String, Object?>.from(item)).toList(),
      );
    }
    final candidates = boundedCandidateLimit == null
        ? matched
        : matched.take(boundedCandidateLimit).toList();
    final result = DriftRepositorySupport.page(
      candidates.skip(offset).take(limit).toList(),
      candidates.length,
      offset,
    );
    for (final entry
        in includeSourceText
            ? result['items'] as List<Map<String, Object?>>
            : const <Map<String, Object?>>[]) {
      final parts = (entry['source_ref'] as String? ?? '').split(':');
      if (parts.length != 3 ||
          parts.first != 'conversation' ||
          int.tryParse(parts.last) == null) {
        continue;
      }
      final source = await rows(
        'SELECT data FROM assistant_session_records WHERE session_id=? AND sequence=?',
        [parts[1], int.parse(parts.last)],
      );
      if (source.isEmpty) continue;
      final message =
          (jsonDecode(source.single['data'] as String)
              as Map<String, dynamic>)['message'];
      if (message is Map<String, dynamic> && message['role'] == 'user') {
        final text = (message['content'] as List<dynamic>)
            .whereType<Map<String, dynamic>>()
            .where((b) => b['type'] == 'text')
            .map((b) => b['text'])
            .join()
            .split('MissionBook 文本附件')
            .first;
        entry['sourceText'] = String.fromCharCodes(text.runes.take(300));
      }
    }
    final jobs = await rows(
      "SELECT target_id,status,error FROM analysis_jobs WHERE scope='memory' AND status IN ('failed','blocked','manual_failed','manual_blocked') ORDER BY available_at LIMIT 20",
    );
    final pending = (await rows(
      "SELECT COUNT(*) n FROM analysis_jobs WHERE scope='memory' AND status IN ('pending','running','manual_pending','manual_running')",
    )).single['n'];
    result['extraction'] = {'pending': pending, 'retriable': jobs};
    return result;
  }

  // ignore: invalid_use_of_internal_member
  bool get _outsideTransaction => identical(db.resolvedEngine, db);

  Future<String> _databaseStamp() async {
    final stamp = (await rows(
      'SELECT total_changes() AS changes, data_version AS version '
      'FROM pragma_data_version',
    )).single;
    return '${stamp['changes']}:${stamp['version']}';
  }

  bool _canReuseCandidates(
    _MemoryCandidates cached,
    int nowMs,
    int limit,
    String? goalId,
    String keyword,
  ) {
    if (nowMs < cached.nowMs) return false;
    // 界外条目可能正好到期，故跨过任何已知期限都会重新读取。
    for (final item in cached.items) {
      final expires = item['expires_at'] as int?;
      if (expires != null && expires > cached.nowMs && expires <= nowMs) {
        return false;
      }
    }
    if (cached.items.length <= limit || nowMs == cached.nowMs) return true;
    double score(Map<String, Object?> item) => _scoreRow(
      item,
      goalId: goalId,
      keyword: keyword.isEmpty ? null : keyword,
      nowMs: cached.nowMs,
    );
    final gap = score(cached.items[limit - 1]) - score(cached.items[limit]);
    // freshness 的变化率最多为 2*ln(2)/(90天)，其余评分项不随时间变化。
    // 界外条目到期只会扣分；缓存条目到期已在上面拒绝。
    final maxDrift =
        2 *
        math.log(2) *
        (nowMs - cached.nowMs) /
        (90 * Duration.millisecondsPerDay);
    return gap > maxDrift + 1e-12;
  }

  static String _relevanceSql(String keyword) => keyword.isEmpty
      ? '0.5'
      : () {
          final key = _literal(keyword.toLowerCase());
          final aliasHit =
              'mi.topic_id IN (SELECT sa.topic_id FROM memory_topic_aliases sa WHERE instr(lower(sa.alias), $key)>0)';
          final unitTerms = _searchUnits(keyword)
              .map(
                (unit) =>
                    "CASE WHEN instr(lower(mi.content), ${_literal(unit.toLowerCase())})>0 THEN 1 ELSE 0 END",
              )
              .join(' + ');
          final unitCount = _searchUnits(keyword).length;
          final partial = unitCount == 0
              ? '0'
              : 'CASE WHEN ($unitTerms)=0 THEN 0 ELSE '
                    '(0.25 + 0.5 * (($unitTerms) / $unitCount.0)) END';
          return 'CASE WHEN instr(lower(mi.content), $key)>0 THEN 1.0 '
              'WHEN $aliasHit OR mi.topic_id IN '
              '(SELECT st.id FROM memory_topics st WHERE instr(lower(st.canonical_name), $key)>0) THEN 0.95 '
              'ELSE $partial END';
        }();

  String _scoreSql({
    required String? goalId,
    required String keyword,
    required int nowMs,
  }) {
    final relevance = _relevanceSql(keyword);
    final certainty =
        "CASE WHEN mi.user_edited=1 THEN 1.0 WHEN mi.certainty='stated' THEN 0.8 "
        "WHEN mi.certainty='inferred' THEN 0.5 ELSE 0.25 END";
    final layer =
        "CASE mi.layer WHEN 'identity' THEN 1.0 WHEN 'semantic' THEN 0.8 "
        "WHEN 'procedural' THEN 0.7 WHEN 'episodic' THEN 0.5 "
        'WHEN \'observation\' THEN 0.2 ELSE 0.5 END';
    final affinity = goalId == null
        ? '0.5'
        : 'CASE WHEN mi.goal_id=${_literal(goalId)} THEN 1.0 ELSE 0.6 END';
    final freshness =
        'pow(0.5, max(0, $nowMs-mi.updated_at)/${Duration.millisecondsPerDay}.0/90.0)';
    final usage =
        'log2(1 + coalesce(u.recall_count, 0) + coalesce(u.inject_count, 0) * 2)';
    final expired =
        "CASE WHEN mi.expires_at IS NOT NULL AND mi.expires_at <= $nowMs THEN 3 ELSE 0 END";
    return '$relevance * 4 + $certainty * 2 + $layer + '
        'mi.importance / 100.0 * 0.5 + $affinity * 0.8 + '
        '$freshness * 2 + $usage * 0.25 - $expired';
  }

  static String _literal(String value) => "'${value.replaceAll("'", "''")}'";

  static String _escapeLike(String value) => value
      .replaceAll('\\', '\\\\')
      .replaceAll('%', '\\%')
      .replaceAll('_', '\\_');

  static List<String> _searchUnits(String keyword) {
    final text = keyword.toLowerCase();
    final units = <String>[];
    for (final part in text.split(RegExp(r'[\s,，。;；:：!！?？、]+'))) {
      if (part.isEmpty) continue;
      final runes = part.runes.toList();
      final cjk = runes.any((rune) => rune >= 0x3400 && rune <= 0x9fff);
      if (!cjk || runes.length <= 2) {
        units.add(part);
        continue;
      }
      for (var index = 0; index + 1 < runes.length; index++) {
        units.add(String.fromCharCodes(runes.sublist(index, index + 2)));
      }
    }
    return units.take(12).toList();
  }

  static double _relevance(Map<String, Object?> row, String? keyword) {
    if (keyword == null || keyword.isEmpty) return 0.5;
    final text = (row['content'] as String).toLowerCase();
    if (text.contains(keyword.toLowerCase())) return 1;
    final aliases = (row['topic_aliases'] as String? ?? '')
        .split('，')
        .where((alias) => alias.isNotEmpty)
        .toList();
    if (aliases.any(
          (alias) => alias.toLowerCase().contains(keyword.toLowerCase()),
        ) ||
        (row['topic_name'] as String? ?? '').toLowerCase().contains(
          keyword.toLowerCase(),
        )) {
      return 0.95;
    }
    final units = _searchUnits(keyword);
    if (units.isEmpty) return 0;
    final matched = units.where(text.contains).length;
    if (matched == 0) return 0;
    return 0.25 + 0.5 * matched / units.length;
  }

  static double _scoreRow(
    Map<String, Object?> row, {
    required String? goalId,
    required String? keyword,
    required int nowMs,
  }) {
    // SQLite lower 的 Unicode 规则与 Dart 不同，复用 SQL 实际相关度，
    // 保证候选截断与最终排名对非 ASCII 文本也使用同一分数。
    final relevance =
        (row['_relevance'] as num?)?.toDouble() ?? _relevance(row, keyword);
    final certainty = row['user_edited'] == 1
        ? 1.0
        : row['certainty'] == 'stated'
        ? 0.8
        : row['certainty'] == 'inferred'
        ? 0.5
        : 0.25;
    final layer = _layerWeight[row['layer']] ?? 0.5;
    final importance = (row['importance'] as int) / 100;
    final affinity = goalId == null
        ? 0.5
        : row['goal_id'] == goalId
        ? 1.0
        : 0.6;
    final ageMs = math.max(0, nowMs - (row['updated_at'] as int));
    final ageDays = ageMs / Duration.millisecondsPerDay;
    final freshness = math.pow(0.5, ageDays / 90).toDouble();
    final recallCount = (row['recall_count'] as int?) ?? 0;
    final injectCount = (row['inject_count'] as int?) ?? 0;
    final usageSignal =
        math.log(1 + recallCount + injectCount * 2) / math.log(2);
    final expiresAt = row['expires_at'] as int?;
    final expired = expiresAt != null && expiresAt <= nowMs;
    return relevance * 4 +
        certainty * 2 +
        layer +
        importance * 0.5 +
        affinity * 0.8 +
        freshness * 2 +
        usageSignal * 0.25 -
        (expired ? 3 : 0);
  }

  @override
  Future<Map<String, Object?>> saveMemory(
    Map<String, Object?> entry, {
    bool userEdited = false,
    bool explicitCorrection = false,
    String? operationId,
  }) => commandResult(
    operationId,
    'memory_save',
    entry['id'] as String,
    {
      ...entry,
      'userEdited': userEdited,
      'explicitCorrection': explicitCorrection,
    },
    () => _save(
      entry,
      userEdited: userEdited,
      explicitCorrection: explicitCorrection,
      operationId: operationId,
    ),
    true,
  );

  Future<Map<String, Object?>> _save(
    Map<String, Object?> entry, {
    required bool userEdited,
    required bool explicitCorrection,
    required String? operationId,
  }) async {
    // 强制遍历类型转换，避免 CastList 在主条目落库后才暴露结构错误。
    _validateDerived(entry);
    final saved = await _saveItem(
      entry,
      userEdited: userEdited,
      explicitCorrection: explicitCorrection,
      operationId: operationId,
    );
    if (saved['status'] != 'blocked' && saved['id'] == entry['id']) {
      await _syncDerived(entry);
    } else if (saved['status'] == 'unchanged') {
      // 去重命中其他条目时仅修复该条目的派生结构，不能带入被拒绝的新元数据。
      final existing = (await rows('SELECT * FROM memory_items WHERE id=?', [
        saved['id'],
      ])).single;
      await _syncDerived({
        'id': existing['id'],
        'layer': existing['layer'],
        'sourceRef': existing['source_ref'],
      });
    }
    return saved;
  }

  static void _validateDerived(Map<String, Object?> entry) {
    for (final key in ['sourceRefs', 'steps']) {
      if (entry.containsKey(key)) {
        final value = entry[key];
        if (value is! List || value.any((element) => element is! String)) {
          throw ArgumentError('invalid_shape');
        }
      }
    }
    if (entry['trigger'] != null && entry['trigger'] is! String) {
      throw ArgumentError('invalid_shape');
    }
  }

  Future<void> _syncDerived(Map<String, Object?> entry) async {
    final id = entry['id'] as String;
    final layer = entry['layer'];
    List<String>? refs = (entry['sourceRefs'] as List?)
        ?.cast<String>()
        .toList();
    if (refs == null && entry.containsKey('sourceRef')) {
      refs =
          (entry['sourceRef'] as String?)
              ?.split('|')
              .where((ref) => ref.isNotEmpty)
              .toList() ??
          const [];
    }
    if (layer != 'episodic') {
      await (db.delete(
        db.memoryEpisodes,
      )..where((t) => t.itemId.equals(id))).go();
    }
    if (layer != 'procedural') {
      await (db.delete(
        db.memoryProcedures,
      )..where((t) => t.itemId.equals(id))).go();
    }
    if (layer == 'episodic') {
      final previous = await (db.select(
        db.memoryEpisodes,
      )..where((t) => t.itemId.equals(id))).getSingleOrNull();
      await db
          .into(db.memoryEpisodes)
          .insertOnConflictUpdate(
            MemoryEpisodesCompanion.insert(
              itemId: id,
              sourceRefsJson: refs == null
                  ? previous?.sourceRefsJson ?? '[]'
                  : jsonEncode(refs),
            ),
          );
    } else if (layer == 'procedural') {
      final previous = await (db.select(
        db.memoryProcedures,
      )..where((t) => t.itemId.equals(id))).getSingleOrNull();
      await db
          .into(db.memoryProcedures)
          .insertOnConflictUpdate(
            MemoryProceduresCompanion.insert(
              itemId: id,
              stepsJson: entry.containsKey('steps')
                  ? jsonEncode(entry['steps'])
                  : previous?.stepsJson ?? '[]',
              triggerContext: Value(
                entry.containsKey('trigger')
                    ? entry['trigger'] as String?
                    : previous?.triggerContext,
              ),
              sourceRefsJson: refs == null
                  ? previous?.sourceRefsJson ?? '[]'
                  : jsonEncode(refs),
            ),
          );
    }
  }

  Future<Map<String, Object?>> _saveItem(
    Map<String, Object?> entry, {
    required bool userEdited,
    required bool explicitCorrection,
    required String? operationId,
  }) async {
    final id = entry['id'] as String;
    final content = (entry['content'] as String).trim();
    final layer = entry['layer'] as String?;
    final certainty = entry['certainty'] as String? ?? 'unverified';
    final sourceKind = entry['sourceKind'] as String? ?? 'assistant';
    final sourceRef = entry['sourceRef'] as String?;
    final goal = entry['goalId'] as String?;
    final importance = entry['importance'] as int? ?? 50;
    final expiresAt = entry['expiresAt'];
    final requestedTopic = (entry['topic'] as String? ?? '').trim();
    // 空主题由正文承载，避免把无效主题写入 canonical_name 的 CHECK 约束。
    final topicName = requestedTopic.isEmpty ? content : requestedTopic;
    final aliases = (entry['aliases'] as List?)?.cast<String>() ?? const [];
    if (content.isEmpty ||
        content.length > 1000 ||
        ![
          'identity',
          'semantic',
          'episodic',
          'procedural',
          'observation',
        ].contains(layer)) {
      throw ArgumentError('记忆内容、层级或正文长度无效');
    }
    if (!['stated', 'inferred', 'unverified'].contains(certainty)) {
      throw ArgumentError('记忆确认状态无效');
    }
    if (![
      'user',
      'assistant',
      'extraction',
      'manual',
      'reflection',
    ].contains(sourceKind)) {
      throw ArgumentError('记忆来源无效');
    }
    if (layer == 'observation' && certainty != 'unverified') {
      throw ArgumentError('观察记忆必须以未验证状态保存');
    }
    if (explicitCorrection && certainty != 'stated') {
      throw ArgumentError('只有明确陈述可以更正原条目');
    }
    if (expiresAt != null && expiresAt is! int) {
      throw ArgumentError('记忆期限格式无效');
    }
    if (importance < 1 || importance > 100) {
      throw ArgumentError('记忆重要度必须在 1 到 100 之间');
    }
    final expiresAtMs = expiresAt as int?;
    final now = clock().millisecondsSinceEpoch;
    if (expiresAtMs != null && expiresAtMs <= now) {
      throw ArgumentError('记忆期限必须晚于当前时刻');
    }
    final credential = RegExp(
      r'(?:tvly-[A-Za-z0-9_-]{12,}|sk-[A-Za-z0-9_-]{16,}|(?:api.?key|token|密码|密钥)\s*[:：=]\s*\S{8,})',
      caseSensitive: false,
    );
    if ([
      content,
      topicName,
      ...aliases,
      sourceRef ?? '',
    ].any((value) => credential.hasMatch(value))) {
      throw ArgumentError('凭据请保存到安全设置，不放入助手记忆');
    }

    final existingRows = await rows(
      'SELECT mi.*, t.canonical_name AS topic_name FROM memory_items mi '
      'LEFT JOIN memory_topics t ON t.id=mi.topic_id WHERE mi.id=?',
      [id],
    );
    final existing = existingRows.firstOrNull;
    final expectedVersion = entry['expectedVersion'];
    if (expectedVersion != null) {
      if (existing == null ||
          jsonEncode(_version(existing)) != jsonEncode(expectedVersion)) {
        return {'status': 'blocked', 'id': id, 'reason': 'changed'};
      }
    }
    if (existing != null && existing['forgotten'] == 1) {
      return {'status': 'blocked', 'id': id, 'reason': 'forgotten_memory'};
    }
    final normalized = _normalize(content);
    if (existing == null) {
      final forgotten = await rows(
        'SELECT id,content FROM memory_items WHERE forgotten=1 AND goal_id IS ?',
        [goal],
      );
      final tombstone = forgotten
          .where((row) => _normalize(row['content'] as String) == normalized)
          .firstOrNull;
      if (tombstone != null) {
        return {
          'status': 'blocked',
          'id': tombstone['id'],
          'reason': 'protected_memory',
        };
      }
    }
    final topicId = await _resolveTopic(
      name: topicName,
      kind: _topicKind(layer!),
      goalId: goal,
      aliases: aliases,
    );

    if (userEdited || explicitCorrection) {
      final actor = explicitCorrection ? 'assistant' : 'user';
      if (existing == null) {
        await _insert(
          id: id,
          layer: layer,
          topicId: topicId,
          content: content,
          certainty: certainty,
          importance: importance,
          expiresAtMs: expiresAtMs,
          goal: goal,
          sourceKind: sourceKind,
          sourceRef: sourceRef,
          userEdited: !explicitCorrection && userEdited,
          now: now,
          reason: explicitCorrection ? 'explicit_correction' : 'manual_add',
          actor: actor,
          operationId: operationId,
        );
        return {
          'status': 'created',
          'id': id,
          'reason': 'manual',
          'topicId': topicId,
        };
      }
      if (existing['forgotten'] == 0 &&
          _normalize(existing['content'] as String) == normalized &&
          existing['layer'] == layer &&
          existing['certainty'] == certainty &&
          existing['expires_at'] == expiresAtMs &&
          existing['topic_id'] == topicId &&
          existing['goal_id'] == goal &&
          existing['importance'] == importance) {
        return {'status': 'unchanged', 'id': id, 'reason': 'identical'};
      }
      await _update(
        existing: existing,
        content: content,
        layer: layer,
        topicId: topicId,
        certainty: certainty,
        importance: importance,
        expiresAtMs: expiresAtMs,
        goal: goal,
        sourceKind: sourceKind,
        sourceRef: sourceRef,
        now: now,
        reason: explicitCorrection ? 'explicit_correction' : 'user_edit',
        actor: actor,
        userEdited:
            existing['user_edited'] == 1 || (!explicitCorrection && userEdited),
        operationId: operationId,
      );
      return {
        'status': 'updated',
        'id': id,
        'reason': explicitCorrection ? 'explicit_correction' : 'user_edit',
        'previousContent': _summary(existing['content'] as String),
      };
    }

    if (existing != null) {
      return {'status': 'blocked', 'id': id, 'reason': 'existing_id'};
    }
    final live = await rows(
      'SELECT * FROM memory_items WHERE forgotten=0 AND goal_id IS ? '
      'AND (topic_id=? OR lower(trim(content))=?)',
      [goal, topicId, normalized.toLowerCase()],
    );
    final manual = live.where((row) => row['user_edited'] == 1).firstOrNull;
    if (manual != null) {
      return {
        'status': 'unchanged',
        'id': manual['id'],
        'reason': 'manual_protected',
      };
    }
    final sameContent = live
        .where(
          (row) =>
              _normalize(row['content'] as String) == normalized &&
              row['layer'] == layer,
        )
        .firstOrNull;
    if (sameContent != null) {
      return {
        'status': 'unchanged',
        'id': sameContent['id'],
        'reason': 'identical',
      };
    }
    final conflict = live.firstOrNull;
    await _insert(
      id: id,
      layer: layer,
      topicId: topicId,
      content: content,
      certainty: conflict == null ? certainty : 'unverified',
      importance: importance,
      expiresAtMs: expiresAtMs,
      goal: goal,
      sourceKind: sourceKind,
      sourceRef: sourceRef,
      userEdited: false,
      now: now,
      reason: conflict == null ? 'added' : 'topic_conflict_kept',
      actor: sourceKind,
      operationId: operationId,
    );
    if (conflict == null) {
      return {
        'status': 'created',
        'id': id,
        'reason': 'added',
        'topicId': topicId,
      };
    }
    return {
      'status': 'created',
      'id': id,
      'reason': 'topic_conflict_kept',
      'keptId': conflict['id'],
      'topicId': topicId,
    };
  }

  Future<String> _resolveTopic({
    required String name,
    required String kind,
    required String? goalId,
    required List<String> aliases,
  }) async {
    final normalized = _normalize(name).toLowerCase();
    final topics = await rows(
      'SELECT * FROM memory_topics WHERE goal_id IS ?',
      [goalId],
    );
    String? topicId;
    for (final topic in topics) {
      if (_normalize(topic['canonical_name'] as String).toLowerCase() ==
          normalized) {
        topicId = topic['id'] as String;
        break;
      }
    }
    if (topicId == null && topics.isNotEmpty) {
      final hit = await rows(
        'SELECT topic_id FROM memory_topic_aliases WHERE normalized_alias=? '
        'AND topic_id IN (${List.filled(topics.length, '?').join(',')}) LIMIT 1',
        [normalized, for (final topic in topics) topic['id']],
      );
      if (hit.isNotEmpty) topicId = hit.single['topic_id'] as String;
    }
    if (topicId == null) {
      topicId = const Uuid().v5(
        Namespace.url.value,
        'memory-topic:${goalId ?? ''}:$normalized',
      );
      await db
          .into(db.memoryTopics)
          .insertOnConflictUpdate(
            MemoryTopicsCompanion.insert(
              id: topicId,
              canonicalName: _normalize(name),
              kind: kind,
              goalId: Value(goalId),
              createdAt: clock().millisecondsSinceEpoch,
            ),
          );
    }
    final names = {
      _normalize(name),
      for (final alias in aliases) _normalize(alias),
    };
    for (final alias in names) {
      if (alias.isEmpty) continue;
      await db
          .into(db.memoryTopicAliases)
          .insertOnConflictUpdate(
            MemoryTopicAliasesCompanion.insert(
              topicId: topicId,
              alias: alias,
              normalizedAlias: alias.toLowerCase(),
            ),
          );
    }
    return topicId;
  }

  static String _topicKind(String layer) => switch (layer) {
    'identity' => 'identity',
    'observation' => 'observation',
    _ => 'fact',
  };

  Future<void> _insert({
    required String id,
    required String layer,
    required String topicId,
    required String content,
    required String certainty,
    required int importance,
    required int? expiresAtMs,
    required String? goal,
    required String sourceKind,
    required String? sourceRef,
    required bool userEdited,
    required int now,
    required String reason,
    required String actor,
    required String? operationId,
  }) async {
    await db
        .into(db.memoryItems)
        .insert(
          MemoryItemsCompanion.insert(
            id: id,
            layer: layer,
            topicId: Value(topicId),
            content: content,
            certainty: certainty,
            importance: Value(importance),
            createdAt: now,
            updatedAt: now,
            expiresAt: Value(expiresAtMs),
            sourceKind: sourceKind,
            sourceRef: Value(sourceRef),
            goalId: Value(goal),
            userEdited: Value(userEdited),
          ),
        );
    await _recordVersion(
      itemId: id,
      changeKind: 'add',
      before: null,
      after: (await rows('SELECT * FROM memory_items WHERE id=?', [id])).single,
      reason: reason,
      actor: actor,
      operationId: operationId,
      now: now,
    );
  }

  Future<void> _update({
    required Map<String, Object?> existing,
    required bool userEdited,
    required String content,
    required String layer,
    required String topicId,
    required String certainty,
    required int importance,
    required int? expiresAtMs,
    required String? goal,
    required String sourceKind,
    required String? sourceRef,
    required int now,
    required String reason,
    required String actor,
    required String? operationId,
  }) async {
    await (db.update(
      db.memoryItems,
    )..where((t) => t.id.equals(existing['id'] as String))).write(
      MemoryItemsCompanion(
        layer: Value(layer),
        topicId: Value(topicId),
        content: Value(content),
        certainty: Value(certainty),
        importance: Value(importance),
        updatedAt: Value(now),
        expiresAt: Value(expiresAtMs),
        goalId: Value(goal),
        sourceKind: Value(sourceKind),
        sourceRef: Value(sourceRef),
        userEdited: Value(userEdited),
      ),
    );
    await _recordVersion(
      itemId: existing['id'] as String,
      changeKind: 'update',
      before: _version(existing),
      after: (await rows('SELECT * FROM memory_items WHERE id=?', [
        existing['id'],
      ])).single,
      reason: reason,
      actor: actor,
      operationId: operationId,
      now: now,
    );
  }

  Future<void> _recordVersion({
    required String itemId,
    required String changeKind,
    required Map<String, Object?>? before,
    required Map<String, Object?> after,
    required String reason,
    required String actor,
    required String? operationId,
    required int now,
  }) async {
    await db
        .into(db.memoryVersions)
        .insert(
          MemoryVersionsCompanion.insert(
            id: const Uuid().v4(),
            itemId: itemId,
            changeKind: changeKind,
            beforeJson: Value(before == null ? null : jsonEncode(before)),
            afterJson: jsonEncode(after),
            reason: reason,
            operationId: Value(operationId),
            actor: actor,
            createdAt: now,
          ),
        );
  }

  @override
  Future<void> forgetMemory(String id, {String? operationId}) => command(
    operationId,
    'memory_forget',
    id,
    {'id': id},
    {'forgotten': true},
    () => _forgetItems(
      [id],
      reason: 'user_forgot',
      actor: 'user',
      operationId: operationId,
    ),
  );

  Future<void> _forgetItems(
    List<String> ids, {
    required String reason,
    required String actor,
    required String? operationId,
  }) async {
    final now = clock().millisecondsSinceEpoch;
    for (final id in ids) {
      final before = await rows('SELECT * FROM memory_items WHERE id=?', [id]);
      if (before.isEmpty) continue;
      await (db.update(db.memoryItems)..where((t) => t.id.equals(id))).write(
        MemoryItemsCompanion(
          forgotten: const Value(true),
          userEdited: const Value(true),
          updatedAt: Value(now),
        ),
      );
      await _recordVersion(
        itemId: id,
        changeKind: 'forget',
        before: _version(before.single),
        after: (await rows('SELECT * FROM memory_items WHERE id=?', [
          id,
        ])).single,
        reason: reason,
        actor: actor,
        operationId: operationId,
        now: now,
      );
    }
  }

  @override
  Future<Map<String, Object?>> reflectionInput() async {
    final now = clock().millisecondsSinceEpoch;
    final items = await rows(
      'SELECT mi.id, mi.layer, mi.content, mi.certainty, mi.importance, '
      'mi.updated_at, mi.goal_id, t.canonical_name AS topic '
      'FROM memory_items mi LEFT JOIN memory_topics t ON t.id=mi.topic_id '
      'WHERE mi.forgotten=0 AND (mi.expires_at IS NULL OR mi.expires_at>?) '
      'ORDER BY mi.updated_at DESC LIMIT 200',
      [now],
    );
    return {
      'items': items,
      'topics': await rows(
        'SELECT id,canonical_name,kind,goal_id FROM memory_topics',
      ),
      'aliases': await rows(
        'SELECT topic_id,normalized_alias FROM memory_topic_aliases',
      ),
      'episodes': await rows(
        'SELECT e.item_id,e.source_refs_json FROM memory_episodes e '
        'JOIN memory_items mi ON mi.id=e.item_id '
        "WHERE mi.layer='episodic' AND mi.forgotten=0 "
        'AND (mi.expires_at IS NULL OR mi.expires_at>?)',
        [now],
      ),
      'procedures': await rows(
        'SELECT e.item_id,e.steps_json,e.trigger_context,e.source_refs_json '
        'FROM memory_procedures e JOIN memory_items mi ON mi.id=e.item_id '
        "WHERE mi.layer='procedural' AND mi.forgotten=0 "
        'AND (mi.expires_at IS NULL OR mi.expires_at>?)',
        [now],
      ),
      'goalIds': {
        for (final item in items)
          if (item['goal_id'] != null) item['goal_id'],
      }.toList(),
    };
  }

  @override
  Future<Map<String, Object?>> applyReflection(
    List<Map<String, Object?>> actions, {
    String? operationId,
  }) async {
    final applied = <Map<String, Object?>>[];
    final skipped = <Map<String, Object?>>[];
    await db.transaction(() async {
      for (final action in actions.take(50)) {
        try {
          // 嵌套事务是动作级 savepoint：捕获错误前先回滚该动作的全部写入。
          final result = await db.transaction(() async {
            final written = await _applyReflectionAction(action, operationId);
            if (written == null) throw ArgumentError('not_allowed');
            return written;
          });
          applied.add(result);
        } on ArgumentError catch (error) {
          skipped.add({'action': action['action'], 'reason': error.message});
        } on TypeError {
          // 模型动作字段类型错误时只丢弃该动作，不能回滚同批安全动作。
          skipped.add({'action': action['action'], 'reason': 'invalid_shape'});
        } on SqliteException catch (error) {
          if (error.resultCode != 19) rethrow;
          skipped.add({
            'action': action['action'],
            'reason': 'constraint_failed',
          });
        }
      }
    });
    return {'applied': applied, 'skipped': skipped};
  }

  Future<Map<String, Object?>?> _applyReflectionAction(
    Map<String, Object?> action,
    String? operationId,
  ) async => switch (action['action']) {
    'merge_topics' => _mergeTopics(action, operationId),
    'add_episode' => _addDerived(action, operationId, episodic: true),
    'add_procedure' => _addDerived(action, operationId, episodic: false),
    'adjust_item' => _adjustItem(action, operationId),
    'decay_item' => _decayItem(action, operationId),
    _ => null,
  };

  Future<Map<String, Object?>?> _addDerived(
    Map<String, Object?> action,
    String? operationId, {
    required bool episodic,
  }) async {
    final content = (action['content'] as String? ?? '').trim();
    if (content.isEmpty) return null;
    final id = action['id'] as String? ?? const Uuid().v4();
    final derived = <String, Object?>{
      if (action.containsKey('source_refs'))
        'sourceRefs': action['source_refs'],
      if (action.containsKey('steps')) 'steps': action['steps'],
      if (action.containsKey('trigger')) 'trigger': action['trigger'],
    };
    _validateDerived(derived);
    final refs =
        (derived['sourceRefs'] as List?)?.cast<String>().toList() ??
        const <String>[];
    final topic = (action['topic'] as String? ?? '').trim();
    if (refs.isNotEmpty) {
      final inactive = await rows(
        'SELECT 1 FROM memory_items WHERE id IN '
        '(${List.filled(refs.length, '?').join(',')}) '
        'AND (forgotten=1 OR (expires_at IS NOT NULL AND expires_at<=?)) LIMIT 1',
        [...refs, clock().millisecondsSinceEpoch],
      );
      if (inactive.isNotEmpty) return null;
    }
    final saved = await _save(
      {
        'id': id,
        'content': content,
        'layer': episodic ? 'episodic' : 'procedural',
        'certainty': 'inferred',
        'topic': topic.isEmpty ? content : topic,
        'aliases': action['aliases'] ?? const <String>[],
        'importance': action['importance'] ?? 50,
        'goalId': action['goalId'],
        'sourceKind': 'reflection',
        'sourceRef': refs.isEmpty ? null : refs.join('|'),
        ...derived,
      },
      userEdited: false,
      explicitCorrection: false,
      operationId: operationId,
    );
    if (saved['status'] == 'blocked' || saved['status'] == 'unchanged') {
      return null;
    }
    final itemId = saved['id'] as String;
    return {
      'action': action['action'],
      'id': itemId,
      'status': saved['status'],
    };
  }

  Future<Map<String, Object?>?> _mergeTopics(
    Map<String, Object?> action,
    String? operationId,
  ) async {
    final from = action['from_topic_id'] as String?;
    final into = action['into_topic_id'] as String?;
    if (from == null || into == null || from == into) return null;
    final topics = await rows(
      'SELECT id,goal_id FROM memory_topics WHERE id IN (?,?)',
      [from, into],
    );
    if (topics.length != 2 || topics[0]['goal_id'] != topics[1]['goal_id']) {
      return null;
    }
    final now = clock().millisecondsSinceEpoch;
    final items = await rows(
      'SELECT * FROM memory_items WHERE topic_id=? AND forgotten=0 '
      'AND (expires_at IS NULL OR expires_at>?)',
      [from, now],
    );
    for (final item in items) {
      await (db.update(db.memoryItems)
            ..where((t) => t.id.equals(item['id'] as String)))
          .write(MemoryItemsCompanion(topicId: Value(into)));
      final after = await rows('SELECT * FROM memory_items WHERE id=?', [
        item['id'],
      ]);
      await _recordVersion(
        itemId: item['id'] as String,
        changeKind: 'update',
        before: _version(item),
        after: after.single,
        reason: 'topic_merge',
        actor: 'reflection',
        operationId: operationId,
        now: now,
      );
    }
    final aliases = await rows(
      'SELECT alias,normalized_alias FROM memory_topic_aliases WHERE topic_id=?',
      [from],
    );
    for (final alias in aliases) {
      await db
          .into(db.memoryTopicAliases)
          .insertOnConflictUpdate(
            MemoryTopicAliasesCompanion.insert(
              topicId: into,
              alias: alias['alias'] as String,
              normalizedAlias: alias['normalized_alias'] as String,
            ),
          );
    }
    // 墓碑和到期条目仍引用原主题，保留其主题与别名以免改写历史或触发外键错误。
    final remaining = await rows(
      'SELECT 1 FROM memory_items WHERE topic_id=? LIMIT 1',
      [from],
    );
    if (remaining.isEmpty) {
      await (db.delete(
        db.memoryTopicAliases,
      )..where((t) => t.topicId.equals(from))).go();
      await (db.delete(db.memoryTopics)..where((t) => t.id.equals(from))).go();
    }
    return {
      'action': 'merge_topics',
      'from': from,
      'into': into,
      'moved': items.length,
    };
  }

  Future<Map<String, Object?>?> _adjustItem(
    Map<String, Object?> action,
    String? operationId,
  ) async {
    final id = action['id'] as String?;
    if (id == null) return null;
    final item = (await rows('SELECT * FROM memory_items WHERE id=?', [
      id,
    ])).firstOrNull;
    if (item == null ||
        item['forgotten'] == 1 ||
        item['user_edited'] == 1 ||
        item['certainty'] == 'stated' ||
        (item['expires_at'] != null &&
            (item['expires_at'] as int) <= clock().millisecondsSinceEpoch)) {
      return null;
    }
    final certainty = action['certainty'] as String?;
    if ((item['layer'] == 'observation' &&
            certainty != null &&
            certainty != 'unverified') ||
        (certainty != null &&
            !['inferred', 'unverified'].contains(certainty))) {
      return null;
    }
    final importance = action['importance'] as int?;
    if (importance != null && (importance < 1 || importance > 100)) {
      return null;
    }
    await (db.update(db.memoryItems)..where((t) => t.id.equals(id))).write(
      MemoryItemsCompanion(
        certainty: Value(certainty ?? item['certainty'] as String),
        importance: Value(importance ?? item['importance'] as int),
        updatedAt: Value(clock().millisecondsSinceEpoch),
      ),
    );
    final after = await rows('SELECT * FROM memory_items WHERE id=?', [id]);
    await _recordVersion(
      itemId: id,
      changeKind: 'update',
      before: _version(item),
      after: after.single,
      reason: 'reflection_adjust',
      actor: 'reflection',
      operationId: operationId,
      now: clock().millisecondsSinceEpoch,
    );
    return {'action': 'adjust_item', 'id': id};
  }

  Future<Map<String, Object?>?> _decayItem(
    Map<String, Object?> action,
    String? operationId,
  ) async {
    final id = action['id'] as String?;
    if (id == null) return null;
    final item = (await rows('SELECT * FROM memory_items WHERE id=?', [
      id,
    ])).firstOrNull;
    if (item == null ||
        item['forgotten'] == 1 ||
        item['user_edited'] == 1 ||
        item['certainty'] == 'stated' ||
        (item['importance'] as int) > 30) {
      return null;
    }
    final now = clock().millisecondsSinceEpoch;
    if (now - (item['updated_at'] as int) <
        const Duration(days: 90).inMilliseconds) {
      return null;
    }
    await (db.update(db.memoryItems)..where((t) => t.id.equals(id))).write(
      MemoryItemsCompanion(forgotten: const Value(true), updatedAt: Value(now)),
    );
    final after = await rows('SELECT * FROM memory_items WHERE id=?', [id]);
    await _recordVersion(
      itemId: id,
      changeKind: 'decay',
      before: _version(item),
      after: after.single,
      reason: 'decay',
      actor: 'reflection',
      operationId: operationId,
      now: now,
    );
    return {'action': 'decay_item', 'id': id};
  }

  @override
  Future<void> recordUsage({
    required List<String> ids,
    required bool injected,
  }) async {
    final now = clock().millisecondsSinceEpoch;
    await db.transaction(() async {
      for (final id in ids.toSet()) {
        await db.customStatement(
          'INSERT INTO memory_usage(item_id,recall_count,inject_count,last_used_at) '
          'VALUES(?,?,?,?) ON CONFLICT(item_id) DO UPDATE SET '
          'recall_count=recall_count+excluded.recall_count, '
          'inject_count=inject_count+excluded.inject_count, '
          'last_used_at=excluded.last_used_at',
          [id, injected ? 0 : 1, injected ? 1 : 0, now],
        );
      }
    });
  }

  @override
  Future<List<Map<String, Object?>>> memoryEpisodes({
    String? goalId,
    String? search,
    int limit = 20,
  }) => _derived(
    table: 'memory_episodes',
    columns: 'e.source_refs_json',
    goalId: goalId,
    search: search,
    limit: limit,
  );

  @override
  Future<List<Map<String, Object?>>> memoryProcedures({
    String? goalId,
    String? search,
    int limit = 20,
  }) => _derived(
    table: 'memory_procedures',
    columns: 'e.steps_json, e.trigger_context, e.source_refs_json',
    goalId: goalId,
    search: search,
    limit: limit,
  );

  Future<List<Map<String, Object?>>> _derived({
    required String table,
    required String columns,
    required String? goalId,
    required String? search,
    required int limit,
  }) async {
    final now = clock().millisecondsSinceEpoch;
    final keyword = search?.trim() ?? '';
    final aliasPattern = '%${_escapeLike(keyword)}%';
    final args = <Object>[now];
    final where = <String>[
      'mi.forgotten=0',
      "mi.layer='${table == 'memory_episodes' ? 'episodic' : 'procedural'}'",
      "(mi.expires_at IS NULL OR mi.expires_at>?)",
    ];
    if (goalId != null) {
      where.add('(mi.goal_id IS NULL OR mi.goal_id=?)');
      args.add(goalId);
    }
    if (keyword.isNotEmpty) {
      where.add(
        "(mi.content LIKE ? ESCAPE '\\' OR t.canonical_name LIKE ? ESCAPE '\\' "
        'OR EXISTS(SELECT 1 FROM memory_topic_aliases a '
        "WHERE a.topic_id=mi.topic_id AND a.normalized_alias LIKE ? ESCAPE '\\'))",
      );
      args.addAll([aliasPattern, aliasPattern, aliasPattern]);
    }
    return rows(
      'SELECT mi.*, t.canonical_name AS topic_name, $columns '
      'FROM memory_items mi JOIN $table e ON e.item_id=mi.id '
      'LEFT JOIN memory_topics t ON t.id=mi.topic_id '
      'WHERE ${where.join(' AND ')} '
      'ORDER BY mi.importance DESC, mi.updated_at DESC LIMIT ?',
      [...args, limit],
    );
  }

  static String _normalize(String value) =>
      value.trim().replaceAll(RegExp(r'\s+'), ' ');

  static String _summary(String content) {
    final runes = content.runes.toList();
    return runes.length <= 200
        ? content
        : '${String.fromCharCodes(runes.take(200))}…';
  }
}

class _MemoryCandidates {
  const _MemoryCandidates({
    required this.stamp,
    required this.nowMs,
    required this.items,
  });

  final String stamp;
  final int nowMs;
  final List<Map<String, Object?>> items;
}

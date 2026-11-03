import 'dart:convert';
import 'package:drift/drift.dart';
import '../../domain/repositories/memory_repository.dart';
import '../local/app_database.dart';
import 'drift_repository_support.dart';

/// 仅负责助手记忆、来源、用户更正和忘记；与记录仓储共享数据库连接。
class DriftMemoryRepository extends DriftRepositorySupport
    implements MemoryRepository {
  DriftMemoryRepository(super.db, {super.clock});

  static const _versionFields = [
    'id',
    'goal_id',
    'kind',
    'content',
    'source',
    'certainty',
    'conflict_key',
    'updated_at',
    'expires_at',
    'forgotten',
    'user_edited',
  ];

  Map<String, Object?> _version(Map<String, Object?> entry) => {
    for (final key in _versionFields) key: entry[key],
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
      'kind': raw['kind'],
      'content': truncated
          ? String.fromCharCodes(content.runes.take(200))
          : content,
      if (truncated) 'contentTruncated': true,
      if (truncated) 'contentLength': length,
      'certainty': raw['certainty'],
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
      },
      () async {
        final page = await queryMemory(
          goalId: goalId,
          search: search,
          offset: offset,
          limit: limit,
          includeSourceText: false,
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
        'SELECT * FROM memory_entries WHERE id IN (${List.filled(ids.length, '?').join(',')})',
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
    return {
      'status': issues.isEmpty ? 'ready' : 'blocked',
      'counts': {
        'requested': itemIds.length,
        'matched': selected.length,
        'changed': 0,
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
          return {...checked, 'operationId': operationId};
        }
        final selected = (checked['items'] as List)
            .cast<Map<String, Object?>>();
        final ids = selected.map((item) => item['id'] as String).toList();
        await (db.update(db.memoryEntries)..where((t) => t.id.isIn(ids))).write(
          MemoryEntriesCompanion(
            forgotten: const Value(true),
            userEdited: const Value(true),
            updatedAt: Value(clock().millisecondsSinceEpoch),
          ),
        );
        return {
          'status': 'success',
          'operationId': operationId,
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
  }) async {
    if (offset < 0 || limit < 1 || limit > 100) throw ArgumentError('记忆分页范围无效');
    final where = <String>['forgotten=0'];
    final args = <Object>[];
    if (!includeExpired) {
      where.add('(expires_at IS NULL OR expires_at>?)');
      args.add(clock().millisecondsSinceEpoch);
    }
    if (goalId != null) {
      where.add('(goal_id IS NULL OR goal_id=?)');
      args.add(goalId);
    }
    if (search != null) {
      where.add('(content LIKE ? OR id=?)');
      args.addAll(['%$search%', search]);
    }
    final clause = where.join(' AND ');
    final count =
        (await rows(
              'SELECT COUNT(*) n FROM memory_entries WHERE $clause',
              args,
            )).single['n']
            as int;
    final result = DriftRepositorySupport.page(
      await rows(
        'SELECT *, (SELECT title FROM goals WHERE goals.id=memory_entries.goal_id) AS goalTitle FROM memory_entries WHERE $clause ORDER BY ${search == null ? '' : 'CASE WHEN id=? THEN 0 ELSE 1 END,'}user_edited DESC,updated_at DESC,id LIMIT ? OFFSET ?',
        [...args, ?search, limit, offset],
      ),
      count,
      offset,
    );
    for (final entry
        in includeSourceText
            ? result['items'] as List<Map<String, Object?>>
            : const <Map<String, Object?>>[]) {
      final parts = (entry['source'] as String).split(':');
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

  @override
  Future<Map<String, Object?>> saveMemory(
    Map<String, Object?> entry, {
    bool userEdited = false,
    String? operationId,
  }) => commandResult(operationId, 'memory_save', entry['id'] as String, {
    ...entry,
    'userEdited': userEdited,
  }, () => _saveMemory(entry, userEdited: userEdited));

  Future<Map<String, Object?>> _saveMemory(
    Map<String, Object?> entry, {
    bool userEdited = false,
  }) async {
    final id = entry['id'] as String;
    final content = (entry['content'] as String).trim();
    var source = entry['source'] as String;
    final sourceParts = source.split(':');
    if (sourceParts.length == 3 &&
        sourceParts.first == 'conversation' &&
        int.tryParse(sourceParts.last) == null) {
      final user = await rows(
        "SELECT sequence FROM assistant_session_records WHERE session_id=? AND type='message_added' AND CASE WHEN json_valid(data) THEN json_extract(data,'\$.message.role') ELSE NULL END='user' ORDER BY sequence DESC LIMIT 1",
        [sourceParts[1]],
      );
      if (user.isNotEmpty) {
        source = 'conversation:${sourceParts[1]}:${user.single['sequence']}';
      }
    }

    final key = entry['conflictKey'] as String? ?? content;
    final goal = entry['goalId'] as String?;
    if (RegExp(
      r'(?:tvly-[A-Za-z0-9_-]{12,}|sk-[A-Za-z0-9_-]{16,}|(?:api.?key|token|密码|密钥)\s*[:：=]\s*\S{8,})',
      caseSensitive: false,
    ).hasMatch(content)) {
      throw ArgumentError('凭据请保存到安全设置，不放入助手记忆');
    }
    final kind = entry['kind'] as String?;
    final expiresAt = entry['expiresAt'];
    if (content.isEmpty ||
        content.length > 1000 ||
        source.trim().isEmpty ||
        !['preference', 'fact', 'constraint', 'observation'].contains(kind)) {
      throw ArgumentError('记忆内容、类型或来源无效');
    }
    if (expiresAt != null && expiresAt is! int) {
      throw ArgumentError('记忆期限格式无效');
    }
    final expiresAtMs = expiresAt as int?;
    final updatedAt = clock().millisecondsSinceEpoch;
    if (kind == 'constraint' &&
        (expiresAtMs == null || expiresAtMs <= updatedAt)) {
      throw ArgumentError('约束记忆必须包含未来的期限');
    }
    final same = await rows(
      'SELECT * FROM memory_entries WHERE id=? OR goal_id IS ?',
      [id, goal],
    );
    String normalized(Object? value) =>
        (value as String).trim().replaceAll(RegExp(r'\s+'), ' ');
    final expectedVersion = entry['expectedVersion'];
    if (expectedVersion != null) {
      final existing = same.where((row) => row['id'] == id).firstOrNull;
      if (existing == null ||
          jsonEncode(_version(existing)) != jsonEncode(expectedVersion)) {
        return {'status': 'blocked', 'id': id, 'reason': 'changed'};
      }
    }
    final protected = same.where(
      (e) =>
          !userEdited &&
          ((e['forgotten'] == 1 &&
                  (e['id'] == id ||
                      normalized(e['content']) == normalized(content))) ||
              (e['user_edited'] == 1 && e['id'] == id)),
    );
    if (protected.isNotEmpty) {
      return {
        'status': 'blocked',
        'id': protected.first['id'],
        'reason': 'protected_memory',
      };
    }
    final existing = same.where((e) => e['id'] == id).firstOrNull;
    if (existing != null && existing['forgotten'] == 1) {
      return {'status': 'blocked', 'id': id, 'reason': 'forgotten_memory'};
    }
    if (existing != null && !userEdited) {
      return {'status': 'blocked', 'id': id, 'reason': 'existing_id'};
    }
    if (!userEdited) {
      final live = same.where((e) => e['forgotten'] == 0).toList();
      final keyText = normalized(key).toLowerCase();
      final topicMatches = live.where((e) {
        final sameKey = normalized(e['conflict_key']).toLowerCase() == keyText;
        // 文本包含不证明同一事实：目标/动机、肯定/否定必须能独立保留。
        return sameKey || normalized(e['content']) == normalized(content);
      }).toList();
      if (topicMatches.isNotEmpty) {
        // 用户手动编辑的事实保持原样；自动提取只更新未编辑的同主题条目。
        final manual = topicMatches
            .where((e) => e['user_edited'] == 1)
            .firstOrNull;
        if (manual != null) {
          return {'status': 'unchanged', 'id': manual['id']};
        }
        topicMatches.sort((a, b) {
          final aExact = normalized(a['conflict_key']).toLowerCase() == keyText;
          final bExact = normalized(b['conflict_key']).toLowerCase() == keyText;
          if (aExact != bExact) return aExact ? -1 : 1;
          return (b['updated_at'] as int).compareTo(a['updated_at'] as int);
        });
        final target = topicMatches.first;
        if (normalized(target['content']) == normalized(content) &&
            target['kind'] == kind &&
            target['certainty'] == (entry['certainty'] ?? 'unverified') &&
            target['expires_at'] == expiresAtMs) {
          return {'status': 'unchanged', 'id': target['id']};
        }
        await (db.update(
          db.memoryEntries,
        )..where((t) => t.id.equals(target['id'] as String))).write(
          MemoryEntriesCompanion(
            content: Value(content),
            kind: Value(kind!),
            source: Value(source),
            certainty: Value(entry['certainty'] as String? ?? 'unverified'),
            updatedAt: Value(updatedAt),
            expiresAt: Value(expiresAtMs),
          ),
        );
        return {'status': 'updated', 'id': target['id']};
      }
    }
    await db
        .into(db.memoryEntries)
        .insertOnConflictUpdate(
          MemoryEntriesCompanion.insert(
            id: id,
            goalId: Value(goal),
            kind: kind!,
            content: content,
            source: source,
            certainty: entry['certainty'] as String? ?? 'unverified',
            conflictKey: key,
            updatedAt: updatedAt,
            expiresAt: Value(expiresAtMs),
            userEdited: Value(userEdited),
          ),
        );
    return {'status': existing != null ? 'updated' : 'created', 'id': id};
  }

  @override
  Future<void> forgetMemory(String id, {String? operationId}) => command(
    operationId,
    'memory_forget',
    id,
    {'id': id},
    {'forgotten': true},
    () => _forgetMemory(id),
  );

  Future<void> _forgetMemory(String id) async {
    await (db.update(db.memoryEntries)..where((t) => t.id.equals(id))).write(
      MemoryEntriesCompanion(
        forgotten: const Value(true),
        userEdited: const Value(true),
        updatedAt: Value(clock().millisecondsSinceEpoch),
      ),
    );
  }

  @override
  Future<String> coreMemory() async {
    final entries = (await rows(
      "SELECT * FROM memory_entries WHERE forgotten=0 AND goal_id IS NULL AND certainty='stated' AND (expires_at IS NULL OR expires_at>?) ORDER BY user_edited DESC,updated_at DESC,id LIMIT 10",
      [clock().millisecondsSinceEpoch],
    ));
    final out = <Map<String, Object?>>[];
    var size = 2;
    for (final e in entries) {
      if (e['certainty'] == 'unverified' || e['goal_id'] != null) continue;
      final v = {
        'id': e['id'],
        'kind': e['kind'],
        'content': e['content'],
        'source': e['source'],
        'certainty': e['certainty'],
        'expiresAt': e['expires_at'],
      };
      final n = jsonEncode(v).length + (out.isEmpty ? 0 : 1);
      if (size + n > 2000 || out.length >= 10) break;
      size += n;
      out.add(v);
    }
    return jsonEncode(out);
  }
}

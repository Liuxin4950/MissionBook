import 'dart:convert';
import 'package:drift/drift.dart';
import '../../domain/repositories/memory_repository.dart';
import '../local/app_database.dart';
import 'drift_repository_support.dart';

/// 仅负责助手记忆、来源、用户更正和忘记；与记录仓储共享数据库连接。
class DriftMemoryRepository extends DriftRepositorySupport
    implements MemoryRepository {
  DriftMemoryRepository(super.db, {super.clock});
  @override
  Future<Map<String, Object?>> queryMemory({
    String? goalId,
    String? search,
    int offset = 0,
    bool includeExpired = false,
  }) async {
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
        'SELECT *, (SELECT title FROM goals WHERE goals.id=memory_entries.goal_id) AS goalTitle FROM memory_entries WHERE $clause ORDER BY user_edited DESC,updated_at DESC,id LIMIT 20 OFFSET ?',
        [...args, offset],
      ),
      count,
      offset,
    );
    for (final entry in result['items'] as List<Map<String, Object?>>) {
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
  Future<void> saveMemory(
    Map<String, Object?> entry, {
    bool userEdited = false,
    String? operationId,
  }) => command(operationId, 'memory_save', entry['id'] as String, entry, {
    'saved': true,
    'id': entry['id'],
  }, () => _saveMemory(entry, userEdited: userEdited));

  Future<void> _saveMemory(
    Map<String, Object?> entry, {
    bool userEdited = false,
  }) => db.transaction(() async {
    await lock();
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
    if (content.isEmpty ||
        content.length > 1000 ||
        source.trim().isEmpty ||
        ![
          'preference',
          'fact',
          'constraint',
          'observation',
        ].contains(entry['kind'])) {
      throw ArgumentError('记忆内容、类型或来源无效');
    }
    final same = await rows(
      'SELECT * FROM memory_entries WHERE id=? OR source=? OR (conflict_key=? AND goal_id IS ?)',
      [id, source, key, goal],
    );
    if (!userEdited &&
        same.any((e) => e['forgotten'] == 1 || e['user_edited'] == 1)) {
      return;
    }
    final conflict = same.where(
      (e) =>
          e['conflict_key'] == key &&
          e['goal_id'] == goal &&
          e['content'] != content &&
          e['forgotten'] == 0,
    );
    if (!userEdited && conflict.isNotEmpty) {
      // 冲突观察保持待验证，不让模型静默替换用户事实。
      entry = {...entry, 'certainty': 'unverified', 'kind': 'observation'};
    }
    if (!userEdited &&
        same.any((e) => e['content'] == content && e['forgotten'] == 0)) {
      return;
    }
    final existing = same.where((e) => e['id'] == id);
    if (existing.isNotEmpty && existing.single['forgotten'] == 1) return;
    await db
        .into(db.memoryEntries)
        .insertOnConflictUpdate(
          MemoryEntriesCompanion.insert(
            id: id,
            goalId: Value(goal),
            kind: entry['kind'] as String,
            content: content,
            source: source,
            certainty: entry['certainty'] as String? ?? 'unverified',
            conflictKey: key,
            updatedAt: clock().toUtc().millisecondsSinceEpoch,
            expiresAt: Value(entry['expiresAt'] as int?),
            userEdited: Value(userEdited),
          ),
        );
  });

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

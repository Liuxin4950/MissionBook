import '../../domain/repositories/memory_repository.dart';
import '../../domain/rules/evidence_rules.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';
import 'package:drift/drift.dart';
import 'package:timezone/timezone.dart' as tz;
import '../../domain/entities/evidence.dart';
import '../../domain/entities/user_execution_report.dart';
import '../../domain/entities/execution_command.dart';
import '../../domain/entities/execution_event.dart';
import '../../domain/entities/mission_phase.dart';
import '../../domain/repositories/record_repository.dart';
import '../local/app_database.dart';
import 'drift_mission_repository.dart';

/// 内容、材料引用和分析待办共用一个 SQLite 事务。
class DriftRecordRepository implements RecordRepository, MemoryRepository {
  DriftRecordRepository(this.db, {DateTime Function()? clock})
    : clock = clock ?? DateTime.now;
  final AppDatabase db;
  final DateTime Function() clock;

  /// 独立记录可删除；正式材料必须保留，以免改写任务事实。
  @override
  Future<void> deleteRecord(String id) => db.transaction(() async {
    await lock();
    final record = await (db.select(
      db.records,
    )..where((r) => r.id.equals(id))).getSingleOrNull();
    if (record == null) return;
    if ((await rows('SELECT id FROM evidence_records WHERE record_id=?', [
      id,
    ])).isNotEmpty) {
      throw const EvidenceConflict('已作为任务材料的记录不能删除，请在任务材料中追加修正');
    }
    if (record.goalNodeId != null) {
      await db.customStatement(
        '''INSERT INTO analysis_jobs(scope,target_id,source_version,status,attempts,available_at)
        SELECT 'node',id,1,'pending',0,0 FROM (
          WITH RECURSIVE parents(id) AS (SELECT ? UNION SELECT n.parent_node_id FROM goal_nodes n JOIN parents p ON n.id=p.id WHERE n.parent_node_id IS NOT NULL)
          SELECT id FROM parents) WHERE id IS NOT NULL
        ON CONFLICT(scope,target_id) DO UPDATE SET source_version=source_version+1,status='pending',attempts=0,available_at=0,error=NULL''',
        [record.goalNodeId],
      );
    }
    if (record.goalId != null) {
      await db.customStatement(
        '''INSERT INTO analysis_jobs(scope,target_id,source_version,status,attempts,available_at)
        VALUES('goal',?,1,'pending',0,0) ON CONFLICT(scope,target_id) DO UPDATE SET
        source_version=source_version+1,status='pending',attempts=0,available_at=0,error=NULL''',
        [record.goalId],
      );
    }
    await db.customStatement(
      "DELETE FROM analysis_jobs WHERE scope='record' AND target_id=?",
      [id],
    );
    await db.customStatement(
      "DELETE FROM analysis_versions WHERE scope='record' AND target_id=?",
      [id],
    );
    await (db.delete(db.records)..where((r) => r.id.equals(id))).go();
  });
  @override
  Future<Map<String, Object?>> associationChoices(
    String kind, {
    String search = '',
    int offset = 0,
  }) async {
    final table = switch (kind) {
      'goal' => 'goals',
      'node' => 'goal_nodes',
      'mission' => 'missions',
      _ => throw ArgumentError('关联类型无效'),
    };
    final count =
        (await rows('SELECT COUNT(*) n FROM $table WHERE title LIKE ?', [
              '%$search%',
            ])).single['n']
            as int;
    return page(
      await rows(
        'SELECT id,title FROM $table WHERE title LIKE ? ORDER BY title,id LIMIT 20 OFFSET ?',
        ['%$search%', offset],
      ),
      count,
      offset,
    );
  }

  Future<List<Map<String, Object?>>> rows(
    String sql, [
    List<Object?> args = const [],
  ]) async =>
      (await db
              .customSelect(
                sql,
                variables: args
                    .map<Variable>(
                      (v) => switch (v) {
                        int n => Variable.withInt(n),
                        String text => Variable.withString(text),
                        null => const Variable<String>(null),
                        _ => throw ArgumentError('无效查询参数'),
                      },
                    )
                    .toList(),
              )
              .get())
          .map((r) => r.data)
          .toList();
  Future<void> lock() => db.customStatement(
    'UPDATE analysis_jobs SET source_version=source_version WHERE 0',
  );

  Future<void> command(
    String? operationId,
    String kind,
    String entityId,
    Map<String, Object?> input,
    Map<String, Object?> result,
    Future<void> Function() write,
  ) async {
    if (operationId == null) {
      await write();
      return;
    }
    final fingerprint = sha256
        .convert(utf8.encode(jsonEncode(input)))
        .toString();
    await db.transaction(() async {
      await lock();
      final saved = await (db.select(
        db.operationReceipts,
      )..where((t) => t.id.equals(operationId))).getSingleOrNull();
      if (saved != null) {
        if (saved.kind != kind ||
            saved.fingerprint != fingerprint ||
            saved.entityId != entityId) {
          throw const EvidenceConflict('操作编号已用于不同请求');
        }
        return;
      }
      await write();
      await db
          .into(db.operationReceipts)
          .insert(
            OperationReceiptsCompanion.insert(
              id: operationId,
              kind: kind,
              fingerprint: fingerprint,
              entityId: entityId,
              resultJson: jsonEncode(result),
              createdAt: clock().millisecondsSinceEpoch,
            ),
          );
    });
  }

  @override
  Future<void> saveRecord(
    EvidenceDraft draft, {
    String? goalId,
    String? nodeId,
    String? missionId,
  }) => command(
    draft.id,
    'record_save',
    draft.id,
    {
      'type': draft.type.name,
      'source': draft.source.name,
      'content': draft.content,
      'key': draft.attachmentStorageKey,
      'name': draft.attachmentFileName,
      'mime': draft.attachmentMimeType,
      'capturedAt': draft.capturedAt?.millisecondsSinceEpoch,
      'goalId': goalId,
      'nodeId': nodeId,
      'missionId': missionId,
    },
    {'saved': true, 'recordId': draft.id},
    () => _saveRecord(
      draft,
      goalId: goalId,
      nodeId: nodeId,
      missionId: missionId,
    ),
  );

  Future<void> _saveRecord(
    EvidenceDraft draft, {
    String? goalId,
    String? nodeId,
    String? missionId,
  }) => db.transaction(() async {
    validateEvidenceDraft(draft, missionId ?? draft.id);
    await lock();
    final prior = await (db.select(
      db.records,
    )..where((t) => t.id.equals(draft.id))).getSingleOrNull();
    final type = switch (draft.type) {
      EvidenceType.manualRecord => 'MANUAL_RECORD',
      _ => draft.type.name.toUpperCase(),
    };
    final source = switch (draft.source) {
      EvidenceSource.fileSystem => 'FILE_SYSTEM',
      _ => draft.source.name.toUpperCase(),
    };
    if (prior != null) {
      if (prior.type != type ||
          prior.source != source ||
          prior.content != draft.content ||
          prior.attachmentStorageKey != draft.attachmentStorageKey ||
          prior.attachmentFileName != draft.attachmentFileName ||
          prior.attachmentMimeType != draft.attachmentMimeType ||
          prior.capturedAt != draft.capturedAt?.millisecondsSinceEpoch) {
        throw const EvidenceConflict('记录编号已用于不同内容');
      }
      // 重试只确认原内容，关联使用独立命令，不能悄悄改写已提交事实。
      if (missionId != null) await linkRecord(draft.id, missionId: missionId);
      return;
    }
    final scope = await _scope(goalId, nodeId, missionId);
    final now = clock().toUtc().millisecondsSinceEpoch;
    await db
        .into(db.records)
        .insert(
          RecordsCompanion.insert(
            id: draft.id,
            type: type,
            source: source,
            content: Value(draft.content),
            attachmentStorageKey: Value(draft.attachmentStorageKey),
            attachmentFileName: Value(draft.attachmentFileName),
            attachmentMimeType: Value(draft.attachmentMimeType),
            capturedAt: Value(draft.capturedAt?.millisecondsSinceEpoch),
            occurredAt: draft.capturedAt?.millisecondsSinceEpoch ?? now,
            createdAt: now,
            goalId: Value(scope.$1),
            goalNodeId: Value(scope.$2),
          ),
        );
    if (missionId != null) await _attach(draft.id, missionId);
  });

  Future<(String?, String?)> _scope(
    String? goal,
    String? node,
    String? mission,
  ) async {
    if (mission != null) {
      final row = await (db.select(
        db.missions,
      )..where((t) => t.id.equals(mission))).getSingleOrNull();
      if (row == null) throw ArgumentError('任务不存在');
      if ((goal != null && row.goalId != goal) ||
          (node != null && row.goalNodeId != node)) {
        throw ArgumentError('任务与所选目标、节点不一致');
      }
      return (row.goalId, row.goalNodeId);
    }
    if (node != null) {
      final row = await (db.select(
        db.goalNodes,
      )..where((t) => t.id.equals(node))).getSingleOrNull();
      if (row == null || (goal != null && row.goalId != goal)) {
        throw ArgumentError('目标节点不存在或归属不一致');
      }
      goal = row.goalId;
    }
    if (goal != null &&
        (await rows('SELECT id FROM goals WHERE id=?', [goal])).isEmpty) {
      throw ArgumentError('目标不存在');
    }
    return (goal, node);
  }

  @override
  Future<void> linkRecord(
    String id, {
    String? goalId,
    String? nodeId,
    String? missionId,
    String? operationId,
  }) => command(
    operationId,
    'record_link',
    id,
    {
      'recordId': id,
      'goalId': goalId,
      'nodeId': nodeId,
      'missionId': missionId,
    },
    {'saved': true},
    () => _linkRecord(id, goalId: goalId, nodeId: nodeId, missionId: missionId),
  );
  Future<void> _linkRecord(
    String id, {
    String? goalId,
    String? nodeId,
    String? missionId,
  }) => db.transaction(() async {
    await lock();
    final r = await (db.select(
      db.records,
    )..where((t) => t.id.equals(id))).getSingle();
    final links = await rows(
      'SELECT mission_id FROM evidence_records WHERE record_id=?',
      [id],
    );
    if (links.isNotEmpty) {
      if (missionId != links.first['mission_id']) {
        throw const EvidenceConflict('正式材料保留原引用，请追加修正');
      }
      return;
    }
    final scope = await _scope(goalId, nodeId, missionId);
    await (db.update(db.records)..where((t) => t.id.equals(r.id))).write(
      RecordsCompanion(goalId: Value(scope.$1), goalNodeId: Value(scope.$2)),
    );
    if (missionId != null) await _attach(id, missionId);
  });

  Future<void> _attach(String id, String missionId) async {
    final missions = DriftMissionRepository(db, clock: clock);
    final detail = (await missions.findDetail(missionId))!;
    final now = clock().toUtc();
    if (detail.phase == MissionPhase.evidencePending &&
        detail.schedule.evidenceDeadlineAt != null &&
        !now.isBefore(detail.schedule.evidenceDeadlineAt!)) {
      await missions.reconcileEvidenceDeadlines();
    }
    final r = await (db.select(
      db.records,
    )..where((t) => t.id.equals(id))).getSingle();
    await db
        .into(db.evidenceRecords)
        .insert(
          EvidenceRecordsCompanion.insert(
            id: 'record:$id',
            missionId: missionId,
            submissionId: 'record:$id',
            recordId: Value(id),
            type: r.type,
            source: r.source,
            submittedAt: now.millisecondsSinceEpoch,
          ),
        );
    await missions.findDetail(missionId); // 同一事务内复查领域阶段，失败全部回滚。
  }

  @override
  Future<Map<String, Object?>> queryRecords({
    String? id,
    String? goalId,
    String? nodeId,
    String? missionId,
    String? date,
    int offset = 0,
    bool content = false,
    int contentOffset = 0,
  }) async {
    if (offset < 0) throw ArgumentError('分页位置无效');
    final clauses = <String>[];
    final args = <Object>[];
    void filter(String sql, Object? v) {
      if (v != null) {
        clauses.add(sql);
        args.add(v);
      }
    }

    filter('r.id=?', id);
    filter('r.goal_id=?', goalId);
    filter('r.goal_node_id=?', nodeId);
    filter(
      'EXISTS (SELECT 1 FROM evidence_records e WHERE e.record_id=r.id AND e.mission_id=?)',
      missionId,
    );
    if (date != null) {
      final d = DateTime.parse(date);
      final zone = tz.getLocation('Asia/Shanghai');
      args.addAll([
        tz.TZDateTime(zone, d.year, d.month, d.day).millisecondsSinceEpoch,
        tz.TZDateTime(zone, d.year, d.month, d.day + 1).millisecondsSinceEpoch,
      ]);
      clauses.add('r.occurred_at>=? AND r.occurred_at<?');
    }
    final where = clauses.isEmpty ? '' : 'WHERE ${clauses.join(' AND ')}';
    final total =
        (await rows(
              'SELECT COUNT(*) n FROM records r $where',
              args,
            )).single['n']
            as int;
    final items = await rows(
      'SELECT r.*, (SELECT mission_id FROM evidence_records e WHERE e.record_id=r.id LIMIT 1) mission_id FROM records r $where ORDER BY r.occurred_at DESC,r.id LIMIT 20 OFFSET ?',
      [...args, offset],
    );
    for (final item in items) {
      final text = item['content'] as String?;
      final limit = content ? 6000 : 160;
      if (text != null) {
        if (contentOffset < 0) throw ArgumentError('正文分段位置无效');
        final start = content ? contentOffset.clamp(0, text.length) : 0;
        final end = (start + limit).clamp(0, text.length);
        item['content'] = text.substring(start, end);
        item['contentLength'] = text.length;
        item['contentOffset'] = start;
        item['nextContentOffset'] = end < text.length ? end : null;
        item['contentTruncated'] = end < text.length;
      }
      item['analysis'] = await analysis('record', item['id'] as String);
    }
    return page(items, total, offset);
  }

  @override
  Future<void> updateRecordContent(
    String id,
    String? expectedContent,
    String? content,
  ) => db.transaction(() async {
    await lock();
    final row = await (db.select(
      db.records,
    )..where((t) => t.id.equals(id))).getSingle();
    if ((await rows('SELECT id FROM evidence_records WHERE record_id=?', [
      id,
    ])).isNotEmpty) {
      throw const EvidenceConflict('正式材料通过任务材料区追加修正');
    }
    if (row.content == content) return;
    if (row.content != expectedContent) {
      throw const EvidenceConflict('记录已被修改，请重读后更正');
    }
    if (['TEXT', 'CODE', 'MANUAL_RECORD'].contains(row.type) &&
        (content?.trim().isEmpty ?? true)) {
      throw ArgumentError('记录正文不能为空');
    }
    await (db.update(db.records)..where((t) => t.id.equals(id))).write(
      RecordsCompanion(content: Value(content)),
    );
  });

  static Map<String, Object?> page(
    List<Map<String, Object?>> items,
    int total,
    int offset,
  ) => {
    'items': items,
    'total': total,
    'offset': offset,
    'nextOffset': offset + items.length < total ? offset + items.length : null,
    'truncated': offset + items.length < total,
  };
  @override
  Future<Map<String, Object?>> analysis(String scope, String id) async {
    final jobs = await rows(
      'SELECT status,source_version,error,attempts FROM analysis_jobs WHERE scope=? AND target_id=?',
      [scope, id],
    );
    final versions = await rows(
      'SELECT content,source_version,coverage,created_at,closing FROM analysis_versions WHERE scope=? AND target_id=? ORDER BY source_version DESC,created_at DESC,id DESC LIMIT 1',
      [scope, id],
    );
    return {
      'state': jobs.isEmpty
          ? 'not_requested'
          : (jobs.single['status'] as String).replaceFirst('manual_', ''),
      'manual':
          jobs.isNotEmpty &&
          (jobs.single['status'] as String).startsWith('manual_'),
      if (jobs.isNotEmpty) 'error': jobs.single['error'],
      if (versions.isNotEmpty) ...versions.single,
      'stale':
          versions.isNotEmpty &&
          jobs.isNotEmpty &&
          versions.single['source_version'] != jobs.single['source_version'],
    };
  }

  @override
  Future<void> reportExecution(
    UserExecutionReport report, {
    required int expectedSequence,
    required String scheduleId,
    UserReportedResult? result,
    bool? submitOptionalEvidence,
  }) => command(
    report.id,
    'execution_report',
    report.missionId,
    {
      'date': report.occurrenceDate,
      'zone': report.timeZoneId,
      'basis': report.basis,
      'start': report.actualStart?.millisecondsSinceEpoch,
      'end': report.actualEnd?.millisecondsSinceEpoch,
      'supersedesId': report.supersedesId,
      'result': result?.name,
      'optional': submitOptionalEvidence,
    },
    {'saved': true, 'reportId': report.id},
    () => _reportExecution(
      report,
      expectedSequence: expectedSequence,
      scheduleId: scheduleId,
      result: result,
      submitOptionalEvidence: submitOptionalEvidence,
    ),
  );
  Future<void> _reportExecution(
    UserExecutionReport report, {
    required int expectedSequence,
    required String scheduleId,
    UserReportedResult? result,
    bool? submitOptionalEvidence,
  }) => db.transaction(() async {
    await lock();
    report.validate(clock().toUtc());
    final previous = await rows(
      'SELECT * FROM user_execution_reports WHERE id=?',
      [report.id],
    );
    if (previous.isNotEmpty) {
      final p = previous.single;
      if (p['mission_id'] != report.missionId ||
          p['occurrence_date'] != report.occurrenceDate ||
          p['time_zone_id'] != report.timeZoneId ||
          p['actual_start'] != report.actualStart?.millisecondsSinceEpoch ||
          p['actual_end'] != report.actualEnd?.millisecondsSinceEpoch ||
          p['basis'] != report.basis ||
          p['supersedes_id'] != report.supersedesId) {
        throw const EvidenceConflict('补记编号已用于不同内容');
      }
      return;
    }
    final missions = DriftMissionRepository(db, clock: clock);
    final detail = await missions.findDetail(report.missionId);
    if (detail == null ||
        detail.lastSequence != expectedSequence ||
        detail.schedule.id != scheduleId) {
      throw const EvidenceConflict('任务已变化，请刷新后重试');
    }
    if (detail.phase == MissionPhase.cancelled) {
      throw ArgumentError('已取消任务不改写执行结果');
    }
    final latest = await rows(
      'SELECT id FROM user_execution_reports WHERE mission_id=? ORDER BY reported_at DESC,rowid DESC LIMIT 1',
      [report.missionId],
    );
    if (report.supersedesId != (latest.isEmpty ? null : latest.single['id'])) {
      throw const EvidenceConflict('时间声明已被更正，请刷新');
    }
    final ended = detail.events.any((e) => e.type == ExecutionEventType.end);
    if (!ended) {
      if (result == null) throw ArgumentError('请明确完成或未执行的结果');
      await missions.execute(
        ExecutionCommand(
          id: 'report:${report.id}',
          missionId: report.missionId,
          expectedSequence: expectedSequence,
          type: ExecutionEventType.end,
          scheduleRevisionId: detail.events.isEmpty ? scheduleId : null,
          isRetrospective: detail.events.isEmpty,
          reason: detail.events.isEmpty ? report.basis : null,
          userReportedResult: result,
          submitOptionalEvidence: submitOptionalEvidence,
          userReasonText: result == UserReportedResult.notCompleted
              ? report.basis
              : null,
        ),
      );
    } else if (result != null &&
        result != detail.events.last.userReportedResult) {
      throw ArgumentError('时间更正不改写原完成报告');
    }
    await db
        .into(db.userExecutionReports)
        .insert(
          UserExecutionReportsCompanion.insert(
            id: report.id,
            missionId: report.missionId,
            occurrenceDate: report.occurrenceDate,
            timeZoneId: report.timeZoneId,
            actualStart: Value(report.actualStart?.millisecondsSinceEpoch),
            actualEnd: Value(report.actualEnd?.millisecondsSinceEpoch),
            reportedAt: clock().toUtc().millisecondsSinceEpoch,
            basis: report.basis,
            supersedesId: Value(report.supersedesId),
          ),
        );
  });

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
    final result = page(
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
          (jsonDecode(source.single['data'] as String) as Map)['message'];
      if (message is Map && message['role'] == 'user') {
        final text = (message['content'] as List)
            .whereType<Map>()
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

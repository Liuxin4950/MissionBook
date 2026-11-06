import 'content_mapping.dart';
import '../../domain/entities/saved_record.dart';
import 'evidence_mapping.dart';
import '../../domain/entities/record_draft.dart';
import '../../domain/entities/analysis_scope.dart';
import 'package:drift/drift.dart';
import 'package:timezone/timezone.dart' as tz;
import '../../domain/entities/evidence.dart';
import '../../domain/entities/mission_schedule_revision.dart';
import '../../domain/repositories/record_repository.dart';
import '../../domain/repositories/mission_evidence_repository.dart';
import '../../domain/rules/content_rules.dart';
import '../local/app_database.dart';
import 'drift_mission_repository.dart';
import 'drift_repository_support.dart';

/// 独立记录的保存、关联与查询；任务材料只经共享材料命令追加。
class DriftRecordRepository extends DriftRepositorySupport
    implements RecordRepository {
  DriftRecordRepository(
    super.db, {
    super.clock,
    MissionEvidenceRepository? materials,
  }) : _materials =
           materials ??
           DriftMissionRepository(db, clock: clock ?? DateTime.now);
  final MissionEvidenceRepository _materials;

  /// 删除来源记录；任务已提交的材料快照独立保留。
  @override
  Future<void> deleteRecord(String id) => db.transaction(() async {
    await lock();
    final record = await (db.select(
      db.records,
    )..where((r) => r.id.equals(id))).getSingleOrNull();
    if (record == null) return;
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
    return DriftRepositorySupport.page(
      await rows(
        'SELECT id,title FROM $table WHERE title LIKE ? ORDER BY title,id LIMIT 20 OFFSET ?',
        ['%$search%', offset],
      ),
      count,
      offset,
    );
  }

  @override
  Future<void> saveRecord(
    RecordDraft draft, {
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
    RecordDraft draft, {
    String? goalId,
    String? nodeId,
    String? missionId,
  }) => db.transaction(() async {
    validateContentDraft(draft);
    await lock();
    final prior = await (db.select(
      db.records,
    )..where((t) => t.id.equals(draft.id))).getSingleOrNull();
    final type = switch (draft.type) {
      ContentType.manualRecord => 'MANUAL_RECORD',
      _ => draft.type.name.toUpperCase(),
    };
    final source = switch (draft.source) {
      ContentSource.fileSystem => 'FILE_SYSTEM',
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
      if (missionId != null) await _attach(draft.id, missionId);
      return;
    }
    final scope = await _scope(goalId, nodeId);
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

  Future<(String?, String?)> _scope(String? goal, String? node) async {
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
  Future<void> updateOwnership(
    String id, {
    String? goalId,
    String? nodeId,
    String? operationId,
  }) => command(
    operationId,
    'record_ownership',
    id,
    {'recordId': id, 'goalId': goalId, 'nodeId': nodeId},
    {'saved': true},
    () => db.transaction(() async {
      await lock();
      final r = await (db.select(
        db.records,
      )..where((t) => t.id.equals(id))).getSingleOrNull();
      if (r == null) {
        // 在写入前明确拒绝缺失对象，避免查询异常被助手当成结果未知。
        throw ArgumentError('记录 $id 不存在或已删除，请重新查询');
      }
      final scope = await _scope(goalId, nodeId);
      await (db.update(db.records)..where((t) => t.id.equals(r.id))).write(
        RecordsCompanion(goalId: Value(scope.$1), goalNodeId: Value(scope.$2)),
      );
    }),
  );

  Future<void> _attach(String id, String missionId) async {
    await _materials.attachRecordEvidence(id, missionId);
  }

  @override
  Future<RecordDraft> readDraft(String id) async {
    final row = await (db.select(
      db.records,
    )..where((r) => r.id.equals(id))).getSingleOrNull();
    if (row == null) throw StateError('记录已删除，请返回列表刷新');
    return recordDraftFromRow(row, id: id);
  }

  @override
  Future<RecordPage> readRecords({
    String? id,
    String? goalId,
    String? nodeId,
    String? missionId,
    String? date,
    int offset = 0,
    bool content = false,
    int contentOffset = 0,
  }) async {
    final page = await _queryRecords(
      id: id,
      goalId: goalId,
      nodeId: nodeId,
      missionId: missionId,
      date: date,
      offset: offset,
      content: content,
      contentOffset: contentOffset,
    );
    return RecordPage(
      total: page['total'] as int,
      nextOffset: page['nextOffset'] as int?,
      items: [
        for (final r in page['items'] as List<Map<String, Object?>>)
          SavedRecord(
            id: r['id'] as String,
            type: contentTypeFromStorage(r['type'] as String),
            source: contentSourceFromStorage(r['source'] as String),
            content: r['content'] as String?,
            attachmentStorageKey: r['attachment_storage_key'] as String?,
            attachmentFileName: r['attachment_file_name'] as String?,
            attachmentMimeType: r['attachment_mime_type'] as String?,
            capturedAt: r['captured_at'] == null
                ? null
                : DateTime.fromMillisecondsSinceEpoch(
                    r['captured_at'] as int,
                    isUtc: true,
                  ),
            contentLength: r['contentLength'] as int?,
            contentOffset: r['contentOffset'] as int?,
            occurredAt: DateTime.fromMillisecondsSinceEpoch(
              r['occurred_at'] as int,
              isUtc: true,
            ),
            createdAt: DateTime.fromMillisecondsSinceEpoch(
              r['created_at'] as int,
              isUtc: true,
            ),
            goalId: r['goal_id'] as String?,
            nodeId: r['goal_node_id'] as String?,
            goalTitle: r['goal_title'] as String?,
            nodeTitle: r['node_title'] as String?,
            materialMissionId: r['mission_id'] as String?,
            materialMissionTitle: r['mission_title'] as String?,
            nextContentOffset: r['nextContentOffset'] as int?,
            contentTruncated: r['contentTruncated'] == true,
          ),
      ],
    );
  }

  Future<Map<String, Object?>> _queryRecords({
    String? id,
    String? goalId,
    String? nodeId,
    String? missionId,
    String? date,
    int offset = 0,
    bool content = false,
    int contentOffset = 0,
  }) async {
    if (offset < 0 || contentOffset < 0) throw ArgumentError('分页位置无效');
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
      final zone = tz.getLocation(defaultScheduleTimeZone);
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
      'SELECT r.*, (SELECT title FROM goals WHERE id=r.goal_id) goal_title, (SELECT title FROM goal_nodes WHERE id=r.goal_node_id) node_title, (SELECT m.title FROM missions m JOIN evidence_records e ON e.mission_id=m.id WHERE e.record_id=r.id LIMIT 1) mission_title, (SELECT mission_id FROM evidence_records e WHERE e.record_id=r.id LIMIT 1) mission_id FROM records r $where ORDER BY r.occurred_at DESC,r.id LIMIT 20 OFFSET ?',
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
    }
    return DriftRepositorySupport.page(items, total, offset);
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

  @override
  Future<Map<String, Object?>> analysis(AnalysisScope scope, String id) async {
    final jobs = await rows(
      'SELECT status,source_version,error,attempts FROM analysis_jobs WHERE scope=? AND target_id=?',
      [scope.name, id],
    );
    final versions = await rows(
      'SELECT content,source_version,coverage,created_at,closing FROM analysis_versions WHERE scope=? AND target_id=? ORDER BY source_version DESC,created_at DESC,id DESC LIMIT 1',
      [scope.name, id],
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
}

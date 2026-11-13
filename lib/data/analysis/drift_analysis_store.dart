import '../repositories/drift_memory_repository.dart';
import '../../domain/entities/analysis_scope.dart';
import '../../domain/entities/content_draft.dart';
import 'dart:convert';
import 'dart:math';
import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';
import '../../application/analysis/analysis_service.dart';
import '../../domain/entities/mission_schedule_revision.dart';
import '../local/app_database.dart';
import '../repositories/drift_record_repository.dart';
import '../repositories/drift_mission_repository.dart';

class DriftAnalysisStore implements AnalysisStore {
  DriftAnalysisStore(this.db) : records = DriftRecordRepository(db);
  final AppDatabase db;
  final DriftRecordRepository records;
  @override
  Future<void> recover() async {
    await db.customStatement(
      "UPDATE analysis_jobs SET status=CASE WHEN status='manual_running' THEN 'manual_pending' ELSE 'pending' END WHERE status IN ('running','manual_running')",
    );
  }

  @override
  Future<void> resumeBlocked() async {
    await db.customStatement(
      "UPDATE analysis_jobs SET status=CASE WHEN status='manual_blocked' THEN 'manual_pending' ELSE 'pending' END,attempts=0,available_at=0,error=NULL WHERE status IN ('blocked','manual_blocked')",
    );
  }

  @override
  Future<AnalysisWork?> claim({
    Set<AnalysisScope>? automaticScopes,
  }) => db.transaction(() async {
    await records.lock();
    final now = DateTime.now().millisecondsSinceEpoch;
    final rows = await records.rows(
      "SELECT * FROM analysis_jobs WHERE scope!='record' AND ((status IN ('pending','failed') AND ${automaticScopes == null
          ? '1=1'
          : automaticScopes.isEmpty
          ? '0=1'
          : 'scope IN (${List.filled(automaticScopes.length, '?').join(',')})'}) OR status IN ('manual_pending','manual_failed')) AND attempts<5 AND available_at<=? AND (scope!='mission' OR EXISTS(SELECT 1 FROM execution_events e WHERE e.mission_id=analysis_jobs.target_id AND e.type='END')) ORDER BY CASE scope WHEN 'mission' THEN 0 WHEN 'node' THEN 1 WHEN 'goal' THEN 2 ELSE 3 END, available_at LIMIT 1",
      [...?automaticScopes?.map((scope) => scope.name), now],
    );
    if (rows.isEmpty) return null;
    final r = rows.single;
    final manual = (r['status'] as String).startsWith('manual_');
    await db.customStatement(
      'UPDATE analysis_jobs SET status=? WHERE scope=? AND target_id=?',
      [manual ? 'manual_running' : 'running', r['scope'], r['target_id']],
    );
    return AnalysisWork(
      AnalysisScope.parse(r['scope'] as String),
      r['target_id'] as String,
      r['source_version'] as int,
      r['closing'] == 1,
      r['attempts'] as int,
      manual,
    );
  });
  @override
  Future<AnalysisInput> input(AnalysisWork w) async {
    if (w.scope == AnalysisScope.reflection) {
      return AnalysisInput(
        await DriftMemoryRepository(db).reflectionInput(),
        const [],
      );
    }
    if (w.scope == AnalysisScope.memory) {
      final payload = await records.rows(
        'SELECT data,timestamp FROM assistant_session_records WHERE session_id=? AND sequence=?',
        _memorySource(w.id),
      );
      return AnalysisInput({
        'source': w.id,
        'sourceTimeZone': defaultScheduleTimeZone,
        'sourceAt': payload.isEmpty
            ? null
            : DateTime.fromMillisecondsSinceEpoch(
                payload.single['timestamp'] as int,
                isUtc: true,
              ).toIso8601String(),
        'userMessage': payload.isEmpty
            ? ''
            : _userText(payload.single['data'] as String),
      }, const []);
    }
    if (w.scope == AnalysisScope.mission) {
      final d = (await DriftMissionRepository(db).findDetail(w.id))!;
      final items = <Map<String, Object?>>[
        for (final e in d.effectiveEvidence)
          {
            'id': e.id,
            'scope': 'mission',
            'version': e.submittedAt.millisecondsSinceEpoch,
            'state': 'snapshot',
            'type': e.type.name,
            'content': e.content?.substring(
              0,
              min(8000, e.content?.length ?? 0),
            ),
            'contentTruncated': (e.content?.length ?? 0) > 8000,
            'attachmentFileName': e.attachmentFileName,
            'attachmentStorageKey': e.attachmentStorageKey,
            'capturedAt': e.capturedAt?.toIso8601String(),
            'submittedAt': e.submittedAt.toIso8601String(),
            'supersedesId': e.supersedesEvidenceId,
          },
      ];
      final events = d.events
          .map(
            (e) => {
              'id': e.id,
              'type': e.type.name,
              'occurredAt': e.occurredAt.toIso8601String(),
              'report': e.userReportedResult?.name,
              'retrospective': e.isRetrospective,
              'basis': e.reason,
            },
          )
          .toList();
      return AnalysisInput(
        {
          'id': d.mission.id,
          'title': d.mission.title,
          'policy': d.mission.verificationPolicy.name,
          'objective': d.executionPlan.objective,
          'steps': d.executionPlan.steps,
          'criteria': d.executionPlan.verificationCriteria,
          'deadline': d.schedule.evidenceDeadlineAt?.toIso8601String(),
          'phase': d.phase.name,
          'events': events.take(100).toList(),
          'eventCount': events.length,
          'eventsTruncated': events.length > 100,
          'failures': d.failures
              .map(
                (f) => {
                  'trigger': f.trigger,
                  'occurredAt': f.occurredAt.toIso8601String(),
                },
              )
              .toList(),
          'userTime': d.effectiveUserReport == null
              ? null
              : {
                  'date': d.effectiveUserReport!.occurrenceDate,
                  'start': d.effectiveUserReport!.actualStart
                      ?.toIso8601String(),
                  'end': d.effectiveUserReport!.actualEnd?.toIso8601String(),
                  'basis': d.effectiveUserReport!.basis,
                },
          'materialCount': d.effectiveEvidence.length,
        },
        items,
        images: [
          for (final e in d.effectiveEvidence)
            if (e.type == ContentType.image && e.attachmentStorageKey != null)
              AnalysisImage(
                materialId: e.id,
                storageKey: e.attachmentStorageKey!,
                mime: e.attachmentMimeType,
              ),
        ],
      );
    }
    final node = w.scope == AnalysisScope.node;
    final facts = (await records.rows(
      'SELECT * FROM ${node ? 'goal_nodes' : 'goals'} WHERE id=?',
      [w.id],
    )).single;
    final scope = node
        ? 'm.goal_node_id=?'
        : 'm.goal_id=? AND m.goal_node_id IS NULL';
    final allMissionCount =
        (await records.rows('SELECT COUNT(*) n FROM missions m WHERE $scope', [
              w.id,
            ])).single['n']
            as int;
    final meaningful = await records.rows(
      "SELECT m.id FROM missions m WHERE $scope AND (EXISTS(SELECT 1 FROM execution_events e WHERE e.mission_id=m.id AND e.type='END') OR EXISTS(SELECT 1 FROM analysis_versions v WHERE v.scope='mission' AND v.target_id=m.id))",
      [w.id],
    );
    facts['directMissionCount'] = allMissionCount;
    facts['missionsWithoutReviewFacts'] = allMissionCount - meaningful.length;
    final nodes = await records.rows(
      node
          ? 'SELECT id FROM goal_nodes WHERE parent_node_id=?'
          : 'SELECT id FROM goal_nodes WHERE goal_id=? AND parent_node_id IS NULL',
      [w.id],
    );
    final items = <Map<String, Object?>>[];
    for (final group in [
      (meaningful, AnalysisScope.mission),
      (nodes, AnalysisScope.node),
    ]) {
      items.addAll(
        await _children(
          group.$2,
          group.$1.map((row) => row['id'] as String).toList(),
        ),
      );
    }
    return AnalysisInput(facts, items);
  }

  String _userText(String encoded) {
    final message =
        (jsonDecode(encoded) as Map<String, dynamic>)['message']
            as Map<String, dynamic>;
    if (message['role'] != 'user') throw const FormatException('记忆来源不是用户陈述');
    final text = (message['content'] as List<dynamic>)
        .whereType<Map<String, dynamic>>()
        .where((b) => b['type'] == 'text')
        .map((b) => b['text'])
        .join()
        .split('MissionBook 文本附件')
        .first;
    return text.length > 8000 ? text.substring(0, 8000) : text;
  }

  /// 批量读取同一层级的摘要和展示事实，避免每个子项触发三次 SQL。
  Future<List<Map<String, Object?>>> _children(
    AnalysisScope scope,
    List<String> ids,
  ) async {
    if (ids.isEmpty) return const [];
    final table = switch (scope) {
      AnalysisScope.mission => 'missions',
      AnalysisScope.node => 'goal_nodes',
      _ => throw ArgumentError.value(scope, 'scope', '不支持的子摘要范围'),
    };
    final facts = switch (scope) {
      AnalysisScope.mission =>
        ',x.title,(SELECT user_reported_result FROM execution_events e WHERE e.mission_id=x.id AND e.type=\'END\') userReportedResult,(SELECT COUNT(*) FROM evidence_records e WHERE e.mission_id=x.id AND NOT EXISTS(SELECT 1 FROM evidence_records n WHERE n.supersedes_evidence_id=e.id)) materialCount',
      AnalysisScope.node => ',x.title,x.archived_at',
      _ => '',
    };
    final result = <Map<String, Object?>>[];
    // 保持低于常见 SQLite 绑定参数上限，也不让单条语句过长。
    for (var offset = 0; offset < ids.length; offset += 400) {
      final page = ids.sublist(offset, min(offset + 400, ids.length));
      final rows = await records.rows(
        '''SELECT x.id $facts,
                  j.status AS job_status,j.source_version AS job_source_version,
                  j.error AS job_error,
                  v.content AS version_content,
                  v.source_version AS version_source_version,
                  v.coverage AS version_coverage,
                  v.created_at AS version_created_at,
                  v.closing AS version_closing
           FROM $table x
           LEFT JOIN analysis_jobs j
             ON j.scope=? AND j.target_id=x.id
           LEFT JOIN analysis_versions v ON v.id=(
             SELECT av.id FROM analysis_versions av
             WHERE av.scope=? AND av.target_id=x.id
             ORDER BY av.source_version DESC,av.created_at DESC,av.id DESC LIMIT 1
           )
           WHERE x.id IN (${List.filled(page.length, '?').join(',')})''',
        [scope.name, scope.name, ...page],
      );
      for (final row in rows) {
        final status = row['job_status'] as String?;
        final jobVersion = row['job_source_version'] as int?;
        final version = row['version_source_version'] as int?;
        final summary = <String, Object?>{
          'state': status == null
              ? 'not_requested'
              : status.replaceFirst('manual_', ''),
          'manual': status?.startsWith('manual_') ?? false,
          if (status != null) 'error': row['job_error'],
          if (version != null) ...{
            'content': row['version_content'],
            'source_version': version,
            'coverage': row['version_coverage'],
            'created_at': row['version_created_at'],
            'closing': row['version_closing'],
          },
          'stale':
              version != null && jobVersion != null && version != jobVersion,
        };
        final index = switch (scope) {
          AnalysisScope.mission => <String, Object?>{
            'id': row['id'],
            'title': row['title'],
            'userReportedResult': row['userReportedResult'],
            'materialCount': row['materialCount'],
          },
          AnalysisScope.node => <String, Object?>{
            'id': row['id'],
            'title': row['title'],
            'archived_at': row['archived_at'],
          },
          _ => const <String, Object?>{},
        };
        result.add({
          'id': row['id'],
          'scope': scope.name,
          'version': version,
          'facts': index,
          ...summary,
        });
      }
    }
    return result;
  }

  @override
  Future<void> ensureReflectionJob() async {
    await db.customStatement(
      'INSERT INTO analysis_jobs(scope,target_id,source_version,status,attempts,available_at) '
      "VALUES('reflection','global',1,'pending',0,?) "
      'ON CONFLICT(scope,target_id) DO NOTHING',
      [
        DateTime.now().millisecondsSinceEpoch +
            const Duration(minutes: 5).inMilliseconds,
      ],
    );
  }

  @override
  Future<bool> completeReflection(AnalysisWork w, String json) async {
    final decoded = jsonDecode(json);
    final rawActions = decoded is Map ? decoded['actions'] : null;
    final actions = rawActions is List
        ? [
            for (final raw in rawActions)
              if (raw is Map) Map<String, Object?>.from(raw),
          ]
        : const <Map<String, Object?>>[];
    return db.transaction(() async {
      await records.lock();
      final job = await records.rows(
        'SELECT source_version,status FROM analysis_jobs WHERE scope=? AND target_id=?',
        [w.scope.name, w.id],
      );
      if (job.isEmpty ||
          job.single['source_version'] != w.version ||
          job.single['status'] != (w.manual ? 'manual_running' : 'running')) {
        return false;
      }
      await DriftMemoryRepository(db).applyReflection(
        actions,
        operationId:
            'reflection:${w.id}:${DateTime.now().millisecondsSinceEpoch}',
      );
      await db.customStatement(
        "UPDATE analysis_jobs SET status='pending',source_version=source_version+1,"
        "attempts=0,error=NULL,available_at=? WHERE scope=? AND target_id=?",
        [
          DateTime.now().millisecondsSinceEpoch +
              const Duration(hours: 6).inMilliseconds,
          w.scope.name,
          w.id,
        ],
      );
      return true;
    });
  }

  @override
  Future<bool> publish(
    AnalysisWork w,
    String content,
    List<Map<String, Object?>> sources,
    int coverage,
  ) => db.transaction(() async {
    await records.lock();
    final rows = await records.rows(
      'SELECT source_version,status FROM analysis_jobs WHERE scope=? AND target_id=?',
      [w.scope.name, w.id],
    );
    if (rows.isEmpty ||
        rows.single['source_version'] != w.version ||
        rows.single['status'] != (w.manual ? 'manual_running' : 'running')) {
      return false;
    }
    await db
        .into(db.analysisVersions)
        .insert(
          AnalysisVersionsCompanion.insert(
            id: const Uuid().v4(),
            scope: w.scope.name,
            targetId: w.id,
            sourceVersion: w.version,
            content: content,
            sourcesJson: jsonEncode(sources),
            coverage: coverage,
            createdAt: DateTime.now().millisecondsSinceEpoch,
            closing: Value(w.closing),
          ),
        );
    await db.customStatement(
      "UPDATE analysis_jobs SET status='ready',error=NULL,closing=0 WHERE scope=? AND target_id=?",
      [w.scope.name, w.id],
    );
    await parents(w.scope, w.id);
    return true;
  });
  Future<void> parents(AnalysisScope scope, String id) async {
    List<Map<String, Object?>> targets = [];
    if (scope == AnalysisScope.mission) {
      targets = await records.rows(
        "SELECT 'node' scope,goal_node_id id FROM missions WHERE id=? AND goal_node_id IS NOT NULL UNION SELECT 'goal',goal_id FROM missions WHERE id=? AND goal_id IS NOT NULL",
        [id, id],
      );
    } else if (scope == AnalysisScope.node) {
      targets = await records.rows(
        "SELECT 'node' scope,parent_node_id id FROM goal_nodes WHERE id=? AND parent_node_id IS NOT NULL UNION SELECT 'goal',goal_id FROM goal_nodes WHERE id=?",
        [id, id],
      );
    }
    for (final t in targets) {
      await retry(
        AnalysisScope.parse(t['scope'] as String),
        t['id'] as String,
        manual: false,
      );
    }
  }

  @override
  Future<void> fail(
    AnalysisWork w,
    String message, {
    bool blocked = false,
    bool interrupted = false,
  }) async {
    final next = DateTime.now()
        .add(
          Duration(
            seconds: interrupted ? 5 : 30 * pow(2, min(5, w.attempts)).toInt(),
          ),
        )
        .millisecondsSinceEpoch;
    await db.customStatement(
      'UPDATE analysis_jobs SET status=?,error=?,attempts=attempts+?,available_at=? WHERE scope=? AND target_id=? AND source_version=? AND status=?',
      [
        '${w.manual ? 'manual_' : ''}${blocked
            ? 'blocked'
            : interrupted
            ? 'pending'
            : 'failed'}',
        message,
        interrupted ? 0 : 1,
        next,
        w.scope.name,
        w.id,
        w.version,
        w.manual ? 'manual_running' : 'running',
      ],
    );
  }

  @override
  Future<void> retry(
    AnalysisScope scope,
    String id, {
    bool closing = false,
    bool manual = true,
    String? operationId,
  }) => records.command(
    operationId,
    'analysis_retry',
    id,
    {'scope': scope.name, 'closing': closing},
    {'queued': true},
    () => _retry(scope, id, closing: closing, manual: manual),
  );
  Future<void> _retry(
    AnalysisScope scope,
    String id, {
    bool closing = false,
    bool manual = true,
  }) async {
    await db.customStatement(
      "INSERT INTO analysis_jobs(scope,target_id,source_version,status,attempts,available_at,closing) VALUES(?,?,1,?,0,0,?) ON CONFLICT(scope,target_id) DO UPDATE SET source_version=source_version+1,status=excluded.status,attempts=0,available_at=0,error=NULL,closing=MAX(closing,excluded.closing)",
      [scope.name, id, manual ? 'manual_pending' : 'pending', closing ? 1 : 0],
    );
  }

  List<Object> _memorySource(String id) {
    final pos = id.lastIndexOf(':');
    return [id.substring(0, pos), int.parse(id.substring(pos + 1))];
  }

  @override
  Future<void> saveMemoryCandidates(AnalysisWork w, String json) async {
    final decoded = jsonDecode(json) as Map<String, dynamic>;
    final entries = decoded['entries'] as List;
    final sourceInput = await input(w);
    final userText = sourceInput.facts['userMessage'] as String;
    await db.transaction(() async {
      final current = await records.rows(
        'SELECT source_version FROM analysis_jobs WHERE scope=? AND target_id=?',
        [w.scope.name, w.id],
      );
      if (current.single['source_version'] != w.version) return;
      for (final raw in entries.take(5)) {
        if (raw is! Map) continue;
        final e = Map<String, Object?>.from(raw);
        final quote = e['quote'] as String?;
        final content = e['content'] as String?;
        final topic = e['topic'] as String?;
        final layer = e['layer'] as String? ?? 'semantic';
        // 抽取候选必须有明确主题；空主题不能借助仓储回退正文，避免把
        // malformed 模型输出伪装成稳定主题，同时不影响同批其他候选。
        if (e['certainty'] != 'stated' ||
            quote == null ||
            quote.trim().isEmpty ||
            content == null ||
            content.trim().isEmpty ||
            topic == null ||
            topic.trim().isEmpty ||
            !userText.contains(quote) ||
            !['identity', 'semantic', 'procedural'].contains(layer)) {
          continue;
        }
        e['id'] = const Uuid().v5(Namespace.url.value, 'memory:${w.id}:$topic');
        e['layer'] = layer;
        e['topic'] = topic;
        e['aliases'] = (e['aliases'] as List?)?.cast<String>() ?? const [];
        e['sourceKind'] = 'extraction';
        e['sourceRef'] = 'conversation:${w.id}';
        e['importance'] = 50;
        final expiresAt = e['expiresAt'];
        e['expiresAt'] = expiresAt is int
            ? expiresAt
            : expiresAt is String
            ? DateTime.tryParse(expiresAt)?.millisecondsSinceEpoch
            : null;
        try {
          await DriftMemoryRepository(db).saveMemory(e);
        } on ArgumentError {
          // 模型给出的约束缺少有效期限等内容不合规时，跳过该条而不是放弃整批。
          continue;
        }
      }
    });
  }
}

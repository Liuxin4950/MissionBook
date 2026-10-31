import 'dart:convert';
import 'dart:math';
import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';
import '../../application/analysis/analysis_service.dart';
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
    Set<String>? automaticScopes,
  }) => db.transaction(() async {
    await records.lock();
    final now = DateTime.now().millisecondsSinceEpoch;
    final rows = await records.rows(
      "SELECT * FROM analysis_jobs WHERE ((status IN ('pending','failed') AND ${automaticScopes == null
          ? '1=1'
          : automaticScopes.isEmpty
          ? '0=1'
          : 'scope IN (${List.filled(automaticScopes.length, '?').join(',')})'}) OR status IN ('manual_pending','manual_failed')) AND attempts<5 AND available_at<=? ORDER BY CASE scope WHEN 'record' THEN 0 WHEN 'mission' THEN 1 WHEN 'node' THEN 2 WHEN 'goal' THEN 3 ELSE 4 END, available_at LIMIT 1",
      [...?automaticScopes, now],
    );
    if (rows.isEmpty) return null;
    final r = rows.single;
    final manual = (r['status'] as String).startsWith('manual_');
    await db.customStatement(
      'UPDATE analysis_jobs SET status=? WHERE scope=? AND target_id=?',
      [manual ? 'manual_running' : 'running', r['scope'], r['target_id']],
    );
    return AnalysisWork(
      r['scope'] as String,
      r['target_id'] as String,
      r['source_version'] as int,
      r['closing'] == 1,
      r['attempts'] as int,
      manual,
    );
  });
  @override
  Future<AnalysisInput> input(AnalysisWork w) async {
    if (w.scope == 'memory') {
      final payload = await records.rows(
        'SELECT data,timestamp FROM assistant_session_records WHERE session_id=? AND sequence=?',
        _memorySource(w.id),
      );
      return AnalysisInput({
        'source': w.id,
        'sourceTimeZone': 'Asia/Shanghai',
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
    if (w.scope == 'record') {
      final r = (await records.rows('SELECT * FROM records WHERE id=?', [
        w.id,
      ])).single;
      final body = r['content'] as String?;
      if (body != null && body.length > 8000) {
        r['content'] = body.substring(0, 8000);
        r['contentTruncated'] = true;
      }
      return AnalysisInput(
        r,
        const [],
        imageKey: r['type'] == 'IMAGE'
            ? r['attachment_storage_key'] as String?
            : null,
        mime: r['attachment_mime_type'] as String?,
      );
    }
    if (w.scope == 'mission') {
      final d = (await DriftMissionRepository(db).findDetail(w.id))!;
      final materials = await records.rows(
        'SELECT r.id,e.id evidenceId,e.submitted_at submittedAt,e.supersedes_evidence_id supersedesId FROM records r JOIN evidence_records e ON e.record_id=r.id WHERE e.mission_id=? AND NOT EXISTS(SELECT 1 FROM evidence_records n WHERE n.supersedes_evidence_id=e.id) ORDER BY e.submitted_at,e.id',
        [w.id],
      );
      final items = <Map<String, Object?>>[];
      for (final r in materials) {
        items.add({
          ...await child('record', r['id'] as String),
          'evidenceId': r['evidenceId'],
          'submittedAt': r['submittedAt'],
          'supersedesId': r['supersedesId'],
        });
      }
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
      return AnalysisInput({
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
                'start': d.effectiveUserReport!.actualStart?.toIso8601String(),
                'end': d.effectiveUserReport!.actualEnd?.toIso8601String(),
                'basis': d.effectiveUserReport!.basis,
              },
        'materialCount': d.effectiveEvidence.length,
      }, items);
    }
    final node = w.scope == 'node';
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
      "SELECT m.id FROM missions m WHERE $scope AND (EXISTS(SELECT 1 FROM execution_events e WHERE e.mission_id=m.id AND e.type='END') OR EXISTS(SELECT 1 FROM evidence_records e WHERE e.mission_id=m.id) OR EXISTS(SELECT 1 FROM analysis_versions v WHERE v.scope='mission' AND v.target_id=m.id))",
      [w.id],
    );
    facts['directMissionCount'] = allMissionCount;
    facts['missionsWithoutReviewFacts'] = allMissionCount - meaningful.length;
    final directRecords = await records.rows(
      'SELECT r.id FROM records r WHERE ${node ? 'r.goal_node_id=?' : 'r.goal_id=? AND r.goal_node_id IS NULL'} AND NOT EXISTS(SELECT 1 FROM evidence_records e WHERE e.record_id=r.id)',
      [w.id],
    );
    final nodes = await records.rows(
      node
          ? 'SELECT id FROM goal_nodes WHERE parent_node_id=?'
          : 'SELECT id FROM goal_nodes WHERE goal_id=? AND parent_node_id IS NULL',
      [w.id],
    );
    final items = <Map<String, Object?>>[];
    for (final group in [
      (meaningful, 'mission'),
      (directRecords, 'record'),
      (nodes, 'node'),
    ]) {
      for (final r in group.$1) {
        items.add(await child(group.$2, r['id'] as String));
      }
    }
    return AnalysisInput(facts, items);
  }

  String _userText(String encoded) {
    final message = (jsonDecode(encoded) as Map)['message'] as Map;
    if (message['role'] != 'user') throw const FormatException('记忆来源不是用户陈述');
    final text = (message['content'] as List)
        .whereType<Map>()
        .where((b) => b['type'] == 'text')
        .map((b) => b['text'])
        .join()
        .split('MissionBook 文本附件')
        .first;
    return text.length > 8000 ? text.substring(0, 8000) : text;
  }

  Future<Map<String, Object?>> child(String scope, String id) async {
    final summary = await records.analysis(scope, id);
    final index = switch (scope) {
      'record' => await records.rows(
        'SELECT id,type,substr(content,1,300) caption,occurred_at FROM records WHERE id=?',
        [id],
      ),
      'mission' => await records.rows(
        "SELECT m.id,m.title,(SELECT user_reported_result FROM execution_events e WHERE e.mission_id=m.id AND e.type='END') userReportedResult,(SELECT COUNT(*) FROM evidence_records e WHERE e.mission_id=m.id AND NOT EXISTS(SELECT 1 FROM evidence_records n WHERE n.supersedes_evidence_id=e.id)) materialCount FROM missions m WHERE m.id=?",
        [id],
      ),
      'node' => await records.rows(
        'SELECT id,title,archived_at FROM goal_nodes WHERE id=?',
        [id],
      ),
      _ => <Map<String, Object?>>[],
    };
    return {
      'id': id,
      'scope': scope,
      'version': summary['source_version'],
      if (index.isNotEmpty) 'facts': index.single,
      ...summary,
    };
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
      [w.scope, w.id],
    );
    if (rows.single['source_version'] != w.version ||
        rows.single['status'] != (w.manual ? 'manual_running' : 'running')) {
      return false;
    }
    await db
        .into(db.analysisVersions)
        .insert(
          AnalysisVersionsCompanion.insert(
            id: const Uuid().v4(),
            scope: w.scope,
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
      [w.scope, w.id],
    );
    await parents(w.scope, w.id);
    return true;
  });
  Future<void> parents(String scope, String id) async {
    List<Map<String, Object?>> targets = [];
    if (scope == 'record') {
      targets = await records.rows(
        "SELECT 'mission' scope,mission_id id FROM evidence_records WHERE record_id=? UNION SELECT 'node',goal_node_id FROM records WHERE id=? AND goal_node_id IS NOT NULL UNION SELECT 'goal',goal_id FROM records WHERE id=? AND goal_id IS NOT NULL",
        [id, id, id],
      );
    } else if (scope == 'mission') {
      targets = await records.rows(
        "SELECT 'node' scope,goal_node_id id FROM missions WHERE id=? AND goal_node_id IS NOT NULL UNION SELECT 'goal',goal_id FROM missions WHERE id=? AND goal_id IS NOT NULL",
        [id, id],
      );
    } else if (scope == 'node') {
      targets = await records.rows(
        "SELECT 'node' scope,parent_node_id id FROM goal_nodes WHERE id=? AND parent_node_id IS NOT NULL UNION SELECT 'goal',goal_id FROM goal_nodes WHERE id=?",
        [id, id],
      );
    }
    for (final t in targets) {
      await retry(t['scope'] as String, t['id'] as String, manual: false);
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
        w.scope,
        w.id,
        w.version,
        w.manual ? 'manual_running' : 'running',
      ],
    );
  }

  @override
  Future<void> retry(
    String scope,
    String id, {
    bool closing = false,
    bool manual = true,
    String? operationId,
  }) => records.command(
    operationId,
    'analysis_retry',
    id,
    {'scope': scope, 'closing': closing},
    {'queued': true},
    () => _retry(scope, id, closing: closing, manual: manual),
  );
  Future<void> _retry(
    String scope,
    String id, {
    bool closing = false,
    bool manual = true,
  }) async {
    if (!['record', 'mission', 'node', 'goal', 'memory'].contains(scope)) {
      throw ArgumentError('分析对象类型无效');
    }
    await db.customStatement(
      "INSERT INTO analysis_jobs(scope,target_id,source_version,status,attempts,available_at,closing) VALUES(?,?,1,?,0,0,?) ON CONFLICT(scope,target_id) DO UPDATE SET source_version=source_version+1,status=excluded.status,attempts=0,available_at=0,error=NULL,closing=MAX(closing,excluded.closing)",
      [scope, id, manual ? 'manual_pending' : 'pending', closing ? 1 : 0],
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
        [w.scope, w.id],
      );
      if (current.single['source_version'] != w.version) return;
      for (final raw in entries.take(5)) {
        final e = Map<String, Object?>.from(raw as Map);
        final quote = e['quote'] as String?;
        if (e['certainty'] == 'stated' &&
            (quote == null || quote.isEmpty || !userText.contains(quote))) {
          e['certainty'] = 'unverified';
        }
        final key = e['conflictKey'] as String? ?? e['content'] as String;
        e['id'] = const Uuid().v5(Namespace.url.value, 'memory:${w.id}:$key');
        e['source'] = 'conversation:${w.id}';
        if (e['expiresAt'] is! int) e['expiresAt'] = null;
        await records.saveMemory(e);
      }
    });
  }
}

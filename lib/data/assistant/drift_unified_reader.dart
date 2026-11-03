import '../../domain/entities/mission_phase.dart';
import '../repositories/drift_repository_support.dart';
import 'dart:convert';
import '../../domain/entities/analysis_scope.dart';
import 'package:timezone/timezone.dart' as tz;
import '../../domain/entities/mission_schedule_revision.dart';
import '../../domain/rules/mission_attention_rules.dart';
import '../../application/assistant/unified_reader.dart';
import '../../application/missions/mission_projection.dart';
import '../local/app_database.dart';
import '../repositories/drift_record_repository.dart';
import '../repositories/drift_mission_repository.dart';
import 'drift_assistant_reader.dart';

/// 分层查询共用轻量索引，任务详情复用完整领域事实；正文与图片按需读取。
class DriftUnifiedReader implements UnifiedReader {
  DriftUnifiedReader(this.db)
    : recordRepository = DriftRecordRepository(db),
      taskReader = DriftAssistantReader(db);
  final AppDatabase db;
  final DriftRecordRepository recordRepository;
  final DriftAssistantReader taskReader;
  @override
  Future<Map<String, Object?>> records(
    String missionId,
    String section, {
    int offset = 0,
  }) async {
    if (section != 'revoked') {
      return taskReader.records(missionId, section, offset: offset);
    }
    if (offset < 0) throw ArgumentError('分页位置无效');
    final archives = await DriftMissionRepository(
      db,
    ).executionArchives(missionId);
    final items = <Map<String, Object?>>[];
    for (final archive in archives) {
      for (final table in [
        'execution_events',
        'user_execution_reports',
        'failure_records',
        'evidence_records',
      ]) {
        for (final raw in archive[table] as List) {
          final item = Map<String, Object?>.from(raw as Map);
          for (final field in ['content', 'basis', 'user_reason_text']) {
            final value = item[field];
            if (value is String && value.length > 500) {
              item[field] = value.substring(0, 500);
            }
          }
          item.remove('attachment_storage_key');
          items.add({
            'kind': table,
            'archivedAt': archive['archivedAt'],
            ...item,
          });
        }
      }
    }
    return {
      ...DriftRepositorySupport.page(
        items.skip(offset).take(20).toList(),
        items.length,
        offset,
      ),
      'hint': '这些事实已被用户撤销，仅作历史追溯，不参与当前阶段与计时。',
    };
  }

  @override
  Future<Map<String, Object?>> evidenceContent(
    String evidenceId, {
    int offset = 0,
  }) async {
    final current = await taskReader.evidenceContent(
      evidenceId,
      offset: offset,
    );
    if (current['ok'] != false) return current;
    final found = await recordRepository.rows(
      "SELECT e.value payload FROM operation_receipts r, json_each(r.result_json,'\$.evidence_records') e WHERE r.kind='missionExecutionArchive' AND json_extract(e.value,'\$.id')=? LIMIT 1",
      [evidenceId],
    );
    if (found.isEmpty) return current;
    final material = jsonDecode(found.single['payload'] as String) as Map;
    final content = (material['content'] as String? ?? '').runes.toList();
    final text = String.fromCharCodes(content.skip(offset).take(2000));
    final next = offset + text.runes.length;
    return {
      'ok': true,
      'evidenceId': evidenceId,
      'missionId': material['mission_id'],
      'type': material['type'],
      'source': material['source'],
      'text': text,
      'offset': offset,
      'totalCharacters': content.length,
      'hasMore': next < content.length,
      'nextOffset': next < content.length ? next : null,
      'revoked': true,
      'hint': '已撤销的历史材料，不参与当前阶段或评价；图片/文件的空正文不表示附件为空。',
    };
  }

  @override
  Future<Map<String, Object?>> content(
    String missionId,
    String field, {
    int offset = 0,
  }) => taskReader.content(missionId, field, offset: offset);

  Future<Map<String, Object?>> resolve(
    String table,
    String key, {
    String? goalId,
  }) async {
    final exact = await recordRepository.rows(
      'SELECT id,title FROM $table WHERE id=? ${goalId == null ? '' : 'AND goal_id=?'}',
      [key, ?goalId],
    );
    if (exact.isNotEmpty) return {'id': exact.single['id']};
    final found = await recordRepository.rows(
      'SELECT id,title FROM $table WHERE (id=? OR title=?) ${goalId == null ? '' : 'AND goal_id=?'} ORDER BY id LIMIT 21',
      [key, key, ?goalId],
    );
    if (found.length != 1) {
      return {
        'state': found.isEmpty ? 'not_found' : 'ambiguous',
        'candidates': found.take(20).toList(),
        'truncated': found.length > 20,
      };
    }
    return {'id': found.single['id']};
  }

  @override
  Future<Map<String, Object?>> getGoal({
    String? goal,
    String? node,
    String? mission,
    int offset = 0,
  }) => db.transaction(
    () => _getGoal(goal: goal, node: node, mission: mission, offset: offset),
  );
  Future<Map<String, Object?>> _getGoal({
    String? goal,
    String? node,
    String? mission,
    int offset = 0,
  }) async {
    if (offset < 0) throw ArgumentError('分页位置无效');
    if (goal == null) {
      if (node != null || mission != null) throw ArgumentError('查询节点或任务时先指定目标');
      final total =
          (await recordRepository.rows(
                'SELECT COUNT(*) n FROM goals',
              )).single['n']
              as int;
      final items = await recordRepository.rows(
        '''SELECT g.id,substr(g.title,1,200) title,length(g.title) titleLength,g.status,g.created_at AS createdAt,substr(g.why,1,300) why,length(g.why) whyLength,g.desire_level AS desireLevel,
        (SELECT COUNT(*) FROM goal_nodes n WHERE n.goal_id=g.id) nodeCount,
        (SELECT COUNT(*) FROM missions m WHERE m.goal_id=g.id) missionCount,
        (SELECT COUNT(*) FROM missions m JOIN execution_events e ON e.mission_id=m.id AND e.type='END' AND e.user_reported_result='COMPLETED' WHERE m.goal_id=g.id) completedMissionCount
        FROM goals g ORDER BY g.created_at DESC,g.id LIMIT 20 OFFSET ?''',
        [offset],
      );
      for (final item in items) {
        item['analysis'] = await recordRepository.analysis(
          AnalysisScope.goal,
          item['id'] as String,
        );
      }
      return DriftRepositorySupport.page(items, total, offset);
    }
    final resolved = await resolve('goals', goal);
    if (resolved['id'] == null) return resolved;
    final goalId = resolved['id'] as String;
    String? nodeId;
    if (node != null) {
      final r = await resolve('goal_nodes', node, goalId: goalId);
      if (r['id'] == null) return r;
      nodeId = r['id'] as String;
    }
    if (mission != null && mission != '*') {
      final r = await resolve('missions', mission, goalId: goalId);
      if (r['id'] == null) return r;
      final d = (await DriftMissionRepository(
        db,
      ).findDetail(r['id'] as String))!;
      if (nodeId != null) {
        final membership = await recordRepository.rows(
          'WITH RECURSIVE subtree(id) AS (SELECT ? UNION ALL SELECT n.id FROM goal_nodes n JOIN subtree p ON n.parent_node_id=p.id) SELECT id FROM subtree WHERE id=?',
          [nodeId, d.mission.goalNodeId],
        );
        if (membership.isEmpty) return {'state': 'outside_node'};
      }
      return getMission(mission: r['id'] as String);
    }
    final root = (await recordRepository.rows(
      'SELECT id,substr(title,1,200) title,status,created_at AS createdAt,substr(why,1,300) why,length(why) whyLength,desire_level AS desireLevel FROM goals WHERE id=?',
      [goalId],
    )).single;
    final prefix = nodeId == null
        ? ''
        : 'WITH RECURSIVE subtree(id) AS (SELECT ? UNION ALL SELECT n.id FROM goal_nodes n JOIN subtree p ON n.parent_node_id=p.id) ';
    final args = <Object?>[?nodeId, goalId];
    if (mission == '*') {
      final condition =
          'goal_id=? ${nodeId == null ? '' : 'AND goal_node_id IN (SELECT id FROM subtree)'}';
      final count =
          (await recordRepository.rows(
                '${prefix}SELECT COUNT(*) n FROM missions WHERE $condition',
                args,
              )).single['n']
              as int;
      final items = await recordRepository.rows(
        '''${prefix}SELECT m.id,m.title,m.created_at AS createdAt,
        (SELECT scheduled_date FROM mission_schedule_revisions r WHERE r.mission_id=m.id ORDER BY revision_number DESC LIMIT 1) scheduledDate,
        (SELECT user_reported_result FROM execution_events e WHERE e.mission_id=m.id AND e.type='END') userReportedResult
        FROM missions m WHERE $condition ORDER BY m.created_at,m.id LIMIT 20 OFFSET ?''',
        [...args, offset],
      );
      for (final item in items) {
        final d = await DriftMissionRepository(
          db,
        ).findDetail(item['id'] as String);
        if (d != null) item.addAll(missionProjection(d, DateTime.now()));
        item['analysis'] = await recordRepository.analysis(
          AnalysisScope.mission,
          item['id'] as String,
        );
      }
      return {
        'goal': root,
        'nodeId': nodeId,
        ...DriftRepositorySupport.page(items, count, offset),
      };
    }
    final condition =
        'goal_id=? ${nodeId == null ? '' : 'AND id IN (SELECT id FROM subtree)'}';
    final total =
        (await recordRepository.rows(
              '${prefix}SELECT COUNT(*) n FROM goal_nodes WHERE $condition',
              args,
            )).single['n']
            as int;
    final nodes = await recordRepository.rows(
      '${prefix}SELECT id,title,parent_node_id AS parentNodeId,order_index AS orderIndex,archived_at AS archivedAt,created_at AS createdAt FROM goal_nodes WHERE $condition ORDER BY order_index,id LIMIT 20 OFFSET ?',
      [...args, offset],
    );
    for (final n in nodes) {
      n['analysis'] = await recordRepository.analysis(
        AnalysisScope.node,
        n['id'] as String,
      );
    }
    return {
      'goal': root,
      'analysis': await recordRepository.analysis(
        nodeId == null ? AnalysisScope.goal : AnalysisScope.node,
        nodeId ?? goalId,
      ),
      'nodeId': nodeId,
      'nodes': DriftRepositorySupport.page(nodes, total, offset),
      'missions':
          nodeId == null
                ? await enhance(
                    await taskReader.missions(goalId: goalId, offset: offset),
                  )
                : (await getGoal(
                    goal: goalId,
                    node: nodeId,
                    mission: '*',
                    offset: offset,
                  ))
            ..remove('goal'),
      'hint': '任务索引不含原图和正文；mission=*分页查询当前范围任务评价，指定稳定ID读取单任务',
    };
  }

  @override
  Future<Map<String, Object?>> getMission({
    String? mission,
    String? search,
    String? goalId,
    String? nodeId,
    String? date,
    String? beforeDate,
    String? phase,
    bool summaryOnly = false,
    int offset = 0,
  }) => db.transaction(
    () => _getMission(
      mission: mission,
      search: search,
      goalId: goalId,
      nodeId: nodeId,
      date: date,
      beforeDate: beforeDate,
      phase: phase,
      summaryOnly: summaryOnly,
      offset: offset,
    ),
  );
  Future<Map<String, Object?>> _getMission({
    String? mission,
    String? search,
    String? goalId,
    String? nodeId,
    String? date,
    String? beforeDate,
    String? phase,
    bool summaryOnly = false,
    int offset = 0,
  }) async {
    if (offset < 0) throw ArgumentError('分页位置不能为负数');
    if (summaryOnly && offset != 0) {
      throw ArgumentError('summaryOnly 返回完整范围统计，不接受 offset');
    }
    if (date != null) validateScheduledDate(date);
    if (beforeDate != null) validateScheduledDate(beforeDate);
    if (phase != null && !MissionPhase.values.any((p) => p.name == phase)) {
      throw ArgumentError('任务阶段无效');
    }
    if (mission == null &&
        (date != null || beforeDate != null || phase != null || summaryOnly)) {
      final all = await DriftMissionRepository(db).findAllDetails();
      final selected =
          all
              .where(
                (d) =>
                    (search == null || d.mission.title.contains(search)) &&
                    (goalId == null || d.mission.goalId == goalId) &&
                    (nodeId == null || d.mission.goalNodeId == nodeId) &&
                    (date == null || d.schedule.scheduledDate == date) &&
                    (beforeDate == null ||
                        d.schedule.scheduledDate.compareTo(beforeDate) < 0) &&
                    (phase == null || d.phase.name == phase),
              )
              .toList()
            ..sort(
              (a, b) => '${a.schedule.scheduledDate}:${a.mission.id}'.compareTo(
                '${b.schedule.scheduledDate}:${b.mission.id}',
              ),
            );
      final counts = <String, int>{};
      for (final d in selected) {
        counts.update(d.phase.name, (v) => v + 1, ifAbsent: () => 1);
      }
      final items = summaryOnly
          ? <Map<String, Object?>>[]
          : [
              for (final d in selected.skip(offset).take(20))
                <String, Object?>{
                  'id': d.mission.id,
                  'title': d.mission.title,
                  'phase': d.phase.name,
                  'scheduledDate': d.schedule.scheduledDate,
                  'goalId': d.mission.goalId,
                },
            ];
      final next = offset + items.length;
      return {
        'total': selected.length,
        'countsByPhase': counts,
        'summaryComplete': true,
        'items': items,
        'offset': offset,
        'nextOffset': !summaryOnly && next < selected.length ? next : null,
        'truncated': !summaryOnly && next < selected.length,
        'hint': 'total 和 countsByPhase 覆盖完整筛选范围，items 仅为本页；阶段由完整任务事实派生。',
      };
    }
    if (mission == null) {
      return enhance(
        await taskReader.missions(
          search: search,
          goalId: goalId,
          nodeId: nodeId,
          offset: offset,
        ),
      );
    }
    final r = await resolve('missions', mission, goalId: goalId);
    if (r['id'] == null) return r;
    final d = (await DriftMissionRepository(db).findDetail(r['id'] as String))!;
    return {
      ...missionProjection(d, DateTime.now().toUtc()),
      'analysis': await recordRepository.analysis(
        AnalysisScope.mission,
        d.mission.id,
      ),
      'execution': await taskReader.records(
        d.mission.id,
        'execution',
        offset: offset,
      ),
      'failures': await taskReader.records(
        d.mission.id,
        'failures',
        offset: offset,
      ),
      'materialIndex': await taskReader.records(
        d.mission.id,
        'evidence',
        offset: offset,
      ),
    };
  }

  Future<Map<String, Object?>> enhance(Map<String, Object?> page) async {
    final list = page['items'] as List;
    for (final raw in list) {
      final item = raw as Map<String, Object?>;
      final d = await DriftMissionRepository(
        db,
      ).findDetail(item['id'] as String);
      if (d != null) {
        item['phase'] = d.phase.name;
        item['attention'] = missionAttention(
          d.phase,
          d.schedule,
          DateTime.now(),
        ).name;
        item['effectiveOccurrenceDate'] = d.effectiveOccurrenceDate;
        item['userReportedCompleted'] = d.endReportedCompleted;
      }
    }
    page['phaseIncluded'] = true;
    page['truncated'] = page['nextOffset'] != null;
    return page;
  }

  String _today() {
    final d = tz.TZDateTime.from(
      DateTime.now(),
      tz.getLocation(defaultScheduleTimeZone),
    );
    return '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  @override
  Future<Map<String, Object?>> getSchedule({
    String? date,
    int offset = 0,
  }) async => enhance(
    await taskReader.missions(date: date ?? _today(), offset: offset),
  );
}

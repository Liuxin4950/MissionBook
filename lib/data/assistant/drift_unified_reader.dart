import 'package:timezone/timezone.dart' as tz;
import '../../domain/rules/mission_attention_rules.dart';
import '../../application/assistant/unified_reader.dart';
import '../../domain/rules/mission_projection.dart';
import '../local/app_database.dart';
import '../repositories/drift_record_repository.dart';
import '../repositories/drift_mission_repository.dart';
import 'drift_assistant_reader.dart';

/// 分层查询共用轻量索引，任务详情复用完整领域事实；正文与图片按需读取。
class DriftUnifiedReader implements UnifiedReader {
  DriftUnifiedReader(this.db)
    : records = DriftRecordRepository(db),
      legacy = DriftAssistantReader(db);
  final AppDatabase db;
  final DriftRecordRepository records;
  final DriftAssistantReader legacy;
  Future<Map<String, Object?>> resolve(
    String table,
    String key, {
    String? goalId,
  }) async {
    final exact = await records.rows(
      'SELECT id,title FROM $table WHERE id=? ${goalId == null ? '' : 'AND goal_id=?'}',
      [key, ?goalId],
    );
    if (exact.isNotEmpty) return {'id': exact.single['id']};
    final found = await records.rows(
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
          (await records.rows('SELECT COUNT(*) n FROM goals')).single['n']
              as int;
      final items = await records.rows(
        '''SELECT g.id,substr(g.title,1,200) title,length(g.title) titleLength,g.status,g.created_at,substr(g.why,1,300) why,length(g.why) whyLength,g.desire_level,
        (SELECT COUNT(*) FROM goal_nodes n WHERE n.goal_id=g.id) nodeCount,
        (SELECT COUNT(*) FROM missions m WHERE m.goal_id=g.id) missionCount,
        (SELECT COUNT(*) FROM missions m JOIN execution_events e ON e.mission_id=m.id AND e.type='END' AND e.user_reported_result='COMPLETED' WHERE m.goal_id=g.id) completedMissionCount
        FROM goals g ORDER BY g.created_at DESC,g.id LIMIT 20 OFFSET ?''',
        [offset],
      );
      for (final item in items) {
        item['analysis'] = await records.analysis('goal', item['id'] as String);
      }
      return DriftRecordRepository.page(items, total, offset);
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
        final membership = await records.rows(
          'WITH RECURSIVE subtree(id) AS (SELECT ? UNION ALL SELECT n.id FROM goal_nodes n JOIN subtree p ON n.parent_node_id=p.id) SELECT id FROM subtree WHERE id=?',
          [nodeId, d.mission.goalNodeId],
        );
        if (membership.isEmpty) return {'state': 'outside_node'};
      }
      return getMission(mission: r['id'] as String);
    }
    final root = (await records.rows(
      'SELECT id,substr(title,1,200) title,status,created_at,substr(why,1,300) why,length(why) whyLength,desire_level FROM goals WHERE id=?',
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
          (await records.rows(
                '${prefix}SELECT COUNT(*) n FROM missions WHERE $condition',
                args,
              )).single['n']
              as int;
      final items = await records.rows(
        '''${prefix}SELECT m.id,m.title,m.created_at,
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
        item['analysis'] = await records.analysis(
          'mission',
          item['id'] as String,
        );
      }
      return {
        'goal': root,
        'nodeId': nodeId,
        ...DriftRecordRepository.page(items, count, offset),
      };
    }
    final condition =
        'goal_id=? ${nodeId == null ? '' : 'AND id IN (SELECT id FROM subtree)'}';
    final total =
        (await records.rows(
              '${prefix}SELECT COUNT(*) n FROM goal_nodes WHERE $condition',
              args,
            )).single['n']
            as int;
    final nodes = await records.rows(
      '${prefix}SELECT id,title,parent_node_id,order_index,archived_at,created_at FROM goal_nodes WHERE $condition ORDER BY order_index,id LIMIT 20 OFFSET ?',
      [...args, offset],
    );
    for (final n in nodes) {
      n['analysis'] = await records.analysis('node', n['id'] as String);
    }
    return {
      'goal': root,
      'analysis': await records.analysis(
        nodeId == null ? 'goal' : 'node',
        nodeId ?? goalId,
      ),
      'nodeId': nodeId,
      'nodes': DriftRecordRepository.page(nodes, total, offset),
      'missions':
          nodeId == null
                ? await enhance(
                    await legacy.missions(goalId: goalId, offset: offset),
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
    int offset = 0,
  }) => db.transaction(
    () => _getMission(
      mission: mission,
      search: search,
      goalId: goalId,
      nodeId: nodeId,
      offset: offset,
    ),
  );
  Future<Map<String, Object?>> _getMission({
    String? mission,
    String? search,
    String? goalId,
    String? nodeId,
    int offset = 0,
  }) async {
    if (mission == null) {
      return enhance(
        await legacy.missions(
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
      'analysis': await records.analysis('mission', d.mission.id),
      'execution': await legacy.records(
        d.mission.id,
        'execution',
        offset: offset,
      ),
      'failures': await legacy.records(
        d.mission.id,
        'failures',
        offset: offset,
      ),
      'materialIndex': await legacy.records(
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
      tz.getLocation('Asia/Shanghai'),
    );
    return '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  @override
  Future<Map<String, Object?>> getSchedule({
    String? date,
    int offset = 0,
  }) async =>
      enhance(await legacy.missions(date: date ?? _today(), offset: offset));
}

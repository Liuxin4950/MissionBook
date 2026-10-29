import 'package:drift/drift.dart';

import '../../application/assistant/assistant_reader.dart';
import '../local/app_database.dart';

/// 所有 LIMIT / substr 在 SQLite 执行，避免先装载全目标再在 Dart 截断。
class DriftAssistantReader implements AssistantReader {
  DriftAssistantReader(this.database);
  final AppDatabase database;
  static const pageSize = 20;
  static const chunkSize = 2000;

  @override
  Future<Map<String, Object?>> missions({
    String? date,
    String? goalId,
    String? nodeId,
    String? search,
    int offset = 0,
  }) async {
    _checkOffset(offset);
    final conditions = <String>[];
    final variables = <Variable>[];
    for (final filter in [
      (date, 's.scheduled_date'),
      (goalId, 'm.goal_id'),
      (nodeId, 'm.goal_node_id'),
    ]) {
      if (filter.$1 != null) {
        conditions.add('${filter.$2} = ?');
        variables.add(Variable<String>(filter.$1!));
      }
    }
    if (search != null && search.isNotEmpty) {
      conditions.add('instr(m.title, ?) > 0');
      variables.add(Variable<String>(search));
    }
    final where = conditions.isEmpty ? '' : 'WHERE ${conditions.join(' AND ')}';
    const join =
        '''FROM missions m JOIN mission_schedule_revisions s ON s.mission_id = m.id
      AND s.revision_number = (SELECT MAX(r.revision_number) FROM mission_schedule_revisions r WHERE r.mission_id = m.id)''';
    return database.transaction(() async {
      final total =
          (await database
                  .customSelect(
                    'SELECT COUNT(*) AS total $join $where',
                    variables: variables,
                  )
                  .getSingle())
              .read<int>('total');
      final rows = await database
          .customSelect(
            '''SELECT m.id, substr(m.title, 1, 120) AS title,
        m.goal_id AS goalId, m.goal_node_id AS nodeId, m.updated_at AS updatedAt,
        m.cancelled_at AS cancelledAt, s.scheduled_date AS scheduledDate, s.time_zone AS timeZone,
        s.planned_duration_minutes AS plannedMinutes, s.time_policy AS timePolicy,
        s.id AS scheduleRevisionId, s.fixed_start_at AS fixedStartAt
        $join $where ORDER BY s.scheduled_date, m.id LIMIT $pageSize OFFSET ?''',
            variables: [...variables, Variable<int>(offset)],
          )
          .get();
      return {
        ..._page(total, offset, rows.map((row) => row.data).toList()),
        'scope': 'candidate_index',
        'phaseIncluded': false,
        'hint': '索引未读取方案、材料和完整阶段；需要时用 mission_query / mission_content。',
        'references': [
          for (final row in rows)
            {
              'type': 'mission',
              'id': row.read<String>('id'),
              'title': row.read<String>('title'),
            },
        ],
      };
    });
  }

  @override
  Future<Map<String, Object?>> goals({int offset = 0}) async {
    _checkOffset(offset);
    return database.transaction(() async {
      final total =
          (await database
                  .customSelect(
                    "SELECT COUNT(*) AS total FROM goals WHERE status != 'DROPPED'",
                  )
                  .getSingle())
              .read<int>('total');
      final rows = await database
          .customSelect(
            "SELECT id, substr(title, 1, 120) AS title, status FROM goals WHERE status != 'DROPPED' ORDER BY id LIMIT $pageSize OFFSET ?",
            variables: [Variable<int>(offset)],
          )
          .get();
      return {
        ..._page(total, offset, rows.map((row) => row.data).toList()),
        'references': [
          for (final row in rows)
            {
              'type': 'goal',
              'id': row.read<String>('id'),
              'title': row.read<String>('title'),
            },
        ],
      };
    });
  }

  @override
  Future<Map<String, Object?>> goal(String id, {int offset = 0}) async {
    _checkOffset(offset);
    return database.transaction(() async {
      final record = await database
          .customSelect(
            '''SELECT id, substr(title,1,120) AS title, status,
        substr(description,1,1000) AS description, length(description) AS descriptionLength,
        substr(why,1,500) AS why, length(why) AS whyLength, updated_at AS updatedAt FROM goals WHERE id = ?''',
            variables: [Variable<String>(id)],
          )
          .getSingleOrNull();
      if (record == null) {
        return {'ok': false, 'code': 'not_found', 'message': '目标不存在'};
      }
      final total =
          (await database
                  .customSelect(
                    'SELECT COUNT(*) AS total FROM goal_nodes WHERE goal_id = ?',
                    variables: [Variable<String>(id)],
                  )
                  .getSingle())
              .read<int>('total');
      final nodes = await database
          .customSelect(
            '''SELECT id, parent_node_id AS parentNodeId,
        substr(title,1,120) AS title, substr(description,1,300) AS description,
        length(description) AS descriptionLength, archived_at AS archivedAt, order_index AS orderIndex
        FROM goal_nodes WHERE goal_id = ? ORDER BY parent_node_id, order_index, id LIMIT $pageSize OFFSET ?''',
            variables: [Variable<String>(id), Variable<int>(offset)],
          )
          .get();
      final count =
          (await database
                  .customSelect(
                    'SELECT COUNT(*) AS total FROM missions WHERE goal_id = ?',
                    variables: [Variable<String>(id)],
                  )
                  .getSingle())
              .read<int>('total');
      return {
        'ok': true,
        'goal': record.data,
        'missionCount': count,
        'nodes': _page(total, offset, nodes.map((row) => row.data).toList()),
        'hint': '任务不随目标返回，用 mission_search 按 goalId/nodeId 检索。较长文字明确按长度截断。',
      };
    });
  }

  @override
  Future<Map<String, Object?>> records(
    String missionId,
    String section, {
    int offset = 0,
  }) async {
    _checkOffset(offset);
    final (table, columns, order) = switch (section) {
      'execution' => (
        'execution_events',
        'id, sequence, type, occurred_at AS occurredAt, schedule_revision_id AS scheduleRevisionId, granted_duration_minutes AS grantedMinutes, substr(reason,1,500) AS reason, length(reason) AS reasonLength, user_reported_result AS userReportedResult, submit_optional_evidence AS submitOptionalEvidence',
        'sequence',
      ),
      'failures' => (
        'failure_records',
        'id, trigger, occurred_at AS occurredAt, user_reason_category AS userReasonCategory, substr(user_reason_text,1,1000) AS userReasonText, length(user_reason_text) AS reasonLength',
        'occurred_at, id',
      ),
      'evidence' => (
        'evidence_records',
        'id, type, source, substr(content,1,500) AS contentPreview, length(content) AS contentLength, attachment_file_name AS attachmentFileName, attachment_mime_type AS attachmentMimeType, submitted_at AS submittedAt, supersedes_evidence_id AS supersedesEvidenceId, NOT EXISTS(SELECT 1 FROM evidence_records n WHERE n.supersedes_evidence_id = evidence_records.id) AS isCurrent',
        'submitted_at, id',
      ),
      _ => throw ArgumentError('不支持的记录范围'),
    };
    return database.transaction(() async {
      final exists = await database
          .customSelect(
            'SELECT id FROM missions WHERE id = ?',
            variables: [Variable<String>(missionId)],
          )
          .getSingleOrNull();
      if (exists == null) {
        return {'ok': false, 'code': 'not_found', 'message': '任务不存在'};
      }
      final count =
          (await database
                  .customSelect(
                    'SELECT COUNT(*) AS total FROM $table WHERE mission_id = ?',
                    variables: [Variable<String>(missionId)],
                  )
                  .getSingle())
              .read<int>('total');
      final rows = await database
          .customSelect(
            'SELECT $columns FROM $table WHERE mission_id = ? ORDER BY $order LIMIT $pageSize OFFSET ?',
            variables: [Variable<String>(missionId), Variable<int>(offset)],
          )
          .get();
      return {
        ..._page(
          count,
          offset,
          rows
              .map(
                (row) => <String, Object?>{
                  ...row.data,
                  if (section == 'evidence')
                    'isCurrent': row.read<int>('isCurrent') == 1,
                },
              )
              .toList(),
        ),
        'missionId': missionId,
        'section': section,
        'source': 'saved_app_facts',
        'hint':
            '用户报告、提交材料和规则阶段分别表达，不等于AI评价或掌握。预览可能截断；材料正文用 evidence_content 继续读取。修正链保留原文，最新有效材料需检查supersedesEvidenceId。',
      };
    });
  }

  @override
  Future<Map<String, Object?>> evidenceContent(
    String evidenceId, {
    int offset = 0,
  }) async {
    _checkOffset(offset);
    final row = await database
        .customSelect(
          'SELECT id, mission_id AS missionId, type, source, substr(content, ?, $chunkSize) AS text, length(content) AS total, supersedes_evidence_id AS supersedesEvidenceId FROM evidence_records WHERE id = ?',
          variables: [Variable<int>(offset + 1), Variable<String>(evidenceId)],
        )
        .getSingleOrNull();
    if (row == null) {
      return {'ok': false, 'code': 'not_found', 'message': '材料不存在'};
    }
    final text = row.readNullable<String>('text') ?? '';
    final total = row.readNullable<int>('total') ?? 0;
    final next = offset + text.runes.length;
    return {
      'ok': true,
      'evidenceId': evidenceId,
      'missionId': row.read<String>('missionId'),
      'type': row.read<String>('type'),
      'source': row.read<String>('source'),
      'text': text,
      'offset': offset,
      'totalCharacters': total,
      'hasMore': next < total,
      'nextOffset': next < total ? next : null,
      'supersedesEvidenceId': row.readNullable<String>('supersedesEvidenceId'),
      if (row.read<String>('type') == 'IMAGE' ||
          row.read<String>('type') == 'FILE')
        'hint': '这份材料是附件，本次没有读取文件内容，不能据空文字判断附件为空。',
    };
  }

  @override
  Future<Map<String, Object?>> content(
    String missionId,
    String field, {
    int offset = 0,
  }) async {
    _checkOffset(offset);
    // 字段名仅来自这份白名单，编号与偏移始终用 SQL 变量绑定。
    final source = switch (field) {
      'objective' => ('execution_plans', 'objective', 'mission_id'),
      'steps' => ('execution_plans', 'steps', 'mission_id'),
      'notes' => ('execution_plans', 'notes', 'mission_id'),
      'description' => ('missions', 'description', 'id'),
      'why' => ('missions', 'why', 'id'),
      _ => throw ArgumentError('不支持的任务正文字段'),
    };
    final row = await database
        .customSelect(
          '''SELECT substr(${source.$2}, ?, $chunkSize) AS text,
      length(${source.$2}) AS total FROM ${source.$1} WHERE ${source.$3} = ?''',
          variables: [Variable<int>(offset + 1), Variable<String>(missionId)],
        )
        .getSingleOrNull();
    if (row == null) {
      return {'ok': false, 'code': 'not_found', 'message': '任务或方案不存在'};
    }
    final text = row.readNullable<String>('text') ?? '';
    final total = row.readNullable<int>('total') ?? 0;
    final next = offset + text.runes.length;
    return {
      'ok': true,
      'missionId': missionId,
      'field': field,
      'text': text,
      'offset': offset,
      'totalCharacters': total,
      'hasMore': next < total,
      'nextOffset': next < total ? next : null,
      if (field == 'steps') 'format': 'JSON 数组原文片段；未读取部分不能推断。',
    };
  }

  static Map<String, Object?> _page(
    int total,
    int offset,
    List<Map<String, Object?>> rows,
  ) => {
    'ok': true,
    'total': total,
    'offset': offset,
    'limit': pageSize,
    'items': rows,
    'hasMore': offset + rows.length < total,
    'nextOffset': offset + rows.length < total ? offset + rows.length : null,
  };
  static void _checkOffset(int offset) {
    if (offset < 0 || offset > 10000000) throw ArgumentError('分页偏移无效');
  }
}

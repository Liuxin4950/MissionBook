import 'package:drift/drift.dart';

/// 所有写入入口共用事务内失效规则；触发器只排待办，不调用模型。
Future<void> installAnalysisTriggers(GeneratedDatabase db) async {
  String enqueue(String scope, String target) =>
      '''
    INSERT INTO analysis_jobs(scope,target_id,source_version,status,attempts,available_at)
    SELECT '$scope',$target,1,'pending',0,0 WHERE $target IS NOT NULL
    ON CONFLICT(scope,target_id) DO UPDATE SET source_version=source_version+1,
      status='pending',attempts=0,available_at=0,error=NULL;
  ''';
  final sources = <String, (String, String)>{
    'records': ('record', 'NEW.id'),
    'evidence_records': ('mission', 'NEW.mission_id'),
    'execution_events': ('mission', 'NEW.mission_id'),
    'execution_plans': ('mission', 'NEW.mission_id'),
    'mission_schedule_revisions': ('mission', 'NEW.mission_id'),
    'failure_records': ('mission', 'NEW.mission_id'),
    'user_execution_reports': ('mission', 'NEW.mission_id'),
    'missions': ('mission', 'NEW.id'),
    'goal_nodes': ('node', 'NEW.id'),
    'goals': ('goal', 'NEW.id'),
  };
  for (final entry in sources.entries) {
    final missionId = entry.key == 'missions' ? 'NEW.id' : 'NEW.mission_id';
    final missionHasFacts = entry.value.$1 == 'mission'
        ? '''(
      EXISTS(SELECT 1 FROM execution_events e WHERE e.mission_id=$missionId AND e.type='END') OR
      EXISTS(SELECT 1 FROM evidence_records e WHERE e.mission_id=$missionId) OR
      EXISTS(SELECT 1 FROM analysis_versions v WHERE v.scope='mission' AND v.target_id=$missionId))'''
        : null;
    String? node;
    String? goal;
    if (entry.key == 'records' || entry.key == 'missions') {
      node = 'NEW.goal_node_id';
      goal = 'NEW.goal_id';
    } else if (entry.key == 'goal_nodes') {
      node = 'NEW.parent_node_id';
      goal = 'NEW.goal_id';
    } else if (entry.value.$1 == 'mission') {
      node = '(SELECT goal_node_id FROM missions WHERE id=NEW.mission_id)';
      goal = '(SELECT goal_id FROM missions WHERE id=NEW.mission_id)';
    }
    final ancestors = node == null
        ? ''
        : '''
      INSERT INTO analysis_jobs(scope,target_id,source_version,status,attempts,available_at)
      SELECT 'node',id,1,'pending',0,0 FROM (
        WITH RECURSIVE parents(id) AS (SELECT $node UNION SELECT n.parent_node_id
          FROM goal_nodes n JOIN parents p ON n.id=p.id WHERE n.parent_node_id IS NOT NULL)
        SELECT id FROM parents) WHERE id IS NOT NULL
      ON CONFLICT(scope,target_id) DO UPDATE SET source_version=source_version+1,status='pending',attempts=0,available_at=0,error=NULL;
    ''';
    for (final action in ['INSERT', 'UPDATE']) {
      await db.customStatement(
        '''CREATE TRIGGER IF NOT EXISTS analysis_${entry.key}_${action.toLowerCase()}
        AFTER $action ON ${entry.key} BEGIN
          ${enqueue(entry.value.$1, missionHasFacts == null ? entry.value.$2 : 'CASE WHEN $missionHasFacts THEN ${entry.value.$2} ELSE NULL END')}
          $ancestors
          ${goal == null ? '' : enqueue('goal', goal)}
        END''',
      );
    }
  }
  await db.customStatement(
    '''CREATE TRIGGER IF NOT EXISTS analysis_conversation_memory
    AFTER INSERT ON assistant_session_records
    WHEN NEW.type='message_added' AND
      CASE WHEN json_valid(NEW.data) THEN json_extract(NEW.data,'\$.message.role') ELSE NULL END='user'
    BEGIN INSERT OR IGNORE INTO analysis_jobs(scope,target_id,source_version,status,attempts,available_at)
      VALUES('memory',NEW.session_id || ':' || NEW.sequence,1,'pending',0,0); END''',
  );
  // 移动尚未成为材料的记录或调整任务归属，也使原归属的摘要失效。
  for (final table in ['records', 'missions']) {
    await db.customStatement(
      '''CREATE TRIGGER IF NOT EXISTS analysis_${table}_old_scope
      AFTER UPDATE ON $table
      WHEN OLD.goal_id IS NOT NEW.goal_id OR OLD.goal_node_id IS NOT NEW.goal_node_id
      BEGIN ${enqueue('node', 'OLD.goal_node_id')} ${enqueue('goal', 'OLD.goal_id')} END''',
    );
  }
  await db.customStatement(
    '''CREATE TRIGGER IF NOT EXISTS records_formal_immutable
    BEFORE UPDATE OF content,type,source,attachment_storage_key,attachment_file_name,
      attachment_mime_type,captured_at ON records
    WHEN EXISTS(SELECT 1 FROM evidence_records e WHERE e.record_id=OLD.id)
    BEGIN SELECT RAISE(ABORT,'正式材料只能追加修正'); END''',
  );
  // 任务开始前可调整归属，材料的目标/节点是任务的派生归属，必须同事务跟随。
  await db.customStatement(
    '''CREATE TRIGGER IF NOT EXISTS records_follow_mission_scope
    AFTER UPDATE OF goal_id,goal_node_id ON missions
    WHEN OLD.goal_id IS NOT NEW.goal_id OR OLD.goal_node_id IS NOT NEW.goal_node_id
    BEGIN UPDATE records SET goal_id=NEW.goal_id,goal_node_id=NEW.goal_node_id
      WHERE id IN(SELECT record_id FROM evidence_records WHERE mission_id=NEW.id); END''',
  );
  for (final action in ['INSERT', 'UPDATE']) {
    await db.customStatement(
      '''CREATE TRIGGER IF NOT EXISTS records_scope_${action.toLowerCase()}
      BEFORE $action ON records
      WHEN NEW.goal_node_id IS NOT NULL AND NOT EXISTS(
        SELECT 1 FROM goal_nodes n WHERE n.id=NEW.goal_node_id AND n.goal_id=NEW.goal_id)
      BEGIN SELECT RAISE(ABORT,'记录节点与目标不一致'); END''',
    );
  }
}

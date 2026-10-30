import 'package:drift/drift.dart';
import 'missions.dart';
import 'goals.dart';
import 'goal_nodes.dart';

/// 内容只保存在记录中；任务材料通过 recordId 引用它。
@DataClassName('RecordRow')
@TableIndex.sql(
  'CREATE INDEX records_scope ON records(goal_id, goal_node_id, occurred_at)',
)
@TableIndex.sql('CREATE INDEX records_day ON records(occurred_at,id)')
class Records extends Table {
  TextColumn get id => text()();
  TextColumn get type => text()();
  TextColumn get source => text()();
  TextColumn get content => text().nullable()();
  TextColumn get attachmentStorageKey => text().nullable().unique()();
  TextColumn get attachmentFileName => text().nullable()();
  TextColumn get attachmentMimeType => text().nullable()();
  IntColumn get capturedAt => integer().nullable()();
  IntColumn get occurredAt => integer()();
  IntColumn get createdAt => integer()();
  TextColumn get goalId => text().nullable().references(Goals, #id)();
  TextColumn get goalNodeId => text().nullable().references(GoalNodes, #id)();
  @override
  Set<Column> get primaryKey => {id};
  @override
  List<String> get customConstraints => [
    'CHECK (goal_node_id IS NULL OR goal_id IS NOT NULL)',
    "CHECK (((type IN ('TEXT','CODE','MANUAL_RECORD')) AND source='USER' AND content IS NOT NULL AND length(trim(content))>0 AND attachment_storage_key IS NULL AND attachment_file_name IS NULL AND attachment_mime_type IS NULL) OR (type='IMAGE' AND source IN ('FILE_SYSTEM','CAMERA') AND attachment_storage_key IS NOT NULL AND attachment_file_name IS NOT NULL) OR (type='FILE' AND source='FILE_SYSTEM' AND attachment_storage_key IS NOT NULL AND attachment_file_name IS NOT NULL))",
  ];
}

/// 用户对实际时间的追加声明，原执行事件不被覆盖。
@DataClassName('UserExecutionReportRow')
@TableIndex.sql(
  'CREATE INDEX user_reports_mission ON user_execution_reports(mission_id,reported_at)',
)
class UserExecutionReports extends Table {
  TextColumn get id => text()();
  TextColumn get missionId => text().references(Missions, #id)();
  TextColumn get occurrenceDate => text()(); // 用户当地 YYYY-MM-DD。
  TextColumn get timeZoneId => text()();
  IntColumn get actualStart => integer().nullable()();
  IntColumn get actualEnd => integer().nullable()();
  IntColumn get reportedAt => integer()();
  TextColumn get basis => text()();
  TextColumn get supersedesId =>
      text().nullable().unique().references(UserExecutionReports, #id)();
  @override
  Set<Column> get primaryKey => {id};
  @override
  List<String> get customConstraints => [
    'CHECK ((actual_start IS NULL AND actual_end IS NULL) OR (actual_start IS NOT NULL AND actual_end IS NOT NULL AND actual_end >= actual_start))',
    'CHECK (length(trim(basis)) > 0)',
  ];
}

/// 待办与来源版本同事务递增，迟到的模型结果不能覆盖新事实。
@DataClassName('AnalysisJobRow')
@TableIndex.sql(
  'CREATE INDEX analysis_jobs_due ON analysis_jobs(status,available_at,scope)',
)
class AnalysisJobs extends Table {
  TextColumn get scope => text()();
  TextColumn get targetId => text()();
  IntColumn get sourceVersion => integer().withDefault(const Constant(1))();
  TextColumn get status => text().withDefault(const Constant('pending'))();
  IntColumn get attempts => integer().withDefault(const Constant(0))();
  IntColumn get availableAt => integer().withDefault(const Constant(0))();
  TextColumn get error => text().nullable()();
  BoolColumn get closing => boolean().withDefault(const Constant(false))();
  @override
  Set<Column> get primaryKey => {scope, targetId};
}

@DataClassName('AnalysisVersionRow')
@TableIndex.sql(
  'CREATE INDEX analysis_versions_target ON analysis_versions(scope,target_id,created_at DESC)',
)
class AnalysisVersions extends Table {
  TextColumn get id => text()();
  TextColumn get scope => text()();
  TextColumn get targetId => text()();
  IntColumn get sourceVersion => integer()();
  TextColumn get content => text()();
  TextColumn get sourcesJson => text()();
  IntColumn get coverage => integer()();
  IntColumn get createdAt => integer()();
  BoolColumn get closing => boolean().withDefault(const Constant(false))();
  @override
  Set<Column> get primaryKey => {id};
}

/// 忘记使用墓碑，防止同一对话来源又恢复已删除记忆。
@DataClassName('MemoryEntryRow')
@TableIndex.sql('CREATE INDEX memory_entries_source ON memory_entries(source)')
@TableIndex.sql(
  'CREATE INDEX memory_entries_topic ON memory_entries(conflict_key,goal_id)',
)
class MemoryEntries extends Table {
  TextColumn get id => text()();
  TextColumn get goalId => text().nullable().references(Goals, #id)();
  TextColumn get kind => text()();
  TextColumn get content => text()();
  TextColumn get source => text()();
  TextColumn get certainty => text()();
  TextColumn get conflictKey => text()();
  IntColumn get updatedAt => integer()();
  IntColumn get expiresAt => integer().nullable()();
  BoolColumn get forgotten => boolean().withDefault(const Constant(false))();
  BoolColumn get userEdited => boolean().withDefault(const Constant(false))();
  @override
  Set<Column> get primaryKey => {id};
}

/// 搜索按月保存已预留额度；密钥从不进入数据库。
class SearchUsage extends Table {
  TextColumn get month => text()();
  IntColumn get credits => integer().withDefault(const Constant(0))();
  @override
  Set<Column> get primaryKey => {month};
}

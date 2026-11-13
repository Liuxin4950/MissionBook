import 'package:drift/drift.dart';

import 'goals.dart';

/// 记忆条目：layer 独立承担五层语义，certainty 表示确认程度，主题由主题表消解。
@DataClassName('MemoryItemRow')
@TableIndex.sql(
  'CREATE INDEX memory_items_layer ON memory_items(layer, forgotten, updated_at)',
)
@TableIndex.sql('CREATE INDEX memory_items_topic ON memory_items(topic_id)')
@TableIndex.sql('CREATE INDEX memory_items_goal ON memory_items(goal_id)')
@TableIndex.sql(
  'CREATE INDEX memory_items_content ON memory_items(forgotten, updated_at)',
)
class MemoryItems extends Table {
  TextColumn get id => text()();
  TextColumn get layer => text().customConstraint(
    "NOT NULL CHECK (layer IN ('identity', 'semantic', 'episodic', 'procedural', 'observation'))",
  )();
  TextColumn get topicId =>
      text().nullable().references(MemoryTopics, #id)();
  TextColumn get content => text()();
  TextColumn get certainty => text().customConstraint(
    "NOT NULL CHECK (certainty IN ('stated', 'inferred', 'unverified'))",
  )();
  IntColumn get importance => integer().customConstraint(
    'NOT NULL DEFAULT 50 CHECK (importance BETWEEN 1 AND 100)',
  )();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();
  IntColumn get expiresAt => integer().nullable()();
  BoolColumn get forgotten => boolean().withDefault(const Constant(false))();
  BoolColumn get userEdited => boolean().withDefault(const Constant(false))();
  TextColumn get sourceKind => text().customConstraint(
    "NOT NULL CHECK (source_kind IN ('user', 'assistant', 'extraction', 'manual', 'reflection'))",
  )();
  TextColumn get sourceRef => text().nullable()();
  TextColumn get goalId => text().nullable().references(Goals, #id)();
  @override
  Set<Column> get primaryKey => {id};
}

/// 稳定主题；同义写法通过别名表归入同一主题，供写入消解与召回使用。
@DataClassName('MemoryTopicRow')
@TableIndex.sql(
  'CREATE INDEX memory_topics_scope ON memory_topics(goal_id, kind)',
)
class MemoryTopics extends Table {
  TextColumn get id => text()();
  TextColumn get canonicalName => text().customConstraint(
    'NOT NULL CHECK (length(trim(canonical_name)) > 0)',
  )();
  TextColumn get kind => text().customConstraint(
    "NOT NULL CHECK (kind IN ('preference', 'fact', 'constraint', 'observation', 'identity'))",
  )();
  TextColumn get goalId => text().nullable().references(Goals, #id)();
  IntColumn get createdAt => integer()();
  @override
  Set<Column> get primaryKey => {id};
}

/// 主题别名；normalized_alias 由写入入口按同一规则归一化，带唯一约束防重复。
@DataClassName('MemoryTopicAliasRow')
@TableIndex.sql(
  'CREATE UNIQUE INDEX memory_topic_aliases_normalized ON memory_topic_aliases(normalized_alias, topic_id)',
)
class MemoryTopicAliases extends Table {
  TextColumn get topicId => text().references(MemoryTopics, #id)();
  TextColumn get alias => text()();
  TextColumn get normalizedAlias => text()();
  @override
  Set<Column> get primaryKey => {topicId, normalizedAlias};
}

/// 追加式版本历史；每次实际写入或忘记都在同一事务内记录前后快照。
@DataClassName('MemoryVersionRow')
@TableIndex.sql(
  'CREATE INDEX memory_versions_item ON memory_versions(item_id, created_at)',
)
class MemoryVersions extends Table {
  TextColumn get id => text()();
  TextColumn get itemId => text().references(MemoryItems, #id)();
  TextColumn get changeKind => text()();
  TextColumn get beforeJson => text().nullable()();
  TextColumn get afterJson => text()();
  TextColumn get reason => text()();
  TextColumn get operationId => text().nullable()();
  TextColumn get actor => text()();
  IntColumn get createdAt => integer()();
  @override
  Set<Column> get primaryKey => {id};
}

/// 少量跨模块设置；键值随备份导出，用于记忆抽取开关等可恢复选项。
@DataClassName('AppSettingRow')
class AppSettings extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();
  IntColumn get updatedAt => integer()();
  @override
  Set<Column> get primaryKey => {key};
}

/// 情节记忆的附加信息；摘要正文仍是 memory_items(layer='episodic') 的 content。
@DataClassName('MemoryEpisodeRow')
class MemoryEpisodes extends Table {
  TextColumn get itemId => text().references(MemoryItems, #id)();
  TextColumn get sourceRefsJson => text()();
  @override
  Set<Column> get primaryKey => {itemId};
}

/// 程序性记忆的步骤与触发上下文；标题仍是 memory_items(layer='procedural') 的 content。
@DataClassName('MemoryProcedureRow')
class MemoryProcedures extends Table {
  TextColumn get itemId => text().references(MemoryItems, #id)();
  TextColumn get stepsJson => text()();
  TextColumn get triggerContext => text().nullable()();
  TextColumn get sourceRefsJson => text()();
  @override
  Set<Column> get primaryKey => {itemId};
}

/// 召回与注入计数；不在备份指纹与版本快照内，随备份导出恢复。
@DataClassName('MemoryUsageRow')
class MemoryUsage extends Table {
  TextColumn get itemId => text().references(MemoryItems, #id)();
  IntColumn get recallCount => integer().withDefault(const Constant(0))();
  IntColumn get injectCount => integer().withDefault(const Constant(0))();
  IntColumn get lastUsedAt => integer().nullable()();
  @override
  Set<Column> get primaryKey => {itemId};
}

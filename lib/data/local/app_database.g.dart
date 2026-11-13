// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $GoalsTable extends Goals with TableInfo<$GoalsTable, GoalRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $GoalsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL CHECK (length(trim(title)) > 0)',
  );
  static const VerificationMeta _descriptionMeta = const VerificationMeta(
    'description',
  );
  @override
  late final GeneratedColumn<String> description = GeneratedColumn<String>(
    'description',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _whyMeta = const VerificationMeta('why');
  @override
  late final GeneratedColumn<String> why = GeneratedColumn<String>(
    'why',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _desireLevelMeta = const VerificationMeta(
    'desireLevel',
  );
  @override
  late final GeneratedColumn<int> desireLevel = GeneratedColumn<int>(
    'desire_level',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    $customConstraints: 'CHECK (desire_level BETWEEN 1 AND 5)',
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('ACTIVE'),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<int> updatedAt = GeneratedColumn<int>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    title,
    description,
    why,
    desireLevel,
    status,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'goals';
  @override
  VerificationContext validateIntegrity(
    Insertable<GoalRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('description')) {
      context.handle(
        _descriptionMeta,
        description.isAcceptableOrUnknown(
          data['description']!,
          _descriptionMeta,
        ),
      );
    }
    if (data.containsKey('why')) {
      context.handle(
        _whyMeta,
        why.isAcceptableOrUnknown(data['why']!, _whyMeta),
      );
    }
    if (data.containsKey('desire_level')) {
      context.handle(
        _desireLevelMeta,
        desireLevel.isAcceptableOrUnknown(
          data['desire_level']!,
          _desireLevelMeta,
        ),
      );
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  GoalRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return GoalRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      description: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}description'],
      ),
      why: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}why'],
      ),
      desireLevel: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}desire_level'],
      ),
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $GoalsTable createAlias(String alias) {
    return $GoalsTable(attachedDatabase, alias);
  }
}

class GoalRow extends DataClass implements Insertable<GoalRow> {
  final String id;
  final String title;
  final String? description;
  final String? why;
  final int? desireLevel;
  final String status;
  final int createdAt;
  final int updatedAt;
  const GoalRow({
    required this.id,
    required this.title,
    this.description,
    this.why,
    this.desireLevel,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['title'] = Variable<String>(title);
    if (!nullToAbsent || description != null) {
      map['description'] = Variable<String>(description);
    }
    if (!nullToAbsent || why != null) {
      map['why'] = Variable<String>(why);
    }
    if (!nullToAbsent || desireLevel != null) {
      map['desire_level'] = Variable<int>(desireLevel);
    }
    map['status'] = Variable<String>(status);
    map['created_at'] = Variable<int>(createdAt);
    map['updated_at'] = Variable<int>(updatedAt);
    return map;
  }

  GoalsCompanion toCompanion(bool nullToAbsent) {
    return GoalsCompanion(
      id: Value(id),
      title: Value(title),
      description: description == null && nullToAbsent
          ? const Value.absent()
          : Value(description),
      why: why == null && nullToAbsent ? const Value.absent() : Value(why),
      desireLevel: desireLevel == null && nullToAbsent
          ? const Value.absent()
          : Value(desireLevel),
      status: Value(status),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory GoalRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return GoalRow(
      id: serializer.fromJson<String>(json['id']),
      title: serializer.fromJson<String>(json['title']),
      description: serializer.fromJson<String?>(json['description']),
      why: serializer.fromJson<String?>(json['why']),
      desireLevel: serializer.fromJson<int?>(json['desireLevel']),
      status: serializer.fromJson<String>(json['status']),
      createdAt: serializer.fromJson<int>(json['createdAt']),
      updatedAt: serializer.fromJson<int>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'title': serializer.toJson<String>(title),
      'description': serializer.toJson<String?>(description),
      'why': serializer.toJson<String?>(why),
      'desireLevel': serializer.toJson<int?>(desireLevel),
      'status': serializer.toJson<String>(status),
      'createdAt': serializer.toJson<int>(createdAt),
      'updatedAt': serializer.toJson<int>(updatedAt),
    };
  }

  GoalRow copyWith({
    String? id,
    String? title,
    Value<String?> description = const Value.absent(),
    Value<String?> why = const Value.absent(),
    Value<int?> desireLevel = const Value.absent(),
    String? status,
    int? createdAt,
    int? updatedAt,
  }) => GoalRow(
    id: id ?? this.id,
    title: title ?? this.title,
    description: description.present ? description.value : this.description,
    why: why.present ? why.value : this.why,
    desireLevel: desireLevel.present ? desireLevel.value : this.desireLevel,
    status: status ?? this.status,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  GoalRow copyWithCompanion(GoalsCompanion data) {
    return GoalRow(
      id: data.id.present ? data.id.value : this.id,
      title: data.title.present ? data.title.value : this.title,
      description: data.description.present
          ? data.description.value
          : this.description,
      why: data.why.present ? data.why.value : this.why,
      desireLevel: data.desireLevel.present
          ? data.desireLevel.value
          : this.desireLevel,
      status: data.status.present ? data.status.value : this.status,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('GoalRow(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('description: $description, ')
          ..write('why: $why, ')
          ..write('desireLevel: $desireLevel, ')
          ..write('status: $status, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    title,
    description,
    why,
    desireLevel,
    status,
    createdAt,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is GoalRow &&
          other.id == this.id &&
          other.title == this.title &&
          other.description == this.description &&
          other.why == this.why &&
          other.desireLevel == this.desireLevel &&
          other.status == this.status &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class GoalsCompanion extends UpdateCompanion<GoalRow> {
  final Value<String> id;
  final Value<String> title;
  final Value<String?> description;
  final Value<String?> why;
  final Value<int?> desireLevel;
  final Value<String> status;
  final Value<int> createdAt;
  final Value<int> updatedAt;
  final Value<int> rowid;
  const GoalsCompanion({
    this.id = const Value.absent(),
    this.title = const Value.absent(),
    this.description = const Value.absent(),
    this.why = const Value.absent(),
    this.desireLevel = const Value.absent(),
    this.status = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  GoalsCompanion.insert({
    required String id,
    required String title,
    this.description = const Value.absent(),
    this.why = const Value.absent(),
    this.desireLevel = const Value.absent(),
    this.status = const Value.absent(),
    required int createdAt,
    required int updatedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       title = Value(title),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<GoalRow> custom({
    Expression<String>? id,
    Expression<String>? title,
    Expression<String>? description,
    Expression<String>? why,
    Expression<int>? desireLevel,
    Expression<String>? status,
    Expression<int>? createdAt,
    Expression<int>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (title != null) 'title': title,
      if (description != null) 'description': description,
      if (why != null) 'why': why,
      if (desireLevel != null) 'desire_level': desireLevel,
      if (status != null) 'status': status,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  GoalsCompanion copyWith({
    Value<String>? id,
    Value<String>? title,
    Value<String?>? description,
    Value<String?>? why,
    Value<int?>? desireLevel,
    Value<String>? status,
    Value<int>? createdAt,
    Value<int>? updatedAt,
    Value<int>? rowid,
  }) {
    return GoalsCompanion(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      why: why ?? this.why,
      desireLevel: desireLevel ?? this.desireLevel,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (description.present) {
      map['description'] = Variable<String>(description.value);
    }
    if (why.present) {
      map['why'] = Variable<String>(why.value);
    }
    if (desireLevel.present) {
      map['desire_level'] = Variable<int>(desireLevel.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('GoalsCompanion(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('description: $description, ')
          ..write('why: $why, ')
          ..write('desireLevel: $desireLevel, ')
          ..write('status: $status, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $GoalNodesTable extends GoalNodes
    with TableInfo<$GoalNodesTable, GoalNodeRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $GoalNodesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _goalIdMeta = const VerificationMeta('goalId');
  @override
  late final GeneratedColumn<String> goalId = GeneratedColumn<String>(
    'goal_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES goals (id)',
    ),
  );
  static const VerificationMeta _parentNodeIdMeta = const VerificationMeta(
    'parentNodeId',
  );
  @override
  late final GeneratedColumn<String> parentNodeId = GeneratedColumn<String>(
    'parent_node_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL CHECK (length(trim(title)) > 0)',
  );
  static const VerificationMeta _descriptionMeta = const VerificationMeta(
    'description',
  );
  @override
  late final GeneratedColumn<String> description = GeneratedColumn<String>(
    'description',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _orderIndexMeta = const VerificationMeta(
    'orderIndex',
  );
  @override
  late final GeneratedColumn<int> orderIndex = GeneratedColumn<int>(
    'order_index',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL CHECK (order_index >= 0)',
  );
  static const VerificationMeta _archivedAtMeta = const VerificationMeta(
    'archivedAt',
  );
  @override
  late final GeneratedColumn<int> archivedAt = GeneratedColumn<int>(
    'archived_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<int> updatedAt = GeneratedColumn<int>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    goalId,
    parentNodeId,
    title,
    description,
    orderIndex,
    archivedAt,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'goal_nodes';
  @override
  VerificationContext validateIntegrity(
    Insertable<GoalNodeRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('goal_id')) {
      context.handle(
        _goalIdMeta,
        goalId.isAcceptableOrUnknown(data['goal_id']!, _goalIdMeta),
      );
    } else if (isInserting) {
      context.missing(_goalIdMeta);
    }
    if (data.containsKey('parent_node_id')) {
      context.handle(
        _parentNodeIdMeta,
        parentNodeId.isAcceptableOrUnknown(
          data['parent_node_id']!,
          _parentNodeIdMeta,
        ),
      );
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('description')) {
      context.handle(
        _descriptionMeta,
        description.isAcceptableOrUnknown(
          data['description']!,
          _descriptionMeta,
        ),
      );
    }
    if (data.containsKey('order_index')) {
      context.handle(
        _orderIndexMeta,
        orderIndex.isAcceptableOrUnknown(data['order_index']!, _orderIndexMeta),
      );
    } else if (isInserting) {
      context.missing(_orderIndexMeta);
    }
    if (data.containsKey('archived_at')) {
      context.handle(
        _archivedAtMeta,
        archivedAt.isAcceptableOrUnknown(data['archived_at']!, _archivedAtMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  GoalNodeRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return GoalNodeRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      goalId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}goal_id'],
      )!,
      parentNodeId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}parent_node_id'],
      ),
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      description: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}description'],
      ),
      orderIndex: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}order_index'],
      )!,
      archivedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}archived_at'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $GoalNodesTable createAlias(String alias) {
    return $GoalNodesTable(attachedDatabase, alias);
  }
}

class GoalNodeRow extends DataClass implements Insertable<GoalNodeRow> {
  final String id;
  final String goalId;
  final String? parentNodeId;
  final String title;
  final String? description;
  final int orderIndex;
  final int? archivedAt;
  final int createdAt;
  final int updatedAt;
  const GoalNodeRow({
    required this.id,
    required this.goalId,
    this.parentNodeId,
    required this.title,
    this.description,
    required this.orderIndex,
    this.archivedAt,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['goal_id'] = Variable<String>(goalId);
    if (!nullToAbsent || parentNodeId != null) {
      map['parent_node_id'] = Variable<String>(parentNodeId);
    }
    map['title'] = Variable<String>(title);
    if (!nullToAbsent || description != null) {
      map['description'] = Variable<String>(description);
    }
    map['order_index'] = Variable<int>(orderIndex);
    if (!nullToAbsent || archivedAt != null) {
      map['archived_at'] = Variable<int>(archivedAt);
    }
    map['created_at'] = Variable<int>(createdAt);
    map['updated_at'] = Variable<int>(updatedAt);
    return map;
  }

  GoalNodesCompanion toCompanion(bool nullToAbsent) {
    return GoalNodesCompanion(
      id: Value(id),
      goalId: Value(goalId),
      parentNodeId: parentNodeId == null && nullToAbsent
          ? const Value.absent()
          : Value(parentNodeId),
      title: Value(title),
      description: description == null && nullToAbsent
          ? const Value.absent()
          : Value(description),
      orderIndex: Value(orderIndex),
      archivedAt: archivedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(archivedAt),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory GoalNodeRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return GoalNodeRow(
      id: serializer.fromJson<String>(json['id']),
      goalId: serializer.fromJson<String>(json['goalId']),
      parentNodeId: serializer.fromJson<String?>(json['parentNodeId']),
      title: serializer.fromJson<String>(json['title']),
      description: serializer.fromJson<String?>(json['description']),
      orderIndex: serializer.fromJson<int>(json['orderIndex']),
      archivedAt: serializer.fromJson<int?>(json['archivedAt']),
      createdAt: serializer.fromJson<int>(json['createdAt']),
      updatedAt: serializer.fromJson<int>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'goalId': serializer.toJson<String>(goalId),
      'parentNodeId': serializer.toJson<String?>(parentNodeId),
      'title': serializer.toJson<String>(title),
      'description': serializer.toJson<String?>(description),
      'orderIndex': serializer.toJson<int>(orderIndex),
      'archivedAt': serializer.toJson<int?>(archivedAt),
      'createdAt': serializer.toJson<int>(createdAt),
      'updatedAt': serializer.toJson<int>(updatedAt),
    };
  }

  GoalNodeRow copyWith({
    String? id,
    String? goalId,
    Value<String?> parentNodeId = const Value.absent(),
    String? title,
    Value<String?> description = const Value.absent(),
    int? orderIndex,
    Value<int?> archivedAt = const Value.absent(),
    int? createdAt,
    int? updatedAt,
  }) => GoalNodeRow(
    id: id ?? this.id,
    goalId: goalId ?? this.goalId,
    parentNodeId: parentNodeId.present ? parentNodeId.value : this.parentNodeId,
    title: title ?? this.title,
    description: description.present ? description.value : this.description,
    orderIndex: orderIndex ?? this.orderIndex,
    archivedAt: archivedAt.present ? archivedAt.value : this.archivedAt,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  GoalNodeRow copyWithCompanion(GoalNodesCompanion data) {
    return GoalNodeRow(
      id: data.id.present ? data.id.value : this.id,
      goalId: data.goalId.present ? data.goalId.value : this.goalId,
      parentNodeId: data.parentNodeId.present
          ? data.parentNodeId.value
          : this.parentNodeId,
      title: data.title.present ? data.title.value : this.title,
      description: data.description.present
          ? data.description.value
          : this.description,
      orderIndex: data.orderIndex.present
          ? data.orderIndex.value
          : this.orderIndex,
      archivedAt: data.archivedAt.present
          ? data.archivedAt.value
          : this.archivedAt,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('GoalNodeRow(')
          ..write('id: $id, ')
          ..write('goalId: $goalId, ')
          ..write('parentNodeId: $parentNodeId, ')
          ..write('title: $title, ')
          ..write('description: $description, ')
          ..write('orderIndex: $orderIndex, ')
          ..write('archivedAt: $archivedAt, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    goalId,
    parentNodeId,
    title,
    description,
    orderIndex,
    archivedAt,
    createdAt,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is GoalNodeRow &&
          other.id == this.id &&
          other.goalId == this.goalId &&
          other.parentNodeId == this.parentNodeId &&
          other.title == this.title &&
          other.description == this.description &&
          other.orderIndex == this.orderIndex &&
          other.archivedAt == this.archivedAt &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class GoalNodesCompanion extends UpdateCompanion<GoalNodeRow> {
  final Value<String> id;
  final Value<String> goalId;
  final Value<String?> parentNodeId;
  final Value<String> title;
  final Value<String?> description;
  final Value<int> orderIndex;
  final Value<int?> archivedAt;
  final Value<int> createdAt;
  final Value<int> updatedAt;
  final Value<int> rowid;
  const GoalNodesCompanion({
    this.id = const Value.absent(),
    this.goalId = const Value.absent(),
    this.parentNodeId = const Value.absent(),
    this.title = const Value.absent(),
    this.description = const Value.absent(),
    this.orderIndex = const Value.absent(),
    this.archivedAt = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  GoalNodesCompanion.insert({
    required String id,
    required String goalId,
    this.parentNodeId = const Value.absent(),
    required String title,
    this.description = const Value.absent(),
    required int orderIndex,
    this.archivedAt = const Value.absent(),
    required int createdAt,
    required int updatedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       goalId = Value(goalId),
       title = Value(title),
       orderIndex = Value(orderIndex),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<GoalNodeRow> custom({
    Expression<String>? id,
    Expression<String>? goalId,
    Expression<String>? parentNodeId,
    Expression<String>? title,
    Expression<String>? description,
    Expression<int>? orderIndex,
    Expression<int>? archivedAt,
    Expression<int>? createdAt,
    Expression<int>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (goalId != null) 'goal_id': goalId,
      if (parentNodeId != null) 'parent_node_id': parentNodeId,
      if (title != null) 'title': title,
      if (description != null) 'description': description,
      if (orderIndex != null) 'order_index': orderIndex,
      if (archivedAt != null) 'archived_at': archivedAt,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  GoalNodesCompanion copyWith({
    Value<String>? id,
    Value<String>? goalId,
    Value<String?>? parentNodeId,
    Value<String>? title,
    Value<String?>? description,
    Value<int>? orderIndex,
    Value<int?>? archivedAt,
    Value<int>? createdAt,
    Value<int>? updatedAt,
    Value<int>? rowid,
  }) {
    return GoalNodesCompanion(
      id: id ?? this.id,
      goalId: goalId ?? this.goalId,
      parentNodeId: parentNodeId ?? this.parentNodeId,
      title: title ?? this.title,
      description: description ?? this.description,
      orderIndex: orderIndex ?? this.orderIndex,
      archivedAt: archivedAt ?? this.archivedAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (goalId.present) {
      map['goal_id'] = Variable<String>(goalId.value);
    }
    if (parentNodeId.present) {
      map['parent_node_id'] = Variable<String>(parentNodeId.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (description.present) {
      map['description'] = Variable<String>(description.value);
    }
    if (orderIndex.present) {
      map['order_index'] = Variable<int>(orderIndex.value);
    }
    if (archivedAt.present) {
      map['archived_at'] = Variable<int>(archivedAt.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('GoalNodesCompanion(')
          ..write('id: $id, ')
          ..write('goalId: $goalId, ')
          ..write('parentNodeId: $parentNodeId, ')
          ..write('title: $title, ')
          ..write('description: $description, ')
          ..write('orderIndex: $orderIndex, ')
          ..write('archivedAt: $archivedAt, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $MissionsTable extends Missions
    with TableInfo<$MissionsTable, MissionRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $MissionsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _goalIdMeta = const VerificationMeta('goalId');
  @override
  late final GeneratedColumn<String> goalId = GeneratedColumn<String>(
    'goal_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES goals (id)',
    ),
  );
  static const VerificationMeta _goalNodeIdMeta = const VerificationMeta(
    'goalNodeId',
  );
  @override
  late final GeneratedColumn<String> goalNodeId = GeneratedColumn<String>(
    'goal_node_id',
    aliasedName,
    true,
    check: () => const CustomExpression<bool>(
      'goal_node_id IS NULL OR goal_id IS NOT NULL',
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES goal_nodes (id)',
    ),
  );
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _descriptionMeta = const VerificationMeta(
    'description',
  );
  @override
  late final GeneratedColumn<String> description = GeneratedColumn<String>(
    'description',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _whyMeta = const VerificationMeta('why');
  @override
  late final GeneratedColumn<String> why = GeneratedColumn<String>(
    'why',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _verificationPolicyMeta =
      const VerificationMeta('verificationPolicy');
  @override
  late final GeneratedColumn<String> verificationPolicy =
      GeneratedColumn<String>(
        'verification_policy',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
        defaultValue: const Constant('SELF_REPORT'),
      );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<int> updatedAt = GeneratedColumn<int>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _cancelledAtMeta = const VerificationMeta(
    'cancelledAt',
  );
  @override
  late final GeneratedColumn<int> cancelledAt = GeneratedColumn<int>(
    'cancelled_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _evidenceWaivedAtMeta = const VerificationMeta(
    'evidenceWaivedAt',
  );
  @override
  late final GeneratedColumn<int> evidenceWaivedAt = GeneratedColumn<int>(
    'evidence_waived_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _sourceMissionIdMeta = const VerificationMeta(
    'sourceMissionId',
  );
  @override
  late final GeneratedColumn<String> sourceMissionId = GeneratedColumn<String>(
    'source_mission_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES missions (id)',
    ),
  );
  static const VerificationMeta _relationTypeMeta = const VerificationMeta(
    'relationType',
  );
  @override
  late final GeneratedColumn<String> relationType = GeneratedColumn<String>(
    'relation_type',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints:
        'NULL CHECK (relation_type IS NULL OR relation_type = \'RETRY\')',
  );
  @override
  List<GeneratedColumn> get $columns => [
    goalId,
    goalNodeId,
    id,
    title,
    description,
    why,
    verificationPolicy,
    createdAt,
    updatedAt,
    cancelledAt,
    evidenceWaivedAt,
    sourceMissionId,
    relationType,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'missions';
  @override
  VerificationContext validateIntegrity(
    Insertable<MissionRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('goal_id')) {
      context.handle(
        _goalIdMeta,
        goalId.isAcceptableOrUnknown(data['goal_id']!, _goalIdMeta),
      );
    }
    if (data.containsKey('goal_node_id')) {
      context.handle(
        _goalNodeIdMeta,
        goalNodeId.isAcceptableOrUnknown(
          data['goal_node_id']!,
          _goalNodeIdMeta,
        ),
      );
    }
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('description')) {
      context.handle(
        _descriptionMeta,
        description.isAcceptableOrUnknown(
          data['description']!,
          _descriptionMeta,
        ),
      );
    }
    if (data.containsKey('why')) {
      context.handle(
        _whyMeta,
        why.isAcceptableOrUnknown(data['why']!, _whyMeta),
      );
    }
    if (data.containsKey('verification_policy')) {
      context.handle(
        _verificationPolicyMeta,
        verificationPolicy.isAcceptableOrUnknown(
          data['verification_policy']!,
          _verificationPolicyMeta,
        ),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('cancelled_at')) {
      context.handle(
        _cancelledAtMeta,
        cancelledAt.isAcceptableOrUnknown(
          data['cancelled_at']!,
          _cancelledAtMeta,
        ),
      );
    }
    if (data.containsKey('evidence_waived_at')) {
      context.handle(
        _evidenceWaivedAtMeta,
        evidenceWaivedAt.isAcceptableOrUnknown(
          data['evidence_waived_at']!,
          _evidenceWaivedAtMeta,
        ),
      );
    }
    if (data.containsKey('source_mission_id')) {
      context.handle(
        _sourceMissionIdMeta,
        sourceMissionId.isAcceptableOrUnknown(
          data['source_mission_id']!,
          _sourceMissionIdMeta,
        ),
      );
    }
    if (data.containsKey('relation_type')) {
      context.handle(
        _relationTypeMeta,
        relationType.isAcceptableOrUnknown(
          data['relation_type']!,
          _relationTypeMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  MissionRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return MissionRow(
      goalId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}goal_id'],
      ),
      goalNodeId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}goal_node_id'],
      ),
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      description: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}description'],
      ),
      why: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}why'],
      ),
      verificationPolicy: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}verification_policy'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at'],
      )!,
      cancelledAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}cancelled_at'],
      ),
      evidenceWaivedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}evidence_waived_at'],
      ),
      sourceMissionId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source_mission_id'],
      ),
      relationType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}relation_type'],
      ),
    );
  }

  @override
  $MissionsTable createAlias(String alias) {
    return $MissionsTable(attachedDatabase, alias);
  }
}

class MissionRow extends DataClass implements Insertable<MissionRow> {
  final String? goalId;
  final String? goalNodeId;
  final String id;
  final String title;
  final String? description;
  final String? why;
  final String verificationPolicy;
  final int createdAt;
  final int updatedAt;
  final int? cancelledAt;
  final int? evidenceWaivedAt;
  final String? sourceMissionId;
  final String? relationType;
  const MissionRow({
    this.goalId,
    this.goalNodeId,
    required this.id,
    required this.title,
    this.description,
    this.why,
    required this.verificationPolicy,
    required this.createdAt,
    required this.updatedAt,
    this.cancelledAt,
    this.evidenceWaivedAt,
    this.sourceMissionId,
    this.relationType,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (!nullToAbsent || goalId != null) {
      map['goal_id'] = Variable<String>(goalId);
    }
    if (!nullToAbsent || goalNodeId != null) {
      map['goal_node_id'] = Variable<String>(goalNodeId);
    }
    map['id'] = Variable<String>(id);
    map['title'] = Variable<String>(title);
    if (!nullToAbsent || description != null) {
      map['description'] = Variable<String>(description);
    }
    if (!nullToAbsent || why != null) {
      map['why'] = Variable<String>(why);
    }
    map['verification_policy'] = Variable<String>(verificationPolicy);
    map['created_at'] = Variable<int>(createdAt);
    map['updated_at'] = Variable<int>(updatedAt);
    if (!nullToAbsent || cancelledAt != null) {
      map['cancelled_at'] = Variable<int>(cancelledAt);
    }
    if (!nullToAbsent || evidenceWaivedAt != null) {
      map['evidence_waived_at'] = Variable<int>(evidenceWaivedAt);
    }
    if (!nullToAbsent || sourceMissionId != null) {
      map['source_mission_id'] = Variable<String>(sourceMissionId);
    }
    if (!nullToAbsent || relationType != null) {
      map['relation_type'] = Variable<String>(relationType);
    }
    return map;
  }

  MissionsCompanion toCompanion(bool nullToAbsent) {
    return MissionsCompanion(
      goalId: goalId == null && nullToAbsent
          ? const Value.absent()
          : Value(goalId),
      goalNodeId: goalNodeId == null && nullToAbsent
          ? const Value.absent()
          : Value(goalNodeId),
      id: Value(id),
      title: Value(title),
      description: description == null && nullToAbsent
          ? const Value.absent()
          : Value(description),
      why: why == null && nullToAbsent ? const Value.absent() : Value(why),
      verificationPolicy: Value(verificationPolicy),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      cancelledAt: cancelledAt == null && nullToAbsent
          ? const Value.absent()
          : Value(cancelledAt),
      evidenceWaivedAt: evidenceWaivedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(evidenceWaivedAt),
      sourceMissionId: sourceMissionId == null && nullToAbsent
          ? const Value.absent()
          : Value(sourceMissionId),
      relationType: relationType == null && nullToAbsent
          ? const Value.absent()
          : Value(relationType),
    );
  }

  factory MissionRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return MissionRow(
      goalId: serializer.fromJson<String?>(json['goalId']),
      goalNodeId: serializer.fromJson<String?>(json['goalNodeId']),
      id: serializer.fromJson<String>(json['id']),
      title: serializer.fromJson<String>(json['title']),
      description: serializer.fromJson<String?>(json['description']),
      why: serializer.fromJson<String?>(json['why']),
      verificationPolicy: serializer.fromJson<String>(
        json['verificationPolicy'],
      ),
      createdAt: serializer.fromJson<int>(json['createdAt']),
      updatedAt: serializer.fromJson<int>(json['updatedAt']),
      cancelledAt: serializer.fromJson<int?>(json['cancelledAt']),
      evidenceWaivedAt: serializer.fromJson<int?>(json['evidenceWaivedAt']),
      sourceMissionId: serializer.fromJson<String?>(json['sourceMissionId']),
      relationType: serializer.fromJson<String?>(json['relationType']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'goalId': serializer.toJson<String?>(goalId),
      'goalNodeId': serializer.toJson<String?>(goalNodeId),
      'id': serializer.toJson<String>(id),
      'title': serializer.toJson<String>(title),
      'description': serializer.toJson<String?>(description),
      'why': serializer.toJson<String?>(why),
      'verificationPolicy': serializer.toJson<String>(verificationPolicy),
      'createdAt': serializer.toJson<int>(createdAt),
      'updatedAt': serializer.toJson<int>(updatedAt),
      'cancelledAt': serializer.toJson<int?>(cancelledAt),
      'evidenceWaivedAt': serializer.toJson<int?>(evidenceWaivedAt),
      'sourceMissionId': serializer.toJson<String?>(sourceMissionId),
      'relationType': serializer.toJson<String?>(relationType),
    };
  }

  MissionRow copyWith({
    Value<String?> goalId = const Value.absent(),
    Value<String?> goalNodeId = const Value.absent(),
    String? id,
    String? title,
    Value<String?> description = const Value.absent(),
    Value<String?> why = const Value.absent(),
    String? verificationPolicy,
    int? createdAt,
    int? updatedAt,
    Value<int?> cancelledAt = const Value.absent(),
    Value<int?> evidenceWaivedAt = const Value.absent(),
    Value<String?> sourceMissionId = const Value.absent(),
    Value<String?> relationType = const Value.absent(),
  }) => MissionRow(
    goalId: goalId.present ? goalId.value : this.goalId,
    goalNodeId: goalNodeId.present ? goalNodeId.value : this.goalNodeId,
    id: id ?? this.id,
    title: title ?? this.title,
    description: description.present ? description.value : this.description,
    why: why.present ? why.value : this.why,
    verificationPolicy: verificationPolicy ?? this.verificationPolicy,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    cancelledAt: cancelledAt.present ? cancelledAt.value : this.cancelledAt,
    evidenceWaivedAt: evidenceWaivedAt.present
        ? evidenceWaivedAt.value
        : this.evidenceWaivedAt,
    sourceMissionId: sourceMissionId.present
        ? sourceMissionId.value
        : this.sourceMissionId,
    relationType: relationType.present ? relationType.value : this.relationType,
  );
  MissionRow copyWithCompanion(MissionsCompanion data) {
    return MissionRow(
      goalId: data.goalId.present ? data.goalId.value : this.goalId,
      goalNodeId: data.goalNodeId.present
          ? data.goalNodeId.value
          : this.goalNodeId,
      id: data.id.present ? data.id.value : this.id,
      title: data.title.present ? data.title.value : this.title,
      description: data.description.present
          ? data.description.value
          : this.description,
      why: data.why.present ? data.why.value : this.why,
      verificationPolicy: data.verificationPolicy.present
          ? data.verificationPolicy.value
          : this.verificationPolicy,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      cancelledAt: data.cancelledAt.present
          ? data.cancelledAt.value
          : this.cancelledAt,
      evidenceWaivedAt: data.evidenceWaivedAt.present
          ? data.evidenceWaivedAt.value
          : this.evidenceWaivedAt,
      sourceMissionId: data.sourceMissionId.present
          ? data.sourceMissionId.value
          : this.sourceMissionId,
      relationType: data.relationType.present
          ? data.relationType.value
          : this.relationType,
    );
  }

  @override
  String toString() {
    return (StringBuffer('MissionRow(')
          ..write('goalId: $goalId, ')
          ..write('goalNodeId: $goalNodeId, ')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('description: $description, ')
          ..write('why: $why, ')
          ..write('verificationPolicy: $verificationPolicy, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('cancelledAt: $cancelledAt, ')
          ..write('evidenceWaivedAt: $evidenceWaivedAt, ')
          ..write('sourceMissionId: $sourceMissionId, ')
          ..write('relationType: $relationType')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    goalId,
    goalNodeId,
    id,
    title,
    description,
    why,
    verificationPolicy,
    createdAt,
    updatedAt,
    cancelledAt,
    evidenceWaivedAt,
    sourceMissionId,
    relationType,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is MissionRow &&
          other.goalId == this.goalId &&
          other.goalNodeId == this.goalNodeId &&
          other.id == this.id &&
          other.title == this.title &&
          other.description == this.description &&
          other.why == this.why &&
          other.verificationPolicy == this.verificationPolicy &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.cancelledAt == this.cancelledAt &&
          other.evidenceWaivedAt == this.evidenceWaivedAt &&
          other.sourceMissionId == this.sourceMissionId &&
          other.relationType == this.relationType);
}

class MissionsCompanion extends UpdateCompanion<MissionRow> {
  final Value<String?> goalId;
  final Value<String?> goalNodeId;
  final Value<String> id;
  final Value<String> title;
  final Value<String?> description;
  final Value<String?> why;
  final Value<String> verificationPolicy;
  final Value<int> createdAt;
  final Value<int> updatedAt;
  final Value<int?> cancelledAt;
  final Value<int?> evidenceWaivedAt;
  final Value<String?> sourceMissionId;
  final Value<String?> relationType;
  final Value<int> rowid;
  const MissionsCompanion({
    this.goalId = const Value.absent(),
    this.goalNodeId = const Value.absent(),
    this.id = const Value.absent(),
    this.title = const Value.absent(),
    this.description = const Value.absent(),
    this.why = const Value.absent(),
    this.verificationPolicy = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.cancelledAt = const Value.absent(),
    this.evidenceWaivedAt = const Value.absent(),
    this.sourceMissionId = const Value.absent(),
    this.relationType = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  MissionsCompanion.insert({
    this.goalId = const Value.absent(),
    this.goalNodeId = const Value.absent(),
    required String id,
    required String title,
    this.description = const Value.absent(),
    this.why = const Value.absent(),
    this.verificationPolicy = const Value.absent(),
    required int createdAt,
    required int updatedAt,
    this.cancelledAt = const Value.absent(),
    this.evidenceWaivedAt = const Value.absent(),
    this.sourceMissionId = const Value.absent(),
    this.relationType = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       title = Value(title),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<MissionRow> custom({
    Expression<String>? goalId,
    Expression<String>? goalNodeId,
    Expression<String>? id,
    Expression<String>? title,
    Expression<String>? description,
    Expression<String>? why,
    Expression<String>? verificationPolicy,
    Expression<int>? createdAt,
    Expression<int>? updatedAt,
    Expression<int>? cancelledAt,
    Expression<int>? evidenceWaivedAt,
    Expression<String>? sourceMissionId,
    Expression<String>? relationType,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (goalId != null) 'goal_id': goalId,
      if (goalNodeId != null) 'goal_node_id': goalNodeId,
      if (id != null) 'id': id,
      if (title != null) 'title': title,
      if (description != null) 'description': description,
      if (why != null) 'why': why,
      if (verificationPolicy != null) 'verification_policy': verificationPolicy,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (cancelledAt != null) 'cancelled_at': cancelledAt,
      if (evidenceWaivedAt != null) 'evidence_waived_at': evidenceWaivedAt,
      if (sourceMissionId != null) 'source_mission_id': sourceMissionId,
      if (relationType != null) 'relation_type': relationType,
      if (rowid != null) 'rowid': rowid,
    });
  }

  MissionsCompanion copyWith({
    Value<String?>? goalId,
    Value<String?>? goalNodeId,
    Value<String>? id,
    Value<String>? title,
    Value<String?>? description,
    Value<String?>? why,
    Value<String>? verificationPolicy,
    Value<int>? createdAt,
    Value<int>? updatedAt,
    Value<int?>? cancelledAt,
    Value<int?>? evidenceWaivedAt,
    Value<String?>? sourceMissionId,
    Value<String?>? relationType,
    Value<int>? rowid,
  }) {
    return MissionsCompanion(
      goalId: goalId ?? this.goalId,
      goalNodeId: goalNodeId ?? this.goalNodeId,
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      why: why ?? this.why,
      verificationPolicy: verificationPolicy ?? this.verificationPolicy,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      cancelledAt: cancelledAt ?? this.cancelledAt,
      evidenceWaivedAt: evidenceWaivedAt ?? this.evidenceWaivedAt,
      sourceMissionId: sourceMissionId ?? this.sourceMissionId,
      relationType: relationType ?? this.relationType,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (goalId.present) {
      map['goal_id'] = Variable<String>(goalId.value);
    }
    if (goalNodeId.present) {
      map['goal_node_id'] = Variable<String>(goalNodeId.value);
    }
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (description.present) {
      map['description'] = Variable<String>(description.value);
    }
    if (why.present) {
      map['why'] = Variable<String>(why.value);
    }
    if (verificationPolicy.present) {
      map['verification_policy'] = Variable<String>(verificationPolicy.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(updatedAt.value);
    }
    if (cancelledAt.present) {
      map['cancelled_at'] = Variable<int>(cancelledAt.value);
    }
    if (evidenceWaivedAt.present) {
      map['evidence_waived_at'] = Variable<int>(evidenceWaivedAt.value);
    }
    if (sourceMissionId.present) {
      map['source_mission_id'] = Variable<String>(sourceMissionId.value);
    }
    if (relationType.present) {
      map['relation_type'] = Variable<String>(relationType.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('MissionsCompanion(')
          ..write('goalId: $goalId, ')
          ..write('goalNodeId: $goalNodeId, ')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('description: $description, ')
          ..write('why: $why, ')
          ..write('verificationPolicy: $verificationPolicy, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('cancelledAt: $cancelledAt, ')
          ..write('evidenceWaivedAt: $evidenceWaivedAt, ')
          ..write('sourceMissionId: $sourceMissionId, ')
          ..write('relationType: $relationType, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $MissionScheduleRevisionsTable extends MissionScheduleRevisions
    with TableInfo<$MissionScheduleRevisionsTable, MissionScheduleRevisionRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $MissionScheduleRevisionsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _missionIdMeta = const VerificationMeta(
    'missionId',
  );
  @override
  late final GeneratedColumn<String> missionId = GeneratedColumn<String>(
    'mission_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES missions (id)',
    ),
  );
  static const VerificationMeta _revisionNumberMeta = const VerificationMeta(
    'revisionNumber',
  );
  @override
  late final GeneratedColumn<int> revisionNumber = GeneratedColumn<int>(
    'revision_number',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _scheduledDateMeta = const VerificationMeta(
    'scheduledDate',
  );
  @override
  late final GeneratedColumn<String> scheduledDate = GeneratedColumn<String>(
    'scheduled_date',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _timeZoneMeta = const VerificationMeta(
    'timeZone',
  );
  @override
  late final GeneratedColumn<String> timeZone = GeneratedColumn<String>(
    'time_zone',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _timePolicyMeta = const VerificationMeta(
    'timePolicy',
  );
  @override
  late final GeneratedColumn<String> timePolicy = GeneratedColumn<String>(
    'time_policy',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('FLEXIBLE'),
  );
  static const VerificationMeta _fixedStartAtMeta = const VerificationMeta(
    'fixedStartAt',
  );
  @override
  late final GeneratedColumn<int> fixedStartAt = GeneratedColumn<int>(
    'fixed_start_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _plannedDurationMinutesMeta =
      const VerificationMeta('plannedDurationMinutes');
  @override
  late final GeneratedColumn<int> plannedDurationMinutes = GeneratedColumn<int>(
    'planned_duration_minutes',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _evidenceDeadlineAtMeta =
      const VerificationMeta('evidenceDeadlineAt');
  @override
  late final GeneratedColumn<int> evidenceDeadlineAt = GeneratedColumn<int>(
    'evidence_deadline_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _changeReasonMeta = const VerificationMeta(
    'changeReason',
  );
  @override
  late final GeneratedColumn<String> changeReason = GeneratedColumn<String>(
    'change_reason',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _changedAtMeta = const VerificationMeta(
    'changedAt',
  );
  @override
  late final GeneratedColumn<int> changedAt = GeneratedColumn<int>(
    'changed_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    missionId,
    revisionNumber,
    scheduledDate,
    timeZone,
    timePolicy,
    fixedStartAt,
    plannedDurationMinutes,
    evidenceDeadlineAt,
    changeReason,
    changedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'mission_schedule_revisions';
  @override
  VerificationContext validateIntegrity(
    Insertable<MissionScheduleRevisionRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('mission_id')) {
      context.handle(
        _missionIdMeta,
        missionId.isAcceptableOrUnknown(data['mission_id']!, _missionIdMeta),
      );
    } else if (isInserting) {
      context.missing(_missionIdMeta);
    }
    if (data.containsKey('revision_number')) {
      context.handle(
        _revisionNumberMeta,
        revisionNumber.isAcceptableOrUnknown(
          data['revision_number']!,
          _revisionNumberMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_revisionNumberMeta);
    }
    if (data.containsKey('scheduled_date')) {
      context.handle(
        _scheduledDateMeta,
        scheduledDate.isAcceptableOrUnknown(
          data['scheduled_date']!,
          _scheduledDateMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_scheduledDateMeta);
    }
    if (data.containsKey('time_zone')) {
      context.handle(
        _timeZoneMeta,
        timeZone.isAcceptableOrUnknown(data['time_zone']!, _timeZoneMeta),
      );
    } else if (isInserting) {
      context.missing(_timeZoneMeta);
    }
    if (data.containsKey('time_policy')) {
      context.handle(
        _timePolicyMeta,
        timePolicy.isAcceptableOrUnknown(data['time_policy']!, _timePolicyMeta),
      );
    }
    if (data.containsKey('fixed_start_at')) {
      context.handle(
        _fixedStartAtMeta,
        fixedStartAt.isAcceptableOrUnknown(
          data['fixed_start_at']!,
          _fixedStartAtMeta,
        ),
      );
    }
    if (data.containsKey('planned_duration_minutes')) {
      context.handle(
        _plannedDurationMinutesMeta,
        plannedDurationMinutes.isAcceptableOrUnknown(
          data['planned_duration_minutes']!,
          _plannedDurationMinutesMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_plannedDurationMinutesMeta);
    }
    if (data.containsKey('evidence_deadline_at')) {
      context.handle(
        _evidenceDeadlineAtMeta,
        evidenceDeadlineAt.isAcceptableOrUnknown(
          data['evidence_deadline_at']!,
          _evidenceDeadlineAtMeta,
        ),
      );
    }
    if (data.containsKey('change_reason')) {
      context.handle(
        _changeReasonMeta,
        changeReason.isAcceptableOrUnknown(
          data['change_reason']!,
          _changeReasonMeta,
        ),
      );
    }
    if (data.containsKey('changed_at')) {
      context.handle(
        _changedAtMeta,
        changedAt.isAcceptableOrUnknown(data['changed_at']!, _changedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_changedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
    {missionId, revisionNumber},
  ];
  @override
  MissionScheduleRevisionRow map(
    Map<String, dynamic> data, {
    String? tablePrefix,
  }) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return MissionScheduleRevisionRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      missionId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}mission_id'],
      )!,
      revisionNumber: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}revision_number'],
      )!,
      scheduledDate: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}scheduled_date'],
      )!,
      timeZone: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}time_zone'],
      )!,
      timePolicy: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}time_policy'],
      )!,
      fixedStartAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}fixed_start_at'],
      ),
      plannedDurationMinutes: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}planned_duration_minutes'],
      )!,
      evidenceDeadlineAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}evidence_deadline_at'],
      ),
      changeReason: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}change_reason'],
      ),
      changedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}changed_at'],
      )!,
    );
  }

  @override
  $MissionScheduleRevisionsTable createAlias(String alias) {
    return $MissionScheduleRevisionsTable(attachedDatabase, alias);
  }
}

class MissionScheduleRevisionRow extends DataClass
    implements Insertable<MissionScheduleRevisionRow> {
  final String id;
  final String missionId;
  final int revisionNumber;
  final String scheduledDate;
  final String timeZone;
  final String timePolicy;
  final int? fixedStartAt;
  final int plannedDurationMinutes;
  final int? evidenceDeadlineAt;
  final String? changeReason;
  final int changedAt;
  const MissionScheduleRevisionRow({
    required this.id,
    required this.missionId,
    required this.revisionNumber,
    required this.scheduledDate,
    required this.timeZone,
    required this.timePolicy,
    this.fixedStartAt,
    required this.plannedDurationMinutes,
    this.evidenceDeadlineAt,
    this.changeReason,
    required this.changedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['mission_id'] = Variable<String>(missionId);
    map['revision_number'] = Variable<int>(revisionNumber);
    map['scheduled_date'] = Variable<String>(scheduledDate);
    map['time_zone'] = Variable<String>(timeZone);
    map['time_policy'] = Variable<String>(timePolicy);
    if (!nullToAbsent || fixedStartAt != null) {
      map['fixed_start_at'] = Variable<int>(fixedStartAt);
    }
    map['planned_duration_minutes'] = Variable<int>(plannedDurationMinutes);
    if (!nullToAbsent || evidenceDeadlineAt != null) {
      map['evidence_deadline_at'] = Variable<int>(evidenceDeadlineAt);
    }
    if (!nullToAbsent || changeReason != null) {
      map['change_reason'] = Variable<String>(changeReason);
    }
    map['changed_at'] = Variable<int>(changedAt);
    return map;
  }

  MissionScheduleRevisionsCompanion toCompanion(bool nullToAbsent) {
    return MissionScheduleRevisionsCompanion(
      id: Value(id),
      missionId: Value(missionId),
      revisionNumber: Value(revisionNumber),
      scheduledDate: Value(scheduledDate),
      timeZone: Value(timeZone),
      timePolicy: Value(timePolicy),
      fixedStartAt: fixedStartAt == null && nullToAbsent
          ? const Value.absent()
          : Value(fixedStartAt),
      plannedDurationMinutes: Value(plannedDurationMinutes),
      evidenceDeadlineAt: evidenceDeadlineAt == null && nullToAbsent
          ? const Value.absent()
          : Value(evidenceDeadlineAt),
      changeReason: changeReason == null && nullToAbsent
          ? const Value.absent()
          : Value(changeReason),
      changedAt: Value(changedAt),
    );
  }

  factory MissionScheduleRevisionRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return MissionScheduleRevisionRow(
      id: serializer.fromJson<String>(json['id']),
      missionId: serializer.fromJson<String>(json['missionId']),
      revisionNumber: serializer.fromJson<int>(json['revisionNumber']),
      scheduledDate: serializer.fromJson<String>(json['scheduledDate']),
      timeZone: serializer.fromJson<String>(json['timeZone']),
      timePolicy: serializer.fromJson<String>(json['timePolicy']),
      fixedStartAt: serializer.fromJson<int?>(json['fixedStartAt']),
      plannedDurationMinutes: serializer.fromJson<int>(
        json['plannedDurationMinutes'],
      ),
      evidenceDeadlineAt: serializer.fromJson<int?>(json['evidenceDeadlineAt']),
      changeReason: serializer.fromJson<String?>(json['changeReason']),
      changedAt: serializer.fromJson<int>(json['changedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'missionId': serializer.toJson<String>(missionId),
      'revisionNumber': serializer.toJson<int>(revisionNumber),
      'scheduledDate': serializer.toJson<String>(scheduledDate),
      'timeZone': serializer.toJson<String>(timeZone),
      'timePolicy': serializer.toJson<String>(timePolicy),
      'fixedStartAt': serializer.toJson<int?>(fixedStartAt),
      'plannedDurationMinutes': serializer.toJson<int>(plannedDurationMinutes),
      'evidenceDeadlineAt': serializer.toJson<int?>(evidenceDeadlineAt),
      'changeReason': serializer.toJson<String?>(changeReason),
      'changedAt': serializer.toJson<int>(changedAt),
    };
  }

  MissionScheduleRevisionRow copyWith({
    String? id,
    String? missionId,
    int? revisionNumber,
    String? scheduledDate,
    String? timeZone,
    String? timePolicy,
    Value<int?> fixedStartAt = const Value.absent(),
    int? plannedDurationMinutes,
    Value<int?> evidenceDeadlineAt = const Value.absent(),
    Value<String?> changeReason = const Value.absent(),
    int? changedAt,
  }) => MissionScheduleRevisionRow(
    id: id ?? this.id,
    missionId: missionId ?? this.missionId,
    revisionNumber: revisionNumber ?? this.revisionNumber,
    scheduledDate: scheduledDate ?? this.scheduledDate,
    timeZone: timeZone ?? this.timeZone,
    timePolicy: timePolicy ?? this.timePolicy,
    fixedStartAt: fixedStartAt.present ? fixedStartAt.value : this.fixedStartAt,
    plannedDurationMinutes:
        plannedDurationMinutes ?? this.plannedDurationMinutes,
    evidenceDeadlineAt: evidenceDeadlineAt.present
        ? evidenceDeadlineAt.value
        : this.evidenceDeadlineAt,
    changeReason: changeReason.present ? changeReason.value : this.changeReason,
    changedAt: changedAt ?? this.changedAt,
  );
  MissionScheduleRevisionRow copyWithCompanion(
    MissionScheduleRevisionsCompanion data,
  ) {
    return MissionScheduleRevisionRow(
      id: data.id.present ? data.id.value : this.id,
      missionId: data.missionId.present ? data.missionId.value : this.missionId,
      revisionNumber: data.revisionNumber.present
          ? data.revisionNumber.value
          : this.revisionNumber,
      scheduledDate: data.scheduledDate.present
          ? data.scheduledDate.value
          : this.scheduledDate,
      timeZone: data.timeZone.present ? data.timeZone.value : this.timeZone,
      timePolicy: data.timePolicy.present
          ? data.timePolicy.value
          : this.timePolicy,
      fixedStartAt: data.fixedStartAt.present
          ? data.fixedStartAt.value
          : this.fixedStartAt,
      plannedDurationMinutes: data.plannedDurationMinutes.present
          ? data.plannedDurationMinutes.value
          : this.plannedDurationMinutes,
      evidenceDeadlineAt: data.evidenceDeadlineAt.present
          ? data.evidenceDeadlineAt.value
          : this.evidenceDeadlineAt,
      changeReason: data.changeReason.present
          ? data.changeReason.value
          : this.changeReason,
      changedAt: data.changedAt.present ? data.changedAt.value : this.changedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('MissionScheduleRevisionRow(')
          ..write('id: $id, ')
          ..write('missionId: $missionId, ')
          ..write('revisionNumber: $revisionNumber, ')
          ..write('scheduledDate: $scheduledDate, ')
          ..write('timeZone: $timeZone, ')
          ..write('timePolicy: $timePolicy, ')
          ..write('fixedStartAt: $fixedStartAt, ')
          ..write('plannedDurationMinutes: $plannedDurationMinutes, ')
          ..write('evidenceDeadlineAt: $evidenceDeadlineAt, ')
          ..write('changeReason: $changeReason, ')
          ..write('changedAt: $changedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    missionId,
    revisionNumber,
    scheduledDate,
    timeZone,
    timePolicy,
    fixedStartAt,
    plannedDurationMinutes,
    evidenceDeadlineAt,
    changeReason,
    changedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is MissionScheduleRevisionRow &&
          other.id == this.id &&
          other.missionId == this.missionId &&
          other.revisionNumber == this.revisionNumber &&
          other.scheduledDate == this.scheduledDate &&
          other.timeZone == this.timeZone &&
          other.timePolicy == this.timePolicy &&
          other.fixedStartAt == this.fixedStartAt &&
          other.plannedDurationMinutes == this.plannedDurationMinutes &&
          other.evidenceDeadlineAt == this.evidenceDeadlineAt &&
          other.changeReason == this.changeReason &&
          other.changedAt == this.changedAt);
}

class MissionScheduleRevisionsCompanion
    extends UpdateCompanion<MissionScheduleRevisionRow> {
  final Value<String> id;
  final Value<String> missionId;
  final Value<int> revisionNumber;
  final Value<String> scheduledDate;
  final Value<String> timeZone;
  final Value<String> timePolicy;
  final Value<int?> fixedStartAt;
  final Value<int> plannedDurationMinutes;
  final Value<int?> evidenceDeadlineAt;
  final Value<String?> changeReason;
  final Value<int> changedAt;
  final Value<int> rowid;
  const MissionScheduleRevisionsCompanion({
    this.id = const Value.absent(),
    this.missionId = const Value.absent(),
    this.revisionNumber = const Value.absent(),
    this.scheduledDate = const Value.absent(),
    this.timeZone = const Value.absent(),
    this.timePolicy = const Value.absent(),
    this.fixedStartAt = const Value.absent(),
    this.plannedDurationMinutes = const Value.absent(),
    this.evidenceDeadlineAt = const Value.absent(),
    this.changeReason = const Value.absent(),
    this.changedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  MissionScheduleRevisionsCompanion.insert({
    required String id,
    required String missionId,
    required int revisionNumber,
    required String scheduledDate,
    required String timeZone,
    this.timePolicy = const Value.absent(),
    this.fixedStartAt = const Value.absent(),
    required int plannedDurationMinutes,
    this.evidenceDeadlineAt = const Value.absent(),
    this.changeReason = const Value.absent(),
    required int changedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       missionId = Value(missionId),
       revisionNumber = Value(revisionNumber),
       scheduledDate = Value(scheduledDate),
       timeZone = Value(timeZone),
       plannedDurationMinutes = Value(plannedDurationMinutes),
       changedAt = Value(changedAt);
  static Insertable<MissionScheduleRevisionRow> custom({
    Expression<String>? id,
    Expression<String>? missionId,
    Expression<int>? revisionNumber,
    Expression<String>? scheduledDate,
    Expression<String>? timeZone,
    Expression<String>? timePolicy,
    Expression<int>? fixedStartAt,
    Expression<int>? plannedDurationMinutes,
    Expression<int>? evidenceDeadlineAt,
    Expression<String>? changeReason,
    Expression<int>? changedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (missionId != null) 'mission_id': missionId,
      if (revisionNumber != null) 'revision_number': revisionNumber,
      if (scheduledDate != null) 'scheduled_date': scheduledDate,
      if (timeZone != null) 'time_zone': timeZone,
      if (timePolicy != null) 'time_policy': timePolicy,
      if (fixedStartAt != null) 'fixed_start_at': fixedStartAt,
      if (plannedDurationMinutes != null)
        'planned_duration_minutes': plannedDurationMinutes,
      if (evidenceDeadlineAt != null)
        'evidence_deadline_at': evidenceDeadlineAt,
      if (changeReason != null) 'change_reason': changeReason,
      if (changedAt != null) 'changed_at': changedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  MissionScheduleRevisionsCompanion copyWith({
    Value<String>? id,
    Value<String>? missionId,
    Value<int>? revisionNumber,
    Value<String>? scheduledDate,
    Value<String>? timeZone,
    Value<String>? timePolicy,
    Value<int?>? fixedStartAt,
    Value<int>? plannedDurationMinutes,
    Value<int?>? evidenceDeadlineAt,
    Value<String?>? changeReason,
    Value<int>? changedAt,
    Value<int>? rowid,
  }) {
    return MissionScheduleRevisionsCompanion(
      id: id ?? this.id,
      missionId: missionId ?? this.missionId,
      revisionNumber: revisionNumber ?? this.revisionNumber,
      scheduledDate: scheduledDate ?? this.scheduledDate,
      timeZone: timeZone ?? this.timeZone,
      timePolicy: timePolicy ?? this.timePolicy,
      fixedStartAt: fixedStartAt ?? this.fixedStartAt,
      plannedDurationMinutes:
          plannedDurationMinutes ?? this.plannedDurationMinutes,
      evidenceDeadlineAt: evidenceDeadlineAt ?? this.evidenceDeadlineAt,
      changeReason: changeReason ?? this.changeReason,
      changedAt: changedAt ?? this.changedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (missionId.present) {
      map['mission_id'] = Variable<String>(missionId.value);
    }
    if (revisionNumber.present) {
      map['revision_number'] = Variable<int>(revisionNumber.value);
    }
    if (scheduledDate.present) {
      map['scheduled_date'] = Variable<String>(scheduledDate.value);
    }
    if (timeZone.present) {
      map['time_zone'] = Variable<String>(timeZone.value);
    }
    if (timePolicy.present) {
      map['time_policy'] = Variable<String>(timePolicy.value);
    }
    if (fixedStartAt.present) {
      map['fixed_start_at'] = Variable<int>(fixedStartAt.value);
    }
    if (plannedDurationMinutes.present) {
      map['planned_duration_minutes'] = Variable<int>(
        plannedDurationMinutes.value,
      );
    }
    if (evidenceDeadlineAt.present) {
      map['evidence_deadline_at'] = Variable<int>(evidenceDeadlineAt.value);
    }
    if (changeReason.present) {
      map['change_reason'] = Variable<String>(changeReason.value);
    }
    if (changedAt.present) {
      map['changed_at'] = Variable<int>(changedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('MissionScheduleRevisionsCompanion(')
          ..write('id: $id, ')
          ..write('missionId: $missionId, ')
          ..write('revisionNumber: $revisionNumber, ')
          ..write('scheduledDate: $scheduledDate, ')
          ..write('timeZone: $timeZone, ')
          ..write('timePolicy: $timePolicy, ')
          ..write('fixedStartAt: $fixedStartAt, ')
          ..write('plannedDurationMinutes: $plannedDurationMinutes, ')
          ..write('evidenceDeadlineAt: $evidenceDeadlineAt, ')
          ..write('changeReason: $changeReason, ')
          ..write('changedAt: $changedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ExecutionPlansTable extends ExecutionPlans
    with TableInfo<$ExecutionPlansTable, ExecutionPlanRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ExecutionPlansTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _missionIdMeta = const VerificationMeta(
    'missionId',
  );
  @override
  late final GeneratedColumn<String> missionId = GeneratedColumn<String>(
    'mission_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'UNIQUE REFERENCES missions (id)',
    ),
  );
  static const VerificationMeta _objectiveMeta = const VerificationMeta(
    'objective',
  );
  @override
  late final GeneratedColumn<String> objective = GeneratedColumn<String>(
    'objective',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _stepsMeta = const VerificationMeta('steps');
  @override
  late final GeneratedColumn<String> steps = GeneratedColumn<String>(
    'steps',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('[]'),
  );
  static const VerificationMeta _verificationCriteriaMeta =
      const VerificationMeta('verificationCriteria');
  @override
  late final GeneratedColumn<String> verificationCriteria =
      GeneratedColumn<String>(
        'verification_criteria',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _notesMeta = const VerificationMeta('notes');
  @override
  late final GeneratedColumn<String> notes = GeneratedColumn<String>(
    'notes',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<int> updatedAt = GeneratedColumn<int>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    missionId,
    objective,
    steps,
    verificationCriteria,
    notes,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'execution_plans';
  @override
  VerificationContext validateIntegrity(
    Insertable<ExecutionPlanRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('mission_id')) {
      context.handle(
        _missionIdMeta,
        missionId.isAcceptableOrUnknown(data['mission_id']!, _missionIdMeta),
      );
    } else if (isInserting) {
      context.missing(_missionIdMeta);
    }
    if (data.containsKey('objective')) {
      context.handle(
        _objectiveMeta,
        objective.isAcceptableOrUnknown(data['objective']!, _objectiveMeta),
      );
    } else if (isInserting) {
      context.missing(_objectiveMeta);
    }
    if (data.containsKey('steps')) {
      context.handle(
        _stepsMeta,
        steps.isAcceptableOrUnknown(data['steps']!, _stepsMeta),
      );
    }
    if (data.containsKey('verification_criteria')) {
      context.handle(
        _verificationCriteriaMeta,
        verificationCriteria.isAcceptableOrUnknown(
          data['verification_criteria']!,
          _verificationCriteriaMeta,
        ),
      );
    }
    if (data.containsKey('notes')) {
      context.handle(
        _notesMeta,
        notes.isAcceptableOrUnknown(data['notes']!, _notesMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ExecutionPlanRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ExecutionPlanRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      missionId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}mission_id'],
      )!,
      objective: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}objective'],
      )!,
      steps: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}steps'],
      )!,
      verificationCriteria: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}verification_criteria'],
      ),
      notes: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}notes'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $ExecutionPlansTable createAlias(String alias) {
    return $ExecutionPlansTable(attachedDatabase, alias);
  }
}

class ExecutionPlanRow extends DataClass
    implements Insertable<ExecutionPlanRow> {
  final String id;
  final String missionId;
  final String objective;
  final String steps;
  final String? verificationCriteria;
  final String? notes;
  final int createdAt;
  final int updatedAt;
  const ExecutionPlanRow({
    required this.id,
    required this.missionId,
    required this.objective,
    required this.steps,
    this.verificationCriteria,
    this.notes,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['mission_id'] = Variable<String>(missionId);
    map['objective'] = Variable<String>(objective);
    map['steps'] = Variable<String>(steps);
    if (!nullToAbsent || verificationCriteria != null) {
      map['verification_criteria'] = Variable<String>(verificationCriteria);
    }
    if (!nullToAbsent || notes != null) {
      map['notes'] = Variable<String>(notes);
    }
    map['created_at'] = Variable<int>(createdAt);
    map['updated_at'] = Variable<int>(updatedAt);
    return map;
  }

  ExecutionPlansCompanion toCompanion(bool nullToAbsent) {
    return ExecutionPlansCompanion(
      id: Value(id),
      missionId: Value(missionId),
      objective: Value(objective),
      steps: Value(steps),
      verificationCriteria: verificationCriteria == null && nullToAbsent
          ? const Value.absent()
          : Value(verificationCriteria),
      notes: notes == null && nullToAbsent
          ? const Value.absent()
          : Value(notes),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory ExecutionPlanRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ExecutionPlanRow(
      id: serializer.fromJson<String>(json['id']),
      missionId: serializer.fromJson<String>(json['missionId']),
      objective: serializer.fromJson<String>(json['objective']),
      steps: serializer.fromJson<String>(json['steps']),
      verificationCriteria: serializer.fromJson<String?>(
        json['verificationCriteria'],
      ),
      notes: serializer.fromJson<String?>(json['notes']),
      createdAt: serializer.fromJson<int>(json['createdAt']),
      updatedAt: serializer.fromJson<int>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'missionId': serializer.toJson<String>(missionId),
      'objective': serializer.toJson<String>(objective),
      'steps': serializer.toJson<String>(steps),
      'verificationCriteria': serializer.toJson<String?>(verificationCriteria),
      'notes': serializer.toJson<String?>(notes),
      'createdAt': serializer.toJson<int>(createdAt),
      'updatedAt': serializer.toJson<int>(updatedAt),
    };
  }

  ExecutionPlanRow copyWith({
    String? id,
    String? missionId,
    String? objective,
    String? steps,
    Value<String?> verificationCriteria = const Value.absent(),
    Value<String?> notes = const Value.absent(),
    int? createdAt,
    int? updatedAt,
  }) => ExecutionPlanRow(
    id: id ?? this.id,
    missionId: missionId ?? this.missionId,
    objective: objective ?? this.objective,
    steps: steps ?? this.steps,
    verificationCriteria: verificationCriteria.present
        ? verificationCriteria.value
        : this.verificationCriteria,
    notes: notes.present ? notes.value : this.notes,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  ExecutionPlanRow copyWithCompanion(ExecutionPlansCompanion data) {
    return ExecutionPlanRow(
      id: data.id.present ? data.id.value : this.id,
      missionId: data.missionId.present ? data.missionId.value : this.missionId,
      objective: data.objective.present ? data.objective.value : this.objective,
      steps: data.steps.present ? data.steps.value : this.steps,
      verificationCriteria: data.verificationCriteria.present
          ? data.verificationCriteria.value
          : this.verificationCriteria,
      notes: data.notes.present ? data.notes.value : this.notes,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ExecutionPlanRow(')
          ..write('id: $id, ')
          ..write('missionId: $missionId, ')
          ..write('objective: $objective, ')
          ..write('steps: $steps, ')
          ..write('verificationCriteria: $verificationCriteria, ')
          ..write('notes: $notes, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    missionId,
    objective,
    steps,
    verificationCriteria,
    notes,
    createdAt,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ExecutionPlanRow &&
          other.id == this.id &&
          other.missionId == this.missionId &&
          other.objective == this.objective &&
          other.steps == this.steps &&
          other.verificationCriteria == this.verificationCriteria &&
          other.notes == this.notes &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class ExecutionPlansCompanion extends UpdateCompanion<ExecutionPlanRow> {
  final Value<String> id;
  final Value<String> missionId;
  final Value<String> objective;
  final Value<String> steps;
  final Value<String?> verificationCriteria;
  final Value<String?> notes;
  final Value<int> createdAt;
  final Value<int> updatedAt;
  final Value<int> rowid;
  const ExecutionPlansCompanion({
    this.id = const Value.absent(),
    this.missionId = const Value.absent(),
    this.objective = const Value.absent(),
    this.steps = const Value.absent(),
    this.verificationCriteria = const Value.absent(),
    this.notes = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ExecutionPlansCompanion.insert({
    required String id,
    required String missionId,
    required String objective,
    this.steps = const Value.absent(),
    this.verificationCriteria = const Value.absent(),
    this.notes = const Value.absent(),
    required int createdAt,
    required int updatedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       missionId = Value(missionId),
       objective = Value(objective),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<ExecutionPlanRow> custom({
    Expression<String>? id,
    Expression<String>? missionId,
    Expression<String>? objective,
    Expression<String>? steps,
    Expression<String>? verificationCriteria,
    Expression<String>? notes,
    Expression<int>? createdAt,
    Expression<int>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (missionId != null) 'mission_id': missionId,
      if (objective != null) 'objective': objective,
      if (steps != null) 'steps': steps,
      if (verificationCriteria != null)
        'verification_criteria': verificationCriteria,
      if (notes != null) 'notes': notes,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ExecutionPlansCompanion copyWith({
    Value<String>? id,
    Value<String>? missionId,
    Value<String>? objective,
    Value<String>? steps,
    Value<String?>? verificationCriteria,
    Value<String?>? notes,
    Value<int>? createdAt,
    Value<int>? updatedAt,
    Value<int>? rowid,
  }) {
    return ExecutionPlansCompanion(
      id: id ?? this.id,
      missionId: missionId ?? this.missionId,
      objective: objective ?? this.objective,
      steps: steps ?? this.steps,
      verificationCriteria: verificationCriteria ?? this.verificationCriteria,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (missionId.present) {
      map['mission_id'] = Variable<String>(missionId.value);
    }
    if (objective.present) {
      map['objective'] = Variable<String>(objective.value);
    }
    if (steps.present) {
      map['steps'] = Variable<String>(steps.value);
    }
    if (verificationCriteria.present) {
      map['verification_criteria'] = Variable<String>(
        verificationCriteria.value,
      );
    }
    if (notes.present) {
      map['notes'] = Variable<String>(notes.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ExecutionPlansCompanion(')
          ..write('id: $id, ')
          ..write('missionId: $missionId, ')
          ..write('objective: $objective, ')
          ..write('steps: $steps, ')
          ..write('verificationCriteria: $verificationCriteria, ')
          ..write('notes: $notes, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ExecutionEventsTable extends ExecutionEvents
    with TableInfo<$ExecutionEventsTable, ExecutionEventRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ExecutionEventsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _missionIdMeta = const VerificationMeta(
    'missionId',
  );
  @override
  late final GeneratedColumn<String> missionId = GeneratedColumn<String>(
    'mission_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES missions (id)',
    ),
  );
  static const VerificationMeta _sequenceMeta = const VerificationMeta(
    'sequence',
  );
  @override
  late final GeneratedColumn<int> sequence = GeneratedColumn<int>(
    'sequence',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _typeMeta = const VerificationMeta('type');
  @override
  late final GeneratedColumn<String> type = GeneratedColumn<String>(
    'type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _occurredAtMeta = const VerificationMeta(
    'occurredAt',
  );
  @override
  late final GeneratedColumn<int> occurredAt = GeneratedColumn<int>(
    'occurred_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _scheduleRevisionIdMeta =
      const VerificationMeta('scheduleRevisionId');
  @override
  late final GeneratedColumn<String> scheduleRevisionId =
      GeneratedColumn<String>(
        'schedule_revision_id',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
        defaultConstraints: GeneratedColumn.constraintIsAlways(
          'REFERENCES mission_schedule_revisions (id)',
        ),
      );
  static const VerificationMeta _grantedDurationMinutesMeta =
      const VerificationMeta('grantedDurationMinutes');
  @override
  late final GeneratedColumn<int> grantedDurationMinutes = GeneratedColumn<int>(
    'granted_duration_minutes',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _reasonMeta = const VerificationMeta('reason');
  @override
  late final GeneratedColumn<String> reason = GeneratedColumn<String>(
    'reason',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _userReportedResultMeta =
      const VerificationMeta('userReportedResult');
  @override
  late final GeneratedColumn<String> userReportedResult =
      GeneratedColumn<String>(
        'user_reported_result',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _submitOptionalEvidenceMeta =
      const VerificationMeta('submitOptionalEvidence');
  @override
  late final GeneratedColumn<bool> submitOptionalEvidence =
      GeneratedColumn<bool>(
        'submit_optional_evidence',
        aliasedName,
        true,
        type: DriftSqlType.bool,
        requiredDuringInsert: false,
        defaultConstraints: GeneratedColumn.constraintIsAlways(
          'CHECK ("submit_optional_evidence" IN (0, 1))',
        ),
      );
  static const VerificationMeta _isRetrospectiveMeta = const VerificationMeta(
    'isRetrospective',
  );
  @override
  late final GeneratedColumn<bool> isRetrospective = GeneratedColumn<bool>(
    'is_retrospective',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_retrospective" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    missionId,
    sequence,
    type,
    occurredAt,
    scheduleRevisionId,
    grantedDurationMinutes,
    reason,
    userReportedResult,
    submitOptionalEvidence,
    isRetrospective,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'execution_events';
  @override
  VerificationContext validateIntegrity(
    Insertable<ExecutionEventRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('mission_id')) {
      context.handle(
        _missionIdMeta,
        missionId.isAcceptableOrUnknown(data['mission_id']!, _missionIdMeta),
      );
    } else if (isInserting) {
      context.missing(_missionIdMeta);
    }
    if (data.containsKey('sequence')) {
      context.handle(
        _sequenceMeta,
        sequence.isAcceptableOrUnknown(data['sequence']!, _sequenceMeta),
      );
    } else if (isInserting) {
      context.missing(_sequenceMeta);
    }
    if (data.containsKey('type')) {
      context.handle(
        _typeMeta,
        type.isAcceptableOrUnknown(data['type']!, _typeMeta),
      );
    } else if (isInserting) {
      context.missing(_typeMeta);
    }
    if (data.containsKey('occurred_at')) {
      context.handle(
        _occurredAtMeta,
        occurredAt.isAcceptableOrUnknown(data['occurred_at']!, _occurredAtMeta),
      );
    } else if (isInserting) {
      context.missing(_occurredAtMeta);
    }
    if (data.containsKey('schedule_revision_id')) {
      context.handle(
        _scheduleRevisionIdMeta,
        scheduleRevisionId.isAcceptableOrUnknown(
          data['schedule_revision_id']!,
          _scheduleRevisionIdMeta,
        ),
      );
    }
    if (data.containsKey('granted_duration_minutes')) {
      context.handle(
        _grantedDurationMinutesMeta,
        grantedDurationMinutes.isAcceptableOrUnknown(
          data['granted_duration_minutes']!,
          _grantedDurationMinutesMeta,
        ),
      );
    }
    if (data.containsKey('reason')) {
      context.handle(
        _reasonMeta,
        reason.isAcceptableOrUnknown(data['reason']!, _reasonMeta),
      );
    }
    if (data.containsKey('user_reported_result')) {
      context.handle(
        _userReportedResultMeta,
        userReportedResult.isAcceptableOrUnknown(
          data['user_reported_result']!,
          _userReportedResultMeta,
        ),
      );
    }
    if (data.containsKey('submit_optional_evidence')) {
      context.handle(
        _submitOptionalEvidenceMeta,
        submitOptionalEvidence.isAcceptableOrUnknown(
          data['submit_optional_evidence']!,
          _submitOptionalEvidenceMeta,
        ),
      );
    }
    if (data.containsKey('is_retrospective')) {
      context.handle(
        _isRetrospectiveMeta,
        isRetrospective.isAcceptableOrUnknown(
          data['is_retrospective']!,
          _isRetrospectiveMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
    {missionId, sequence},
  ];
  @override
  ExecutionEventRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ExecutionEventRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      missionId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}mission_id'],
      )!,
      sequence: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sequence'],
      )!,
      type: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}type'],
      )!,
      occurredAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}occurred_at'],
      )!,
      scheduleRevisionId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}schedule_revision_id'],
      ),
      grantedDurationMinutes: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}granted_duration_minutes'],
      ),
      reason: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}reason'],
      ),
      userReportedResult: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}user_reported_result'],
      ),
      submitOptionalEvidence: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}submit_optional_evidence'],
      ),
      isRetrospective: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_retrospective'],
      )!,
    );
  }

  @override
  $ExecutionEventsTable createAlias(String alias) {
    return $ExecutionEventsTable(attachedDatabase, alias);
  }
}

class ExecutionEventRow extends DataClass
    implements Insertable<ExecutionEventRow> {
  final String id;
  final String missionId;
  final int sequence;
  final String type;
  final int occurredAt;
  final String? scheduleRevisionId;
  final int? grantedDurationMinutes;
  final String? reason;
  final String? userReportedResult;
  final bool? submitOptionalEvidence;
  final bool isRetrospective;
  const ExecutionEventRow({
    required this.id,
    required this.missionId,
    required this.sequence,
    required this.type,
    required this.occurredAt,
    this.scheduleRevisionId,
    this.grantedDurationMinutes,
    this.reason,
    this.userReportedResult,
    this.submitOptionalEvidence,
    required this.isRetrospective,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['mission_id'] = Variable<String>(missionId);
    map['sequence'] = Variable<int>(sequence);
    map['type'] = Variable<String>(type);
    map['occurred_at'] = Variable<int>(occurredAt);
    if (!nullToAbsent || scheduleRevisionId != null) {
      map['schedule_revision_id'] = Variable<String>(scheduleRevisionId);
    }
    if (!nullToAbsent || grantedDurationMinutes != null) {
      map['granted_duration_minutes'] = Variable<int>(grantedDurationMinutes);
    }
    if (!nullToAbsent || reason != null) {
      map['reason'] = Variable<String>(reason);
    }
    if (!nullToAbsent || userReportedResult != null) {
      map['user_reported_result'] = Variable<String>(userReportedResult);
    }
    if (!nullToAbsent || submitOptionalEvidence != null) {
      map['submit_optional_evidence'] = Variable<bool>(submitOptionalEvidence);
    }
    map['is_retrospective'] = Variable<bool>(isRetrospective);
    return map;
  }

  ExecutionEventsCompanion toCompanion(bool nullToAbsent) {
    return ExecutionEventsCompanion(
      id: Value(id),
      missionId: Value(missionId),
      sequence: Value(sequence),
      type: Value(type),
      occurredAt: Value(occurredAt),
      scheduleRevisionId: scheduleRevisionId == null && nullToAbsent
          ? const Value.absent()
          : Value(scheduleRevisionId),
      grantedDurationMinutes: grantedDurationMinutes == null && nullToAbsent
          ? const Value.absent()
          : Value(grantedDurationMinutes),
      reason: reason == null && nullToAbsent
          ? const Value.absent()
          : Value(reason),
      userReportedResult: userReportedResult == null && nullToAbsent
          ? const Value.absent()
          : Value(userReportedResult),
      submitOptionalEvidence: submitOptionalEvidence == null && nullToAbsent
          ? const Value.absent()
          : Value(submitOptionalEvidence),
      isRetrospective: Value(isRetrospective),
    );
  }

  factory ExecutionEventRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ExecutionEventRow(
      id: serializer.fromJson<String>(json['id']),
      missionId: serializer.fromJson<String>(json['missionId']),
      sequence: serializer.fromJson<int>(json['sequence']),
      type: serializer.fromJson<String>(json['type']),
      occurredAt: serializer.fromJson<int>(json['occurredAt']),
      scheduleRevisionId: serializer.fromJson<String?>(
        json['scheduleRevisionId'],
      ),
      grantedDurationMinutes: serializer.fromJson<int?>(
        json['grantedDurationMinutes'],
      ),
      reason: serializer.fromJson<String?>(json['reason']),
      userReportedResult: serializer.fromJson<String?>(
        json['userReportedResult'],
      ),
      submitOptionalEvidence: serializer.fromJson<bool?>(
        json['submitOptionalEvidence'],
      ),
      isRetrospective: serializer.fromJson<bool>(json['isRetrospective']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'missionId': serializer.toJson<String>(missionId),
      'sequence': serializer.toJson<int>(sequence),
      'type': serializer.toJson<String>(type),
      'occurredAt': serializer.toJson<int>(occurredAt),
      'scheduleRevisionId': serializer.toJson<String?>(scheduleRevisionId),
      'grantedDurationMinutes': serializer.toJson<int?>(grantedDurationMinutes),
      'reason': serializer.toJson<String?>(reason),
      'userReportedResult': serializer.toJson<String?>(userReportedResult),
      'submitOptionalEvidence': serializer.toJson<bool?>(
        submitOptionalEvidence,
      ),
      'isRetrospective': serializer.toJson<bool>(isRetrospective),
    };
  }

  ExecutionEventRow copyWith({
    String? id,
    String? missionId,
    int? sequence,
    String? type,
    int? occurredAt,
    Value<String?> scheduleRevisionId = const Value.absent(),
    Value<int?> grantedDurationMinutes = const Value.absent(),
    Value<String?> reason = const Value.absent(),
    Value<String?> userReportedResult = const Value.absent(),
    Value<bool?> submitOptionalEvidence = const Value.absent(),
    bool? isRetrospective,
  }) => ExecutionEventRow(
    id: id ?? this.id,
    missionId: missionId ?? this.missionId,
    sequence: sequence ?? this.sequence,
    type: type ?? this.type,
    occurredAt: occurredAt ?? this.occurredAt,
    scheduleRevisionId: scheduleRevisionId.present
        ? scheduleRevisionId.value
        : this.scheduleRevisionId,
    grantedDurationMinutes: grantedDurationMinutes.present
        ? grantedDurationMinutes.value
        : this.grantedDurationMinutes,
    reason: reason.present ? reason.value : this.reason,
    userReportedResult: userReportedResult.present
        ? userReportedResult.value
        : this.userReportedResult,
    submitOptionalEvidence: submitOptionalEvidence.present
        ? submitOptionalEvidence.value
        : this.submitOptionalEvidence,
    isRetrospective: isRetrospective ?? this.isRetrospective,
  );
  ExecutionEventRow copyWithCompanion(ExecutionEventsCompanion data) {
    return ExecutionEventRow(
      id: data.id.present ? data.id.value : this.id,
      missionId: data.missionId.present ? data.missionId.value : this.missionId,
      sequence: data.sequence.present ? data.sequence.value : this.sequence,
      type: data.type.present ? data.type.value : this.type,
      occurredAt: data.occurredAt.present
          ? data.occurredAt.value
          : this.occurredAt,
      scheduleRevisionId: data.scheduleRevisionId.present
          ? data.scheduleRevisionId.value
          : this.scheduleRevisionId,
      grantedDurationMinutes: data.grantedDurationMinutes.present
          ? data.grantedDurationMinutes.value
          : this.grantedDurationMinutes,
      reason: data.reason.present ? data.reason.value : this.reason,
      userReportedResult: data.userReportedResult.present
          ? data.userReportedResult.value
          : this.userReportedResult,
      submitOptionalEvidence: data.submitOptionalEvidence.present
          ? data.submitOptionalEvidence.value
          : this.submitOptionalEvidence,
      isRetrospective: data.isRetrospective.present
          ? data.isRetrospective.value
          : this.isRetrospective,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ExecutionEventRow(')
          ..write('id: $id, ')
          ..write('missionId: $missionId, ')
          ..write('sequence: $sequence, ')
          ..write('type: $type, ')
          ..write('occurredAt: $occurredAt, ')
          ..write('scheduleRevisionId: $scheduleRevisionId, ')
          ..write('grantedDurationMinutes: $grantedDurationMinutes, ')
          ..write('reason: $reason, ')
          ..write('userReportedResult: $userReportedResult, ')
          ..write('submitOptionalEvidence: $submitOptionalEvidence, ')
          ..write('isRetrospective: $isRetrospective')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    missionId,
    sequence,
    type,
    occurredAt,
    scheduleRevisionId,
    grantedDurationMinutes,
    reason,
    userReportedResult,
    submitOptionalEvidence,
    isRetrospective,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ExecutionEventRow &&
          other.id == this.id &&
          other.missionId == this.missionId &&
          other.sequence == this.sequence &&
          other.type == this.type &&
          other.occurredAt == this.occurredAt &&
          other.scheduleRevisionId == this.scheduleRevisionId &&
          other.grantedDurationMinutes == this.grantedDurationMinutes &&
          other.reason == this.reason &&
          other.userReportedResult == this.userReportedResult &&
          other.submitOptionalEvidence == this.submitOptionalEvidence &&
          other.isRetrospective == this.isRetrospective);
}

class ExecutionEventsCompanion extends UpdateCompanion<ExecutionEventRow> {
  final Value<String> id;
  final Value<String> missionId;
  final Value<int> sequence;
  final Value<String> type;
  final Value<int> occurredAt;
  final Value<String?> scheduleRevisionId;
  final Value<int?> grantedDurationMinutes;
  final Value<String?> reason;
  final Value<String?> userReportedResult;
  final Value<bool?> submitOptionalEvidence;
  final Value<bool> isRetrospective;
  final Value<int> rowid;
  const ExecutionEventsCompanion({
    this.id = const Value.absent(),
    this.missionId = const Value.absent(),
    this.sequence = const Value.absent(),
    this.type = const Value.absent(),
    this.occurredAt = const Value.absent(),
    this.scheduleRevisionId = const Value.absent(),
    this.grantedDurationMinutes = const Value.absent(),
    this.reason = const Value.absent(),
    this.userReportedResult = const Value.absent(),
    this.submitOptionalEvidence = const Value.absent(),
    this.isRetrospective = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ExecutionEventsCompanion.insert({
    required String id,
    required String missionId,
    required int sequence,
    required String type,
    required int occurredAt,
    this.scheduleRevisionId = const Value.absent(),
    this.grantedDurationMinutes = const Value.absent(),
    this.reason = const Value.absent(),
    this.userReportedResult = const Value.absent(),
    this.submitOptionalEvidence = const Value.absent(),
    this.isRetrospective = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       missionId = Value(missionId),
       sequence = Value(sequence),
       type = Value(type),
       occurredAt = Value(occurredAt);
  static Insertable<ExecutionEventRow> custom({
    Expression<String>? id,
    Expression<String>? missionId,
    Expression<int>? sequence,
    Expression<String>? type,
    Expression<int>? occurredAt,
    Expression<String>? scheduleRevisionId,
    Expression<int>? grantedDurationMinutes,
    Expression<String>? reason,
    Expression<String>? userReportedResult,
    Expression<bool>? submitOptionalEvidence,
    Expression<bool>? isRetrospective,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (missionId != null) 'mission_id': missionId,
      if (sequence != null) 'sequence': sequence,
      if (type != null) 'type': type,
      if (occurredAt != null) 'occurred_at': occurredAt,
      if (scheduleRevisionId != null)
        'schedule_revision_id': scheduleRevisionId,
      if (grantedDurationMinutes != null)
        'granted_duration_minutes': grantedDurationMinutes,
      if (reason != null) 'reason': reason,
      if (userReportedResult != null)
        'user_reported_result': userReportedResult,
      if (submitOptionalEvidence != null)
        'submit_optional_evidence': submitOptionalEvidence,
      if (isRetrospective != null) 'is_retrospective': isRetrospective,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ExecutionEventsCompanion copyWith({
    Value<String>? id,
    Value<String>? missionId,
    Value<int>? sequence,
    Value<String>? type,
    Value<int>? occurredAt,
    Value<String?>? scheduleRevisionId,
    Value<int?>? grantedDurationMinutes,
    Value<String?>? reason,
    Value<String?>? userReportedResult,
    Value<bool?>? submitOptionalEvidence,
    Value<bool>? isRetrospective,
    Value<int>? rowid,
  }) {
    return ExecutionEventsCompanion(
      id: id ?? this.id,
      missionId: missionId ?? this.missionId,
      sequence: sequence ?? this.sequence,
      type: type ?? this.type,
      occurredAt: occurredAt ?? this.occurredAt,
      scheduleRevisionId: scheduleRevisionId ?? this.scheduleRevisionId,
      grantedDurationMinutes:
          grantedDurationMinutes ?? this.grantedDurationMinutes,
      reason: reason ?? this.reason,
      userReportedResult: userReportedResult ?? this.userReportedResult,
      submitOptionalEvidence:
          submitOptionalEvidence ?? this.submitOptionalEvidence,
      isRetrospective: isRetrospective ?? this.isRetrospective,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (missionId.present) {
      map['mission_id'] = Variable<String>(missionId.value);
    }
    if (sequence.present) {
      map['sequence'] = Variable<int>(sequence.value);
    }
    if (type.present) {
      map['type'] = Variable<String>(type.value);
    }
    if (occurredAt.present) {
      map['occurred_at'] = Variable<int>(occurredAt.value);
    }
    if (scheduleRevisionId.present) {
      map['schedule_revision_id'] = Variable<String>(scheduleRevisionId.value);
    }
    if (grantedDurationMinutes.present) {
      map['granted_duration_minutes'] = Variable<int>(
        grantedDurationMinutes.value,
      );
    }
    if (reason.present) {
      map['reason'] = Variable<String>(reason.value);
    }
    if (userReportedResult.present) {
      map['user_reported_result'] = Variable<String>(userReportedResult.value);
    }
    if (submitOptionalEvidence.present) {
      map['submit_optional_evidence'] = Variable<bool>(
        submitOptionalEvidence.value,
      );
    }
    if (isRetrospective.present) {
      map['is_retrospective'] = Variable<bool>(isRetrospective.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ExecutionEventsCompanion(')
          ..write('id: $id, ')
          ..write('missionId: $missionId, ')
          ..write('sequence: $sequence, ')
          ..write('type: $type, ')
          ..write('occurredAt: $occurredAt, ')
          ..write('scheduleRevisionId: $scheduleRevisionId, ')
          ..write('grantedDurationMinutes: $grantedDurationMinutes, ')
          ..write('reason: $reason, ')
          ..write('userReportedResult: $userReportedResult, ')
          ..write('submitOptionalEvidence: $submitOptionalEvidence, ')
          ..write('isRetrospective: $isRetrospective, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $FailureRecordsTable extends FailureRecords
    with TableInfo<$FailureRecordsTable, FailureRecordRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $FailureRecordsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _missionIdMeta = const VerificationMeta(
    'missionId',
  );
  @override
  late final GeneratedColumn<String> missionId = GeneratedColumn<String>(
    'mission_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES missions (id)',
    ),
  );
  static const VerificationMeta _triggerMeta = const VerificationMeta(
    'trigger',
  );
  @override
  late final GeneratedColumn<String> trigger = GeneratedColumn<String>(
    'trigger',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _occurredAtMeta = const VerificationMeta(
    'occurredAt',
  );
  @override
  late final GeneratedColumn<int> occurredAt = GeneratedColumn<int>(
    'occurred_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _userReasonCategoryMeta =
      const VerificationMeta('userReasonCategory');
  @override
  late final GeneratedColumn<String> userReasonCategory =
      GeneratedColumn<String>(
        'user_reason_category',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _userReasonTextMeta = const VerificationMeta(
    'userReasonText',
  );
  @override
  late final GeneratedColumn<String> userReasonText = GeneratedColumn<String>(
    'user_reason_text',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    missionId,
    trigger,
    occurredAt,
    userReasonCategory,
    userReasonText,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'failure_records';
  @override
  VerificationContext validateIntegrity(
    Insertable<FailureRecordRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('mission_id')) {
      context.handle(
        _missionIdMeta,
        missionId.isAcceptableOrUnknown(data['mission_id']!, _missionIdMeta),
      );
    } else if (isInserting) {
      context.missing(_missionIdMeta);
    }
    if (data.containsKey('trigger')) {
      context.handle(
        _triggerMeta,
        trigger.isAcceptableOrUnknown(data['trigger']!, _triggerMeta),
      );
    } else if (isInserting) {
      context.missing(_triggerMeta);
    }
    if (data.containsKey('occurred_at')) {
      context.handle(
        _occurredAtMeta,
        occurredAt.isAcceptableOrUnknown(data['occurred_at']!, _occurredAtMeta),
      );
    } else if (isInserting) {
      context.missing(_occurredAtMeta);
    }
    if (data.containsKey('user_reason_category')) {
      context.handle(
        _userReasonCategoryMeta,
        userReasonCategory.isAcceptableOrUnknown(
          data['user_reason_category']!,
          _userReasonCategoryMeta,
        ),
      );
    }
    if (data.containsKey('user_reason_text')) {
      context.handle(
        _userReasonTextMeta,
        userReasonText.isAcceptableOrUnknown(
          data['user_reason_text']!,
          _userReasonTextMeta,
        ),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
    {missionId, trigger},
  ];
  @override
  FailureRecordRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return FailureRecordRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      missionId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}mission_id'],
      )!,
      trigger: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}trigger'],
      )!,
      occurredAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}occurred_at'],
      )!,
      userReasonCategory: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}user_reason_category'],
      ),
      userReasonText: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}user_reason_text'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $FailureRecordsTable createAlias(String alias) {
    return $FailureRecordsTable(attachedDatabase, alias);
  }
}

class FailureRecordRow extends DataClass
    implements Insertable<FailureRecordRow> {
  final String id;
  final String missionId;
  final String trigger;
  final int occurredAt;
  final String? userReasonCategory;
  final String? userReasonText;
  final int createdAt;
  const FailureRecordRow({
    required this.id,
    required this.missionId,
    required this.trigger,
    required this.occurredAt,
    this.userReasonCategory,
    this.userReasonText,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['mission_id'] = Variable<String>(missionId);
    map['trigger'] = Variable<String>(trigger);
    map['occurred_at'] = Variable<int>(occurredAt);
    if (!nullToAbsent || userReasonCategory != null) {
      map['user_reason_category'] = Variable<String>(userReasonCategory);
    }
    if (!nullToAbsent || userReasonText != null) {
      map['user_reason_text'] = Variable<String>(userReasonText);
    }
    map['created_at'] = Variable<int>(createdAt);
    return map;
  }

  FailureRecordsCompanion toCompanion(bool nullToAbsent) {
    return FailureRecordsCompanion(
      id: Value(id),
      missionId: Value(missionId),
      trigger: Value(trigger),
      occurredAt: Value(occurredAt),
      userReasonCategory: userReasonCategory == null && nullToAbsent
          ? const Value.absent()
          : Value(userReasonCategory),
      userReasonText: userReasonText == null && nullToAbsent
          ? const Value.absent()
          : Value(userReasonText),
      createdAt: Value(createdAt),
    );
  }

  factory FailureRecordRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return FailureRecordRow(
      id: serializer.fromJson<String>(json['id']),
      missionId: serializer.fromJson<String>(json['missionId']),
      trigger: serializer.fromJson<String>(json['trigger']),
      occurredAt: serializer.fromJson<int>(json['occurredAt']),
      userReasonCategory: serializer.fromJson<String?>(
        json['userReasonCategory'],
      ),
      userReasonText: serializer.fromJson<String?>(json['userReasonText']),
      createdAt: serializer.fromJson<int>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'missionId': serializer.toJson<String>(missionId),
      'trigger': serializer.toJson<String>(trigger),
      'occurredAt': serializer.toJson<int>(occurredAt),
      'userReasonCategory': serializer.toJson<String?>(userReasonCategory),
      'userReasonText': serializer.toJson<String?>(userReasonText),
      'createdAt': serializer.toJson<int>(createdAt),
    };
  }

  FailureRecordRow copyWith({
    String? id,
    String? missionId,
    String? trigger,
    int? occurredAt,
    Value<String?> userReasonCategory = const Value.absent(),
    Value<String?> userReasonText = const Value.absent(),
    int? createdAt,
  }) => FailureRecordRow(
    id: id ?? this.id,
    missionId: missionId ?? this.missionId,
    trigger: trigger ?? this.trigger,
    occurredAt: occurredAt ?? this.occurredAt,
    userReasonCategory: userReasonCategory.present
        ? userReasonCategory.value
        : this.userReasonCategory,
    userReasonText: userReasonText.present
        ? userReasonText.value
        : this.userReasonText,
    createdAt: createdAt ?? this.createdAt,
  );
  FailureRecordRow copyWithCompanion(FailureRecordsCompanion data) {
    return FailureRecordRow(
      id: data.id.present ? data.id.value : this.id,
      missionId: data.missionId.present ? data.missionId.value : this.missionId,
      trigger: data.trigger.present ? data.trigger.value : this.trigger,
      occurredAt: data.occurredAt.present
          ? data.occurredAt.value
          : this.occurredAt,
      userReasonCategory: data.userReasonCategory.present
          ? data.userReasonCategory.value
          : this.userReasonCategory,
      userReasonText: data.userReasonText.present
          ? data.userReasonText.value
          : this.userReasonText,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('FailureRecordRow(')
          ..write('id: $id, ')
          ..write('missionId: $missionId, ')
          ..write('trigger: $trigger, ')
          ..write('occurredAt: $occurredAt, ')
          ..write('userReasonCategory: $userReasonCategory, ')
          ..write('userReasonText: $userReasonText, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    missionId,
    trigger,
    occurredAt,
    userReasonCategory,
    userReasonText,
    createdAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is FailureRecordRow &&
          other.id == this.id &&
          other.missionId == this.missionId &&
          other.trigger == this.trigger &&
          other.occurredAt == this.occurredAt &&
          other.userReasonCategory == this.userReasonCategory &&
          other.userReasonText == this.userReasonText &&
          other.createdAt == this.createdAt);
}

class FailureRecordsCompanion extends UpdateCompanion<FailureRecordRow> {
  final Value<String> id;
  final Value<String> missionId;
  final Value<String> trigger;
  final Value<int> occurredAt;
  final Value<String?> userReasonCategory;
  final Value<String?> userReasonText;
  final Value<int> createdAt;
  final Value<int> rowid;
  const FailureRecordsCompanion({
    this.id = const Value.absent(),
    this.missionId = const Value.absent(),
    this.trigger = const Value.absent(),
    this.occurredAt = const Value.absent(),
    this.userReasonCategory = const Value.absent(),
    this.userReasonText = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  FailureRecordsCompanion.insert({
    required String id,
    required String missionId,
    required String trigger,
    required int occurredAt,
    this.userReasonCategory = const Value.absent(),
    this.userReasonText = const Value.absent(),
    required int createdAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       missionId = Value(missionId),
       trigger = Value(trigger),
       occurredAt = Value(occurredAt),
       createdAt = Value(createdAt);
  static Insertable<FailureRecordRow> custom({
    Expression<String>? id,
    Expression<String>? missionId,
    Expression<String>? trigger,
    Expression<int>? occurredAt,
    Expression<String>? userReasonCategory,
    Expression<String>? userReasonText,
    Expression<int>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (missionId != null) 'mission_id': missionId,
      if (trigger != null) 'trigger': trigger,
      if (occurredAt != null) 'occurred_at': occurredAt,
      if (userReasonCategory != null)
        'user_reason_category': userReasonCategory,
      if (userReasonText != null) 'user_reason_text': userReasonText,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  FailureRecordsCompanion copyWith({
    Value<String>? id,
    Value<String>? missionId,
    Value<String>? trigger,
    Value<int>? occurredAt,
    Value<String?>? userReasonCategory,
    Value<String?>? userReasonText,
    Value<int>? createdAt,
    Value<int>? rowid,
  }) {
    return FailureRecordsCompanion(
      id: id ?? this.id,
      missionId: missionId ?? this.missionId,
      trigger: trigger ?? this.trigger,
      occurredAt: occurredAt ?? this.occurredAt,
      userReasonCategory: userReasonCategory ?? this.userReasonCategory,
      userReasonText: userReasonText ?? this.userReasonText,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (missionId.present) {
      map['mission_id'] = Variable<String>(missionId.value);
    }
    if (trigger.present) {
      map['trigger'] = Variable<String>(trigger.value);
    }
    if (occurredAt.present) {
      map['occurred_at'] = Variable<int>(occurredAt.value);
    }
    if (userReasonCategory.present) {
      map['user_reason_category'] = Variable<String>(userReasonCategory.value);
    }
    if (userReasonText.present) {
      map['user_reason_text'] = Variable<String>(userReasonText.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('FailureRecordsCompanion(')
          ..write('id: $id, ')
          ..write('missionId: $missionId, ')
          ..write('trigger: $trigger, ')
          ..write('occurredAt: $occurredAt, ')
          ..write('userReasonCategory: $userReasonCategory, ')
          ..write('userReasonText: $userReasonText, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $EvidenceRecordsTable extends EvidenceRecords
    with TableInfo<$EvidenceRecordsTable, EvidenceRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $EvidenceRecordsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _missionIdMeta = const VerificationMeta(
    'missionId',
  );
  @override
  late final GeneratedColumn<String> missionId = GeneratedColumn<String>(
    'mission_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES missions (id)',
    ),
  );
  static const VerificationMeta _submissionIdMeta = const VerificationMeta(
    'submissionId',
  );
  @override
  late final GeneratedColumn<String> submissionId = GeneratedColumn<String>(
    'submission_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _recordIdMeta = const VerificationMeta(
    'recordId',
  );
  @override
  late final GeneratedColumn<String> recordId = GeneratedColumn<String>(
    'record_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'),
  );
  static const VerificationMeta _typeMeta = const VerificationMeta('type');
  @override
  late final GeneratedColumn<String> type = GeneratedColumn<String>(
    'type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sourceMeta = const VerificationMeta('source');
  @override
  late final GeneratedColumn<String> source = GeneratedColumn<String>(
    'source',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _contentMeta = const VerificationMeta(
    'content',
  );
  @override
  late final GeneratedColumn<String> content = GeneratedColumn<String>(
    'content',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _attachmentStorageKeyMeta =
      const VerificationMeta('attachmentStorageKey');
  @override
  late final GeneratedColumn<String> attachmentStorageKey =
      GeneratedColumn<String>(
        'attachment_storage_key',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _attachmentFileNameMeta =
      const VerificationMeta('attachmentFileName');
  @override
  late final GeneratedColumn<String> attachmentFileName =
      GeneratedColumn<String>(
        'attachment_file_name',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _attachmentMimeTypeMeta =
      const VerificationMeta('attachmentMimeType');
  @override
  late final GeneratedColumn<String> attachmentMimeType =
      GeneratedColumn<String>(
        'attachment_mime_type',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _capturedAtMeta = const VerificationMeta(
    'capturedAt',
  );
  @override
  late final GeneratedColumn<int> capturedAt = GeneratedColumn<int>(
    'captured_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _submittedAtMeta = const VerificationMeta(
    'submittedAt',
  );
  @override
  late final GeneratedColumn<int> submittedAt = GeneratedColumn<int>(
    'submitted_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _supersedesEvidenceIdMeta =
      const VerificationMeta('supersedesEvidenceId');
  @override
  late final GeneratedColumn<String> supersedesEvidenceId =
      GeneratedColumn<String>(
        'supersedes_evidence_id',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
        defaultConstraints: GeneratedColumn.constraintIsAlways(
          'UNIQUE REFERENCES evidence_records (id)',
        ),
      );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    missionId,
    submissionId,
    recordId,
    type,
    source,
    content,
    attachmentStorageKey,
    attachmentFileName,
    attachmentMimeType,
    capturedAt,
    submittedAt,
    supersedesEvidenceId,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'evidence_records';
  @override
  VerificationContext validateIntegrity(
    Insertable<EvidenceRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('mission_id')) {
      context.handle(
        _missionIdMeta,
        missionId.isAcceptableOrUnknown(data['mission_id']!, _missionIdMeta),
      );
    } else if (isInserting) {
      context.missing(_missionIdMeta);
    }
    if (data.containsKey('submission_id')) {
      context.handle(
        _submissionIdMeta,
        submissionId.isAcceptableOrUnknown(
          data['submission_id']!,
          _submissionIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_submissionIdMeta);
    }
    if (data.containsKey('record_id')) {
      context.handle(
        _recordIdMeta,
        recordId.isAcceptableOrUnknown(data['record_id']!, _recordIdMeta),
      );
    }
    if (data.containsKey('type')) {
      context.handle(
        _typeMeta,
        type.isAcceptableOrUnknown(data['type']!, _typeMeta),
      );
    } else if (isInserting) {
      context.missing(_typeMeta);
    }
    if (data.containsKey('source')) {
      context.handle(
        _sourceMeta,
        source.isAcceptableOrUnknown(data['source']!, _sourceMeta),
      );
    } else if (isInserting) {
      context.missing(_sourceMeta);
    }
    if (data.containsKey('content')) {
      context.handle(
        _contentMeta,
        content.isAcceptableOrUnknown(data['content']!, _contentMeta),
      );
    }
    if (data.containsKey('attachment_storage_key')) {
      context.handle(
        _attachmentStorageKeyMeta,
        attachmentStorageKey.isAcceptableOrUnknown(
          data['attachment_storage_key']!,
          _attachmentStorageKeyMeta,
        ),
      );
    }
    if (data.containsKey('attachment_file_name')) {
      context.handle(
        _attachmentFileNameMeta,
        attachmentFileName.isAcceptableOrUnknown(
          data['attachment_file_name']!,
          _attachmentFileNameMeta,
        ),
      );
    }
    if (data.containsKey('attachment_mime_type')) {
      context.handle(
        _attachmentMimeTypeMeta,
        attachmentMimeType.isAcceptableOrUnknown(
          data['attachment_mime_type']!,
          _attachmentMimeTypeMeta,
        ),
      );
    }
    if (data.containsKey('captured_at')) {
      context.handle(
        _capturedAtMeta,
        capturedAt.isAcceptableOrUnknown(data['captured_at']!, _capturedAtMeta),
      );
    }
    if (data.containsKey('submitted_at')) {
      context.handle(
        _submittedAtMeta,
        submittedAt.isAcceptableOrUnknown(
          data['submitted_at']!,
          _submittedAtMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_submittedAtMeta);
    }
    if (data.containsKey('supersedes_evidence_id')) {
      context.handle(
        _supersedesEvidenceIdMeta,
        supersedesEvidenceId.isAcceptableOrUnknown(
          data['supersedes_evidence_id']!,
          _supersedesEvidenceIdMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  EvidenceRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return EvidenceRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      missionId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}mission_id'],
      )!,
      submissionId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}submission_id'],
      )!,
      recordId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}record_id'],
      ),
      type: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}type'],
      )!,
      source: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source'],
      )!,
      content: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}content'],
      ),
      attachmentStorageKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}attachment_storage_key'],
      ),
      attachmentFileName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}attachment_file_name'],
      ),
      attachmentMimeType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}attachment_mime_type'],
      ),
      capturedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}captured_at'],
      ),
      submittedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}submitted_at'],
      )!,
      supersedesEvidenceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}supersedes_evidence_id'],
      ),
    );
  }

  @override
  $EvidenceRecordsTable createAlias(String alias) {
    return $EvidenceRecordsTable(attachedDatabase, alias);
  }
}

class EvidenceRow extends DataClass implements Insertable<EvidenceRow> {
  final String id;
  final String missionId;
  final String submissionId;
  final String? recordId;
  final String type;
  final String source;
  final String? content;
  final String? attachmentStorageKey;
  final String? attachmentFileName;
  final String? attachmentMimeType;
  final int? capturedAt;
  final int submittedAt;
  final String? supersedesEvidenceId;
  const EvidenceRow({
    required this.id,
    required this.missionId,
    required this.submissionId,
    this.recordId,
    required this.type,
    required this.source,
    this.content,
    this.attachmentStorageKey,
    this.attachmentFileName,
    this.attachmentMimeType,
    this.capturedAt,
    required this.submittedAt,
    this.supersedesEvidenceId,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['mission_id'] = Variable<String>(missionId);
    map['submission_id'] = Variable<String>(submissionId);
    if (!nullToAbsent || recordId != null) {
      map['record_id'] = Variable<String>(recordId);
    }
    map['type'] = Variable<String>(type);
    map['source'] = Variable<String>(source);
    if (!nullToAbsent || content != null) {
      map['content'] = Variable<String>(content);
    }
    if (!nullToAbsent || attachmentStorageKey != null) {
      map['attachment_storage_key'] = Variable<String>(attachmentStorageKey);
    }
    if (!nullToAbsent || attachmentFileName != null) {
      map['attachment_file_name'] = Variable<String>(attachmentFileName);
    }
    if (!nullToAbsent || attachmentMimeType != null) {
      map['attachment_mime_type'] = Variable<String>(attachmentMimeType);
    }
    if (!nullToAbsent || capturedAt != null) {
      map['captured_at'] = Variable<int>(capturedAt);
    }
    map['submitted_at'] = Variable<int>(submittedAt);
    if (!nullToAbsent || supersedesEvidenceId != null) {
      map['supersedes_evidence_id'] = Variable<String>(supersedesEvidenceId);
    }
    return map;
  }

  EvidenceRecordsCompanion toCompanion(bool nullToAbsent) {
    return EvidenceRecordsCompanion(
      id: Value(id),
      missionId: Value(missionId),
      submissionId: Value(submissionId),
      recordId: recordId == null && nullToAbsent
          ? const Value.absent()
          : Value(recordId),
      type: Value(type),
      source: Value(source),
      content: content == null && nullToAbsent
          ? const Value.absent()
          : Value(content),
      attachmentStorageKey: attachmentStorageKey == null && nullToAbsent
          ? const Value.absent()
          : Value(attachmentStorageKey),
      attachmentFileName: attachmentFileName == null && nullToAbsent
          ? const Value.absent()
          : Value(attachmentFileName),
      attachmentMimeType: attachmentMimeType == null && nullToAbsent
          ? const Value.absent()
          : Value(attachmentMimeType),
      capturedAt: capturedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(capturedAt),
      submittedAt: Value(submittedAt),
      supersedesEvidenceId: supersedesEvidenceId == null && nullToAbsent
          ? const Value.absent()
          : Value(supersedesEvidenceId),
    );
  }

  factory EvidenceRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return EvidenceRow(
      id: serializer.fromJson<String>(json['id']),
      missionId: serializer.fromJson<String>(json['missionId']),
      submissionId: serializer.fromJson<String>(json['submissionId']),
      recordId: serializer.fromJson<String?>(json['recordId']),
      type: serializer.fromJson<String>(json['type']),
      source: serializer.fromJson<String>(json['source']),
      content: serializer.fromJson<String?>(json['content']),
      attachmentStorageKey: serializer.fromJson<String?>(
        json['attachmentStorageKey'],
      ),
      attachmentFileName: serializer.fromJson<String?>(
        json['attachmentFileName'],
      ),
      attachmentMimeType: serializer.fromJson<String?>(
        json['attachmentMimeType'],
      ),
      capturedAt: serializer.fromJson<int?>(json['capturedAt']),
      submittedAt: serializer.fromJson<int>(json['submittedAt']),
      supersedesEvidenceId: serializer.fromJson<String?>(
        json['supersedesEvidenceId'],
      ),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'missionId': serializer.toJson<String>(missionId),
      'submissionId': serializer.toJson<String>(submissionId),
      'recordId': serializer.toJson<String?>(recordId),
      'type': serializer.toJson<String>(type),
      'source': serializer.toJson<String>(source),
      'content': serializer.toJson<String?>(content),
      'attachmentStorageKey': serializer.toJson<String?>(attachmentStorageKey),
      'attachmentFileName': serializer.toJson<String?>(attachmentFileName),
      'attachmentMimeType': serializer.toJson<String?>(attachmentMimeType),
      'capturedAt': serializer.toJson<int?>(capturedAt),
      'submittedAt': serializer.toJson<int>(submittedAt),
      'supersedesEvidenceId': serializer.toJson<String?>(supersedesEvidenceId),
    };
  }

  EvidenceRow copyWith({
    String? id,
    String? missionId,
    String? submissionId,
    Value<String?> recordId = const Value.absent(),
    String? type,
    String? source,
    Value<String?> content = const Value.absent(),
    Value<String?> attachmentStorageKey = const Value.absent(),
    Value<String?> attachmentFileName = const Value.absent(),
    Value<String?> attachmentMimeType = const Value.absent(),
    Value<int?> capturedAt = const Value.absent(),
    int? submittedAt,
    Value<String?> supersedesEvidenceId = const Value.absent(),
  }) => EvidenceRow(
    id: id ?? this.id,
    missionId: missionId ?? this.missionId,
    submissionId: submissionId ?? this.submissionId,
    recordId: recordId.present ? recordId.value : this.recordId,
    type: type ?? this.type,
    source: source ?? this.source,
    content: content.present ? content.value : this.content,
    attachmentStorageKey: attachmentStorageKey.present
        ? attachmentStorageKey.value
        : this.attachmentStorageKey,
    attachmentFileName: attachmentFileName.present
        ? attachmentFileName.value
        : this.attachmentFileName,
    attachmentMimeType: attachmentMimeType.present
        ? attachmentMimeType.value
        : this.attachmentMimeType,
    capturedAt: capturedAt.present ? capturedAt.value : this.capturedAt,
    submittedAt: submittedAt ?? this.submittedAt,
    supersedesEvidenceId: supersedesEvidenceId.present
        ? supersedesEvidenceId.value
        : this.supersedesEvidenceId,
  );
  EvidenceRow copyWithCompanion(EvidenceRecordsCompanion data) {
    return EvidenceRow(
      id: data.id.present ? data.id.value : this.id,
      missionId: data.missionId.present ? data.missionId.value : this.missionId,
      submissionId: data.submissionId.present
          ? data.submissionId.value
          : this.submissionId,
      recordId: data.recordId.present ? data.recordId.value : this.recordId,
      type: data.type.present ? data.type.value : this.type,
      source: data.source.present ? data.source.value : this.source,
      content: data.content.present ? data.content.value : this.content,
      attachmentStorageKey: data.attachmentStorageKey.present
          ? data.attachmentStorageKey.value
          : this.attachmentStorageKey,
      attachmentFileName: data.attachmentFileName.present
          ? data.attachmentFileName.value
          : this.attachmentFileName,
      attachmentMimeType: data.attachmentMimeType.present
          ? data.attachmentMimeType.value
          : this.attachmentMimeType,
      capturedAt: data.capturedAt.present
          ? data.capturedAt.value
          : this.capturedAt,
      submittedAt: data.submittedAt.present
          ? data.submittedAt.value
          : this.submittedAt,
      supersedesEvidenceId: data.supersedesEvidenceId.present
          ? data.supersedesEvidenceId.value
          : this.supersedesEvidenceId,
    );
  }

  @override
  String toString() {
    return (StringBuffer('EvidenceRow(')
          ..write('id: $id, ')
          ..write('missionId: $missionId, ')
          ..write('submissionId: $submissionId, ')
          ..write('recordId: $recordId, ')
          ..write('type: $type, ')
          ..write('source: $source, ')
          ..write('content: $content, ')
          ..write('attachmentStorageKey: $attachmentStorageKey, ')
          ..write('attachmentFileName: $attachmentFileName, ')
          ..write('attachmentMimeType: $attachmentMimeType, ')
          ..write('capturedAt: $capturedAt, ')
          ..write('submittedAt: $submittedAt, ')
          ..write('supersedesEvidenceId: $supersedesEvidenceId')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    missionId,
    submissionId,
    recordId,
    type,
    source,
    content,
    attachmentStorageKey,
    attachmentFileName,
    attachmentMimeType,
    capturedAt,
    submittedAt,
    supersedesEvidenceId,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is EvidenceRow &&
          other.id == this.id &&
          other.missionId == this.missionId &&
          other.submissionId == this.submissionId &&
          other.recordId == this.recordId &&
          other.type == this.type &&
          other.source == this.source &&
          other.content == this.content &&
          other.attachmentStorageKey == this.attachmentStorageKey &&
          other.attachmentFileName == this.attachmentFileName &&
          other.attachmentMimeType == this.attachmentMimeType &&
          other.capturedAt == this.capturedAt &&
          other.submittedAt == this.submittedAt &&
          other.supersedesEvidenceId == this.supersedesEvidenceId);
}

class EvidenceRecordsCompanion extends UpdateCompanion<EvidenceRow> {
  final Value<String> id;
  final Value<String> missionId;
  final Value<String> submissionId;
  final Value<String?> recordId;
  final Value<String> type;
  final Value<String> source;
  final Value<String?> content;
  final Value<String?> attachmentStorageKey;
  final Value<String?> attachmentFileName;
  final Value<String?> attachmentMimeType;
  final Value<int?> capturedAt;
  final Value<int> submittedAt;
  final Value<String?> supersedesEvidenceId;
  final Value<int> rowid;
  const EvidenceRecordsCompanion({
    this.id = const Value.absent(),
    this.missionId = const Value.absent(),
    this.submissionId = const Value.absent(),
    this.recordId = const Value.absent(),
    this.type = const Value.absent(),
    this.source = const Value.absent(),
    this.content = const Value.absent(),
    this.attachmentStorageKey = const Value.absent(),
    this.attachmentFileName = const Value.absent(),
    this.attachmentMimeType = const Value.absent(),
    this.capturedAt = const Value.absent(),
    this.submittedAt = const Value.absent(),
    this.supersedesEvidenceId = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  EvidenceRecordsCompanion.insert({
    required String id,
    required String missionId,
    required String submissionId,
    this.recordId = const Value.absent(),
    required String type,
    required String source,
    this.content = const Value.absent(),
    this.attachmentStorageKey = const Value.absent(),
    this.attachmentFileName = const Value.absent(),
    this.attachmentMimeType = const Value.absent(),
    this.capturedAt = const Value.absent(),
    required int submittedAt,
    this.supersedesEvidenceId = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       missionId = Value(missionId),
       submissionId = Value(submissionId),
       type = Value(type),
       source = Value(source),
       submittedAt = Value(submittedAt);
  static Insertable<EvidenceRow> custom({
    Expression<String>? id,
    Expression<String>? missionId,
    Expression<String>? submissionId,
    Expression<String>? recordId,
    Expression<String>? type,
    Expression<String>? source,
    Expression<String>? content,
    Expression<String>? attachmentStorageKey,
    Expression<String>? attachmentFileName,
    Expression<String>? attachmentMimeType,
    Expression<int>? capturedAt,
    Expression<int>? submittedAt,
    Expression<String>? supersedesEvidenceId,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (missionId != null) 'mission_id': missionId,
      if (submissionId != null) 'submission_id': submissionId,
      if (recordId != null) 'record_id': recordId,
      if (type != null) 'type': type,
      if (source != null) 'source': source,
      if (content != null) 'content': content,
      if (attachmentStorageKey != null)
        'attachment_storage_key': attachmentStorageKey,
      if (attachmentFileName != null)
        'attachment_file_name': attachmentFileName,
      if (attachmentMimeType != null)
        'attachment_mime_type': attachmentMimeType,
      if (capturedAt != null) 'captured_at': capturedAt,
      if (submittedAt != null) 'submitted_at': submittedAt,
      if (supersedesEvidenceId != null)
        'supersedes_evidence_id': supersedesEvidenceId,
      if (rowid != null) 'rowid': rowid,
    });
  }

  EvidenceRecordsCompanion copyWith({
    Value<String>? id,
    Value<String>? missionId,
    Value<String>? submissionId,
    Value<String?>? recordId,
    Value<String>? type,
    Value<String>? source,
    Value<String?>? content,
    Value<String?>? attachmentStorageKey,
    Value<String?>? attachmentFileName,
    Value<String?>? attachmentMimeType,
    Value<int?>? capturedAt,
    Value<int>? submittedAt,
    Value<String?>? supersedesEvidenceId,
    Value<int>? rowid,
  }) {
    return EvidenceRecordsCompanion(
      id: id ?? this.id,
      missionId: missionId ?? this.missionId,
      submissionId: submissionId ?? this.submissionId,
      recordId: recordId ?? this.recordId,
      type: type ?? this.type,
      source: source ?? this.source,
      content: content ?? this.content,
      attachmentStorageKey: attachmentStorageKey ?? this.attachmentStorageKey,
      attachmentFileName: attachmentFileName ?? this.attachmentFileName,
      attachmentMimeType: attachmentMimeType ?? this.attachmentMimeType,
      capturedAt: capturedAt ?? this.capturedAt,
      submittedAt: submittedAt ?? this.submittedAt,
      supersedesEvidenceId: supersedesEvidenceId ?? this.supersedesEvidenceId,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (missionId.present) {
      map['mission_id'] = Variable<String>(missionId.value);
    }
    if (submissionId.present) {
      map['submission_id'] = Variable<String>(submissionId.value);
    }
    if (recordId.present) {
      map['record_id'] = Variable<String>(recordId.value);
    }
    if (type.present) {
      map['type'] = Variable<String>(type.value);
    }
    if (source.present) {
      map['source'] = Variable<String>(source.value);
    }
    if (content.present) {
      map['content'] = Variable<String>(content.value);
    }
    if (attachmentStorageKey.present) {
      map['attachment_storage_key'] = Variable<String>(
        attachmentStorageKey.value,
      );
    }
    if (attachmentFileName.present) {
      map['attachment_file_name'] = Variable<String>(attachmentFileName.value);
    }
    if (attachmentMimeType.present) {
      map['attachment_mime_type'] = Variable<String>(attachmentMimeType.value);
    }
    if (capturedAt.present) {
      map['captured_at'] = Variable<int>(capturedAt.value);
    }
    if (submittedAt.present) {
      map['submitted_at'] = Variable<int>(submittedAt.value);
    }
    if (supersedesEvidenceId.present) {
      map['supersedes_evidence_id'] = Variable<String>(
        supersedesEvidenceId.value,
      );
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('EvidenceRecordsCompanion(')
          ..write('id: $id, ')
          ..write('missionId: $missionId, ')
          ..write('submissionId: $submissionId, ')
          ..write('recordId: $recordId, ')
          ..write('type: $type, ')
          ..write('source: $source, ')
          ..write('content: $content, ')
          ..write('attachmentStorageKey: $attachmentStorageKey, ')
          ..write('attachmentFileName: $attachmentFileName, ')
          ..write('attachmentMimeType: $attachmentMimeType, ')
          ..write('capturedAt: $capturedAt, ')
          ..write('submittedAt: $submittedAt, ')
          ..write('supersedesEvidenceId: $supersedesEvidenceId, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ImportReceiptsTable extends ImportReceipts
    with TableInfo<$ImportReceiptsTable, ImportReceipt> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ImportReceiptsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _schemaNameMeta = const VerificationMeta(
    'schemaName',
  );
  @override
  late final GeneratedColumn<String> schemaName = GeneratedColumn<String>(
    'schema_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _packageIdMeta = const VerificationMeta(
    'packageId',
  );
  @override
  late final GeneratedColumn<String> packageId = GeneratedColumn<String>(
    'package_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _schemaVersionMeta = const VerificationMeta(
    'schemaVersion',
  );
  @override
  late final GeneratedColumn<int> schemaVersion = GeneratedColumn<int>(
    'schema_version',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _payloadSha256Meta = const VerificationMeta(
    'payloadSha256',
  );
  @override
  late final GeneratedColumn<String> payloadSha256 = GeneratedColumn<String>(
    'payload_sha256',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _contentSha256Meta = const VerificationMeta(
    'contentSha256',
  );
  @override
  late final GeneratedColumn<String> contentSha256 = GeneratedColumn<String>(
    'content_sha256',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _goalIdMeta = const VerificationMeta('goalId');
  @override
  late final GeneratedColumn<String> goalId = GeneratedColumn<String>(
    'goal_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES goals (id)',
    ),
  );
  static const VerificationMeta _importedAtMeta = const VerificationMeta(
    'importedAt',
  );
  @override
  late final GeneratedColumn<int> importedAt = GeneratedColumn<int>(
    'imported_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nodeCountMeta = const VerificationMeta(
    'nodeCount',
  );
  @override
  late final GeneratedColumn<int> nodeCount = GeneratedColumn<int>(
    'node_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _missionCountMeta = const VerificationMeta(
    'missionCount',
  );
  @override
  late final GeneratedColumn<int> missionCount = GeneratedColumn<int>(
    'mission_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    schemaName,
    packageId,
    schemaVersion,
    payloadSha256,
    contentSha256,
    goalId,
    importedAt,
    nodeCount,
    missionCount,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'import_receipts';
  @override
  VerificationContext validateIntegrity(
    Insertable<ImportReceipt> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('schema_name')) {
      context.handle(
        _schemaNameMeta,
        schemaName.isAcceptableOrUnknown(data['schema_name']!, _schemaNameMeta),
      );
    } else if (isInserting) {
      context.missing(_schemaNameMeta);
    }
    if (data.containsKey('package_id')) {
      context.handle(
        _packageIdMeta,
        packageId.isAcceptableOrUnknown(data['package_id']!, _packageIdMeta),
      );
    } else if (isInserting) {
      context.missing(_packageIdMeta);
    }
    if (data.containsKey('schema_version')) {
      context.handle(
        _schemaVersionMeta,
        schemaVersion.isAcceptableOrUnknown(
          data['schema_version']!,
          _schemaVersionMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_schemaVersionMeta);
    }
    if (data.containsKey('payload_sha256')) {
      context.handle(
        _payloadSha256Meta,
        payloadSha256.isAcceptableOrUnknown(
          data['payload_sha256']!,
          _payloadSha256Meta,
        ),
      );
    } else if (isInserting) {
      context.missing(_payloadSha256Meta);
    }
    if (data.containsKey('content_sha256')) {
      context.handle(
        _contentSha256Meta,
        contentSha256.isAcceptableOrUnknown(
          data['content_sha256']!,
          _contentSha256Meta,
        ),
      );
    } else if (isInserting) {
      context.missing(_contentSha256Meta);
    }
    if (data.containsKey('goal_id')) {
      context.handle(
        _goalIdMeta,
        goalId.isAcceptableOrUnknown(data['goal_id']!, _goalIdMeta),
      );
    } else if (isInserting) {
      context.missing(_goalIdMeta);
    }
    if (data.containsKey('imported_at')) {
      context.handle(
        _importedAtMeta,
        importedAt.isAcceptableOrUnknown(data['imported_at']!, _importedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_importedAtMeta);
    }
    if (data.containsKey('node_count')) {
      context.handle(
        _nodeCountMeta,
        nodeCount.isAcceptableOrUnknown(data['node_count']!, _nodeCountMeta),
      );
    } else if (isInserting) {
      context.missing(_nodeCountMeta);
    }
    if (data.containsKey('mission_count')) {
      context.handle(
        _missionCountMeta,
        missionCount.isAcceptableOrUnknown(
          data['mission_count']!,
          _missionCountMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_missionCountMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {schemaName, packageId};
  @override
  ImportReceipt map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ImportReceipt(
      schemaName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}schema_name'],
      )!,
      packageId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}package_id'],
      )!,
      schemaVersion: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}schema_version'],
      )!,
      payloadSha256: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}payload_sha256'],
      )!,
      contentSha256: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}content_sha256'],
      )!,
      goalId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}goal_id'],
      )!,
      importedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}imported_at'],
      )!,
      nodeCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}node_count'],
      )!,
      missionCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}mission_count'],
      )!,
    );
  }

  @override
  $ImportReceiptsTable createAlias(String alias) {
    return $ImportReceiptsTable(attachedDatabase, alias);
  }
}

class ImportReceipt extends DataClass implements Insertable<ImportReceipt> {
  final String schemaName;
  final String packageId;
  final int schemaVersion;
  final String payloadSha256;
  final String contentSha256;
  final String goalId;
  final int importedAt;
  final int nodeCount;
  final int missionCount;
  const ImportReceipt({
    required this.schemaName,
    required this.packageId,
    required this.schemaVersion,
    required this.payloadSha256,
    required this.contentSha256,
    required this.goalId,
    required this.importedAt,
    required this.nodeCount,
    required this.missionCount,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['schema_name'] = Variable<String>(schemaName);
    map['package_id'] = Variable<String>(packageId);
    map['schema_version'] = Variable<int>(schemaVersion);
    map['payload_sha256'] = Variable<String>(payloadSha256);
    map['content_sha256'] = Variable<String>(contentSha256);
    map['goal_id'] = Variable<String>(goalId);
    map['imported_at'] = Variable<int>(importedAt);
    map['node_count'] = Variable<int>(nodeCount);
    map['mission_count'] = Variable<int>(missionCount);
    return map;
  }

  ImportReceiptsCompanion toCompanion(bool nullToAbsent) {
    return ImportReceiptsCompanion(
      schemaName: Value(schemaName),
      packageId: Value(packageId),
      schemaVersion: Value(schemaVersion),
      payloadSha256: Value(payloadSha256),
      contentSha256: Value(contentSha256),
      goalId: Value(goalId),
      importedAt: Value(importedAt),
      nodeCount: Value(nodeCount),
      missionCount: Value(missionCount),
    );
  }

  factory ImportReceipt.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ImportReceipt(
      schemaName: serializer.fromJson<String>(json['schemaName']),
      packageId: serializer.fromJson<String>(json['packageId']),
      schemaVersion: serializer.fromJson<int>(json['schemaVersion']),
      payloadSha256: serializer.fromJson<String>(json['payloadSha256']),
      contentSha256: serializer.fromJson<String>(json['contentSha256']),
      goalId: serializer.fromJson<String>(json['goalId']),
      importedAt: serializer.fromJson<int>(json['importedAt']),
      nodeCount: serializer.fromJson<int>(json['nodeCount']),
      missionCount: serializer.fromJson<int>(json['missionCount']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'schemaName': serializer.toJson<String>(schemaName),
      'packageId': serializer.toJson<String>(packageId),
      'schemaVersion': serializer.toJson<int>(schemaVersion),
      'payloadSha256': serializer.toJson<String>(payloadSha256),
      'contentSha256': serializer.toJson<String>(contentSha256),
      'goalId': serializer.toJson<String>(goalId),
      'importedAt': serializer.toJson<int>(importedAt),
      'nodeCount': serializer.toJson<int>(nodeCount),
      'missionCount': serializer.toJson<int>(missionCount),
    };
  }

  ImportReceipt copyWith({
    String? schemaName,
    String? packageId,
    int? schemaVersion,
    String? payloadSha256,
    String? contentSha256,
    String? goalId,
    int? importedAt,
    int? nodeCount,
    int? missionCount,
  }) => ImportReceipt(
    schemaName: schemaName ?? this.schemaName,
    packageId: packageId ?? this.packageId,
    schemaVersion: schemaVersion ?? this.schemaVersion,
    payloadSha256: payloadSha256 ?? this.payloadSha256,
    contentSha256: contentSha256 ?? this.contentSha256,
    goalId: goalId ?? this.goalId,
    importedAt: importedAt ?? this.importedAt,
    nodeCount: nodeCount ?? this.nodeCount,
    missionCount: missionCount ?? this.missionCount,
  );
  ImportReceipt copyWithCompanion(ImportReceiptsCompanion data) {
    return ImportReceipt(
      schemaName: data.schemaName.present
          ? data.schemaName.value
          : this.schemaName,
      packageId: data.packageId.present ? data.packageId.value : this.packageId,
      schemaVersion: data.schemaVersion.present
          ? data.schemaVersion.value
          : this.schemaVersion,
      payloadSha256: data.payloadSha256.present
          ? data.payloadSha256.value
          : this.payloadSha256,
      contentSha256: data.contentSha256.present
          ? data.contentSha256.value
          : this.contentSha256,
      goalId: data.goalId.present ? data.goalId.value : this.goalId,
      importedAt: data.importedAt.present
          ? data.importedAt.value
          : this.importedAt,
      nodeCount: data.nodeCount.present ? data.nodeCount.value : this.nodeCount,
      missionCount: data.missionCount.present
          ? data.missionCount.value
          : this.missionCount,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ImportReceipt(')
          ..write('schemaName: $schemaName, ')
          ..write('packageId: $packageId, ')
          ..write('schemaVersion: $schemaVersion, ')
          ..write('payloadSha256: $payloadSha256, ')
          ..write('contentSha256: $contentSha256, ')
          ..write('goalId: $goalId, ')
          ..write('importedAt: $importedAt, ')
          ..write('nodeCount: $nodeCount, ')
          ..write('missionCount: $missionCount')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    schemaName,
    packageId,
    schemaVersion,
    payloadSha256,
    contentSha256,
    goalId,
    importedAt,
    nodeCount,
    missionCount,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ImportReceipt &&
          other.schemaName == this.schemaName &&
          other.packageId == this.packageId &&
          other.schemaVersion == this.schemaVersion &&
          other.payloadSha256 == this.payloadSha256 &&
          other.contentSha256 == this.contentSha256 &&
          other.goalId == this.goalId &&
          other.importedAt == this.importedAt &&
          other.nodeCount == this.nodeCount &&
          other.missionCount == this.missionCount);
}

class ImportReceiptsCompanion extends UpdateCompanion<ImportReceipt> {
  final Value<String> schemaName;
  final Value<String> packageId;
  final Value<int> schemaVersion;
  final Value<String> payloadSha256;
  final Value<String> contentSha256;
  final Value<String> goalId;
  final Value<int> importedAt;
  final Value<int> nodeCount;
  final Value<int> missionCount;
  final Value<int> rowid;
  const ImportReceiptsCompanion({
    this.schemaName = const Value.absent(),
    this.packageId = const Value.absent(),
    this.schemaVersion = const Value.absent(),
    this.payloadSha256 = const Value.absent(),
    this.contentSha256 = const Value.absent(),
    this.goalId = const Value.absent(),
    this.importedAt = const Value.absent(),
    this.nodeCount = const Value.absent(),
    this.missionCount = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ImportReceiptsCompanion.insert({
    required String schemaName,
    required String packageId,
    required int schemaVersion,
    required String payloadSha256,
    required String contentSha256,
    required String goalId,
    required int importedAt,
    required int nodeCount,
    required int missionCount,
    this.rowid = const Value.absent(),
  }) : schemaName = Value(schemaName),
       packageId = Value(packageId),
       schemaVersion = Value(schemaVersion),
       payloadSha256 = Value(payloadSha256),
       contentSha256 = Value(contentSha256),
       goalId = Value(goalId),
       importedAt = Value(importedAt),
       nodeCount = Value(nodeCount),
       missionCount = Value(missionCount);
  static Insertable<ImportReceipt> custom({
    Expression<String>? schemaName,
    Expression<String>? packageId,
    Expression<int>? schemaVersion,
    Expression<String>? payloadSha256,
    Expression<String>? contentSha256,
    Expression<String>? goalId,
    Expression<int>? importedAt,
    Expression<int>? nodeCount,
    Expression<int>? missionCount,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (schemaName != null) 'schema_name': schemaName,
      if (packageId != null) 'package_id': packageId,
      if (schemaVersion != null) 'schema_version': schemaVersion,
      if (payloadSha256 != null) 'payload_sha256': payloadSha256,
      if (contentSha256 != null) 'content_sha256': contentSha256,
      if (goalId != null) 'goal_id': goalId,
      if (importedAt != null) 'imported_at': importedAt,
      if (nodeCount != null) 'node_count': nodeCount,
      if (missionCount != null) 'mission_count': missionCount,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ImportReceiptsCompanion copyWith({
    Value<String>? schemaName,
    Value<String>? packageId,
    Value<int>? schemaVersion,
    Value<String>? payloadSha256,
    Value<String>? contentSha256,
    Value<String>? goalId,
    Value<int>? importedAt,
    Value<int>? nodeCount,
    Value<int>? missionCount,
    Value<int>? rowid,
  }) {
    return ImportReceiptsCompanion(
      schemaName: schemaName ?? this.schemaName,
      packageId: packageId ?? this.packageId,
      schemaVersion: schemaVersion ?? this.schemaVersion,
      payloadSha256: payloadSha256 ?? this.payloadSha256,
      contentSha256: contentSha256 ?? this.contentSha256,
      goalId: goalId ?? this.goalId,
      importedAt: importedAt ?? this.importedAt,
      nodeCount: nodeCount ?? this.nodeCount,
      missionCount: missionCount ?? this.missionCount,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (schemaName.present) {
      map['schema_name'] = Variable<String>(schemaName.value);
    }
    if (packageId.present) {
      map['package_id'] = Variable<String>(packageId.value);
    }
    if (schemaVersion.present) {
      map['schema_version'] = Variable<int>(schemaVersion.value);
    }
    if (payloadSha256.present) {
      map['payload_sha256'] = Variable<String>(payloadSha256.value);
    }
    if (contentSha256.present) {
      map['content_sha256'] = Variable<String>(contentSha256.value);
    }
    if (goalId.present) {
      map['goal_id'] = Variable<String>(goalId.value);
    }
    if (importedAt.present) {
      map['imported_at'] = Variable<int>(importedAt.value);
    }
    if (nodeCount.present) {
      map['node_count'] = Variable<int>(nodeCount.value);
    }
    if (missionCount.present) {
      map['mission_count'] = Variable<int>(missionCount.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ImportReceiptsCompanion(')
          ..write('schemaName: $schemaName, ')
          ..write('packageId: $packageId, ')
          ..write('schemaVersion: $schemaVersion, ')
          ..write('payloadSha256: $payloadSha256, ')
          ..write('contentSha256: $contentSha256, ')
          ..write('goalId: $goalId, ')
          ..write('importedAt: $importedAt, ')
          ..write('nodeCount: $nodeCount, ')
          ..write('missionCount: $missionCount, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $AssistantSessionsTable extends AssistantSessions
    with TableInfo<$AssistantSessionsTable, AssistantSession> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AssistantSessionsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<int> updatedAt = GeneratedColumn<int>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _missionIdMeta = const VerificationMeta(
    'missionId',
  );
  @override
  late final GeneratedColumn<String> missionId = GeneratedColumn<String>(
    'mission_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _nodeIdMeta = const VerificationMeta('nodeId');
  @override
  late final GeneratedColumn<String> nodeId = GeneratedColumn<String>(
    'node_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _goalIdMeta = const VerificationMeta('goalId');
  @override
  late final GeneratedColumn<String> goalId = GeneratedColumn<String>(
    'goal_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _writerTokenMeta = const VerificationMeta(
    'writerToken',
  );
  @override
  late final GeneratedColumn<String> writerToken = GeneratedColumn<String>(
    'writer_token',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _writerLeaseUntilMeta = const VerificationMeta(
    'writerLeaseUntil',
  );
  @override
  late final GeneratedColumn<int> writerLeaseUntil = GeneratedColumn<int>(
    'writer_lease_until',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    title,
    createdAt,
    updatedAt,
    missionId,
    nodeId,
    goalId,
    writerToken,
    writerLeaseUntil,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'assistant_sessions';
  @override
  VerificationContext validateIntegrity(
    Insertable<AssistantSession> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('mission_id')) {
      context.handle(
        _missionIdMeta,
        missionId.isAcceptableOrUnknown(data['mission_id']!, _missionIdMeta),
      );
    }
    if (data.containsKey('node_id')) {
      context.handle(
        _nodeIdMeta,
        nodeId.isAcceptableOrUnknown(data['node_id']!, _nodeIdMeta),
      );
    }
    if (data.containsKey('goal_id')) {
      context.handle(
        _goalIdMeta,
        goalId.isAcceptableOrUnknown(data['goal_id']!, _goalIdMeta),
      );
    }
    if (data.containsKey('writer_token')) {
      context.handle(
        _writerTokenMeta,
        writerToken.isAcceptableOrUnknown(
          data['writer_token']!,
          _writerTokenMeta,
        ),
      );
    }
    if (data.containsKey('writer_lease_until')) {
      context.handle(
        _writerLeaseUntilMeta,
        writerLeaseUntil.isAcceptableOrUnknown(
          data['writer_lease_until']!,
          _writerLeaseUntilMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  AssistantSession map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AssistantSession(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at'],
      )!,
      missionId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}mission_id'],
      ),
      nodeId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}node_id'],
      ),
      goalId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}goal_id'],
      ),
      writerToken: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}writer_token'],
      ),
      writerLeaseUntil: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}writer_lease_until'],
      ),
    );
  }

  @override
  $AssistantSessionsTable createAlias(String alias) {
    return $AssistantSessionsTable(attachedDatabase, alias);
  }
}

class AssistantSession extends DataClass
    implements Insertable<AssistantSession> {
  final String id;
  final String title;
  final int createdAt;
  final int updatedAt;
  final String? missionId;
  final String? nodeId;
  final String? goalId;
  final String? writerToken;
  final int? writerLeaseUntil;
  const AssistantSession({
    required this.id,
    required this.title,
    required this.createdAt,
    required this.updatedAt,
    this.missionId,
    this.nodeId,
    this.goalId,
    this.writerToken,
    this.writerLeaseUntil,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['title'] = Variable<String>(title);
    map['created_at'] = Variable<int>(createdAt);
    map['updated_at'] = Variable<int>(updatedAt);
    if (!nullToAbsent || missionId != null) {
      map['mission_id'] = Variable<String>(missionId);
    }
    if (!nullToAbsent || nodeId != null) {
      map['node_id'] = Variable<String>(nodeId);
    }
    if (!nullToAbsent || goalId != null) {
      map['goal_id'] = Variable<String>(goalId);
    }
    if (!nullToAbsent || writerToken != null) {
      map['writer_token'] = Variable<String>(writerToken);
    }
    if (!nullToAbsent || writerLeaseUntil != null) {
      map['writer_lease_until'] = Variable<int>(writerLeaseUntil);
    }
    return map;
  }

  AssistantSessionsCompanion toCompanion(bool nullToAbsent) {
    return AssistantSessionsCompanion(
      id: Value(id),
      title: Value(title),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      missionId: missionId == null && nullToAbsent
          ? const Value.absent()
          : Value(missionId),
      nodeId: nodeId == null && nullToAbsent
          ? const Value.absent()
          : Value(nodeId),
      goalId: goalId == null && nullToAbsent
          ? const Value.absent()
          : Value(goalId),
      writerToken: writerToken == null && nullToAbsent
          ? const Value.absent()
          : Value(writerToken),
      writerLeaseUntil: writerLeaseUntil == null && nullToAbsent
          ? const Value.absent()
          : Value(writerLeaseUntil),
    );
  }

  factory AssistantSession.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AssistantSession(
      id: serializer.fromJson<String>(json['id']),
      title: serializer.fromJson<String>(json['title']),
      createdAt: serializer.fromJson<int>(json['createdAt']),
      updatedAt: serializer.fromJson<int>(json['updatedAt']),
      missionId: serializer.fromJson<String?>(json['missionId']),
      nodeId: serializer.fromJson<String?>(json['nodeId']),
      goalId: serializer.fromJson<String?>(json['goalId']),
      writerToken: serializer.fromJson<String?>(json['writerToken']),
      writerLeaseUntil: serializer.fromJson<int?>(json['writerLeaseUntil']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'title': serializer.toJson<String>(title),
      'createdAt': serializer.toJson<int>(createdAt),
      'updatedAt': serializer.toJson<int>(updatedAt),
      'missionId': serializer.toJson<String?>(missionId),
      'nodeId': serializer.toJson<String?>(nodeId),
      'goalId': serializer.toJson<String?>(goalId),
      'writerToken': serializer.toJson<String?>(writerToken),
      'writerLeaseUntil': serializer.toJson<int?>(writerLeaseUntil),
    };
  }

  AssistantSession copyWith({
    String? id,
    String? title,
    int? createdAt,
    int? updatedAt,
    Value<String?> missionId = const Value.absent(),
    Value<String?> nodeId = const Value.absent(),
    Value<String?> goalId = const Value.absent(),
    Value<String?> writerToken = const Value.absent(),
    Value<int?> writerLeaseUntil = const Value.absent(),
  }) => AssistantSession(
    id: id ?? this.id,
    title: title ?? this.title,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    missionId: missionId.present ? missionId.value : this.missionId,
    nodeId: nodeId.present ? nodeId.value : this.nodeId,
    goalId: goalId.present ? goalId.value : this.goalId,
    writerToken: writerToken.present ? writerToken.value : this.writerToken,
    writerLeaseUntil: writerLeaseUntil.present
        ? writerLeaseUntil.value
        : this.writerLeaseUntil,
  );
  AssistantSession copyWithCompanion(AssistantSessionsCompanion data) {
    return AssistantSession(
      id: data.id.present ? data.id.value : this.id,
      title: data.title.present ? data.title.value : this.title,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      missionId: data.missionId.present ? data.missionId.value : this.missionId,
      nodeId: data.nodeId.present ? data.nodeId.value : this.nodeId,
      goalId: data.goalId.present ? data.goalId.value : this.goalId,
      writerToken: data.writerToken.present
          ? data.writerToken.value
          : this.writerToken,
      writerLeaseUntil: data.writerLeaseUntil.present
          ? data.writerLeaseUntil.value
          : this.writerLeaseUntil,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AssistantSession(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('missionId: $missionId, ')
          ..write('nodeId: $nodeId, ')
          ..write('goalId: $goalId, ')
          ..write('writerToken: $writerToken, ')
          ..write('writerLeaseUntil: $writerLeaseUntil')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    title,
    createdAt,
    updatedAt,
    missionId,
    nodeId,
    goalId,
    writerToken,
    writerLeaseUntil,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AssistantSession &&
          other.id == this.id &&
          other.title == this.title &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.missionId == this.missionId &&
          other.nodeId == this.nodeId &&
          other.goalId == this.goalId &&
          other.writerToken == this.writerToken &&
          other.writerLeaseUntil == this.writerLeaseUntil);
}

class AssistantSessionsCompanion extends UpdateCompanion<AssistantSession> {
  final Value<String> id;
  final Value<String> title;
  final Value<int> createdAt;
  final Value<int> updatedAt;
  final Value<String?> missionId;
  final Value<String?> nodeId;
  final Value<String?> goalId;
  final Value<String?> writerToken;
  final Value<int?> writerLeaseUntil;
  final Value<int> rowid;
  const AssistantSessionsCompanion({
    this.id = const Value.absent(),
    this.title = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.missionId = const Value.absent(),
    this.nodeId = const Value.absent(),
    this.goalId = const Value.absent(),
    this.writerToken = const Value.absent(),
    this.writerLeaseUntil = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  AssistantSessionsCompanion.insert({
    required String id,
    required String title,
    required int createdAt,
    required int updatedAt,
    this.missionId = const Value.absent(),
    this.nodeId = const Value.absent(),
    this.goalId = const Value.absent(),
    this.writerToken = const Value.absent(),
    this.writerLeaseUntil = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       title = Value(title),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<AssistantSession> custom({
    Expression<String>? id,
    Expression<String>? title,
    Expression<int>? createdAt,
    Expression<int>? updatedAt,
    Expression<String>? missionId,
    Expression<String>? nodeId,
    Expression<String>? goalId,
    Expression<String>? writerToken,
    Expression<int>? writerLeaseUntil,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (title != null) 'title': title,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (missionId != null) 'mission_id': missionId,
      if (nodeId != null) 'node_id': nodeId,
      if (goalId != null) 'goal_id': goalId,
      if (writerToken != null) 'writer_token': writerToken,
      if (writerLeaseUntil != null) 'writer_lease_until': writerLeaseUntil,
      if (rowid != null) 'rowid': rowid,
    });
  }

  AssistantSessionsCompanion copyWith({
    Value<String>? id,
    Value<String>? title,
    Value<int>? createdAt,
    Value<int>? updatedAt,
    Value<String?>? missionId,
    Value<String?>? nodeId,
    Value<String?>? goalId,
    Value<String?>? writerToken,
    Value<int?>? writerLeaseUntil,
    Value<int>? rowid,
  }) {
    return AssistantSessionsCompanion(
      id: id ?? this.id,
      title: title ?? this.title,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      missionId: missionId ?? this.missionId,
      nodeId: nodeId ?? this.nodeId,
      goalId: goalId ?? this.goalId,
      writerToken: writerToken ?? this.writerToken,
      writerLeaseUntil: writerLeaseUntil ?? this.writerLeaseUntil,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(updatedAt.value);
    }
    if (missionId.present) {
      map['mission_id'] = Variable<String>(missionId.value);
    }
    if (nodeId.present) {
      map['node_id'] = Variable<String>(nodeId.value);
    }
    if (goalId.present) {
      map['goal_id'] = Variable<String>(goalId.value);
    }
    if (writerToken.present) {
      map['writer_token'] = Variable<String>(writerToken.value);
    }
    if (writerLeaseUntil.present) {
      map['writer_lease_until'] = Variable<int>(writerLeaseUntil.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AssistantSessionsCompanion(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('missionId: $missionId, ')
          ..write('nodeId: $nodeId, ')
          ..write('goalId: $goalId, ')
          ..write('writerToken: $writerToken, ')
          ..write('writerLeaseUntil: $writerLeaseUntil, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $AssistantSessionRecordsTable extends AssistantSessionRecords
    with TableInfo<$AssistantSessionRecordsTable, AssistantSessionRecord> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AssistantSessionRecordsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _sessionIdMeta = const VerificationMeta(
    'sessionId',
  );
  @override
  late final GeneratedColumn<String> sessionId = GeneratedColumn<String>(
    'session_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES assistant_sessions (id)',
    ),
  );
  static const VerificationMeta _sequenceMeta = const VerificationMeta(
    'sequence',
  );
  @override
  late final GeneratedColumn<int> sequence = GeneratedColumn<int>(
    'sequence',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _timestampMeta = const VerificationMeta(
    'timestamp',
  );
  @override
  late final GeneratedColumn<int> timestamp = GeneratedColumn<int>(
    'timestamp',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _typeMeta = const VerificationMeta('type');
  @override
  late final GeneratedColumn<String> type = GeneratedColumn<String>(
    'type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _dataMeta = const VerificationMeta('data');
  @override
  late final GeneratedColumn<String> data = GeneratedColumn<String>(
    'data',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _versionMeta = const VerificationMeta(
    'version',
  );
  @override
  late final GeneratedColumn<int> version = GeneratedColumn<int>(
    'version',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
  );
  static const VerificationMeta _ignorableMeta = const VerificationMeta(
    'ignorable',
  );
  @override
  late final GeneratedColumn<bool> ignorable = GeneratedColumn<bool>(
    'ignorable',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("ignorable" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  @override
  List<GeneratedColumn> get $columns => [
    sessionId,
    sequence,
    timestamp,
    type,
    data,
    version,
    ignorable,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'assistant_session_records';
  @override
  VerificationContext validateIntegrity(
    Insertable<AssistantSessionRecord> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('session_id')) {
      context.handle(
        _sessionIdMeta,
        sessionId.isAcceptableOrUnknown(data['session_id']!, _sessionIdMeta),
      );
    } else if (isInserting) {
      context.missing(_sessionIdMeta);
    }
    if (data.containsKey('sequence')) {
      context.handle(
        _sequenceMeta,
        sequence.isAcceptableOrUnknown(data['sequence']!, _sequenceMeta),
      );
    } else if (isInserting) {
      context.missing(_sequenceMeta);
    }
    if (data.containsKey('timestamp')) {
      context.handle(
        _timestampMeta,
        timestamp.isAcceptableOrUnknown(data['timestamp']!, _timestampMeta),
      );
    } else if (isInserting) {
      context.missing(_timestampMeta);
    }
    if (data.containsKey('type')) {
      context.handle(
        _typeMeta,
        type.isAcceptableOrUnknown(data['type']!, _typeMeta),
      );
    } else if (isInserting) {
      context.missing(_typeMeta);
    }
    if (data.containsKey('data')) {
      context.handle(
        _dataMeta,
        this.data.isAcceptableOrUnknown(data['data']!, _dataMeta),
      );
    } else if (isInserting) {
      context.missing(_dataMeta);
    }
    if (data.containsKey('version')) {
      context.handle(
        _versionMeta,
        version.isAcceptableOrUnknown(data['version']!, _versionMeta),
      );
    }
    if (data.containsKey('ignorable')) {
      context.handle(
        _ignorableMeta,
        ignorable.isAcceptableOrUnknown(data['ignorable']!, _ignorableMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {sessionId, sequence};
  @override
  AssistantSessionRecord map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AssistantSessionRecord(
      sessionId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}session_id'],
      )!,
      sequence: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sequence'],
      )!,
      timestamp: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}timestamp'],
      )!,
      type: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}type'],
      )!,
      data: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}data'],
      )!,
      version: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}version'],
      )!,
      ignorable: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}ignorable'],
      )!,
    );
  }

  @override
  $AssistantSessionRecordsTable createAlias(String alias) {
    return $AssistantSessionRecordsTable(attachedDatabase, alias);
  }
}

class AssistantSessionRecord extends DataClass
    implements Insertable<AssistantSessionRecord> {
  final String sessionId;
  final int sequence;
  final int timestamp;
  final String type;
  final String data;
  final int version;
  final bool ignorable;
  const AssistantSessionRecord({
    required this.sessionId,
    required this.sequence,
    required this.timestamp,
    required this.type,
    required this.data,
    required this.version,
    required this.ignorable,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['session_id'] = Variable<String>(sessionId);
    map['sequence'] = Variable<int>(sequence);
    map['timestamp'] = Variable<int>(timestamp);
    map['type'] = Variable<String>(type);
    map['data'] = Variable<String>(data);
    map['version'] = Variable<int>(version);
    map['ignorable'] = Variable<bool>(ignorable);
    return map;
  }

  AssistantSessionRecordsCompanion toCompanion(bool nullToAbsent) {
    return AssistantSessionRecordsCompanion(
      sessionId: Value(sessionId),
      sequence: Value(sequence),
      timestamp: Value(timestamp),
      type: Value(type),
      data: Value(data),
      version: Value(version),
      ignorable: Value(ignorable),
    );
  }

  factory AssistantSessionRecord.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AssistantSessionRecord(
      sessionId: serializer.fromJson<String>(json['sessionId']),
      sequence: serializer.fromJson<int>(json['sequence']),
      timestamp: serializer.fromJson<int>(json['timestamp']),
      type: serializer.fromJson<String>(json['type']),
      data: serializer.fromJson<String>(json['data']),
      version: serializer.fromJson<int>(json['version']),
      ignorable: serializer.fromJson<bool>(json['ignorable']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'sessionId': serializer.toJson<String>(sessionId),
      'sequence': serializer.toJson<int>(sequence),
      'timestamp': serializer.toJson<int>(timestamp),
      'type': serializer.toJson<String>(type),
      'data': serializer.toJson<String>(data),
      'version': serializer.toJson<int>(version),
      'ignorable': serializer.toJson<bool>(ignorable),
    };
  }

  AssistantSessionRecord copyWith({
    String? sessionId,
    int? sequence,
    int? timestamp,
    String? type,
    String? data,
    int? version,
    bool? ignorable,
  }) => AssistantSessionRecord(
    sessionId: sessionId ?? this.sessionId,
    sequence: sequence ?? this.sequence,
    timestamp: timestamp ?? this.timestamp,
    type: type ?? this.type,
    data: data ?? this.data,
    version: version ?? this.version,
    ignorable: ignorable ?? this.ignorable,
  );
  AssistantSessionRecord copyWithCompanion(
    AssistantSessionRecordsCompanion data,
  ) {
    return AssistantSessionRecord(
      sessionId: data.sessionId.present ? data.sessionId.value : this.sessionId,
      sequence: data.sequence.present ? data.sequence.value : this.sequence,
      timestamp: data.timestamp.present ? data.timestamp.value : this.timestamp,
      type: data.type.present ? data.type.value : this.type,
      data: data.data.present ? data.data.value : this.data,
      version: data.version.present ? data.version.value : this.version,
      ignorable: data.ignorable.present ? data.ignorable.value : this.ignorable,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AssistantSessionRecord(')
          ..write('sessionId: $sessionId, ')
          ..write('sequence: $sequence, ')
          ..write('timestamp: $timestamp, ')
          ..write('type: $type, ')
          ..write('data: $data, ')
          ..write('version: $version, ')
          ..write('ignorable: $ignorable')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    sessionId,
    sequence,
    timestamp,
    type,
    data,
    version,
    ignorable,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AssistantSessionRecord &&
          other.sessionId == this.sessionId &&
          other.sequence == this.sequence &&
          other.timestamp == this.timestamp &&
          other.type == this.type &&
          other.data == this.data &&
          other.version == this.version &&
          other.ignorable == this.ignorable);
}

class AssistantSessionRecordsCompanion
    extends UpdateCompanion<AssistantSessionRecord> {
  final Value<String> sessionId;
  final Value<int> sequence;
  final Value<int> timestamp;
  final Value<String> type;
  final Value<String> data;
  final Value<int> version;
  final Value<bool> ignorable;
  final Value<int> rowid;
  const AssistantSessionRecordsCompanion({
    this.sessionId = const Value.absent(),
    this.sequence = const Value.absent(),
    this.timestamp = const Value.absent(),
    this.type = const Value.absent(),
    this.data = const Value.absent(),
    this.version = const Value.absent(),
    this.ignorable = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  AssistantSessionRecordsCompanion.insert({
    required String sessionId,
    required int sequence,
    required int timestamp,
    required String type,
    required String data,
    this.version = const Value.absent(),
    this.ignorable = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : sessionId = Value(sessionId),
       sequence = Value(sequence),
       timestamp = Value(timestamp),
       type = Value(type),
       data = Value(data);
  static Insertable<AssistantSessionRecord> custom({
    Expression<String>? sessionId,
    Expression<int>? sequence,
    Expression<int>? timestamp,
    Expression<String>? type,
    Expression<String>? data,
    Expression<int>? version,
    Expression<bool>? ignorable,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (sessionId != null) 'session_id': sessionId,
      if (sequence != null) 'sequence': sequence,
      if (timestamp != null) 'timestamp': timestamp,
      if (type != null) 'type': type,
      if (data != null) 'data': data,
      if (version != null) 'version': version,
      if (ignorable != null) 'ignorable': ignorable,
      if (rowid != null) 'rowid': rowid,
    });
  }

  AssistantSessionRecordsCompanion copyWith({
    Value<String>? sessionId,
    Value<int>? sequence,
    Value<int>? timestamp,
    Value<String>? type,
    Value<String>? data,
    Value<int>? version,
    Value<bool>? ignorable,
    Value<int>? rowid,
  }) {
    return AssistantSessionRecordsCompanion(
      sessionId: sessionId ?? this.sessionId,
      sequence: sequence ?? this.sequence,
      timestamp: timestamp ?? this.timestamp,
      type: type ?? this.type,
      data: data ?? this.data,
      version: version ?? this.version,
      ignorable: ignorable ?? this.ignorable,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (sessionId.present) {
      map['session_id'] = Variable<String>(sessionId.value);
    }
    if (sequence.present) {
      map['sequence'] = Variable<int>(sequence.value);
    }
    if (timestamp.present) {
      map['timestamp'] = Variable<int>(timestamp.value);
    }
    if (type.present) {
      map['type'] = Variable<String>(type.value);
    }
    if (data.present) {
      map['data'] = Variable<String>(data.value);
    }
    if (version.present) {
      map['version'] = Variable<int>(version.value);
    }
    if (ignorable.present) {
      map['ignorable'] = Variable<bool>(ignorable.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AssistantSessionRecordsCompanion(')
          ..write('sessionId: $sessionId, ')
          ..write('sequence: $sequence, ')
          ..write('timestamp: $timestamp, ')
          ..write('type: $type, ')
          ..write('data: $data, ')
          ..write('version: $version, ')
          ..write('ignorable: $ignorable, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $OperationReceiptsTable extends OperationReceipts
    with TableInfo<$OperationReceiptsTable, OperationReceipt> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $OperationReceiptsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _kindMeta = const VerificationMeta('kind');
  @override
  late final GeneratedColumn<String> kind = GeneratedColumn<String>(
    'kind',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _fingerprintMeta = const VerificationMeta(
    'fingerprint',
  );
  @override
  late final GeneratedColumn<String> fingerprint = GeneratedColumn<String>(
    'fingerprint',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _entityIdMeta = const VerificationMeta(
    'entityId',
  );
  @override
  late final GeneratedColumn<String> entityId = GeneratedColumn<String>(
    'entity_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _resultJsonMeta = const VerificationMeta(
    'resultJson',
  );
  @override
  late final GeneratedColumn<String> resultJson = GeneratedColumn<String>(
    'result_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    kind,
    fingerprint,
    entityId,
    resultJson,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'operation_receipts';
  @override
  VerificationContext validateIntegrity(
    Insertable<OperationReceipt> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('kind')) {
      context.handle(
        _kindMeta,
        kind.isAcceptableOrUnknown(data['kind']!, _kindMeta),
      );
    } else if (isInserting) {
      context.missing(_kindMeta);
    }
    if (data.containsKey('fingerprint')) {
      context.handle(
        _fingerprintMeta,
        fingerprint.isAcceptableOrUnknown(
          data['fingerprint']!,
          _fingerprintMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_fingerprintMeta);
    }
    if (data.containsKey('entity_id')) {
      context.handle(
        _entityIdMeta,
        entityId.isAcceptableOrUnknown(data['entity_id']!, _entityIdMeta),
      );
    } else if (isInserting) {
      context.missing(_entityIdMeta);
    }
    if (data.containsKey('result_json')) {
      context.handle(
        _resultJsonMeta,
        resultJson.isAcceptableOrUnknown(data['result_json']!, _resultJsonMeta),
      );
    } else if (isInserting) {
      context.missing(_resultJsonMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  OperationReceipt map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return OperationReceipt(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      kind: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}kind'],
      )!,
      fingerprint: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}fingerprint'],
      )!,
      entityId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}entity_id'],
      )!,
      resultJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}result_json'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $OperationReceiptsTable createAlias(String alias) {
    return $OperationReceiptsTable(attachedDatabase, alias);
  }
}

class OperationReceipt extends DataClass
    implements Insertable<OperationReceipt> {
  final String id;
  final String kind;
  final String fingerprint;
  final String entityId;
  final String resultJson;
  final int createdAt;
  const OperationReceipt({
    required this.id,
    required this.kind,
    required this.fingerprint,
    required this.entityId,
    required this.resultJson,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['kind'] = Variable<String>(kind);
    map['fingerprint'] = Variable<String>(fingerprint);
    map['entity_id'] = Variable<String>(entityId);
    map['result_json'] = Variable<String>(resultJson);
    map['created_at'] = Variable<int>(createdAt);
    return map;
  }

  OperationReceiptsCompanion toCompanion(bool nullToAbsent) {
    return OperationReceiptsCompanion(
      id: Value(id),
      kind: Value(kind),
      fingerprint: Value(fingerprint),
      entityId: Value(entityId),
      resultJson: Value(resultJson),
      createdAt: Value(createdAt),
    );
  }

  factory OperationReceipt.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return OperationReceipt(
      id: serializer.fromJson<String>(json['id']),
      kind: serializer.fromJson<String>(json['kind']),
      fingerprint: serializer.fromJson<String>(json['fingerprint']),
      entityId: serializer.fromJson<String>(json['entityId']),
      resultJson: serializer.fromJson<String>(json['resultJson']),
      createdAt: serializer.fromJson<int>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'kind': serializer.toJson<String>(kind),
      'fingerprint': serializer.toJson<String>(fingerprint),
      'entityId': serializer.toJson<String>(entityId),
      'resultJson': serializer.toJson<String>(resultJson),
      'createdAt': serializer.toJson<int>(createdAt),
    };
  }

  OperationReceipt copyWith({
    String? id,
    String? kind,
    String? fingerprint,
    String? entityId,
    String? resultJson,
    int? createdAt,
  }) => OperationReceipt(
    id: id ?? this.id,
    kind: kind ?? this.kind,
    fingerprint: fingerprint ?? this.fingerprint,
    entityId: entityId ?? this.entityId,
    resultJson: resultJson ?? this.resultJson,
    createdAt: createdAt ?? this.createdAt,
  );
  OperationReceipt copyWithCompanion(OperationReceiptsCompanion data) {
    return OperationReceipt(
      id: data.id.present ? data.id.value : this.id,
      kind: data.kind.present ? data.kind.value : this.kind,
      fingerprint: data.fingerprint.present
          ? data.fingerprint.value
          : this.fingerprint,
      entityId: data.entityId.present ? data.entityId.value : this.entityId,
      resultJson: data.resultJson.present
          ? data.resultJson.value
          : this.resultJson,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('OperationReceipt(')
          ..write('id: $id, ')
          ..write('kind: $kind, ')
          ..write('fingerprint: $fingerprint, ')
          ..write('entityId: $entityId, ')
          ..write('resultJson: $resultJson, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, kind, fingerprint, entityId, resultJson, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is OperationReceipt &&
          other.id == this.id &&
          other.kind == this.kind &&
          other.fingerprint == this.fingerprint &&
          other.entityId == this.entityId &&
          other.resultJson == this.resultJson &&
          other.createdAt == this.createdAt);
}

class OperationReceiptsCompanion extends UpdateCompanion<OperationReceipt> {
  final Value<String> id;
  final Value<String> kind;
  final Value<String> fingerprint;
  final Value<String> entityId;
  final Value<String> resultJson;
  final Value<int> createdAt;
  final Value<int> rowid;
  const OperationReceiptsCompanion({
    this.id = const Value.absent(),
    this.kind = const Value.absent(),
    this.fingerprint = const Value.absent(),
    this.entityId = const Value.absent(),
    this.resultJson = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  OperationReceiptsCompanion.insert({
    required String id,
    required String kind,
    required String fingerprint,
    required String entityId,
    required String resultJson,
    required int createdAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       kind = Value(kind),
       fingerprint = Value(fingerprint),
       entityId = Value(entityId),
       resultJson = Value(resultJson),
       createdAt = Value(createdAt);
  static Insertable<OperationReceipt> custom({
    Expression<String>? id,
    Expression<String>? kind,
    Expression<String>? fingerprint,
    Expression<String>? entityId,
    Expression<String>? resultJson,
    Expression<int>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (kind != null) 'kind': kind,
      if (fingerprint != null) 'fingerprint': fingerprint,
      if (entityId != null) 'entity_id': entityId,
      if (resultJson != null) 'result_json': resultJson,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  OperationReceiptsCompanion copyWith({
    Value<String>? id,
    Value<String>? kind,
    Value<String>? fingerprint,
    Value<String>? entityId,
    Value<String>? resultJson,
    Value<int>? createdAt,
    Value<int>? rowid,
  }) {
    return OperationReceiptsCompanion(
      id: id ?? this.id,
      kind: kind ?? this.kind,
      fingerprint: fingerprint ?? this.fingerprint,
      entityId: entityId ?? this.entityId,
      resultJson: resultJson ?? this.resultJson,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (kind.present) {
      map['kind'] = Variable<String>(kind.value);
    }
    if (fingerprint.present) {
      map['fingerprint'] = Variable<String>(fingerprint.value);
    }
    if (entityId.present) {
      map['entity_id'] = Variable<String>(entityId.value);
    }
    if (resultJson.present) {
      map['result_json'] = Variable<String>(resultJson.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('OperationReceiptsCompanion(')
          ..write('id: $id, ')
          ..write('kind: $kind, ')
          ..write('fingerprint: $fingerprint, ')
          ..write('entityId: $entityId, ')
          ..write('resultJson: $resultJson, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $RecordsTable extends Records with TableInfo<$RecordsTable, RecordRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $RecordsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _typeMeta = const VerificationMeta('type');
  @override
  late final GeneratedColumn<String> type = GeneratedColumn<String>(
    'type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sourceMeta = const VerificationMeta('source');
  @override
  late final GeneratedColumn<String> source = GeneratedColumn<String>(
    'source',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _contentMeta = const VerificationMeta(
    'content',
  );
  @override
  late final GeneratedColumn<String> content = GeneratedColumn<String>(
    'content',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _attachmentStorageKeyMeta =
      const VerificationMeta('attachmentStorageKey');
  @override
  late final GeneratedColumn<String> attachmentStorageKey =
      GeneratedColumn<String>(
        'attachment_storage_key',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
        defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'),
      );
  static const VerificationMeta _attachmentFileNameMeta =
      const VerificationMeta('attachmentFileName');
  @override
  late final GeneratedColumn<String> attachmentFileName =
      GeneratedColumn<String>(
        'attachment_file_name',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _attachmentMimeTypeMeta =
      const VerificationMeta('attachmentMimeType');
  @override
  late final GeneratedColumn<String> attachmentMimeType =
      GeneratedColumn<String>(
        'attachment_mime_type',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _capturedAtMeta = const VerificationMeta(
    'capturedAt',
  );
  @override
  late final GeneratedColumn<int> capturedAt = GeneratedColumn<int>(
    'captured_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _occurredAtMeta = const VerificationMeta(
    'occurredAt',
  );
  @override
  late final GeneratedColumn<int> occurredAt = GeneratedColumn<int>(
    'occurred_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _goalIdMeta = const VerificationMeta('goalId');
  @override
  late final GeneratedColumn<String> goalId = GeneratedColumn<String>(
    'goal_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES goals (id)',
    ),
  );
  static const VerificationMeta _goalNodeIdMeta = const VerificationMeta(
    'goalNodeId',
  );
  @override
  late final GeneratedColumn<String> goalNodeId = GeneratedColumn<String>(
    'goal_node_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES goal_nodes (id)',
    ),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    type,
    source,
    content,
    attachmentStorageKey,
    attachmentFileName,
    attachmentMimeType,
    capturedAt,
    occurredAt,
    createdAt,
    goalId,
    goalNodeId,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'records';
  @override
  VerificationContext validateIntegrity(
    Insertable<RecordRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('type')) {
      context.handle(
        _typeMeta,
        type.isAcceptableOrUnknown(data['type']!, _typeMeta),
      );
    } else if (isInserting) {
      context.missing(_typeMeta);
    }
    if (data.containsKey('source')) {
      context.handle(
        _sourceMeta,
        source.isAcceptableOrUnknown(data['source']!, _sourceMeta),
      );
    } else if (isInserting) {
      context.missing(_sourceMeta);
    }
    if (data.containsKey('content')) {
      context.handle(
        _contentMeta,
        content.isAcceptableOrUnknown(data['content']!, _contentMeta),
      );
    }
    if (data.containsKey('attachment_storage_key')) {
      context.handle(
        _attachmentStorageKeyMeta,
        attachmentStorageKey.isAcceptableOrUnknown(
          data['attachment_storage_key']!,
          _attachmentStorageKeyMeta,
        ),
      );
    }
    if (data.containsKey('attachment_file_name')) {
      context.handle(
        _attachmentFileNameMeta,
        attachmentFileName.isAcceptableOrUnknown(
          data['attachment_file_name']!,
          _attachmentFileNameMeta,
        ),
      );
    }
    if (data.containsKey('attachment_mime_type')) {
      context.handle(
        _attachmentMimeTypeMeta,
        attachmentMimeType.isAcceptableOrUnknown(
          data['attachment_mime_type']!,
          _attachmentMimeTypeMeta,
        ),
      );
    }
    if (data.containsKey('captured_at')) {
      context.handle(
        _capturedAtMeta,
        capturedAt.isAcceptableOrUnknown(data['captured_at']!, _capturedAtMeta),
      );
    }
    if (data.containsKey('occurred_at')) {
      context.handle(
        _occurredAtMeta,
        occurredAt.isAcceptableOrUnknown(data['occurred_at']!, _occurredAtMeta),
      );
    } else if (isInserting) {
      context.missing(_occurredAtMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('goal_id')) {
      context.handle(
        _goalIdMeta,
        goalId.isAcceptableOrUnknown(data['goal_id']!, _goalIdMeta),
      );
    }
    if (data.containsKey('goal_node_id')) {
      context.handle(
        _goalNodeIdMeta,
        goalNodeId.isAcceptableOrUnknown(
          data['goal_node_id']!,
          _goalNodeIdMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  RecordRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return RecordRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      type: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}type'],
      )!,
      source: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source'],
      )!,
      content: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}content'],
      ),
      attachmentStorageKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}attachment_storage_key'],
      ),
      attachmentFileName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}attachment_file_name'],
      ),
      attachmentMimeType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}attachment_mime_type'],
      ),
      capturedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}captured_at'],
      ),
      occurredAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}occurred_at'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at'],
      )!,
      goalId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}goal_id'],
      ),
      goalNodeId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}goal_node_id'],
      ),
    );
  }

  @override
  $RecordsTable createAlias(String alias) {
    return $RecordsTable(attachedDatabase, alias);
  }
}

class RecordRow extends DataClass implements Insertable<RecordRow> {
  final String id;
  final String type;
  final String source;
  final String? content;
  final String? attachmentStorageKey;
  final String? attachmentFileName;
  final String? attachmentMimeType;
  final int? capturedAt;
  final int occurredAt;
  final int createdAt;
  final String? goalId;
  final String? goalNodeId;
  const RecordRow({
    required this.id,
    required this.type,
    required this.source,
    this.content,
    this.attachmentStorageKey,
    this.attachmentFileName,
    this.attachmentMimeType,
    this.capturedAt,
    required this.occurredAt,
    required this.createdAt,
    this.goalId,
    this.goalNodeId,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['type'] = Variable<String>(type);
    map['source'] = Variable<String>(source);
    if (!nullToAbsent || content != null) {
      map['content'] = Variable<String>(content);
    }
    if (!nullToAbsent || attachmentStorageKey != null) {
      map['attachment_storage_key'] = Variable<String>(attachmentStorageKey);
    }
    if (!nullToAbsent || attachmentFileName != null) {
      map['attachment_file_name'] = Variable<String>(attachmentFileName);
    }
    if (!nullToAbsent || attachmentMimeType != null) {
      map['attachment_mime_type'] = Variable<String>(attachmentMimeType);
    }
    if (!nullToAbsent || capturedAt != null) {
      map['captured_at'] = Variable<int>(capturedAt);
    }
    map['occurred_at'] = Variable<int>(occurredAt);
    map['created_at'] = Variable<int>(createdAt);
    if (!nullToAbsent || goalId != null) {
      map['goal_id'] = Variable<String>(goalId);
    }
    if (!nullToAbsent || goalNodeId != null) {
      map['goal_node_id'] = Variable<String>(goalNodeId);
    }
    return map;
  }

  RecordsCompanion toCompanion(bool nullToAbsent) {
    return RecordsCompanion(
      id: Value(id),
      type: Value(type),
      source: Value(source),
      content: content == null && nullToAbsent
          ? const Value.absent()
          : Value(content),
      attachmentStorageKey: attachmentStorageKey == null && nullToAbsent
          ? const Value.absent()
          : Value(attachmentStorageKey),
      attachmentFileName: attachmentFileName == null && nullToAbsent
          ? const Value.absent()
          : Value(attachmentFileName),
      attachmentMimeType: attachmentMimeType == null && nullToAbsent
          ? const Value.absent()
          : Value(attachmentMimeType),
      capturedAt: capturedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(capturedAt),
      occurredAt: Value(occurredAt),
      createdAt: Value(createdAt),
      goalId: goalId == null && nullToAbsent
          ? const Value.absent()
          : Value(goalId),
      goalNodeId: goalNodeId == null && nullToAbsent
          ? const Value.absent()
          : Value(goalNodeId),
    );
  }

  factory RecordRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return RecordRow(
      id: serializer.fromJson<String>(json['id']),
      type: serializer.fromJson<String>(json['type']),
      source: serializer.fromJson<String>(json['source']),
      content: serializer.fromJson<String?>(json['content']),
      attachmentStorageKey: serializer.fromJson<String?>(
        json['attachmentStorageKey'],
      ),
      attachmentFileName: serializer.fromJson<String?>(
        json['attachmentFileName'],
      ),
      attachmentMimeType: serializer.fromJson<String?>(
        json['attachmentMimeType'],
      ),
      capturedAt: serializer.fromJson<int?>(json['capturedAt']),
      occurredAt: serializer.fromJson<int>(json['occurredAt']),
      createdAt: serializer.fromJson<int>(json['createdAt']),
      goalId: serializer.fromJson<String?>(json['goalId']),
      goalNodeId: serializer.fromJson<String?>(json['goalNodeId']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'type': serializer.toJson<String>(type),
      'source': serializer.toJson<String>(source),
      'content': serializer.toJson<String?>(content),
      'attachmentStorageKey': serializer.toJson<String?>(attachmentStorageKey),
      'attachmentFileName': serializer.toJson<String?>(attachmentFileName),
      'attachmentMimeType': serializer.toJson<String?>(attachmentMimeType),
      'capturedAt': serializer.toJson<int?>(capturedAt),
      'occurredAt': serializer.toJson<int>(occurredAt),
      'createdAt': serializer.toJson<int>(createdAt),
      'goalId': serializer.toJson<String?>(goalId),
      'goalNodeId': serializer.toJson<String?>(goalNodeId),
    };
  }

  RecordRow copyWith({
    String? id,
    String? type,
    String? source,
    Value<String?> content = const Value.absent(),
    Value<String?> attachmentStorageKey = const Value.absent(),
    Value<String?> attachmentFileName = const Value.absent(),
    Value<String?> attachmentMimeType = const Value.absent(),
    Value<int?> capturedAt = const Value.absent(),
    int? occurredAt,
    int? createdAt,
    Value<String?> goalId = const Value.absent(),
    Value<String?> goalNodeId = const Value.absent(),
  }) => RecordRow(
    id: id ?? this.id,
    type: type ?? this.type,
    source: source ?? this.source,
    content: content.present ? content.value : this.content,
    attachmentStorageKey: attachmentStorageKey.present
        ? attachmentStorageKey.value
        : this.attachmentStorageKey,
    attachmentFileName: attachmentFileName.present
        ? attachmentFileName.value
        : this.attachmentFileName,
    attachmentMimeType: attachmentMimeType.present
        ? attachmentMimeType.value
        : this.attachmentMimeType,
    capturedAt: capturedAt.present ? capturedAt.value : this.capturedAt,
    occurredAt: occurredAt ?? this.occurredAt,
    createdAt: createdAt ?? this.createdAt,
    goalId: goalId.present ? goalId.value : this.goalId,
    goalNodeId: goalNodeId.present ? goalNodeId.value : this.goalNodeId,
  );
  RecordRow copyWithCompanion(RecordsCompanion data) {
    return RecordRow(
      id: data.id.present ? data.id.value : this.id,
      type: data.type.present ? data.type.value : this.type,
      source: data.source.present ? data.source.value : this.source,
      content: data.content.present ? data.content.value : this.content,
      attachmentStorageKey: data.attachmentStorageKey.present
          ? data.attachmentStorageKey.value
          : this.attachmentStorageKey,
      attachmentFileName: data.attachmentFileName.present
          ? data.attachmentFileName.value
          : this.attachmentFileName,
      attachmentMimeType: data.attachmentMimeType.present
          ? data.attachmentMimeType.value
          : this.attachmentMimeType,
      capturedAt: data.capturedAt.present
          ? data.capturedAt.value
          : this.capturedAt,
      occurredAt: data.occurredAt.present
          ? data.occurredAt.value
          : this.occurredAt,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      goalId: data.goalId.present ? data.goalId.value : this.goalId,
      goalNodeId: data.goalNodeId.present
          ? data.goalNodeId.value
          : this.goalNodeId,
    );
  }

  @override
  String toString() {
    return (StringBuffer('RecordRow(')
          ..write('id: $id, ')
          ..write('type: $type, ')
          ..write('source: $source, ')
          ..write('content: $content, ')
          ..write('attachmentStorageKey: $attachmentStorageKey, ')
          ..write('attachmentFileName: $attachmentFileName, ')
          ..write('attachmentMimeType: $attachmentMimeType, ')
          ..write('capturedAt: $capturedAt, ')
          ..write('occurredAt: $occurredAt, ')
          ..write('createdAt: $createdAt, ')
          ..write('goalId: $goalId, ')
          ..write('goalNodeId: $goalNodeId')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    type,
    source,
    content,
    attachmentStorageKey,
    attachmentFileName,
    attachmentMimeType,
    capturedAt,
    occurredAt,
    createdAt,
    goalId,
    goalNodeId,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is RecordRow &&
          other.id == this.id &&
          other.type == this.type &&
          other.source == this.source &&
          other.content == this.content &&
          other.attachmentStorageKey == this.attachmentStorageKey &&
          other.attachmentFileName == this.attachmentFileName &&
          other.attachmentMimeType == this.attachmentMimeType &&
          other.capturedAt == this.capturedAt &&
          other.occurredAt == this.occurredAt &&
          other.createdAt == this.createdAt &&
          other.goalId == this.goalId &&
          other.goalNodeId == this.goalNodeId);
}

class RecordsCompanion extends UpdateCompanion<RecordRow> {
  final Value<String> id;
  final Value<String> type;
  final Value<String> source;
  final Value<String?> content;
  final Value<String?> attachmentStorageKey;
  final Value<String?> attachmentFileName;
  final Value<String?> attachmentMimeType;
  final Value<int?> capturedAt;
  final Value<int> occurredAt;
  final Value<int> createdAt;
  final Value<String?> goalId;
  final Value<String?> goalNodeId;
  final Value<int> rowid;
  const RecordsCompanion({
    this.id = const Value.absent(),
    this.type = const Value.absent(),
    this.source = const Value.absent(),
    this.content = const Value.absent(),
    this.attachmentStorageKey = const Value.absent(),
    this.attachmentFileName = const Value.absent(),
    this.attachmentMimeType = const Value.absent(),
    this.capturedAt = const Value.absent(),
    this.occurredAt = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.goalId = const Value.absent(),
    this.goalNodeId = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  RecordsCompanion.insert({
    required String id,
    required String type,
    required String source,
    this.content = const Value.absent(),
    this.attachmentStorageKey = const Value.absent(),
    this.attachmentFileName = const Value.absent(),
    this.attachmentMimeType = const Value.absent(),
    this.capturedAt = const Value.absent(),
    required int occurredAt,
    required int createdAt,
    this.goalId = const Value.absent(),
    this.goalNodeId = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       type = Value(type),
       source = Value(source),
       occurredAt = Value(occurredAt),
       createdAt = Value(createdAt);
  static Insertable<RecordRow> custom({
    Expression<String>? id,
    Expression<String>? type,
    Expression<String>? source,
    Expression<String>? content,
    Expression<String>? attachmentStorageKey,
    Expression<String>? attachmentFileName,
    Expression<String>? attachmentMimeType,
    Expression<int>? capturedAt,
    Expression<int>? occurredAt,
    Expression<int>? createdAt,
    Expression<String>? goalId,
    Expression<String>? goalNodeId,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (type != null) 'type': type,
      if (source != null) 'source': source,
      if (content != null) 'content': content,
      if (attachmentStorageKey != null)
        'attachment_storage_key': attachmentStorageKey,
      if (attachmentFileName != null)
        'attachment_file_name': attachmentFileName,
      if (attachmentMimeType != null)
        'attachment_mime_type': attachmentMimeType,
      if (capturedAt != null) 'captured_at': capturedAt,
      if (occurredAt != null) 'occurred_at': occurredAt,
      if (createdAt != null) 'created_at': createdAt,
      if (goalId != null) 'goal_id': goalId,
      if (goalNodeId != null) 'goal_node_id': goalNodeId,
      if (rowid != null) 'rowid': rowid,
    });
  }

  RecordsCompanion copyWith({
    Value<String>? id,
    Value<String>? type,
    Value<String>? source,
    Value<String?>? content,
    Value<String?>? attachmentStorageKey,
    Value<String?>? attachmentFileName,
    Value<String?>? attachmentMimeType,
    Value<int?>? capturedAt,
    Value<int>? occurredAt,
    Value<int>? createdAt,
    Value<String?>? goalId,
    Value<String?>? goalNodeId,
    Value<int>? rowid,
  }) {
    return RecordsCompanion(
      id: id ?? this.id,
      type: type ?? this.type,
      source: source ?? this.source,
      content: content ?? this.content,
      attachmentStorageKey: attachmentStorageKey ?? this.attachmentStorageKey,
      attachmentFileName: attachmentFileName ?? this.attachmentFileName,
      attachmentMimeType: attachmentMimeType ?? this.attachmentMimeType,
      capturedAt: capturedAt ?? this.capturedAt,
      occurredAt: occurredAt ?? this.occurredAt,
      createdAt: createdAt ?? this.createdAt,
      goalId: goalId ?? this.goalId,
      goalNodeId: goalNodeId ?? this.goalNodeId,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (type.present) {
      map['type'] = Variable<String>(type.value);
    }
    if (source.present) {
      map['source'] = Variable<String>(source.value);
    }
    if (content.present) {
      map['content'] = Variable<String>(content.value);
    }
    if (attachmentStorageKey.present) {
      map['attachment_storage_key'] = Variable<String>(
        attachmentStorageKey.value,
      );
    }
    if (attachmentFileName.present) {
      map['attachment_file_name'] = Variable<String>(attachmentFileName.value);
    }
    if (attachmentMimeType.present) {
      map['attachment_mime_type'] = Variable<String>(attachmentMimeType.value);
    }
    if (capturedAt.present) {
      map['captured_at'] = Variable<int>(capturedAt.value);
    }
    if (occurredAt.present) {
      map['occurred_at'] = Variable<int>(occurredAt.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    if (goalId.present) {
      map['goal_id'] = Variable<String>(goalId.value);
    }
    if (goalNodeId.present) {
      map['goal_node_id'] = Variable<String>(goalNodeId.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('RecordsCompanion(')
          ..write('id: $id, ')
          ..write('type: $type, ')
          ..write('source: $source, ')
          ..write('content: $content, ')
          ..write('attachmentStorageKey: $attachmentStorageKey, ')
          ..write('attachmentFileName: $attachmentFileName, ')
          ..write('attachmentMimeType: $attachmentMimeType, ')
          ..write('capturedAt: $capturedAt, ')
          ..write('occurredAt: $occurredAt, ')
          ..write('createdAt: $createdAt, ')
          ..write('goalId: $goalId, ')
          ..write('goalNodeId: $goalNodeId, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $UserExecutionReportsTable extends UserExecutionReports
    with TableInfo<$UserExecutionReportsTable, UserExecutionReportRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $UserExecutionReportsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _missionIdMeta = const VerificationMeta(
    'missionId',
  );
  @override
  late final GeneratedColumn<String> missionId = GeneratedColumn<String>(
    'mission_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES missions (id)',
    ),
  );
  static const VerificationMeta _occurrenceDateMeta = const VerificationMeta(
    'occurrenceDate',
  );
  @override
  late final GeneratedColumn<String> occurrenceDate = GeneratedColumn<String>(
    'occurrence_date',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _timeZoneIdMeta = const VerificationMeta(
    'timeZoneId',
  );
  @override
  late final GeneratedColumn<String> timeZoneId = GeneratedColumn<String>(
    'time_zone_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _actualStartMeta = const VerificationMeta(
    'actualStart',
  );
  @override
  late final GeneratedColumn<int> actualStart = GeneratedColumn<int>(
    'actual_start',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _actualEndMeta = const VerificationMeta(
    'actualEnd',
  );
  @override
  late final GeneratedColumn<int> actualEnd = GeneratedColumn<int>(
    'actual_end',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _reportedAtMeta = const VerificationMeta(
    'reportedAt',
  );
  @override
  late final GeneratedColumn<int> reportedAt = GeneratedColumn<int>(
    'reported_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _basisMeta = const VerificationMeta('basis');
  @override
  late final GeneratedColumn<String> basis = GeneratedColumn<String>(
    'basis',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _supersedesIdMeta = const VerificationMeta(
    'supersedesId',
  );
  @override
  late final GeneratedColumn<String> supersedesId = GeneratedColumn<String>(
    'supersedes_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'UNIQUE REFERENCES user_execution_reports (id)',
    ),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    missionId,
    occurrenceDate,
    timeZoneId,
    actualStart,
    actualEnd,
    reportedAt,
    basis,
    supersedesId,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'user_execution_reports';
  @override
  VerificationContext validateIntegrity(
    Insertable<UserExecutionReportRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('mission_id')) {
      context.handle(
        _missionIdMeta,
        missionId.isAcceptableOrUnknown(data['mission_id']!, _missionIdMeta),
      );
    } else if (isInserting) {
      context.missing(_missionIdMeta);
    }
    if (data.containsKey('occurrence_date')) {
      context.handle(
        _occurrenceDateMeta,
        occurrenceDate.isAcceptableOrUnknown(
          data['occurrence_date']!,
          _occurrenceDateMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_occurrenceDateMeta);
    }
    if (data.containsKey('time_zone_id')) {
      context.handle(
        _timeZoneIdMeta,
        timeZoneId.isAcceptableOrUnknown(
          data['time_zone_id']!,
          _timeZoneIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_timeZoneIdMeta);
    }
    if (data.containsKey('actual_start')) {
      context.handle(
        _actualStartMeta,
        actualStart.isAcceptableOrUnknown(
          data['actual_start']!,
          _actualStartMeta,
        ),
      );
    }
    if (data.containsKey('actual_end')) {
      context.handle(
        _actualEndMeta,
        actualEnd.isAcceptableOrUnknown(data['actual_end']!, _actualEndMeta),
      );
    }
    if (data.containsKey('reported_at')) {
      context.handle(
        _reportedAtMeta,
        reportedAt.isAcceptableOrUnknown(data['reported_at']!, _reportedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_reportedAtMeta);
    }
    if (data.containsKey('basis')) {
      context.handle(
        _basisMeta,
        basis.isAcceptableOrUnknown(data['basis']!, _basisMeta),
      );
    } else if (isInserting) {
      context.missing(_basisMeta);
    }
    if (data.containsKey('supersedes_id')) {
      context.handle(
        _supersedesIdMeta,
        supersedesId.isAcceptableOrUnknown(
          data['supersedes_id']!,
          _supersedesIdMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  UserExecutionReportRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return UserExecutionReportRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      missionId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}mission_id'],
      )!,
      occurrenceDate: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}occurrence_date'],
      )!,
      timeZoneId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}time_zone_id'],
      )!,
      actualStart: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}actual_start'],
      ),
      actualEnd: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}actual_end'],
      ),
      reportedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}reported_at'],
      )!,
      basis: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}basis'],
      )!,
      supersedesId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}supersedes_id'],
      ),
    );
  }

  @override
  $UserExecutionReportsTable createAlias(String alias) {
    return $UserExecutionReportsTable(attachedDatabase, alias);
  }
}

class UserExecutionReportRow extends DataClass
    implements Insertable<UserExecutionReportRow> {
  final String id;
  final String missionId;
  final String occurrenceDate;
  final String timeZoneId;
  final int? actualStart;
  final int? actualEnd;
  final int reportedAt;
  final String basis;
  final String? supersedesId;
  const UserExecutionReportRow({
    required this.id,
    required this.missionId,
    required this.occurrenceDate,
    required this.timeZoneId,
    this.actualStart,
    this.actualEnd,
    required this.reportedAt,
    required this.basis,
    this.supersedesId,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['mission_id'] = Variable<String>(missionId);
    map['occurrence_date'] = Variable<String>(occurrenceDate);
    map['time_zone_id'] = Variable<String>(timeZoneId);
    if (!nullToAbsent || actualStart != null) {
      map['actual_start'] = Variable<int>(actualStart);
    }
    if (!nullToAbsent || actualEnd != null) {
      map['actual_end'] = Variable<int>(actualEnd);
    }
    map['reported_at'] = Variable<int>(reportedAt);
    map['basis'] = Variable<String>(basis);
    if (!nullToAbsent || supersedesId != null) {
      map['supersedes_id'] = Variable<String>(supersedesId);
    }
    return map;
  }

  UserExecutionReportsCompanion toCompanion(bool nullToAbsent) {
    return UserExecutionReportsCompanion(
      id: Value(id),
      missionId: Value(missionId),
      occurrenceDate: Value(occurrenceDate),
      timeZoneId: Value(timeZoneId),
      actualStart: actualStart == null && nullToAbsent
          ? const Value.absent()
          : Value(actualStart),
      actualEnd: actualEnd == null && nullToAbsent
          ? const Value.absent()
          : Value(actualEnd),
      reportedAt: Value(reportedAt),
      basis: Value(basis),
      supersedesId: supersedesId == null && nullToAbsent
          ? const Value.absent()
          : Value(supersedesId),
    );
  }

  factory UserExecutionReportRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return UserExecutionReportRow(
      id: serializer.fromJson<String>(json['id']),
      missionId: serializer.fromJson<String>(json['missionId']),
      occurrenceDate: serializer.fromJson<String>(json['occurrenceDate']),
      timeZoneId: serializer.fromJson<String>(json['timeZoneId']),
      actualStart: serializer.fromJson<int?>(json['actualStart']),
      actualEnd: serializer.fromJson<int?>(json['actualEnd']),
      reportedAt: serializer.fromJson<int>(json['reportedAt']),
      basis: serializer.fromJson<String>(json['basis']),
      supersedesId: serializer.fromJson<String?>(json['supersedesId']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'missionId': serializer.toJson<String>(missionId),
      'occurrenceDate': serializer.toJson<String>(occurrenceDate),
      'timeZoneId': serializer.toJson<String>(timeZoneId),
      'actualStart': serializer.toJson<int?>(actualStart),
      'actualEnd': serializer.toJson<int?>(actualEnd),
      'reportedAt': serializer.toJson<int>(reportedAt),
      'basis': serializer.toJson<String>(basis),
      'supersedesId': serializer.toJson<String?>(supersedesId),
    };
  }

  UserExecutionReportRow copyWith({
    String? id,
    String? missionId,
    String? occurrenceDate,
    String? timeZoneId,
    Value<int?> actualStart = const Value.absent(),
    Value<int?> actualEnd = const Value.absent(),
    int? reportedAt,
    String? basis,
    Value<String?> supersedesId = const Value.absent(),
  }) => UserExecutionReportRow(
    id: id ?? this.id,
    missionId: missionId ?? this.missionId,
    occurrenceDate: occurrenceDate ?? this.occurrenceDate,
    timeZoneId: timeZoneId ?? this.timeZoneId,
    actualStart: actualStart.present ? actualStart.value : this.actualStart,
    actualEnd: actualEnd.present ? actualEnd.value : this.actualEnd,
    reportedAt: reportedAt ?? this.reportedAt,
    basis: basis ?? this.basis,
    supersedesId: supersedesId.present ? supersedesId.value : this.supersedesId,
  );
  UserExecutionReportRow copyWithCompanion(UserExecutionReportsCompanion data) {
    return UserExecutionReportRow(
      id: data.id.present ? data.id.value : this.id,
      missionId: data.missionId.present ? data.missionId.value : this.missionId,
      occurrenceDate: data.occurrenceDate.present
          ? data.occurrenceDate.value
          : this.occurrenceDate,
      timeZoneId: data.timeZoneId.present
          ? data.timeZoneId.value
          : this.timeZoneId,
      actualStart: data.actualStart.present
          ? data.actualStart.value
          : this.actualStart,
      actualEnd: data.actualEnd.present ? data.actualEnd.value : this.actualEnd,
      reportedAt: data.reportedAt.present
          ? data.reportedAt.value
          : this.reportedAt,
      basis: data.basis.present ? data.basis.value : this.basis,
      supersedesId: data.supersedesId.present
          ? data.supersedesId.value
          : this.supersedesId,
    );
  }

  @override
  String toString() {
    return (StringBuffer('UserExecutionReportRow(')
          ..write('id: $id, ')
          ..write('missionId: $missionId, ')
          ..write('occurrenceDate: $occurrenceDate, ')
          ..write('timeZoneId: $timeZoneId, ')
          ..write('actualStart: $actualStart, ')
          ..write('actualEnd: $actualEnd, ')
          ..write('reportedAt: $reportedAt, ')
          ..write('basis: $basis, ')
          ..write('supersedesId: $supersedesId')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    missionId,
    occurrenceDate,
    timeZoneId,
    actualStart,
    actualEnd,
    reportedAt,
    basis,
    supersedesId,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is UserExecutionReportRow &&
          other.id == this.id &&
          other.missionId == this.missionId &&
          other.occurrenceDate == this.occurrenceDate &&
          other.timeZoneId == this.timeZoneId &&
          other.actualStart == this.actualStart &&
          other.actualEnd == this.actualEnd &&
          other.reportedAt == this.reportedAt &&
          other.basis == this.basis &&
          other.supersedesId == this.supersedesId);
}

class UserExecutionReportsCompanion
    extends UpdateCompanion<UserExecutionReportRow> {
  final Value<String> id;
  final Value<String> missionId;
  final Value<String> occurrenceDate;
  final Value<String> timeZoneId;
  final Value<int?> actualStart;
  final Value<int?> actualEnd;
  final Value<int> reportedAt;
  final Value<String> basis;
  final Value<String?> supersedesId;
  final Value<int> rowid;
  const UserExecutionReportsCompanion({
    this.id = const Value.absent(),
    this.missionId = const Value.absent(),
    this.occurrenceDate = const Value.absent(),
    this.timeZoneId = const Value.absent(),
    this.actualStart = const Value.absent(),
    this.actualEnd = const Value.absent(),
    this.reportedAt = const Value.absent(),
    this.basis = const Value.absent(),
    this.supersedesId = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  UserExecutionReportsCompanion.insert({
    required String id,
    required String missionId,
    required String occurrenceDate,
    required String timeZoneId,
    this.actualStart = const Value.absent(),
    this.actualEnd = const Value.absent(),
    required int reportedAt,
    required String basis,
    this.supersedesId = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       missionId = Value(missionId),
       occurrenceDate = Value(occurrenceDate),
       timeZoneId = Value(timeZoneId),
       reportedAt = Value(reportedAt),
       basis = Value(basis);
  static Insertable<UserExecutionReportRow> custom({
    Expression<String>? id,
    Expression<String>? missionId,
    Expression<String>? occurrenceDate,
    Expression<String>? timeZoneId,
    Expression<int>? actualStart,
    Expression<int>? actualEnd,
    Expression<int>? reportedAt,
    Expression<String>? basis,
    Expression<String>? supersedesId,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (missionId != null) 'mission_id': missionId,
      if (occurrenceDate != null) 'occurrence_date': occurrenceDate,
      if (timeZoneId != null) 'time_zone_id': timeZoneId,
      if (actualStart != null) 'actual_start': actualStart,
      if (actualEnd != null) 'actual_end': actualEnd,
      if (reportedAt != null) 'reported_at': reportedAt,
      if (basis != null) 'basis': basis,
      if (supersedesId != null) 'supersedes_id': supersedesId,
      if (rowid != null) 'rowid': rowid,
    });
  }

  UserExecutionReportsCompanion copyWith({
    Value<String>? id,
    Value<String>? missionId,
    Value<String>? occurrenceDate,
    Value<String>? timeZoneId,
    Value<int?>? actualStart,
    Value<int?>? actualEnd,
    Value<int>? reportedAt,
    Value<String>? basis,
    Value<String?>? supersedesId,
    Value<int>? rowid,
  }) {
    return UserExecutionReportsCompanion(
      id: id ?? this.id,
      missionId: missionId ?? this.missionId,
      occurrenceDate: occurrenceDate ?? this.occurrenceDate,
      timeZoneId: timeZoneId ?? this.timeZoneId,
      actualStart: actualStart ?? this.actualStart,
      actualEnd: actualEnd ?? this.actualEnd,
      reportedAt: reportedAt ?? this.reportedAt,
      basis: basis ?? this.basis,
      supersedesId: supersedesId ?? this.supersedesId,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (missionId.present) {
      map['mission_id'] = Variable<String>(missionId.value);
    }
    if (occurrenceDate.present) {
      map['occurrence_date'] = Variable<String>(occurrenceDate.value);
    }
    if (timeZoneId.present) {
      map['time_zone_id'] = Variable<String>(timeZoneId.value);
    }
    if (actualStart.present) {
      map['actual_start'] = Variable<int>(actualStart.value);
    }
    if (actualEnd.present) {
      map['actual_end'] = Variable<int>(actualEnd.value);
    }
    if (reportedAt.present) {
      map['reported_at'] = Variable<int>(reportedAt.value);
    }
    if (basis.present) {
      map['basis'] = Variable<String>(basis.value);
    }
    if (supersedesId.present) {
      map['supersedes_id'] = Variable<String>(supersedesId.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('UserExecutionReportsCompanion(')
          ..write('id: $id, ')
          ..write('missionId: $missionId, ')
          ..write('occurrenceDate: $occurrenceDate, ')
          ..write('timeZoneId: $timeZoneId, ')
          ..write('actualStart: $actualStart, ')
          ..write('actualEnd: $actualEnd, ')
          ..write('reportedAt: $reportedAt, ')
          ..write('basis: $basis, ')
          ..write('supersedesId: $supersedesId, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $AnalysisJobsTable extends AnalysisJobs
    with TableInfo<$AnalysisJobsTable, AnalysisJobRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AnalysisJobsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _scopeMeta = const VerificationMeta('scope');
  @override
  late final GeneratedColumn<String> scope = GeneratedColumn<String>(
    'scope',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _targetIdMeta = const VerificationMeta(
    'targetId',
  );
  @override
  late final GeneratedColumn<String> targetId = GeneratedColumn<String>(
    'target_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sourceVersionMeta = const VerificationMeta(
    'sourceVersion',
  );
  @override
  late final GeneratedColumn<int> sourceVersion = GeneratedColumn<int>(
    'source_version',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('pending'),
  );
  static const VerificationMeta _attemptsMeta = const VerificationMeta(
    'attempts',
  );
  @override
  late final GeneratedColumn<int> attempts = GeneratedColumn<int>(
    'attempts',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _availableAtMeta = const VerificationMeta(
    'availableAt',
  );
  @override
  late final GeneratedColumn<int> availableAt = GeneratedColumn<int>(
    'available_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _errorMeta = const VerificationMeta('error');
  @override
  late final GeneratedColumn<String> error = GeneratedColumn<String>(
    'error',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _closingMeta = const VerificationMeta(
    'closing',
  );
  @override
  late final GeneratedColumn<bool> closing = GeneratedColumn<bool>(
    'closing',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("closing" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  @override
  List<GeneratedColumn> get $columns => [
    scope,
    targetId,
    sourceVersion,
    status,
    attempts,
    availableAt,
    error,
    closing,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'analysis_jobs';
  @override
  VerificationContext validateIntegrity(
    Insertable<AnalysisJobRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('scope')) {
      context.handle(
        _scopeMeta,
        scope.isAcceptableOrUnknown(data['scope']!, _scopeMeta),
      );
    } else if (isInserting) {
      context.missing(_scopeMeta);
    }
    if (data.containsKey('target_id')) {
      context.handle(
        _targetIdMeta,
        targetId.isAcceptableOrUnknown(data['target_id']!, _targetIdMeta),
      );
    } else if (isInserting) {
      context.missing(_targetIdMeta);
    }
    if (data.containsKey('source_version')) {
      context.handle(
        _sourceVersionMeta,
        sourceVersion.isAcceptableOrUnknown(
          data['source_version']!,
          _sourceVersionMeta,
        ),
      );
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    }
    if (data.containsKey('attempts')) {
      context.handle(
        _attemptsMeta,
        attempts.isAcceptableOrUnknown(data['attempts']!, _attemptsMeta),
      );
    }
    if (data.containsKey('available_at')) {
      context.handle(
        _availableAtMeta,
        availableAt.isAcceptableOrUnknown(
          data['available_at']!,
          _availableAtMeta,
        ),
      );
    }
    if (data.containsKey('error')) {
      context.handle(
        _errorMeta,
        error.isAcceptableOrUnknown(data['error']!, _errorMeta),
      );
    }
    if (data.containsKey('closing')) {
      context.handle(
        _closingMeta,
        closing.isAcceptableOrUnknown(data['closing']!, _closingMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {scope, targetId};
  @override
  AnalysisJobRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AnalysisJobRow(
      scope: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}scope'],
      )!,
      targetId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}target_id'],
      )!,
      sourceVersion: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}source_version'],
      )!,
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      attempts: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}attempts'],
      )!,
      availableAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}available_at'],
      )!,
      error: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}error'],
      ),
      closing: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}closing'],
      )!,
    );
  }

  @override
  $AnalysisJobsTable createAlias(String alias) {
    return $AnalysisJobsTable(attachedDatabase, alias);
  }
}

class AnalysisJobRow extends DataClass implements Insertable<AnalysisJobRow> {
  final String scope;
  final String targetId;
  final int sourceVersion;
  final String status;
  final int attempts;
  final int availableAt;
  final String? error;
  final bool closing;
  const AnalysisJobRow({
    required this.scope,
    required this.targetId,
    required this.sourceVersion,
    required this.status,
    required this.attempts,
    required this.availableAt,
    this.error,
    required this.closing,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['scope'] = Variable<String>(scope);
    map['target_id'] = Variable<String>(targetId);
    map['source_version'] = Variable<int>(sourceVersion);
    map['status'] = Variable<String>(status);
    map['attempts'] = Variable<int>(attempts);
    map['available_at'] = Variable<int>(availableAt);
    if (!nullToAbsent || error != null) {
      map['error'] = Variable<String>(error);
    }
    map['closing'] = Variable<bool>(closing);
    return map;
  }

  AnalysisJobsCompanion toCompanion(bool nullToAbsent) {
    return AnalysisJobsCompanion(
      scope: Value(scope),
      targetId: Value(targetId),
      sourceVersion: Value(sourceVersion),
      status: Value(status),
      attempts: Value(attempts),
      availableAt: Value(availableAt),
      error: error == null && nullToAbsent
          ? const Value.absent()
          : Value(error),
      closing: Value(closing),
    );
  }

  factory AnalysisJobRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AnalysisJobRow(
      scope: serializer.fromJson<String>(json['scope']),
      targetId: serializer.fromJson<String>(json['targetId']),
      sourceVersion: serializer.fromJson<int>(json['sourceVersion']),
      status: serializer.fromJson<String>(json['status']),
      attempts: serializer.fromJson<int>(json['attempts']),
      availableAt: serializer.fromJson<int>(json['availableAt']),
      error: serializer.fromJson<String?>(json['error']),
      closing: serializer.fromJson<bool>(json['closing']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'scope': serializer.toJson<String>(scope),
      'targetId': serializer.toJson<String>(targetId),
      'sourceVersion': serializer.toJson<int>(sourceVersion),
      'status': serializer.toJson<String>(status),
      'attempts': serializer.toJson<int>(attempts),
      'availableAt': serializer.toJson<int>(availableAt),
      'error': serializer.toJson<String?>(error),
      'closing': serializer.toJson<bool>(closing),
    };
  }

  AnalysisJobRow copyWith({
    String? scope,
    String? targetId,
    int? sourceVersion,
    String? status,
    int? attempts,
    int? availableAt,
    Value<String?> error = const Value.absent(),
    bool? closing,
  }) => AnalysisJobRow(
    scope: scope ?? this.scope,
    targetId: targetId ?? this.targetId,
    sourceVersion: sourceVersion ?? this.sourceVersion,
    status: status ?? this.status,
    attempts: attempts ?? this.attempts,
    availableAt: availableAt ?? this.availableAt,
    error: error.present ? error.value : this.error,
    closing: closing ?? this.closing,
  );
  AnalysisJobRow copyWithCompanion(AnalysisJobsCompanion data) {
    return AnalysisJobRow(
      scope: data.scope.present ? data.scope.value : this.scope,
      targetId: data.targetId.present ? data.targetId.value : this.targetId,
      sourceVersion: data.sourceVersion.present
          ? data.sourceVersion.value
          : this.sourceVersion,
      status: data.status.present ? data.status.value : this.status,
      attempts: data.attempts.present ? data.attempts.value : this.attempts,
      availableAt: data.availableAt.present
          ? data.availableAt.value
          : this.availableAt,
      error: data.error.present ? data.error.value : this.error,
      closing: data.closing.present ? data.closing.value : this.closing,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AnalysisJobRow(')
          ..write('scope: $scope, ')
          ..write('targetId: $targetId, ')
          ..write('sourceVersion: $sourceVersion, ')
          ..write('status: $status, ')
          ..write('attempts: $attempts, ')
          ..write('availableAt: $availableAt, ')
          ..write('error: $error, ')
          ..write('closing: $closing')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    scope,
    targetId,
    sourceVersion,
    status,
    attempts,
    availableAt,
    error,
    closing,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AnalysisJobRow &&
          other.scope == this.scope &&
          other.targetId == this.targetId &&
          other.sourceVersion == this.sourceVersion &&
          other.status == this.status &&
          other.attempts == this.attempts &&
          other.availableAt == this.availableAt &&
          other.error == this.error &&
          other.closing == this.closing);
}

class AnalysisJobsCompanion extends UpdateCompanion<AnalysisJobRow> {
  final Value<String> scope;
  final Value<String> targetId;
  final Value<int> sourceVersion;
  final Value<String> status;
  final Value<int> attempts;
  final Value<int> availableAt;
  final Value<String?> error;
  final Value<bool> closing;
  final Value<int> rowid;
  const AnalysisJobsCompanion({
    this.scope = const Value.absent(),
    this.targetId = const Value.absent(),
    this.sourceVersion = const Value.absent(),
    this.status = const Value.absent(),
    this.attempts = const Value.absent(),
    this.availableAt = const Value.absent(),
    this.error = const Value.absent(),
    this.closing = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  AnalysisJobsCompanion.insert({
    required String scope,
    required String targetId,
    this.sourceVersion = const Value.absent(),
    this.status = const Value.absent(),
    this.attempts = const Value.absent(),
    this.availableAt = const Value.absent(),
    this.error = const Value.absent(),
    this.closing = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : scope = Value(scope),
       targetId = Value(targetId);
  static Insertable<AnalysisJobRow> custom({
    Expression<String>? scope,
    Expression<String>? targetId,
    Expression<int>? sourceVersion,
    Expression<String>? status,
    Expression<int>? attempts,
    Expression<int>? availableAt,
    Expression<String>? error,
    Expression<bool>? closing,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (scope != null) 'scope': scope,
      if (targetId != null) 'target_id': targetId,
      if (sourceVersion != null) 'source_version': sourceVersion,
      if (status != null) 'status': status,
      if (attempts != null) 'attempts': attempts,
      if (availableAt != null) 'available_at': availableAt,
      if (error != null) 'error': error,
      if (closing != null) 'closing': closing,
      if (rowid != null) 'rowid': rowid,
    });
  }

  AnalysisJobsCompanion copyWith({
    Value<String>? scope,
    Value<String>? targetId,
    Value<int>? sourceVersion,
    Value<String>? status,
    Value<int>? attempts,
    Value<int>? availableAt,
    Value<String?>? error,
    Value<bool>? closing,
    Value<int>? rowid,
  }) {
    return AnalysisJobsCompanion(
      scope: scope ?? this.scope,
      targetId: targetId ?? this.targetId,
      sourceVersion: sourceVersion ?? this.sourceVersion,
      status: status ?? this.status,
      attempts: attempts ?? this.attempts,
      availableAt: availableAt ?? this.availableAt,
      error: error ?? this.error,
      closing: closing ?? this.closing,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (scope.present) {
      map['scope'] = Variable<String>(scope.value);
    }
    if (targetId.present) {
      map['target_id'] = Variable<String>(targetId.value);
    }
    if (sourceVersion.present) {
      map['source_version'] = Variable<int>(sourceVersion.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (attempts.present) {
      map['attempts'] = Variable<int>(attempts.value);
    }
    if (availableAt.present) {
      map['available_at'] = Variable<int>(availableAt.value);
    }
    if (error.present) {
      map['error'] = Variable<String>(error.value);
    }
    if (closing.present) {
      map['closing'] = Variable<bool>(closing.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AnalysisJobsCompanion(')
          ..write('scope: $scope, ')
          ..write('targetId: $targetId, ')
          ..write('sourceVersion: $sourceVersion, ')
          ..write('status: $status, ')
          ..write('attempts: $attempts, ')
          ..write('availableAt: $availableAt, ')
          ..write('error: $error, ')
          ..write('closing: $closing, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $AnalysisVersionsTable extends AnalysisVersions
    with TableInfo<$AnalysisVersionsTable, AnalysisVersionRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AnalysisVersionsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _scopeMeta = const VerificationMeta('scope');
  @override
  late final GeneratedColumn<String> scope = GeneratedColumn<String>(
    'scope',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _targetIdMeta = const VerificationMeta(
    'targetId',
  );
  @override
  late final GeneratedColumn<String> targetId = GeneratedColumn<String>(
    'target_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sourceVersionMeta = const VerificationMeta(
    'sourceVersion',
  );
  @override
  late final GeneratedColumn<int> sourceVersion = GeneratedColumn<int>(
    'source_version',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _contentMeta = const VerificationMeta(
    'content',
  );
  @override
  late final GeneratedColumn<String> content = GeneratedColumn<String>(
    'content',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sourcesJsonMeta = const VerificationMeta(
    'sourcesJson',
  );
  @override
  late final GeneratedColumn<String> sourcesJson = GeneratedColumn<String>(
    'sources_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _coverageMeta = const VerificationMeta(
    'coverage',
  );
  @override
  late final GeneratedColumn<int> coverage = GeneratedColumn<int>(
    'coverage',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _closingMeta = const VerificationMeta(
    'closing',
  );
  @override
  late final GeneratedColumn<bool> closing = GeneratedColumn<bool>(
    'closing',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("closing" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    scope,
    targetId,
    sourceVersion,
    content,
    sourcesJson,
    coverage,
    createdAt,
    closing,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'analysis_versions';
  @override
  VerificationContext validateIntegrity(
    Insertable<AnalysisVersionRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('scope')) {
      context.handle(
        _scopeMeta,
        scope.isAcceptableOrUnknown(data['scope']!, _scopeMeta),
      );
    } else if (isInserting) {
      context.missing(_scopeMeta);
    }
    if (data.containsKey('target_id')) {
      context.handle(
        _targetIdMeta,
        targetId.isAcceptableOrUnknown(data['target_id']!, _targetIdMeta),
      );
    } else if (isInserting) {
      context.missing(_targetIdMeta);
    }
    if (data.containsKey('source_version')) {
      context.handle(
        _sourceVersionMeta,
        sourceVersion.isAcceptableOrUnknown(
          data['source_version']!,
          _sourceVersionMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_sourceVersionMeta);
    }
    if (data.containsKey('content')) {
      context.handle(
        _contentMeta,
        content.isAcceptableOrUnknown(data['content']!, _contentMeta),
      );
    } else if (isInserting) {
      context.missing(_contentMeta);
    }
    if (data.containsKey('sources_json')) {
      context.handle(
        _sourcesJsonMeta,
        sourcesJson.isAcceptableOrUnknown(
          data['sources_json']!,
          _sourcesJsonMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_sourcesJsonMeta);
    }
    if (data.containsKey('coverage')) {
      context.handle(
        _coverageMeta,
        coverage.isAcceptableOrUnknown(data['coverage']!, _coverageMeta),
      );
    } else if (isInserting) {
      context.missing(_coverageMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('closing')) {
      context.handle(
        _closingMeta,
        closing.isAcceptableOrUnknown(data['closing']!, _closingMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  AnalysisVersionRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AnalysisVersionRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      scope: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}scope'],
      )!,
      targetId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}target_id'],
      )!,
      sourceVersion: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}source_version'],
      )!,
      content: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}content'],
      )!,
      sourcesJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sources_json'],
      )!,
      coverage: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}coverage'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at'],
      )!,
      closing: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}closing'],
      )!,
    );
  }

  @override
  $AnalysisVersionsTable createAlias(String alias) {
    return $AnalysisVersionsTable(attachedDatabase, alias);
  }
}

class AnalysisVersionRow extends DataClass
    implements Insertable<AnalysisVersionRow> {
  final String id;
  final String scope;
  final String targetId;
  final int sourceVersion;
  final String content;
  final String sourcesJson;
  final int coverage;
  final int createdAt;
  final bool closing;
  const AnalysisVersionRow({
    required this.id,
    required this.scope,
    required this.targetId,
    required this.sourceVersion,
    required this.content,
    required this.sourcesJson,
    required this.coverage,
    required this.createdAt,
    required this.closing,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['scope'] = Variable<String>(scope);
    map['target_id'] = Variable<String>(targetId);
    map['source_version'] = Variable<int>(sourceVersion);
    map['content'] = Variable<String>(content);
    map['sources_json'] = Variable<String>(sourcesJson);
    map['coverage'] = Variable<int>(coverage);
    map['created_at'] = Variable<int>(createdAt);
    map['closing'] = Variable<bool>(closing);
    return map;
  }

  AnalysisVersionsCompanion toCompanion(bool nullToAbsent) {
    return AnalysisVersionsCompanion(
      id: Value(id),
      scope: Value(scope),
      targetId: Value(targetId),
      sourceVersion: Value(sourceVersion),
      content: Value(content),
      sourcesJson: Value(sourcesJson),
      coverage: Value(coverage),
      createdAt: Value(createdAt),
      closing: Value(closing),
    );
  }

  factory AnalysisVersionRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AnalysisVersionRow(
      id: serializer.fromJson<String>(json['id']),
      scope: serializer.fromJson<String>(json['scope']),
      targetId: serializer.fromJson<String>(json['targetId']),
      sourceVersion: serializer.fromJson<int>(json['sourceVersion']),
      content: serializer.fromJson<String>(json['content']),
      sourcesJson: serializer.fromJson<String>(json['sourcesJson']),
      coverage: serializer.fromJson<int>(json['coverage']),
      createdAt: serializer.fromJson<int>(json['createdAt']),
      closing: serializer.fromJson<bool>(json['closing']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'scope': serializer.toJson<String>(scope),
      'targetId': serializer.toJson<String>(targetId),
      'sourceVersion': serializer.toJson<int>(sourceVersion),
      'content': serializer.toJson<String>(content),
      'sourcesJson': serializer.toJson<String>(sourcesJson),
      'coverage': serializer.toJson<int>(coverage),
      'createdAt': serializer.toJson<int>(createdAt),
      'closing': serializer.toJson<bool>(closing),
    };
  }

  AnalysisVersionRow copyWith({
    String? id,
    String? scope,
    String? targetId,
    int? sourceVersion,
    String? content,
    String? sourcesJson,
    int? coverage,
    int? createdAt,
    bool? closing,
  }) => AnalysisVersionRow(
    id: id ?? this.id,
    scope: scope ?? this.scope,
    targetId: targetId ?? this.targetId,
    sourceVersion: sourceVersion ?? this.sourceVersion,
    content: content ?? this.content,
    sourcesJson: sourcesJson ?? this.sourcesJson,
    coverage: coverage ?? this.coverage,
    createdAt: createdAt ?? this.createdAt,
    closing: closing ?? this.closing,
  );
  AnalysisVersionRow copyWithCompanion(AnalysisVersionsCompanion data) {
    return AnalysisVersionRow(
      id: data.id.present ? data.id.value : this.id,
      scope: data.scope.present ? data.scope.value : this.scope,
      targetId: data.targetId.present ? data.targetId.value : this.targetId,
      sourceVersion: data.sourceVersion.present
          ? data.sourceVersion.value
          : this.sourceVersion,
      content: data.content.present ? data.content.value : this.content,
      sourcesJson: data.sourcesJson.present
          ? data.sourcesJson.value
          : this.sourcesJson,
      coverage: data.coverage.present ? data.coverage.value : this.coverage,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      closing: data.closing.present ? data.closing.value : this.closing,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AnalysisVersionRow(')
          ..write('id: $id, ')
          ..write('scope: $scope, ')
          ..write('targetId: $targetId, ')
          ..write('sourceVersion: $sourceVersion, ')
          ..write('content: $content, ')
          ..write('sourcesJson: $sourcesJson, ')
          ..write('coverage: $coverage, ')
          ..write('createdAt: $createdAt, ')
          ..write('closing: $closing')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    scope,
    targetId,
    sourceVersion,
    content,
    sourcesJson,
    coverage,
    createdAt,
    closing,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AnalysisVersionRow &&
          other.id == this.id &&
          other.scope == this.scope &&
          other.targetId == this.targetId &&
          other.sourceVersion == this.sourceVersion &&
          other.content == this.content &&
          other.sourcesJson == this.sourcesJson &&
          other.coverage == this.coverage &&
          other.createdAt == this.createdAt &&
          other.closing == this.closing);
}

class AnalysisVersionsCompanion extends UpdateCompanion<AnalysisVersionRow> {
  final Value<String> id;
  final Value<String> scope;
  final Value<String> targetId;
  final Value<int> sourceVersion;
  final Value<String> content;
  final Value<String> sourcesJson;
  final Value<int> coverage;
  final Value<int> createdAt;
  final Value<bool> closing;
  final Value<int> rowid;
  const AnalysisVersionsCompanion({
    this.id = const Value.absent(),
    this.scope = const Value.absent(),
    this.targetId = const Value.absent(),
    this.sourceVersion = const Value.absent(),
    this.content = const Value.absent(),
    this.sourcesJson = const Value.absent(),
    this.coverage = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.closing = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  AnalysisVersionsCompanion.insert({
    required String id,
    required String scope,
    required String targetId,
    required int sourceVersion,
    required String content,
    required String sourcesJson,
    required int coverage,
    required int createdAt,
    this.closing = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       scope = Value(scope),
       targetId = Value(targetId),
       sourceVersion = Value(sourceVersion),
       content = Value(content),
       sourcesJson = Value(sourcesJson),
       coverage = Value(coverage),
       createdAt = Value(createdAt);
  static Insertable<AnalysisVersionRow> custom({
    Expression<String>? id,
    Expression<String>? scope,
    Expression<String>? targetId,
    Expression<int>? sourceVersion,
    Expression<String>? content,
    Expression<String>? sourcesJson,
    Expression<int>? coverage,
    Expression<int>? createdAt,
    Expression<bool>? closing,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (scope != null) 'scope': scope,
      if (targetId != null) 'target_id': targetId,
      if (sourceVersion != null) 'source_version': sourceVersion,
      if (content != null) 'content': content,
      if (sourcesJson != null) 'sources_json': sourcesJson,
      if (coverage != null) 'coverage': coverage,
      if (createdAt != null) 'created_at': createdAt,
      if (closing != null) 'closing': closing,
      if (rowid != null) 'rowid': rowid,
    });
  }

  AnalysisVersionsCompanion copyWith({
    Value<String>? id,
    Value<String>? scope,
    Value<String>? targetId,
    Value<int>? sourceVersion,
    Value<String>? content,
    Value<String>? sourcesJson,
    Value<int>? coverage,
    Value<int>? createdAt,
    Value<bool>? closing,
    Value<int>? rowid,
  }) {
    return AnalysisVersionsCompanion(
      id: id ?? this.id,
      scope: scope ?? this.scope,
      targetId: targetId ?? this.targetId,
      sourceVersion: sourceVersion ?? this.sourceVersion,
      content: content ?? this.content,
      sourcesJson: sourcesJson ?? this.sourcesJson,
      coverage: coverage ?? this.coverage,
      createdAt: createdAt ?? this.createdAt,
      closing: closing ?? this.closing,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (scope.present) {
      map['scope'] = Variable<String>(scope.value);
    }
    if (targetId.present) {
      map['target_id'] = Variable<String>(targetId.value);
    }
    if (sourceVersion.present) {
      map['source_version'] = Variable<int>(sourceVersion.value);
    }
    if (content.present) {
      map['content'] = Variable<String>(content.value);
    }
    if (sourcesJson.present) {
      map['sources_json'] = Variable<String>(sourcesJson.value);
    }
    if (coverage.present) {
      map['coverage'] = Variable<int>(coverage.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    if (closing.present) {
      map['closing'] = Variable<bool>(closing.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AnalysisVersionsCompanion(')
          ..write('id: $id, ')
          ..write('scope: $scope, ')
          ..write('targetId: $targetId, ')
          ..write('sourceVersion: $sourceVersion, ')
          ..write('content: $content, ')
          ..write('sourcesJson: $sourcesJson, ')
          ..write('coverage: $coverage, ')
          ..write('createdAt: $createdAt, ')
          ..write('closing: $closing, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $MemoryTopicsTable extends MemoryTopics
    with TableInfo<$MemoryTopicsTable, MemoryTopicRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $MemoryTopicsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _canonicalNameMeta = const VerificationMeta(
    'canonicalName',
  );
  @override
  late final GeneratedColumn<String> canonicalName = GeneratedColumn<String>(
    'canonical_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL CHECK (length(trim(canonical_name)) > 0)',
  );
  static const VerificationMeta _kindMeta = const VerificationMeta('kind');
  @override
  late final GeneratedColumn<String> kind = GeneratedColumn<String>(
    'kind',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints:
        'NOT NULL CHECK (kind IN (\'preference\', \'fact\', \'constraint\', \'observation\', \'identity\'))',
  );
  static const VerificationMeta _goalIdMeta = const VerificationMeta('goalId');
  @override
  late final GeneratedColumn<String> goalId = GeneratedColumn<String>(
    'goal_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES goals (id)',
    ),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    canonicalName,
    kind,
    goalId,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'memory_topics';
  @override
  VerificationContext validateIntegrity(
    Insertable<MemoryTopicRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('canonical_name')) {
      context.handle(
        _canonicalNameMeta,
        canonicalName.isAcceptableOrUnknown(
          data['canonical_name']!,
          _canonicalNameMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_canonicalNameMeta);
    }
    if (data.containsKey('kind')) {
      context.handle(
        _kindMeta,
        kind.isAcceptableOrUnknown(data['kind']!, _kindMeta),
      );
    } else if (isInserting) {
      context.missing(_kindMeta);
    }
    if (data.containsKey('goal_id')) {
      context.handle(
        _goalIdMeta,
        goalId.isAcceptableOrUnknown(data['goal_id']!, _goalIdMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  MemoryTopicRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return MemoryTopicRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      canonicalName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}canonical_name'],
      )!,
      kind: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}kind'],
      )!,
      goalId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}goal_id'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $MemoryTopicsTable createAlias(String alias) {
    return $MemoryTopicsTable(attachedDatabase, alias);
  }
}

class MemoryTopicRow extends DataClass implements Insertable<MemoryTopicRow> {
  final String id;
  final String canonicalName;
  final String kind;
  final String? goalId;
  final int createdAt;
  const MemoryTopicRow({
    required this.id,
    required this.canonicalName,
    required this.kind,
    this.goalId,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['canonical_name'] = Variable<String>(canonicalName);
    map['kind'] = Variable<String>(kind);
    if (!nullToAbsent || goalId != null) {
      map['goal_id'] = Variable<String>(goalId);
    }
    map['created_at'] = Variable<int>(createdAt);
    return map;
  }

  MemoryTopicsCompanion toCompanion(bool nullToAbsent) {
    return MemoryTopicsCompanion(
      id: Value(id),
      canonicalName: Value(canonicalName),
      kind: Value(kind),
      goalId: goalId == null && nullToAbsent
          ? const Value.absent()
          : Value(goalId),
      createdAt: Value(createdAt),
    );
  }

  factory MemoryTopicRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return MemoryTopicRow(
      id: serializer.fromJson<String>(json['id']),
      canonicalName: serializer.fromJson<String>(json['canonicalName']),
      kind: serializer.fromJson<String>(json['kind']),
      goalId: serializer.fromJson<String?>(json['goalId']),
      createdAt: serializer.fromJson<int>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'canonicalName': serializer.toJson<String>(canonicalName),
      'kind': serializer.toJson<String>(kind),
      'goalId': serializer.toJson<String?>(goalId),
      'createdAt': serializer.toJson<int>(createdAt),
    };
  }

  MemoryTopicRow copyWith({
    String? id,
    String? canonicalName,
    String? kind,
    Value<String?> goalId = const Value.absent(),
    int? createdAt,
  }) => MemoryTopicRow(
    id: id ?? this.id,
    canonicalName: canonicalName ?? this.canonicalName,
    kind: kind ?? this.kind,
    goalId: goalId.present ? goalId.value : this.goalId,
    createdAt: createdAt ?? this.createdAt,
  );
  MemoryTopicRow copyWithCompanion(MemoryTopicsCompanion data) {
    return MemoryTopicRow(
      id: data.id.present ? data.id.value : this.id,
      canonicalName: data.canonicalName.present
          ? data.canonicalName.value
          : this.canonicalName,
      kind: data.kind.present ? data.kind.value : this.kind,
      goalId: data.goalId.present ? data.goalId.value : this.goalId,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('MemoryTopicRow(')
          ..write('id: $id, ')
          ..write('canonicalName: $canonicalName, ')
          ..write('kind: $kind, ')
          ..write('goalId: $goalId, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, canonicalName, kind, goalId, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is MemoryTopicRow &&
          other.id == this.id &&
          other.canonicalName == this.canonicalName &&
          other.kind == this.kind &&
          other.goalId == this.goalId &&
          other.createdAt == this.createdAt);
}

class MemoryTopicsCompanion extends UpdateCompanion<MemoryTopicRow> {
  final Value<String> id;
  final Value<String> canonicalName;
  final Value<String> kind;
  final Value<String?> goalId;
  final Value<int> createdAt;
  final Value<int> rowid;
  const MemoryTopicsCompanion({
    this.id = const Value.absent(),
    this.canonicalName = const Value.absent(),
    this.kind = const Value.absent(),
    this.goalId = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  MemoryTopicsCompanion.insert({
    required String id,
    required String canonicalName,
    required String kind,
    this.goalId = const Value.absent(),
    required int createdAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       canonicalName = Value(canonicalName),
       kind = Value(kind),
       createdAt = Value(createdAt);
  static Insertable<MemoryTopicRow> custom({
    Expression<String>? id,
    Expression<String>? canonicalName,
    Expression<String>? kind,
    Expression<String>? goalId,
    Expression<int>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (canonicalName != null) 'canonical_name': canonicalName,
      if (kind != null) 'kind': kind,
      if (goalId != null) 'goal_id': goalId,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  MemoryTopicsCompanion copyWith({
    Value<String>? id,
    Value<String>? canonicalName,
    Value<String>? kind,
    Value<String?>? goalId,
    Value<int>? createdAt,
    Value<int>? rowid,
  }) {
    return MemoryTopicsCompanion(
      id: id ?? this.id,
      canonicalName: canonicalName ?? this.canonicalName,
      kind: kind ?? this.kind,
      goalId: goalId ?? this.goalId,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (canonicalName.present) {
      map['canonical_name'] = Variable<String>(canonicalName.value);
    }
    if (kind.present) {
      map['kind'] = Variable<String>(kind.value);
    }
    if (goalId.present) {
      map['goal_id'] = Variable<String>(goalId.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('MemoryTopicsCompanion(')
          ..write('id: $id, ')
          ..write('canonicalName: $canonicalName, ')
          ..write('kind: $kind, ')
          ..write('goalId: $goalId, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $MemoryItemsTable extends MemoryItems
    with TableInfo<$MemoryItemsTable, MemoryItemRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $MemoryItemsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _layerMeta = const VerificationMeta('layer');
  @override
  late final GeneratedColumn<String> layer = GeneratedColumn<String>(
    'layer',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints:
        'NOT NULL CHECK (layer IN (\'identity\', \'semantic\', \'episodic\', \'procedural\', \'observation\'))',
  );
  static const VerificationMeta _topicIdMeta = const VerificationMeta(
    'topicId',
  );
  @override
  late final GeneratedColumn<String> topicId = GeneratedColumn<String>(
    'topic_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES memory_topics (id)',
    ),
  );
  static const VerificationMeta _contentMeta = const VerificationMeta(
    'content',
  );
  @override
  late final GeneratedColumn<String> content = GeneratedColumn<String>(
    'content',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _certaintyMeta = const VerificationMeta(
    'certainty',
  );
  @override
  late final GeneratedColumn<String> certainty = GeneratedColumn<String>(
    'certainty',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints:
        'NOT NULL CHECK (certainty IN (\'stated\', \'inferred\', \'unverified\'))',
  );
  static const VerificationMeta _importanceMeta = const VerificationMeta(
    'importance',
  );
  @override
  late final GeneratedColumn<int> importance = GeneratedColumn<int>(
    'importance',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    $customConstraints:
        'NOT NULL DEFAULT 50 CHECK (importance BETWEEN 1 AND 100)',
    defaultValue: const CustomExpression('50'),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<int> updatedAt = GeneratedColumn<int>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _expiresAtMeta = const VerificationMeta(
    'expiresAt',
  );
  @override
  late final GeneratedColumn<int> expiresAt = GeneratedColumn<int>(
    'expires_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _forgottenMeta = const VerificationMeta(
    'forgotten',
  );
  @override
  late final GeneratedColumn<bool> forgotten = GeneratedColumn<bool>(
    'forgotten',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("forgotten" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _userEditedMeta = const VerificationMeta(
    'userEdited',
  );
  @override
  late final GeneratedColumn<bool> userEdited = GeneratedColumn<bool>(
    'user_edited',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("user_edited" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _sourceKindMeta = const VerificationMeta(
    'sourceKind',
  );
  @override
  late final GeneratedColumn<String> sourceKind = GeneratedColumn<String>(
    'source_kind',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints:
        'NOT NULL CHECK (source_kind IN (\'user\', \'assistant\', \'extraction\', \'manual\', \'reflection\'))',
  );
  static const VerificationMeta _sourceRefMeta = const VerificationMeta(
    'sourceRef',
  );
  @override
  late final GeneratedColumn<String> sourceRef = GeneratedColumn<String>(
    'source_ref',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _goalIdMeta = const VerificationMeta('goalId');
  @override
  late final GeneratedColumn<String> goalId = GeneratedColumn<String>(
    'goal_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES goals (id)',
    ),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    layer,
    topicId,
    content,
    certainty,
    importance,
    createdAt,
    updatedAt,
    expiresAt,
    forgotten,
    userEdited,
    sourceKind,
    sourceRef,
    goalId,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'memory_items';
  @override
  VerificationContext validateIntegrity(
    Insertable<MemoryItemRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('layer')) {
      context.handle(
        _layerMeta,
        layer.isAcceptableOrUnknown(data['layer']!, _layerMeta),
      );
    } else if (isInserting) {
      context.missing(_layerMeta);
    }
    if (data.containsKey('topic_id')) {
      context.handle(
        _topicIdMeta,
        topicId.isAcceptableOrUnknown(data['topic_id']!, _topicIdMeta),
      );
    }
    if (data.containsKey('content')) {
      context.handle(
        _contentMeta,
        content.isAcceptableOrUnknown(data['content']!, _contentMeta),
      );
    } else if (isInserting) {
      context.missing(_contentMeta);
    }
    if (data.containsKey('certainty')) {
      context.handle(
        _certaintyMeta,
        certainty.isAcceptableOrUnknown(data['certainty']!, _certaintyMeta),
      );
    } else if (isInserting) {
      context.missing(_certaintyMeta);
    }
    if (data.containsKey('importance')) {
      context.handle(
        _importanceMeta,
        importance.isAcceptableOrUnknown(data['importance']!, _importanceMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('expires_at')) {
      context.handle(
        _expiresAtMeta,
        expiresAt.isAcceptableOrUnknown(data['expires_at']!, _expiresAtMeta),
      );
    }
    if (data.containsKey('forgotten')) {
      context.handle(
        _forgottenMeta,
        forgotten.isAcceptableOrUnknown(data['forgotten']!, _forgottenMeta),
      );
    }
    if (data.containsKey('user_edited')) {
      context.handle(
        _userEditedMeta,
        userEdited.isAcceptableOrUnknown(data['user_edited']!, _userEditedMeta),
      );
    }
    if (data.containsKey('source_kind')) {
      context.handle(
        _sourceKindMeta,
        sourceKind.isAcceptableOrUnknown(data['source_kind']!, _sourceKindMeta),
      );
    } else if (isInserting) {
      context.missing(_sourceKindMeta);
    }
    if (data.containsKey('source_ref')) {
      context.handle(
        _sourceRefMeta,
        sourceRef.isAcceptableOrUnknown(data['source_ref']!, _sourceRefMeta),
      );
    }
    if (data.containsKey('goal_id')) {
      context.handle(
        _goalIdMeta,
        goalId.isAcceptableOrUnknown(data['goal_id']!, _goalIdMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  MemoryItemRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return MemoryItemRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      layer: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}layer'],
      )!,
      topicId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}topic_id'],
      ),
      content: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}content'],
      )!,
      certainty: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}certainty'],
      )!,
      importance: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}importance'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at'],
      )!,
      expiresAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}expires_at'],
      ),
      forgotten: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}forgotten'],
      )!,
      userEdited: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}user_edited'],
      )!,
      sourceKind: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source_kind'],
      )!,
      sourceRef: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source_ref'],
      ),
      goalId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}goal_id'],
      ),
    );
  }

  @override
  $MemoryItemsTable createAlias(String alias) {
    return $MemoryItemsTable(attachedDatabase, alias);
  }
}

class MemoryItemRow extends DataClass implements Insertable<MemoryItemRow> {
  final String id;
  final String layer;
  final String? topicId;
  final String content;
  final String certainty;
  final int importance;
  final int createdAt;
  final int updatedAt;
  final int? expiresAt;
  final bool forgotten;
  final bool userEdited;
  final String sourceKind;
  final String? sourceRef;
  final String? goalId;
  const MemoryItemRow({
    required this.id,
    required this.layer,
    this.topicId,
    required this.content,
    required this.certainty,
    required this.importance,
    required this.createdAt,
    required this.updatedAt,
    this.expiresAt,
    required this.forgotten,
    required this.userEdited,
    required this.sourceKind,
    this.sourceRef,
    this.goalId,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['layer'] = Variable<String>(layer);
    if (!nullToAbsent || topicId != null) {
      map['topic_id'] = Variable<String>(topicId);
    }
    map['content'] = Variable<String>(content);
    map['certainty'] = Variable<String>(certainty);
    map['importance'] = Variable<int>(importance);
    map['created_at'] = Variable<int>(createdAt);
    map['updated_at'] = Variable<int>(updatedAt);
    if (!nullToAbsent || expiresAt != null) {
      map['expires_at'] = Variable<int>(expiresAt);
    }
    map['forgotten'] = Variable<bool>(forgotten);
    map['user_edited'] = Variable<bool>(userEdited);
    map['source_kind'] = Variable<String>(sourceKind);
    if (!nullToAbsent || sourceRef != null) {
      map['source_ref'] = Variable<String>(sourceRef);
    }
    if (!nullToAbsent || goalId != null) {
      map['goal_id'] = Variable<String>(goalId);
    }
    return map;
  }

  MemoryItemsCompanion toCompanion(bool nullToAbsent) {
    return MemoryItemsCompanion(
      id: Value(id),
      layer: Value(layer),
      topicId: topicId == null && nullToAbsent
          ? const Value.absent()
          : Value(topicId),
      content: Value(content),
      certainty: Value(certainty),
      importance: Value(importance),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      expiresAt: expiresAt == null && nullToAbsent
          ? const Value.absent()
          : Value(expiresAt),
      forgotten: Value(forgotten),
      userEdited: Value(userEdited),
      sourceKind: Value(sourceKind),
      sourceRef: sourceRef == null && nullToAbsent
          ? const Value.absent()
          : Value(sourceRef),
      goalId: goalId == null && nullToAbsent
          ? const Value.absent()
          : Value(goalId),
    );
  }

  factory MemoryItemRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return MemoryItemRow(
      id: serializer.fromJson<String>(json['id']),
      layer: serializer.fromJson<String>(json['layer']),
      topicId: serializer.fromJson<String?>(json['topicId']),
      content: serializer.fromJson<String>(json['content']),
      certainty: serializer.fromJson<String>(json['certainty']),
      importance: serializer.fromJson<int>(json['importance']),
      createdAt: serializer.fromJson<int>(json['createdAt']),
      updatedAt: serializer.fromJson<int>(json['updatedAt']),
      expiresAt: serializer.fromJson<int?>(json['expiresAt']),
      forgotten: serializer.fromJson<bool>(json['forgotten']),
      userEdited: serializer.fromJson<bool>(json['userEdited']),
      sourceKind: serializer.fromJson<String>(json['sourceKind']),
      sourceRef: serializer.fromJson<String?>(json['sourceRef']),
      goalId: serializer.fromJson<String?>(json['goalId']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'layer': serializer.toJson<String>(layer),
      'topicId': serializer.toJson<String?>(topicId),
      'content': serializer.toJson<String>(content),
      'certainty': serializer.toJson<String>(certainty),
      'importance': serializer.toJson<int>(importance),
      'createdAt': serializer.toJson<int>(createdAt),
      'updatedAt': serializer.toJson<int>(updatedAt),
      'expiresAt': serializer.toJson<int?>(expiresAt),
      'forgotten': serializer.toJson<bool>(forgotten),
      'userEdited': serializer.toJson<bool>(userEdited),
      'sourceKind': serializer.toJson<String>(sourceKind),
      'sourceRef': serializer.toJson<String?>(sourceRef),
      'goalId': serializer.toJson<String?>(goalId),
    };
  }

  MemoryItemRow copyWith({
    String? id,
    String? layer,
    Value<String?> topicId = const Value.absent(),
    String? content,
    String? certainty,
    int? importance,
    int? createdAt,
    int? updatedAt,
    Value<int?> expiresAt = const Value.absent(),
    bool? forgotten,
    bool? userEdited,
    String? sourceKind,
    Value<String?> sourceRef = const Value.absent(),
    Value<String?> goalId = const Value.absent(),
  }) => MemoryItemRow(
    id: id ?? this.id,
    layer: layer ?? this.layer,
    topicId: topicId.present ? topicId.value : this.topicId,
    content: content ?? this.content,
    certainty: certainty ?? this.certainty,
    importance: importance ?? this.importance,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    expiresAt: expiresAt.present ? expiresAt.value : this.expiresAt,
    forgotten: forgotten ?? this.forgotten,
    userEdited: userEdited ?? this.userEdited,
    sourceKind: sourceKind ?? this.sourceKind,
    sourceRef: sourceRef.present ? sourceRef.value : this.sourceRef,
    goalId: goalId.present ? goalId.value : this.goalId,
  );
  MemoryItemRow copyWithCompanion(MemoryItemsCompanion data) {
    return MemoryItemRow(
      id: data.id.present ? data.id.value : this.id,
      layer: data.layer.present ? data.layer.value : this.layer,
      topicId: data.topicId.present ? data.topicId.value : this.topicId,
      content: data.content.present ? data.content.value : this.content,
      certainty: data.certainty.present ? data.certainty.value : this.certainty,
      importance: data.importance.present
          ? data.importance.value
          : this.importance,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      expiresAt: data.expiresAt.present ? data.expiresAt.value : this.expiresAt,
      forgotten: data.forgotten.present ? data.forgotten.value : this.forgotten,
      userEdited: data.userEdited.present
          ? data.userEdited.value
          : this.userEdited,
      sourceKind: data.sourceKind.present
          ? data.sourceKind.value
          : this.sourceKind,
      sourceRef: data.sourceRef.present ? data.sourceRef.value : this.sourceRef,
      goalId: data.goalId.present ? data.goalId.value : this.goalId,
    );
  }

  @override
  String toString() {
    return (StringBuffer('MemoryItemRow(')
          ..write('id: $id, ')
          ..write('layer: $layer, ')
          ..write('topicId: $topicId, ')
          ..write('content: $content, ')
          ..write('certainty: $certainty, ')
          ..write('importance: $importance, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('expiresAt: $expiresAt, ')
          ..write('forgotten: $forgotten, ')
          ..write('userEdited: $userEdited, ')
          ..write('sourceKind: $sourceKind, ')
          ..write('sourceRef: $sourceRef, ')
          ..write('goalId: $goalId')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    layer,
    topicId,
    content,
    certainty,
    importance,
    createdAt,
    updatedAt,
    expiresAt,
    forgotten,
    userEdited,
    sourceKind,
    sourceRef,
    goalId,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is MemoryItemRow &&
          other.id == this.id &&
          other.layer == this.layer &&
          other.topicId == this.topicId &&
          other.content == this.content &&
          other.certainty == this.certainty &&
          other.importance == this.importance &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.expiresAt == this.expiresAt &&
          other.forgotten == this.forgotten &&
          other.userEdited == this.userEdited &&
          other.sourceKind == this.sourceKind &&
          other.sourceRef == this.sourceRef &&
          other.goalId == this.goalId);
}

class MemoryItemsCompanion extends UpdateCompanion<MemoryItemRow> {
  final Value<String> id;
  final Value<String> layer;
  final Value<String?> topicId;
  final Value<String> content;
  final Value<String> certainty;
  final Value<int> importance;
  final Value<int> createdAt;
  final Value<int> updatedAt;
  final Value<int?> expiresAt;
  final Value<bool> forgotten;
  final Value<bool> userEdited;
  final Value<String> sourceKind;
  final Value<String?> sourceRef;
  final Value<String?> goalId;
  final Value<int> rowid;
  const MemoryItemsCompanion({
    this.id = const Value.absent(),
    this.layer = const Value.absent(),
    this.topicId = const Value.absent(),
    this.content = const Value.absent(),
    this.certainty = const Value.absent(),
    this.importance = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.expiresAt = const Value.absent(),
    this.forgotten = const Value.absent(),
    this.userEdited = const Value.absent(),
    this.sourceKind = const Value.absent(),
    this.sourceRef = const Value.absent(),
    this.goalId = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  MemoryItemsCompanion.insert({
    required String id,
    required String layer,
    this.topicId = const Value.absent(),
    required String content,
    required String certainty,
    this.importance = const Value.absent(),
    required int createdAt,
    required int updatedAt,
    this.expiresAt = const Value.absent(),
    this.forgotten = const Value.absent(),
    this.userEdited = const Value.absent(),
    required String sourceKind,
    this.sourceRef = const Value.absent(),
    this.goalId = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       layer = Value(layer),
       content = Value(content),
       certainty = Value(certainty),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt),
       sourceKind = Value(sourceKind);
  static Insertable<MemoryItemRow> custom({
    Expression<String>? id,
    Expression<String>? layer,
    Expression<String>? topicId,
    Expression<String>? content,
    Expression<String>? certainty,
    Expression<int>? importance,
    Expression<int>? createdAt,
    Expression<int>? updatedAt,
    Expression<int>? expiresAt,
    Expression<bool>? forgotten,
    Expression<bool>? userEdited,
    Expression<String>? sourceKind,
    Expression<String>? sourceRef,
    Expression<String>? goalId,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (layer != null) 'layer': layer,
      if (topicId != null) 'topic_id': topicId,
      if (content != null) 'content': content,
      if (certainty != null) 'certainty': certainty,
      if (importance != null) 'importance': importance,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (expiresAt != null) 'expires_at': expiresAt,
      if (forgotten != null) 'forgotten': forgotten,
      if (userEdited != null) 'user_edited': userEdited,
      if (sourceKind != null) 'source_kind': sourceKind,
      if (sourceRef != null) 'source_ref': sourceRef,
      if (goalId != null) 'goal_id': goalId,
      if (rowid != null) 'rowid': rowid,
    });
  }

  MemoryItemsCompanion copyWith({
    Value<String>? id,
    Value<String>? layer,
    Value<String?>? topicId,
    Value<String>? content,
    Value<String>? certainty,
    Value<int>? importance,
    Value<int>? createdAt,
    Value<int>? updatedAt,
    Value<int?>? expiresAt,
    Value<bool>? forgotten,
    Value<bool>? userEdited,
    Value<String>? sourceKind,
    Value<String?>? sourceRef,
    Value<String?>? goalId,
    Value<int>? rowid,
  }) {
    return MemoryItemsCompanion(
      id: id ?? this.id,
      layer: layer ?? this.layer,
      topicId: topicId ?? this.topicId,
      content: content ?? this.content,
      certainty: certainty ?? this.certainty,
      importance: importance ?? this.importance,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      expiresAt: expiresAt ?? this.expiresAt,
      forgotten: forgotten ?? this.forgotten,
      userEdited: userEdited ?? this.userEdited,
      sourceKind: sourceKind ?? this.sourceKind,
      sourceRef: sourceRef ?? this.sourceRef,
      goalId: goalId ?? this.goalId,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (layer.present) {
      map['layer'] = Variable<String>(layer.value);
    }
    if (topicId.present) {
      map['topic_id'] = Variable<String>(topicId.value);
    }
    if (content.present) {
      map['content'] = Variable<String>(content.value);
    }
    if (certainty.present) {
      map['certainty'] = Variable<String>(certainty.value);
    }
    if (importance.present) {
      map['importance'] = Variable<int>(importance.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(updatedAt.value);
    }
    if (expiresAt.present) {
      map['expires_at'] = Variable<int>(expiresAt.value);
    }
    if (forgotten.present) {
      map['forgotten'] = Variable<bool>(forgotten.value);
    }
    if (userEdited.present) {
      map['user_edited'] = Variable<bool>(userEdited.value);
    }
    if (sourceKind.present) {
      map['source_kind'] = Variable<String>(sourceKind.value);
    }
    if (sourceRef.present) {
      map['source_ref'] = Variable<String>(sourceRef.value);
    }
    if (goalId.present) {
      map['goal_id'] = Variable<String>(goalId.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('MemoryItemsCompanion(')
          ..write('id: $id, ')
          ..write('layer: $layer, ')
          ..write('topicId: $topicId, ')
          ..write('content: $content, ')
          ..write('certainty: $certainty, ')
          ..write('importance: $importance, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('expiresAt: $expiresAt, ')
          ..write('forgotten: $forgotten, ')
          ..write('userEdited: $userEdited, ')
          ..write('sourceKind: $sourceKind, ')
          ..write('sourceRef: $sourceRef, ')
          ..write('goalId: $goalId, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $MemoryTopicAliasesTable extends MemoryTopicAliases
    with TableInfo<$MemoryTopicAliasesTable, MemoryTopicAliasRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $MemoryTopicAliasesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _topicIdMeta = const VerificationMeta(
    'topicId',
  );
  @override
  late final GeneratedColumn<String> topicId = GeneratedColumn<String>(
    'topic_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES memory_topics (id)',
    ),
  );
  static const VerificationMeta _aliasMeta = const VerificationMeta('alias');
  @override
  late final GeneratedColumn<String> alias = GeneratedColumn<String>(
    'alias',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _normalizedAliasMeta = const VerificationMeta(
    'normalizedAlias',
  );
  @override
  late final GeneratedColumn<String> normalizedAlias = GeneratedColumn<String>(
    'normalized_alias',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [topicId, alias, normalizedAlias];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'memory_topic_aliases';
  @override
  VerificationContext validateIntegrity(
    Insertable<MemoryTopicAliasRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('topic_id')) {
      context.handle(
        _topicIdMeta,
        topicId.isAcceptableOrUnknown(data['topic_id']!, _topicIdMeta),
      );
    } else if (isInserting) {
      context.missing(_topicIdMeta);
    }
    if (data.containsKey('alias')) {
      context.handle(
        _aliasMeta,
        alias.isAcceptableOrUnknown(data['alias']!, _aliasMeta),
      );
    } else if (isInserting) {
      context.missing(_aliasMeta);
    }
    if (data.containsKey('normalized_alias')) {
      context.handle(
        _normalizedAliasMeta,
        normalizedAlias.isAcceptableOrUnknown(
          data['normalized_alias']!,
          _normalizedAliasMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_normalizedAliasMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {topicId, normalizedAlias};
  @override
  MemoryTopicAliasRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return MemoryTopicAliasRow(
      topicId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}topic_id'],
      )!,
      alias: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}alias'],
      )!,
      normalizedAlias: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}normalized_alias'],
      )!,
    );
  }

  @override
  $MemoryTopicAliasesTable createAlias(String alias) {
    return $MemoryTopicAliasesTable(attachedDatabase, alias);
  }
}

class MemoryTopicAliasRow extends DataClass
    implements Insertable<MemoryTopicAliasRow> {
  final String topicId;
  final String alias;
  final String normalizedAlias;
  const MemoryTopicAliasRow({
    required this.topicId,
    required this.alias,
    required this.normalizedAlias,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['topic_id'] = Variable<String>(topicId);
    map['alias'] = Variable<String>(alias);
    map['normalized_alias'] = Variable<String>(normalizedAlias);
    return map;
  }

  MemoryTopicAliasesCompanion toCompanion(bool nullToAbsent) {
    return MemoryTopicAliasesCompanion(
      topicId: Value(topicId),
      alias: Value(alias),
      normalizedAlias: Value(normalizedAlias),
    );
  }

  factory MemoryTopicAliasRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return MemoryTopicAliasRow(
      topicId: serializer.fromJson<String>(json['topicId']),
      alias: serializer.fromJson<String>(json['alias']),
      normalizedAlias: serializer.fromJson<String>(json['normalizedAlias']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'topicId': serializer.toJson<String>(topicId),
      'alias': serializer.toJson<String>(alias),
      'normalizedAlias': serializer.toJson<String>(normalizedAlias),
    };
  }

  MemoryTopicAliasRow copyWith({
    String? topicId,
    String? alias,
    String? normalizedAlias,
  }) => MemoryTopicAliasRow(
    topicId: topicId ?? this.topicId,
    alias: alias ?? this.alias,
    normalizedAlias: normalizedAlias ?? this.normalizedAlias,
  );
  MemoryTopicAliasRow copyWithCompanion(MemoryTopicAliasesCompanion data) {
    return MemoryTopicAliasRow(
      topicId: data.topicId.present ? data.topicId.value : this.topicId,
      alias: data.alias.present ? data.alias.value : this.alias,
      normalizedAlias: data.normalizedAlias.present
          ? data.normalizedAlias.value
          : this.normalizedAlias,
    );
  }

  @override
  String toString() {
    return (StringBuffer('MemoryTopicAliasRow(')
          ..write('topicId: $topicId, ')
          ..write('alias: $alias, ')
          ..write('normalizedAlias: $normalizedAlias')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(topicId, alias, normalizedAlias);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is MemoryTopicAliasRow &&
          other.topicId == this.topicId &&
          other.alias == this.alias &&
          other.normalizedAlias == this.normalizedAlias);
}

class MemoryTopicAliasesCompanion extends UpdateCompanion<MemoryTopicAliasRow> {
  final Value<String> topicId;
  final Value<String> alias;
  final Value<String> normalizedAlias;
  final Value<int> rowid;
  const MemoryTopicAliasesCompanion({
    this.topicId = const Value.absent(),
    this.alias = const Value.absent(),
    this.normalizedAlias = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  MemoryTopicAliasesCompanion.insert({
    required String topicId,
    required String alias,
    required String normalizedAlias,
    this.rowid = const Value.absent(),
  }) : topicId = Value(topicId),
       alias = Value(alias),
       normalizedAlias = Value(normalizedAlias);
  static Insertable<MemoryTopicAliasRow> custom({
    Expression<String>? topicId,
    Expression<String>? alias,
    Expression<String>? normalizedAlias,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (topicId != null) 'topic_id': topicId,
      if (alias != null) 'alias': alias,
      if (normalizedAlias != null) 'normalized_alias': normalizedAlias,
      if (rowid != null) 'rowid': rowid,
    });
  }

  MemoryTopicAliasesCompanion copyWith({
    Value<String>? topicId,
    Value<String>? alias,
    Value<String>? normalizedAlias,
    Value<int>? rowid,
  }) {
    return MemoryTopicAliasesCompanion(
      topicId: topicId ?? this.topicId,
      alias: alias ?? this.alias,
      normalizedAlias: normalizedAlias ?? this.normalizedAlias,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (topicId.present) {
      map['topic_id'] = Variable<String>(topicId.value);
    }
    if (alias.present) {
      map['alias'] = Variable<String>(alias.value);
    }
    if (normalizedAlias.present) {
      map['normalized_alias'] = Variable<String>(normalizedAlias.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('MemoryTopicAliasesCompanion(')
          ..write('topicId: $topicId, ')
          ..write('alias: $alias, ')
          ..write('normalizedAlias: $normalizedAlias, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $MemoryVersionsTable extends MemoryVersions
    with TableInfo<$MemoryVersionsTable, MemoryVersionRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $MemoryVersionsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _itemIdMeta = const VerificationMeta('itemId');
  @override
  late final GeneratedColumn<String> itemId = GeneratedColumn<String>(
    'item_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES memory_items (id)',
    ),
  );
  static const VerificationMeta _changeKindMeta = const VerificationMeta(
    'changeKind',
  );
  @override
  late final GeneratedColumn<String> changeKind = GeneratedColumn<String>(
    'change_kind',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _beforeJsonMeta = const VerificationMeta(
    'beforeJson',
  );
  @override
  late final GeneratedColumn<String> beforeJson = GeneratedColumn<String>(
    'before_json',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _afterJsonMeta = const VerificationMeta(
    'afterJson',
  );
  @override
  late final GeneratedColumn<String> afterJson = GeneratedColumn<String>(
    'after_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _reasonMeta = const VerificationMeta('reason');
  @override
  late final GeneratedColumn<String> reason = GeneratedColumn<String>(
    'reason',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _operationIdMeta = const VerificationMeta(
    'operationId',
  );
  @override
  late final GeneratedColumn<String> operationId = GeneratedColumn<String>(
    'operation_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _actorMeta = const VerificationMeta('actor');
  @override
  late final GeneratedColumn<String> actor = GeneratedColumn<String>(
    'actor',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    itemId,
    changeKind,
    beforeJson,
    afterJson,
    reason,
    operationId,
    actor,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'memory_versions';
  @override
  VerificationContext validateIntegrity(
    Insertable<MemoryVersionRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('item_id')) {
      context.handle(
        _itemIdMeta,
        itemId.isAcceptableOrUnknown(data['item_id']!, _itemIdMeta),
      );
    } else if (isInserting) {
      context.missing(_itemIdMeta);
    }
    if (data.containsKey('change_kind')) {
      context.handle(
        _changeKindMeta,
        changeKind.isAcceptableOrUnknown(data['change_kind']!, _changeKindMeta),
      );
    } else if (isInserting) {
      context.missing(_changeKindMeta);
    }
    if (data.containsKey('before_json')) {
      context.handle(
        _beforeJsonMeta,
        beforeJson.isAcceptableOrUnknown(data['before_json']!, _beforeJsonMeta),
      );
    }
    if (data.containsKey('after_json')) {
      context.handle(
        _afterJsonMeta,
        afterJson.isAcceptableOrUnknown(data['after_json']!, _afterJsonMeta),
      );
    } else if (isInserting) {
      context.missing(_afterJsonMeta);
    }
    if (data.containsKey('reason')) {
      context.handle(
        _reasonMeta,
        reason.isAcceptableOrUnknown(data['reason']!, _reasonMeta),
      );
    } else if (isInserting) {
      context.missing(_reasonMeta);
    }
    if (data.containsKey('operation_id')) {
      context.handle(
        _operationIdMeta,
        operationId.isAcceptableOrUnknown(
          data['operation_id']!,
          _operationIdMeta,
        ),
      );
    }
    if (data.containsKey('actor')) {
      context.handle(
        _actorMeta,
        actor.isAcceptableOrUnknown(data['actor']!, _actorMeta),
      );
    } else if (isInserting) {
      context.missing(_actorMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  MemoryVersionRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return MemoryVersionRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      itemId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}item_id'],
      )!,
      changeKind: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}change_kind'],
      )!,
      beforeJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}before_json'],
      ),
      afterJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}after_json'],
      )!,
      reason: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}reason'],
      )!,
      operationId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}operation_id'],
      ),
      actor: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}actor'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $MemoryVersionsTable createAlias(String alias) {
    return $MemoryVersionsTable(attachedDatabase, alias);
  }
}

class MemoryVersionRow extends DataClass
    implements Insertable<MemoryVersionRow> {
  final String id;
  final String itemId;
  final String changeKind;
  final String? beforeJson;
  final String afterJson;
  final String reason;
  final String? operationId;
  final String actor;
  final int createdAt;
  const MemoryVersionRow({
    required this.id,
    required this.itemId,
    required this.changeKind,
    this.beforeJson,
    required this.afterJson,
    required this.reason,
    this.operationId,
    required this.actor,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['item_id'] = Variable<String>(itemId);
    map['change_kind'] = Variable<String>(changeKind);
    if (!nullToAbsent || beforeJson != null) {
      map['before_json'] = Variable<String>(beforeJson);
    }
    map['after_json'] = Variable<String>(afterJson);
    map['reason'] = Variable<String>(reason);
    if (!nullToAbsent || operationId != null) {
      map['operation_id'] = Variable<String>(operationId);
    }
    map['actor'] = Variable<String>(actor);
    map['created_at'] = Variable<int>(createdAt);
    return map;
  }

  MemoryVersionsCompanion toCompanion(bool nullToAbsent) {
    return MemoryVersionsCompanion(
      id: Value(id),
      itemId: Value(itemId),
      changeKind: Value(changeKind),
      beforeJson: beforeJson == null && nullToAbsent
          ? const Value.absent()
          : Value(beforeJson),
      afterJson: Value(afterJson),
      reason: Value(reason),
      operationId: operationId == null && nullToAbsent
          ? const Value.absent()
          : Value(operationId),
      actor: Value(actor),
      createdAt: Value(createdAt),
    );
  }

  factory MemoryVersionRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return MemoryVersionRow(
      id: serializer.fromJson<String>(json['id']),
      itemId: serializer.fromJson<String>(json['itemId']),
      changeKind: serializer.fromJson<String>(json['changeKind']),
      beforeJson: serializer.fromJson<String?>(json['beforeJson']),
      afterJson: serializer.fromJson<String>(json['afterJson']),
      reason: serializer.fromJson<String>(json['reason']),
      operationId: serializer.fromJson<String?>(json['operationId']),
      actor: serializer.fromJson<String>(json['actor']),
      createdAt: serializer.fromJson<int>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'itemId': serializer.toJson<String>(itemId),
      'changeKind': serializer.toJson<String>(changeKind),
      'beforeJson': serializer.toJson<String?>(beforeJson),
      'afterJson': serializer.toJson<String>(afterJson),
      'reason': serializer.toJson<String>(reason),
      'operationId': serializer.toJson<String?>(operationId),
      'actor': serializer.toJson<String>(actor),
      'createdAt': serializer.toJson<int>(createdAt),
    };
  }

  MemoryVersionRow copyWith({
    String? id,
    String? itemId,
    String? changeKind,
    Value<String?> beforeJson = const Value.absent(),
    String? afterJson,
    String? reason,
    Value<String?> operationId = const Value.absent(),
    String? actor,
    int? createdAt,
  }) => MemoryVersionRow(
    id: id ?? this.id,
    itemId: itemId ?? this.itemId,
    changeKind: changeKind ?? this.changeKind,
    beforeJson: beforeJson.present ? beforeJson.value : this.beforeJson,
    afterJson: afterJson ?? this.afterJson,
    reason: reason ?? this.reason,
    operationId: operationId.present ? operationId.value : this.operationId,
    actor: actor ?? this.actor,
    createdAt: createdAt ?? this.createdAt,
  );
  MemoryVersionRow copyWithCompanion(MemoryVersionsCompanion data) {
    return MemoryVersionRow(
      id: data.id.present ? data.id.value : this.id,
      itemId: data.itemId.present ? data.itemId.value : this.itemId,
      changeKind: data.changeKind.present
          ? data.changeKind.value
          : this.changeKind,
      beforeJson: data.beforeJson.present
          ? data.beforeJson.value
          : this.beforeJson,
      afterJson: data.afterJson.present ? data.afterJson.value : this.afterJson,
      reason: data.reason.present ? data.reason.value : this.reason,
      operationId: data.operationId.present
          ? data.operationId.value
          : this.operationId,
      actor: data.actor.present ? data.actor.value : this.actor,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('MemoryVersionRow(')
          ..write('id: $id, ')
          ..write('itemId: $itemId, ')
          ..write('changeKind: $changeKind, ')
          ..write('beforeJson: $beforeJson, ')
          ..write('afterJson: $afterJson, ')
          ..write('reason: $reason, ')
          ..write('operationId: $operationId, ')
          ..write('actor: $actor, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    itemId,
    changeKind,
    beforeJson,
    afterJson,
    reason,
    operationId,
    actor,
    createdAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is MemoryVersionRow &&
          other.id == this.id &&
          other.itemId == this.itemId &&
          other.changeKind == this.changeKind &&
          other.beforeJson == this.beforeJson &&
          other.afterJson == this.afterJson &&
          other.reason == this.reason &&
          other.operationId == this.operationId &&
          other.actor == this.actor &&
          other.createdAt == this.createdAt);
}

class MemoryVersionsCompanion extends UpdateCompanion<MemoryVersionRow> {
  final Value<String> id;
  final Value<String> itemId;
  final Value<String> changeKind;
  final Value<String?> beforeJson;
  final Value<String> afterJson;
  final Value<String> reason;
  final Value<String?> operationId;
  final Value<String> actor;
  final Value<int> createdAt;
  final Value<int> rowid;
  const MemoryVersionsCompanion({
    this.id = const Value.absent(),
    this.itemId = const Value.absent(),
    this.changeKind = const Value.absent(),
    this.beforeJson = const Value.absent(),
    this.afterJson = const Value.absent(),
    this.reason = const Value.absent(),
    this.operationId = const Value.absent(),
    this.actor = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  MemoryVersionsCompanion.insert({
    required String id,
    required String itemId,
    required String changeKind,
    this.beforeJson = const Value.absent(),
    required String afterJson,
    required String reason,
    this.operationId = const Value.absent(),
    required String actor,
    required int createdAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       itemId = Value(itemId),
       changeKind = Value(changeKind),
       afterJson = Value(afterJson),
       reason = Value(reason),
       actor = Value(actor),
       createdAt = Value(createdAt);
  static Insertable<MemoryVersionRow> custom({
    Expression<String>? id,
    Expression<String>? itemId,
    Expression<String>? changeKind,
    Expression<String>? beforeJson,
    Expression<String>? afterJson,
    Expression<String>? reason,
    Expression<String>? operationId,
    Expression<String>? actor,
    Expression<int>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (itemId != null) 'item_id': itemId,
      if (changeKind != null) 'change_kind': changeKind,
      if (beforeJson != null) 'before_json': beforeJson,
      if (afterJson != null) 'after_json': afterJson,
      if (reason != null) 'reason': reason,
      if (operationId != null) 'operation_id': operationId,
      if (actor != null) 'actor': actor,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  MemoryVersionsCompanion copyWith({
    Value<String>? id,
    Value<String>? itemId,
    Value<String>? changeKind,
    Value<String?>? beforeJson,
    Value<String>? afterJson,
    Value<String>? reason,
    Value<String?>? operationId,
    Value<String>? actor,
    Value<int>? createdAt,
    Value<int>? rowid,
  }) {
    return MemoryVersionsCompanion(
      id: id ?? this.id,
      itemId: itemId ?? this.itemId,
      changeKind: changeKind ?? this.changeKind,
      beforeJson: beforeJson ?? this.beforeJson,
      afterJson: afterJson ?? this.afterJson,
      reason: reason ?? this.reason,
      operationId: operationId ?? this.operationId,
      actor: actor ?? this.actor,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (itemId.present) {
      map['item_id'] = Variable<String>(itemId.value);
    }
    if (changeKind.present) {
      map['change_kind'] = Variable<String>(changeKind.value);
    }
    if (beforeJson.present) {
      map['before_json'] = Variable<String>(beforeJson.value);
    }
    if (afterJson.present) {
      map['after_json'] = Variable<String>(afterJson.value);
    }
    if (reason.present) {
      map['reason'] = Variable<String>(reason.value);
    }
    if (operationId.present) {
      map['operation_id'] = Variable<String>(operationId.value);
    }
    if (actor.present) {
      map['actor'] = Variable<String>(actor.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('MemoryVersionsCompanion(')
          ..write('id: $id, ')
          ..write('itemId: $itemId, ')
          ..write('changeKind: $changeKind, ')
          ..write('beforeJson: $beforeJson, ')
          ..write('afterJson: $afterJson, ')
          ..write('reason: $reason, ')
          ..write('operationId: $operationId, ')
          ..write('actor: $actor, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $MemoryEpisodesTable extends MemoryEpisodes
    with TableInfo<$MemoryEpisodesTable, MemoryEpisodeRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $MemoryEpisodesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _itemIdMeta = const VerificationMeta('itemId');
  @override
  late final GeneratedColumn<String> itemId = GeneratedColumn<String>(
    'item_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES memory_items (id)',
    ),
  );
  static const VerificationMeta _sourceRefsJsonMeta = const VerificationMeta(
    'sourceRefsJson',
  );
  @override
  late final GeneratedColumn<String> sourceRefsJson = GeneratedColumn<String>(
    'source_refs_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [itemId, sourceRefsJson];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'memory_episodes';
  @override
  VerificationContext validateIntegrity(
    Insertable<MemoryEpisodeRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('item_id')) {
      context.handle(
        _itemIdMeta,
        itemId.isAcceptableOrUnknown(data['item_id']!, _itemIdMeta),
      );
    } else if (isInserting) {
      context.missing(_itemIdMeta);
    }
    if (data.containsKey('source_refs_json')) {
      context.handle(
        _sourceRefsJsonMeta,
        sourceRefsJson.isAcceptableOrUnknown(
          data['source_refs_json']!,
          _sourceRefsJsonMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_sourceRefsJsonMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {itemId};
  @override
  MemoryEpisodeRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return MemoryEpisodeRow(
      itemId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}item_id'],
      )!,
      sourceRefsJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source_refs_json'],
      )!,
    );
  }

  @override
  $MemoryEpisodesTable createAlias(String alias) {
    return $MemoryEpisodesTable(attachedDatabase, alias);
  }
}

class MemoryEpisodeRow extends DataClass
    implements Insertable<MemoryEpisodeRow> {
  final String itemId;
  final String sourceRefsJson;
  const MemoryEpisodeRow({required this.itemId, required this.sourceRefsJson});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['item_id'] = Variable<String>(itemId);
    map['source_refs_json'] = Variable<String>(sourceRefsJson);
    return map;
  }

  MemoryEpisodesCompanion toCompanion(bool nullToAbsent) {
    return MemoryEpisodesCompanion(
      itemId: Value(itemId),
      sourceRefsJson: Value(sourceRefsJson),
    );
  }

  factory MemoryEpisodeRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return MemoryEpisodeRow(
      itemId: serializer.fromJson<String>(json['itemId']),
      sourceRefsJson: serializer.fromJson<String>(json['sourceRefsJson']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'itemId': serializer.toJson<String>(itemId),
      'sourceRefsJson': serializer.toJson<String>(sourceRefsJson),
    };
  }

  MemoryEpisodeRow copyWith({String? itemId, String? sourceRefsJson}) =>
      MemoryEpisodeRow(
        itemId: itemId ?? this.itemId,
        sourceRefsJson: sourceRefsJson ?? this.sourceRefsJson,
      );
  MemoryEpisodeRow copyWithCompanion(MemoryEpisodesCompanion data) {
    return MemoryEpisodeRow(
      itemId: data.itemId.present ? data.itemId.value : this.itemId,
      sourceRefsJson: data.sourceRefsJson.present
          ? data.sourceRefsJson.value
          : this.sourceRefsJson,
    );
  }

  @override
  String toString() {
    return (StringBuffer('MemoryEpisodeRow(')
          ..write('itemId: $itemId, ')
          ..write('sourceRefsJson: $sourceRefsJson')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(itemId, sourceRefsJson);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is MemoryEpisodeRow &&
          other.itemId == this.itemId &&
          other.sourceRefsJson == this.sourceRefsJson);
}

class MemoryEpisodesCompanion extends UpdateCompanion<MemoryEpisodeRow> {
  final Value<String> itemId;
  final Value<String> sourceRefsJson;
  final Value<int> rowid;
  const MemoryEpisodesCompanion({
    this.itemId = const Value.absent(),
    this.sourceRefsJson = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  MemoryEpisodesCompanion.insert({
    required String itemId,
    required String sourceRefsJson,
    this.rowid = const Value.absent(),
  }) : itemId = Value(itemId),
       sourceRefsJson = Value(sourceRefsJson);
  static Insertable<MemoryEpisodeRow> custom({
    Expression<String>? itemId,
    Expression<String>? sourceRefsJson,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (itemId != null) 'item_id': itemId,
      if (sourceRefsJson != null) 'source_refs_json': sourceRefsJson,
      if (rowid != null) 'rowid': rowid,
    });
  }

  MemoryEpisodesCompanion copyWith({
    Value<String>? itemId,
    Value<String>? sourceRefsJson,
    Value<int>? rowid,
  }) {
    return MemoryEpisodesCompanion(
      itemId: itemId ?? this.itemId,
      sourceRefsJson: sourceRefsJson ?? this.sourceRefsJson,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (itemId.present) {
      map['item_id'] = Variable<String>(itemId.value);
    }
    if (sourceRefsJson.present) {
      map['source_refs_json'] = Variable<String>(sourceRefsJson.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('MemoryEpisodesCompanion(')
          ..write('itemId: $itemId, ')
          ..write('sourceRefsJson: $sourceRefsJson, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $MemoryProceduresTable extends MemoryProcedures
    with TableInfo<$MemoryProceduresTable, MemoryProcedureRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $MemoryProceduresTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _itemIdMeta = const VerificationMeta('itemId');
  @override
  late final GeneratedColumn<String> itemId = GeneratedColumn<String>(
    'item_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES memory_items (id)',
    ),
  );
  static const VerificationMeta _stepsJsonMeta = const VerificationMeta(
    'stepsJson',
  );
  @override
  late final GeneratedColumn<String> stepsJson = GeneratedColumn<String>(
    'steps_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _triggerContextMeta = const VerificationMeta(
    'triggerContext',
  );
  @override
  late final GeneratedColumn<String> triggerContext = GeneratedColumn<String>(
    'trigger_context',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _sourceRefsJsonMeta = const VerificationMeta(
    'sourceRefsJson',
  );
  @override
  late final GeneratedColumn<String> sourceRefsJson = GeneratedColumn<String>(
    'source_refs_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    itemId,
    stepsJson,
    triggerContext,
    sourceRefsJson,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'memory_procedures';
  @override
  VerificationContext validateIntegrity(
    Insertable<MemoryProcedureRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('item_id')) {
      context.handle(
        _itemIdMeta,
        itemId.isAcceptableOrUnknown(data['item_id']!, _itemIdMeta),
      );
    } else if (isInserting) {
      context.missing(_itemIdMeta);
    }
    if (data.containsKey('steps_json')) {
      context.handle(
        _stepsJsonMeta,
        stepsJson.isAcceptableOrUnknown(data['steps_json']!, _stepsJsonMeta),
      );
    } else if (isInserting) {
      context.missing(_stepsJsonMeta);
    }
    if (data.containsKey('trigger_context')) {
      context.handle(
        _triggerContextMeta,
        triggerContext.isAcceptableOrUnknown(
          data['trigger_context']!,
          _triggerContextMeta,
        ),
      );
    }
    if (data.containsKey('source_refs_json')) {
      context.handle(
        _sourceRefsJsonMeta,
        sourceRefsJson.isAcceptableOrUnknown(
          data['source_refs_json']!,
          _sourceRefsJsonMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_sourceRefsJsonMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {itemId};
  @override
  MemoryProcedureRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return MemoryProcedureRow(
      itemId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}item_id'],
      )!,
      stepsJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}steps_json'],
      )!,
      triggerContext: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}trigger_context'],
      ),
      sourceRefsJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source_refs_json'],
      )!,
    );
  }

  @override
  $MemoryProceduresTable createAlias(String alias) {
    return $MemoryProceduresTable(attachedDatabase, alias);
  }
}

class MemoryProcedureRow extends DataClass
    implements Insertable<MemoryProcedureRow> {
  final String itemId;
  final String stepsJson;
  final String? triggerContext;
  final String sourceRefsJson;
  const MemoryProcedureRow({
    required this.itemId,
    required this.stepsJson,
    this.triggerContext,
    required this.sourceRefsJson,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['item_id'] = Variable<String>(itemId);
    map['steps_json'] = Variable<String>(stepsJson);
    if (!nullToAbsent || triggerContext != null) {
      map['trigger_context'] = Variable<String>(triggerContext);
    }
    map['source_refs_json'] = Variable<String>(sourceRefsJson);
    return map;
  }

  MemoryProceduresCompanion toCompanion(bool nullToAbsent) {
    return MemoryProceduresCompanion(
      itemId: Value(itemId),
      stepsJson: Value(stepsJson),
      triggerContext: triggerContext == null && nullToAbsent
          ? const Value.absent()
          : Value(triggerContext),
      sourceRefsJson: Value(sourceRefsJson),
    );
  }

  factory MemoryProcedureRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return MemoryProcedureRow(
      itemId: serializer.fromJson<String>(json['itemId']),
      stepsJson: serializer.fromJson<String>(json['stepsJson']),
      triggerContext: serializer.fromJson<String?>(json['triggerContext']),
      sourceRefsJson: serializer.fromJson<String>(json['sourceRefsJson']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'itemId': serializer.toJson<String>(itemId),
      'stepsJson': serializer.toJson<String>(stepsJson),
      'triggerContext': serializer.toJson<String?>(triggerContext),
      'sourceRefsJson': serializer.toJson<String>(sourceRefsJson),
    };
  }

  MemoryProcedureRow copyWith({
    String? itemId,
    String? stepsJson,
    Value<String?> triggerContext = const Value.absent(),
    String? sourceRefsJson,
  }) => MemoryProcedureRow(
    itemId: itemId ?? this.itemId,
    stepsJson: stepsJson ?? this.stepsJson,
    triggerContext: triggerContext.present
        ? triggerContext.value
        : this.triggerContext,
    sourceRefsJson: sourceRefsJson ?? this.sourceRefsJson,
  );
  MemoryProcedureRow copyWithCompanion(MemoryProceduresCompanion data) {
    return MemoryProcedureRow(
      itemId: data.itemId.present ? data.itemId.value : this.itemId,
      stepsJson: data.stepsJson.present ? data.stepsJson.value : this.stepsJson,
      triggerContext: data.triggerContext.present
          ? data.triggerContext.value
          : this.triggerContext,
      sourceRefsJson: data.sourceRefsJson.present
          ? data.sourceRefsJson.value
          : this.sourceRefsJson,
    );
  }

  @override
  String toString() {
    return (StringBuffer('MemoryProcedureRow(')
          ..write('itemId: $itemId, ')
          ..write('stepsJson: $stepsJson, ')
          ..write('triggerContext: $triggerContext, ')
          ..write('sourceRefsJson: $sourceRefsJson')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(itemId, stepsJson, triggerContext, sourceRefsJson);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is MemoryProcedureRow &&
          other.itemId == this.itemId &&
          other.stepsJson == this.stepsJson &&
          other.triggerContext == this.triggerContext &&
          other.sourceRefsJson == this.sourceRefsJson);
}

class MemoryProceduresCompanion extends UpdateCompanion<MemoryProcedureRow> {
  final Value<String> itemId;
  final Value<String> stepsJson;
  final Value<String?> triggerContext;
  final Value<String> sourceRefsJson;
  final Value<int> rowid;
  const MemoryProceduresCompanion({
    this.itemId = const Value.absent(),
    this.stepsJson = const Value.absent(),
    this.triggerContext = const Value.absent(),
    this.sourceRefsJson = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  MemoryProceduresCompanion.insert({
    required String itemId,
    required String stepsJson,
    this.triggerContext = const Value.absent(),
    required String sourceRefsJson,
    this.rowid = const Value.absent(),
  }) : itemId = Value(itemId),
       stepsJson = Value(stepsJson),
       sourceRefsJson = Value(sourceRefsJson);
  static Insertable<MemoryProcedureRow> custom({
    Expression<String>? itemId,
    Expression<String>? stepsJson,
    Expression<String>? triggerContext,
    Expression<String>? sourceRefsJson,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (itemId != null) 'item_id': itemId,
      if (stepsJson != null) 'steps_json': stepsJson,
      if (triggerContext != null) 'trigger_context': triggerContext,
      if (sourceRefsJson != null) 'source_refs_json': sourceRefsJson,
      if (rowid != null) 'rowid': rowid,
    });
  }

  MemoryProceduresCompanion copyWith({
    Value<String>? itemId,
    Value<String>? stepsJson,
    Value<String?>? triggerContext,
    Value<String>? sourceRefsJson,
    Value<int>? rowid,
  }) {
    return MemoryProceduresCompanion(
      itemId: itemId ?? this.itemId,
      stepsJson: stepsJson ?? this.stepsJson,
      triggerContext: triggerContext ?? this.triggerContext,
      sourceRefsJson: sourceRefsJson ?? this.sourceRefsJson,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (itemId.present) {
      map['item_id'] = Variable<String>(itemId.value);
    }
    if (stepsJson.present) {
      map['steps_json'] = Variable<String>(stepsJson.value);
    }
    if (triggerContext.present) {
      map['trigger_context'] = Variable<String>(triggerContext.value);
    }
    if (sourceRefsJson.present) {
      map['source_refs_json'] = Variable<String>(sourceRefsJson.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('MemoryProceduresCompanion(')
          ..write('itemId: $itemId, ')
          ..write('stepsJson: $stepsJson, ')
          ..write('triggerContext: $triggerContext, ')
          ..write('sourceRefsJson: $sourceRefsJson, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $MemoryUsageTable extends MemoryUsage
    with TableInfo<$MemoryUsageTable, MemoryUsageRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $MemoryUsageTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _itemIdMeta = const VerificationMeta('itemId');
  @override
  late final GeneratedColumn<String> itemId = GeneratedColumn<String>(
    'item_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES memory_items (id)',
    ),
  );
  static const VerificationMeta _recallCountMeta = const VerificationMeta(
    'recallCount',
  );
  @override
  late final GeneratedColumn<int> recallCount = GeneratedColumn<int>(
    'recall_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _injectCountMeta = const VerificationMeta(
    'injectCount',
  );
  @override
  late final GeneratedColumn<int> injectCount = GeneratedColumn<int>(
    'inject_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _lastUsedAtMeta = const VerificationMeta(
    'lastUsedAt',
  );
  @override
  late final GeneratedColumn<int> lastUsedAt = GeneratedColumn<int>(
    'last_used_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    itemId,
    recallCount,
    injectCount,
    lastUsedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'memory_usage';
  @override
  VerificationContext validateIntegrity(
    Insertable<MemoryUsageRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('item_id')) {
      context.handle(
        _itemIdMeta,
        itemId.isAcceptableOrUnknown(data['item_id']!, _itemIdMeta),
      );
    } else if (isInserting) {
      context.missing(_itemIdMeta);
    }
    if (data.containsKey('recall_count')) {
      context.handle(
        _recallCountMeta,
        recallCount.isAcceptableOrUnknown(
          data['recall_count']!,
          _recallCountMeta,
        ),
      );
    }
    if (data.containsKey('inject_count')) {
      context.handle(
        _injectCountMeta,
        injectCount.isAcceptableOrUnknown(
          data['inject_count']!,
          _injectCountMeta,
        ),
      );
    }
    if (data.containsKey('last_used_at')) {
      context.handle(
        _lastUsedAtMeta,
        lastUsedAt.isAcceptableOrUnknown(
          data['last_used_at']!,
          _lastUsedAtMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {itemId};
  @override
  MemoryUsageRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return MemoryUsageRow(
      itemId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}item_id'],
      )!,
      recallCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}recall_count'],
      )!,
      injectCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}inject_count'],
      )!,
      lastUsedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}last_used_at'],
      ),
    );
  }

  @override
  $MemoryUsageTable createAlias(String alias) {
    return $MemoryUsageTable(attachedDatabase, alias);
  }
}

class MemoryUsageRow extends DataClass implements Insertable<MemoryUsageRow> {
  final String itemId;
  final int recallCount;
  final int injectCount;
  final int? lastUsedAt;
  const MemoryUsageRow({
    required this.itemId,
    required this.recallCount,
    required this.injectCount,
    this.lastUsedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['item_id'] = Variable<String>(itemId);
    map['recall_count'] = Variable<int>(recallCount);
    map['inject_count'] = Variable<int>(injectCount);
    if (!nullToAbsent || lastUsedAt != null) {
      map['last_used_at'] = Variable<int>(lastUsedAt);
    }
    return map;
  }

  MemoryUsageCompanion toCompanion(bool nullToAbsent) {
    return MemoryUsageCompanion(
      itemId: Value(itemId),
      recallCount: Value(recallCount),
      injectCount: Value(injectCount),
      lastUsedAt: lastUsedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(lastUsedAt),
    );
  }

  factory MemoryUsageRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return MemoryUsageRow(
      itemId: serializer.fromJson<String>(json['itemId']),
      recallCount: serializer.fromJson<int>(json['recallCount']),
      injectCount: serializer.fromJson<int>(json['injectCount']),
      lastUsedAt: serializer.fromJson<int?>(json['lastUsedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'itemId': serializer.toJson<String>(itemId),
      'recallCount': serializer.toJson<int>(recallCount),
      'injectCount': serializer.toJson<int>(injectCount),
      'lastUsedAt': serializer.toJson<int?>(lastUsedAt),
    };
  }

  MemoryUsageRow copyWith({
    String? itemId,
    int? recallCount,
    int? injectCount,
    Value<int?> lastUsedAt = const Value.absent(),
  }) => MemoryUsageRow(
    itemId: itemId ?? this.itemId,
    recallCount: recallCount ?? this.recallCount,
    injectCount: injectCount ?? this.injectCount,
    lastUsedAt: lastUsedAt.present ? lastUsedAt.value : this.lastUsedAt,
  );
  MemoryUsageRow copyWithCompanion(MemoryUsageCompanion data) {
    return MemoryUsageRow(
      itemId: data.itemId.present ? data.itemId.value : this.itemId,
      recallCount: data.recallCount.present
          ? data.recallCount.value
          : this.recallCount,
      injectCount: data.injectCount.present
          ? data.injectCount.value
          : this.injectCount,
      lastUsedAt: data.lastUsedAt.present
          ? data.lastUsedAt.value
          : this.lastUsedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('MemoryUsageRow(')
          ..write('itemId: $itemId, ')
          ..write('recallCount: $recallCount, ')
          ..write('injectCount: $injectCount, ')
          ..write('lastUsedAt: $lastUsedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(itemId, recallCount, injectCount, lastUsedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is MemoryUsageRow &&
          other.itemId == this.itemId &&
          other.recallCount == this.recallCount &&
          other.injectCount == this.injectCount &&
          other.lastUsedAt == this.lastUsedAt);
}

class MemoryUsageCompanion extends UpdateCompanion<MemoryUsageRow> {
  final Value<String> itemId;
  final Value<int> recallCount;
  final Value<int> injectCount;
  final Value<int?> lastUsedAt;
  final Value<int> rowid;
  const MemoryUsageCompanion({
    this.itemId = const Value.absent(),
    this.recallCount = const Value.absent(),
    this.injectCount = const Value.absent(),
    this.lastUsedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  MemoryUsageCompanion.insert({
    required String itemId,
    this.recallCount = const Value.absent(),
    this.injectCount = const Value.absent(),
    this.lastUsedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : itemId = Value(itemId);
  static Insertable<MemoryUsageRow> custom({
    Expression<String>? itemId,
    Expression<int>? recallCount,
    Expression<int>? injectCount,
    Expression<int>? lastUsedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (itemId != null) 'item_id': itemId,
      if (recallCount != null) 'recall_count': recallCount,
      if (injectCount != null) 'inject_count': injectCount,
      if (lastUsedAt != null) 'last_used_at': lastUsedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  MemoryUsageCompanion copyWith({
    Value<String>? itemId,
    Value<int>? recallCount,
    Value<int>? injectCount,
    Value<int?>? lastUsedAt,
    Value<int>? rowid,
  }) {
    return MemoryUsageCompanion(
      itemId: itemId ?? this.itemId,
      recallCount: recallCount ?? this.recallCount,
      injectCount: injectCount ?? this.injectCount,
      lastUsedAt: lastUsedAt ?? this.lastUsedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (itemId.present) {
      map['item_id'] = Variable<String>(itemId.value);
    }
    if (recallCount.present) {
      map['recall_count'] = Variable<int>(recallCount.value);
    }
    if (injectCount.present) {
      map['inject_count'] = Variable<int>(injectCount.value);
    }
    if (lastUsedAt.present) {
      map['last_used_at'] = Variable<int>(lastUsedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('MemoryUsageCompanion(')
          ..write('itemId: $itemId, ')
          ..write('recallCount: $recallCount, ')
          ..write('injectCount: $injectCount, ')
          ..write('lastUsedAt: $lastUsedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $AppSettingsTable extends AppSettings
    with TableInfo<$AppSettingsTable, AppSettingRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AppSettingsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  @override
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
    'key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _valueMeta = const VerificationMeta('value');
  @override
  late final GeneratedColumn<String> value = GeneratedColumn<String>(
    'value',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<int> updatedAt = GeneratedColumn<int>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [key, value, updatedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'app_settings';
  @override
  VerificationContext validateIntegrity(
    Insertable<AppSettingRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('key')) {
      context.handle(
        _keyMeta,
        key.isAcceptableOrUnknown(data['key']!, _keyMeta),
      );
    } else if (isInserting) {
      context.missing(_keyMeta);
    }
    if (data.containsKey('value')) {
      context.handle(
        _valueMeta,
        value.isAcceptableOrUnknown(data['value']!, _valueMeta),
      );
    } else if (isInserting) {
      context.missing(_valueMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {key};
  @override
  AppSettingRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AppSettingRow(
      key: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}key'],
      )!,
      value: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}value'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $AppSettingsTable createAlias(String alias) {
    return $AppSettingsTable(attachedDatabase, alias);
  }
}

class AppSettingRow extends DataClass implements Insertable<AppSettingRow> {
  final String key;
  final String value;
  final int updatedAt;
  const AppSettingRow({
    required this.key,
    required this.value,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['key'] = Variable<String>(key);
    map['value'] = Variable<String>(value);
    map['updated_at'] = Variable<int>(updatedAt);
    return map;
  }

  AppSettingsCompanion toCompanion(bool nullToAbsent) {
    return AppSettingsCompanion(
      key: Value(key),
      value: Value(value),
      updatedAt: Value(updatedAt),
    );
  }

  factory AppSettingRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AppSettingRow(
      key: serializer.fromJson<String>(json['key']),
      value: serializer.fromJson<String>(json['value']),
      updatedAt: serializer.fromJson<int>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'key': serializer.toJson<String>(key),
      'value': serializer.toJson<String>(value),
      'updatedAt': serializer.toJson<int>(updatedAt),
    };
  }

  AppSettingRow copyWith({String? key, String? value, int? updatedAt}) =>
      AppSettingRow(
        key: key ?? this.key,
        value: value ?? this.value,
        updatedAt: updatedAt ?? this.updatedAt,
      );
  AppSettingRow copyWithCompanion(AppSettingsCompanion data) {
    return AppSettingRow(
      key: data.key.present ? data.key.value : this.key,
      value: data.value.present ? data.value.value : this.value,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AppSettingRow(')
          ..write('key: $key, ')
          ..write('value: $value, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(key, value, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AppSettingRow &&
          other.key == this.key &&
          other.value == this.value &&
          other.updatedAt == this.updatedAt);
}

class AppSettingsCompanion extends UpdateCompanion<AppSettingRow> {
  final Value<String> key;
  final Value<String> value;
  final Value<int> updatedAt;
  final Value<int> rowid;
  const AppSettingsCompanion({
    this.key = const Value.absent(),
    this.value = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  AppSettingsCompanion.insert({
    required String key,
    required String value,
    required int updatedAt,
    this.rowid = const Value.absent(),
  }) : key = Value(key),
       value = Value(value),
       updatedAt = Value(updatedAt);
  static Insertable<AppSettingRow> custom({
    Expression<String>? key,
    Expression<String>? value,
    Expression<int>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (key != null) 'key': key,
      if (value != null) 'value': value,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  AppSettingsCompanion copyWith({
    Value<String>? key,
    Value<String>? value,
    Value<int>? updatedAt,
    Value<int>? rowid,
  }) {
    return AppSettingsCompanion(
      key: key ?? this.key,
      value: value ?? this.value,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (key.present) {
      map['key'] = Variable<String>(key.value);
    }
    if (value.present) {
      map['value'] = Variable<String>(value.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AppSettingsCompanion(')
          ..write('key: $key, ')
          ..write('value: $value, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SearchUsageTable extends SearchUsage
    with TableInfo<$SearchUsageTable, SearchUsageData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SearchUsageTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _monthMeta = const VerificationMeta('month');
  @override
  late final GeneratedColumn<String> month = GeneratedColumn<String>(
    'month',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _creditsMeta = const VerificationMeta(
    'credits',
  );
  @override
  late final GeneratedColumn<int> credits = GeneratedColumn<int>(
    'credits',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  @override
  List<GeneratedColumn> get $columns => [month, credits];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'search_usage';
  @override
  VerificationContext validateIntegrity(
    Insertable<SearchUsageData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('month')) {
      context.handle(
        _monthMeta,
        month.isAcceptableOrUnknown(data['month']!, _monthMeta),
      );
    } else if (isInserting) {
      context.missing(_monthMeta);
    }
    if (data.containsKey('credits')) {
      context.handle(
        _creditsMeta,
        credits.isAcceptableOrUnknown(data['credits']!, _creditsMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {month};
  @override
  SearchUsageData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SearchUsageData(
      month: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}month'],
      )!,
      credits: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}credits'],
      )!,
    );
  }

  @override
  $SearchUsageTable createAlias(String alias) {
    return $SearchUsageTable(attachedDatabase, alias);
  }
}

class SearchUsageData extends DataClass implements Insertable<SearchUsageData> {
  final String month;
  final int credits;
  const SearchUsageData({required this.month, required this.credits});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['month'] = Variable<String>(month);
    map['credits'] = Variable<int>(credits);
    return map;
  }

  SearchUsageCompanion toCompanion(bool nullToAbsent) {
    return SearchUsageCompanion(month: Value(month), credits: Value(credits));
  }

  factory SearchUsageData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SearchUsageData(
      month: serializer.fromJson<String>(json['month']),
      credits: serializer.fromJson<int>(json['credits']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'month': serializer.toJson<String>(month),
      'credits': serializer.toJson<int>(credits),
    };
  }

  SearchUsageData copyWith({String? month, int? credits}) => SearchUsageData(
    month: month ?? this.month,
    credits: credits ?? this.credits,
  );
  SearchUsageData copyWithCompanion(SearchUsageCompanion data) {
    return SearchUsageData(
      month: data.month.present ? data.month.value : this.month,
      credits: data.credits.present ? data.credits.value : this.credits,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SearchUsageData(')
          ..write('month: $month, ')
          ..write('credits: $credits')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(month, credits);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SearchUsageData &&
          other.month == this.month &&
          other.credits == this.credits);
}

class SearchUsageCompanion extends UpdateCompanion<SearchUsageData> {
  final Value<String> month;
  final Value<int> credits;
  final Value<int> rowid;
  const SearchUsageCompanion({
    this.month = const Value.absent(),
    this.credits = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SearchUsageCompanion.insert({
    required String month,
    this.credits = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : month = Value(month);
  static Insertable<SearchUsageData> custom({
    Expression<String>? month,
    Expression<int>? credits,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (month != null) 'month': month,
      if (credits != null) 'credits': credits,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SearchUsageCompanion copyWith({
    Value<String>? month,
    Value<int>? credits,
    Value<int>? rowid,
  }) {
    return SearchUsageCompanion(
      month: month ?? this.month,
      credits: credits ?? this.credits,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (month.present) {
      map['month'] = Variable<String>(month.value);
    }
    if (credits.present) {
      map['credits'] = Variable<int>(credits.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SearchUsageCompanion(')
          ..write('month: $month, ')
          ..write('credits: $credits, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $GoalsTable goals = $GoalsTable(this);
  late final $GoalNodesTable goalNodes = $GoalNodesTable(this);
  late final $MissionsTable missions = $MissionsTable(this);
  late final Trigger missionsOwnershipInsert = Trigger(
    'CREATE TRIGGER missions_ownership_insert BEFORE INSERT ON missions WHEN NEW.goal_node_id IS NOT NULL AND NOT EXISTS (SELECT 1 FROM goal_nodes WHERE id = NEW.goal_node_id AND goal_id = NEW.goal_id) BEGIN SELECT RAISE (ABORT, \'mission node must belong to goal\');END',
    'missions_ownership_insert',
  );
  late final Trigger missionsOwnershipUpdate = Trigger(
    'CREATE TRIGGER missions_ownership_update BEFORE UPDATE OF goal_id, goal_node_id ON missions WHEN NEW.goal_node_id IS NOT NULL AND NOT EXISTS (SELECT 1 FROM goal_nodes WHERE id = NEW.goal_node_id AND goal_id = NEW.goal_id) BEGIN SELECT RAISE (ABORT, \'mission node must belong to goal\');END',
    'missions_ownership_update',
  );
  late final Index goalNodesSiblings = Index(
    'goal_nodes_siblings',
    'CREATE INDEX goal_nodes_siblings ON goal_nodes (goal_id, parent_node_id, order_index)',
  );
  late final Index missionsGoalNode = Index(
    'missions_goal_node',
    'CREATE INDEX missions_goal_node ON missions (goal_id, goal_node_id)',
  );
  late final $MissionScheduleRevisionsTable missionScheduleRevisions =
      $MissionScheduleRevisionsTable(this);
  late final $ExecutionPlansTable executionPlans = $ExecutionPlansTable(this);
  late final $ExecutionEventsTable executionEvents = $ExecutionEventsTable(
    this,
  );
  late final $FailureRecordsTable failureRecords = $FailureRecordsTable(this);
  late final $EvidenceRecordsTable evidenceRecords = $EvidenceRecordsTable(
    this,
  );
  late final $ImportReceiptsTable importReceipts = $ImportReceiptsTable(this);
  late final $AssistantSessionsTable assistantSessions =
      $AssistantSessionsTable(this);
  late final $AssistantSessionRecordsTable assistantSessionRecords =
      $AssistantSessionRecordsTable(this);
  late final $OperationReceiptsTable operationReceipts =
      $OperationReceiptsTable(this);
  late final $RecordsTable records = $RecordsTable(this);
  late final $UserExecutionReportsTable userExecutionReports =
      $UserExecutionReportsTable(this);
  late final $AnalysisJobsTable analysisJobs = $AnalysisJobsTable(this);
  late final $AnalysisVersionsTable analysisVersions = $AnalysisVersionsTable(
    this,
  );
  late final $MemoryTopicsTable memoryTopics = $MemoryTopicsTable(this);
  late final $MemoryItemsTable memoryItems = $MemoryItemsTable(this);
  late final $MemoryTopicAliasesTable memoryTopicAliases =
      $MemoryTopicAliasesTable(this);
  late final $MemoryVersionsTable memoryVersions = $MemoryVersionsTable(this);
  late final $MemoryEpisodesTable memoryEpisodes = $MemoryEpisodesTable(this);
  late final $MemoryProceduresTable memoryProcedures = $MemoryProceduresTable(
    this,
  );
  late final $MemoryUsageTable memoryUsage = $MemoryUsageTable(this);
  late final $AppSettingsTable appSettings = $AppSettingsTable(this);
  late final $SearchUsageTable searchUsage = $SearchUsageTable(this);
  late final Index missionScheduleFixed = Index(
    'mission_schedule_fixed',
    'CREATE INDEX mission_schedule_fixed ON mission_schedule_revisions (time_policy, fixed_start_at, mission_id, revision_number)',
  );
  late final Index executionEventsOneStart = Index(
    'execution_events_one_start',
    'CREATE UNIQUE INDEX execution_events_one_start ON execution_events (mission_id) WHERE type = \'START\'',
  );
  late final Index executionEventsOneEnd = Index(
    'execution_events_one_end',
    'CREATE UNIQUE INDEX execution_events_one_end ON execution_events (mission_id) WHERE type = \'END\'',
  );
  late final Index evidenceRecordsMission = Index(
    'evidence_records_mission',
    'CREATE INDEX evidence_records_mission ON evidence_records (mission_id, submitted_at, id)',
  );
  late final Index importReceiptsContent = Index(
    'import_receipts_content',
    'CREATE INDEX import_receipts_content ON import_receipts (schema_name, content_sha256)',
  );
  late final Index assistantSessionsUpdated = Index(
    'assistant_sessions_updated',
    'CREATE INDEX assistant_sessions_updated ON assistant_sessions (updated_at, id)',
  );
  late final Index operationReceiptsEntity = Index(
    'operation_receipts_entity',
    'CREATE INDEX operation_receipts_entity ON operation_receipts (kind, entity_id)',
  );
  late final Index recordsScope = Index(
    'records_scope',
    'CREATE INDEX records_scope ON records (goal_id, goal_node_id, occurred_at)',
  );
  late final Index recordsDay = Index(
    'records_day',
    'CREATE INDEX records_day ON records (occurred_at, id)',
  );
  late final Index userReportsMission = Index(
    'user_reports_mission',
    'CREATE INDEX user_reports_mission ON user_execution_reports (mission_id, reported_at)',
  );
  late final Index analysisJobsDue = Index(
    'analysis_jobs_due',
    'CREATE INDEX analysis_jobs_due ON analysis_jobs (status, available_at, scope)',
  );
  late final Index analysisVersionsTarget = Index(
    'analysis_versions_target',
    'CREATE INDEX analysis_versions_target ON analysis_versions (scope, target_id, created_at DESC)',
  );
  late final Index memoryItemsLayer = Index(
    'memory_items_layer',
    'CREATE INDEX memory_items_layer ON memory_items (layer, forgotten, updated_at)',
  );
  late final Index memoryItemsTopic = Index(
    'memory_items_topic',
    'CREATE INDEX memory_items_topic ON memory_items (topic_id)',
  );
  late final Index memoryItemsGoal = Index(
    'memory_items_goal',
    'CREATE INDEX memory_items_goal ON memory_items (goal_id)',
  );
  late final Index memoryItemsContent = Index(
    'memory_items_content',
    'CREATE INDEX memory_items_content ON memory_items (forgotten, updated_at)',
  );
  late final Index memoryTopicsScope = Index(
    'memory_topics_scope',
    'CREATE INDEX memory_topics_scope ON memory_topics (goal_id, kind)',
  );
  late final Index memoryTopicAliasesNormalized = Index(
    'memory_topic_aliases_normalized',
    'CREATE UNIQUE INDEX memory_topic_aliases_normalized ON memory_topic_aliases (normalized_alias, topic_id)',
  );
  late final Index memoryVersionsItem = Index(
    'memory_versions_item',
    'CREATE INDEX memory_versions_item ON memory_versions (item_id, created_at)',
  );
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    goals,
    goalNodes,
    missions,
    missionsOwnershipInsert,
    missionsOwnershipUpdate,
    goalNodesSiblings,
    missionsGoalNode,
    missionScheduleRevisions,
    executionPlans,
    executionEvents,
    failureRecords,
    evidenceRecords,
    importReceipts,
    assistantSessions,
    assistantSessionRecords,
    operationReceipts,
    records,
    userExecutionReports,
    analysisJobs,
    analysisVersions,
    memoryTopics,
    memoryItems,
    memoryTopicAliases,
    memoryVersions,
    memoryEpisodes,
    memoryProcedures,
    memoryUsage,
    appSettings,
    searchUsage,
    missionScheduleFixed,
    executionEventsOneStart,
    executionEventsOneEnd,
    evidenceRecordsMission,
    importReceiptsContent,
    assistantSessionsUpdated,
    operationReceiptsEntity,
    recordsScope,
    recordsDay,
    userReportsMission,
    analysisJobsDue,
    analysisVersionsTarget,
    memoryItemsLayer,
    memoryItemsTopic,
    memoryItemsGoal,
    memoryItemsContent,
    memoryTopicsScope,
    memoryTopicAliasesNormalized,
    memoryVersionsItem,
  ];
  @override
  StreamQueryUpdateRules get streamUpdateRules => const StreamQueryUpdateRules([
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'missions',
        limitUpdateKind: UpdateKind.insert,
      ),
      result: [],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'missions',
        limitUpdateKind: UpdateKind.update,
      ),
      result: [],
    ),
  ]);
}

typedef $$GoalsTableCreateCompanionBuilder =
    GoalsCompanion Function({
      required String id,
      required String title,
      Value<String?> description,
      Value<String?> why,
      Value<int?> desireLevel,
      Value<String> status,
      required int createdAt,
      required int updatedAt,
      Value<int> rowid,
    });
typedef $$GoalsTableUpdateCompanionBuilder =
    GoalsCompanion Function({
      Value<String> id,
      Value<String> title,
      Value<String?> description,
      Value<String?> why,
      Value<int?> desireLevel,
      Value<String> status,
      Value<int> createdAt,
      Value<int> updatedAt,
      Value<int> rowid,
    });

final class $$GoalsTableReferences
    extends BaseReferences<_$AppDatabase, $GoalsTable, GoalRow> {
  $$GoalsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$GoalNodesTable, List<GoalNodeRow>>
  _goalNodesRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.goalNodes,
    aliasName: 'goals__id__goal_nodes__goal_id',
  );

  $$GoalNodesTableProcessedTableManager get goalNodesRefs {
    final manager = $$GoalNodesTableTableManager(
      $_db,
      $_db.goalNodes,
    ).filter((f) => f.goalId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_goalNodesRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$MissionsTable, List<MissionRow>>
  _missionsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.missions,
    aliasName: 'goals__id__missions__goal_id',
  );

  $$MissionsTableProcessedTableManager get missionsRefs {
    final manager = $$MissionsTableTableManager(
      $_db,
      $_db.missions,
    ).filter((f) => f.goalId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_missionsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$ImportReceiptsTable, List<ImportReceipt>>
  _importReceiptsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.importReceipts,
    aliasName: 'goals__id__import_receipts__goal_id',
  );

  $$ImportReceiptsTableProcessedTableManager get importReceiptsRefs {
    final manager = $$ImportReceiptsTableTableManager(
      $_db,
      $_db.importReceipts,
    ).filter((f) => f.goalId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_importReceiptsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$RecordsTable, List<RecordRow>> _recordsRefsTable(
    _$AppDatabase db,
  ) => MultiTypedResultKey.fromTable(
    db.records,
    aliasName: 'goals__id__records__goal_id',
  );

  $$RecordsTableProcessedTableManager get recordsRefs {
    final manager = $$RecordsTableTableManager(
      $_db,
      $_db.records,
    ).filter((f) => f.goalId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_recordsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$MemoryTopicsTable, List<MemoryTopicRow>>
  _memoryTopicsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.memoryTopics,
    aliasName: 'goals__id__memory_topics__goal_id',
  );

  $$MemoryTopicsTableProcessedTableManager get memoryTopicsRefs {
    final manager = $$MemoryTopicsTableTableManager(
      $_db,
      $_db.memoryTopics,
    ).filter((f) => f.goalId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_memoryTopicsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$MemoryItemsTable, List<MemoryItemRow>>
  _memoryItemsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.memoryItems,
    aliasName: 'goals__id__memory_items__goal_id',
  );

  $$MemoryItemsTableProcessedTableManager get memoryItemsRefs {
    final manager = $$MemoryItemsTableTableManager(
      $_db,
      $_db.memoryItems,
    ).filter((f) => f.goalId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_memoryItemsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$GoalsTableFilterComposer extends Composer<_$AppDatabase, $GoalsTable> {
  $$GoalsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get why => $composableBuilder(
    column: $table.why,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get desireLevel => $composableBuilder(
    column: $table.desireLevel,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> goalNodesRefs(
    Expression<bool> Function($$GoalNodesTableFilterComposer f) f,
  ) {
    final $$GoalNodesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.goalNodes,
      getReferencedColumn: (t) => t.goalId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$GoalNodesTableFilterComposer(
            $db: $db,
            $table: $db.goalNodes,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> missionsRefs(
    Expression<bool> Function($$MissionsTableFilterComposer f) f,
  ) {
    final $$MissionsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.missions,
      getReferencedColumn: (t) => t.goalId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MissionsTableFilterComposer(
            $db: $db,
            $table: $db.missions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> importReceiptsRefs(
    Expression<bool> Function($$ImportReceiptsTableFilterComposer f) f,
  ) {
    final $$ImportReceiptsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.importReceipts,
      getReferencedColumn: (t) => t.goalId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ImportReceiptsTableFilterComposer(
            $db: $db,
            $table: $db.importReceipts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> recordsRefs(
    Expression<bool> Function($$RecordsTableFilterComposer f) f,
  ) {
    final $$RecordsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.records,
      getReferencedColumn: (t) => t.goalId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RecordsTableFilterComposer(
            $db: $db,
            $table: $db.records,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> memoryTopicsRefs(
    Expression<bool> Function($$MemoryTopicsTableFilterComposer f) f,
  ) {
    final $$MemoryTopicsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.memoryTopics,
      getReferencedColumn: (t) => t.goalId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MemoryTopicsTableFilterComposer(
            $db: $db,
            $table: $db.memoryTopics,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> memoryItemsRefs(
    Expression<bool> Function($$MemoryItemsTableFilterComposer f) f,
  ) {
    final $$MemoryItemsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.memoryItems,
      getReferencedColumn: (t) => t.goalId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MemoryItemsTableFilterComposer(
            $db: $db,
            $table: $db.memoryItems,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$GoalsTableOrderingComposer
    extends Composer<_$AppDatabase, $GoalsTable> {
  $$GoalsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get why => $composableBuilder(
    column: $table.why,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get desireLevel => $composableBuilder(
    column: $table.desireLevel,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$GoalsTableAnnotationComposer
    extends Composer<_$AppDatabase, $GoalsTable> {
  $$GoalsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => column,
  );

  GeneratedColumn<String> get why =>
      $composableBuilder(column: $table.why, builder: (column) => column);

  GeneratedColumn<int> get desireLevel => $composableBuilder(
    column: $table.desireLevel,
    builder: (column) => column,
  );

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  Expression<T> goalNodesRefs<T extends Object>(
    Expression<T> Function($$GoalNodesTableAnnotationComposer a) f,
  ) {
    final $$GoalNodesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.goalNodes,
      getReferencedColumn: (t) => t.goalId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$GoalNodesTableAnnotationComposer(
            $db: $db,
            $table: $db.goalNodes,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> missionsRefs<T extends Object>(
    Expression<T> Function($$MissionsTableAnnotationComposer a) f,
  ) {
    final $$MissionsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.missions,
      getReferencedColumn: (t) => t.goalId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MissionsTableAnnotationComposer(
            $db: $db,
            $table: $db.missions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> importReceiptsRefs<T extends Object>(
    Expression<T> Function($$ImportReceiptsTableAnnotationComposer a) f,
  ) {
    final $$ImportReceiptsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.importReceipts,
      getReferencedColumn: (t) => t.goalId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ImportReceiptsTableAnnotationComposer(
            $db: $db,
            $table: $db.importReceipts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> recordsRefs<T extends Object>(
    Expression<T> Function($$RecordsTableAnnotationComposer a) f,
  ) {
    final $$RecordsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.records,
      getReferencedColumn: (t) => t.goalId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RecordsTableAnnotationComposer(
            $db: $db,
            $table: $db.records,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> memoryTopicsRefs<T extends Object>(
    Expression<T> Function($$MemoryTopicsTableAnnotationComposer a) f,
  ) {
    final $$MemoryTopicsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.memoryTopics,
      getReferencedColumn: (t) => t.goalId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MemoryTopicsTableAnnotationComposer(
            $db: $db,
            $table: $db.memoryTopics,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> memoryItemsRefs<T extends Object>(
    Expression<T> Function($$MemoryItemsTableAnnotationComposer a) f,
  ) {
    final $$MemoryItemsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.memoryItems,
      getReferencedColumn: (t) => t.goalId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MemoryItemsTableAnnotationComposer(
            $db: $db,
            $table: $db.memoryItems,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$GoalsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $GoalsTable,
          GoalRow,
          $$GoalsTableFilterComposer,
          $$GoalsTableOrderingComposer,
          $$GoalsTableAnnotationComposer,
          $$GoalsTableCreateCompanionBuilder,
          $$GoalsTableUpdateCompanionBuilder,
          (GoalRow, $$GoalsTableReferences),
          GoalRow,
          PrefetchHooks Function({
            bool goalNodesRefs,
            bool missionsRefs,
            bool importReceiptsRefs,
            bool recordsRefs,
            bool memoryTopicsRefs,
            bool memoryItemsRefs,
          })
        > {
  $$GoalsTableTableManager(_$AppDatabase db, $GoalsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$GoalsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$GoalsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$GoalsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String?> description = const Value.absent(),
                Value<String?> why = const Value.absent(),
                Value<int?> desireLevel = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<int> createdAt = const Value.absent(),
                Value<int> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => GoalsCompanion(
                id: id,
                title: title,
                description: description,
                why: why,
                desireLevel: desireLevel,
                status: status,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String title,
                Value<String?> description = const Value.absent(),
                Value<String?> why = const Value.absent(),
                Value<int?> desireLevel = const Value.absent(),
                Value<String> status = const Value.absent(),
                required int createdAt,
                required int updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => GoalsCompanion.insert(
                id: id,
                title: title,
                description: description,
                why: why,
                desireLevel: desireLevel,
                status: status,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) =>
                    (e.readTable(table), $$GoalsTableReferences(db, table, e)),
              )
              .toList(),
          prefetchHooksCallback:
              ({
                goalNodesRefs = false,
                missionsRefs = false,
                importReceiptsRefs = false,
                recordsRefs = false,
                memoryTopicsRefs = false,
                memoryItemsRefs = false,
              }) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (goalNodesRefs) db.goalNodes,
                    if (missionsRefs) db.missions,
                    if (importReceiptsRefs) db.importReceipts,
                    if (recordsRefs) db.records,
                    if (memoryTopicsRefs) db.memoryTopics,
                    if (memoryItemsRefs) db.memoryItems,
                  ],
                  addJoins: null,
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (goalNodesRefs)
                        await $_getPrefetchedData<
                          GoalRow,
                          $GoalsTable,
                          GoalNodeRow
                        >(
                          currentTable: table,
                          referencedTable: $$GoalsTableReferences
                              ._goalNodesRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$GoalsTableReferences(
                                db,
                                table,
                                p0,
                              ).goalNodesRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.goalId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (missionsRefs)
                        await $_getPrefetchedData<
                          GoalRow,
                          $GoalsTable,
                          MissionRow
                        >(
                          currentTable: table,
                          referencedTable: $$GoalsTableReferences
                              ._missionsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$GoalsTableReferences(
                                db,
                                table,
                                p0,
                              ).missionsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.goalId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (importReceiptsRefs)
                        await $_getPrefetchedData<
                          GoalRow,
                          $GoalsTable,
                          ImportReceipt
                        >(
                          currentTable: table,
                          referencedTable: $$GoalsTableReferences
                              ._importReceiptsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$GoalsTableReferences(
                                db,
                                table,
                                p0,
                              ).importReceiptsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.goalId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (recordsRefs)
                        await $_getPrefetchedData<
                          GoalRow,
                          $GoalsTable,
                          RecordRow
                        >(
                          currentTable: table,
                          referencedTable: $$GoalsTableReferences
                              ._recordsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$GoalsTableReferences(db, table, p0).recordsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.goalId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (memoryTopicsRefs)
                        await $_getPrefetchedData<
                          GoalRow,
                          $GoalsTable,
                          MemoryTopicRow
                        >(
                          currentTable: table,
                          referencedTable: $$GoalsTableReferences
                              ._memoryTopicsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$GoalsTableReferences(
                                db,
                                table,
                                p0,
                              ).memoryTopicsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.goalId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (memoryItemsRefs)
                        await $_getPrefetchedData<
                          GoalRow,
                          $GoalsTable,
                          MemoryItemRow
                        >(
                          currentTable: table,
                          referencedTable: $$GoalsTableReferences
                              ._memoryItemsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$GoalsTableReferences(
                                db,
                                table,
                                p0,
                              ).memoryItemsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.goalId == item.id,
                              ),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$GoalsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $GoalsTable,
      GoalRow,
      $$GoalsTableFilterComposer,
      $$GoalsTableOrderingComposer,
      $$GoalsTableAnnotationComposer,
      $$GoalsTableCreateCompanionBuilder,
      $$GoalsTableUpdateCompanionBuilder,
      (GoalRow, $$GoalsTableReferences),
      GoalRow,
      PrefetchHooks Function({
        bool goalNodesRefs,
        bool missionsRefs,
        bool importReceiptsRefs,
        bool recordsRefs,
        bool memoryTopicsRefs,
        bool memoryItemsRefs,
      })
    >;
typedef $$GoalNodesTableCreateCompanionBuilder =
    GoalNodesCompanion Function({
      required String id,
      required String goalId,
      Value<String?> parentNodeId,
      required String title,
      Value<String?> description,
      required int orderIndex,
      Value<int?> archivedAt,
      required int createdAt,
      required int updatedAt,
      Value<int> rowid,
    });
typedef $$GoalNodesTableUpdateCompanionBuilder =
    GoalNodesCompanion Function({
      Value<String> id,
      Value<String> goalId,
      Value<String?> parentNodeId,
      Value<String> title,
      Value<String?> description,
      Value<int> orderIndex,
      Value<int?> archivedAt,
      Value<int> createdAt,
      Value<int> updatedAt,
      Value<int> rowid,
    });

final class $$GoalNodesTableReferences
    extends BaseReferences<_$AppDatabase, $GoalNodesTable, GoalNodeRow> {
  $$GoalNodesTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $GoalsTable _goalIdTable(_$AppDatabase db) =>
      db.goals.createAlias('goal_nodes__goal_id__goals__id');

  $$GoalsTableProcessedTableManager get goalId {
    final $_column = $_itemColumn<String>('goal_id')!;

    final manager = $$GoalsTableTableManager(
      $_db,
      $_db.goals,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_goalIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static MultiTypedResultKey<$MissionsTable, List<MissionRow>>
  _missionsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.missions,
    aliasName: 'goal_nodes__id__missions__goal_node_id',
  );

  $$MissionsTableProcessedTableManager get missionsRefs {
    final manager = $$MissionsTableTableManager(
      $_db,
      $_db.missions,
    ).filter((f) => f.goalNodeId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_missionsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$RecordsTable, List<RecordRow>> _recordsRefsTable(
    _$AppDatabase db,
  ) => MultiTypedResultKey.fromTable(
    db.records,
    aliasName: 'goal_nodes__id__records__goal_node_id',
  );

  $$RecordsTableProcessedTableManager get recordsRefs {
    final manager = $$RecordsTableTableManager(
      $_db,
      $_db.records,
    ).filter((f) => f.goalNodeId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_recordsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$GoalNodesTableFilterComposer
    extends Composer<_$AppDatabase, $GoalNodesTable> {
  $$GoalNodesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get parentNodeId => $composableBuilder(
    column: $table.parentNodeId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get orderIndex => $composableBuilder(
    column: $table.orderIndex,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get archivedAt => $composableBuilder(
    column: $table.archivedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  $$GoalsTableFilterComposer get goalId {
    final $$GoalsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.goalId,
      referencedTable: $db.goals,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$GoalsTableFilterComposer(
            $db: $db,
            $table: $db.goals,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<bool> missionsRefs(
    Expression<bool> Function($$MissionsTableFilterComposer f) f,
  ) {
    final $$MissionsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.missions,
      getReferencedColumn: (t) => t.goalNodeId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MissionsTableFilterComposer(
            $db: $db,
            $table: $db.missions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> recordsRefs(
    Expression<bool> Function($$RecordsTableFilterComposer f) f,
  ) {
    final $$RecordsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.records,
      getReferencedColumn: (t) => t.goalNodeId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RecordsTableFilterComposer(
            $db: $db,
            $table: $db.records,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$GoalNodesTableOrderingComposer
    extends Composer<_$AppDatabase, $GoalNodesTable> {
  $$GoalNodesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get parentNodeId => $composableBuilder(
    column: $table.parentNodeId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get orderIndex => $composableBuilder(
    column: $table.orderIndex,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get archivedAt => $composableBuilder(
    column: $table.archivedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$GoalsTableOrderingComposer get goalId {
    final $$GoalsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.goalId,
      referencedTable: $db.goals,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$GoalsTableOrderingComposer(
            $db: $db,
            $table: $db.goals,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$GoalNodesTableAnnotationComposer
    extends Composer<_$AppDatabase, $GoalNodesTable> {
  $$GoalNodesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get parentNodeId => $composableBuilder(
    column: $table.parentNodeId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => column,
  );

  GeneratedColumn<int> get orderIndex => $composableBuilder(
    column: $table.orderIndex,
    builder: (column) => column,
  );

  GeneratedColumn<int> get archivedAt => $composableBuilder(
    column: $table.archivedAt,
    builder: (column) => column,
  );

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  $$GoalsTableAnnotationComposer get goalId {
    final $$GoalsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.goalId,
      referencedTable: $db.goals,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$GoalsTableAnnotationComposer(
            $db: $db,
            $table: $db.goals,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<T> missionsRefs<T extends Object>(
    Expression<T> Function($$MissionsTableAnnotationComposer a) f,
  ) {
    final $$MissionsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.missions,
      getReferencedColumn: (t) => t.goalNodeId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MissionsTableAnnotationComposer(
            $db: $db,
            $table: $db.missions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> recordsRefs<T extends Object>(
    Expression<T> Function($$RecordsTableAnnotationComposer a) f,
  ) {
    final $$RecordsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.records,
      getReferencedColumn: (t) => t.goalNodeId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RecordsTableAnnotationComposer(
            $db: $db,
            $table: $db.records,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$GoalNodesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $GoalNodesTable,
          GoalNodeRow,
          $$GoalNodesTableFilterComposer,
          $$GoalNodesTableOrderingComposer,
          $$GoalNodesTableAnnotationComposer,
          $$GoalNodesTableCreateCompanionBuilder,
          $$GoalNodesTableUpdateCompanionBuilder,
          (GoalNodeRow, $$GoalNodesTableReferences),
          GoalNodeRow,
          PrefetchHooks Function({
            bool goalId,
            bool missionsRefs,
            bool recordsRefs,
          })
        > {
  $$GoalNodesTableTableManager(_$AppDatabase db, $GoalNodesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$GoalNodesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$GoalNodesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$GoalNodesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> goalId = const Value.absent(),
                Value<String?> parentNodeId = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String?> description = const Value.absent(),
                Value<int> orderIndex = const Value.absent(),
                Value<int?> archivedAt = const Value.absent(),
                Value<int> createdAt = const Value.absent(),
                Value<int> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => GoalNodesCompanion(
                id: id,
                goalId: goalId,
                parentNodeId: parentNodeId,
                title: title,
                description: description,
                orderIndex: orderIndex,
                archivedAt: archivedAt,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String goalId,
                Value<String?> parentNodeId = const Value.absent(),
                required String title,
                Value<String?> description = const Value.absent(),
                required int orderIndex,
                Value<int?> archivedAt = const Value.absent(),
                required int createdAt,
                required int updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => GoalNodesCompanion.insert(
                id: id,
                goalId: goalId,
                parentNodeId: parentNodeId,
                title: title,
                description: description,
                orderIndex: orderIndex,
                archivedAt: archivedAt,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$GoalNodesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({goalId = false, missionsRefs = false, recordsRefs = false}) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (missionsRefs) db.missions,
                    if (recordsRefs) db.records,
                  ],
                  addJoins:
                      <
                        T extends TableManagerState<
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic
                        >
                      >(state) {
                        if (goalId) {
                          state =
                              state.withJoin(
                                    currentTable: table,
                                    currentColumn: table.goalId,
                                    referencedTable: $$GoalNodesTableReferences
                                        ._goalIdTable(db),
                                    referencedColumn: $$GoalNodesTableReferences
                                        ._goalIdTable(db)
                                        .id,
                                  )
                                  as T;
                        }

                        return state;
                      },
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (missionsRefs)
                        await $_getPrefetchedData<
                          GoalNodeRow,
                          $GoalNodesTable,
                          MissionRow
                        >(
                          currentTable: table,
                          referencedTable: $$GoalNodesTableReferences
                              ._missionsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$GoalNodesTableReferences(
                                db,
                                table,
                                p0,
                              ).missionsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.goalNodeId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (recordsRefs)
                        await $_getPrefetchedData<
                          GoalNodeRow,
                          $GoalNodesTable,
                          RecordRow
                        >(
                          currentTable: table,
                          referencedTable: $$GoalNodesTableReferences
                              ._recordsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$GoalNodesTableReferences(
                                db,
                                table,
                                p0,
                              ).recordsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.goalNodeId == item.id,
                              ),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$GoalNodesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $GoalNodesTable,
      GoalNodeRow,
      $$GoalNodesTableFilterComposer,
      $$GoalNodesTableOrderingComposer,
      $$GoalNodesTableAnnotationComposer,
      $$GoalNodesTableCreateCompanionBuilder,
      $$GoalNodesTableUpdateCompanionBuilder,
      (GoalNodeRow, $$GoalNodesTableReferences),
      GoalNodeRow,
      PrefetchHooks Function({bool goalId, bool missionsRefs, bool recordsRefs})
    >;
typedef $$MissionsTableCreateCompanionBuilder =
    MissionsCompanion Function({
      Value<String?> goalId,
      Value<String?> goalNodeId,
      required String id,
      required String title,
      Value<String?> description,
      Value<String?> why,
      Value<String> verificationPolicy,
      required int createdAt,
      required int updatedAt,
      Value<int?> cancelledAt,
      Value<int?> evidenceWaivedAt,
      Value<String?> sourceMissionId,
      Value<String?> relationType,
      Value<int> rowid,
    });
typedef $$MissionsTableUpdateCompanionBuilder =
    MissionsCompanion Function({
      Value<String?> goalId,
      Value<String?> goalNodeId,
      Value<String> id,
      Value<String> title,
      Value<String?> description,
      Value<String?> why,
      Value<String> verificationPolicy,
      Value<int> createdAt,
      Value<int> updatedAt,
      Value<int?> cancelledAt,
      Value<int?> evidenceWaivedAt,
      Value<String?> sourceMissionId,
      Value<String?> relationType,
      Value<int> rowid,
    });

final class $$MissionsTableReferences
    extends BaseReferences<_$AppDatabase, $MissionsTable, MissionRow> {
  $$MissionsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $GoalsTable _goalIdTable(_$AppDatabase db) =>
      db.goals.createAlias('missions__goal_id__goals__id');

  $$GoalsTableProcessedTableManager? get goalId {
    final $_column = $_itemColumn<String>('goal_id');
    if ($_column == null) return null;
    final manager = $$GoalsTableTableManager(
      $_db,
      $_db.goals,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_goalIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $GoalNodesTable _goalNodeIdTable(_$AppDatabase db) =>
      db.goalNodes.createAlias('missions__goal_node_id__goal_nodes__id');

  $$GoalNodesTableProcessedTableManager? get goalNodeId {
    final $_column = $_itemColumn<String>('goal_node_id');
    if ($_column == null) return null;
    final manager = $$GoalNodesTableTableManager(
      $_db,
      $_db.goalNodes,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_goalNodeIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $MissionsTable _sourceMissionIdTable(_$AppDatabase db) =>
      db.missions.createAlias('missions__source_mission_id__missions__id');

  $$MissionsTableProcessedTableManager? get sourceMissionId {
    final $_column = $_itemColumn<String>('source_mission_id');
    if ($_column == null) return null;
    final manager = $$MissionsTableTableManager(
      $_db,
      $_db.missions,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_sourceMissionIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static MultiTypedResultKey<
    $MissionScheduleRevisionsTable,
    List<MissionScheduleRevisionRow>
  >
  _missionScheduleRevisionsRefsTable(_$AppDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.missionScheduleRevisions,
        aliasName: 'missions__id__mission_schedule_revisions__mission_id',
      );

  $$MissionScheduleRevisionsTableProcessedTableManager
  get missionScheduleRevisionsRefs {
    final manager = $$MissionScheduleRevisionsTableTableManager(
      $_db,
      $_db.missionScheduleRevisions,
    ).filter((f) => f.missionId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _missionScheduleRevisionsRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$ExecutionPlansTable, List<ExecutionPlanRow>>
  _executionPlansRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.executionPlans,
    aliasName: 'missions__id__execution_plans__mission_id',
  );

  $$ExecutionPlansTableProcessedTableManager get executionPlansRefs {
    final manager = $$ExecutionPlansTableTableManager(
      $_db,
      $_db.executionPlans,
    ).filter((f) => f.missionId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_executionPlansRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$ExecutionEventsTable, List<ExecutionEventRow>>
  _executionEventsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.executionEvents,
    aliasName: 'missions__id__execution_events__mission_id',
  );

  $$ExecutionEventsTableProcessedTableManager get executionEventsRefs {
    final manager = $$ExecutionEventsTableTableManager(
      $_db,
      $_db.executionEvents,
    ).filter((f) => f.missionId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _executionEventsRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$FailureRecordsTable, List<FailureRecordRow>>
  _failureRecordsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.failureRecords,
    aliasName: 'missions__id__failure_records__mission_id',
  );

  $$FailureRecordsTableProcessedTableManager get failureRecordsRefs {
    final manager = $$FailureRecordsTableTableManager(
      $_db,
      $_db.failureRecords,
    ).filter((f) => f.missionId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_failureRecordsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$EvidenceRecordsTable, List<EvidenceRow>>
  _evidenceRecordsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.evidenceRecords,
    aliasName: 'missions__id__evidence_records__mission_id',
  );

  $$EvidenceRecordsTableProcessedTableManager get evidenceRecordsRefs {
    final manager = $$EvidenceRecordsTableTableManager(
      $_db,
      $_db.evidenceRecords,
    ).filter((f) => f.missionId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _evidenceRecordsRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<
    $UserExecutionReportsTable,
    List<UserExecutionReportRow>
  >
  _userExecutionReportsRefsTable(_$AppDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.userExecutionReports,
        aliasName: 'missions__id__user_execution_reports__mission_id',
      );

  $$UserExecutionReportsTableProcessedTableManager
  get userExecutionReportsRefs {
    final manager = $$UserExecutionReportsTableTableManager(
      $_db,
      $_db.userExecutionReports,
    ).filter((f) => f.missionId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _userExecutionReportsRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$MissionsTableFilterComposer
    extends Composer<_$AppDatabase, $MissionsTable> {
  $$MissionsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get why => $composableBuilder(
    column: $table.why,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get verificationPolicy => $composableBuilder(
    column: $table.verificationPolicy,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get cancelledAt => $composableBuilder(
    column: $table.cancelledAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get evidenceWaivedAt => $composableBuilder(
    column: $table.evidenceWaivedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get relationType => $composableBuilder(
    column: $table.relationType,
    builder: (column) => ColumnFilters(column),
  );

  $$GoalsTableFilterComposer get goalId {
    final $$GoalsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.goalId,
      referencedTable: $db.goals,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$GoalsTableFilterComposer(
            $db: $db,
            $table: $db.goals,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$GoalNodesTableFilterComposer get goalNodeId {
    final $$GoalNodesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.goalNodeId,
      referencedTable: $db.goalNodes,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$GoalNodesTableFilterComposer(
            $db: $db,
            $table: $db.goalNodes,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$MissionsTableFilterComposer get sourceMissionId {
    final $$MissionsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.sourceMissionId,
      referencedTable: $db.missions,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MissionsTableFilterComposer(
            $db: $db,
            $table: $db.missions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<bool> missionScheduleRevisionsRefs(
    Expression<bool> Function($$MissionScheduleRevisionsTableFilterComposer f)
    f,
  ) {
    final $$MissionScheduleRevisionsTableFilterComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.missionScheduleRevisions,
          getReferencedColumn: (t) => t.missionId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$MissionScheduleRevisionsTableFilterComposer(
                $db: $db,
                $table: $db.missionScheduleRevisions,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }

  Expression<bool> executionPlansRefs(
    Expression<bool> Function($$ExecutionPlansTableFilterComposer f) f,
  ) {
    final $$ExecutionPlansTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.executionPlans,
      getReferencedColumn: (t) => t.missionId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ExecutionPlansTableFilterComposer(
            $db: $db,
            $table: $db.executionPlans,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> executionEventsRefs(
    Expression<bool> Function($$ExecutionEventsTableFilterComposer f) f,
  ) {
    final $$ExecutionEventsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.executionEvents,
      getReferencedColumn: (t) => t.missionId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ExecutionEventsTableFilterComposer(
            $db: $db,
            $table: $db.executionEvents,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> failureRecordsRefs(
    Expression<bool> Function($$FailureRecordsTableFilterComposer f) f,
  ) {
    final $$FailureRecordsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.failureRecords,
      getReferencedColumn: (t) => t.missionId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$FailureRecordsTableFilterComposer(
            $db: $db,
            $table: $db.failureRecords,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> evidenceRecordsRefs(
    Expression<bool> Function($$EvidenceRecordsTableFilterComposer f) f,
  ) {
    final $$EvidenceRecordsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.evidenceRecords,
      getReferencedColumn: (t) => t.missionId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$EvidenceRecordsTableFilterComposer(
            $db: $db,
            $table: $db.evidenceRecords,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> userExecutionReportsRefs(
    Expression<bool> Function($$UserExecutionReportsTableFilterComposer f) f,
  ) {
    final $$UserExecutionReportsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.userExecutionReports,
      getReferencedColumn: (t) => t.missionId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$UserExecutionReportsTableFilterComposer(
            $db: $db,
            $table: $db.userExecutionReports,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$MissionsTableOrderingComposer
    extends Composer<_$AppDatabase, $MissionsTable> {
  $$MissionsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get why => $composableBuilder(
    column: $table.why,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get verificationPolicy => $composableBuilder(
    column: $table.verificationPolicy,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get cancelledAt => $composableBuilder(
    column: $table.cancelledAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get evidenceWaivedAt => $composableBuilder(
    column: $table.evidenceWaivedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get relationType => $composableBuilder(
    column: $table.relationType,
    builder: (column) => ColumnOrderings(column),
  );

  $$GoalsTableOrderingComposer get goalId {
    final $$GoalsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.goalId,
      referencedTable: $db.goals,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$GoalsTableOrderingComposer(
            $db: $db,
            $table: $db.goals,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$GoalNodesTableOrderingComposer get goalNodeId {
    final $$GoalNodesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.goalNodeId,
      referencedTable: $db.goalNodes,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$GoalNodesTableOrderingComposer(
            $db: $db,
            $table: $db.goalNodes,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$MissionsTableOrderingComposer get sourceMissionId {
    final $$MissionsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.sourceMissionId,
      referencedTable: $db.missions,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MissionsTableOrderingComposer(
            $db: $db,
            $table: $db.missions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$MissionsTableAnnotationComposer
    extends Composer<_$AppDatabase, $MissionsTable> {
  $$MissionsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => column,
  );

  GeneratedColumn<String> get why =>
      $composableBuilder(column: $table.why, builder: (column) => column);

  GeneratedColumn<String> get verificationPolicy => $composableBuilder(
    column: $table.verificationPolicy,
    builder: (column) => column,
  );

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<int> get cancelledAt => $composableBuilder(
    column: $table.cancelledAt,
    builder: (column) => column,
  );

  GeneratedColumn<int> get evidenceWaivedAt => $composableBuilder(
    column: $table.evidenceWaivedAt,
    builder: (column) => column,
  );

  GeneratedColumn<String> get relationType => $composableBuilder(
    column: $table.relationType,
    builder: (column) => column,
  );

  $$GoalsTableAnnotationComposer get goalId {
    final $$GoalsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.goalId,
      referencedTable: $db.goals,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$GoalsTableAnnotationComposer(
            $db: $db,
            $table: $db.goals,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$GoalNodesTableAnnotationComposer get goalNodeId {
    final $$GoalNodesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.goalNodeId,
      referencedTable: $db.goalNodes,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$GoalNodesTableAnnotationComposer(
            $db: $db,
            $table: $db.goalNodes,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$MissionsTableAnnotationComposer get sourceMissionId {
    final $$MissionsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.sourceMissionId,
      referencedTable: $db.missions,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MissionsTableAnnotationComposer(
            $db: $db,
            $table: $db.missions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<T> missionScheduleRevisionsRefs<T extends Object>(
    Expression<T> Function($$MissionScheduleRevisionsTableAnnotationComposer a)
    f,
  ) {
    final $$MissionScheduleRevisionsTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.missionScheduleRevisions,
          getReferencedColumn: (t) => t.missionId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$MissionScheduleRevisionsTableAnnotationComposer(
                $db: $db,
                $table: $db.missionScheduleRevisions,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }

  Expression<T> executionPlansRefs<T extends Object>(
    Expression<T> Function($$ExecutionPlansTableAnnotationComposer a) f,
  ) {
    final $$ExecutionPlansTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.executionPlans,
      getReferencedColumn: (t) => t.missionId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ExecutionPlansTableAnnotationComposer(
            $db: $db,
            $table: $db.executionPlans,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> executionEventsRefs<T extends Object>(
    Expression<T> Function($$ExecutionEventsTableAnnotationComposer a) f,
  ) {
    final $$ExecutionEventsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.executionEvents,
      getReferencedColumn: (t) => t.missionId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ExecutionEventsTableAnnotationComposer(
            $db: $db,
            $table: $db.executionEvents,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> failureRecordsRefs<T extends Object>(
    Expression<T> Function($$FailureRecordsTableAnnotationComposer a) f,
  ) {
    final $$FailureRecordsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.failureRecords,
      getReferencedColumn: (t) => t.missionId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$FailureRecordsTableAnnotationComposer(
            $db: $db,
            $table: $db.failureRecords,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> evidenceRecordsRefs<T extends Object>(
    Expression<T> Function($$EvidenceRecordsTableAnnotationComposer a) f,
  ) {
    final $$EvidenceRecordsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.evidenceRecords,
      getReferencedColumn: (t) => t.missionId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$EvidenceRecordsTableAnnotationComposer(
            $db: $db,
            $table: $db.evidenceRecords,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> userExecutionReportsRefs<T extends Object>(
    Expression<T> Function($$UserExecutionReportsTableAnnotationComposer a) f,
  ) {
    final $$UserExecutionReportsTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.userExecutionReports,
          getReferencedColumn: (t) => t.missionId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$UserExecutionReportsTableAnnotationComposer(
                $db: $db,
                $table: $db.userExecutionReports,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }
}

class $$MissionsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $MissionsTable,
          MissionRow,
          $$MissionsTableFilterComposer,
          $$MissionsTableOrderingComposer,
          $$MissionsTableAnnotationComposer,
          $$MissionsTableCreateCompanionBuilder,
          $$MissionsTableUpdateCompanionBuilder,
          (MissionRow, $$MissionsTableReferences),
          MissionRow,
          PrefetchHooks Function({
            bool goalId,
            bool goalNodeId,
            bool sourceMissionId,
            bool missionScheduleRevisionsRefs,
            bool executionPlansRefs,
            bool executionEventsRefs,
            bool failureRecordsRefs,
            bool evidenceRecordsRefs,
            bool userExecutionReportsRefs,
          })
        > {
  $$MissionsTableTableManager(_$AppDatabase db, $MissionsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$MissionsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$MissionsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$MissionsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String?> goalId = const Value.absent(),
                Value<String?> goalNodeId = const Value.absent(),
                Value<String> id = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String?> description = const Value.absent(),
                Value<String?> why = const Value.absent(),
                Value<String> verificationPolicy = const Value.absent(),
                Value<int> createdAt = const Value.absent(),
                Value<int> updatedAt = const Value.absent(),
                Value<int?> cancelledAt = const Value.absent(),
                Value<int?> evidenceWaivedAt = const Value.absent(),
                Value<String?> sourceMissionId = const Value.absent(),
                Value<String?> relationType = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => MissionsCompanion(
                goalId: goalId,
                goalNodeId: goalNodeId,
                id: id,
                title: title,
                description: description,
                why: why,
                verificationPolicy: verificationPolicy,
                createdAt: createdAt,
                updatedAt: updatedAt,
                cancelledAt: cancelledAt,
                evidenceWaivedAt: evidenceWaivedAt,
                sourceMissionId: sourceMissionId,
                relationType: relationType,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                Value<String?> goalId = const Value.absent(),
                Value<String?> goalNodeId = const Value.absent(),
                required String id,
                required String title,
                Value<String?> description = const Value.absent(),
                Value<String?> why = const Value.absent(),
                Value<String> verificationPolicy = const Value.absent(),
                required int createdAt,
                required int updatedAt,
                Value<int?> cancelledAt = const Value.absent(),
                Value<int?> evidenceWaivedAt = const Value.absent(),
                Value<String?> sourceMissionId = const Value.absent(),
                Value<String?> relationType = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => MissionsCompanion.insert(
                goalId: goalId,
                goalNodeId: goalNodeId,
                id: id,
                title: title,
                description: description,
                why: why,
                verificationPolicy: verificationPolicy,
                createdAt: createdAt,
                updatedAt: updatedAt,
                cancelledAt: cancelledAt,
                evidenceWaivedAt: evidenceWaivedAt,
                sourceMissionId: sourceMissionId,
                relationType: relationType,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$MissionsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({
                goalId = false,
                goalNodeId = false,
                sourceMissionId = false,
                missionScheduleRevisionsRefs = false,
                executionPlansRefs = false,
                executionEventsRefs = false,
                failureRecordsRefs = false,
                evidenceRecordsRefs = false,
                userExecutionReportsRefs = false,
              }) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (missionScheduleRevisionsRefs)
                      db.missionScheduleRevisions,
                    if (executionPlansRefs) db.executionPlans,
                    if (executionEventsRefs) db.executionEvents,
                    if (failureRecordsRefs) db.failureRecords,
                    if (evidenceRecordsRefs) db.evidenceRecords,
                    if (userExecutionReportsRefs) db.userExecutionReports,
                  ],
                  addJoins:
                      <
                        T extends TableManagerState<
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic
                        >
                      >(state) {
                        if (goalId) {
                          state =
                              state.withJoin(
                                    currentTable: table,
                                    currentColumn: table.goalId,
                                    referencedTable: $$MissionsTableReferences
                                        ._goalIdTable(db),
                                    referencedColumn: $$MissionsTableReferences
                                        ._goalIdTable(db)
                                        .id,
                                  )
                                  as T;
                        }
                        if (goalNodeId) {
                          state =
                              state.withJoin(
                                    currentTable: table,
                                    currentColumn: table.goalNodeId,
                                    referencedTable: $$MissionsTableReferences
                                        ._goalNodeIdTable(db),
                                    referencedColumn: $$MissionsTableReferences
                                        ._goalNodeIdTable(db)
                                        .id,
                                  )
                                  as T;
                        }
                        if (sourceMissionId) {
                          state =
                              state.withJoin(
                                    currentTable: table,
                                    currentColumn: table.sourceMissionId,
                                    referencedTable: $$MissionsTableReferences
                                        ._sourceMissionIdTable(db),
                                    referencedColumn: $$MissionsTableReferences
                                        ._sourceMissionIdTable(db)
                                        .id,
                                  )
                                  as T;
                        }

                        return state;
                      },
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (missionScheduleRevisionsRefs)
                        await $_getPrefetchedData<
                          MissionRow,
                          $MissionsTable,
                          MissionScheduleRevisionRow
                        >(
                          currentTable: table,
                          referencedTable: $$MissionsTableReferences
                              ._missionScheduleRevisionsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$MissionsTableReferences(
                                db,
                                table,
                                p0,
                              ).missionScheduleRevisionsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.missionId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (executionPlansRefs)
                        await $_getPrefetchedData<
                          MissionRow,
                          $MissionsTable,
                          ExecutionPlanRow
                        >(
                          currentTable: table,
                          referencedTable: $$MissionsTableReferences
                              ._executionPlansRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$MissionsTableReferences(
                                db,
                                table,
                                p0,
                              ).executionPlansRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.missionId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (executionEventsRefs)
                        await $_getPrefetchedData<
                          MissionRow,
                          $MissionsTable,
                          ExecutionEventRow
                        >(
                          currentTable: table,
                          referencedTable: $$MissionsTableReferences
                              ._executionEventsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$MissionsTableReferences(
                                db,
                                table,
                                p0,
                              ).executionEventsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.missionId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (failureRecordsRefs)
                        await $_getPrefetchedData<
                          MissionRow,
                          $MissionsTable,
                          FailureRecordRow
                        >(
                          currentTable: table,
                          referencedTable: $$MissionsTableReferences
                              ._failureRecordsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$MissionsTableReferences(
                                db,
                                table,
                                p0,
                              ).failureRecordsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.missionId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (evidenceRecordsRefs)
                        await $_getPrefetchedData<
                          MissionRow,
                          $MissionsTable,
                          EvidenceRow
                        >(
                          currentTable: table,
                          referencedTable: $$MissionsTableReferences
                              ._evidenceRecordsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$MissionsTableReferences(
                                db,
                                table,
                                p0,
                              ).evidenceRecordsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.missionId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (userExecutionReportsRefs)
                        await $_getPrefetchedData<
                          MissionRow,
                          $MissionsTable,
                          UserExecutionReportRow
                        >(
                          currentTable: table,
                          referencedTable: $$MissionsTableReferences
                              ._userExecutionReportsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$MissionsTableReferences(
                                db,
                                table,
                                p0,
                              ).userExecutionReportsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.missionId == item.id,
                              ),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$MissionsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $MissionsTable,
      MissionRow,
      $$MissionsTableFilterComposer,
      $$MissionsTableOrderingComposer,
      $$MissionsTableAnnotationComposer,
      $$MissionsTableCreateCompanionBuilder,
      $$MissionsTableUpdateCompanionBuilder,
      (MissionRow, $$MissionsTableReferences),
      MissionRow,
      PrefetchHooks Function({
        bool goalId,
        bool goalNodeId,
        bool sourceMissionId,
        bool missionScheduleRevisionsRefs,
        bool executionPlansRefs,
        bool executionEventsRefs,
        bool failureRecordsRefs,
        bool evidenceRecordsRefs,
        bool userExecutionReportsRefs,
      })
    >;
typedef $$MissionScheduleRevisionsTableCreateCompanionBuilder =
    MissionScheduleRevisionsCompanion Function({
      required String id,
      required String missionId,
      required int revisionNumber,
      required String scheduledDate,
      required String timeZone,
      Value<String> timePolicy,
      Value<int?> fixedStartAt,
      required int plannedDurationMinutes,
      Value<int?> evidenceDeadlineAt,
      Value<String?> changeReason,
      required int changedAt,
      Value<int> rowid,
    });
typedef $$MissionScheduleRevisionsTableUpdateCompanionBuilder =
    MissionScheduleRevisionsCompanion Function({
      Value<String> id,
      Value<String> missionId,
      Value<int> revisionNumber,
      Value<String> scheduledDate,
      Value<String> timeZone,
      Value<String> timePolicy,
      Value<int?> fixedStartAt,
      Value<int> plannedDurationMinutes,
      Value<int?> evidenceDeadlineAt,
      Value<String?> changeReason,
      Value<int> changedAt,
      Value<int> rowid,
    });

final class $$MissionScheduleRevisionsTableReferences
    extends
        BaseReferences<
          _$AppDatabase,
          $MissionScheduleRevisionsTable,
          MissionScheduleRevisionRow
        > {
  $$MissionScheduleRevisionsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $MissionsTable _missionIdTable(_$AppDatabase db) => db.missions
      .createAlias('mission_schedule_revisions__mission_id__missions__id');

  $$MissionsTableProcessedTableManager get missionId {
    final $_column = $_itemColumn<String>('mission_id')!;

    final manager = $$MissionsTableTableManager(
      $_db,
      $_db.missions,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_missionIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static MultiTypedResultKey<$ExecutionEventsTable, List<ExecutionEventRow>>
  _executionEventsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.executionEvents,
    aliasName:
        'mission_schedule_revisions__id__execution_events__schedule_revision_id',
  );

  $$ExecutionEventsTableProcessedTableManager get executionEventsRefs {
    final manager =
        $$ExecutionEventsTableTableManager($_db, $_db.executionEvents).filter(
          (f) => f.scheduleRevisionId.id.sqlEquals($_itemColumn<String>('id')!),
        );

    final cache = $_typedResult.readTableOrNull(
      _executionEventsRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$MissionScheduleRevisionsTableFilterComposer
    extends Composer<_$AppDatabase, $MissionScheduleRevisionsTable> {
  $$MissionScheduleRevisionsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get revisionNumber => $composableBuilder(
    column: $table.revisionNumber,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get scheduledDate => $composableBuilder(
    column: $table.scheduledDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get timeZone => $composableBuilder(
    column: $table.timeZone,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get timePolicy => $composableBuilder(
    column: $table.timePolicy,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get fixedStartAt => $composableBuilder(
    column: $table.fixedStartAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get plannedDurationMinutes => $composableBuilder(
    column: $table.plannedDurationMinutes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get evidenceDeadlineAt => $composableBuilder(
    column: $table.evidenceDeadlineAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get changeReason => $composableBuilder(
    column: $table.changeReason,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get changedAt => $composableBuilder(
    column: $table.changedAt,
    builder: (column) => ColumnFilters(column),
  );

  $$MissionsTableFilterComposer get missionId {
    final $$MissionsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.missionId,
      referencedTable: $db.missions,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MissionsTableFilterComposer(
            $db: $db,
            $table: $db.missions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<bool> executionEventsRefs(
    Expression<bool> Function($$ExecutionEventsTableFilterComposer f) f,
  ) {
    final $$ExecutionEventsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.executionEvents,
      getReferencedColumn: (t) => t.scheduleRevisionId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ExecutionEventsTableFilterComposer(
            $db: $db,
            $table: $db.executionEvents,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$MissionScheduleRevisionsTableOrderingComposer
    extends Composer<_$AppDatabase, $MissionScheduleRevisionsTable> {
  $$MissionScheduleRevisionsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get revisionNumber => $composableBuilder(
    column: $table.revisionNumber,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get scheduledDate => $composableBuilder(
    column: $table.scheduledDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get timeZone => $composableBuilder(
    column: $table.timeZone,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get timePolicy => $composableBuilder(
    column: $table.timePolicy,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get fixedStartAt => $composableBuilder(
    column: $table.fixedStartAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get plannedDurationMinutes => $composableBuilder(
    column: $table.plannedDurationMinutes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get evidenceDeadlineAt => $composableBuilder(
    column: $table.evidenceDeadlineAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get changeReason => $composableBuilder(
    column: $table.changeReason,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get changedAt => $composableBuilder(
    column: $table.changedAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$MissionsTableOrderingComposer get missionId {
    final $$MissionsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.missionId,
      referencedTable: $db.missions,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MissionsTableOrderingComposer(
            $db: $db,
            $table: $db.missions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$MissionScheduleRevisionsTableAnnotationComposer
    extends Composer<_$AppDatabase, $MissionScheduleRevisionsTable> {
  $$MissionScheduleRevisionsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get revisionNumber => $composableBuilder(
    column: $table.revisionNumber,
    builder: (column) => column,
  );

  GeneratedColumn<String> get scheduledDate => $composableBuilder(
    column: $table.scheduledDate,
    builder: (column) => column,
  );

  GeneratedColumn<String> get timeZone =>
      $composableBuilder(column: $table.timeZone, builder: (column) => column);

  GeneratedColumn<String> get timePolicy => $composableBuilder(
    column: $table.timePolicy,
    builder: (column) => column,
  );

  GeneratedColumn<int> get fixedStartAt => $composableBuilder(
    column: $table.fixedStartAt,
    builder: (column) => column,
  );

  GeneratedColumn<int> get plannedDurationMinutes => $composableBuilder(
    column: $table.plannedDurationMinutes,
    builder: (column) => column,
  );

  GeneratedColumn<int> get evidenceDeadlineAt => $composableBuilder(
    column: $table.evidenceDeadlineAt,
    builder: (column) => column,
  );

  GeneratedColumn<String> get changeReason => $composableBuilder(
    column: $table.changeReason,
    builder: (column) => column,
  );

  GeneratedColumn<int> get changedAt =>
      $composableBuilder(column: $table.changedAt, builder: (column) => column);

  $$MissionsTableAnnotationComposer get missionId {
    final $$MissionsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.missionId,
      referencedTable: $db.missions,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MissionsTableAnnotationComposer(
            $db: $db,
            $table: $db.missions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<T> executionEventsRefs<T extends Object>(
    Expression<T> Function($$ExecutionEventsTableAnnotationComposer a) f,
  ) {
    final $$ExecutionEventsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.executionEvents,
      getReferencedColumn: (t) => t.scheduleRevisionId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ExecutionEventsTableAnnotationComposer(
            $db: $db,
            $table: $db.executionEvents,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$MissionScheduleRevisionsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $MissionScheduleRevisionsTable,
          MissionScheduleRevisionRow,
          $$MissionScheduleRevisionsTableFilterComposer,
          $$MissionScheduleRevisionsTableOrderingComposer,
          $$MissionScheduleRevisionsTableAnnotationComposer,
          $$MissionScheduleRevisionsTableCreateCompanionBuilder,
          $$MissionScheduleRevisionsTableUpdateCompanionBuilder,
          (
            MissionScheduleRevisionRow,
            $$MissionScheduleRevisionsTableReferences,
          ),
          MissionScheduleRevisionRow,
          PrefetchHooks Function({bool missionId, bool executionEventsRefs})
        > {
  $$MissionScheduleRevisionsTableTableManager(
    _$AppDatabase db,
    $MissionScheduleRevisionsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$MissionScheduleRevisionsTableFilterComposer(
                $db: db,
                $table: table,
              ),
          createOrderingComposer: () =>
              $$MissionScheduleRevisionsTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$MissionScheduleRevisionsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> missionId = const Value.absent(),
                Value<int> revisionNumber = const Value.absent(),
                Value<String> scheduledDate = const Value.absent(),
                Value<String> timeZone = const Value.absent(),
                Value<String> timePolicy = const Value.absent(),
                Value<int?> fixedStartAt = const Value.absent(),
                Value<int> plannedDurationMinutes = const Value.absent(),
                Value<int?> evidenceDeadlineAt = const Value.absent(),
                Value<String?> changeReason = const Value.absent(),
                Value<int> changedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => MissionScheduleRevisionsCompanion(
                id: id,
                missionId: missionId,
                revisionNumber: revisionNumber,
                scheduledDate: scheduledDate,
                timeZone: timeZone,
                timePolicy: timePolicy,
                fixedStartAt: fixedStartAt,
                plannedDurationMinutes: plannedDurationMinutes,
                evidenceDeadlineAt: evidenceDeadlineAt,
                changeReason: changeReason,
                changedAt: changedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String missionId,
                required int revisionNumber,
                required String scheduledDate,
                required String timeZone,
                Value<String> timePolicy = const Value.absent(),
                Value<int?> fixedStartAt = const Value.absent(),
                required int plannedDurationMinutes,
                Value<int?> evidenceDeadlineAt = const Value.absent(),
                Value<String?> changeReason = const Value.absent(),
                required int changedAt,
                Value<int> rowid = const Value.absent(),
              }) => MissionScheduleRevisionsCompanion.insert(
                id: id,
                missionId: missionId,
                revisionNumber: revisionNumber,
                scheduledDate: scheduledDate,
                timeZone: timeZone,
                timePolicy: timePolicy,
                fixedStartAt: fixedStartAt,
                plannedDurationMinutes: plannedDurationMinutes,
                evidenceDeadlineAt: evidenceDeadlineAt,
                changeReason: changeReason,
                changedAt: changedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$MissionScheduleRevisionsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({missionId = false, executionEventsRefs = false}) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (executionEventsRefs) db.executionEvents,
                  ],
                  addJoins:
                      <
                        T extends TableManagerState<
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic
                        >
                      >(state) {
                        if (missionId) {
                          state =
                              state.withJoin(
                                    currentTable: table,
                                    currentColumn: table.missionId,
                                    referencedTable:
                                        $$MissionScheduleRevisionsTableReferences
                                            ._missionIdTable(db),
                                    referencedColumn:
                                        $$MissionScheduleRevisionsTableReferences
                                            ._missionIdTable(db)
                                            .id,
                                  )
                                  as T;
                        }

                        return state;
                      },
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (executionEventsRefs)
                        await $_getPrefetchedData<
                          MissionScheduleRevisionRow,
                          $MissionScheduleRevisionsTable,
                          ExecutionEventRow
                        >(
                          currentTable: table,
                          referencedTable:
                              $$MissionScheduleRevisionsTableReferences
                                  ._executionEventsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$MissionScheduleRevisionsTableReferences(
                                db,
                                table,
                                p0,
                              ).executionEventsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.scheduleRevisionId == item.id,
                              ),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$MissionScheduleRevisionsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $MissionScheduleRevisionsTable,
      MissionScheduleRevisionRow,
      $$MissionScheduleRevisionsTableFilterComposer,
      $$MissionScheduleRevisionsTableOrderingComposer,
      $$MissionScheduleRevisionsTableAnnotationComposer,
      $$MissionScheduleRevisionsTableCreateCompanionBuilder,
      $$MissionScheduleRevisionsTableUpdateCompanionBuilder,
      (MissionScheduleRevisionRow, $$MissionScheduleRevisionsTableReferences),
      MissionScheduleRevisionRow,
      PrefetchHooks Function({bool missionId, bool executionEventsRefs})
    >;
typedef $$ExecutionPlansTableCreateCompanionBuilder =
    ExecutionPlansCompanion Function({
      required String id,
      required String missionId,
      required String objective,
      Value<String> steps,
      Value<String?> verificationCriteria,
      Value<String?> notes,
      required int createdAt,
      required int updatedAt,
      Value<int> rowid,
    });
typedef $$ExecutionPlansTableUpdateCompanionBuilder =
    ExecutionPlansCompanion Function({
      Value<String> id,
      Value<String> missionId,
      Value<String> objective,
      Value<String> steps,
      Value<String?> verificationCriteria,
      Value<String?> notes,
      Value<int> createdAt,
      Value<int> updatedAt,
      Value<int> rowid,
    });

final class $$ExecutionPlansTableReferences
    extends
        BaseReferences<_$AppDatabase, $ExecutionPlansTable, ExecutionPlanRow> {
  $$ExecutionPlansTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $MissionsTable _missionIdTable(_$AppDatabase db) =>
      db.missions.createAlias('execution_plans__mission_id__missions__id');

  $$MissionsTableProcessedTableManager get missionId {
    final $_column = $_itemColumn<String>('mission_id')!;

    final manager = $$MissionsTableTableManager(
      $_db,
      $_db.missions,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_missionIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$ExecutionPlansTableFilterComposer
    extends Composer<_$AppDatabase, $ExecutionPlansTable> {
  $$ExecutionPlansTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get objective => $composableBuilder(
    column: $table.objective,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get steps => $composableBuilder(
    column: $table.steps,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get verificationCriteria => $composableBuilder(
    column: $table.verificationCriteria,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  $$MissionsTableFilterComposer get missionId {
    final $$MissionsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.missionId,
      referencedTable: $db.missions,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MissionsTableFilterComposer(
            $db: $db,
            $table: $db.missions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ExecutionPlansTableOrderingComposer
    extends Composer<_$AppDatabase, $ExecutionPlansTable> {
  $$ExecutionPlansTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get objective => $composableBuilder(
    column: $table.objective,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get steps => $composableBuilder(
    column: $table.steps,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get verificationCriteria => $composableBuilder(
    column: $table.verificationCriteria,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$MissionsTableOrderingComposer get missionId {
    final $$MissionsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.missionId,
      referencedTable: $db.missions,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MissionsTableOrderingComposer(
            $db: $db,
            $table: $db.missions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ExecutionPlansTableAnnotationComposer
    extends Composer<_$AppDatabase, $ExecutionPlansTable> {
  $$ExecutionPlansTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get objective =>
      $composableBuilder(column: $table.objective, builder: (column) => column);

  GeneratedColumn<String> get steps =>
      $composableBuilder(column: $table.steps, builder: (column) => column);

  GeneratedColumn<String> get verificationCriteria => $composableBuilder(
    column: $table.verificationCriteria,
    builder: (column) => column,
  );

  GeneratedColumn<String> get notes =>
      $composableBuilder(column: $table.notes, builder: (column) => column);

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  $$MissionsTableAnnotationComposer get missionId {
    final $$MissionsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.missionId,
      referencedTable: $db.missions,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MissionsTableAnnotationComposer(
            $db: $db,
            $table: $db.missions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ExecutionPlansTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ExecutionPlansTable,
          ExecutionPlanRow,
          $$ExecutionPlansTableFilterComposer,
          $$ExecutionPlansTableOrderingComposer,
          $$ExecutionPlansTableAnnotationComposer,
          $$ExecutionPlansTableCreateCompanionBuilder,
          $$ExecutionPlansTableUpdateCompanionBuilder,
          (ExecutionPlanRow, $$ExecutionPlansTableReferences),
          ExecutionPlanRow,
          PrefetchHooks Function({bool missionId})
        > {
  $$ExecutionPlansTableTableManager(
    _$AppDatabase db,
    $ExecutionPlansTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ExecutionPlansTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ExecutionPlansTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ExecutionPlansTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> missionId = const Value.absent(),
                Value<String> objective = const Value.absent(),
                Value<String> steps = const Value.absent(),
                Value<String?> verificationCriteria = const Value.absent(),
                Value<String?> notes = const Value.absent(),
                Value<int> createdAt = const Value.absent(),
                Value<int> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ExecutionPlansCompanion(
                id: id,
                missionId: missionId,
                objective: objective,
                steps: steps,
                verificationCriteria: verificationCriteria,
                notes: notes,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String missionId,
                required String objective,
                Value<String> steps = const Value.absent(),
                Value<String?> verificationCriteria = const Value.absent(),
                Value<String?> notes = const Value.absent(),
                required int createdAt,
                required int updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => ExecutionPlansCompanion.insert(
                id: id,
                missionId: missionId,
                objective: objective,
                steps: steps,
                verificationCriteria: verificationCriteria,
                notes: notes,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$ExecutionPlansTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({missionId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (missionId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.missionId,
                                referencedTable: $$ExecutionPlansTableReferences
                                    ._missionIdTable(db),
                                referencedColumn:
                                    $$ExecutionPlansTableReferences
                                        ._missionIdTable(db)
                                        .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$ExecutionPlansTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ExecutionPlansTable,
      ExecutionPlanRow,
      $$ExecutionPlansTableFilterComposer,
      $$ExecutionPlansTableOrderingComposer,
      $$ExecutionPlansTableAnnotationComposer,
      $$ExecutionPlansTableCreateCompanionBuilder,
      $$ExecutionPlansTableUpdateCompanionBuilder,
      (ExecutionPlanRow, $$ExecutionPlansTableReferences),
      ExecutionPlanRow,
      PrefetchHooks Function({bool missionId})
    >;
typedef $$ExecutionEventsTableCreateCompanionBuilder =
    ExecutionEventsCompanion Function({
      required String id,
      required String missionId,
      required int sequence,
      required String type,
      required int occurredAt,
      Value<String?> scheduleRevisionId,
      Value<int?> grantedDurationMinutes,
      Value<String?> reason,
      Value<String?> userReportedResult,
      Value<bool?> submitOptionalEvidence,
      Value<bool> isRetrospective,
      Value<int> rowid,
    });
typedef $$ExecutionEventsTableUpdateCompanionBuilder =
    ExecutionEventsCompanion Function({
      Value<String> id,
      Value<String> missionId,
      Value<int> sequence,
      Value<String> type,
      Value<int> occurredAt,
      Value<String?> scheduleRevisionId,
      Value<int?> grantedDurationMinutes,
      Value<String?> reason,
      Value<String?> userReportedResult,
      Value<bool?> submitOptionalEvidence,
      Value<bool> isRetrospective,
      Value<int> rowid,
    });

final class $$ExecutionEventsTableReferences
    extends
        BaseReferences<
          _$AppDatabase,
          $ExecutionEventsTable,
          ExecutionEventRow
        > {
  $$ExecutionEventsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $MissionsTable _missionIdTable(_$AppDatabase db) =>
      db.missions.createAlias('execution_events__mission_id__missions__id');

  $$MissionsTableProcessedTableManager get missionId {
    final $_column = $_itemColumn<String>('mission_id')!;

    final manager = $$MissionsTableTableManager(
      $_db,
      $_db.missions,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_missionIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $MissionScheduleRevisionsTable _scheduleRevisionIdTable(
    _$AppDatabase db,
  ) => db.missionScheduleRevisions.createAlias(
    'execution_events__schedule_revision_id__mission_schedule_revisions__id',
  );

  $$MissionScheduleRevisionsTableProcessedTableManager? get scheduleRevisionId {
    final $_column = $_itemColumn<String>('schedule_revision_id');
    if ($_column == null) return null;
    final manager = $$MissionScheduleRevisionsTableTableManager(
      $_db,
      $_db.missionScheduleRevisions,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_scheduleRevisionIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$ExecutionEventsTableFilterComposer
    extends Composer<_$AppDatabase, $ExecutionEventsTable> {
  $$ExecutionEventsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sequence => $composableBuilder(
    column: $table.sequence,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get occurredAt => $composableBuilder(
    column: $table.occurredAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get grantedDurationMinutes => $composableBuilder(
    column: $table.grantedDurationMinutes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get reason => $composableBuilder(
    column: $table.reason,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get userReportedResult => $composableBuilder(
    column: $table.userReportedResult,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get submitOptionalEvidence => $composableBuilder(
    column: $table.submitOptionalEvidence,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isRetrospective => $composableBuilder(
    column: $table.isRetrospective,
    builder: (column) => ColumnFilters(column),
  );

  $$MissionsTableFilterComposer get missionId {
    final $$MissionsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.missionId,
      referencedTable: $db.missions,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MissionsTableFilterComposer(
            $db: $db,
            $table: $db.missions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$MissionScheduleRevisionsTableFilterComposer get scheduleRevisionId {
    final $$MissionScheduleRevisionsTableFilterComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.scheduleRevisionId,
          referencedTable: $db.missionScheduleRevisions,
          getReferencedColumn: (t) => t.id,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$MissionScheduleRevisionsTableFilterComposer(
                $db: $db,
                $table: $db.missionScheduleRevisions,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return composer;
  }
}

class $$ExecutionEventsTableOrderingComposer
    extends Composer<_$AppDatabase, $ExecutionEventsTable> {
  $$ExecutionEventsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sequence => $composableBuilder(
    column: $table.sequence,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get occurredAt => $composableBuilder(
    column: $table.occurredAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get grantedDurationMinutes => $composableBuilder(
    column: $table.grantedDurationMinutes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get reason => $composableBuilder(
    column: $table.reason,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get userReportedResult => $composableBuilder(
    column: $table.userReportedResult,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get submitOptionalEvidence => $composableBuilder(
    column: $table.submitOptionalEvidence,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isRetrospective => $composableBuilder(
    column: $table.isRetrospective,
    builder: (column) => ColumnOrderings(column),
  );

  $$MissionsTableOrderingComposer get missionId {
    final $$MissionsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.missionId,
      referencedTable: $db.missions,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MissionsTableOrderingComposer(
            $db: $db,
            $table: $db.missions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$MissionScheduleRevisionsTableOrderingComposer get scheduleRevisionId {
    final $$MissionScheduleRevisionsTableOrderingComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.scheduleRevisionId,
          referencedTable: $db.missionScheduleRevisions,
          getReferencedColumn: (t) => t.id,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$MissionScheduleRevisionsTableOrderingComposer(
                $db: $db,
                $table: $db.missionScheduleRevisions,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return composer;
  }
}

class $$ExecutionEventsTableAnnotationComposer
    extends Composer<_$AppDatabase, $ExecutionEventsTable> {
  $$ExecutionEventsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get sequence =>
      $composableBuilder(column: $table.sequence, builder: (column) => column);

  GeneratedColumn<String> get type =>
      $composableBuilder(column: $table.type, builder: (column) => column);

  GeneratedColumn<int> get occurredAt => $composableBuilder(
    column: $table.occurredAt,
    builder: (column) => column,
  );

  GeneratedColumn<int> get grantedDurationMinutes => $composableBuilder(
    column: $table.grantedDurationMinutes,
    builder: (column) => column,
  );

  GeneratedColumn<String> get reason =>
      $composableBuilder(column: $table.reason, builder: (column) => column);

  GeneratedColumn<String> get userReportedResult => $composableBuilder(
    column: $table.userReportedResult,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get submitOptionalEvidence => $composableBuilder(
    column: $table.submitOptionalEvidence,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get isRetrospective => $composableBuilder(
    column: $table.isRetrospective,
    builder: (column) => column,
  );

  $$MissionsTableAnnotationComposer get missionId {
    final $$MissionsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.missionId,
      referencedTable: $db.missions,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MissionsTableAnnotationComposer(
            $db: $db,
            $table: $db.missions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$MissionScheduleRevisionsTableAnnotationComposer get scheduleRevisionId {
    final $$MissionScheduleRevisionsTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.scheduleRevisionId,
          referencedTable: $db.missionScheduleRevisions,
          getReferencedColumn: (t) => t.id,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$MissionScheduleRevisionsTableAnnotationComposer(
                $db: $db,
                $table: $db.missionScheduleRevisions,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return composer;
  }
}

class $$ExecutionEventsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ExecutionEventsTable,
          ExecutionEventRow,
          $$ExecutionEventsTableFilterComposer,
          $$ExecutionEventsTableOrderingComposer,
          $$ExecutionEventsTableAnnotationComposer,
          $$ExecutionEventsTableCreateCompanionBuilder,
          $$ExecutionEventsTableUpdateCompanionBuilder,
          (ExecutionEventRow, $$ExecutionEventsTableReferences),
          ExecutionEventRow,
          PrefetchHooks Function({bool missionId, bool scheduleRevisionId})
        > {
  $$ExecutionEventsTableTableManager(
    _$AppDatabase db,
    $ExecutionEventsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ExecutionEventsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ExecutionEventsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ExecutionEventsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> missionId = const Value.absent(),
                Value<int> sequence = const Value.absent(),
                Value<String> type = const Value.absent(),
                Value<int> occurredAt = const Value.absent(),
                Value<String?> scheduleRevisionId = const Value.absent(),
                Value<int?> grantedDurationMinutes = const Value.absent(),
                Value<String?> reason = const Value.absent(),
                Value<String?> userReportedResult = const Value.absent(),
                Value<bool?> submitOptionalEvidence = const Value.absent(),
                Value<bool> isRetrospective = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ExecutionEventsCompanion(
                id: id,
                missionId: missionId,
                sequence: sequence,
                type: type,
                occurredAt: occurredAt,
                scheduleRevisionId: scheduleRevisionId,
                grantedDurationMinutes: grantedDurationMinutes,
                reason: reason,
                userReportedResult: userReportedResult,
                submitOptionalEvidence: submitOptionalEvidence,
                isRetrospective: isRetrospective,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String missionId,
                required int sequence,
                required String type,
                required int occurredAt,
                Value<String?> scheduleRevisionId = const Value.absent(),
                Value<int?> grantedDurationMinutes = const Value.absent(),
                Value<String?> reason = const Value.absent(),
                Value<String?> userReportedResult = const Value.absent(),
                Value<bool?> submitOptionalEvidence = const Value.absent(),
                Value<bool> isRetrospective = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ExecutionEventsCompanion.insert(
                id: id,
                missionId: missionId,
                sequence: sequence,
                type: type,
                occurredAt: occurredAt,
                scheduleRevisionId: scheduleRevisionId,
                grantedDurationMinutes: grantedDurationMinutes,
                reason: reason,
                userReportedResult: userReportedResult,
                submitOptionalEvidence: submitOptionalEvidence,
                isRetrospective: isRetrospective,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$ExecutionEventsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({missionId = false, scheduleRevisionId = false}) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [],
                  addJoins:
                      <
                        T extends TableManagerState<
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic
                        >
                      >(state) {
                        if (missionId) {
                          state =
                              state.withJoin(
                                    currentTable: table,
                                    currentColumn: table.missionId,
                                    referencedTable:
                                        $$ExecutionEventsTableReferences
                                            ._missionIdTable(db),
                                    referencedColumn:
                                        $$ExecutionEventsTableReferences
                                            ._missionIdTable(db)
                                            .id,
                                  )
                                  as T;
                        }
                        if (scheduleRevisionId) {
                          state =
                              state.withJoin(
                                    currentTable: table,
                                    currentColumn: table.scheduleRevisionId,
                                    referencedTable:
                                        $$ExecutionEventsTableReferences
                                            ._scheduleRevisionIdTable(db),
                                    referencedColumn:
                                        $$ExecutionEventsTableReferences
                                            ._scheduleRevisionIdTable(db)
                                            .id,
                                  )
                                  as T;
                        }

                        return state;
                      },
                  getPrefetchedDataCallback: (items) async {
                    return [];
                  },
                );
              },
        ),
      );
}

typedef $$ExecutionEventsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ExecutionEventsTable,
      ExecutionEventRow,
      $$ExecutionEventsTableFilterComposer,
      $$ExecutionEventsTableOrderingComposer,
      $$ExecutionEventsTableAnnotationComposer,
      $$ExecutionEventsTableCreateCompanionBuilder,
      $$ExecutionEventsTableUpdateCompanionBuilder,
      (ExecutionEventRow, $$ExecutionEventsTableReferences),
      ExecutionEventRow,
      PrefetchHooks Function({bool missionId, bool scheduleRevisionId})
    >;
typedef $$FailureRecordsTableCreateCompanionBuilder =
    FailureRecordsCompanion Function({
      required String id,
      required String missionId,
      required String trigger,
      required int occurredAt,
      Value<String?> userReasonCategory,
      Value<String?> userReasonText,
      required int createdAt,
      Value<int> rowid,
    });
typedef $$FailureRecordsTableUpdateCompanionBuilder =
    FailureRecordsCompanion Function({
      Value<String> id,
      Value<String> missionId,
      Value<String> trigger,
      Value<int> occurredAt,
      Value<String?> userReasonCategory,
      Value<String?> userReasonText,
      Value<int> createdAt,
      Value<int> rowid,
    });

final class $$FailureRecordsTableReferences
    extends
        BaseReferences<_$AppDatabase, $FailureRecordsTable, FailureRecordRow> {
  $$FailureRecordsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $MissionsTable _missionIdTable(_$AppDatabase db) =>
      db.missions.createAlias('failure_records__mission_id__missions__id');

  $$MissionsTableProcessedTableManager get missionId {
    final $_column = $_itemColumn<String>('mission_id')!;

    final manager = $$MissionsTableTableManager(
      $_db,
      $_db.missions,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_missionIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$FailureRecordsTableFilterComposer
    extends Composer<_$AppDatabase, $FailureRecordsTable> {
  $$FailureRecordsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get trigger => $composableBuilder(
    column: $table.trigger,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get occurredAt => $composableBuilder(
    column: $table.occurredAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get userReasonCategory => $composableBuilder(
    column: $table.userReasonCategory,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get userReasonText => $composableBuilder(
    column: $table.userReasonText,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  $$MissionsTableFilterComposer get missionId {
    final $$MissionsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.missionId,
      referencedTable: $db.missions,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MissionsTableFilterComposer(
            $db: $db,
            $table: $db.missions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$FailureRecordsTableOrderingComposer
    extends Composer<_$AppDatabase, $FailureRecordsTable> {
  $$FailureRecordsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get trigger => $composableBuilder(
    column: $table.trigger,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get occurredAt => $composableBuilder(
    column: $table.occurredAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get userReasonCategory => $composableBuilder(
    column: $table.userReasonCategory,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get userReasonText => $composableBuilder(
    column: $table.userReasonText,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$MissionsTableOrderingComposer get missionId {
    final $$MissionsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.missionId,
      referencedTable: $db.missions,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MissionsTableOrderingComposer(
            $db: $db,
            $table: $db.missions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$FailureRecordsTableAnnotationComposer
    extends Composer<_$AppDatabase, $FailureRecordsTable> {
  $$FailureRecordsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get trigger =>
      $composableBuilder(column: $table.trigger, builder: (column) => column);

  GeneratedColumn<int> get occurredAt => $composableBuilder(
    column: $table.occurredAt,
    builder: (column) => column,
  );

  GeneratedColumn<String> get userReasonCategory => $composableBuilder(
    column: $table.userReasonCategory,
    builder: (column) => column,
  );

  GeneratedColumn<String> get userReasonText => $composableBuilder(
    column: $table.userReasonText,
    builder: (column) => column,
  );

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  $$MissionsTableAnnotationComposer get missionId {
    final $$MissionsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.missionId,
      referencedTable: $db.missions,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MissionsTableAnnotationComposer(
            $db: $db,
            $table: $db.missions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$FailureRecordsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $FailureRecordsTable,
          FailureRecordRow,
          $$FailureRecordsTableFilterComposer,
          $$FailureRecordsTableOrderingComposer,
          $$FailureRecordsTableAnnotationComposer,
          $$FailureRecordsTableCreateCompanionBuilder,
          $$FailureRecordsTableUpdateCompanionBuilder,
          (FailureRecordRow, $$FailureRecordsTableReferences),
          FailureRecordRow,
          PrefetchHooks Function({bool missionId})
        > {
  $$FailureRecordsTableTableManager(
    _$AppDatabase db,
    $FailureRecordsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$FailureRecordsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$FailureRecordsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$FailureRecordsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> missionId = const Value.absent(),
                Value<String> trigger = const Value.absent(),
                Value<int> occurredAt = const Value.absent(),
                Value<String?> userReasonCategory = const Value.absent(),
                Value<String?> userReasonText = const Value.absent(),
                Value<int> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => FailureRecordsCompanion(
                id: id,
                missionId: missionId,
                trigger: trigger,
                occurredAt: occurredAt,
                userReasonCategory: userReasonCategory,
                userReasonText: userReasonText,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String missionId,
                required String trigger,
                required int occurredAt,
                Value<String?> userReasonCategory = const Value.absent(),
                Value<String?> userReasonText = const Value.absent(),
                required int createdAt,
                Value<int> rowid = const Value.absent(),
              }) => FailureRecordsCompanion.insert(
                id: id,
                missionId: missionId,
                trigger: trigger,
                occurredAt: occurredAt,
                userReasonCategory: userReasonCategory,
                userReasonText: userReasonText,
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$FailureRecordsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({missionId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (missionId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.missionId,
                                referencedTable: $$FailureRecordsTableReferences
                                    ._missionIdTable(db),
                                referencedColumn:
                                    $$FailureRecordsTableReferences
                                        ._missionIdTable(db)
                                        .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$FailureRecordsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $FailureRecordsTable,
      FailureRecordRow,
      $$FailureRecordsTableFilterComposer,
      $$FailureRecordsTableOrderingComposer,
      $$FailureRecordsTableAnnotationComposer,
      $$FailureRecordsTableCreateCompanionBuilder,
      $$FailureRecordsTableUpdateCompanionBuilder,
      (FailureRecordRow, $$FailureRecordsTableReferences),
      FailureRecordRow,
      PrefetchHooks Function({bool missionId})
    >;
typedef $$EvidenceRecordsTableCreateCompanionBuilder =
    EvidenceRecordsCompanion Function({
      required String id,
      required String missionId,
      required String submissionId,
      Value<String?> recordId,
      required String type,
      required String source,
      Value<String?> content,
      Value<String?> attachmentStorageKey,
      Value<String?> attachmentFileName,
      Value<String?> attachmentMimeType,
      Value<int?> capturedAt,
      required int submittedAt,
      Value<String?> supersedesEvidenceId,
      Value<int> rowid,
    });
typedef $$EvidenceRecordsTableUpdateCompanionBuilder =
    EvidenceRecordsCompanion Function({
      Value<String> id,
      Value<String> missionId,
      Value<String> submissionId,
      Value<String?> recordId,
      Value<String> type,
      Value<String> source,
      Value<String?> content,
      Value<String?> attachmentStorageKey,
      Value<String?> attachmentFileName,
      Value<String?> attachmentMimeType,
      Value<int?> capturedAt,
      Value<int> submittedAt,
      Value<String?> supersedesEvidenceId,
      Value<int> rowid,
    });

final class $$EvidenceRecordsTableReferences
    extends BaseReferences<_$AppDatabase, $EvidenceRecordsTable, EvidenceRow> {
  $$EvidenceRecordsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $MissionsTable _missionIdTable(_$AppDatabase db) =>
      db.missions.createAlias('evidence_records__mission_id__missions__id');

  $$MissionsTableProcessedTableManager get missionId {
    final $_column = $_itemColumn<String>('mission_id')!;

    final manager = $$MissionsTableTableManager(
      $_db,
      $_db.missions,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_missionIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $EvidenceRecordsTable _supersedesEvidenceIdTable(_$AppDatabase db) =>
      db.evidenceRecords.createAlias(
        'evidence_records__supersedes_evidence_id__evidence_records__id',
      );

  $$EvidenceRecordsTableProcessedTableManager? get supersedesEvidenceId {
    final $_column = $_itemColumn<String>('supersedes_evidence_id');
    if ($_column == null) return null;
    final manager = $$EvidenceRecordsTableTableManager(
      $_db,
      $_db.evidenceRecords,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(
      _supersedesEvidenceIdTable($_db),
    );
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$EvidenceRecordsTableFilterComposer
    extends Composer<_$AppDatabase, $EvidenceRecordsTable> {
  $$EvidenceRecordsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get submissionId => $composableBuilder(
    column: $table.submissionId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get recordId => $composableBuilder(
    column: $table.recordId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get source => $composableBuilder(
    column: $table.source,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get content => $composableBuilder(
    column: $table.content,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get attachmentStorageKey => $composableBuilder(
    column: $table.attachmentStorageKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get attachmentFileName => $composableBuilder(
    column: $table.attachmentFileName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get attachmentMimeType => $composableBuilder(
    column: $table.attachmentMimeType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get capturedAt => $composableBuilder(
    column: $table.capturedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get submittedAt => $composableBuilder(
    column: $table.submittedAt,
    builder: (column) => ColumnFilters(column),
  );

  $$MissionsTableFilterComposer get missionId {
    final $$MissionsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.missionId,
      referencedTable: $db.missions,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MissionsTableFilterComposer(
            $db: $db,
            $table: $db.missions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$EvidenceRecordsTableFilterComposer get supersedesEvidenceId {
    final $$EvidenceRecordsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.supersedesEvidenceId,
      referencedTable: $db.evidenceRecords,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$EvidenceRecordsTableFilterComposer(
            $db: $db,
            $table: $db.evidenceRecords,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$EvidenceRecordsTableOrderingComposer
    extends Composer<_$AppDatabase, $EvidenceRecordsTable> {
  $$EvidenceRecordsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get submissionId => $composableBuilder(
    column: $table.submissionId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get recordId => $composableBuilder(
    column: $table.recordId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get source => $composableBuilder(
    column: $table.source,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get content => $composableBuilder(
    column: $table.content,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get attachmentStorageKey => $composableBuilder(
    column: $table.attachmentStorageKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get attachmentFileName => $composableBuilder(
    column: $table.attachmentFileName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get attachmentMimeType => $composableBuilder(
    column: $table.attachmentMimeType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get capturedAt => $composableBuilder(
    column: $table.capturedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get submittedAt => $composableBuilder(
    column: $table.submittedAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$MissionsTableOrderingComposer get missionId {
    final $$MissionsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.missionId,
      referencedTable: $db.missions,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MissionsTableOrderingComposer(
            $db: $db,
            $table: $db.missions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$EvidenceRecordsTableOrderingComposer get supersedesEvidenceId {
    final $$EvidenceRecordsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.supersedesEvidenceId,
      referencedTable: $db.evidenceRecords,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$EvidenceRecordsTableOrderingComposer(
            $db: $db,
            $table: $db.evidenceRecords,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$EvidenceRecordsTableAnnotationComposer
    extends Composer<_$AppDatabase, $EvidenceRecordsTable> {
  $$EvidenceRecordsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get submissionId => $composableBuilder(
    column: $table.submissionId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get recordId =>
      $composableBuilder(column: $table.recordId, builder: (column) => column);

  GeneratedColumn<String> get type =>
      $composableBuilder(column: $table.type, builder: (column) => column);

  GeneratedColumn<String> get source =>
      $composableBuilder(column: $table.source, builder: (column) => column);

  GeneratedColumn<String> get content =>
      $composableBuilder(column: $table.content, builder: (column) => column);

  GeneratedColumn<String> get attachmentStorageKey => $composableBuilder(
    column: $table.attachmentStorageKey,
    builder: (column) => column,
  );

  GeneratedColumn<String> get attachmentFileName => $composableBuilder(
    column: $table.attachmentFileName,
    builder: (column) => column,
  );

  GeneratedColumn<String> get attachmentMimeType => $composableBuilder(
    column: $table.attachmentMimeType,
    builder: (column) => column,
  );

  GeneratedColumn<int> get capturedAt => $composableBuilder(
    column: $table.capturedAt,
    builder: (column) => column,
  );

  GeneratedColumn<int> get submittedAt => $composableBuilder(
    column: $table.submittedAt,
    builder: (column) => column,
  );

  $$MissionsTableAnnotationComposer get missionId {
    final $$MissionsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.missionId,
      referencedTable: $db.missions,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MissionsTableAnnotationComposer(
            $db: $db,
            $table: $db.missions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$EvidenceRecordsTableAnnotationComposer get supersedesEvidenceId {
    final $$EvidenceRecordsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.supersedesEvidenceId,
      referencedTable: $db.evidenceRecords,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$EvidenceRecordsTableAnnotationComposer(
            $db: $db,
            $table: $db.evidenceRecords,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$EvidenceRecordsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $EvidenceRecordsTable,
          EvidenceRow,
          $$EvidenceRecordsTableFilterComposer,
          $$EvidenceRecordsTableOrderingComposer,
          $$EvidenceRecordsTableAnnotationComposer,
          $$EvidenceRecordsTableCreateCompanionBuilder,
          $$EvidenceRecordsTableUpdateCompanionBuilder,
          (EvidenceRow, $$EvidenceRecordsTableReferences),
          EvidenceRow,
          PrefetchHooks Function({bool missionId, bool supersedesEvidenceId})
        > {
  $$EvidenceRecordsTableTableManager(
    _$AppDatabase db,
    $EvidenceRecordsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$EvidenceRecordsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$EvidenceRecordsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$EvidenceRecordsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> missionId = const Value.absent(),
                Value<String> submissionId = const Value.absent(),
                Value<String?> recordId = const Value.absent(),
                Value<String> type = const Value.absent(),
                Value<String> source = const Value.absent(),
                Value<String?> content = const Value.absent(),
                Value<String?> attachmentStorageKey = const Value.absent(),
                Value<String?> attachmentFileName = const Value.absent(),
                Value<String?> attachmentMimeType = const Value.absent(),
                Value<int?> capturedAt = const Value.absent(),
                Value<int> submittedAt = const Value.absent(),
                Value<String?> supersedesEvidenceId = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => EvidenceRecordsCompanion(
                id: id,
                missionId: missionId,
                submissionId: submissionId,
                recordId: recordId,
                type: type,
                source: source,
                content: content,
                attachmentStorageKey: attachmentStorageKey,
                attachmentFileName: attachmentFileName,
                attachmentMimeType: attachmentMimeType,
                capturedAt: capturedAt,
                submittedAt: submittedAt,
                supersedesEvidenceId: supersedesEvidenceId,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String missionId,
                required String submissionId,
                Value<String?> recordId = const Value.absent(),
                required String type,
                required String source,
                Value<String?> content = const Value.absent(),
                Value<String?> attachmentStorageKey = const Value.absent(),
                Value<String?> attachmentFileName = const Value.absent(),
                Value<String?> attachmentMimeType = const Value.absent(),
                Value<int?> capturedAt = const Value.absent(),
                required int submittedAt,
                Value<String?> supersedesEvidenceId = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => EvidenceRecordsCompanion.insert(
                id: id,
                missionId: missionId,
                submissionId: submissionId,
                recordId: recordId,
                type: type,
                source: source,
                content: content,
                attachmentStorageKey: attachmentStorageKey,
                attachmentFileName: attachmentFileName,
                attachmentMimeType: attachmentMimeType,
                capturedAt: capturedAt,
                submittedAt: submittedAt,
                supersedesEvidenceId: supersedesEvidenceId,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$EvidenceRecordsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({missionId = false, supersedesEvidenceId = false}) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [],
                  addJoins:
                      <
                        T extends TableManagerState<
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic
                        >
                      >(state) {
                        if (missionId) {
                          state =
                              state.withJoin(
                                    currentTable: table,
                                    currentColumn: table.missionId,
                                    referencedTable:
                                        $$EvidenceRecordsTableReferences
                                            ._missionIdTable(db),
                                    referencedColumn:
                                        $$EvidenceRecordsTableReferences
                                            ._missionIdTable(db)
                                            .id,
                                  )
                                  as T;
                        }
                        if (supersedesEvidenceId) {
                          state =
                              state.withJoin(
                                    currentTable: table,
                                    currentColumn: table.supersedesEvidenceId,
                                    referencedTable:
                                        $$EvidenceRecordsTableReferences
                                            ._supersedesEvidenceIdTable(db),
                                    referencedColumn:
                                        $$EvidenceRecordsTableReferences
                                            ._supersedesEvidenceIdTable(db)
                                            .id,
                                  )
                                  as T;
                        }

                        return state;
                      },
                  getPrefetchedDataCallback: (items) async {
                    return [];
                  },
                );
              },
        ),
      );
}

typedef $$EvidenceRecordsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $EvidenceRecordsTable,
      EvidenceRow,
      $$EvidenceRecordsTableFilterComposer,
      $$EvidenceRecordsTableOrderingComposer,
      $$EvidenceRecordsTableAnnotationComposer,
      $$EvidenceRecordsTableCreateCompanionBuilder,
      $$EvidenceRecordsTableUpdateCompanionBuilder,
      (EvidenceRow, $$EvidenceRecordsTableReferences),
      EvidenceRow,
      PrefetchHooks Function({bool missionId, bool supersedesEvidenceId})
    >;
typedef $$ImportReceiptsTableCreateCompanionBuilder =
    ImportReceiptsCompanion Function({
      required String schemaName,
      required String packageId,
      required int schemaVersion,
      required String payloadSha256,
      required String contentSha256,
      required String goalId,
      required int importedAt,
      required int nodeCount,
      required int missionCount,
      Value<int> rowid,
    });
typedef $$ImportReceiptsTableUpdateCompanionBuilder =
    ImportReceiptsCompanion Function({
      Value<String> schemaName,
      Value<String> packageId,
      Value<int> schemaVersion,
      Value<String> payloadSha256,
      Value<String> contentSha256,
      Value<String> goalId,
      Value<int> importedAt,
      Value<int> nodeCount,
      Value<int> missionCount,
      Value<int> rowid,
    });

final class $$ImportReceiptsTableReferences
    extends BaseReferences<_$AppDatabase, $ImportReceiptsTable, ImportReceipt> {
  $$ImportReceiptsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $GoalsTable _goalIdTable(_$AppDatabase db) =>
      db.goals.createAlias('import_receipts__goal_id__goals__id');

  $$GoalsTableProcessedTableManager get goalId {
    final $_column = $_itemColumn<String>('goal_id')!;

    final manager = $$GoalsTableTableManager(
      $_db,
      $_db.goals,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_goalIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$ImportReceiptsTableFilterComposer
    extends Composer<_$AppDatabase, $ImportReceiptsTable> {
  $$ImportReceiptsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get schemaName => $composableBuilder(
    column: $table.schemaName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get packageId => $composableBuilder(
    column: $table.packageId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get schemaVersion => $composableBuilder(
    column: $table.schemaVersion,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get payloadSha256 => $composableBuilder(
    column: $table.payloadSha256,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get contentSha256 => $composableBuilder(
    column: $table.contentSha256,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get importedAt => $composableBuilder(
    column: $table.importedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get nodeCount => $composableBuilder(
    column: $table.nodeCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get missionCount => $composableBuilder(
    column: $table.missionCount,
    builder: (column) => ColumnFilters(column),
  );

  $$GoalsTableFilterComposer get goalId {
    final $$GoalsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.goalId,
      referencedTable: $db.goals,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$GoalsTableFilterComposer(
            $db: $db,
            $table: $db.goals,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ImportReceiptsTableOrderingComposer
    extends Composer<_$AppDatabase, $ImportReceiptsTable> {
  $$ImportReceiptsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get schemaName => $composableBuilder(
    column: $table.schemaName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get packageId => $composableBuilder(
    column: $table.packageId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get schemaVersion => $composableBuilder(
    column: $table.schemaVersion,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get payloadSha256 => $composableBuilder(
    column: $table.payloadSha256,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get contentSha256 => $composableBuilder(
    column: $table.contentSha256,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get importedAt => $composableBuilder(
    column: $table.importedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get nodeCount => $composableBuilder(
    column: $table.nodeCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get missionCount => $composableBuilder(
    column: $table.missionCount,
    builder: (column) => ColumnOrderings(column),
  );

  $$GoalsTableOrderingComposer get goalId {
    final $$GoalsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.goalId,
      referencedTable: $db.goals,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$GoalsTableOrderingComposer(
            $db: $db,
            $table: $db.goals,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ImportReceiptsTableAnnotationComposer
    extends Composer<_$AppDatabase, $ImportReceiptsTable> {
  $$ImportReceiptsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get schemaName => $composableBuilder(
    column: $table.schemaName,
    builder: (column) => column,
  );

  GeneratedColumn<String> get packageId =>
      $composableBuilder(column: $table.packageId, builder: (column) => column);

  GeneratedColumn<int> get schemaVersion => $composableBuilder(
    column: $table.schemaVersion,
    builder: (column) => column,
  );

  GeneratedColumn<String> get payloadSha256 => $composableBuilder(
    column: $table.payloadSha256,
    builder: (column) => column,
  );

  GeneratedColumn<String> get contentSha256 => $composableBuilder(
    column: $table.contentSha256,
    builder: (column) => column,
  );

  GeneratedColumn<int> get importedAt => $composableBuilder(
    column: $table.importedAt,
    builder: (column) => column,
  );

  GeneratedColumn<int> get nodeCount =>
      $composableBuilder(column: $table.nodeCount, builder: (column) => column);

  GeneratedColumn<int> get missionCount => $composableBuilder(
    column: $table.missionCount,
    builder: (column) => column,
  );

  $$GoalsTableAnnotationComposer get goalId {
    final $$GoalsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.goalId,
      referencedTable: $db.goals,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$GoalsTableAnnotationComposer(
            $db: $db,
            $table: $db.goals,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ImportReceiptsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ImportReceiptsTable,
          ImportReceipt,
          $$ImportReceiptsTableFilterComposer,
          $$ImportReceiptsTableOrderingComposer,
          $$ImportReceiptsTableAnnotationComposer,
          $$ImportReceiptsTableCreateCompanionBuilder,
          $$ImportReceiptsTableUpdateCompanionBuilder,
          (ImportReceipt, $$ImportReceiptsTableReferences),
          ImportReceipt,
          PrefetchHooks Function({bool goalId})
        > {
  $$ImportReceiptsTableTableManager(
    _$AppDatabase db,
    $ImportReceiptsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ImportReceiptsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ImportReceiptsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ImportReceiptsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> schemaName = const Value.absent(),
                Value<String> packageId = const Value.absent(),
                Value<int> schemaVersion = const Value.absent(),
                Value<String> payloadSha256 = const Value.absent(),
                Value<String> contentSha256 = const Value.absent(),
                Value<String> goalId = const Value.absent(),
                Value<int> importedAt = const Value.absent(),
                Value<int> nodeCount = const Value.absent(),
                Value<int> missionCount = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ImportReceiptsCompanion(
                schemaName: schemaName,
                packageId: packageId,
                schemaVersion: schemaVersion,
                payloadSha256: payloadSha256,
                contentSha256: contentSha256,
                goalId: goalId,
                importedAt: importedAt,
                nodeCount: nodeCount,
                missionCount: missionCount,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String schemaName,
                required String packageId,
                required int schemaVersion,
                required String payloadSha256,
                required String contentSha256,
                required String goalId,
                required int importedAt,
                required int nodeCount,
                required int missionCount,
                Value<int> rowid = const Value.absent(),
              }) => ImportReceiptsCompanion.insert(
                schemaName: schemaName,
                packageId: packageId,
                schemaVersion: schemaVersion,
                payloadSha256: payloadSha256,
                contentSha256: contentSha256,
                goalId: goalId,
                importedAt: importedAt,
                nodeCount: nodeCount,
                missionCount: missionCount,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$ImportReceiptsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({goalId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (goalId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.goalId,
                                referencedTable: $$ImportReceiptsTableReferences
                                    ._goalIdTable(db),
                                referencedColumn:
                                    $$ImportReceiptsTableReferences
                                        ._goalIdTable(db)
                                        .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$ImportReceiptsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ImportReceiptsTable,
      ImportReceipt,
      $$ImportReceiptsTableFilterComposer,
      $$ImportReceiptsTableOrderingComposer,
      $$ImportReceiptsTableAnnotationComposer,
      $$ImportReceiptsTableCreateCompanionBuilder,
      $$ImportReceiptsTableUpdateCompanionBuilder,
      (ImportReceipt, $$ImportReceiptsTableReferences),
      ImportReceipt,
      PrefetchHooks Function({bool goalId})
    >;
typedef $$AssistantSessionsTableCreateCompanionBuilder =
    AssistantSessionsCompanion Function({
      required String id,
      required String title,
      required int createdAt,
      required int updatedAt,
      Value<String?> missionId,
      Value<String?> nodeId,
      Value<String?> goalId,
      Value<String?> writerToken,
      Value<int?> writerLeaseUntil,
      Value<int> rowid,
    });
typedef $$AssistantSessionsTableUpdateCompanionBuilder =
    AssistantSessionsCompanion Function({
      Value<String> id,
      Value<String> title,
      Value<int> createdAt,
      Value<int> updatedAt,
      Value<String?> missionId,
      Value<String?> nodeId,
      Value<String?> goalId,
      Value<String?> writerToken,
      Value<int?> writerLeaseUntil,
      Value<int> rowid,
    });

final class $$AssistantSessionsTableReferences
    extends
        BaseReferences<
          _$AppDatabase,
          $AssistantSessionsTable,
          AssistantSession
        > {
  $$AssistantSessionsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static MultiTypedResultKey<
    $AssistantSessionRecordsTable,
    List<AssistantSessionRecord>
  >
  _assistantSessionRecordsRefsTable(_$AppDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.assistantSessionRecords,
        aliasName:
            'assistant_sessions__id__assistant_session_records__session_id',
      );

  $$AssistantSessionRecordsTableProcessedTableManager
  get assistantSessionRecordsRefs {
    final manager = $$AssistantSessionRecordsTableTableManager(
      $_db,
      $_db.assistantSessionRecords,
    ).filter((f) => f.sessionId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _assistantSessionRecordsRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$AssistantSessionsTableFilterComposer
    extends Composer<_$AppDatabase, $AssistantSessionsTable> {
  $$AssistantSessionsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get missionId => $composableBuilder(
    column: $table.missionId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get nodeId => $composableBuilder(
    column: $table.nodeId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get goalId => $composableBuilder(
    column: $table.goalId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get writerToken => $composableBuilder(
    column: $table.writerToken,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get writerLeaseUntil => $composableBuilder(
    column: $table.writerLeaseUntil,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> assistantSessionRecordsRefs(
    Expression<bool> Function($$AssistantSessionRecordsTableFilterComposer f) f,
  ) {
    final $$AssistantSessionRecordsTableFilterComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.assistantSessionRecords,
          getReferencedColumn: (t) => t.sessionId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$AssistantSessionRecordsTableFilterComposer(
                $db: $db,
                $table: $db.assistantSessionRecords,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }
}

class $$AssistantSessionsTableOrderingComposer
    extends Composer<_$AppDatabase, $AssistantSessionsTable> {
  $$AssistantSessionsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get missionId => $composableBuilder(
    column: $table.missionId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get nodeId => $composableBuilder(
    column: $table.nodeId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get goalId => $composableBuilder(
    column: $table.goalId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get writerToken => $composableBuilder(
    column: $table.writerToken,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get writerLeaseUntil => $composableBuilder(
    column: $table.writerLeaseUntil,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$AssistantSessionsTableAnnotationComposer
    extends Composer<_$AppDatabase, $AssistantSessionsTable> {
  $$AssistantSessionsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<String> get missionId =>
      $composableBuilder(column: $table.missionId, builder: (column) => column);

  GeneratedColumn<String> get nodeId =>
      $composableBuilder(column: $table.nodeId, builder: (column) => column);

  GeneratedColumn<String> get goalId =>
      $composableBuilder(column: $table.goalId, builder: (column) => column);

  GeneratedColumn<String> get writerToken => $composableBuilder(
    column: $table.writerToken,
    builder: (column) => column,
  );

  GeneratedColumn<int> get writerLeaseUntil => $composableBuilder(
    column: $table.writerLeaseUntil,
    builder: (column) => column,
  );

  Expression<T> assistantSessionRecordsRefs<T extends Object>(
    Expression<T> Function($$AssistantSessionRecordsTableAnnotationComposer a)
    f,
  ) {
    final $$AssistantSessionRecordsTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.assistantSessionRecords,
          getReferencedColumn: (t) => t.sessionId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$AssistantSessionRecordsTableAnnotationComposer(
                $db: $db,
                $table: $db.assistantSessionRecords,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }
}

class $$AssistantSessionsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $AssistantSessionsTable,
          AssistantSession,
          $$AssistantSessionsTableFilterComposer,
          $$AssistantSessionsTableOrderingComposer,
          $$AssistantSessionsTableAnnotationComposer,
          $$AssistantSessionsTableCreateCompanionBuilder,
          $$AssistantSessionsTableUpdateCompanionBuilder,
          (AssistantSession, $$AssistantSessionsTableReferences),
          AssistantSession,
          PrefetchHooks Function({bool assistantSessionRecordsRefs})
        > {
  $$AssistantSessionsTableTableManager(
    _$AppDatabase db,
    $AssistantSessionsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AssistantSessionsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AssistantSessionsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AssistantSessionsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<int> createdAt = const Value.absent(),
                Value<int> updatedAt = const Value.absent(),
                Value<String?> missionId = const Value.absent(),
                Value<String?> nodeId = const Value.absent(),
                Value<String?> goalId = const Value.absent(),
                Value<String?> writerToken = const Value.absent(),
                Value<int?> writerLeaseUntil = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => AssistantSessionsCompanion(
                id: id,
                title: title,
                createdAt: createdAt,
                updatedAt: updatedAt,
                missionId: missionId,
                nodeId: nodeId,
                goalId: goalId,
                writerToken: writerToken,
                writerLeaseUntil: writerLeaseUntil,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String title,
                required int createdAt,
                required int updatedAt,
                Value<String?> missionId = const Value.absent(),
                Value<String?> nodeId = const Value.absent(),
                Value<String?> goalId = const Value.absent(),
                Value<String?> writerToken = const Value.absent(),
                Value<int?> writerLeaseUntil = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => AssistantSessionsCompanion.insert(
                id: id,
                title: title,
                createdAt: createdAt,
                updatedAt: updatedAt,
                missionId: missionId,
                nodeId: nodeId,
                goalId: goalId,
                writerToken: writerToken,
                writerLeaseUntil: writerLeaseUntil,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$AssistantSessionsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({assistantSessionRecordsRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [
                if (assistantSessionRecordsRefs) db.assistantSessionRecords,
              ],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (assistantSessionRecordsRefs)
                    await $_getPrefetchedData<
                      AssistantSession,
                      $AssistantSessionsTable,
                      AssistantSessionRecord
                    >(
                      currentTable: table,
                      referencedTable: $$AssistantSessionsTableReferences
                          ._assistantSessionRecordsRefsTable(db),
                      managerFromTypedResult: (p0) =>
                          $$AssistantSessionsTableReferences(
                            db,
                            table,
                            p0,
                          ).assistantSessionRecordsRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where((e) => e.sessionId == item.id),
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$AssistantSessionsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $AssistantSessionsTable,
      AssistantSession,
      $$AssistantSessionsTableFilterComposer,
      $$AssistantSessionsTableOrderingComposer,
      $$AssistantSessionsTableAnnotationComposer,
      $$AssistantSessionsTableCreateCompanionBuilder,
      $$AssistantSessionsTableUpdateCompanionBuilder,
      (AssistantSession, $$AssistantSessionsTableReferences),
      AssistantSession,
      PrefetchHooks Function({bool assistantSessionRecordsRefs})
    >;
typedef $$AssistantSessionRecordsTableCreateCompanionBuilder =
    AssistantSessionRecordsCompanion Function({
      required String sessionId,
      required int sequence,
      required int timestamp,
      required String type,
      required String data,
      Value<int> version,
      Value<bool> ignorable,
      Value<int> rowid,
    });
typedef $$AssistantSessionRecordsTableUpdateCompanionBuilder =
    AssistantSessionRecordsCompanion Function({
      Value<String> sessionId,
      Value<int> sequence,
      Value<int> timestamp,
      Value<String> type,
      Value<String> data,
      Value<int> version,
      Value<bool> ignorable,
      Value<int> rowid,
    });

final class $$AssistantSessionRecordsTableReferences
    extends
        BaseReferences<
          _$AppDatabase,
          $AssistantSessionRecordsTable,
          AssistantSessionRecord
        > {
  $$AssistantSessionRecordsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $AssistantSessionsTable _sessionIdTable(_$AppDatabase db) =>
      db.assistantSessions.createAlias(
        'assistant_session_records__session_id__assistant_sessions__id',
      );

  $$AssistantSessionsTableProcessedTableManager get sessionId {
    final $_column = $_itemColumn<String>('session_id')!;

    final manager = $$AssistantSessionsTableTableManager(
      $_db,
      $_db.assistantSessions,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_sessionIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$AssistantSessionRecordsTableFilterComposer
    extends Composer<_$AppDatabase, $AssistantSessionRecordsTable> {
  $$AssistantSessionRecordsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get sequence => $composableBuilder(
    column: $table.sequence,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get timestamp => $composableBuilder(
    column: $table.timestamp,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get data => $composableBuilder(
    column: $table.data,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get ignorable => $composableBuilder(
    column: $table.ignorable,
    builder: (column) => ColumnFilters(column),
  );

  $$AssistantSessionsTableFilterComposer get sessionId {
    final $$AssistantSessionsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.sessionId,
      referencedTable: $db.assistantSessions,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AssistantSessionsTableFilterComposer(
            $db: $db,
            $table: $db.assistantSessions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$AssistantSessionRecordsTableOrderingComposer
    extends Composer<_$AppDatabase, $AssistantSessionRecordsTable> {
  $$AssistantSessionRecordsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get sequence => $composableBuilder(
    column: $table.sequence,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get timestamp => $composableBuilder(
    column: $table.timestamp,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get data => $composableBuilder(
    column: $table.data,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get ignorable => $composableBuilder(
    column: $table.ignorable,
    builder: (column) => ColumnOrderings(column),
  );

  $$AssistantSessionsTableOrderingComposer get sessionId {
    final $$AssistantSessionsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.sessionId,
      referencedTable: $db.assistantSessions,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AssistantSessionsTableOrderingComposer(
            $db: $db,
            $table: $db.assistantSessions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$AssistantSessionRecordsTableAnnotationComposer
    extends Composer<_$AppDatabase, $AssistantSessionRecordsTable> {
  $$AssistantSessionRecordsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get sequence =>
      $composableBuilder(column: $table.sequence, builder: (column) => column);

  GeneratedColumn<int> get timestamp =>
      $composableBuilder(column: $table.timestamp, builder: (column) => column);

  GeneratedColumn<String> get type =>
      $composableBuilder(column: $table.type, builder: (column) => column);

  GeneratedColumn<String> get data =>
      $composableBuilder(column: $table.data, builder: (column) => column);

  GeneratedColumn<int> get version =>
      $composableBuilder(column: $table.version, builder: (column) => column);

  GeneratedColumn<bool> get ignorable =>
      $composableBuilder(column: $table.ignorable, builder: (column) => column);

  $$AssistantSessionsTableAnnotationComposer get sessionId {
    final $$AssistantSessionsTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.sessionId,
          referencedTable: $db.assistantSessions,
          getReferencedColumn: (t) => t.id,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$AssistantSessionsTableAnnotationComposer(
                $db: $db,
                $table: $db.assistantSessions,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return composer;
  }
}

class $$AssistantSessionRecordsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $AssistantSessionRecordsTable,
          AssistantSessionRecord,
          $$AssistantSessionRecordsTableFilterComposer,
          $$AssistantSessionRecordsTableOrderingComposer,
          $$AssistantSessionRecordsTableAnnotationComposer,
          $$AssistantSessionRecordsTableCreateCompanionBuilder,
          $$AssistantSessionRecordsTableUpdateCompanionBuilder,
          (AssistantSessionRecord, $$AssistantSessionRecordsTableReferences),
          AssistantSessionRecord,
          PrefetchHooks Function({bool sessionId})
        > {
  $$AssistantSessionRecordsTableTableManager(
    _$AppDatabase db,
    $AssistantSessionRecordsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AssistantSessionRecordsTableFilterComposer(
                $db: db,
                $table: table,
              ),
          createOrderingComposer: () =>
              $$AssistantSessionRecordsTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$AssistantSessionRecordsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> sessionId = const Value.absent(),
                Value<int> sequence = const Value.absent(),
                Value<int> timestamp = const Value.absent(),
                Value<String> type = const Value.absent(),
                Value<String> data = const Value.absent(),
                Value<int> version = const Value.absent(),
                Value<bool> ignorable = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => AssistantSessionRecordsCompanion(
                sessionId: sessionId,
                sequence: sequence,
                timestamp: timestamp,
                type: type,
                data: data,
                version: version,
                ignorable: ignorable,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String sessionId,
                required int sequence,
                required int timestamp,
                required String type,
                required String data,
                Value<int> version = const Value.absent(),
                Value<bool> ignorable = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => AssistantSessionRecordsCompanion.insert(
                sessionId: sessionId,
                sequence: sequence,
                timestamp: timestamp,
                type: type,
                data: data,
                version: version,
                ignorable: ignorable,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$AssistantSessionRecordsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({sessionId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (sessionId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.sessionId,
                                referencedTable:
                                    $$AssistantSessionRecordsTableReferences
                                        ._sessionIdTable(db),
                                referencedColumn:
                                    $$AssistantSessionRecordsTableReferences
                                        ._sessionIdTable(db)
                                        .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$AssistantSessionRecordsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $AssistantSessionRecordsTable,
      AssistantSessionRecord,
      $$AssistantSessionRecordsTableFilterComposer,
      $$AssistantSessionRecordsTableOrderingComposer,
      $$AssistantSessionRecordsTableAnnotationComposer,
      $$AssistantSessionRecordsTableCreateCompanionBuilder,
      $$AssistantSessionRecordsTableUpdateCompanionBuilder,
      (AssistantSessionRecord, $$AssistantSessionRecordsTableReferences),
      AssistantSessionRecord,
      PrefetchHooks Function({bool sessionId})
    >;
typedef $$OperationReceiptsTableCreateCompanionBuilder =
    OperationReceiptsCompanion Function({
      required String id,
      required String kind,
      required String fingerprint,
      required String entityId,
      required String resultJson,
      required int createdAt,
      Value<int> rowid,
    });
typedef $$OperationReceiptsTableUpdateCompanionBuilder =
    OperationReceiptsCompanion Function({
      Value<String> id,
      Value<String> kind,
      Value<String> fingerprint,
      Value<String> entityId,
      Value<String> resultJson,
      Value<int> createdAt,
      Value<int> rowid,
    });

class $$OperationReceiptsTableFilterComposer
    extends Composer<_$AppDatabase, $OperationReceiptsTable> {
  $$OperationReceiptsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get fingerprint => $composableBuilder(
    column: $table.fingerprint,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get entityId => $composableBuilder(
    column: $table.entityId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get resultJson => $composableBuilder(
    column: $table.resultJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$OperationReceiptsTableOrderingComposer
    extends Composer<_$AppDatabase, $OperationReceiptsTable> {
  $$OperationReceiptsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get fingerprint => $composableBuilder(
    column: $table.fingerprint,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get entityId => $composableBuilder(
    column: $table.entityId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get resultJson => $composableBuilder(
    column: $table.resultJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$OperationReceiptsTableAnnotationComposer
    extends Composer<_$AppDatabase, $OperationReceiptsTable> {
  $$OperationReceiptsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<String> get fingerprint => $composableBuilder(
    column: $table.fingerprint,
    builder: (column) => column,
  );

  GeneratedColumn<String> get entityId =>
      $composableBuilder(column: $table.entityId, builder: (column) => column);

  GeneratedColumn<String> get resultJson => $composableBuilder(
    column: $table.resultJson,
    builder: (column) => column,
  );

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$OperationReceiptsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $OperationReceiptsTable,
          OperationReceipt,
          $$OperationReceiptsTableFilterComposer,
          $$OperationReceiptsTableOrderingComposer,
          $$OperationReceiptsTableAnnotationComposer,
          $$OperationReceiptsTableCreateCompanionBuilder,
          $$OperationReceiptsTableUpdateCompanionBuilder,
          (
            OperationReceipt,
            BaseReferences<
              _$AppDatabase,
              $OperationReceiptsTable,
              OperationReceipt
            >,
          ),
          OperationReceipt,
          PrefetchHooks Function()
        > {
  $$OperationReceiptsTableTableManager(
    _$AppDatabase db,
    $OperationReceiptsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$OperationReceiptsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$OperationReceiptsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$OperationReceiptsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> kind = const Value.absent(),
                Value<String> fingerprint = const Value.absent(),
                Value<String> entityId = const Value.absent(),
                Value<String> resultJson = const Value.absent(),
                Value<int> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => OperationReceiptsCompanion(
                id: id,
                kind: kind,
                fingerprint: fingerprint,
                entityId: entityId,
                resultJson: resultJson,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String kind,
                required String fingerprint,
                required String entityId,
                required String resultJson,
                required int createdAt,
                Value<int> rowid = const Value.absent(),
              }) => OperationReceiptsCompanion.insert(
                id: id,
                kind: kind,
                fingerprint: fingerprint,
                entityId: entityId,
                resultJson: resultJson,
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$OperationReceiptsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $OperationReceiptsTable,
      OperationReceipt,
      $$OperationReceiptsTableFilterComposer,
      $$OperationReceiptsTableOrderingComposer,
      $$OperationReceiptsTableAnnotationComposer,
      $$OperationReceiptsTableCreateCompanionBuilder,
      $$OperationReceiptsTableUpdateCompanionBuilder,
      (
        OperationReceipt,
        BaseReferences<
          _$AppDatabase,
          $OperationReceiptsTable,
          OperationReceipt
        >,
      ),
      OperationReceipt,
      PrefetchHooks Function()
    >;
typedef $$RecordsTableCreateCompanionBuilder =
    RecordsCompanion Function({
      required String id,
      required String type,
      required String source,
      Value<String?> content,
      Value<String?> attachmentStorageKey,
      Value<String?> attachmentFileName,
      Value<String?> attachmentMimeType,
      Value<int?> capturedAt,
      required int occurredAt,
      required int createdAt,
      Value<String?> goalId,
      Value<String?> goalNodeId,
      Value<int> rowid,
    });
typedef $$RecordsTableUpdateCompanionBuilder =
    RecordsCompanion Function({
      Value<String> id,
      Value<String> type,
      Value<String> source,
      Value<String?> content,
      Value<String?> attachmentStorageKey,
      Value<String?> attachmentFileName,
      Value<String?> attachmentMimeType,
      Value<int?> capturedAt,
      Value<int> occurredAt,
      Value<int> createdAt,
      Value<String?> goalId,
      Value<String?> goalNodeId,
      Value<int> rowid,
    });

final class $$RecordsTableReferences
    extends BaseReferences<_$AppDatabase, $RecordsTable, RecordRow> {
  $$RecordsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $GoalsTable _goalIdTable(_$AppDatabase db) =>
      db.goals.createAlias('records__goal_id__goals__id');

  $$GoalsTableProcessedTableManager? get goalId {
    final $_column = $_itemColumn<String>('goal_id');
    if ($_column == null) return null;
    final manager = $$GoalsTableTableManager(
      $_db,
      $_db.goals,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_goalIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $GoalNodesTable _goalNodeIdTable(_$AppDatabase db) =>
      db.goalNodes.createAlias('records__goal_node_id__goal_nodes__id');

  $$GoalNodesTableProcessedTableManager? get goalNodeId {
    final $_column = $_itemColumn<String>('goal_node_id');
    if ($_column == null) return null;
    final manager = $$GoalNodesTableTableManager(
      $_db,
      $_db.goalNodes,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_goalNodeIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$RecordsTableFilterComposer
    extends Composer<_$AppDatabase, $RecordsTable> {
  $$RecordsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get source => $composableBuilder(
    column: $table.source,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get content => $composableBuilder(
    column: $table.content,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get attachmentStorageKey => $composableBuilder(
    column: $table.attachmentStorageKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get attachmentFileName => $composableBuilder(
    column: $table.attachmentFileName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get attachmentMimeType => $composableBuilder(
    column: $table.attachmentMimeType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get capturedAt => $composableBuilder(
    column: $table.capturedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get occurredAt => $composableBuilder(
    column: $table.occurredAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  $$GoalsTableFilterComposer get goalId {
    final $$GoalsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.goalId,
      referencedTable: $db.goals,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$GoalsTableFilterComposer(
            $db: $db,
            $table: $db.goals,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$GoalNodesTableFilterComposer get goalNodeId {
    final $$GoalNodesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.goalNodeId,
      referencedTable: $db.goalNodes,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$GoalNodesTableFilterComposer(
            $db: $db,
            $table: $db.goalNodes,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$RecordsTableOrderingComposer
    extends Composer<_$AppDatabase, $RecordsTable> {
  $$RecordsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get source => $composableBuilder(
    column: $table.source,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get content => $composableBuilder(
    column: $table.content,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get attachmentStorageKey => $composableBuilder(
    column: $table.attachmentStorageKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get attachmentFileName => $composableBuilder(
    column: $table.attachmentFileName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get attachmentMimeType => $composableBuilder(
    column: $table.attachmentMimeType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get capturedAt => $composableBuilder(
    column: $table.capturedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get occurredAt => $composableBuilder(
    column: $table.occurredAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$GoalsTableOrderingComposer get goalId {
    final $$GoalsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.goalId,
      referencedTable: $db.goals,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$GoalsTableOrderingComposer(
            $db: $db,
            $table: $db.goals,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$GoalNodesTableOrderingComposer get goalNodeId {
    final $$GoalNodesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.goalNodeId,
      referencedTable: $db.goalNodes,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$GoalNodesTableOrderingComposer(
            $db: $db,
            $table: $db.goalNodes,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$RecordsTableAnnotationComposer
    extends Composer<_$AppDatabase, $RecordsTable> {
  $$RecordsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get type =>
      $composableBuilder(column: $table.type, builder: (column) => column);

  GeneratedColumn<String> get source =>
      $composableBuilder(column: $table.source, builder: (column) => column);

  GeneratedColumn<String> get content =>
      $composableBuilder(column: $table.content, builder: (column) => column);

  GeneratedColumn<String> get attachmentStorageKey => $composableBuilder(
    column: $table.attachmentStorageKey,
    builder: (column) => column,
  );

  GeneratedColumn<String> get attachmentFileName => $composableBuilder(
    column: $table.attachmentFileName,
    builder: (column) => column,
  );

  GeneratedColumn<String> get attachmentMimeType => $composableBuilder(
    column: $table.attachmentMimeType,
    builder: (column) => column,
  );

  GeneratedColumn<int> get capturedAt => $composableBuilder(
    column: $table.capturedAt,
    builder: (column) => column,
  );

  GeneratedColumn<int> get occurredAt => $composableBuilder(
    column: $table.occurredAt,
    builder: (column) => column,
  );

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  $$GoalsTableAnnotationComposer get goalId {
    final $$GoalsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.goalId,
      referencedTable: $db.goals,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$GoalsTableAnnotationComposer(
            $db: $db,
            $table: $db.goals,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$GoalNodesTableAnnotationComposer get goalNodeId {
    final $$GoalNodesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.goalNodeId,
      referencedTable: $db.goalNodes,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$GoalNodesTableAnnotationComposer(
            $db: $db,
            $table: $db.goalNodes,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$RecordsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $RecordsTable,
          RecordRow,
          $$RecordsTableFilterComposer,
          $$RecordsTableOrderingComposer,
          $$RecordsTableAnnotationComposer,
          $$RecordsTableCreateCompanionBuilder,
          $$RecordsTableUpdateCompanionBuilder,
          (RecordRow, $$RecordsTableReferences),
          RecordRow,
          PrefetchHooks Function({bool goalId, bool goalNodeId})
        > {
  $$RecordsTableTableManager(_$AppDatabase db, $RecordsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$RecordsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$RecordsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$RecordsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> type = const Value.absent(),
                Value<String> source = const Value.absent(),
                Value<String?> content = const Value.absent(),
                Value<String?> attachmentStorageKey = const Value.absent(),
                Value<String?> attachmentFileName = const Value.absent(),
                Value<String?> attachmentMimeType = const Value.absent(),
                Value<int?> capturedAt = const Value.absent(),
                Value<int> occurredAt = const Value.absent(),
                Value<int> createdAt = const Value.absent(),
                Value<String?> goalId = const Value.absent(),
                Value<String?> goalNodeId = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => RecordsCompanion(
                id: id,
                type: type,
                source: source,
                content: content,
                attachmentStorageKey: attachmentStorageKey,
                attachmentFileName: attachmentFileName,
                attachmentMimeType: attachmentMimeType,
                capturedAt: capturedAt,
                occurredAt: occurredAt,
                createdAt: createdAt,
                goalId: goalId,
                goalNodeId: goalNodeId,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String type,
                required String source,
                Value<String?> content = const Value.absent(),
                Value<String?> attachmentStorageKey = const Value.absent(),
                Value<String?> attachmentFileName = const Value.absent(),
                Value<String?> attachmentMimeType = const Value.absent(),
                Value<int?> capturedAt = const Value.absent(),
                required int occurredAt,
                required int createdAt,
                Value<String?> goalId = const Value.absent(),
                Value<String?> goalNodeId = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => RecordsCompanion.insert(
                id: id,
                type: type,
                source: source,
                content: content,
                attachmentStorageKey: attachmentStorageKey,
                attachmentFileName: attachmentFileName,
                attachmentMimeType: attachmentMimeType,
                capturedAt: capturedAt,
                occurredAt: occurredAt,
                createdAt: createdAt,
                goalId: goalId,
                goalNodeId: goalNodeId,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$RecordsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({goalId = false, goalNodeId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (goalId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.goalId,
                                referencedTable: $$RecordsTableReferences
                                    ._goalIdTable(db),
                                referencedColumn: $$RecordsTableReferences
                                    ._goalIdTable(db)
                                    .id,
                              )
                              as T;
                    }
                    if (goalNodeId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.goalNodeId,
                                referencedTable: $$RecordsTableReferences
                                    ._goalNodeIdTable(db),
                                referencedColumn: $$RecordsTableReferences
                                    ._goalNodeIdTable(db)
                                    .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$RecordsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $RecordsTable,
      RecordRow,
      $$RecordsTableFilterComposer,
      $$RecordsTableOrderingComposer,
      $$RecordsTableAnnotationComposer,
      $$RecordsTableCreateCompanionBuilder,
      $$RecordsTableUpdateCompanionBuilder,
      (RecordRow, $$RecordsTableReferences),
      RecordRow,
      PrefetchHooks Function({bool goalId, bool goalNodeId})
    >;
typedef $$UserExecutionReportsTableCreateCompanionBuilder =
    UserExecutionReportsCompanion Function({
      required String id,
      required String missionId,
      required String occurrenceDate,
      required String timeZoneId,
      Value<int?> actualStart,
      Value<int?> actualEnd,
      required int reportedAt,
      required String basis,
      Value<String?> supersedesId,
      Value<int> rowid,
    });
typedef $$UserExecutionReportsTableUpdateCompanionBuilder =
    UserExecutionReportsCompanion Function({
      Value<String> id,
      Value<String> missionId,
      Value<String> occurrenceDate,
      Value<String> timeZoneId,
      Value<int?> actualStart,
      Value<int?> actualEnd,
      Value<int> reportedAt,
      Value<String> basis,
      Value<String?> supersedesId,
      Value<int> rowid,
    });

final class $$UserExecutionReportsTableReferences
    extends
        BaseReferences<
          _$AppDatabase,
          $UserExecutionReportsTable,
          UserExecutionReportRow
        > {
  $$UserExecutionReportsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $MissionsTable _missionIdTable(_$AppDatabase db) => db.missions
      .createAlias('user_execution_reports__mission_id__missions__id');

  $$MissionsTableProcessedTableManager get missionId {
    final $_column = $_itemColumn<String>('mission_id')!;

    final manager = $$MissionsTableTableManager(
      $_db,
      $_db.missions,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_missionIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $UserExecutionReportsTable _supersedesIdTable(_$AppDatabase db) =>
      db.userExecutionReports.createAlias(
        'user_execution_reports__supersedes_id__user_execution_reports__id',
      );

  $$UserExecutionReportsTableProcessedTableManager? get supersedesId {
    final $_column = $_itemColumn<String>('supersedes_id');
    if ($_column == null) return null;
    final manager = $$UserExecutionReportsTableTableManager(
      $_db,
      $_db.userExecutionReports,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_supersedesIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$UserExecutionReportsTableFilterComposer
    extends Composer<_$AppDatabase, $UserExecutionReportsTable> {
  $$UserExecutionReportsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get occurrenceDate => $composableBuilder(
    column: $table.occurrenceDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get timeZoneId => $composableBuilder(
    column: $table.timeZoneId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get actualStart => $composableBuilder(
    column: $table.actualStart,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get actualEnd => $composableBuilder(
    column: $table.actualEnd,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get reportedAt => $composableBuilder(
    column: $table.reportedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get basis => $composableBuilder(
    column: $table.basis,
    builder: (column) => ColumnFilters(column),
  );

  $$MissionsTableFilterComposer get missionId {
    final $$MissionsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.missionId,
      referencedTable: $db.missions,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MissionsTableFilterComposer(
            $db: $db,
            $table: $db.missions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$UserExecutionReportsTableFilterComposer get supersedesId {
    final $$UserExecutionReportsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.supersedesId,
      referencedTable: $db.userExecutionReports,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$UserExecutionReportsTableFilterComposer(
            $db: $db,
            $table: $db.userExecutionReports,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$UserExecutionReportsTableOrderingComposer
    extends Composer<_$AppDatabase, $UserExecutionReportsTable> {
  $$UserExecutionReportsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get occurrenceDate => $composableBuilder(
    column: $table.occurrenceDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get timeZoneId => $composableBuilder(
    column: $table.timeZoneId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get actualStart => $composableBuilder(
    column: $table.actualStart,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get actualEnd => $composableBuilder(
    column: $table.actualEnd,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get reportedAt => $composableBuilder(
    column: $table.reportedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get basis => $composableBuilder(
    column: $table.basis,
    builder: (column) => ColumnOrderings(column),
  );

  $$MissionsTableOrderingComposer get missionId {
    final $$MissionsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.missionId,
      referencedTable: $db.missions,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MissionsTableOrderingComposer(
            $db: $db,
            $table: $db.missions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$UserExecutionReportsTableOrderingComposer get supersedesId {
    final $$UserExecutionReportsTableOrderingComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.supersedesId,
          referencedTable: $db.userExecutionReports,
          getReferencedColumn: (t) => t.id,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$UserExecutionReportsTableOrderingComposer(
                $db: $db,
                $table: $db.userExecutionReports,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return composer;
  }
}

class $$UserExecutionReportsTableAnnotationComposer
    extends Composer<_$AppDatabase, $UserExecutionReportsTable> {
  $$UserExecutionReportsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get occurrenceDate => $composableBuilder(
    column: $table.occurrenceDate,
    builder: (column) => column,
  );

  GeneratedColumn<String> get timeZoneId => $composableBuilder(
    column: $table.timeZoneId,
    builder: (column) => column,
  );

  GeneratedColumn<int> get actualStart => $composableBuilder(
    column: $table.actualStart,
    builder: (column) => column,
  );

  GeneratedColumn<int> get actualEnd =>
      $composableBuilder(column: $table.actualEnd, builder: (column) => column);

  GeneratedColumn<int> get reportedAt => $composableBuilder(
    column: $table.reportedAt,
    builder: (column) => column,
  );

  GeneratedColumn<String> get basis =>
      $composableBuilder(column: $table.basis, builder: (column) => column);

  $$MissionsTableAnnotationComposer get missionId {
    final $$MissionsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.missionId,
      referencedTable: $db.missions,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MissionsTableAnnotationComposer(
            $db: $db,
            $table: $db.missions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$UserExecutionReportsTableAnnotationComposer get supersedesId {
    final $$UserExecutionReportsTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.supersedesId,
          referencedTable: $db.userExecutionReports,
          getReferencedColumn: (t) => t.id,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$UserExecutionReportsTableAnnotationComposer(
                $db: $db,
                $table: $db.userExecutionReports,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return composer;
  }
}

class $$UserExecutionReportsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $UserExecutionReportsTable,
          UserExecutionReportRow,
          $$UserExecutionReportsTableFilterComposer,
          $$UserExecutionReportsTableOrderingComposer,
          $$UserExecutionReportsTableAnnotationComposer,
          $$UserExecutionReportsTableCreateCompanionBuilder,
          $$UserExecutionReportsTableUpdateCompanionBuilder,
          (UserExecutionReportRow, $$UserExecutionReportsTableReferences),
          UserExecutionReportRow,
          PrefetchHooks Function({bool missionId, bool supersedesId})
        > {
  $$UserExecutionReportsTableTableManager(
    _$AppDatabase db,
    $UserExecutionReportsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$UserExecutionReportsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$UserExecutionReportsTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$UserExecutionReportsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> missionId = const Value.absent(),
                Value<String> occurrenceDate = const Value.absent(),
                Value<String> timeZoneId = const Value.absent(),
                Value<int?> actualStart = const Value.absent(),
                Value<int?> actualEnd = const Value.absent(),
                Value<int> reportedAt = const Value.absent(),
                Value<String> basis = const Value.absent(),
                Value<String?> supersedesId = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => UserExecutionReportsCompanion(
                id: id,
                missionId: missionId,
                occurrenceDate: occurrenceDate,
                timeZoneId: timeZoneId,
                actualStart: actualStart,
                actualEnd: actualEnd,
                reportedAt: reportedAt,
                basis: basis,
                supersedesId: supersedesId,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String missionId,
                required String occurrenceDate,
                required String timeZoneId,
                Value<int?> actualStart = const Value.absent(),
                Value<int?> actualEnd = const Value.absent(),
                required int reportedAt,
                required String basis,
                Value<String?> supersedesId = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => UserExecutionReportsCompanion.insert(
                id: id,
                missionId: missionId,
                occurrenceDate: occurrenceDate,
                timeZoneId: timeZoneId,
                actualStart: actualStart,
                actualEnd: actualEnd,
                reportedAt: reportedAt,
                basis: basis,
                supersedesId: supersedesId,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$UserExecutionReportsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({missionId = false, supersedesId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (missionId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.missionId,
                                referencedTable:
                                    $$UserExecutionReportsTableReferences
                                        ._missionIdTable(db),
                                referencedColumn:
                                    $$UserExecutionReportsTableReferences
                                        ._missionIdTable(db)
                                        .id,
                              )
                              as T;
                    }
                    if (supersedesId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.supersedesId,
                                referencedTable:
                                    $$UserExecutionReportsTableReferences
                                        ._supersedesIdTable(db),
                                referencedColumn:
                                    $$UserExecutionReportsTableReferences
                                        ._supersedesIdTable(db)
                                        .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$UserExecutionReportsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $UserExecutionReportsTable,
      UserExecutionReportRow,
      $$UserExecutionReportsTableFilterComposer,
      $$UserExecutionReportsTableOrderingComposer,
      $$UserExecutionReportsTableAnnotationComposer,
      $$UserExecutionReportsTableCreateCompanionBuilder,
      $$UserExecutionReportsTableUpdateCompanionBuilder,
      (UserExecutionReportRow, $$UserExecutionReportsTableReferences),
      UserExecutionReportRow,
      PrefetchHooks Function({bool missionId, bool supersedesId})
    >;
typedef $$AnalysisJobsTableCreateCompanionBuilder =
    AnalysisJobsCompanion Function({
      required String scope,
      required String targetId,
      Value<int> sourceVersion,
      Value<String> status,
      Value<int> attempts,
      Value<int> availableAt,
      Value<String?> error,
      Value<bool> closing,
      Value<int> rowid,
    });
typedef $$AnalysisJobsTableUpdateCompanionBuilder =
    AnalysisJobsCompanion Function({
      Value<String> scope,
      Value<String> targetId,
      Value<int> sourceVersion,
      Value<String> status,
      Value<int> attempts,
      Value<int> availableAt,
      Value<String?> error,
      Value<bool> closing,
      Value<int> rowid,
    });

class $$AnalysisJobsTableFilterComposer
    extends Composer<_$AppDatabase, $AnalysisJobsTable> {
  $$AnalysisJobsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get scope => $composableBuilder(
    column: $table.scope,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get targetId => $composableBuilder(
    column: $table.targetId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sourceVersion => $composableBuilder(
    column: $table.sourceVersion,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get attempts => $composableBuilder(
    column: $table.attempts,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get availableAt => $composableBuilder(
    column: $table.availableAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get error => $composableBuilder(
    column: $table.error,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get closing => $composableBuilder(
    column: $table.closing,
    builder: (column) => ColumnFilters(column),
  );
}

class $$AnalysisJobsTableOrderingComposer
    extends Composer<_$AppDatabase, $AnalysisJobsTable> {
  $$AnalysisJobsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get scope => $composableBuilder(
    column: $table.scope,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get targetId => $composableBuilder(
    column: $table.targetId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sourceVersion => $composableBuilder(
    column: $table.sourceVersion,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get attempts => $composableBuilder(
    column: $table.attempts,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get availableAt => $composableBuilder(
    column: $table.availableAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get error => $composableBuilder(
    column: $table.error,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get closing => $composableBuilder(
    column: $table.closing,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$AnalysisJobsTableAnnotationComposer
    extends Composer<_$AppDatabase, $AnalysisJobsTable> {
  $$AnalysisJobsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get scope =>
      $composableBuilder(column: $table.scope, builder: (column) => column);

  GeneratedColumn<String> get targetId =>
      $composableBuilder(column: $table.targetId, builder: (column) => column);

  GeneratedColumn<int> get sourceVersion => $composableBuilder(
    column: $table.sourceVersion,
    builder: (column) => column,
  );

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<int> get attempts =>
      $composableBuilder(column: $table.attempts, builder: (column) => column);

  GeneratedColumn<int> get availableAt => $composableBuilder(
    column: $table.availableAt,
    builder: (column) => column,
  );

  GeneratedColumn<String> get error =>
      $composableBuilder(column: $table.error, builder: (column) => column);

  GeneratedColumn<bool> get closing =>
      $composableBuilder(column: $table.closing, builder: (column) => column);
}

class $$AnalysisJobsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $AnalysisJobsTable,
          AnalysisJobRow,
          $$AnalysisJobsTableFilterComposer,
          $$AnalysisJobsTableOrderingComposer,
          $$AnalysisJobsTableAnnotationComposer,
          $$AnalysisJobsTableCreateCompanionBuilder,
          $$AnalysisJobsTableUpdateCompanionBuilder,
          (
            AnalysisJobRow,
            BaseReferences<_$AppDatabase, $AnalysisJobsTable, AnalysisJobRow>,
          ),
          AnalysisJobRow,
          PrefetchHooks Function()
        > {
  $$AnalysisJobsTableTableManager(_$AppDatabase db, $AnalysisJobsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AnalysisJobsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AnalysisJobsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AnalysisJobsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> scope = const Value.absent(),
                Value<String> targetId = const Value.absent(),
                Value<int> sourceVersion = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<int> attempts = const Value.absent(),
                Value<int> availableAt = const Value.absent(),
                Value<String?> error = const Value.absent(),
                Value<bool> closing = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => AnalysisJobsCompanion(
                scope: scope,
                targetId: targetId,
                sourceVersion: sourceVersion,
                status: status,
                attempts: attempts,
                availableAt: availableAt,
                error: error,
                closing: closing,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String scope,
                required String targetId,
                Value<int> sourceVersion = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<int> attempts = const Value.absent(),
                Value<int> availableAt = const Value.absent(),
                Value<String?> error = const Value.absent(),
                Value<bool> closing = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => AnalysisJobsCompanion.insert(
                scope: scope,
                targetId: targetId,
                sourceVersion: sourceVersion,
                status: status,
                attempts: attempts,
                availableAt: availableAt,
                error: error,
                closing: closing,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$AnalysisJobsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $AnalysisJobsTable,
      AnalysisJobRow,
      $$AnalysisJobsTableFilterComposer,
      $$AnalysisJobsTableOrderingComposer,
      $$AnalysisJobsTableAnnotationComposer,
      $$AnalysisJobsTableCreateCompanionBuilder,
      $$AnalysisJobsTableUpdateCompanionBuilder,
      (
        AnalysisJobRow,
        BaseReferences<_$AppDatabase, $AnalysisJobsTable, AnalysisJobRow>,
      ),
      AnalysisJobRow,
      PrefetchHooks Function()
    >;
typedef $$AnalysisVersionsTableCreateCompanionBuilder =
    AnalysisVersionsCompanion Function({
      required String id,
      required String scope,
      required String targetId,
      required int sourceVersion,
      required String content,
      required String sourcesJson,
      required int coverage,
      required int createdAt,
      Value<bool> closing,
      Value<int> rowid,
    });
typedef $$AnalysisVersionsTableUpdateCompanionBuilder =
    AnalysisVersionsCompanion Function({
      Value<String> id,
      Value<String> scope,
      Value<String> targetId,
      Value<int> sourceVersion,
      Value<String> content,
      Value<String> sourcesJson,
      Value<int> coverage,
      Value<int> createdAt,
      Value<bool> closing,
      Value<int> rowid,
    });

class $$AnalysisVersionsTableFilterComposer
    extends Composer<_$AppDatabase, $AnalysisVersionsTable> {
  $$AnalysisVersionsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get scope => $composableBuilder(
    column: $table.scope,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get targetId => $composableBuilder(
    column: $table.targetId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sourceVersion => $composableBuilder(
    column: $table.sourceVersion,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get content => $composableBuilder(
    column: $table.content,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sourcesJson => $composableBuilder(
    column: $table.sourcesJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get coverage => $composableBuilder(
    column: $table.coverage,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get closing => $composableBuilder(
    column: $table.closing,
    builder: (column) => ColumnFilters(column),
  );
}

class $$AnalysisVersionsTableOrderingComposer
    extends Composer<_$AppDatabase, $AnalysisVersionsTable> {
  $$AnalysisVersionsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get scope => $composableBuilder(
    column: $table.scope,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get targetId => $composableBuilder(
    column: $table.targetId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sourceVersion => $composableBuilder(
    column: $table.sourceVersion,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get content => $composableBuilder(
    column: $table.content,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sourcesJson => $composableBuilder(
    column: $table.sourcesJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get coverage => $composableBuilder(
    column: $table.coverage,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get closing => $composableBuilder(
    column: $table.closing,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$AnalysisVersionsTableAnnotationComposer
    extends Composer<_$AppDatabase, $AnalysisVersionsTable> {
  $$AnalysisVersionsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get scope =>
      $composableBuilder(column: $table.scope, builder: (column) => column);

  GeneratedColumn<String> get targetId =>
      $composableBuilder(column: $table.targetId, builder: (column) => column);

  GeneratedColumn<int> get sourceVersion => $composableBuilder(
    column: $table.sourceVersion,
    builder: (column) => column,
  );

  GeneratedColumn<String> get content =>
      $composableBuilder(column: $table.content, builder: (column) => column);

  GeneratedColumn<String> get sourcesJson => $composableBuilder(
    column: $table.sourcesJson,
    builder: (column) => column,
  );

  GeneratedColumn<int> get coverage =>
      $composableBuilder(column: $table.coverage, builder: (column) => column);

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<bool> get closing =>
      $composableBuilder(column: $table.closing, builder: (column) => column);
}

class $$AnalysisVersionsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $AnalysisVersionsTable,
          AnalysisVersionRow,
          $$AnalysisVersionsTableFilterComposer,
          $$AnalysisVersionsTableOrderingComposer,
          $$AnalysisVersionsTableAnnotationComposer,
          $$AnalysisVersionsTableCreateCompanionBuilder,
          $$AnalysisVersionsTableUpdateCompanionBuilder,
          (
            AnalysisVersionRow,
            BaseReferences<
              _$AppDatabase,
              $AnalysisVersionsTable,
              AnalysisVersionRow
            >,
          ),
          AnalysisVersionRow,
          PrefetchHooks Function()
        > {
  $$AnalysisVersionsTableTableManager(
    _$AppDatabase db,
    $AnalysisVersionsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AnalysisVersionsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AnalysisVersionsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AnalysisVersionsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> scope = const Value.absent(),
                Value<String> targetId = const Value.absent(),
                Value<int> sourceVersion = const Value.absent(),
                Value<String> content = const Value.absent(),
                Value<String> sourcesJson = const Value.absent(),
                Value<int> coverage = const Value.absent(),
                Value<int> createdAt = const Value.absent(),
                Value<bool> closing = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => AnalysisVersionsCompanion(
                id: id,
                scope: scope,
                targetId: targetId,
                sourceVersion: sourceVersion,
                content: content,
                sourcesJson: sourcesJson,
                coverage: coverage,
                createdAt: createdAt,
                closing: closing,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String scope,
                required String targetId,
                required int sourceVersion,
                required String content,
                required String sourcesJson,
                required int coverage,
                required int createdAt,
                Value<bool> closing = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => AnalysisVersionsCompanion.insert(
                id: id,
                scope: scope,
                targetId: targetId,
                sourceVersion: sourceVersion,
                content: content,
                sourcesJson: sourcesJson,
                coverage: coverage,
                createdAt: createdAt,
                closing: closing,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$AnalysisVersionsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $AnalysisVersionsTable,
      AnalysisVersionRow,
      $$AnalysisVersionsTableFilterComposer,
      $$AnalysisVersionsTableOrderingComposer,
      $$AnalysisVersionsTableAnnotationComposer,
      $$AnalysisVersionsTableCreateCompanionBuilder,
      $$AnalysisVersionsTableUpdateCompanionBuilder,
      (
        AnalysisVersionRow,
        BaseReferences<
          _$AppDatabase,
          $AnalysisVersionsTable,
          AnalysisVersionRow
        >,
      ),
      AnalysisVersionRow,
      PrefetchHooks Function()
    >;
typedef $$MemoryTopicsTableCreateCompanionBuilder =
    MemoryTopicsCompanion Function({
      required String id,
      required String canonicalName,
      required String kind,
      Value<String?> goalId,
      required int createdAt,
      Value<int> rowid,
    });
typedef $$MemoryTopicsTableUpdateCompanionBuilder =
    MemoryTopicsCompanion Function({
      Value<String> id,
      Value<String> canonicalName,
      Value<String> kind,
      Value<String?> goalId,
      Value<int> createdAt,
      Value<int> rowid,
    });

final class $$MemoryTopicsTableReferences
    extends BaseReferences<_$AppDatabase, $MemoryTopicsTable, MemoryTopicRow> {
  $$MemoryTopicsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $GoalsTable _goalIdTable(_$AppDatabase db) =>
      db.goals.createAlias('memory_topics__goal_id__goals__id');

  $$GoalsTableProcessedTableManager? get goalId {
    final $_column = $_itemColumn<String>('goal_id');
    if ($_column == null) return null;
    final manager = $$GoalsTableTableManager(
      $_db,
      $_db.goals,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_goalIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static MultiTypedResultKey<$MemoryItemsTable, List<MemoryItemRow>>
  _memoryItemsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.memoryItems,
    aliasName: 'memory_topics__id__memory_items__topic_id',
  );

  $$MemoryItemsTableProcessedTableManager get memoryItemsRefs {
    final manager = $$MemoryItemsTableTableManager(
      $_db,
      $_db.memoryItems,
    ).filter((f) => f.topicId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_memoryItemsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<
    $MemoryTopicAliasesTable,
    List<MemoryTopicAliasRow>
  >
  _memoryTopicAliasesRefsTable(_$AppDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.memoryTopicAliases,
        aliasName: 'memory_topics__id__memory_topic_aliases__topic_id',
      );

  $$MemoryTopicAliasesTableProcessedTableManager get memoryTopicAliasesRefs {
    final manager = $$MemoryTopicAliasesTableTableManager(
      $_db,
      $_db.memoryTopicAliases,
    ).filter((f) => f.topicId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _memoryTopicAliasesRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$MemoryTopicsTableFilterComposer
    extends Composer<_$AppDatabase, $MemoryTopicsTable> {
  $$MemoryTopicsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get canonicalName => $composableBuilder(
    column: $table.canonicalName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  $$GoalsTableFilterComposer get goalId {
    final $$GoalsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.goalId,
      referencedTable: $db.goals,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$GoalsTableFilterComposer(
            $db: $db,
            $table: $db.goals,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<bool> memoryItemsRefs(
    Expression<bool> Function($$MemoryItemsTableFilterComposer f) f,
  ) {
    final $$MemoryItemsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.memoryItems,
      getReferencedColumn: (t) => t.topicId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MemoryItemsTableFilterComposer(
            $db: $db,
            $table: $db.memoryItems,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> memoryTopicAliasesRefs(
    Expression<bool> Function($$MemoryTopicAliasesTableFilterComposer f) f,
  ) {
    final $$MemoryTopicAliasesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.memoryTopicAliases,
      getReferencedColumn: (t) => t.topicId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MemoryTopicAliasesTableFilterComposer(
            $db: $db,
            $table: $db.memoryTopicAliases,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$MemoryTopicsTableOrderingComposer
    extends Composer<_$AppDatabase, $MemoryTopicsTable> {
  $$MemoryTopicsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get canonicalName => $composableBuilder(
    column: $table.canonicalName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$GoalsTableOrderingComposer get goalId {
    final $$GoalsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.goalId,
      referencedTable: $db.goals,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$GoalsTableOrderingComposer(
            $db: $db,
            $table: $db.goals,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$MemoryTopicsTableAnnotationComposer
    extends Composer<_$AppDatabase, $MemoryTopicsTable> {
  $$MemoryTopicsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get canonicalName => $composableBuilder(
    column: $table.canonicalName,
    builder: (column) => column,
  );

  GeneratedColumn<String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  $$GoalsTableAnnotationComposer get goalId {
    final $$GoalsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.goalId,
      referencedTable: $db.goals,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$GoalsTableAnnotationComposer(
            $db: $db,
            $table: $db.goals,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<T> memoryItemsRefs<T extends Object>(
    Expression<T> Function($$MemoryItemsTableAnnotationComposer a) f,
  ) {
    final $$MemoryItemsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.memoryItems,
      getReferencedColumn: (t) => t.topicId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MemoryItemsTableAnnotationComposer(
            $db: $db,
            $table: $db.memoryItems,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> memoryTopicAliasesRefs<T extends Object>(
    Expression<T> Function($$MemoryTopicAliasesTableAnnotationComposer a) f,
  ) {
    final $$MemoryTopicAliasesTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.memoryTopicAliases,
          getReferencedColumn: (t) => t.topicId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$MemoryTopicAliasesTableAnnotationComposer(
                $db: $db,
                $table: $db.memoryTopicAliases,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }
}

class $$MemoryTopicsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $MemoryTopicsTable,
          MemoryTopicRow,
          $$MemoryTopicsTableFilterComposer,
          $$MemoryTopicsTableOrderingComposer,
          $$MemoryTopicsTableAnnotationComposer,
          $$MemoryTopicsTableCreateCompanionBuilder,
          $$MemoryTopicsTableUpdateCompanionBuilder,
          (MemoryTopicRow, $$MemoryTopicsTableReferences),
          MemoryTopicRow,
          PrefetchHooks Function({
            bool goalId,
            bool memoryItemsRefs,
            bool memoryTopicAliasesRefs,
          })
        > {
  $$MemoryTopicsTableTableManager(_$AppDatabase db, $MemoryTopicsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$MemoryTopicsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$MemoryTopicsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$MemoryTopicsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> canonicalName = const Value.absent(),
                Value<String> kind = const Value.absent(),
                Value<String?> goalId = const Value.absent(),
                Value<int> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => MemoryTopicsCompanion(
                id: id,
                canonicalName: canonicalName,
                kind: kind,
                goalId: goalId,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String canonicalName,
                required String kind,
                Value<String?> goalId = const Value.absent(),
                required int createdAt,
                Value<int> rowid = const Value.absent(),
              }) => MemoryTopicsCompanion.insert(
                id: id,
                canonicalName: canonicalName,
                kind: kind,
                goalId: goalId,
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$MemoryTopicsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({
                goalId = false,
                memoryItemsRefs = false,
                memoryTopicAliasesRefs = false,
              }) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (memoryItemsRefs) db.memoryItems,
                    if (memoryTopicAliasesRefs) db.memoryTopicAliases,
                  ],
                  addJoins:
                      <
                        T extends TableManagerState<
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic
                        >
                      >(state) {
                        if (goalId) {
                          state =
                              state.withJoin(
                                    currentTable: table,
                                    currentColumn: table.goalId,
                                    referencedTable:
                                        $$MemoryTopicsTableReferences
                                            ._goalIdTable(db),
                                    referencedColumn:
                                        $$MemoryTopicsTableReferences
                                            ._goalIdTable(db)
                                            .id,
                                  )
                                  as T;
                        }

                        return state;
                      },
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (memoryItemsRefs)
                        await $_getPrefetchedData<
                          MemoryTopicRow,
                          $MemoryTopicsTable,
                          MemoryItemRow
                        >(
                          currentTable: table,
                          referencedTable: $$MemoryTopicsTableReferences
                              ._memoryItemsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$MemoryTopicsTableReferences(
                                db,
                                table,
                                p0,
                              ).memoryItemsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.topicId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (memoryTopicAliasesRefs)
                        await $_getPrefetchedData<
                          MemoryTopicRow,
                          $MemoryTopicsTable,
                          MemoryTopicAliasRow
                        >(
                          currentTable: table,
                          referencedTable: $$MemoryTopicsTableReferences
                              ._memoryTopicAliasesRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$MemoryTopicsTableReferences(
                                db,
                                table,
                                p0,
                              ).memoryTopicAliasesRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.topicId == item.id,
                              ),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$MemoryTopicsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $MemoryTopicsTable,
      MemoryTopicRow,
      $$MemoryTopicsTableFilterComposer,
      $$MemoryTopicsTableOrderingComposer,
      $$MemoryTopicsTableAnnotationComposer,
      $$MemoryTopicsTableCreateCompanionBuilder,
      $$MemoryTopicsTableUpdateCompanionBuilder,
      (MemoryTopicRow, $$MemoryTopicsTableReferences),
      MemoryTopicRow,
      PrefetchHooks Function({
        bool goalId,
        bool memoryItemsRefs,
        bool memoryTopicAliasesRefs,
      })
    >;
typedef $$MemoryItemsTableCreateCompanionBuilder =
    MemoryItemsCompanion Function({
      required String id,
      required String layer,
      Value<String?> topicId,
      required String content,
      required String certainty,
      Value<int> importance,
      required int createdAt,
      required int updatedAt,
      Value<int?> expiresAt,
      Value<bool> forgotten,
      Value<bool> userEdited,
      required String sourceKind,
      Value<String?> sourceRef,
      Value<String?> goalId,
      Value<int> rowid,
    });
typedef $$MemoryItemsTableUpdateCompanionBuilder =
    MemoryItemsCompanion Function({
      Value<String> id,
      Value<String> layer,
      Value<String?> topicId,
      Value<String> content,
      Value<String> certainty,
      Value<int> importance,
      Value<int> createdAt,
      Value<int> updatedAt,
      Value<int?> expiresAt,
      Value<bool> forgotten,
      Value<bool> userEdited,
      Value<String> sourceKind,
      Value<String?> sourceRef,
      Value<String?> goalId,
      Value<int> rowid,
    });

final class $$MemoryItemsTableReferences
    extends BaseReferences<_$AppDatabase, $MemoryItemsTable, MemoryItemRow> {
  $$MemoryItemsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $MemoryTopicsTable _topicIdTable(_$AppDatabase db) =>
      db.memoryTopics.createAlias('memory_items__topic_id__memory_topics__id');

  $$MemoryTopicsTableProcessedTableManager? get topicId {
    final $_column = $_itemColumn<String>('topic_id');
    if ($_column == null) return null;
    final manager = $$MemoryTopicsTableTableManager(
      $_db,
      $_db.memoryTopics,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_topicIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $GoalsTable _goalIdTable(_$AppDatabase db) =>
      db.goals.createAlias('memory_items__goal_id__goals__id');

  $$GoalsTableProcessedTableManager? get goalId {
    final $_column = $_itemColumn<String>('goal_id');
    if ($_column == null) return null;
    final manager = $$GoalsTableTableManager(
      $_db,
      $_db.goals,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_goalIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static MultiTypedResultKey<$MemoryVersionsTable, List<MemoryVersionRow>>
  _memoryVersionsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.memoryVersions,
    aliasName: 'memory_items__id__memory_versions__item_id',
  );

  $$MemoryVersionsTableProcessedTableManager get memoryVersionsRefs {
    final manager = $$MemoryVersionsTableTableManager(
      $_db,
      $_db.memoryVersions,
    ).filter((f) => f.itemId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_memoryVersionsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$MemoryEpisodesTable, List<MemoryEpisodeRow>>
  _memoryEpisodesRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.memoryEpisodes,
    aliasName: 'memory_items__id__memory_episodes__item_id',
  );

  $$MemoryEpisodesTableProcessedTableManager get memoryEpisodesRefs {
    final manager = $$MemoryEpisodesTableTableManager(
      $_db,
      $_db.memoryEpisodes,
    ).filter((f) => f.itemId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_memoryEpisodesRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$MemoryProceduresTable, List<MemoryProcedureRow>>
  _memoryProceduresRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.memoryProcedures,
    aliasName: 'memory_items__id__memory_procedures__item_id',
  );

  $$MemoryProceduresTableProcessedTableManager get memoryProceduresRefs {
    final manager = $$MemoryProceduresTableTableManager(
      $_db,
      $_db.memoryProcedures,
    ).filter((f) => f.itemId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _memoryProceduresRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$MemoryUsageTable, List<MemoryUsageRow>>
  _memoryUsageRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.memoryUsage,
    aliasName: 'memory_items__id__memory_usage__item_id',
  );

  $$MemoryUsageTableProcessedTableManager get memoryUsageRefs {
    final manager = $$MemoryUsageTableTableManager(
      $_db,
      $_db.memoryUsage,
    ).filter((f) => f.itemId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_memoryUsageRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$MemoryItemsTableFilterComposer
    extends Composer<_$AppDatabase, $MemoryItemsTable> {
  $$MemoryItemsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get layer => $composableBuilder(
    column: $table.layer,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get content => $composableBuilder(
    column: $table.content,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get certainty => $composableBuilder(
    column: $table.certainty,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get importance => $composableBuilder(
    column: $table.importance,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get expiresAt => $composableBuilder(
    column: $table.expiresAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get forgotten => $composableBuilder(
    column: $table.forgotten,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get userEdited => $composableBuilder(
    column: $table.userEdited,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sourceKind => $composableBuilder(
    column: $table.sourceKind,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sourceRef => $composableBuilder(
    column: $table.sourceRef,
    builder: (column) => ColumnFilters(column),
  );

  $$MemoryTopicsTableFilterComposer get topicId {
    final $$MemoryTopicsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.topicId,
      referencedTable: $db.memoryTopics,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MemoryTopicsTableFilterComposer(
            $db: $db,
            $table: $db.memoryTopics,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$GoalsTableFilterComposer get goalId {
    final $$GoalsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.goalId,
      referencedTable: $db.goals,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$GoalsTableFilterComposer(
            $db: $db,
            $table: $db.goals,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<bool> memoryVersionsRefs(
    Expression<bool> Function($$MemoryVersionsTableFilterComposer f) f,
  ) {
    final $$MemoryVersionsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.memoryVersions,
      getReferencedColumn: (t) => t.itemId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MemoryVersionsTableFilterComposer(
            $db: $db,
            $table: $db.memoryVersions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> memoryEpisodesRefs(
    Expression<bool> Function($$MemoryEpisodesTableFilterComposer f) f,
  ) {
    final $$MemoryEpisodesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.memoryEpisodes,
      getReferencedColumn: (t) => t.itemId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MemoryEpisodesTableFilterComposer(
            $db: $db,
            $table: $db.memoryEpisodes,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> memoryProceduresRefs(
    Expression<bool> Function($$MemoryProceduresTableFilterComposer f) f,
  ) {
    final $$MemoryProceduresTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.memoryProcedures,
      getReferencedColumn: (t) => t.itemId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MemoryProceduresTableFilterComposer(
            $db: $db,
            $table: $db.memoryProcedures,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> memoryUsageRefs(
    Expression<bool> Function($$MemoryUsageTableFilterComposer f) f,
  ) {
    final $$MemoryUsageTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.memoryUsage,
      getReferencedColumn: (t) => t.itemId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MemoryUsageTableFilterComposer(
            $db: $db,
            $table: $db.memoryUsage,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$MemoryItemsTableOrderingComposer
    extends Composer<_$AppDatabase, $MemoryItemsTable> {
  $$MemoryItemsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get layer => $composableBuilder(
    column: $table.layer,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get content => $composableBuilder(
    column: $table.content,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get certainty => $composableBuilder(
    column: $table.certainty,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get importance => $composableBuilder(
    column: $table.importance,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get expiresAt => $composableBuilder(
    column: $table.expiresAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get forgotten => $composableBuilder(
    column: $table.forgotten,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get userEdited => $composableBuilder(
    column: $table.userEdited,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sourceKind => $composableBuilder(
    column: $table.sourceKind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sourceRef => $composableBuilder(
    column: $table.sourceRef,
    builder: (column) => ColumnOrderings(column),
  );

  $$MemoryTopicsTableOrderingComposer get topicId {
    final $$MemoryTopicsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.topicId,
      referencedTable: $db.memoryTopics,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MemoryTopicsTableOrderingComposer(
            $db: $db,
            $table: $db.memoryTopics,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$GoalsTableOrderingComposer get goalId {
    final $$GoalsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.goalId,
      referencedTable: $db.goals,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$GoalsTableOrderingComposer(
            $db: $db,
            $table: $db.goals,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$MemoryItemsTableAnnotationComposer
    extends Composer<_$AppDatabase, $MemoryItemsTable> {
  $$MemoryItemsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get layer =>
      $composableBuilder(column: $table.layer, builder: (column) => column);

  GeneratedColumn<String> get content =>
      $composableBuilder(column: $table.content, builder: (column) => column);

  GeneratedColumn<String> get certainty =>
      $composableBuilder(column: $table.certainty, builder: (column) => column);

  GeneratedColumn<int> get importance => $composableBuilder(
    column: $table.importance,
    builder: (column) => column,
  );

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<int> get expiresAt =>
      $composableBuilder(column: $table.expiresAt, builder: (column) => column);

  GeneratedColumn<bool> get forgotten =>
      $composableBuilder(column: $table.forgotten, builder: (column) => column);

  GeneratedColumn<bool> get userEdited => $composableBuilder(
    column: $table.userEdited,
    builder: (column) => column,
  );

  GeneratedColumn<String> get sourceKind => $composableBuilder(
    column: $table.sourceKind,
    builder: (column) => column,
  );

  GeneratedColumn<String> get sourceRef =>
      $composableBuilder(column: $table.sourceRef, builder: (column) => column);

  $$MemoryTopicsTableAnnotationComposer get topicId {
    final $$MemoryTopicsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.topicId,
      referencedTable: $db.memoryTopics,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MemoryTopicsTableAnnotationComposer(
            $db: $db,
            $table: $db.memoryTopics,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$GoalsTableAnnotationComposer get goalId {
    final $$GoalsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.goalId,
      referencedTable: $db.goals,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$GoalsTableAnnotationComposer(
            $db: $db,
            $table: $db.goals,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<T> memoryVersionsRefs<T extends Object>(
    Expression<T> Function($$MemoryVersionsTableAnnotationComposer a) f,
  ) {
    final $$MemoryVersionsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.memoryVersions,
      getReferencedColumn: (t) => t.itemId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MemoryVersionsTableAnnotationComposer(
            $db: $db,
            $table: $db.memoryVersions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> memoryEpisodesRefs<T extends Object>(
    Expression<T> Function($$MemoryEpisodesTableAnnotationComposer a) f,
  ) {
    final $$MemoryEpisodesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.memoryEpisodes,
      getReferencedColumn: (t) => t.itemId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MemoryEpisodesTableAnnotationComposer(
            $db: $db,
            $table: $db.memoryEpisodes,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> memoryProceduresRefs<T extends Object>(
    Expression<T> Function($$MemoryProceduresTableAnnotationComposer a) f,
  ) {
    final $$MemoryProceduresTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.memoryProcedures,
      getReferencedColumn: (t) => t.itemId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MemoryProceduresTableAnnotationComposer(
            $db: $db,
            $table: $db.memoryProcedures,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> memoryUsageRefs<T extends Object>(
    Expression<T> Function($$MemoryUsageTableAnnotationComposer a) f,
  ) {
    final $$MemoryUsageTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.memoryUsage,
      getReferencedColumn: (t) => t.itemId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MemoryUsageTableAnnotationComposer(
            $db: $db,
            $table: $db.memoryUsage,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$MemoryItemsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $MemoryItemsTable,
          MemoryItemRow,
          $$MemoryItemsTableFilterComposer,
          $$MemoryItemsTableOrderingComposer,
          $$MemoryItemsTableAnnotationComposer,
          $$MemoryItemsTableCreateCompanionBuilder,
          $$MemoryItemsTableUpdateCompanionBuilder,
          (MemoryItemRow, $$MemoryItemsTableReferences),
          MemoryItemRow,
          PrefetchHooks Function({
            bool topicId,
            bool goalId,
            bool memoryVersionsRefs,
            bool memoryEpisodesRefs,
            bool memoryProceduresRefs,
            bool memoryUsageRefs,
          })
        > {
  $$MemoryItemsTableTableManager(_$AppDatabase db, $MemoryItemsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$MemoryItemsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$MemoryItemsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$MemoryItemsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> layer = const Value.absent(),
                Value<String?> topicId = const Value.absent(),
                Value<String> content = const Value.absent(),
                Value<String> certainty = const Value.absent(),
                Value<int> importance = const Value.absent(),
                Value<int> createdAt = const Value.absent(),
                Value<int> updatedAt = const Value.absent(),
                Value<int?> expiresAt = const Value.absent(),
                Value<bool> forgotten = const Value.absent(),
                Value<bool> userEdited = const Value.absent(),
                Value<String> sourceKind = const Value.absent(),
                Value<String?> sourceRef = const Value.absent(),
                Value<String?> goalId = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => MemoryItemsCompanion(
                id: id,
                layer: layer,
                topicId: topicId,
                content: content,
                certainty: certainty,
                importance: importance,
                createdAt: createdAt,
                updatedAt: updatedAt,
                expiresAt: expiresAt,
                forgotten: forgotten,
                userEdited: userEdited,
                sourceKind: sourceKind,
                sourceRef: sourceRef,
                goalId: goalId,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String layer,
                Value<String?> topicId = const Value.absent(),
                required String content,
                required String certainty,
                Value<int> importance = const Value.absent(),
                required int createdAt,
                required int updatedAt,
                Value<int?> expiresAt = const Value.absent(),
                Value<bool> forgotten = const Value.absent(),
                Value<bool> userEdited = const Value.absent(),
                required String sourceKind,
                Value<String?> sourceRef = const Value.absent(),
                Value<String?> goalId = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => MemoryItemsCompanion.insert(
                id: id,
                layer: layer,
                topicId: topicId,
                content: content,
                certainty: certainty,
                importance: importance,
                createdAt: createdAt,
                updatedAt: updatedAt,
                expiresAt: expiresAt,
                forgotten: forgotten,
                userEdited: userEdited,
                sourceKind: sourceKind,
                sourceRef: sourceRef,
                goalId: goalId,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$MemoryItemsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({
                topicId = false,
                goalId = false,
                memoryVersionsRefs = false,
                memoryEpisodesRefs = false,
                memoryProceduresRefs = false,
                memoryUsageRefs = false,
              }) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (memoryVersionsRefs) db.memoryVersions,
                    if (memoryEpisodesRefs) db.memoryEpisodes,
                    if (memoryProceduresRefs) db.memoryProcedures,
                    if (memoryUsageRefs) db.memoryUsage,
                  ],
                  addJoins:
                      <
                        T extends TableManagerState<
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic
                        >
                      >(state) {
                        if (topicId) {
                          state =
                              state.withJoin(
                                    currentTable: table,
                                    currentColumn: table.topicId,
                                    referencedTable:
                                        $$MemoryItemsTableReferences
                                            ._topicIdTable(db),
                                    referencedColumn:
                                        $$MemoryItemsTableReferences
                                            ._topicIdTable(db)
                                            .id,
                                  )
                                  as T;
                        }
                        if (goalId) {
                          state =
                              state.withJoin(
                                    currentTable: table,
                                    currentColumn: table.goalId,
                                    referencedTable:
                                        $$MemoryItemsTableReferences
                                            ._goalIdTable(db),
                                    referencedColumn:
                                        $$MemoryItemsTableReferences
                                            ._goalIdTable(db)
                                            .id,
                                  )
                                  as T;
                        }

                        return state;
                      },
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (memoryVersionsRefs)
                        await $_getPrefetchedData<
                          MemoryItemRow,
                          $MemoryItemsTable,
                          MemoryVersionRow
                        >(
                          currentTable: table,
                          referencedTable: $$MemoryItemsTableReferences
                              ._memoryVersionsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$MemoryItemsTableReferences(
                                db,
                                table,
                                p0,
                              ).memoryVersionsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.itemId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (memoryEpisodesRefs)
                        await $_getPrefetchedData<
                          MemoryItemRow,
                          $MemoryItemsTable,
                          MemoryEpisodeRow
                        >(
                          currentTable: table,
                          referencedTable: $$MemoryItemsTableReferences
                              ._memoryEpisodesRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$MemoryItemsTableReferences(
                                db,
                                table,
                                p0,
                              ).memoryEpisodesRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.itemId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (memoryProceduresRefs)
                        await $_getPrefetchedData<
                          MemoryItemRow,
                          $MemoryItemsTable,
                          MemoryProcedureRow
                        >(
                          currentTable: table,
                          referencedTable: $$MemoryItemsTableReferences
                              ._memoryProceduresRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$MemoryItemsTableReferences(
                                db,
                                table,
                                p0,
                              ).memoryProceduresRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.itemId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (memoryUsageRefs)
                        await $_getPrefetchedData<
                          MemoryItemRow,
                          $MemoryItemsTable,
                          MemoryUsageRow
                        >(
                          currentTable: table,
                          referencedTable: $$MemoryItemsTableReferences
                              ._memoryUsageRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$MemoryItemsTableReferences(
                                db,
                                table,
                                p0,
                              ).memoryUsageRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.itemId == item.id,
                              ),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$MemoryItemsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $MemoryItemsTable,
      MemoryItemRow,
      $$MemoryItemsTableFilterComposer,
      $$MemoryItemsTableOrderingComposer,
      $$MemoryItemsTableAnnotationComposer,
      $$MemoryItemsTableCreateCompanionBuilder,
      $$MemoryItemsTableUpdateCompanionBuilder,
      (MemoryItemRow, $$MemoryItemsTableReferences),
      MemoryItemRow,
      PrefetchHooks Function({
        bool topicId,
        bool goalId,
        bool memoryVersionsRefs,
        bool memoryEpisodesRefs,
        bool memoryProceduresRefs,
        bool memoryUsageRefs,
      })
    >;
typedef $$MemoryTopicAliasesTableCreateCompanionBuilder =
    MemoryTopicAliasesCompanion Function({
      required String topicId,
      required String alias,
      required String normalizedAlias,
      Value<int> rowid,
    });
typedef $$MemoryTopicAliasesTableUpdateCompanionBuilder =
    MemoryTopicAliasesCompanion Function({
      Value<String> topicId,
      Value<String> alias,
      Value<String> normalizedAlias,
      Value<int> rowid,
    });

final class $$MemoryTopicAliasesTableReferences
    extends
        BaseReferences<
          _$AppDatabase,
          $MemoryTopicAliasesTable,
          MemoryTopicAliasRow
        > {
  $$MemoryTopicAliasesTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $MemoryTopicsTable _topicIdTable(_$AppDatabase db) => db.memoryTopics
      .createAlias('memory_topic_aliases__topic_id__memory_topics__id');

  $$MemoryTopicsTableProcessedTableManager get topicId {
    final $_column = $_itemColumn<String>('topic_id')!;

    final manager = $$MemoryTopicsTableTableManager(
      $_db,
      $_db.memoryTopics,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_topicIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$MemoryTopicAliasesTableFilterComposer
    extends Composer<_$AppDatabase, $MemoryTopicAliasesTable> {
  $$MemoryTopicAliasesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get alias => $composableBuilder(
    column: $table.alias,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get normalizedAlias => $composableBuilder(
    column: $table.normalizedAlias,
    builder: (column) => ColumnFilters(column),
  );

  $$MemoryTopicsTableFilterComposer get topicId {
    final $$MemoryTopicsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.topicId,
      referencedTable: $db.memoryTopics,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MemoryTopicsTableFilterComposer(
            $db: $db,
            $table: $db.memoryTopics,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$MemoryTopicAliasesTableOrderingComposer
    extends Composer<_$AppDatabase, $MemoryTopicAliasesTable> {
  $$MemoryTopicAliasesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get alias => $composableBuilder(
    column: $table.alias,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get normalizedAlias => $composableBuilder(
    column: $table.normalizedAlias,
    builder: (column) => ColumnOrderings(column),
  );

  $$MemoryTopicsTableOrderingComposer get topicId {
    final $$MemoryTopicsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.topicId,
      referencedTable: $db.memoryTopics,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MemoryTopicsTableOrderingComposer(
            $db: $db,
            $table: $db.memoryTopics,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$MemoryTopicAliasesTableAnnotationComposer
    extends Composer<_$AppDatabase, $MemoryTopicAliasesTable> {
  $$MemoryTopicAliasesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get alias =>
      $composableBuilder(column: $table.alias, builder: (column) => column);

  GeneratedColumn<String> get normalizedAlias => $composableBuilder(
    column: $table.normalizedAlias,
    builder: (column) => column,
  );

  $$MemoryTopicsTableAnnotationComposer get topicId {
    final $$MemoryTopicsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.topicId,
      referencedTable: $db.memoryTopics,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MemoryTopicsTableAnnotationComposer(
            $db: $db,
            $table: $db.memoryTopics,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$MemoryTopicAliasesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $MemoryTopicAliasesTable,
          MemoryTopicAliasRow,
          $$MemoryTopicAliasesTableFilterComposer,
          $$MemoryTopicAliasesTableOrderingComposer,
          $$MemoryTopicAliasesTableAnnotationComposer,
          $$MemoryTopicAliasesTableCreateCompanionBuilder,
          $$MemoryTopicAliasesTableUpdateCompanionBuilder,
          (MemoryTopicAliasRow, $$MemoryTopicAliasesTableReferences),
          MemoryTopicAliasRow,
          PrefetchHooks Function({bool topicId})
        > {
  $$MemoryTopicAliasesTableTableManager(
    _$AppDatabase db,
    $MemoryTopicAliasesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$MemoryTopicAliasesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$MemoryTopicAliasesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$MemoryTopicAliasesTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> topicId = const Value.absent(),
                Value<String> alias = const Value.absent(),
                Value<String> normalizedAlias = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => MemoryTopicAliasesCompanion(
                topicId: topicId,
                alias: alias,
                normalizedAlias: normalizedAlias,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String topicId,
                required String alias,
                required String normalizedAlias,
                Value<int> rowid = const Value.absent(),
              }) => MemoryTopicAliasesCompanion.insert(
                topicId: topicId,
                alias: alias,
                normalizedAlias: normalizedAlias,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$MemoryTopicAliasesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({topicId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (topicId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.topicId,
                                referencedTable:
                                    $$MemoryTopicAliasesTableReferences
                                        ._topicIdTable(db),
                                referencedColumn:
                                    $$MemoryTopicAliasesTableReferences
                                        ._topicIdTable(db)
                                        .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$MemoryTopicAliasesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $MemoryTopicAliasesTable,
      MemoryTopicAliasRow,
      $$MemoryTopicAliasesTableFilterComposer,
      $$MemoryTopicAliasesTableOrderingComposer,
      $$MemoryTopicAliasesTableAnnotationComposer,
      $$MemoryTopicAliasesTableCreateCompanionBuilder,
      $$MemoryTopicAliasesTableUpdateCompanionBuilder,
      (MemoryTopicAliasRow, $$MemoryTopicAliasesTableReferences),
      MemoryTopicAliasRow,
      PrefetchHooks Function({bool topicId})
    >;
typedef $$MemoryVersionsTableCreateCompanionBuilder =
    MemoryVersionsCompanion Function({
      required String id,
      required String itemId,
      required String changeKind,
      Value<String?> beforeJson,
      required String afterJson,
      required String reason,
      Value<String?> operationId,
      required String actor,
      required int createdAt,
      Value<int> rowid,
    });
typedef $$MemoryVersionsTableUpdateCompanionBuilder =
    MemoryVersionsCompanion Function({
      Value<String> id,
      Value<String> itemId,
      Value<String> changeKind,
      Value<String?> beforeJson,
      Value<String> afterJson,
      Value<String> reason,
      Value<String?> operationId,
      Value<String> actor,
      Value<int> createdAt,
      Value<int> rowid,
    });

final class $$MemoryVersionsTableReferences
    extends
        BaseReferences<_$AppDatabase, $MemoryVersionsTable, MemoryVersionRow> {
  $$MemoryVersionsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $MemoryItemsTable _itemIdTable(_$AppDatabase db) =>
      db.memoryItems.createAlias('memory_versions__item_id__memory_items__id');

  $$MemoryItemsTableProcessedTableManager get itemId {
    final $_column = $_itemColumn<String>('item_id')!;

    final manager = $$MemoryItemsTableTableManager(
      $_db,
      $_db.memoryItems,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_itemIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$MemoryVersionsTableFilterComposer
    extends Composer<_$AppDatabase, $MemoryVersionsTable> {
  $$MemoryVersionsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get changeKind => $composableBuilder(
    column: $table.changeKind,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get beforeJson => $composableBuilder(
    column: $table.beforeJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get afterJson => $composableBuilder(
    column: $table.afterJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get reason => $composableBuilder(
    column: $table.reason,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get operationId => $composableBuilder(
    column: $table.operationId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get actor => $composableBuilder(
    column: $table.actor,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  $$MemoryItemsTableFilterComposer get itemId {
    final $$MemoryItemsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.itemId,
      referencedTable: $db.memoryItems,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MemoryItemsTableFilterComposer(
            $db: $db,
            $table: $db.memoryItems,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$MemoryVersionsTableOrderingComposer
    extends Composer<_$AppDatabase, $MemoryVersionsTable> {
  $$MemoryVersionsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get changeKind => $composableBuilder(
    column: $table.changeKind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get beforeJson => $composableBuilder(
    column: $table.beforeJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get afterJson => $composableBuilder(
    column: $table.afterJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get reason => $composableBuilder(
    column: $table.reason,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get operationId => $composableBuilder(
    column: $table.operationId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get actor => $composableBuilder(
    column: $table.actor,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$MemoryItemsTableOrderingComposer get itemId {
    final $$MemoryItemsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.itemId,
      referencedTable: $db.memoryItems,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MemoryItemsTableOrderingComposer(
            $db: $db,
            $table: $db.memoryItems,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$MemoryVersionsTableAnnotationComposer
    extends Composer<_$AppDatabase, $MemoryVersionsTable> {
  $$MemoryVersionsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get changeKind => $composableBuilder(
    column: $table.changeKind,
    builder: (column) => column,
  );

  GeneratedColumn<String> get beforeJson => $composableBuilder(
    column: $table.beforeJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get afterJson =>
      $composableBuilder(column: $table.afterJson, builder: (column) => column);

  GeneratedColumn<String> get reason =>
      $composableBuilder(column: $table.reason, builder: (column) => column);

  GeneratedColumn<String> get operationId => $composableBuilder(
    column: $table.operationId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get actor =>
      $composableBuilder(column: $table.actor, builder: (column) => column);

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  $$MemoryItemsTableAnnotationComposer get itemId {
    final $$MemoryItemsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.itemId,
      referencedTable: $db.memoryItems,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MemoryItemsTableAnnotationComposer(
            $db: $db,
            $table: $db.memoryItems,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$MemoryVersionsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $MemoryVersionsTable,
          MemoryVersionRow,
          $$MemoryVersionsTableFilterComposer,
          $$MemoryVersionsTableOrderingComposer,
          $$MemoryVersionsTableAnnotationComposer,
          $$MemoryVersionsTableCreateCompanionBuilder,
          $$MemoryVersionsTableUpdateCompanionBuilder,
          (MemoryVersionRow, $$MemoryVersionsTableReferences),
          MemoryVersionRow,
          PrefetchHooks Function({bool itemId})
        > {
  $$MemoryVersionsTableTableManager(
    _$AppDatabase db,
    $MemoryVersionsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$MemoryVersionsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$MemoryVersionsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$MemoryVersionsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> itemId = const Value.absent(),
                Value<String> changeKind = const Value.absent(),
                Value<String?> beforeJson = const Value.absent(),
                Value<String> afterJson = const Value.absent(),
                Value<String> reason = const Value.absent(),
                Value<String?> operationId = const Value.absent(),
                Value<String> actor = const Value.absent(),
                Value<int> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => MemoryVersionsCompanion(
                id: id,
                itemId: itemId,
                changeKind: changeKind,
                beforeJson: beforeJson,
                afterJson: afterJson,
                reason: reason,
                operationId: operationId,
                actor: actor,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String itemId,
                required String changeKind,
                Value<String?> beforeJson = const Value.absent(),
                required String afterJson,
                required String reason,
                Value<String?> operationId = const Value.absent(),
                required String actor,
                required int createdAt,
                Value<int> rowid = const Value.absent(),
              }) => MemoryVersionsCompanion.insert(
                id: id,
                itemId: itemId,
                changeKind: changeKind,
                beforeJson: beforeJson,
                afterJson: afterJson,
                reason: reason,
                operationId: operationId,
                actor: actor,
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$MemoryVersionsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({itemId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (itemId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.itemId,
                                referencedTable: $$MemoryVersionsTableReferences
                                    ._itemIdTable(db),
                                referencedColumn:
                                    $$MemoryVersionsTableReferences
                                        ._itemIdTable(db)
                                        .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$MemoryVersionsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $MemoryVersionsTable,
      MemoryVersionRow,
      $$MemoryVersionsTableFilterComposer,
      $$MemoryVersionsTableOrderingComposer,
      $$MemoryVersionsTableAnnotationComposer,
      $$MemoryVersionsTableCreateCompanionBuilder,
      $$MemoryVersionsTableUpdateCompanionBuilder,
      (MemoryVersionRow, $$MemoryVersionsTableReferences),
      MemoryVersionRow,
      PrefetchHooks Function({bool itemId})
    >;
typedef $$MemoryEpisodesTableCreateCompanionBuilder =
    MemoryEpisodesCompanion Function({
      required String itemId,
      required String sourceRefsJson,
      Value<int> rowid,
    });
typedef $$MemoryEpisodesTableUpdateCompanionBuilder =
    MemoryEpisodesCompanion Function({
      Value<String> itemId,
      Value<String> sourceRefsJson,
      Value<int> rowid,
    });

final class $$MemoryEpisodesTableReferences
    extends
        BaseReferences<_$AppDatabase, $MemoryEpisodesTable, MemoryEpisodeRow> {
  $$MemoryEpisodesTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $MemoryItemsTable _itemIdTable(_$AppDatabase db) =>
      db.memoryItems.createAlias('memory_episodes__item_id__memory_items__id');

  $$MemoryItemsTableProcessedTableManager get itemId {
    final $_column = $_itemColumn<String>('item_id')!;

    final manager = $$MemoryItemsTableTableManager(
      $_db,
      $_db.memoryItems,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_itemIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$MemoryEpisodesTableFilterComposer
    extends Composer<_$AppDatabase, $MemoryEpisodesTable> {
  $$MemoryEpisodesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get sourceRefsJson => $composableBuilder(
    column: $table.sourceRefsJson,
    builder: (column) => ColumnFilters(column),
  );

  $$MemoryItemsTableFilterComposer get itemId {
    final $$MemoryItemsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.itemId,
      referencedTable: $db.memoryItems,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MemoryItemsTableFilterComposer(
            $db: $db,
            $table: $db.memoryItems,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$MemoryEpisodesTableOrderingComposer
    extends Composer<_$AppDatabase, $MemoryEpisodesTable> {
  $$MemoryEpisodesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get sourceRefsJson => $composableBuilder(
    column: $table.sourceRefsJson,
    builder: (column) => ColumnOrderings(column),
  );

  $$MemoryItemsTableOrderingComposer get itemId {
    final $$MemoryItemsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.itemId,
      referencedTable: $db.memoryItems,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MemoryItemsTableOrderingComposer(
            $db: $db,
            $table: $db.memoryItems,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$MemoryEpisodesTableAnnotationComposer
    extends Composer<_$AppDatabase, $MemoryEpisodesTable> {
  $$MemoryEpisodesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get sourceRefsJson => $composableBuilder(
    column: $table.sourceRefsJson,
    builder: (column) => column,
  );

  $$MemoryItemsTableAnnotationComposer get itemId {
    final $$MemoryItemsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.itemId,
      referencedTable: $db.memoryItems,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MemoryItemsTableAnnotationComposer(
            $db: $db,
            $table: $db.memoryItems,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$MemoryEpisodesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $MemoryEpisodesTable,
          MemoryEpisodeRow,
          $$MemoryEpisodesTableFilterComposer,
          $$MemoryEpisodesTableOrderingComposer,
          $$MemoryEpisodesTableAnnotationComposer,
          $$MemoryEpisodesTableCreateCompanionBuilder,
          $$MemoryEpisodesTableUpdateCompanionBuilder,
          (MemoryEpisodeRow, $$MemoryEpisodesTableReferences),
          MemoryEpisodeRow,
          PrefetchHooks Function({bool itemId})
        > {
  $$MemoryEpisodesTableTableManager(
    _$AppDatabase db,
    $MemoryEpisodesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$MemoryEpisodesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$MemoryEpisodesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$MemoryEpisodesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> itemId = const Value.absent(),
                Value<String> sourceRefsJson = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => MemoryEpisodesCompanion(
                itemId: itemId,
                sourceRefsJson: sourceRefsJson,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String itemId,
                required String sourceRefsJson,
                Value<int> rowid = const Value.absent(),
              }) => MemoryEpisodesCompanion.insert(
                itemId: itemId,
                sourceRefsJson: sourceRefsJson,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$MemoryEpisodesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({itemId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (itemId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.itemId,
                                referencedTable: $$MemoryEpisodesTableReferences
                                    ._itemIdTable(db),
                                referencedColumn:
                                    $$MemoryEpisodesTableReferences
                                        ._itemIdTable(db)
                                        .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$MemoryEpisodesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $MemoryEpisodesTable,
      MemoryEpisodeRow,
      $$MemoryEpisodesTableFilterComposer,
      $$MemoryEpisodesTableOrderingComposer,
      $$MemoryEpisodesTableAnnotationComposer,
      $$MemoryEpisodesTableCreateCompanionBuilder,
      $$MemoryEpisodesTableUpdateCompanionBuilder,
      (MemoryEpisodeRow, $$MemoryEpisodesTableReferences),
      MemoryEpisodeRow,
      PrefetchHooks Function({bool itemId})
    >;
typedef $$MemoryProceduresTableCreateCompanionBuilder =
    MemoryProceduresCompanion Function({
      required String itemId,
      required String stepsJson,
      Value<String?> triggerContext,
      required String sourceRefsJson,
      Value<int> rowid,
    });
typedef $$MemoryProceduresTableUpdateCompanionBuilder =
    MemoryProceduresCompanion Function({
      Value<String> itemId,
      Value<String> stepsJson,
      Value<String?> triggerContext,
      Value<String> sourceRefsJson,
      Value<int> rowid,
    });

final class $$MemoryProceduresTableReferences
    extends
        BaseReferences<
          _$AppDatabase,
          $MemoryProceduresTable,
          MemoryProcedureRow
        > {
  $$MemoryProceduresTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $MemoryItemsTable _itemIdTable(_$AppDatabase db) => db.memoryItems
      .createAlias('memory_procedures__item_id__memory_items__id');

  $$MemoryItemsTableProcessedTableManager get itemId {
    final $_column = $_itemColumn<String>('item_id')!;

    final manager = $$MemoryItemsTableTableManager(
      $_db,
      $_db.memoryItems,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_itemIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$MemoryProceduresTableFilterComposer
    extends Composer<_$AppDatabase, $MemoryProceduresTable> {
  $$MemoryProceduresTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get stepsJson => $composableBuilder(
    column: $table.stepsJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get triggerContext => $composableBuilder(
    column: $table.triggerContext,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sourceRefsJson => $composableBuilder(
    column: $table.sourceRefsJson,
    builder: (column) => ColumnFilters(column),
  );

  $$MemoryItemsTableFilterComposer get itemId {
    final $$MemoryItemsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.itemId,
      referencedTable: $db.memoryItems,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MemoryItemsTableFilterComposer(
            $db: $db,
            $table: $db.memoryItems,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$MemoryProceduresTableOrderingComposer
    extends Composer<_$AppDatabase, $MemoryProceduresTable> {
  $$MemoryProceduresTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get stepsJson => $composableBuilder(
    column: $table.stepsJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get triggerContext => $composableBuilder(
    column: $table.triggerContext,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sourceRefsJson => $composableBuilder(
    column: $table.sourceRefsJson,
    builder: (column) => ColumnOrderings(column),
  );

  $$MemoryItemsTableOrderingComposer get itemId {
    final $$MemoryItemsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.itemId,
      referencedTable: $db.memoryItems,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MemoryItemsTableOrderingComposer(
            $db: $db,
            $table: $db.memoryItems,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$MemoryProceduresTableAnnotationComposer
    extends Composer<_$AppDatabase, $MemoryProceduresTable> {
  $$MemoryProceduresTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get stepsJson =>
      $composableBuilder(column: $table.stepsJson, builder: (column) => column);

  GeneratedColumn<String> get triggerContext => $composableBuilder(
    column: $table.triggerContext,
    builder: (column) => column,
  );

  GeneratedColumn<String> get sourceRefsJson => $composableBuilder(
    column: $table.sourceRefsJson,
    builder: (column) => column,
  );

  $$MemoryItemsTableAnnotationComposer get itemId {
    final $$MemoryItemsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.itemId,
      referencedTable: $db.memoryItems,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MemoryItemsTableAnnotationComposer(
            $db: $db,
            $table: $db.memoryItems,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$MemoryProceduresTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $MemoryProceduresTable,
          MemoryProcedureRow,
          $$MemoryProceduresTableFilterComposer,
          $$MemoryProceduresTableOrderingComposer,
          $$MemoryProceduresTableAnnotationComposer,
          $$MemoryProceduresTableCreateCompanionBuilder,
          $$MemoryProceduresTableUpdateCompanionBuilder,
          (MemoryProcedureRow, $$MemoryProceduresTableReferences),
          MemoryProcedureRow,
          PrefetchHooks Function({bool itemId})
        > {
  $$MemoryProceduresTableTableManager(
    _$AppDatabase db,
    $MemoryProceduresTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$MemoryProceduresTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$MemoryProceduresTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$MemoryProceduresTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> itemId = const Value.absent(),
                Value<String> stepsJson = const Value.absent(),
                Value<String?> triggerContext = const Value.absent(),
                Value<String> sourceRefsJson = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => MemoryProceduresCompanion(
                itemId: itemId,
                stepsJson: stepsJson,
                triggerContext: triggerContext,
                sourceRefsJson: sourceRefsJson,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String itemId,
                required String stepsJson,
                Value<String?> triggerContext = const Value.absent(),
                required String sourceRefsJson,
                Value<int> rowid = const Value.absent(),
              }) => MemoryProceduresCompanion.insert(
                itemId: itemId,
                stepsJson: stepsJson,
                triggerContext: triggerContext,
                sourceRefsJson: sourceRefsJson,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$MemoryProceduresTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({itemId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (itemId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.itemId,
                                referencedTable:
                                    $$MemoryProceduresTableReferences
                                        ._itemIdTable(db),
                                referencedColumn:
                                    $$MemoryProceduresTableReferences
                                        ._itemIdTable(db)
                                        .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$MemoryProceduresTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $MemoryProceduresTable,
      MemoryProcedureRow,
      $$MemoryProceduresTableFilterComposer,
      $$MemoryProceduresTableOrderingComposer,
      $$MemoryProceduresTableAnnotationComposer,
      $$MemoryProceduresTableCreateCompanionBuilder,
      $$MemoryProceduresTableUpdateCompanionBuilder,
      (MemoryProcedureRow, $$MemoryProceduresTableReferences),
      MemoryProcedureRow,
      PrefetchHooks Function({bool itemId})
    >;
typedef $$MemoryUsageTableCreateCompanionBuilder =
    MemoryUsageCompanion Function({
      required String itemId,
      Value<int> recallCount,
      Value<int> injectCount,
      Value<int?> lastUsedAt,
      Value<int> rowid,
    });
typedef $$MemoryUsageTableUpdateCompanionBuilder =
    MemoryUsageCompanion Function({
      Value<String> itemId,
      Value<int> recallCount,
      Value<int> injectCount,
      Value<int?> lastUsedAt,
      Value<int> rowid,
    });

final class $$MemoryUsageTableReferences
    extends BaseReferences<_$AppDatabase, $MemoryUsageTable, MemoryUsageRow> {
  $$MemoryUsageTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $MemoryItemsTable _itemIdTable(_$AppDatabase db) =>
      db.memoryItems.createAlias('memory_usage__item_id__memory_items__id');

  $$MemoryItemsTableProcessedTableManager get itemId {
    final $_column = $_itemColumn<String>('item_id')!;

    final manager = $$MemoryItemsTableTableManager(
      $_db,
      $_db.memoryItems,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_itemIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$MemoryUsageTableFilterComposer
    extends Composer<_$AppDatabase, $MemoryUsageTable> {
  $$MemoryUsageTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get recallCount => $composableBuilder(
    column: $table.recallCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get injectCount => $composableBuilder(
    column: $table.injectCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get lastUsedAt => $composableBuilder(
    column: $table.lastUsedAt,
    builder: (column) => ColumnFilters(column),
  );

  $$MemoryItemsTableFilterComposer get itemId {
    final $$MemoryItemsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.itemId,
      referencedTable: $db.memoryItems,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MemoryItemsTableFilterComposer(
            $db: $db,
            $table: $db.memoryItems,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$MemoryUsageTableOrderingComposer
    extends Composer<_$AppDatabase, $MemoryUsageTable> {
  $$MemoryUsageTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get recallCount => $composableBuilder(
    column: $table.recallCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get injectCount => $composableBuilder(
    column: $table.injectCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get lastUsedAt => $composableBuilder(
    column: $table.lastUsedAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$MemoryItemsTableOrderingComposer get itemId {
    final $$MemoryItemsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.itemId,
      referencedTable: $db.memoryItems,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MemoryItemsTableOrderingComposer(
            $db: $db,
            $table: $db.memoryItems,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$MemoryUsageTableAnnotationComposer
    extends Composer<_$AppDatabase, $MemoryUsageTable> {
  $$MemoryUsageTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get recallCount => $composableBuilder(
    column: $table.recallCount,
    builder: (column) => column,
  );

  GeneratedColumn<int> get injectCount => $composableBuilder(
    column: $table.injectCount,
    builder: (column) => column,
  );

  GeneratedColumn<int> get lastUsedAt => $composableBuilder(
    column: $table.lastUsedAt,
    builder: (column) => column,
  );

  $$MemoryItemsTableAnnotationComposer get itemId {
    final $$MemoryItemsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.itemId,
      referencedTable: $db.memoryItems,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MemoryItemsTableAnnotationComposer(
            $db: $db,
            $table: $db.memoryItems,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$MemoryUsageTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $MemoryUsageTable,
          MemoryUsageRow,
          $$MemoryUsageTableFilterComposer,
          $$MemoryUsageTableOrderingComposer,
          $$MemoryUsageTableAnnotationComposer,
          $$MemoryUsageTableCreateCompanionBuilder,
          $$MemoryUsageTableUpdateCompanionBuilder,
          (MemoryUsageRow, $$MemoryUsageTableReferences),
          MemoryUsageRow,
          PrefetchHooks Function({bool itemId})
        > {
  $$MemoryUsageTableTableManager(_$AppDatabase db, $MemoryUsageTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$MemoryUsageTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$MemoryUsageTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$MemoryUsageTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> itemId = const Value.absent(),
                Value<int> recallCount = const Value.absent(),
                Value<int> injectCount = const Value.absent(),
                Value<int?> lastUsedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => MemoryUsageCompanion(
                itemId: itemId,
                recallCount: recallCount,
                injectCount: injectCount,
                lastUsedAt: lastUsedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String itemId,
                Value<int> recallCount = const Value.absent(),
                Value<int> injectCount = const Value.absent(),
                Value<int?> lastUsedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => MemoryUsageCompanion.insert(
                itemId: itemId,
                recallCount: recallCount,
                injectCount: injectCount,
                lastUsedAt: lastUsedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$MemoryUsageTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({itemId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (itemId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.itemId,
                                referencedTable: $$MemoryUsageTableReferences
                                    ._itemIdTable(db),
                                referencedColumn: $$MemoryUsageTableReferences
                                    ._itemIdTable(db)
                                    .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$MemoryUsageTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $MemoryUsageTable,
      MemoryUsageRow,
      $$MemoryUsageTableFilterComposer,
      $$MemoryUsageTableOrderingComposer,
      $$MemoryUsageTableAnnotationComposer,
      $$MemoryUsageTableCreateCompanionBuilder,
      $$MemoryUsageTableUpdateCompanionBuilder,
      (MemoryUsageRow, $$MemoryUsageTableReferences),
      MemoryUsageRow,
      PrefetchHooks Function({bool itemId})
    >;
typedef $$AppSettingsTableCreateCompanionBuilder =
    AppSettingsCompanion Function({
      required String key,
      required String value,
      required int updatedAt,
      Value<int> rowid,
    });
typedef $$AppSettingsTableUpdateCompanionBuilder =
    AppSettingsCompanion Function({
      Value<String> key,
      Value<String> value,
      Value<int> updatedAt,
      Value<int> rowid,
    });

class $$AppSettingsTableFilterComposer
    extends Composer<_$AppDatabase, $AppSettingsTable> {
  $$AppSettingsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$AppSettingsTableOrderingComposer
    extends Composer<_$AppDatabase, $AppSettingsTable> {
  $$AppSettingsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$AppSettingsTableAnnotationComposer
    extends Composer<_$AppDatabase, $AppSettingsTable> {
  $$AppSettingsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get key =>
      $composableBuilder(column: $table.key, builder: (column) => column);

  GeneratedColumn<String> get value =>
      $composableBuilder(column: $table.value, builder: (column) => column);

  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$AppSettingsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $AppSettingsTable,
          AppSettingRow,
          $$AppSettingsTableFilterComposer,
          $$AppSettingsTableOrderingComposer,
          $$AppSettingsTableAnnotationComposer,
          $$AppSettingsTableCreateCompanionBuilder,
          $$AppSettingsTableUpdateCompanionBuilder,
          (
            AppSettingRow,
            BaseReferences<_$AppDatabase, $AppSettingsTable, AppSettingRow>,
          ),
          AppSettingRow,
          PrefetchHooks Function()
        > {
  $$AppSettingsTableTableManager(_$AppDatabase db, $AppSettingsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AppSettingsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AppSettingsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AppSettingsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> key = const Value.absent(),
                Value<String> value = const Value.absent(),
                Value<int> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => AppSettingsCompanion(
                key: key,
                value: value,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String key,
                required String value,
                required int updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => AppSettingsCompanion.insert(
                key: key,
                value: value,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$AppSettingsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $AppSettingsTable,
      AppSettingRow,
      $$AppSettingsTableFilterComposer,
      $$AppSettingsTableOrderingComposer,
      $$AppSettingsTableAnnotationComposer,
      $$AppSettingsTableCreateCompanionBuilder,
      $$AppSettingsTableUpdateCompanionBuilder,
      (
        AppSettingRow,
        BaseReferences<_$AppDatabase, $AppSettingsTable, AppSettingRow>,
      ),
      AppSettingRow,
      PrefetchHooks Function()
    >;
typedef $$SearchUsageTableCreateCompanionBuilder =
    SearchUsageCompanion Function({
      required String month,
      Value<int> credits,
      Value<int> rowid,
    });
typedef $$SearchUsageTableUpdateCompanionBuilder =
    SearchUsageCompanion Function({
      Value<String> month,
      Value<int> credits,
      Value<int> rowid,
    });

class $$SearchUsageTableFilterComposer
    extends Composer<_$AppDatabase, $SearchUsageTable> {
  $$SearchUsageTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get month => $composableBuilder(
    column: $table.month,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get credits => $composableBuilder(
    column: $table.credits,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SearchUsageTableOrderingComposer
    extends Composer<_$AppDatabase, $SearchUsageTable> {
  $$SearchUsageTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get month => $composableBuilder(
    column: $table.month,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get credits => $composableBuilder(
    column: $table.credits,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SearchUsageTableAnnotationComposer
    extends Composer<_$AppDatabase, $SearchUsageTable> {
  $$SearchUsageTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get month =>
      $composableBuilder(column: $table.month, builder: (column) => column);

  GeneratedColumn<int> get credits =>
      $composableBuilder(column: $table.credits, builder: (column) => column);
}

class $$SearchUsageTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SearchUsageTable,
          SearchUsageData,
          $$SearchUsageTableFilterComposer,
          $$SearchUsageTableOrderingComposer,
          $$SearchUsageTableAnnotationComposer,
          $$SearchUsageTableCreateCompanionBuilder,
          $$SearchUsageTableUpdateCompanionBuilder,
          (
            SearchUsageData,
            BaseReferences<_$AppDatabase, $SearchUsageTable, SearchUsageData>,
          ),
          SearchUsageData,
          PrefetchHooks Function()
        > {
  $$SearchUsageTableTableManager(_$AppDatabase db, $SearchUsageTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SearchUsageTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SearchUsageTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SearchUsageTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> month = const Value.absent(),
                Value<int> credits = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SearchUsageCompanion(
                month: month,
                credits: credits,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String month,
                Value<int> credits = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SearchUsageCompanion.insert(
                month: month,
                credits: credits,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SearchUsageTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SearchUsageTable,
      SearchUsageData,
      $$SearchUsageTableFilterComposer,
      $$SearchUsageTableOrderingComposer,
      $$SearchUsageTableAnnotationComposer,
      $$SearchUsageTableCreateCompanionBuilder,
      $$SearchUsageTableUpdateCompanionBuilder,
      (
        SearchUsageData,
        BaseReferences<_$AppDatabase, $SearchUsageTable, SearchUsageData>,
      ),
      SearchUsageData,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$GoalsTableTableManager get goals =>
      $$GoalsTableTableManager(_db, _db.goals);
  $$GoalNodesTableTableManager get goalNodes =>
      $$GoalNodesTableTableManager(_db, _db.goalNodes);
  $$MissionsTableTableManager get missions =>
      $$MissionsTableTableManager(_db, _db.missions);
  $$MissionScheduleRevisionsTableTableManager get missionScheduleRevisions =>
      $$MissionScheduleRevisionsTableTableManager(
        _db,
        _db.missionScheduleRevisions,
      );
  $$ExecutionPlansTableTableManager get executionPlans =>
      $$ExecutionPlansTableTableManager(_db, _db.executionPlans);
  $$ExecutionEventsTableTableManager get executionEvents =>
      $$ExecutionEventsTableTableManager(_db, _db.executionEvents);
  $$FailureRecordsTableTableManager get failureRecords =>
      $$FailureRecordsTableTableManager(_db, _db.failureRecords);
  $$EvidenceRecordsTableTableManager get evidenceRecords =>
      $$EvidenceRecordsTableTableManager(_db, _db.evidenceRecords);
  $$ImportReceiptsTableTableManager get importReceipts =>
      $$ImportReceiptsTableTableManager(_db, _db.importReceipts);
  $$AssistantSessionsTableTableManager get assistantSessions =>
      $$AssistantSessionsTableTableManager(_db, _db.assistantSessions);
  $$AssistantSessionRecordsTableTableManager get assistantSessionRecords =>
      $$AssistantSessionRecordsTableTableManager(
        _db,
        _db.assistantSessionRecords,
      );
  $$OperationReceiptsTableTableManager get operationReceipts =>
      $$OperationReceiptsTableTableManager(_db, _db.operationReceipts);
  $$RecordsTableTableManager get records =>
      $$RecordsTableTableManager(_db, _db.records);
  $$UserExecutionReportsTableTableManager get userExecutionReports =>
      $$UserExecutionReportsTableTableManager(_db, _db.userExecutionReports);
  $$AnalysisJobsTableTableManager get analysisJobs =>
      $$AnalysisJobsTableTableManager(_db, _db.analysisJobs);
  $$AnalysisVersionsTableTableManager get analysisVersions =>
      $$AnalysisVersionsTableTableManager(_db, _db.analysisVersions);
  $$MemoryTopicsTableTableManager get memoryTopics =>
      $$MemoryTopicsTableTableManager(_db, _db.memoryTopics);
  $$MemoryItemsTableTableManager get memoryItems =>
      $$MemoryItemsTableTableManager(_db, _db.memoryItems);
  $$MemoryTopicAliasesTableTableManager get memoryTopicAliases =>
      $$MemoryTopicAliasesTableTableManager(_db, _db.memoryTopicAliases);
  $$MemoryVersionsTableTableManager get memoryVersions =>
      $$MemoryVersionsTableTableManager(_db, _db.memoryVersions);
  $$MemoryEpisodesTableTableManager get memoryEpisodes =>
      $$MemoryEpisodesTableTableManager(_db, _db.memoryEpisodes);
  $$MemoryProceduresTableTableManager get memoryProcedures =>
      $$MemoryProceduresTableTableManager(_db, _db.memoryProcedures);
  $$MemoryUsageTableTableManager get memoryUsage =>
      $$MemoryUsageTableTableManager(_db, _db.memoryUsage);
  $$AppSettingsTableTableManager get appSettings =>
      $$AppSettingsTableTableManager(_db, _db.appSettings);
  $$SearchUsageTableTableManager get searchUsage =>
      $$SearchUsageTableTableManager(_db, _db.searchUsage);
}

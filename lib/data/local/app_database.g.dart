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
  final String status;
  final int createdAt;
  final int updatedAt;
  const GoalRow({
    required this.id,
    required this.title,
    this.description,
    this.why,
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
    String? status,
    int? createdAt,
    int? updatedAt,
  }) => GoalRow(
    id: id ?? this.id,
    title: title ?? this.title,
    description: description.present ? description.value : this.description,
    why: why.present ? why.value : this.why,
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
          ..write('status: $status, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, title, description, why, status, createdAt, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is GoalRow &&
          other.id == this.id &&
          other.title == this.title &&
          other.description == this.description &&
          other.why == this.why &&
          other.status == this.status &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class GoalsCompanion extends UpdateCompanion<GoalRow> {
  final Value<String> id;
  final Value<String> title;
  final Value<String?> description;
  final Value<String?> why;
  final Value<String> status;
  final Value<int> createdAt;
  final Value<int> updatedAt;
  final Value<int> rowid;
  const GoalsCompanion({
    this.id = const Value.absent(),
    this.title = const Value.absent(),
    this.description = const Value.absent(),
    this.why = const Value.absent(),
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
          ..write('submitOptionalEvidence: $submitOptionalEvidence')
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
          other.submitOptionalEvidence == this.submitOptionalEvidence);
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
    missionScheduleFixed,
    executionEventsOneStart,
    executionEventsOneEnd,
    evidenceRecordsMission,
    importReceiptsContent,
    assistantSessionsUpdated,
    operationReceiptsEntity,
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
                Value<String> status = const Value.absent(),
                Value<int> createdAt = const Value.absent(),
                Value<int> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => GoalsCompanion(
                id: id,
                title: title,
                description: description,
                why: why,
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
                Value<String> status = const Value.absent(),
                required int createdAt,
                required int updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => GoalsCompanion.insert(
                id: id,
                title: title,
                description: description,
                why: why,
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
              }) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (goalNodesRefs) db.goalNodes,
                    if (missionsRefs) db.missions,
                    if (importReceiptsRefs) db.importReceipts,
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
          PrefetchHooks Function({bool goalId, bool missionsRefs})
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
          prefetchHooksCallback: ({goalId = false, missionsRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [if (missionsRefs) db.missions],
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
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where((e) => e.goalNodeId == item.id),
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
      PrefetchHooks Function({bool goalId, bool missionsRefs})
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
}

// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $MissionsTable extends Missions
    with TableInfo<$MissionsTable, MissionRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $MissionsTable(this.attachedDatabase, [this._alias]);
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
    id,
    title,
    description,
    why,
    verificationPolicy,
    createdAt,
    updatedAt,
    cancelledAt,
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
  final String id;
  final String title;
  final String? description;
  final String? why;
  final String verificationPolicy;
  final int createdAt;
  final int updatedAt;
  final int? cancelledAt;
  final String? sourceMissionId;
  final String? relationType;
  const MissionRow({
    required this.id,
    required this.title,
    this.description,
    this.why,
    required this.verificationPolicy,
    required this.createdAt,
    required this.updatedAt,
    this.cancelledAt,
    this.sourceMissionId,
    this.relationType,
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
    map['verification_policy'] = Variable<String>(verificationPolicy);
    map['created_at'] = Variable<int>(createdAt);
    map['updated_at'] = Variable<int>(updatedAt);
    if (!nullToAbsent || cancelledAt != null) {
      map['cancelled_at'] = Variable<int>(cancelledAt);
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
      sourceMissionId: serializer.fromJson<String?>(json['sourceMissionId']),
      relationType: serializer.fromJson<String?>(json['relationType']),
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
      'verificationPolicy': serializer.toJson<String>(verificationPolicy),
      'createdAt': serializer.toJson<int>(createdAt),
      'updatedAt': serializer.toJson<int>(updatedAt),
      'cancelledAt': serializer.toJson<int?>(cancelledAt),
      'sourceMissionId': serializer.toJson<String?>(sourceMissionId),
      'relationType': serializer.toJson<String?>(relationType),
    };
  }

  MissionRow copyWith({
    String? id,
    String? title,
    Value<String?> description = const Value.absent(),
    Value<String?> why = const Value.absent(),
    String? verificationPolicy,
    int? createdAt,
    int? updatedAt,
    Value<int?> cancelledAt = const Value.absent(),
    Value<String?> sourceMissionId = const Value.absent(),
    Value<String?> relationType = const Value.absent(),
  }) => MissionRow(
    id: id ?? this.id,
    title: title ?? this.title,
    description: description.present ? description.value : this.description,
    why: why.present ? why.value : this.why,
    verificationPolicy: verificationPolicy ?? this.verificationPolicy,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    cancelledAt: cancelledAt.present ? cancelledAt.value : this.cancelledAt,
    sourceMissionId: sourceMissionId.present
        ? sourceMissionId.value
        : this.sourceMissionId,
    relationType: relationType.present ? relationType.value : this.relationType,
  );
  MissionRow copyWithCompanion(MissionsCompanion data) {
    return MissionRow(
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
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('description: $description, ')
          ..write('why: $why, ')
          ..write('verificationPolicy: $verificationPolicy, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('cancelledAt: $cancelledAt, ')
          ..write('sourceMissionId: $sourceMissionId, ')
          ..write('relationType: $relationType')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    title,
    description,
    why,
    verificationPolicy,
    createdAt,
    updatedAt,
    cancelledAt,
    sourceMissionId,
    relationType,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is MissionRow &&
          other.id == this.id &&
          other.title == this.title &&
          other.description == this.description &&
          other.why == this.why &&
          other.verificationPolicy == this.verificationPolicy &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.cancelledAt == this.cancelledAt &&
          other.sourceMissionId == this.sourceMissionId &&
          other.relationType == this.relationType);
}

class MissionsCompanion extends UpdateCompanion<MissionRow> {
  final Value<String> id;
  final Value<String> title;
  final Value<String?> description;
  final Value<String?> why;
  final Value<String> verificationPolicy;
  final Value<int> createdAt;
  final Value<int> updatedAt;
  final Value<int?> cancelledAt;
  final Value<String?> sourceMissionId;
  final Value<String?> relationType;
  final Value<int> rowid;
  const MissionsCompanion({
    this.id = const Value.absent(),
    this.title = const Value.absent(),
    this.description = const Value.absent(),
    this.why = const Value.absent(),
    this.verificationPolicy = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.cancelledAt = const Value.absent(),
    this.sourceMissionId = const Value.absent(),
    this.relationType = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  MissionsCompanion.insert({
    required String id,
    required String title,
    this.description = const Value.absent(),
    this.why = const Value.absent(),
    this.verificationPolicy = const Value.absent(),
    required int createdAt,
    required int updatedAt,
    this.cancelledAt = const Value.absent(),
    this.sourceMissionId = const Value.absent(),
    this.relationType = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       title = Value(title),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<MissionRow> custom({
    Expression<String>? id,
    Expression<String>? title,
    Expression<String>? description,
    Expression<String>? why,
    Expression<String>? verificationPolicy,
    Expression<int>? createdAt,
    Expression<int>? updatedAt,
    Expression<int>? cancelledAt,
    Expression<String>? sourceMissionId,
    Expression<String>? relationType,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (title != null) 'title': title,
      if (description != null) 'description': description,
      if (why != null) 'why': why,
      if (verificationPolicy != null) 'verification_policy': verificationPolicy,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (cancelledAt != null) 'cancelled_at': cancelledAt,
      if (sourceMissionId != null) 'source_mission_id': sourceMissionId,
      if (relationType != null) 'relation_type': relationType,
      if (rowid != null) 'rowid': rowid,
    });
  }

  MissionsCompanion copyWith({
    Value<String>? id,
    Value<String>? title,
    Value<String?>? description,
    Value<String?>? why,
    Value<String>? verificationPolicy,
    Value<int>? createdAt,
    Value<int>? updatedAt,
    Value<int?>? cancelledAt,
    Value<String?>? sourceMissionId,
    Value<String?>? relationType,
    Value<int>? rowid,
  }) {
    return MissionsCompanion(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      why: why ?? this.why,
      verificationPolicy: verificationPolicy ?? this.verificationPolicy,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      cancelledAt: cancelledAt ?? this.cancelledAt,
      sourceMissionId: sourceMissionId ?? this.sourceMissionId,
      relationType: relationType ?? this.relationType,
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
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('description: $description, ')
          ..write('why: $why, ')
          ..write('verificationPolicy: $verificationPolicy, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('cancelledAt: $cancelledAt, ')
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

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $MissionsTable missions = $MissionsTable(this);
  late final $MissionScheduleRevisionsTable missionScheduleRevisions =
      $MissionScheduleRevisionsTable(this);
  late final $ExecutionPlansTable executionPlans = $ExecutionPlansTable(this);
  late final $ExecutionEventsTable executionEvents = $ExecutionEventsTable(
    this,
  );
  late final $FailureRecordsTable failureRecords = $FailureRecordsTable(this);
  late final Index executionEventsOneStart = Index(
    'execution_events_one_start',
    'CREATE UNIQUE INDEX execution_events_one_start ON execution_events (mission_id) WHERE type = \'START\'',
  );
  late final Index executionEventsOneEnd = Index(
    'execution_events_one_end',
    'CREATE UNIQUE INDEX execution_events_one_end ON execution_events (mission_id) WHERE type = \'END\'',
  );
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    missions,
    missionScheduleRevisions,
    executionPlans,
    executionEvents,
    failureRecords,
    executionEventsOneStart,
    executionEventsOneEnd,
  ];
}

typedef $$MissionsTableCreateCompanionBuilder =
    MissionsCompanion Function({
      required String id,
      required String title,
      Value<String?> description,
      Value<String?> why,
      Value<String> verificationPolicy,
      required int createdAt,
      required int updatedAt,
      Value<int?> cancelledAt,
      Value<String?> sourceMissionId,
      Value<String?> relationType,
      Value<int> rowid,
    });
typedef $$MissionsTableUpdateCompanionBuilder =
    MissionsCompanion Function({
      Value<String> id,
      Value<String> title,
      Value<String?> description,
      Value<String?> why,
      Value<String> verificationPolicy,
      Value<int> createdAt,
      Value<int> updatedAt,
      Value<int?> cancelledAt,
      Value<String?> sourceMissionId,
      Value<String?> relationType,
      Value<int> rowid,
    });

final class $$MissionsTableReferences
    extends BaseReferences<_$AppDatabase, $MissionsTable, MissionRow> {
  $$MissionsTableReferences(super.$_db, super.$_table, super.$_typedResult);

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

  ColumnFilters<String> get relationType => $composableBuilder(
    column: $table.relationType,
    builder: (column) => ColumnFilters(column),
  );

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

  ColumnOrderings<String> get relationType => $composableBuilder(
    column: $table.relationType,
    builder: (column) => ColumnOrderings(column),
  );

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

  GeneratedColumn<String> get relationType => $composableBuilder(
    column: $table.relationType,
    builder: (column) => column,
  );

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
            bool sourceMissionId,
            bool missionScheduleRevisionsRefs,
            bool executionPlansRefs,
            bool executionEventsRefs,
            bool failureRecordsRefs,
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
                Value<String> id = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String?> description = const Value.absent(),
                Value<String?> why = const Value.absent(),
                Value<String> verificationPolicy = const Value.absent(),
                Value<int> createdAt = const Value.absent(),
                Value<int> updatedAt = const Value.absent(),
                Value<int?> cancelledAt = const Value.absent(),
                Value<String?> sourceMissionId = const Value.absent(),
                Value<String?> relationType = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => MissionsCompanion(
                id: id,
                title: title,
                description: description,
                why: why,
                verificationPolicy: verificationPolicy,
                createdAt: createdAt,
                updatedAt: updatedAt,
                cancelledAt: cancelledAt,
                sourceMissionId: sourceMissionId,
                relationType: relationType,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String title,
                Value<String?> description = const Value.absent(),
                Value<String?> why = const Value.absent(),
                Value<String> verificationPolicy = const Value.absent(),
                required int createdAt,
                required int updatedAt,
                Value<int?> cancelledAt = const Value.absent(),
                Value<String?> sourceMissionId = const Value.absent(),
                Value<String?> relationType = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => MissionsCompanion.insert(
                id: id,
                title: title,
                description: description,
                why: why,
                verificationPolicy: verificationPolicy,
                createdAt: createdAt,
                updatedAt: updatedAt,
                cancelledAt: cancelledAt,
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
                sourceMissionId = false,
                missionScheduleRevisionsRefs = false,
                executionPlansRefs = false,
                executionEventsRefs = false,
                failureRecordsRefs = false,
              }) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (missionScheduleRevisionsRefs)
                      db.missionScheduleRevisions,
                    if (executionPlansRefs) db.executionPlans,
                    if (executionEventsRefs) db.executionEvents,
                    if (failureRecordsRefs) db.failureRecords,
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
        bool sourceMissionId,
        bool missionScheduleRevisionsRefs,
        bool executionPlansRefs,
        bool executionEventsRefs,
        bool failureRecordsRefs,
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

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
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
}

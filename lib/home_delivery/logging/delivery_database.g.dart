// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'delivery_database.dart';

// ignore_for_file: type=lint
class $DeliveryLogsTable extends DeliveryLogs
    with TableInfo<$DeliveryLogsTable, DeliveryLog> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DeliveryLogsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
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
  );
  static const VerificationMeta _prayerMeta = const VerificationMeta('prayer');
  @override
  late final GeneratedColumn<String> prayer = GeneratedColumn<String>(
    'prayer',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _scheduledAtMeta = const VerificationMeta(
    'scheduledAt',
  );
  @override
  late final GeneratedColumn<int> scheduledAt = GeneratedColumn<int>(
    'scheduled_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _firedAtMeta = const VerificationMeta(
    'firedAt',
  );
  @override
  late final GeneratedColumn<int> firedAt = GeneratedColumn<int>(
    'fired_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _presenceStateMeta = const VerificationMeta(
    'presenceState',
  );
  @override
  late final GeneratedColumn<String> presenceState = GeneratedColumn<String>(
    'presence_state',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _presenceSignalMeta = const VerificationMeta(
    'presenceSignal',
  );
  @override
  late final GeneratedColumn<String> presenceSignal = GeneratedColumn<String>(
    'presence_signal',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _roleMeta = const VerificationMeta('role');
  @override
  late final GeneratedColumn<String> role = GeneratedColumn<String>(
    'role',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _peerCountMeta = const VerificationMeta(
    'peerCount',
  );
  @override
  late final GeneratedColumn<int> peerCount = GeneratedColumn<int>(
    'peer_count',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _targetIdMeta = const VerificationMeta(
    'targetId',
  );
  @override
  late final GeneratedColumn<String> targetId = GeneratedColumn<String>(
    'target_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _targetNameMeta = const VerificationMeta(
    'targetName',
  );
  @override
  late final GeneratedColumn<String> targetName = GeneratedColumn<String>(
    'target_name',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _outcomeMeta = const VerificationMeta(
    'outcome',
  );
  @override
  late final GeneratedColumn<String> outcome = GeneratedColumn<String>(
    'outcome',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _detailMeta = const VerificationMeta('detail');
  @override
  late final GeneratedColumn<String> detail = GeneratedColumn<String>(
    'detail',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _latencyMsMeta = const VerificationMeta(
    'latencyMs',
  );
  @override
  late final GeneratedColumn<int> latencyMs = GeneratedColumn<int>(
    'latency_ms',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    sessionId,
    prayer,
    scheduledAt,
    firedAt,
    presenceState,
    presenceSignal,
    role,
    peerCount,
    targetId,
    targetName,
    outcome,
    detail,
    latencyMs,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'delivery_logs';
  @override
  VerificationContext validateIntegrity(
    Insertable<DeliveryLog> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('session_id')) {
      context.handle(
        _sessionIdMeta,
        sessionId.isAcceptableOrUnknown(data['session_id']!, _sessionIdMeta),
      );
    } else if (isInserting) {
      context.missing(_sessionIdMeta);
    }
    if (data.containsKey('prayer')) {
      context.handle(
        _prayerMeta,
        prayer.isAcceptableOrUnknown(data['prayer']!, _prayerMeta),
      );
    } else if (isInserting) {
      context.missing(_prayerMeta);
    }
    if (data.containsKey('scheduled_at')) {
      context.handle(
        _scheduledAtMeta,
        scheduledAt.isAcceptableOrUnknown(
          data['scheduled_at']!,
          _scheduledAtMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_scheduledAtMeta);
    }
    if (data.containsKey('fired_at')) {
      context.handle(
        _firedAtMeta,
        firedAt.isAcceptableOrUnknown(data['fired_at']!, _firedAtMeta),
      );
    }
    if (data.containsKey('presence_state')) {
      context.handle(
        _presenceStateMeta,
        presenceState.isAcceptableOrUnknown(
          data['presence_state']!,
          _presenceStateMeta,
        ),
      );
    }
    if (data.containsKey('presence_signal')) {
      context.handle(
        _presenceSignalMeta,
        presenceSignal.isAcceptableOrUnknown(
          data['presence_signal']!,
          _presenceSignalMeta,
        ),
      );
    }
    if (data.containsKey('role')) {
      context.handle(
        _roleMeta,
        role.isAcceptableOrUnknown(data['role']!, _roleMeta),
      );
    }
    if (data.containsKey('peer_count')) {
      context.handle(
        _peerCountMeta,
        peerCount.isAcceptableOrUnknown(data['peer_count']!, _peerCountMeta),
      );
    }
    if (data.containsKey('target_id')) {
      context.handle(
        _targetIdMeta,
        targetId.isAcceptableOrUnknown(data['target_id']!, _targetIdMeta),
      );
    }
    if (data.containsKey('target_name')) {
      context.handle(
        _targetNameMeta,
        targetName.isAcceptableOrUnknown(data['target_name']!, _targetNameMeta),
      );
    }
    if (data.containsKey('outcome')) {
      context.handle(
        _outcomeMeta,
        outcome.isAcceptableOrUnknown(data['outcome']!, _outcomeMeta),
      );
    } else if (isInserting) {
      context.missing(_outcomeMeta);
    }
    if (data.containsKey('detail')) {
      context.handle(
        _detailMeta,
        detail.isAcceptableOrUnknown(data['detail']!, _detailMeta),
      );
    }
    if (data.containsKey('latency_ms')) {
      context.handle(
        _latencyMsMeta,
        latencyMs.isAcceptableOrUnknown(data['latency_ms']!, _latencyMsMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  DeliveryLog map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DeliveryLog(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      sessionId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}session_id'],
      )!,
      prayer: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}prayer'],
      )!,
      scheduledAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}scheduled_at'],
      )!,
      firedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}fired_at'],
      ),
      presenceState: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}presence_state'],
      ),
      presenceSignal: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}presence_signal'],
      ),
      role: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}role'],
      ),
      peerCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}peer_count'],
      ),
      targetId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}target_id'],
      ),
      targetName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}target_name'],
      ),
      outcome: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}outcome'],
      )!,
      detail: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}detail'],
      ),
      latencyMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}latency_ms'],
      ),
    );
  }

  @override
  $DeliveryLogsTable createAlias(String alias) {
    return $DeliveryLogsTable(attachedDatabase, alias);
  }
}

class DeliveryLog extends DataClass implements Insertable<DeliveryLog> {
  final int id;
  final String sessionId;
  final String prayer;

  /// Scheduled azan time, Unix epoch milliseconds.
  final int scheduledAt;
  final int? firedAt;

  /// HOME | AWAY | UNKNOWN
  final String? presenceState;

  /// A | B | C | D | NONE
  final String? presenceSignal;

  /// LEADER | FOLLOWER | SOLO | PROMOTED
  final String? role;
  final int? peerCount;
  final String? targetId;
  final String? targetName;

  /// See [Outcome.code] (§6.2).
  final String outcome;
  final String? detail;

  /// loadMedia call → PLAYING state, milliseconds.
  final int? latencyMs;
  const DeliveryLog({
    required this.id,
    required this.sessionId,
    required this.prayer,
    required this.scheduledAt,
    this.firedAt,
    this.presenceState,
    this.presenceSignal,
    this.role,
    this.peerCount,
    this.targetId,
    this.targetName,
    required this.outcome,
    this.detail,
    this.latencyMs,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['session_id'] = Variable<String>(sessionId);
    map['prayer'] = Variable<String>(prayer);
    map['scheduled_at'] = Variable<int>(scheduledAt);
    if (!nullToAbsent || firedAt != null) {
      map['fired_at'] = Variable<int>(firedAt);
    }
    if (!nullToAbsent || presenceState != null) {
      map['presence_state'] = Variable<String>(presenceState);
    }
    if (!nullToAbsent || presenceSignal != null) {
      map['presence_signal'] = Variable<String>(presenceSignal);
    }
    if (!nullToAbsent || role != null) {
      map['role'] = Variable<String>(role);
    }
    if (!nullToAbsent || peerCount != null) {
      map['peer_count'] = Variable<int>(peerCount);
    }
    if (!nullToAbsent || targetId != null) {
      map['target_id'] = Variable<String>(targetId);
    }
    if (!nullToAbsent || targetName != null) {
      map['target_name'] = Variable<String>(targetName);
    }
    map['outcome'] = Variable<String>(outcome);
    if (!nullToAbsent || detail != null) {
      map['detail'] = Variable<String>(detail);
    }
    if (!nullToAbsent || latencyMs != null) {
      map['latency_ms'] = Variable<int>(latencyMs);
    }
    return map;
  }

  DeliveryLogsCompanion toCompanion(bool nullToAbsent) {
    return DeliveryLogsCompanion(
      id: Value(id),
      sessionId: Value(sessionId),
      prayer: Value(prayer),
      scheduledAt: Value(scheduledAt),
      firedAt: firedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(firedAt),
      presenceState: presenceState == null && nullToAbsent
          ? const Value.absent()
          : Value(presenceState),
      presenceSignal: presenceSignal == null && nullToAbsent
          ? const Value.absent()
          : Value(presenceSignal),
      role: role == null && nullToAbsent ? const Value.absent() : Value(role),
      peerCount: peerCount == null && nullToAbsent
          ? const Value.absent()
          : Value(peerCount),
      targetId: targetId == null && nullToAbsent
          ? const Value.absent()
          : Value(targetId),
      targetName: targetName == null && nullToAbsent
          ? const Value.absent()
          : Value(targetName),
      outcome: Value(outcome),
      detail: detail == null && nullToAbsent
          ? const Value.absent()
          : Value(detail),
      latencyMs: latencyMs == null && nullToAbsent
          ? const Value.absent()
          : Value(latencyMs),
    );
  }

  factory DeliveryLog.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DeliveryLog(
      id: serializer.fromJson<int>(json['id']),
      sessionId: serializer.fromJson<String>(json['sessionId']),
      prayer: serializer.fromJson<String>(json['prayer']),
      scheduledAt: serializer.fromJson<int>(json['scheduledAt']),
      firedAt: serializer.fromJson<int?>(json['firedAt']),
      presenceState: serializer.fromJson<String?>(json['presenceState']),
      presenceSignal: serializer.fromJson<String?>(json['presenceSignal']),
      role: serializer.fromJson<String?>(json['role']),
      peerCount: serializer.fromJson<int?>(json['peerCount']),
      targetId: serializer.fromJson<String?>(json['targetId']),
      targetName: serializer.fromJson<String?>(json['targetName']),
      outcome: serializer.fromJson<String>(json['outcome']),
      detail: serializer.fromJson<String?>(json['detail']),
      latencyMs: serializer.fromJson<int?>(json['latencyMs']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'sessionId': serializer.toJson<String>(sessionId),
      'prayer': serializer.toJson<String>(prayer),
      'scheduledAt': serializer.toJson<int>(scheduledAt),
      'firedAt': serializer.toJson<int?>(firedAt),
      'presenceState': serializer.toJson<String?>(presenceState),
      'presenceSignal': serializer.toJson<String?>(presenceSignal),
      'role': serializer.toJson<String?>(role),
      'peerCount': serializer.toJson<int?>(peerCount),
      'targetId': serializer.toJson<String?>(targetId),
      'targetName': serializer.toJson<String?>(targetName),
      'outcome': serializer.toJson<String>(outcome),
      'detail': serializer.toJson<String?>(detail),
      'latencyMs': serializer.toJson<int?>(latencyMs),
    };
  }

  DeliveryLog copyWith({
    int? id,
    String? sessionId,
    String? prayer,
    int? scheduledAt,
    Value<int?> firedAt = const Value.absent(),
    Value<String?> presenceState = const Value.absent(),
    Value<String?> presenceSignal = const Value.absent(),
    Value<String?> role = const Value.absent(),
    Value<int?> peerCount = const Value.absent(),
    Value<String?> targetId = const Value.absent(),
    Value<String?> targetName = const Value.absent(),
    String? outcome,
    Value<String?> detail = const Value.absent(),
    Value<int?> latencyMs = const Value.absent(),
  }) => DeliveryLog(
    id: id ?? this.id,
    sessionId: sessionId ?? this.sessionId,
    prayer: prayer ?? this.prayer,
    scheduledAt: scheduledAt ?? this.scheduledAt,
    firedAt: firedAt.present ? firedAt.value : this.firedAt,
    presenceState: presenceState.present
        ? presenceState.value
        : this.presenceState,
    presenceSignal: presenceSignal.present
        ? presenceSignal.value
        : this.presenceSignal,
    role: role.present ? role.value : this.role,
    peerCount: peerCount.present ? peerCount.value : this.peerCount,
    targetId: targetId.present ? targetId.value : this.targetId,
    targetName: targetName.present ? targetName.value : this.targetName,
    outcome: outcome ?? this.outcome,
    detail: detail.present ? detail.value : this.detail,
    latencyMs: latencyMs.present ? latencyMs.value : this.latencyMs,
  );
  DeliveryLog copyWithCompanion(DeliveryLogsCompanion data) {
    return DeliveryLog(
      id: data.id.present ? data.id.value : this.id,
      sessionId: data.sessionId.present ? data.sessionId.value : this.sessionId,
      prayer: data.prayer.present ? data.prayer.value : this.prayer,
      scheduledAt: data.scheduledAt.present
          ? data.scheduledAt.value
          : this.scheduledAt,
      firedAt: data.firedAt.present ? data.firedAt.value : this.firedAt,
      presenceState: data.presenceState.present
          ? data.presenceState.value
          : this.presenceState,
      presenceSignal: data.presenceSignal.present
          ? data.presenceSignal.value
          : this.presenceSignal,
      role: data.role.present ? data.role.value : this.role,
      peerCount: data.peerCount.present ? data.peerCount.value : this.peerCount,
      targetId: data.targetId.present ? data.targetId.value : this.targetId,
      targetName: data.targetName.present
          ? data.targetName.value
          : this.targetName,
      outcome: data.outcome.present ? data.outcome.value : this.outcome,
      detail: data.detail.present ? data.detail.value : this.detail,
      latencyMs: data.latencyMs.present ? data.latencyMs.value : this.latencyMs,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DeliveryLog(')
          ..write('id: $id, ')
          ..write('sessionId: $sessionId, ')
          ..write('prayer: $prayer, ')
          ..write('scheduledAt: $scheduledAt, ')
          ..write('firedAt: $firedAt, ')
          ..write('presenceState: $presenceState, ')
          ..write('presenceSignal: $presenceSignal, ')
          ..write('role: $role, ')
          ..write('peerCount: $peerCount, ')
          ..write('targetId: $targetId, ')
          ..write('targetName: $targetName, ')
          ..write('outcome: $outcome, ')
          ..write('detail: $detail, ')
          ..write('latencyMs: $latencyMs')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    sessionId,
    prayer,
    scheduledAt,
    firedAt,
    presenceState,
    presenceSignal,
    role,
    peerCount,
    targetId,
    targetName,
    outcome,
    detail,
    latencyMs,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DeliveryLog &&
          other.id == this.id &&
          other.sessionId == this.sessionId &&
          other.prayer == this.prayer &&
          other.scheduledAt == this.scheduledAt &&
          other.firedAt == this.firedAt &&
          other.presenceState == this.presenceState &&
          other.presenceSignal == this.presenceSignal &&
          other.role == this.role &&
          other.peerCount == this.peerCount &&
          other.targetId == this.targetId &&
          other.targetName == this.targetName &&
          other.outcome == this.outcome &&
          other.detail == this.detail &&
          other.latencyMs == this.latencyMs);
}

class DeliveryLogsCompanion extends UpdateCompanion<DeliveryLog> {
  final Value<int> id;
  final Value<String> sessionId;
  final Value<String> prayer;
  final Value<int> scheduledAt;
  final Value<int?> firedAt;
  final Value<String?> presenceState;
  final Value<String?> presenceSignal;
  final Value<String?> role;
  final Value<int?> peerCount;
  final Value<String?> targetId;
  final Value<String?> targetName;
  final Value<String> outcome;
  final Value<String?> detail;
  final Value<int?> latencyMs;
  const DeliveryLogsCompanion({
    this.id = const Value.absent(),
    this.sessionId = const Value.absent(),
    this.prayer = const Value.absent(),
    this.scheduledAt = const Value.absent(),
    this.firedAt = const Value.absent(),
    this.presenceState = const Value.absent(),
    this.presenceSignal = const Value.absent(),
    this.role = const Value.absent(),
    this.peerCount = const Value.absent(),
    this.targetId = const Value.absent(),
    this.targetName = const Value.absent(),
    this.outcome = const Value.absent(),
    this.detail = const Value.absent(),
    this.latencyMs = const Value.absent(),
  });
  DeliveryLogsCompanion.insert({
    this.id = const Value.absent(),
    required String sessionId,
    required String prayer,
    required int scheduledAt,
    this.firedAt = const Value.absent(),
    this.presenceState = const Value.absent(),
    this.presenceSignal = const Value.absent(),
    this.role = const Value.absent(),
    this.peerCount = const Value.absent(),
    this.targetId = const Value.absent(),
    this.targetName = const Value.absent(),
    required String outcome,
    this.detail = const Value.absent(),
    this.latencyMs = const Value.absent(),
  }) : sessionId = Value(sessionId),
       prayer = Value(prayer),
       scheduledAt = Value(scheduledAt),
       outcome = Value(outcome);
  static Insertable<DeliveryLog> custom({
    Expression<int>? id,
    Expression<String>? sessionId,
    Expression<String>? prayer,
    Expression<int>? scheduledAt,
    Expression<int>? firedAt,
    Expression<String>? presenceState,
    Expression<String>? presenceSignal,
    Expression<String>? role,
    Expression<int>? peerCount,
    Expression<String>? targetId,
    Expression<String>? targetName,
    Expression<String>? outcome,
    Expression<String>? detail,
    Expression<int>? latencyMs,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (sessionId != null) 'session_id': sessionId,
      if (prayer != null) 'prayer': prayer,
      if (scheduledAt != null) 'scheduled_at': scheduledAt,
      if (firedAt != null) 'fired_at': firedAt,
      if (presenceState != null) 'presence_state': presenceState,
      if (presenceSignal != null) 'presence_signal': presenceSignal,
      if (role != null) 'role': role,
      if (peerCount != null) 'peer_count': peerCount,
      if (targetId != null) 'target_id': targetId,
      if (targetName != null) 'target_name': targetName,
      if (outcome != null) 'outcome': outcome,
      if (detail != null) 'detail': detail,
      if (latencyMs != null) 'latency_ms': latencyMs,
    });
  }

  DeliveryLogsCompanion copyWith({
    Value<int>? id,
    Value<String>? sessionId,
    Value<String>? prayer,
    Value<int>? scheduledAt,
    Value<int?>? firedAt,
    Value<String?>? presenceState,
    Value<String?>? presenceSignal,
    Value<String?>? role,
    Value<int?>? peerCount,
    Value<String?>? targetId,
    Value<String?>? targetName,
    Value<String>? outcome,
    Value<String?>? detail,
    Value<int?>? latencyMs,
  }) {
    return DeliveryLogsCompanion(
      id: id ?? this.id,
      sessionId: sessionId ?? this.sessionId,
      prayer: prayer ?? this.prayer,
      scheduledAt: scheduledAt ?? this.scheduledAt,
      firedAt: firedAt ?? this.firedAt,
      presenceState: presenceState ?? this.presenceState,
      presenceSignal: presenceSignal ?? this.presenceSignal,
      role: role ?? this.role,
      peerCount: peerCount ?? this.peerCount,
      targetId: targetId ?? this.targetId,
      targetName: targetName ?? this.targetName,
      outcome: outcome ?? this.outcome,
      detail: detail ?? this.detail,
      latencyMs: latencyMs ?? this.latencyMs,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (sessionId.present) {
      map['session_id'] = Variable<String>(sessionId.value);
    }
    if (prayer.present) {
      map['prayer'] = Variable<String>(prayer.value);
    }
    if (scheduledAt.present) {
      map['scheduled_at'] = Variable<int>(scheduledAt.value);
    }
    if (firedAt.present) {
      map['fired_at'] = Variable<int>(firedAt.value);
    }
    if (presenceState.present) {
      map['presence_state'] = Variable<String>(presenceState.value);
    }
    if (presenceSignal.present) {
      map['presence_signal'] = Variable<String>(presenceSignal.value);
    }
    if (role.present) {
      map['role'] = Variable<String>(role.value);
    }
    if (peerCount.present) {
      map['peer_count'] = Variable<int>(peerCount.value);
    }
    if (targetId.present) {
      map['target_id'] = Variable<String>(targetId.value);
    }
    if (targetName.present) {
      map['target_name'] = Variable<String>(targetName.value);
    }
    if (outcome.present) {
      map['outcome'] = Variable<String>(outcome.value);
    }
    if (detail.present) {
      map['detail'] = Variable<String>(detail.value);
    }
    if (latencyMs.present) {
      map['latency_ms'] = Variable<int>(latencyMs.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DeliveryLogsCompanion(')
          ..write('id: $id, ')
          ..write('sessionId: $sessionId, ')
          ..write('prayer: $prayer, ')
          ..write('scheduledAt: $scheduledAt, ')
          ..write('firedAt: $firedAt, ')
          ..write('presenceState: $presenceState, ')
          ..write('presenceSignal: $presenceSignal, ')
          ..write('role: $role, ')
          ..write('peerCount: $peerCount, ')
          ..write('targetId: $targetId, ')
          ..write('targetName: $targetName, ')
          ..write('outcome: $outcome, ')
          ..write('detail: $detail, ')
          ..write('latencyMs: $latencyMs')
          ..write(')'))
        .toString();
  }
}

abstract class _$DeliveryDatabase extends GeneratedDatabase {
  _$DeliveryDatabase(QueryExecutor e) : super(e);
  $DeliveryDatabaseManager get managers => $DeliveryDatabaseManager(this);
  late final $DeliveryLogsTable deliveryLogs = $DeliveryLogsTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [deliveryLogs];
}

typedef $$DeliveryLogsTableCreateCompanionBuilder =
    DeliveryLogsCompanion Function({
      Value<int> id,
      required String sessionId,
      required String prayer,
      required int scheduledAt,
      Value<int?> firedAt,
      Value<String?> presenceState,
      Value<String?> presenceSignal,
      Value<String?> role,
      Value<int?> peerCount,
      Value<String?> targetId,
      Value<String?> targetName,
      required String outcome,
      Value<String?> detail,
      Value<int?> latencyMs,
    });
typedef $$DeliveryLogsTableUpdateCompanionBuilder =
    DeliveryLogsCompanion Function({
      Value<int> id,
      Value<String> sessionId,
      Value<String> prayer,
      Value<int> scheduledAt,
      Value<int?> firedAt,
      Value<String?> presenceState,
      Value<String?> presenceSignal,
      Value<String?> role,
      Value<int?> peerCount,
      Value<String?> targetId,
      Value<String?> targetName,
      Value<String> outcome,
      Value<String?> detail,
      Value<int?> latencyMs,
    });

class $$DeliveryLogsTableFilterComposer
    extends Composer<_$DeliveryDatabase, $DeliveryLogsTable> {
  $$DeliveryLogsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sessionId => $composableBuilder(
    column: $table.sessionId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get prayer => $composableBuilder(
    column: $table.prayer,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get scheduledAt => $composableBuilder(
    column: $table.scheduledAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get firedAt => $composableBuilder(
    column: $table.firedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get presenceState => $composableBuilder(
    column: $table.presenceState,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get presenceSignal => $composableBuilder(
    column: $table.presenceSignal,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get role => $composableBuilder(
    column: $table.role,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get peerCount => $composableBuilder(
    column: $table.peerCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get targetId => $composableBuilder(
    column: $table.targetId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get targetName => $composableBuilder(
    column: $table.targetName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get outcome => $composableBuilder(
    column: $table.outcome,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get detail => $composableBuilder(
    column: $table.detail,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get latencyMs => $composableBuilder(
    column: $table.latencyMs,
    builder: (column) => ColumnFilters(column),
  );
}

class $$DeliveryLogsTableOrderingComposer
    extends Composer<_$DeliveryDatabase, $DeliveryLogsTable> {
  $$DeliveryLogsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sessionId => $composableBuilder(
    column: $table.sessionId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get prayer => $composableBuilder(
    column: $table.prayer,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get scheduledAt => $composableBuilder(
    column: $table.scheduledAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get firedAt => $composableBuilder(
    column: $table.firedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get presenceState => $composableBuilder(
    column: $table.presenceState,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get presenceSignal => $composableBuilder(
    column: $table.presenceSignal,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get role => $composableBuilder(
    column: $table.role,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get peerCount => $composableBuilder(
    column: $table.peerCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get targetId => $composableBuilder(
    column: $table.targetId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get targetName => $composableBuilder(
    column: $table.targetName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get outcome => $composableBuilder(
    column: $table.outcome,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get detail => $composableBuilder(
    column: $table.detail,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get latencyMs => $composableBuilder(
    column: $table.latencyMs,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$DeliveryLogsTableAnnotationComposer
    extends Composer<_$DeliveryDatabase, $DeliveryLogsTable> {
  $$DeliveryLogsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get sessionId =>
      $composableBuilder(column: $table.sessionId, builder: (column) => column);

  GeneratedColumn<String> get prayer =>
      $composableBuilder(column: $table.prayer, builder: (column) => column);

  GeneratedColumn<int> get scheduledAt => $composableBuilder(
    column: $table.scheduledAt,
    builder: (column) => column,
  );

  GeneratedColumn<int> get firedAt =>
      $composableBuilder(column: $table.firedAt, builder: (column) => column);

  GeneratedColumn<String> get presenceState => $composableBuilder(
    column: $table.presenceState,
    builder: (column) => column,
  );

  GeneratedColumn<String> get presenceSignal => $composableBuilder(
    column: $table.presenceSignal,
    builder: (column) => column,
  );

  GeneratedColumn<String> get role =>
      $composableBuilder(column: $table.role, builder: (column) => column);

  GeneratedColumn<int> get peerCount =>
      $composableBuilder(column: $table.peerCount, builder: (column) => column);

  GeneratedColumn<String> get targetId =>
      $composableBuilder(column: $table.targetId, builder: (column) => column);

  GeneratedColumn<String> get targetName => $composableBuilder(
    column: $table.targetName,
    builder: (column) => column,
  );

  GeneratedColumn<String> get outcome =>
      $composableBuilder(column: $table.outcome, builder: (column) => column);

  GeneratedColumn<String> get detail =>
      $composableBuilder(column: $table.detail, builder: (column) => column);

  GeneratedColumn<int> get latencyMs =>
      $composableBuilder(column: $table.latencyMs, builder: (column) => column);
}

class $$DeliveryLogsTableTableManager
    extends
        RootTableManager<
          _$DeliveryDatabase,
          $DeliveryLogsTable,
          DeliveryLog,
          $$DeliveryLogsTableFilterComposer,
          $$DeliveryLogsTableOrderingComposer,
          $$DeliveryLogsTableAnnotationComposer,
          $$DeliveryLogsTableCreateCompanionBuilder,
          $$DeliveryLogsTableUpdateCompanionBuilder,
          (
            DeliveryLog,
            BaseReferences<_$DeliveryDatabase, $DeliveryLogsTable, DeliveryLog>,
          ),
          DeliveryLog,
          PrefetchHooks Function()
        > {
  $$DeliveryLogsTableTableManager(
    _$DeliveryDatabase db,
    $DeliveryLogsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$DeliveryLogsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$DeliveryLogsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$DeliveryLogsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> sessionId = const Value.absent(),
                Value<String> prayer = const Value.absent(),
                Value<int> scheduledAt = const Value.absent(),
                Value<int?> firedAt = const Value.absent(),
                Value<String?> presenceState = const Value.absent(),
                Value<String?> presenceSignal = const Value.absent(),
                Value<String?> role = const Value.absent(),
                Value<int?> peerCount = const Value.absent(),
                Value<String?> targetId = const Value.absent(),
                Value<String?> targetName = const Value.absent(),
                Value<String> outcome = const Value.absent(),
                Value<String?> detail = const Value.absent(),
                Value<int?> latencyMs = const Value.absent(),
              }) => DeliveryLogsCompanion(
                id: id,
                sessionId: sessionId,
                prayer: prayer,
                scheduledAt: scheduledAt,
                firedAt: firedAt,
                presenceState: presenceState,
                presenceSignal: presenceSignal,
                role: role,
                peerCount: peerCount,
                targetId: targetId,
                targetName: targetName,
                outcome: outcome,
                detail: detail,
                latencyMs: latencyMs,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String sessionId,
                required String prayer,
                required int scheduledAt,
                Value<int?> firedAt = const Value.absent(),
                Value<String?> presenceState = const Value.absent(),
                Value<String?> presenceSignal = const Value.absent(),
                Value<String?> role = const Value.absent(),
                Value<int?> peerCount = const Value.absent(),
                Value<String?> targetId = const Value.absent(),
                Value<String?> targetName = const Value.absent(),
                required String outcome,
                Value<String?> detail = const Value.absent(),
                Value<int?> latencyMs = const Value.absent(),
              }) => DeliveryLogsCompanion.insert(
                id: id,
                sessionId: sessionId,
                prayer: prayer,
                scheduledAt: scheduledAt,
                firedAt: firedAt,
                presenceState: presenceState,
                presenceSignal: presenceSignal,
                role: role,
                peerCount: peerCount,
                targetId: targetId,
                targetName: targetName,
                outcome: outcome,
                detail: detail,
                latencyMs: latencyMs,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$DeliveryLogsTableProcessedTableManager =
    ProcessedTableManager<
      _$DeliveryDatabase,
      $DeliveryLogsTable,
      DeliveryLog,
      $$DeliveryLogsTableFilterComposer,
      $$DeliveryLogsTableOrderingComposer,
      $$DeliveryLogsTableAnnotationComposer,
      $$DeliveryLogsTableCreateCompanionBuilder,
      $$DeliveryLogsTableUpdateCompanionBuilder,
      (
        DeliveryLog,
        BaseReferences<_$DeliveryDatabase, $DeliveryLogsTable, DeliveryLog>,
      ),
      DeliveryLog,
      PrefetchHooks Function()
    >;

class $DeliveryDatabaseManager {
  final _$DeliveryDatabase _db;
  $DeliveryDatabaseManager(this._db);
  $$DeliveryLogsTableTableManager get deliveryLogs =>
      $$DeliveryLogsTableTableManager(_db, _db.deliveryLogs);
}

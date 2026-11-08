// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'planner_db.dart';

// ignore_for_file: type=lint
class $BoardsTable extends Boards with TableInfo<$BoardsTable, BoardRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $BoardsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [id, name];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'boards';
  @override
  VerificationContext validateIntegrity(
    Insertable<BoardRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  BoardRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return BoardRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
    );
  }

  @override
  $BoardsTable createAlias(String alias) {
    return $BoardsTable(attachedDatabase, alias);
  }
}

class BoardRow extends DataClass implements Insertable<BoardRow> {
  final String id;
  final String name;
  const BoardRow({required this.id, required this.name});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    return map;
  }

  BoardsCompanion toCompanion(bool nullToAbsent) {
    return BoardsCompanion(id: Value(id), name: Value(name));
  }

  factory BoardRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return BoardRow(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
    };
  }

  BoardRow copyWith({String? id, String? name}) =>
      BoardRow(id: id ?? this.id, name: name ?? this.name);
  BoardRow copyWithCompanion(BoardsCompanion data) {
    return BoardRow(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
    );
  }

  @override
  String toString() {
    return (StringBuffer('BoardRow(')
          ..write('id: $id, ')
          ..write('name: $name')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, name);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is BoardRow && other.id == this.id && other.name == this.name);
}

class BoardsCompanion extends UpdateCompanion<BoardRow> {
  final Value<String> id;
  final Value<String> name;
  final Value<int> rowid;
  const BoardsCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  BoardsCompanion.insert({
    required String id,
    required String name,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       name = Value(name);
  static Insertable<BoardRow> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (rowid != null) 'rowid': rowid,
    });
  }

  BoardsCompanion copyWith({
    Value<String>? id,
    Value<String>? name,
    Value<int>? rowid,
  }) {
    return BoardsCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('BoardsCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $TimersTable extends Timers with TableInfo<$TimersTable, TimerRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TimersTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _boardIdMeta = const VerificationMeta(
    'boardId',
  );
  @override
  late final GeneratedColumn<String> boardId = GeneratedColumn<String>(
    'board_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _colorMeta = const VerificationMeta('color');
  @override
  late final GeneratedColumn<String> color = GeneratedColumn<String>(
    'color',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _folderIdMeta = const VerificationMeta(
    'folderId',
  );
  @override
  late final GeneratedColumn<String> folderId = GeneratedColumn<String>(
    'folder_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _sortIndexMeta = const VerificationMeta(
    'sortIndex',
  );
  @override
  late final GeneratedColumn<int> sortIndex = GeneratedColumn<int>(
    'sort_index',
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
  static const VerificationMeta _dayDateMeta = const VerificationMeta(
    'dayDate',
  );
  @override
  late final GeneratedColumn<int> dayDate = GeneratedColumn<int>(
    'day_date',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _originPlanIdMeta = const VerificationMeta(
    'originPlanId',
  );
  @override
  late final GeneratedColumn<String> originPlanId = GeneratedColumn<String>(
    'origin_plan_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    boardId,
    name,
    color,
    folderId,
    sortIndex,
    createdAt,
    updatedAt,
    dayDate,
    originPlanId,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'timers';
  @override
  VerificationContext validateIntegrity(
    Insertable<TimerRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('board_id')) {
      context.handle(
        _boardIdMeta,
        boardId.isAcceptableOrUnknown(data['board_id']!, _boardIdMeta),
      );
    } else if (isInserting) {
      context.missing(_boardIdMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('color')) {
      context.handle(
        _colorMeta,
        color.isAcceptableOrUnknown(data['color']!, _colorMeta),
      );
    } else if (isInserting) {
      context.missing(_colorMeta);
    }
    if (data.containsKey('folder_id')) {
      context.handle(
        _folderIdMeta,
        folderId.isAcceptableOrUnknown(data['folder_id']!, _folderIdMeta),
      );
    }
    if (data.containsKey('sort_index')) {
      context.handle(
        _sortIndexMeta,
        sortIndex.isAcceptableOrUnknown(data['sort_index']!, _sortIndexMeta),
      );
    } else if (isInserting) {
      context.missing(_sortIndexMeta);
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
    if (data.containsKey('day_date')) {
      context.handle(
        _dayDateMeta,
        dayDate.isAcceptableOrUnknown(data['day_date']!, _dayDateMeta),
      );
    }
    if (data.containsKey('origin_plan_id')) {
      context.handle(
        _originPlanIdMeta,
        originPlanId.isAcceptableOrUnknown(
          data['origin_plan_id']!,
          _originPlanIdMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  TimerRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return TimerRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      boardId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}board_id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      color: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}color'],
      )!,
      folderId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}folder_id'],
      ),
      sortIndex: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sort_index'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at'],
      )!,
      dayDate: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}day_date'],
      ),
      originPlanId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}origin_plan_id'],
      ),
    );
  }

  @override
  $TimersTable createAlias(String alias) {
    return $TimersTable(attachedDatabase, alias);
  }
}

class TimerRow extends DataClass implements Insertable<TimerRow> {
  final String id;
  final String boardId;
  final String name;
  final String color;
  final String? folderId;
  final int sortIndex;
  final int createdAt;
  final int updatedAt;
  final int? dayDate;
  final String? originPlanId;
  const TimerRow({
    required this.id,
    required this.boardId,
    required this.name,
    required this.color,
    this.folderId,
    required this.sortIndex,
    required this.createdAt,
    required this.updatedAt,
    this.dayDate,
    this.originPlanId,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['board_id'] = Variable<String>(boardId);
    map['name'] = Variable<String>(name);
    map['color'] = Variable<String>(color);
    if (!nullToAbsent || folderId != null) {
      map['folder_id'] = Variable<String>(folderId);
    }
    map['sort_index'] = Variable<int>(sortIndex);
    map['created_at'] = Variable<int>(createdAt);
    map['updated_at'] = Variable<int>(updatedAt);
    if (!nullToAbsent || dayDate != null) {
      map['day_date'] = Variable<int>(dayDate);
    }
    if (!nullToAbsent || originPlanId != null) {
      map['origin_plan_id'] = Variable<String>(originPlanId);
    }
    return map;
  }

  TimersCompanion toCompanion(bool nullToAbsent) {
    return TimersCompanion(
      id: Value(id),
      boardId: Value(boardId),
      name: Value(name),
      color: Value(color),
      folderId: folderId == null && nullToAbsent
          ? const Value.absent()
          : Value(folderId),
      sortIndex: Value(sortIndex),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      dayDate: dayDate == null && nullToAbsent
          ? const Value.absent()
          : Value(dayDate),
      originPlanId: originPlanId == null && nullToAbsent
          ? const Value.absent()
          : Value(originPlanId),
    );
  }

  factory TimerRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return TimerRow(
      id: serializer.fromJson<String>(json['id']),
      boardId: serializer.fromJson<String>(json['boardId']),
      name: serializer.fromJson<String>(json['name']),
      color: serializer.fromJson<String>(json['color']),
      folderId: serializer.fromJson<String?>(json['folderId']),
      sortIndex: serializer.fromJson<int>(json['sortIndex']),
      createdAt: serializer.fromJson<int>(json['createdAt']),
      updatedAt: serializer.fromJson<int>(json['updatedAt']),
      dayDate: serializer.fromJson<int?>(json['dayDate']),
      originPlanId: serializer.fromJson<String?>(json['originPlanId']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'boardId': serializer.toJson<String>(boardId),
      'name': serializer.toJson<String>(name),
      'color': serializer.toJson<String>(color),
      'folderId': serializer.toJson<String?>(folderId),
      'sortIndex': serializer.toJson<int>(sortIndex),
      'createdAt': serializer.toJson<int>(createdAt),
      'updatedAt': serializer.toJson<int>(updatedAt),
      'dayDate': serializer.toJson<int?>(dayDate),
      'originPlanId': serializer.toJson<String?>(originPlanId),
    };
  }

  TimerRow copyWith({
    String? id,
    String? boardId,
    String? name,
    String? color,
    Value<String?> folderId = const Value.absent(),
    int? sortIndex,
    int? createdAt,
    int? updatedAt,
    Value<int?> dayDate = const Value.absent(),
    Value<String?> originPlanId = const Value.absent(),
  }) => TimerRow(
    id: id ?? this.id,
    boardId: boardId ?? this.boardId,
    name: name ?? this.name,
    color: color ?? this.color,
    folderId: folderId.present ? folderId.value : this.folderId,
    sortIndex: sortIndex ?? this.sortIndex,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    dayDate: dayDate.present ? dayDate.value : this.dayDate,
    originPlanId: originPlanId.present ? originPlanId.value : this.originPlanId,
  );
  TimerRow copyWithCompanion(TimersCompanion data) {
    return TimerRow(
      id: data.id.present ? data.id.value : this.id,
      boardId: data.boardId.present ? data.boardId.value : this.boardId,
      name: data.name.present ? data.name.value : this.name,
      color: data.color.present ? data.color.value : this.color,
      folderId: data.folderId.present ? data.folderId.value : this.folderId,
      sortIndex: data.sortIndex.present ? data.sortIndex.value : this.sortIndex,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      dayDate: data.dayDate.present ? data.dayDate.value : this.dayDate,
      originPlanId: data.originPlanId.present
          ? data.originPlanId.value
          : this.originPlanId,
    );
  }

  @override
  String toString() {
    return (StringBuffer('TimerRow(')
          ..write('id: $id, ')
          ..write('boardId: $boardId, ')
          ..write('name: $name, ')
          ..write('color: $color, ')
          ..write('folderId: $folderId, ')
          ..write('sortIndex: $sortIndex, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('dayDate: $dayDate, ')
          ..write('originPlanId: $originPlanId')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    boardId,
    name,
    color,
    folderId,
    sortIndex,
    createdAt,
    updatedAt,
    dayDate,
    originPlanId,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TimerRow &&
          other.id == this.id &&
          other.boardId == this.boardId &&
          other.name == this.name &&
          other.color == this.color &&
          other.folderId == this.folderId &&
          other.sortIndex == this.sortIndex &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.dayDate == this.dayDate &&
          other.originPlanId == this.originPlanId);
}

class TimersCompanion extends UpdateCompanion<TimerRow> {
  final Value<String> id;
  final Value<String> boardId;
  final Value<String> name;
  final Value<String> color;
  final Value<String?> folderId;
  final Value<int> sortIndex;
  final Value<int> createdAt;
  final Value<int> updatedAt;
  final Value<int?> dayDate;
  final Value<String?> originPlanId;
  final Value<int> rowid;
  const TimersCompanion({
    this.id = const Value.absent(),
    this.boardId = const Value.absent(),
    this.name = const Value.absent(),
    this.color = const Value.absent(),
    this.folderId = const Value.absent(),
    this.sortIndex = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.dayDate = const Value.absent(),
    this.originPlanId = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  TimersCompanion.insert({
    required String id,
    required String boardId,
    required String name,
    required String color,
    this.folderId = const Value.absent(),
    required int sortIndex,
    required int createdAt,
    required int updatedAt,
    this.dayDate = const Value.absent(),
    this.originPlanId = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       boardId = Value(boardId),
       name = Value(name),
       color = Value(color),
       sortIndex = Value(sortIndex),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<TimerRow> custom({
    Expression<String>? id,
    Expression<String>? boardId,
    Expression<String>? name,
    Expression<String>? color,
    Expression<String>? folderId,
    Expression<int>? sortIndex,
    Expression<int>? createdAt,
    Expression<int>? updatedAt,
    Expression<int>? dayDate,
    Expression<String>? originPlanId,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (boardId != null) 'board_id': boardId,
      if (name != null) 'name': name,
      if (color != null) 'color': color,
      if (folderId != null) 'folder_id': folderId,
      if (sortIndex != null) 'sort_index': sortIndex,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (dayDate != null) 'day_date': dayDate,
      if (originPlanId != null) 'origin_plan_id': originPlanId,
      if (rowid != null) 'rowid': rowid,
    });
  }

  TimersCompanion copyWith({
    Value<String>? id,
    Value<String>? boardId,
    Value<String>? name,
    Value<String>? color,
    Value<String?>? folderId,
    Value<int>? sortIndex,
    Value<int>? createdAt,
    Value<int>? updatedAt,
    Value<int?>? dayDate,
    Value<String?>? originPlanId,
    Value<int>? rowid,
  }) {
    return TimersCompanion(
      id: id ?? this.id,
      boardId: boardId ?? this.boardId,
      name: name ?? this.name,
      color: color ?? this.color,
      folderId: folderId ?? this.folderId,
      sortIndex: sortIndex ?? this.sortIndex,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      dayDate: dayDate ?? this.dayDate,
      originPlanId: originPlanId ?? this.originPlanId,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (boardId.present) {
      map['board_id'] = Variable<String>(boardId.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (color.present) {
      map['color'] = Variable<String>(color.value);
    }
    if (folderId.present) {
      map['folder_id'] = Variable<String>(folderId.value);
    }
    if (sortIndex.present) {
      map['sort_index'] = Variable<int>(sortIndex.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(updatedAt.value);
    }
    if (dayDate.present) {
      map['day_date'] = Variable<int>(dayDate.value);
    }
    if (originPlanId.present) {
      map['origin_plan_id'] = Variable<String>(originPlanId.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TimersCompanion(')
          ..write('id: $id, ')
          ..write('boardId: $boardId, ')
          ..write('name: $name, ')
          ..write('color: $color, ')
          ..write('folderId: $folderId, ')
          ..write('sortIndex: $sortIndex, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('dayDate: $dayDate, ')
          ..write('originPlanId: $originPlanId, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $IntervalDefsTable extends IntervalDefs
    with TableInfo<$IntervalDefsTable, IntervalDefRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $IntervalDefsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _timerIdMeta = const VerificationMeta(
    'timerId',
  );
  @override
  late final GeneratedColumn<String> timerId = GeneratedColumn<String>(
    'timer_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _colorMeta = const VerificationMeta('color');
  @override
  late final GeneratedColumn<String> color = GeneratedColumn<String>(
    'color',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _durationSecondsMeta = const VerificationMeta(
    'durationSeconds',
  );
  @override
  late final GeneratedColumn<int> durationSeconds = GeneratedColumn<int>(
    'duration_seconds',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _autoFinishMeta = const VerificationMeta(
    'autoFinish',
  );
  @override
  late final GeneratedColumn<bool> autoFinish = GeneratedColumn<bool>(
    'auto_finish',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("auto_finish" IN (0, 1))',
    ),
  );
  static const VerificationMeta _endAlertSoundFileMeta = const VerificationMeta(
    'endAlertSoundFile',
  );
  @override
  late final GeneratedColumn<String> endAlertSoundFile =
      GeneratedColumn<String>(
        'end_alert_sound_file',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _parentGroupIdMeta = const VerificationMeta(
    'parentGroupId',
  );
  @override
  late final GeneratedColumn<String> parentGroupId = GeneratedColumn<String>(
    'parent_group_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _sortIndexMeta = const VerificationMeta(
    'sortIndex',
  );
  @override
  late final GeneratedColumn<int> sortIndex = GeneratedColumn<int>(
    'sort_index',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _completedMeta = const VerificationMeta(
    'completed',
  );
  @override
  late final GeneratedColumn<bool> completed = GeneratedColumn<bool>(
    'completed',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("completed" IN (0, 1))',
    ),
  );
  static const VerificationMeta _triggerTimeSecondsMeta =
      const VerificationMeta('triggerTimeSeconds');
  @override
  late final GeneratedColumn<int> triggerTimeSeconds = GeneratedColumn<int>(
    'trigger_time_seconds',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    timerId,
    name,
    color,
    durationSeconds,
    autoFinish,
    endAlertSoundFile,
    parentGroupId,
    sortIndex,
    completed,
    triggerTimeSeconds,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'interval_defs';
  @override
  VerificationContext validateIntegrity(
    Insertable<IntervalDefRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('timer_id')) {
      context.handle(
        _timerIdMeta,
        timerId.isAcceptableOrUnknown(data['timer_id']!, _timerIdMeta),
      );
    } else if (isInserting) {
      context.missing(_timerIdMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    }
    if (data.containsKey('color')) {
      context.handle(
        _colorMeta,
        color.isAcceptableOrUnknown(data['color']!, _colorMeta),
      );
    } else if (isInserting) {
      context.missing(_colorMeta);
    }
    if (data.containsKey('duration_seconds')) {
      context.handle(
        _durationSecondsMeta,
        durationSeconds.isAcceptableOrUnknown(
          data['duration_seconds']!,
          _durationSecondsMeta,
        ),
      );
    }
    if (data.containsKey('auto_finish')) {
      context.handle(
        _autoFinishMeta,
        autoFinish.isAcceptableOrUnknown(data['auto_finish']!, _autoFinishMeta),
      );
    } else if (isInserting) {
      context.missing(_autoFinishMeta);
    }
    if (data.containsKey('end_alert_sound_file')) {
      context.handle(
        _endAlertSoundFileMeta,
        endAlertSoundFile.isAcceptableOrUnknown(
          data['end_alert_sound_file']!,
          _endAlertSoundFileMeta,
        ),
      );
    }
    if (data.containsKey('parent_group_id')) {
      context.handle(
        _parentGroupIdMeta,
        parentGroupId.isAcceptableOrUnknown(
          data['parent_group_id']!,
          _parentGroupIdMeta,
        ),
      );
    }
    if (data.containsKey('sort_index')) {
      context.handle(
        _sortIndexMeta,
        sortIndex.isAcceptableOrUnknown(data['sort_index']!, _sortIndexMeta),
      );
    } else if (isInserting) {
      context.missing(_sortIndexMeta);
    }
    if (data.containsKey('completed')) {
      context.handle(
        _completedMeta,
        completed.isAcceptableOrUnknown(data['completed']!, _completedMeta),
      );
    } else if (isInserting) {
      context.missing(_completedMeta);
    }
    if (data.containsKey('trigger_time_seconds')) {
      context.handle(
        _triggerTimeSecondsMeta,
        triggerTimeSeconds.isAcceptableOrUnknown(
          data['trigger_time_seconds']!,
          _triggerTimeSecondsMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  IntervalDefRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return IntervalDefRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      timerId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}timer_id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      ),
      color: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}color'],
      )!,
      durationSeconds: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}duration_seconds'],
      ),
      autoFinish: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}auto_finish'],
      )!,
      endAlertSoundFile: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}end_alert_sound_file'],
      ),
      parentGroupId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}parent_group_id'],
      ),
      sortIndex: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sort_index'],
      )!,
      completed: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}completed'],
      )!,
      triggerTimeSeconds: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}trigger_time_seconds'],
      ),
    );
  }

  @override
  $IntervalDefsTable createAlias(String alias) {
    return $IntervalDefsTable(attachedDatabase, alias);
  }
}

class IntervalDefRow extends DataClass implements Insertable<IntervalDefRow> {
  final String id;
  final String timerId;
  final String? name;
  final String color;
  final int? durationSeconds;
  final bool autoFinish;
  final String? endAlertSoundFile;
  final String? parentGroupId;
  final int sortIndex;
  final bool completed;
  final int? triggerTimeSeconds;
  const IntervalDefRow({
    required this.id,
    required this.timerId,
    this.name,
    required this.color,
    this.durationSeconds,
    required this.autoFinish,
    this.endAlertSoundFile,
    this.parentGroupId,
    required this.sortIndex,
    required this.completed,
    this.triggerTimeSeconds,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['timer_id'] = Variable<String>(timerId);
    if (!nullToAbsent || name != null) {
      map['name'] = Variable<String>(name);
    }
    map['color'] = Variable<String>(color);
    if (!nullToAbsent || durationSeconds != null) {
      map['duration_seconds'] = Variable<int>(durationSeconds);
    }
    map['auto_finish'] = Variable<bool>(autoFinish);
    if (!nullToAbsent || endAlertSoundFile != null) {
      map['end_alert_sound_file'] = Variable<String>(endAlertSoundFile);
    }
    if (!nullToAbsent || parentGroupId != null) {
      map['parent_group_id'] = Variable<String>(parentGroupId);
    }
    map['sort_index'] = Variable<int>(sortIndex);
    map['completed'] = Variable<bool>(completed);
    if (!nullToAbsent || triggerTimeSeconds != null) {
      map['trigger_time_seconds'] = Variable<int>(triggerTimeSeconds);
    }
    return map;
  }

  IntervalDefsCompanion toCompanion(bool nullToAbsent) {
    return IntervalDefsCompanion(
      id: Value(id),
      timerId: Value(timerId),
      name: name == null && nullToAbsent ? const Value.absent() : Value(name),
      color: Value(color),
      durationSeconds: durationSeconds == null && nullToAbsent
          ? const Value.absent()
          : Value(durationSeconds),
      autoFinish: Value(autoFinish),
      endAlertSoundFile: endAlertSoundFile == null && nullToAbsent
          ? const Value.absent()
          : Value(endAlertSoundFile),
      parentGroupId: parentGroupId == null && nullToAbsent
          ? const Value.absent()
          : Value(parentGroupId),
      sortIndex: Value(sortIndex),
      completed: Value(completed),
      triggerTimeSeconds: triggerTimeSeconds == null && nullToAbsent
          ? const Value.absent()
          : Value(triggerTimeSeconds),
    );
  }

  factory IntervalDefRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return IntervalDefRow(
      id: serializer.fromJson<String>(json['id']),
      timerId: serializer.fromJson<String>(json['timerId']),
      name: serializer.fromJson<String?>(json['name']),
      color: serializer.fromJson<String>(json['color']),
      durationSeconds: serializer.fromJson<int?>(json['durationSeconds']),
      autoFinish: serializer.fromJson<bool>(json['autoFinish']),
      endAlertSoundFile: serializer.fromJson<String?>(
        json['endAlertSoundFile'],
      ),
      parentGroupId: serializer.fromJson<String?>(json['parentGroupId']),
      sortIndex: serializer.fromJson<int>(json['sortIndex']),
      completed: serializer.fromJson<bool>(json['completed']),
      triggerTimeSeconds: serializer.fromJson<int?>(json['triggerTimeSeconds']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'timerId': serializer.toJson<String>(timerId),
      'name': serializer.toJson<String?>(name),
      'color': serializer.toJson<String>(color),
      'durationSeconds': serializer.toJson<int?>(durationSeconds),
      'autoFinish': serializer.toJson<bool>(autoFinish),
      'endAlertSoundFile': serializer.toJson<String?>(endAlertSoundFile),
      'parentGroupId': serializer.toJson<String?>(parentGroupId),
      'sortIndex': serializer.toJson<int>(sortIndex),
      'completed': serializer.toJson<bool>(completed),
      'triggerTimeSeconds': serializer.toJson<int?>(triggerTimeSeconds),
    };
  }

  IntervalDefRow copyWith({
    String? id,
    String? timerId,
    Value<String?> name = const Value.absent(),
    String? color,
    Value<int?> durationSeconds = const Value.absent(),
    bool? autoFinish,
    Value<String?> endAlertSoundFile = const Value.absent(),
    Value<String?> parentGroupId = const Value.absent(),
    int? sortIndex,
    bool? completed,
    Value<int?> triggerTimeSeconds = const Value.absent(),
  }) => IntervalDefRow(
    id: id ?? this.id,
    timerId: timerId ?? this.timerId,
    name: name.present ? name.value : this.name,
    color: color ?? this.color,
    durationSeconds: durationSeconds.present
        ? durationSeconds.value
        : this.durationSeconds,
    autoFinish: autoFinish ?? this.autoFinish,
    endAlertSoundFile: endAlertSoundFile.present
        ? endAlertSoundFile.value
        : this.endAlertSoundFile,
    parentGroupId: parentGroupId.present
        ? parentGroupId.value
        : this.parentGroupId,
    sortIndex: sortIndex ?? this.sortIndex,
    completed: completed ?? this.completed,
    triggerTimeSeconds: triggerTimeSeconds.present
        ? triggerTimeSeconds.value
        : this.triggerTimeSeconds,
  );
  IntervalDefRow copyWithCompanion(IntervalDefsCompanion data) {
    return IntervalDefRow(
      id: data.id.present ? data.id.value : this.id,
      timerId: data.timerId.present ? data.timerId.value : this.timerId,
      name: data.name.present ? data.name.value : this.name,
      color: data.color.present ? data.color.value : this.color,
      durationSeconds: data.durationSeconds.present
          ? data.durationSeconds.value
          : this.durationSeconds,
      autoFinish: data.autoFinish.present
          ? data.autoFinish.value
          : this.autoFinish,
      endAlertSoundFile: data.endAlertSoundFile.present
          ? data.endAlertSoundFile.value
          : this.endAlertSoundFile,
      parentGroupId: data.parentGroupId.present
          ? data.parentGroupId.value
          : this.parentGroupId,
      sortIndex: data.sortIndex.present ? data.sortIndex.value : this.sortIndex,
      completed: data.completed.present ? data.completed.value : this.completed,
      triggerTimeSeconds: data.triggerTimeSeconds.present
          ? data.triggerTimeSeconds.value
          : this.triggerTimeSeconds,
    );
  }

  @override
  String toString() {
    return (StringBuffer('IntervalDefRow(')
          ..write('id: $id, ')
          ..write('timerId: $timerId, ')
          ..write('name: $name, ')
          ..write('color: $color, ')
          ..write('durationSeconds: $durationSeconds, ')
          ..write('autoFinish: $autoFinish, ')
          ..write('endAlertSoundFile: $endAlertSoundFile, ')
          ..write('parentGroupId: $parentGroupId, ')
          ..write('sortIndex: $sortIndex, ')
          ..write('completed: $completed, ')
          ..write('triggerTimeSeconds: $triggerTimeSeconds')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    timerId,
    name,
    color,
    durationSeconds,
    autoFinish,
    endAlertSoundFile,
    parentGroupId,
    sortIndex,
    completed,
    triggerTimeSeconds,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is IntervalDefRow &&
          other.id == this.id &&
          other.timerId == this.timerId &&
          other.name == this.name &&
          other.color == this.color &&
          other.durationSeconds == this.durationSeconds &&
          other.autoFinish == this.autoFinish &&
          other.endAlertSoundFile == this.endAlertSoundFile &&
          other.parentGroupId == this.parentGroupId &&
          other.sortIndex == this.sortIndex &&
          other.completed == this.completed &&
          other.triggerTimeSeconds == this.triggerTimeSeconds);
}

class IntervalDefsCompanion extends UpdateCompanion<IntervalDefRow> {
  final Value<String> id;
  final Value<String> timerId;
  final Value<String?> name;
  final Value<String> color;
  final Value<int?> durationSeconds;
  final Value<bool> autoFinish;
  final Value<String?> endAlertSoundFile;
  final Value<String?> parentGroupId;
  final Value<int> sortIndex;
  final Value<bool> completed;
  final Value<int?> triggerTimeSeconds;
  final Value<int> rowid;
  const IntervalDefsCompanion({
    this.id = const Value.absent(),
    this.timerId = const Value.absent(),
    this.name = const Value.absent(),
    this.color = const Value.absent(),
    this.durationSeconds = const Value.absent(),
    this.autoFinish = const Value.absent(),
    this.endAlertSoundFile = const Value.absent(),
    this.parentGroupId = const Value.absent(),
    this.sortIndex = const Value.absent(),
    this.completed = const Value.absent(),
    this.triggerTimeSeconds = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  IntervalDefsCompanion.insert({
    required String id,
    required String timerId,
    this.name = const Value.absent(),
    required String color,
    this.durationSeconds = const Value.absent(),
    required bool autoFinish,
    this.endAlertSoundFile = const Value.absent(),
    this.parentGroupId = const Value.absent(),
    required int sortIndex,
    required bool completed,
    this.triggerTimeSeconds = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       timerId = Value(timerId),
       color = Value(color),
       autoFinish = Value(autoFinish),
       sortIndex = Value(sortIndex),
       completed = Value(completed);
  static Insertable<IntervalDefRow> custom({
    Expression<String>? id,
    Expression<String>? timerId,
    Expression<String>? name,
    Expression<String>? color,
    Expression<int>? durationSeconds,
    Expression<bool>? autoFinish,
    Expression<String>? endAlertSoundFile,
    Expression<String>? parentGroupId,
    Expression<int>? sortIndex,
    Expression<bool>? completed,
    Expression<int>? triggerTimeSeconds,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (timerId != null) 'timer_id': timerId,
      if (name != null) 'name': name,
      if (color != null) 'color': color,
      if (durationSeconds != null) 'duration_seconds': durationSeconds,
      if (autoFinish != null) 'auto_finish': autoFinish,
      if (endAlertSoundFile != null) 'end_alert_sound_file': endAlertSoundFile,
      if (parentGroupId != null) 'parent_group_id': parentGroupId,
      if (sortIndex != null) 'sort_index': sortIndex,
      if (completed != null) 'completed': completed,
      if (triggerTimeSeconds != null)
        'trigger_time_seconds': triggerTimeSeconds,
      if (rowid != null) 'rowid': rowid,
    });
  }

  IntervalDefsCompanion copyWith({
    Value<String>? id,
    Value<String>? timerId,
    Value<String?>? name,
    Value<String>? color,
    Value<int?>? durationSeconds,
    Value<bool>? autoFinish,
    Value<String?>? endAlertSoundFile,
    Value<String?>? parentGroupId,
    Value<int>? sortIndex,
    Value<bool>? completed,
    Value<int?>? triggerTimeSeconds,
    Value<int>? rowid,
  }) {
    return IntervalDefsCompanion(
      id: id ?? this.id,
      timerId: timerId ?? this.timerId,
      name: name ?? this.name,
      color: color ?? this.color,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      autoFinish: autoFinish ?? this.autoFinish,
      endAlertSoundFile: endAlertSoundFile ?? this.endAlertSoundFile,
      parentGroupId: parentGroupId ?? this.parentGroupId,
      sortIndex: sortIndex ?? this.sortIndex,
      completed: completed ?? this.completed,
      triggerTimeSeconds: triggerTimeSeconds ?? this.triggerTimeSeconds,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (timerId.present) {
      map['timer_id'] = Variable<String>(timerId.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (color.present) {
      map['color'] = Variable<String>(color.value);
    }
    if (durationSeconds.present) {
      map['duration_seconds'] = Variable<int>(durationSeconds.value);
    }
    if (autoFinish.present) {
      map['auto_finish'] = Variable<bool>(autoFinish.value);
    }
    if (endAlertSoundFile.present) {
      map['end_alert_sound_file'] = Variable<String>(endAlertSoundFile.value);
    }
    if (parentGroupId.present) {
      map['parent_group_id'] = Variable<String>(parentGroupId.value);
    }
    if (sortIndex.present) {
      map['sort_index'] = Variable<int>(sortIndex.value);
    }
    if (completed.present) {
      map['completed'] = Variable<bool>(completed.value);
    }
    if (triggerTimeSeconds.present) {
      map['trigger_time_seconds'] = Variable<int>(triggerTimeSeconds.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('IntervalDefsCompanion(')
          ..write('id: $id, ')
          ..write('timerId: $timerId, ')
          ..write('name: $name, ')
          ..write('color: $color, ')
          ..write('durationSeconds: $durationSeconds, ')
          ..write('autoFinish: $autoFinish, ')
          ..write('endAlertSoundFile: $endAlertSoundFile, ')
          ..write('parentGroupId: $parentGroupId, ')
          ..write('sortIndex: $sortIndex, ')
          ..write('completed: $completed, ')
          ..write('triggerTimeSeconds: $triggerTimeSeconds, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $GroupDefsTable extends GroupDefs
    with TableInfo<$GroupDefsTable, GroupDefRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $GroupDefsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _timerIdMeta = const VerificationMeta(
    'timerId',
  );
  @override
  late final GeneratedColumn<String> timerId = GeneratedColumn<String>(
    'timer_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _repeatCountMeta = const VerificationMeta(
    'repeatCount',
  );
  @override
  late final GeneratedColumn<int> repeatCount = GeneratedColumn<int>(
    'repeat_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _parentGroupIdMeta = const VerificationMeta(
    'parentGroupId',
  );
  @override
  late final GeneratedColumn<String> parentGroupId = GeneratedColumn<String>(
    'parent_group_id',
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
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    timerId,
    repeatCount,
    parentGroupId,
    orderIndex,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'group_defs';
  @override
  VerificationContext validateIntegrity(
    Insertable<GroupDefRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('timer_id')) {
      context.handle(
        _timerIdMeta,
        timerId.isAcceptableOrUnknown(data['timer_id']!, _timerIdMeta),
      );
    } else if (isInserting) {
      context.missing(_timerIdMeta);
    }
    if (data.containsKey('repeat_count')) {
      context.handle(
        _repeatCountMeta,
        repeatCount.isAcceptableOrUnknown(
          data['repeat_count']!,
          _repeatCountMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_repeatCountMeta);
    }
    if (data.containsKey('parent_group_id')) {
      context.handle(
        _parentGroupIdMeta,
        parentGroupId.isAcceptableOrUnknown(
          data['parent_group_id']!,
          _parentGroupIdMeta,
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
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  GroupDefRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return GroupDefRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      timerId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}timer_id'],
      )!,
      repeatCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}repeat_count'],
      )!,
      parentGroupId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}parent_group_id'],
      ),
      orderIndex: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}order_index'],
      )!,
    );
  }

  @override
  $GroupDefsTable createAlias(String alias) {
    return $GroupDefsTable(attachedDatabase, alias);
  }
}

class GroupDefRow extends DataClass implements Insertable<GroupDefRow> {
  final String id;
  final String timerId;
  final int repeatCount;
  final String? parentGroupId;
  final int orderIndex;
  const GroupDefRow({
    required this.id,
    required this.timerId,
    required this.repeatCount,
    this.parentGroupId,
    required this.orderIndex,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['timer_id'] = Variable<String>(timerId);
    map['repeat_count'] = Variable<int>(repeatCount);
    if (!nullToAbsent || parentGroupId != null) {
      map['parent_group_id'] = Variable<String>(parentGroupId);
    }
    map['order_index'] = Variable<int>(orderIndex);
    return map;
  }

  GroupDefsCompanion toCompanion(bool nullToAbsent) {
    return GroupDefsCompanion(
      id: Value(id),
      timerId: Value(timerId),
      repeatCount: Value(repeatCount),
      parentGroupId: parentGroupId == null && nullToAbsent
          ? const Value.absent()
          : Value(parentGroupId),
      orderIndex: Value(orderIndex),
    );
  }

  factory GroupDefRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return GroupDefRow(
      id: serializer.fromJson<String>(json['id']),
      timerId: serializer.fromJson<String>(json['timerId']),
      repeatCount: serializer.fromJson<int>(json['repeatCount']),
      parentGroupId: serializer.fromJson<String?>(json['parentGroupId']),
      orderIndex: serializer.fromJson<int>(json['orderIndex']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'timerId': serializer.toJson<String>(timerId),
      'repeatCount': serializer.toJson<int>(repeatCount),
      'parentGroupId': serializer.toJson<String?>(parentGroupId),
      'orderIndex': serializer.toJson<int>(orderIndex),
    };
  }

  GroupDefRow copyWith({
    String? id,
    String? timerId,
    int? repeatCount,
    Value<String?> parentGroupId = const Value.absent(),
    int? orderIndex,
  }) => GroupDefRow(
    id: id ?? this.id,
    timerId: timerId ?? this.timerId,
    repeatCount: repeatCount ?? this.repeatCount,
    parentGroupId: parentGroupId.present
        ? parentGroupId.value
        : this.parentGroupId,
    orderIndex: orderIndex ?? this.orderIndex,
  );
  GroupDefRow copyWithCompanion(GroupDefsCompanion data) {
    return GroupDefRow(
      id: data.id.present ? data.id.value : this.id,
      timerId: data.timerId.present ? data.timerId.value : this.timerId,
      repeatCount: data.repeatCount.present
          ? data.repeatCount.value
          : this.repeatCount,
      parentGroupId: data.parentGroupId.present
          ? data.parentGroupId.value
          : this.parentGroupId,
      orderIndex: data.orderIndex.present
          ? data.orderIndex.value
          : this.orderIndex,
    );
  }

  @override
  String toString() {
    return (StringBuffer('GroupDefRow(')
          ..write('id: $id, ')
          ..write('timerId: $timerId, ')
          ..write('repeatCount: $repeatCount, ')
          ..write('parentGroupId: $parentGroupId, ')
          ..write('orderIndex: $orderIndex')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, timerId, repeatCount, parentGroupId, orderIndex);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is GroupDefRow &&
          other.id == this.id &&
          other.timerId == this.timerId &&
          other.repeatCount == this.repeatCount &&
          other.parentGroupId == this.parentGroupId &&
          other.orderIndex == this.orderIndex);
}

class GroupDefsCompanion extends UpdateCompanion<GroupDefRow> {
  final Value<String> id;
  final Value<String> timerId;
  final Value<int> repeatCount;
  final Value<String?> parentGroupId;
  final Value<int> orderIndex;
  final Value<int> rowid;
  const GroupDefsCompanion({
    this.id = const Value.absent(),
    this.timerId = const Value.absent(),
    this.repeatCount = const Value.absent(),
    this.parentGroupId = const Value.absent(),
    this.orderIndex = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  GroupDefsCompanion.insert({
    required String id,
    required String timerId,
    required int repeatCount,
    this.parentGroupId = const Value.absent(),
    required int orderIndex,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       timerId = Value(timerId),
       repeatCount = Value(repeatCount),
       orderIndex = Value(orderIndex);
  static Insertable<GroupDefRow> custom({
    Expression<String>? id,
    Expression<String>? timerId,
    Expression<int>? repeatCount,
    Expression<String>? parentGroupId,
    Expression<int>? orderIndex,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (timerId != null) 'timer_id': timerId,
      if (repeatCount != null) 'repeat_count': repeatCount,
      if (parentGroupId != null) 'parent_group_id': parentGroupId,
      if (orderIndex != null) 'order_index': orderIndex,
      if (rowid != null) 'rowid': rowid,
    });
  }

  GroupDefsCompanion copyWith({
    Value<String>? id,
    Value<String>? timerId,
    Value<int>? repeatCount,
    Value<String?>? parentGroupId,
    Value<int>? orderIndex,
    Value<int>? rowid,
  }) {
    return GroupDefsCompanion(
      id: id ?? this.id,
      timerId: timerId ?? this.timerId,
      repeatCount: repeatCount ?? this.repeatCount,
      parentGroupId: parentGroupId ?? this.parentGroupId,
      orderIndex: orderIndex ?? this.orderIndex,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (timerId.present) {
      map['timer_id'] = Variable<String>(timerId.value);
    }
    if (repeatCount.present) {
      map['repeat_count'] = Variable<int>(repeatCount.value);
    }
    if (parentGroupId.present) {
      map['parent_group_id'] = Variable<String>(parentGroupId.value);
    }
    if (orderIndex.present) {
      map['order_index'] = Variable<int>(orderIndex.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('GroupDefsCompanion(')
          ..write('id: $id, ')
          ..write('timerId: $timerId, ')
          ..write('repeatCount: $repeatCount, ')
          ..write('parentGroupId: $parentGroupId, ')
          ..write('orderIndex: $orderIndex, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $EventLogTable extends EventLog
    with TableInfo<$EventLogTable, EventLogRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $EventLogTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _seqMeta = const VerificationMeta('seq');
  @override
  late final GeneratedColumn<int> seq = GeneratedColumn<int>(
    'seq',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'),
  );
  static const VerificationMeta _timestampMsMeta = const VerificationMeta(
    'timestampMs',
  );
  @override
  late final GeneratedColumn<int> timestampMs = GeneratedColumn<int>(
    'timestamp_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
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
  static const VerificationMeta _payloadJsonMeta = const VerificationMeta(
    'payloadJson',
  );
  @override
  late final GeneratedColumn<String> payloadJson = GeneratedColumn<String>(
    'payload_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    seq,
    timestampMs,
    kind,
    payloadJson,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'event_log';
  @override
  VerificationContext validateIntegrity(
    Insertable<EventLogRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('seq')) {
      context.handle(
        _seqMeta,
        seq.isAcceptableOrUnknown(data['seq']!, _seqMeta),
      );
    } else if (isInserting) {
      context.missing(_seqMeta);
    }
    if (data.containsKey('timestamp_ms')) {
      context.handle(
        _timestampMsMeta,
        timestampMs.isAcceptableOrUnknown(
          data['timestamp_ms']!,
          _timestampMsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_timestampMsMeta);
    }
    if (data.containsKey('kind')) {
      context.handle(
        _kindMeta,
        kind.isAcceptableOrUnknown(data['kind']!, _kindMeta),
      );
    } else if (isInserting) {
      context.missing(_kindMeta);
    }
    if (data.containsKey('payload_json')) {
      context.handle(
        _payloadJsonMeta,
        payloadJson.isAcceptableOrUnknown(
          data['payload_json']!,
          _payloadJsonMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_payloadJsonMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  EventLogRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return EventLogRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      seq: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}seq'],
      )!,
      timestampMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}timestamp_ms'],
      )!,
      kind: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}kind'],
      )!,
      payloadJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}payload_json'],
      )!,
    );
  }

  @override
  $EventLogTable createAlias(String alias) {
    return $EventLogTable(attachedDatabase, alias);
  }
}

class EventLogRow extends DataClass implements Insertable<EventLogRow> {
  final String id;
  final int seq;
  final int timestampMs;
  final String kind;
  final String payloadJson;
  const EventLogRow({
    required this.id,
    required this.seq,
    required this.timestampMs,
    required this.kind,
    required this.payloadJson,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['seq'] = Variable<int>(seq);
    map['timestamp_ms'] = Variable<int>(timestampMs);
    map['kind'] = Variable<String>(kind);
    map['payload_json'] = Variable<String>(payloadJson);
    return map;
  }

  EventLogCompanion toCompanion(bool nullToAbsent) {
    return EventLogCompanion(
      id: Value(id),
      seq: Value(seq),
      timestampMs: Value(timestampMs),
      kind: Value(kind),
      payloadJson: Value(payloadJson),
    );
  }

  factory EventLogRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return EventLogRow(
      id: serializer.fromJson<String>(json['id']),
      seq: serializer.fromJson<int>(json['seq']),
      timestampMs: serializer.fromJson<int>(json['timestampMs']),
      kind: serializer.fromJson<String>(json['kind']),
      payloadJson: serializer.fromJson<String>(json['payloadJson']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'seq': serializer.toJson<int>(seq),
      'timestampMs': serializer.toJson<int>(timestampMs),
      'kind': serializer.toJson<String>(kind),
      'payloadJson': serializer.toJson<String>(payloadJson),
    };
  }

  EventLogRow copyWith({
    String? id,
    int? seq,
    int? timestampMs,
    String? kind,
    String? payloadJson,
  }) => EventLogRow(
    id: id ?? this.id,
    seq: seq ?? this.seq,
    timestampMs: timestampMs ?? this.timestampMs,
    kind: kind ?? this.kind,
    payloadJson: payloadJson ?? this.payloadJson,
  );
  EventLogRow copyWithCompanion(EventLogCompanion data) {
    return EventLogRow(
      id: data.id.present ? data.id.value : this.id,
      seq: data.seq.present ? data.seq.value : this.seq,
      timestampMs: data.timestampMs.present
          ? data.timestampMs.value
          : this.timestampMs,
      kind: data.kind.present ? data.kind.value : this.kind,
      payloadJson: data.payloadJson.present
          ? data.payloadJson.value
          : this.payloadJson,
    );
  }

  @override
  String toString() {
    return (StringBuffer('EventLogRow(')
          ..write('id: $id, ')
          ..write('seq: $seq, ')
          ..write('timestampMs: $timestampMs, ')
          ..write('kind: $kind, ')
          ..write('payloadJson: $payloadJson')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, seq, timestampMs, kind, payloadJson);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is EventLogRow &&
          other.id == this.id &&
          other.seq == this.seq &&
          other.timestampMs == this.timestampMs &&
          other.kind == this.kind &&
          other.payloadJson == this.payloadJson);
}

class EventLogCompanion extends UpdateCompanion<EventLogRow> {
  final Value<String> id;
  final Value<int> seq;
  final Value<int> timestampMs;
  final Value<String> kind;
  final Value<String> payloadJson;
  final Value<int> rowid;
  const EventLogCompanion({
    this.id = const Value.absent(),
    this.seq = const Value.absent(),
    this.timestampMs = const Value.absent(),
    this.kind = const Value.absent(),
    this.payloadJson = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  EventLogCompanion.insert({
    required String id,
    required int seq,
    required int timestampMs,
    required String kind,
    required String payloadJson,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       seq = Value(seq),
       timestampMs = Value(timestampMs),
       kind = Value(kind),
       payloadJson = Value(payloadJson);
  static Insertable<EventLogRow> custom({
    Expression<String>? id,
    Expression<int>? seq,
    Expression<int>? timestampMs,
    Expression<String>? kind,
    Expression<String>? payloadJson,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (seq != null) 'seq': seq,
      if (timestampMs != null) 'timestamp_ms': timestampMs,
      if (kind != null) 'kind': kind,
      if (payloadJson != null) 'payload_json': payloadJson,
      if (rowid != null) 'rowid': rowid,
    });
  }

  EventLogCompanion copyWith({
    Value<String>? id,
    Value<int>? seq,
    Value<int>? timestampMs,
    Value<String>? kind,
    Value<String>? payloadJson,
    Value<int>? rowid,
  }) {
    return EventLogCompanion(
      id: id ?? this.id,
      seq: seq ?? this.seq,
      timestampMs: timestampMs ?? this.timestampMs,
      kind: kind ?? this.kind,
      payloadJson: payloadJson ?? this.payloadJson,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (seq.present) {
      map['seq'] = Variable<int>(seq.value);
    }
    if (timestampMs.present) {
      map['timestamp_ms'] = Variable<int>(timestampMs.value);
    }
    if (kind.present) {
      map['kind'] = Variable<String>(kind.value);
    }
    if (payloadJson.present) {
      map['payload_json'] = Variable<String>(payloadJson.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('EventLogCompanion(')
          ..write('id: $id, ')
          ..write('seq: $seq, ')
          ..write('timestampMs: $timestampMs, ')
          ..write('kind: $kind, ')
          ..write('payloadJson: $payloadJson, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $FoldersTable extends Folders with TableInfo<$FoldersTable, FolderRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $FoldersTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sortIndexMeta = const VerificationMeta(
    'sortIndex',
  );
  @override
  late final GeneratedColumn<int> sortIndex = GeneratedColumn<int>(
    'sort_index',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [id, name, sortIndex];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'folders';
  @override
  VerificationContext validateIntegrity(
    Insertable<FolderRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('sort_index')) {
      context.handle(
        _sortIndexMeta,
        sortIndex.isAcceptableOrUnknown(data['sort_index']!, _sortIndexMeta),
      );
    } else if (isInserting) {
      context.missing(_sortIndexMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  FolderRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return FolderRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      sortIndex: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sort_index'],
      )!,
    );
  }

  @override
  $FoldersTable createAlias(String alias) {
    return $FoldersTable(attachedDatabase, alias);
  }
}

class FolderRow extends DataClass implements Insertable<FolderRow> {
  final String id;
  final String name;
  final int sortIndex;
  const FolderRow({
    required this.id,
    required this.name,
    required this.sortIndex,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    map['sort_index'] = Variable<int>(sortIndex);
    return map;
  }

  FoldersCompanion toCompanion(bool nullToAbsent) {
    return FoldersCompanion(
      id: Value(id),
      name: Value(name),
      sortIndex: Value(sortIndex),
    );
  }

  factory FolderRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return FolderRow(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      sortIndex: serializer.fromJson<int>(json['sortIndex']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'sortIndex': serializer.toJson<int>(sortIndex),
    };
  }

  FolderRow copyWith({String? id, String? name, int? sortIndex}) => FolderRow(
    id: id ?? this.id,
    name: name ?? this.name,
    sortIndex: sortIndex ?? this.sortIndex,
  );
  FolderRow copyWithCompanion(FoldersCompanion data) {
    return FolderRow(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      sortIndex: data.sortIndex.present ? data.sortIndex.value : this.sortIndex,
    );
  }

  @override
  String toString() {
    return (StringBuffer('FolderRow(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('sortIndex: $sortIndex')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, name, sortIndex);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is FolderRow &&
          other.id == this.id &&
          other.name == this.name &&
          other.sortIndex == this.sortIndex);
}

class FoldersCompanion extends UpdateCompanion<FolderRow> {
  final Value<String> id;
  final Value<String> name;
  final Value<int> sortIndex;
  final Value<int> rowid;
  const FoldersCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.sortIndex = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  FoldersCompanion.insert({
    required String id,
    required String name,
    required int sortIndex,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       name = Value(name),
       sortIndex = Value(sortIndex);
  static Insertable<FolderRow> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<int>? sortIndex,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (sortIndex != null) 'sort_index': sortIndex,
      if (rowid != null) 'rowid': rowid,
    });
  }

  FoldersCompanion copyWith({
    Value<String>? id,
    Value<String>? name,
    Value<int>? sortIndex,
    Value<int>? rowid,
  }) {
    return FoldersCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      sortIndex: sortIndex ?? this.sortIndex,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (sortIndex.present) {
      map['sort_index'] = Variable<int>(sortIndex.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('FoldersCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('sortIndex: $sortIndex, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $DefaultRulesTable extends DefaultRules
    with TableInfo<$DefaultRulesTable, DefaultRuleRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DefaultRulesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _timerIdMeta = const VerificationMeta(
    'timerId',
  );
  @override
  late final GeneratedColumn<String> timerId = GeneratedColumn<String>(
    'timer_id',
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
  static const VerificationMeta _valueMeta = const VerificationMeta('value');
  @override
  late final GeneratedColumn<int> value = GeneratedColumn<int>(
    'value',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _repeatMeta = const VerificationMeta('repeat');
  @override
  late final GeneratedColumn<bool> repeat = GeneratedColumn<bool>(
    'repeat',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("repeat" IN (0, 1))',
    ),
  );
  @override
  List<GeneratedColumn> get $columns => [id, timerId, kind, value, repeat];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'default_rules';
  @override
  VerificationContext validateIntegrity(
    Insertable<DefaultRuleRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('timer_id')) {
      context.handle(
        _timerIdMeta,
        timerId.isAcceptableOrUnknown(data['timer_id']!, _timerIdMeta),
      );
    } else if (isInserting) {
      context.missing(_timerIdMeta);
    }
    if (data.containsKey('kind')) {
      context.handle(
        _kindMeta,
        kind.isAcceptableOrUnknown(data['kind']!, _kindMeta),
      );
    } else if (isInserting) {
      context.missing(_kindMeta);
    }
    if (data.containsKey('value')) {
      context.handle(
        _valueMeta,
        value.isAcceptableOrUnknown(data['value']!, _valueMeta),
      );
    }
    if (data.containsKey('repeat')) {
      context.handle(
        _repeatMeta,
        repeat.isAcceptableOrUnknown(data['repeat']!, _repeatMeta),
      );
    } else if (isInserting) {
      context.missing(_repeatMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  DefaultRuleRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DefaultRuleRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      timerId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}timer_id'],
      )!,
      kind: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}kind'],
      )!,
      value: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}value'],
      ),
      repeat: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}repeat'],
      )!,
    );
  }

  @override
  $DefaultRulesTable createAlias(String alias) {
    return $DefaultRulesTable(attachedDatabase, alias);
  }
}

class DefaultRuleRow extends DataClass implements Insertable<DefaultRuleRow> {
  final String id;
  final String timerId;
  final String kind;
  final int? value;
  final bool repeat;
  const DefaultRuleRow({
    required this.id,
    required this.timerId,
    required this.kind,
    this.value,
    required this.repeat,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['timer_id'] = Variable<String>(timerId);
    map['kind'] = Variable<String>(kind);
    if (!nullToAbsent || value != null) {
      map['value'] = Variable<int>(value);
    }
    map['repeat'] = Variable<bool>(repeat);
    return map;
  }

  DefaultRulesCompanion toCompanion(bool nullToAbsent) {
    return DefaultRulesCompanion(
      id: Value(id),
      timerId: Value(timerId),
      kind: Value(kind),
      value: value == null && nullToAbsent
          ? const Value.absent()
          : Value(value),
      repeat: Value(repeat),
    );
  }

  factory DefaultRuleRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DefaultRuleRow(
      id: serializer.fromJson<String>(json['id']),
      timerId: serializer.fromJson<String>(json['timerId']),
      kind: serializer.fromJson<String>(json['kind']),
      value: serializer.fromJson<int?>(json['value']),
      repeat: serializer.fromJson<bool>(json['repeat']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'timerId': serializer.toJson<String>(timerId),
      'kind': serializer.toJson<String>(kind),
      'value': serializer.toJson<int?>(value),
      'repeat': serializer.toJson<bool>(repeat),
    };
  }

  DefaultRuleRow copyWith({
    String? id,
    String? timerId,
    String? kind,
    Value<int?> value = const Value.absent(),
    bool? repeat,
  }) => DefaultRuleRow(
    id: id ?? this.id,
    timerId: timerId ?? this.timerId,
    kind: kind ?? this.kind,
    value: value.present ? value.value : this.value,
    repeat: repeat ?? this.repeat,
  );
  DefaultRuleRow copyWithCompanion(DefaultRulesCompanion data) {
    return DefaultRuleRow(
      id: data.id.present ? data.id.value : this.id,
      timerId: data.timerId.present ? data.timerId.value : this.timerId,
      kind: data.kind.present ? data.kind.value : this.kind,
      value: data.value.present ? data.value.value : this.value,
      repeat: data.repeat.present ? data.repeat.value : this.repeat,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DefaultRuleRow(')
          ..write('id: $id, ')
          ..write('timerId: $timerId, ')
          ..write('kind: $kind, ')
          ..write('value: $value, ')
          ..write('repeat: $repeat')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, timerId, kind, value, repeat);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DefaultRuleRow &&
          other.id == this.id &&
          other.timerId == this.timerId &&
          other.kind == this.kind &&
          other.value == this.value &&
          other.repeat == this.repeat);
}

class DefaultRulesCompanion extends UpdateCompanion<DefaultRuleRow> {
  final Value<String> id;
  final Value<String> timerId;
  final Value<String> kind;
  final Value<int?> value;
  final Value<bool> repeat;
  final Value<int> rowid;
  const DefaultRulesCompanion({
    this.id = const Value.absent(),
    this.timerId = const Value.absent(),
    this.kind = const Value.absent(),
    this.value = const Value.absent(),
    this.repeat = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  DefaultRulesCompanion.insert({
    required String id,
    required String timerId,
    required String kind,
    this.value = const Value.absent(),
    required bool repeat,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       timerId = Value(timerId),
       kind = Value(kind),
       repeat = Value(repeat);
  static Insertable<DefaultRuleRow> custom({
    Expression<String>? id,
    Expression<String>? timerId,
    Expression<String>? kind,
    Expression<int>? value,
    Expression<bool>? repeat,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (timerId != null) 'timer_id': timerId,
      if (kind != null) 'kind': kind,
      if (value != null) 'value': value,
      if (repeat != null) 'repeat': repeat,
      if (rowid != null) 'rowid': rowid,
    });
  }

  DefaultRulesCompanion copyWith({
    Value<String>? id,
    Value<String>? timerId,
    Value<String>? kind,
    Value<int?>? value,
    Value<bool>? repeat,
    Value<int>? rowid,
  }) {
    return DefaultRulesCompanion(
      id: id ?? this.id,
      timerId: timerId ?? this.timerId,
      kind: kind ?? this.kind,
      value: value ?? this.value,
      repeat: repeat ?? this.repeat,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (timerId.present) {
      map['timer_id'] = Variable<String>(timerId.value);
    }
    if (kind.present) {
      map['kind'] = Variable<String>(kind.value);
    }
    if (value.present) {
      map['value'] = Variable<int>(value.value);
    }
    if (repeat.present) {
      map['repeat'] = Variable<bool>(repeat.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DefaultRulesCompanion(')
          ..write('id: $id, ')
          ..write('timerId: $timerId, ')
          ..write('kind: $kind, ')
          ..write('value: $value, ')
          ..write('repeat: $repeat, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $DaysTable extends Days with TableInfo<$DaysTable, DayRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DaysTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _dateMeta = const VerificationMeta('date');
  @override
  late final GeneratedColumn<int> date = GeneratedColumn<int>(
    'date',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _planTimerIdMeta = const VerificationMeta(
    'planTimerId',
  );
  @override
  late final GeneratedColumn<String> planTimerId = GeneratedColumn<String>(
    'plan_timer_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [date, planTimerId];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'days';
  @override
  VerificationContext validateIntegrity(
    Insertable<DayRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('date')) {
      context.handle(
        _dateMeta,
        date.isAcceptableOrUnknown(data['date']!, _dateMeta),
      );
    }
    if (data.containsKey('plan_timer_id')) {
      context.handle(
        _planTimerIdMeta,
        planTimerId.isAcceptableOrUnknown(
          data['plan_timer_id']!,
          _planTimerIdMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {date};
  @override
  DayRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DayRow(
      date: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}date'],
      )!,
      planTimerId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}plan_timer_id'],
      ),
    );
  }

  @override
  $DaysTable createAlias(String alias) {
    return $DaysTable(attachedDatabase, alias);
  }
}

class DayRow extends DataClass implements Insertable<DayRow> {
  final int date;
  final String? planTimerId;
  const DayRow({required this.date, this.planTimerId});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['date'] = Variable<int>(date);
    if (!nullToAbsent || planTimerId != null) {
      map['plan_timer_id'] = Variable<String>(planTimerId);
    }
    return map;
  }

  DaysCompanion toCompanion(bool nullToAbsent) {
    return DaysCompanion(
      date: Value(date),
      planTimerId: planTimerId == null && nullToAbsent
          ? const Value.absent()
          : Value(planTimerId),
    );
  }

  factory DayRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DayRow(
      date: serializer.fromJson<int>(json['date']),
      planTimerId: serializer.fromJson<String?>(json['planTimerId']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'date': serializer.toJson<int>(date),
      'planTimerId': serializer.toJson<String?>(planTimerId),
    };
  }

  DayRow copyWith({
    int? date,
    Value<String?> planTimerId = const Value.absent(),
  }) => DayRow(
    date: date ?? this.date,
    planTimerId: planTimerId.present ? planTimerId.value : this.planTimerId,
  );
  DayRow copyWithCompanion(DaysCompanion data) {
    return DayRow(
      date: data.date.present ? data.date.value : this.date,
      planTimerId: data.planTimerId.present
          ? data.planTimerId.value
          : this.planTimerId,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DayRow(')
          ..write('date: $date, ')
          ..write('planTimerId: $planTimerId')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(date, planTimerId);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DayRow &&
          other.date == this.date &&
          other.planTimerId == this.planTimerId);
}

class DaysCompanion extends UpdateCompanion<DayRow> {
  final Value<int> date;
  final Value<String?> planTimerId;
  const DaysCompanion({
    this.date = const Value.absent(),
    this.planTimerId = const Value.absent(),
  });
  DaysCompanion.insert({
    this.date = const Value.absent(),
    this.planTimerId = const Value.absent(),
  });
  static Insertable<DayRow> custom({
    Expression<int>? date,
    Expression<String>? planTimerId,
  }) {
    return RawValuesInsertable({
      if (date != null) 'date': date,
      if (planTimerId != null) 'plan_timer_id': planTimerId,
    });
  }

  DaysCompanion copyWith({Value<int>? date, Value<String?>? planTimerId}) {
    return DaysCompanion(
      date: date ?? this.date,
      planTimerId: planTimerId ?? this.planTimerId,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (date.present) {
      map['date'] = Variable<int>(date.value);
    }
    if (planTimerId.present) {
      map['plan_timer_id'] = Variable<String>(planTimerId.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DaysCompanion(')
          ..write('date: $date, ')
          ..write('planTimerId: $planTimerId')
          ..write(')'))
        .toString();
  }
}

abstract class _$PlannerDb extends GeneratedDatabase {
  _$PlannerDb(QueryExecutor e) : super(e);
  $PlannerDbManager get managers => $PlannerDbManager(this);
  late final $BoardsTable boards = $BoardsTable(this);
  late final $TimersTable timers = $TimersTable(this);
  late final $IntervalDefsTable intervalDefs = $IntervalDefsTable(this);
  late final $GroupDefsTable groupDefs = $GroupDefsTable(this);
  late final $EventLogTable eventLog = $EventLogTable(this);
  late final $FoldersTable folders = $FoldersTable(this);
  late final $DefaultRulesTable defaultRules = $DefaultRulesTable(this);
  late final $DaysTable days = $DaysTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    boards,
    timers,
    intervalDefs,
    groupDefs,
    eventLog,
    folders,
    defaultRules,
    days,
  ];
}

typedef $$BoardsTableCreateCompanionBuilder = BoardsCompanion Function({
  required String id,
  required String name,
  Value<int> rowid,
});
typedef $$BoardsTableUpdateCompanionBuilder = BoardsCompanion Function({
  Value<String> id,
  Value<String> name,
  Value<int> rowid,
});

class $$BoardsTableFilterComposer extends Composer<_$PlannerDb, $BoardsTable> {
  $$BoardsTableFilterComposer({
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

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );
}

class $$BoardsTableOrderingComposer
    extends Composer<_$PlannerDb, $BoardsTable> {
  $$BoardsTableOrderingComposer({
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

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$BoardsTableAnnotationComposer
    extends Composer<_$PlannerDb, $BoardsTable> {
  $$BoardsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);
}

class $$BoardsTableTableManager
    extends
        RootTableManager<
          _$PlannerDb,
          $BoardsTable,
          BoardRow,
          $$BoardsTableFilterComposer,
          $$BoardsTableOrderingComposer,
          $$BoardsTableAnnotationComposer,
          $$BoardsTableCreateCompanionBuilder,
          $$BoardsTableUpdateCompanionBuilder,
          (BoardRow, BaseReferences<_$PlannerDb, $BoardsTable, BoardRow>),
          BoardRow,
          PrefetchHooks Function()
        > {
  $$BoardsTableTableManager(_$PlannerDb db, $BoardsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$BoardsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$BoardsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$BoardsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> name = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) => BoardsCompanion(id: id, name: name, rowid: rowid),
          createCompanionCallback: ({
            required String id,
            required String name,
            Value<int> rowid = const Value.absent(),
          }) => BoardsCompanion.insert(id: id, name: name, rowid: rowid),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$BoardsTable, BoardRow>(table),
                  BaseReferences<_$PlannerDb, $BoardsTable, BoardRow>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$BoardsTableProcessedTableManager =
    ProcessedTableManager<
      _$PlannerDb,
      $BoardsTable,
      BoardRow,
      $$BoardsTableFilterComposer,
      $$BoardsTableOrderingComposer,
      $$BoardsTableAnnotationComposer,
      $$BoardsTableCreateCompanionBuilder,
      $$BoardsTableUpdateCompanionBuilder,
      (BoardRow, BaseReferences<_$PlannerDb, $BoardsTable, BoardRow>),
      BoardRow,
      PrefetchHooks Function()
    >;
typedef $$TimersTableCreateCompanionBuilder = TimersCompanion Function({
  required String id,
  required String boardId,
  required String name,
  required String color,
  Value<String?> folderId,
  required int sortIndex,
  required int createdAt,
  required int updatedAt,
  Value<int?> dayDate,
  Value<String?> originPlanId,
  Value<int> rowid,
});
typedef $$TimersTableUpdateCompanionBuilder = TimersCompanion Function({
  Value<String> id,
  Value<String> boardId,
  Value<String> name,
  Value<String> color,
  Value<String?> folderId,
  Value<int> sortIndex,
  Value<int> createdAt,
  Value<int> updatedAt,
  Value<int?> dayDate,
  Value<String?> originPlanId,
  Value<int> rowid,
});

class $$TimersTableFilterComposer extends Composer<_$PlannerDb, $TimersTable> {
  $$TimersTableFilterComposer({
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

  ColumnFilters<String> get boardId => $composableBuilder(
    column: $table.boardId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get color => $composableBuilder(
    column: $table.color,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get folderId => $composableBuilder(
    column: $table.folderId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sortIndex => $composableBuilder(
    column: $table.sortIndex,
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

  ColumnFilters<int> get dayDate => $composableBuilder(
    column: $table.dayDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get originPlanId => $composableBuilder(
    column: $table.originPlanId,
    builder: (column) => ColumnFilters(column),
  );
}

class $$TimersTableOrderingComposer
    extends Composer<_$PlannerDb, $TimersTable> {
  $$TimersTableOrderingComposer({
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

  ColumnOrderings<String> get boardId => $composableBuilder(
    column: $table.boardId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get color => $composableBuilder(
    column: $table.color,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get folderId => $composableBuilder(
    column: $table.folderId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sortIndex => $composableBuilder(
    column: $table.sortIndex,
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

  ColumnOrderings<int> get dayDate => $composableBuilder(
    column: $table.dayDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get originPlanId => $composableBuilder(
    column: $table.originPlanId,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$TimersTableAnnotationComposer
    extends Composer<_$PlannerDb, $TimersTable> {
  $$TimersTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get boardId =>
      $composableBuilder(column: $table.boardId, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get color =>
      $composableBuilder(column: $table.color, builder: (column) => column);

  GeneratedColumn<String> get folderId =>
      $composableBuilder(column: $table.folderId, builder: (column) => column);

  GeneratedColumn<int> get sortIndex =>
      $composableBuilder(column: $table.sortIndex, builder: (column) => column);

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<int> get dayDate =>
      $composableBuilder(column: $table.dayDate, builder: (column) => column);

  GeneratedColumn<String> get originPlanId => $composableBuilder(
    column: $table.originPlanId,
    builder: (column) => column,
  );
}

class $$TimersTableTableManager
    extends
        RootTableManager<
          _$PlannerDb,
          $TimersTable,
          TimerRow,
          $$TimersTableFilterComposer,
          $$TimersTableOrderingComposer,
          $$TimersTableAnnotationComposer,
          $$TimersTableCreateCompanionBuilder,
          $$TimersTableUpdateCompanionBuilder,
          (TimerRow, BaseReferences<_$PlannerDb, $TimersTable, TimerRow>),
          TimerRow,
          PrefetchHooks Function()
        > {
  $$TimersTableTableManager(_$PlannerDb db, $TimersTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TimersTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TimersTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$TimersTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> boardId = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> color = const Value.absent(),
                Value<String?> folderId = const Value.absent(),
                Value<int> sortIndex = const Value.absent(),
                Value<int> createdAt = const Value.absent(),
                Value<int> updatedAt = const Value.absent(),
                Value<int?> dayDate = const Value.absent(),
                Value<String?> originPlanId = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => TimersCompanion(
                id: id,
                boardId: boardId,
                name: name,
                color: color,
                folderId: folderId,
                sortIndex: sortIndex,
                createdAt: createdAt,
                updatedAt: updatedAt,
                dayDate: dayDate,
                originPlanId: originPlanId,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String boardId,
                required String name,
                required String color,
                Value<String?> folderId = const Value.absent(),
                required int sortIndex,
                required int createdAt,
                required int updatedAt,
                Value<int?> dayDate = const Value.absent(),
                Value<String?> originPlanId = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => TimersCompanion.insert(
                id: id,
                boardId: boardId,
                name: name,
                color: color,
                folderId: folderId,
                sortIndex: sortIndex,
                createdAt: createdAt,
                updatedAt: updatedAt,
                dayDate: dayDate,
                originPlanId: originPlanId,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$TimersTable, TimerRow>(table),
                  BaseReferences<_$PlannerDb, $TimersTable, TimerRow>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$TimersTableProcessedTableManager =
    ProcessedTableManager<
      _$PlannerDb,
      $TimersTable,
      TimerRow,
      $$TimersTableFilterComposer,
      $$TimersTableOrderingComposer,
      $$TimersTableAnnotationComposer,
      $$TimersTableCreateCompanionBuilder,
      $$TimersTableUpdateCompanionBuilder,
      (TimerRow, BaseReferences<_$PlannerDb, $TimersTable, TimerRow>),
      TimerRow,
      PrefetchHooks Function()
    >;
typedef $$IntervalDefsTableCreateCompanionBuilder =
    IntervalDefsCompanion Function({
      required String id,
      required String timerId,
      Value<String?> name,
      required String color,
      Value<int?> durationSeconds,
      required bool autoFinish,
      Value<String?> endAlertSoundFile,
      Value<String?> parentGroupId,
      required int sortIndex,
      required bool completed,
      Value<int?> triggerTimeSeconds,
      Value<int> rowid,
    });
typedef $$IntervalDefsTableUpdateCompanionBuilder =
    IntervalDefsCompanion Function({
      Value<String> id,
      Value<String> timerId,
      Value<String?> name,
      Value<String> color,
      Value<int?> durationSeconds,
      Value<bool> autoFinish,
      Value<String?> endAlertSoundFile,
      Value<String?> parentGroupId,
      Value<int> sortIndex,
      Value<bool> completed,
      Value<int?> triggerTimeSeconds,
      Value<int> rowid,
    });

class $$IntervalDefsTableFilterComposer
    extends Composer<_$PlannerDb, $IntervalDefsTable> {
  $$IntervalDefsTableFilterComposer({
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

  ColumnFilters<String> get timerId => $composableBuilder(
    column: $table.timerId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get color => $composableBuilder(
    column: $table.color,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get durationSeconds => $composableBuilder(
    column: $table.durationSeconds,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get autoFinish => $composableBuilder(
    column: $table.autoFinish,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get endAlertSoundFile => $composableBuilder(
    column: $table.endAlertSoundFile,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get parentGroupId => $composableBuilder(
    column: $table.parentGroupId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sortIndex => $composableBuilder(
    column: $table.sortIndex,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get completed => $composableBuilder(
    column: $table.completed,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get triggerTimeSeconds => $composableBuilder(
    column: $table.triggerTimeSeconds,
    builder: (column) => ColumnFilters(column),
  );
}

class $$IntervalDefsTableOrderingComposer
    extends Composer<_$PlannerDb, $IntervalDefsTable> {
  $$IntervalDefsTableOrderingComposer({
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

  ColumnOrderings<String> get timerId => $composableBuilder(
    column: $table.timerId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get color => $composableBuilder(
    column: $table.color,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get durationSeconds => $composableBuilder(
    column: $table.durationSeconds,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get autoFinish => $composableBuilder(
    column: $table.autoFinish,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get endAlertSoundFile => $composableBuilder(
    column: $table.endAlertSoundFile,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get parentGroupId => $composableBuilder(
    column: $table.parentGroupId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sortIndex => $composableBuilder(
    column: $table.sortIndex,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get completed => $composableBuilder(
    column: $table.completed,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get triggerTimeSeconds => $composableBuilder(
    column: $table.triggerTimeSeconds,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$IntervalDefsTableAnnotationComposer
    extends Composer<_$PlannerDb, $IntervalDefsTable> {
  $$IntervalDefsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get timerId =>
      $composableBuilder(column: $table.timerId, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get color =>
      $composableBuilder(column: $table.color, builder: (column) => column);

  GeneratedColumn<int> get durationSeconds => $composableBuilder(
    column: $table.durationSeconds,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get autoFinish => $composableBuilder(
    column: $table.autoFinish,
    builder: (column) => column,
  );

  GeneratedColumn<String> get endAlertSoundFile => $composableBuilder(
    column: $table.endAlertSoundFile,
    builder: (column) => column,
  );

  GeneratedColumn<String> get parentGroupId => $composableBuilder(
    column: $table.parentGroupId,
    builder: (column) => column,
  );

  GeneratedColumn<int> get sortIndex =>
      $composableBuilder(column: $table.sortIndex, builder: (column) => column);

  GeneratedColumn<bool> get completed =>
      $composableBuilder(column: $table.completed, builder: (column) => column);

  GeneratedColumn<int> get triggerTimeSeconds => $composableBuilder(
    column: $table.triggerTimeSeconds,
    builder: (column) => column,
  );
}

class $$IntervalDefsTableTableManager
    extends
        RootTableManager<
          _$PlannerDb,
          $IntervalDefsTable,
          IntervalDefRow,
          $$IntervalDefsTableFilterComposer,
          $$IntervalDefsTableOrderingComposer,
          $$IntervalDefsTableAnnotationComposer,
          $$IntervalDefsTableCreateCompanionBuilder,
          $$IntervalDefsTableUpdateCompanionBuilder,
          (
            IntervalDefRow,
            BaseReferences<_$PlannerDb, $IntervalDefsTable, IntervalDefRow>,
          ),
          IntervalDefRow,
          PrefetchHooks Function()
        > {
  $$IntervalDefsTableTableManager(_$PlannerDb db, $IntervalDefsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$IntervalDefsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$IntervalDefsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$IntervalDefsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> timerId = const Value.absent(),
                Value<String?> name = const Value.absent(),
                Value<String> color = const Value.absent(),
                Value<int?> durationSeconds = const Value.absent(),
                Value<bool> autoFinish = const Value.absent(),
                Value<String?> endAlertSoundFile = const Value.absent(),
                Value<String?> parentGroupId = const Value.absent(),
                Value<int> sortIndex = const Value.absent(),
                Value<bool> completed = const Value.absent(),
                Value<int?> triggerTimeSeconds = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => IntervalDefsCompanion(
                id: id,
                timerId: timerId,
                name: name,
                color: color,
                durationSeconds: durationSeconds,
                autoFinish: autoFinish,
                endAlertSoundFile: endAlertSoundFile,
                parentGroupId: parentGroupId,
                sortIndex: sortIndex,
                completed: completed,
                triggerTimeSeconds: triggerTimeSeconds,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String timerId,
                Value<String?> name = const Value.absent(),
                required String color,
                Value<int?> durationSeconds = const Value.absent(),
                required bool autoFinish,
                Value<String?> endAlertSoundFile = const Value.absent(),
                Value<String?> parentGroupId = const Value.absent(),
                required int sortIndex,
                required bool completed,
                Value<int?> triggerTimeSeconds = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => IntervalDefsCompanion.insert(
                id: id,
                timerId: timerId,
                name: name,
                color: color,
                durationSeconds: durationSeconds,
                autoFinish: autoFinish,
                endAlertSoundFile: endAlertSoundFile,
                parentGroupId: parentGroupId,
                sortIndex: sortIndex,
                completed: completed,
                triggerTimeSeconds: triggerTimeSeconds,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$IntervalDefsTable, IntervalDefRow>(table),
                  BaseReferences<
                    _$PlannerDb,
                    $IntervalDefsTable,
                    IntervalDefRow
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$IntervalDefsTableProcessedTableManager =
    ProcessedTableManager<
      _$PlannerDb,
      $IntervalDefsTable,
      IntervalDefRow,
      $$IntervalDefsTableFilterComposer,
      $$IntervalDefsTableOrderingComposer,
      $$IntervalDefsTableAnnotationComposer,
      $$IntervalDefsTableCreateCompanionBuilder,
      $$IntervalDefsTableUpdateCompanionBuilder,
      (
        IntervalDefRow,
        BaseReferences<_$PlannerDb, $IntervalDefsTable, IntervalDefRow>,
      ),
      IntervalDefRow,
      PrefetchHooks Function()
    >;
typedef $$GroupDefsTableCreateCompanionBuilder = GroupDefsCompanion Function({
  required String id,
  required String timerId,
  required int repeatCount,
  Value<String?> parentGroupId,
  required int orderIndex,
  Value<int> rowid,
});
typedef $$GroupDefsTableUpdateCompanionBuilder = GroupDefsCompanion Function({
  Value<String> id,
  Value<String> timerId,
  Value<int> repeatCount,
  Value<String?> parentGroupId,
  Value<int> orderIndex,
  Value<int> rowid,
});

class $$GroupDefsTableFilterComposer
    extends Composer<_$PlannerDb, $GroupDefsTable> {
  $$GroupDefsTableFilterComposer({
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

  ColumnFilters<String> get timerId => $composableBuilder(
    column: $table.timerId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get repeatCount => $composableBuilder(
    column: $table.repeatCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get parentGroupId => $composableBuilder(
    column: $table.parentGroupId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get orderIndex => $composableBuilder(
    column: $table.orderIndex,
    builder: (column) => ColumnFilters(column),
  );
}

class $$GroupDefsTableOrderingComposer
    extends Composer<_$PlannerDb, $GroupDefsTable> {
  $$GroupDefsTableOrderingComposer({
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

  ColumnOrderings<String> get timerId => $composableBuilder(
    column: $table.timerId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get repeatCount => $composableBuilder(
    column: $table.repeatCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get parentGroupId => $composableBuilder(
    column: $table.parentGroupId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get orderIndex => $composableBuilder(
    column: $table.orderIndex,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$GroupDefsTableAnnotationComposer
    extends Composer<_$PlannerDb, $GroupDefsTable> {
  $$GroupDefsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get timerId =>
      $composableBuilder(column: $table.timerId, builder: (column) => column);

  GeneratedColumn<int> get repeatCount => $composableBuilder(
    column: $table.repeatCount,
    builder: (column) => column,
  );

  GeneratedColumn<String> get parentGroupId => $composableBuilder(
    column: $table.parentGroupId,
    builder: (column) => column,
  );

  GeneratedColumn<int> get orderIndex => $composableBuilder(
    column: $table.orderIndex,
    builder: (column) => column,
  );
}

class $$GroupDefsTableTableManager
    extends
        RootTableManager<
          _$PlannerDb,
          $GroupDefsTable,
          GroupDefRow,
          $$GroupDefsTableFilterComposer,
          $$GroupDefsTableOrderingComposer,
          $$GroupDefsTableAnnotationComposer,
          $$GroupDefsTableCreateCompanionBuilder,
          $$GroupDefsTableUpdateCompanionBuilder,
          (
            GroupDefRow,
            BaseReferences<_$PlannerDb, $GroupDefsTable, GroupDefRow>,
          ),
          GroupDefRow,
          PrefetchHooks Function()
        > {
  $$GroupDefsTableTableManager(_$PlannerDb db, $GroupDefsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$GroupDefsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$GroupDefsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$GroupDefsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> timerId = const Value.absent(),
                Value<int> repeatCount = const Value.absent(),
                Value<String?> parentGroupId = const Value.absent(),
                Value<int> orderIndex = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => GroupDefsCompanion(
                id: id,
                timerId: timerId,
                repeatCount: repeatCount,
                parentGroupId: parentGroupId,
                orderIndex: orderIndex,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String timerId,
                required int repeatCount,
                Value<String?> parentGroupId = const Value.absent(),
                required int orderIndex,
                Value<int> rowid = const Value.absent(),
              }) => GroupDefsCompanion.insert(
                id: id,
                timerId: timerId,
                repeatCount: repeatCount,
                parentGroupId: parentGroupId,
                orderIndex: orderIndex,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$GroupDefsTable, GroupDefRow>(table),
                  BaseReferences<_$PlannerDb, $GroupDefsTable, GroupDefRow>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$GroupDefsTableProcessedTableManager =
    ProcessedTableManager<
      _$PlannerDb,
      $GroupDefsTable,
      GroupDefRow,
      $$GroupDefsTableFilterComposer,
      $$GroupDefsTableOrderingComposer,
      $$GroupDefsTableAnnotationComposer,
      $$GroupDefsTableCreateCompanionBuilder,
      $$GroupDefsTableUpdateCompanionBuilder,
      (GroupDefRow, BaseReferences<_$PlannerDb, $GroupDefsTable, GroupDefRow>),
      GroupDefRow,
      PrefetchHooks Function()
    >;
typedef $$EventLogTableCreateCompanionBuilder = EventLogCompanion Function({
  required String id,
  required int seq,
  required int timestampMs,
  required String kind,
  required String payloadJson,
  Value<int> rowid,
});
typedef $$EventLogTableUpdateCompanionBuilder = EventLogCompanion Function({
  Value<String> id,
  Value<int> seq,
  Value<int> timestampMs,
  Value<String> kind,
  Value<String> payloadJson,
  Value<int> rowid,
});

class $$EventLogTableFilterComposer
    extends Composer<_$PlannerDb, $EventLogTable> {
  $$EventLogTableFilterComposer({
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

  ColumnFilters<int> get seq => $composableBuilder(
    column: $table.seq,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get timestampMs => $composableBuilder(
    column: $table.timestampMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get payloadJson => $composableBuilder(
    column: $table.payloadJson,
    builder: (column) => ColumnFilters(column),
  );
}

class $$EventLogTableOrderingComposer
    extends Composer<_$PlannerDb, $EventLogTable> {
  $$EventLogTableOrderingComposer({
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

  ColumnOrderings<int> get seq => $composableBuilder(
    column: $table.seq,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get timestampMs => $composableBuilder(
    column: $table.timestampMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get payloadJson => $composableBuilder(
    column: $table.payloadJson,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$EventLogTableAnnotationComposer
    extends Composer<_$PlannerDb, $EventLogTable> {
  $$EventLogTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get seq =>
      $composableBuilder(column: $table.seq, builder: (column) => column);

  GeneratedColumn<int> get timestampMs => $composableBuilder(
    column: $table.timestampMs,
    builder: (column) => column,
  );

  GeneratedColumn<String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<String> get payloadJson => $composableBuilder(
    column: $table.payloadJson,
    builder: (column) => column,
  );
}

class $$EventLogTableTableManager
    extends
        RootTableManager<
          _$PlannerDb,
          $EventLogTable,
          EventLogRow,
          $$EventLogTableFilterComposer,
          $$EventLogTableOrderingComposer,
          $$EventLogTableAnnotationComposer,
          $$EventLogTableCreateCompanionBuilder,
          $$EventLogTableUpdateCompanionBuilder,
          (
            EventLogRow,
            BaseReferences<_$PlannerDb, $EventLogTable, EventLogRow>,
          ),
          EventLogRow,
          PrefetchHooks Function()
        > {
  $$EventLogTableTableManager(_$PlannerDb db, $EventLogTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$EventLogTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$EventLogTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$EventLogTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<int> seq = const Value.absent(),
                Value<int> timestampMs = const Value.absent(),
                Value<String> kind = const Value.absent(),
                Value<String> payloadJson = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => EventLogCompanion(
                id: id,
                seq: seq,
                timestampMs: timestampMs,
                kind: kind,
                payloadJson: payloadJson,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required int seq,
                required int timestampMs,
                required String kind,
                required String payloadJson,
                Value<int> rowid = const Value.absent(),
              }) => EventLogCompanion.insert(
                id: id,
                seq: seq,
                timestampMs: timestampMs,
                kind: kind,
                payloadJson: payloadJson,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$EventLogTable, EventLogRow>(table),
                  BaseReferences<_$PlannerDb, $EventLogTable, EventLogRow>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$EventLogTableProcessedTableManager =
    ProcessedTableManager<
      _$PlannerDb,
      $EventLogTable,
      EventLogRow,
      $$EventLogTableFilterComposer,
      $$EventLogTableOrderingComposer,
      $$EventLogTableAnnotationComposer,
      $$EventLogTableCreateCompanionBuilder,
      $$EventLogTableUpdateCompanionBuilder,
      (EventLogRow, BaseReferences<_$PlannerDb, $EventLogTable, EventLogRow>),
      EventLogRow,
      PrefetchHooks Function()
    >;
typedef $$FoldersTableCreateCompanionBuilder = FoldersCompanion Function({
  required String id,
  required String name,
  required int sortIndex,
  Value<int> rowid,
});
typedef $$FoldersTableUpdateCompanionBuilder = FoldersCompanion Function({
  Value<String> id,
  Value<String> name,
  Value<int> sortIndex,
  Value<int> rowid,
});

class $$FoldersTableFilterComposer
    extends Composer<_$PlannerDb, $FoldersTable> {
  $$FoldersTableFilterComposer({
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

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sortIndex => $composableBuilder(
    column: $table.sortIndex,
    builder: (column) => ColumnFilters(column),
  );
}

class $$FoldersTableOrderingComposer
    extends Composer<_$PlannerDb, $FoldersTable> {
  $$FoldersTableOrderingComposer({
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

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sortIndex => $composableBuilder(
    column: $table.sortIndex,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$FoldersTableAnnotationComposer
    extends Composer<_$PlannerDb, $FoldersTable> {
  $$FoldersTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<int> get sortIndex =>
      $composableBuilder(column: $table.sortIndex, builder: (column) => column);
}

class $$FoldersTableTableManager
    extends
        RootTableManager<
          _$PlannerDb,
          $FoldersTable,
          FolderRow,
          $$FoldersTableFilterComposer,
          $$FoldersTableOrderingComposer,
          $$FoldersTableAnnotationComposer,
          $$FoldersTableCreateCompanionBuilder,
          $$FoldersTableUpdateCompanionBuilder,
          (FolderRow, BaseReferences<_$PlannerDb, $FoldersTable, FolderRow>),
          FolderRow,
          PrefetchHooks Function()
        > {
  $$FoldersTableTableManager(_$PlannerDb db, $FoldersTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$FoldersTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$FoldersTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$FoldersTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<int> sortIndex = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => FoldersCompanion(
                id: id,
                name: name,
                sortIndex: sortIndex,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String name,
                required int sortIndex,
                Value<int> rowid = const Value.absent(),
              }) => FoldersCompanion.insert(
                id: id,
                name: name,
                sortIndex: sortIndex,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$FoldersTable, FolderRow>(table),
                  BaseReferences<_$PlannerDb, $FoldersTable, FolderRow>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$FoldersTableProcessedTableManager =
    ProcessedTableManager<
      _$PlannerDb,
      $FoldersTable,
      FolderRow,
      $$FoldersTableFilterComposer,
      $$FoldersTableOrderingComposer,
      $$FoldersTableAnnotationComposer,
      $$FoldersTableCreateCompanionBuilder,
      $$FoldersTableUpdateCompanionBuilder,
      (FolderRow, BaseReferences<_$PlannerDb, $FoldersTable, FolderRow>),
      FolderRow,
      PrefetchHooks Function()
    >;
typedef $$DefaultRulesTableCreateCompanionBuilder =
    DefaultRulesCompanion Function({
      required String id,
      required String timerId,
      required String kind,
      Value<int?> value,
      required bool repeat,
      Value<int> rowid,
    });
typedef $$DefaultRulesTableUpdateCompanionBuilder =
    DefaultRulesCompanion Function({
      Value<String> id,
      Value<String> timerId,
      Value<String> kind,
      Value<int?> value,
      Value<bool> repeat,
      Value<int> rowid,
    });

class $$DefaultRulesTableFilterComposer
    extends Composer<_$PlannerDb, $DefaultRulesTable> {
  $$DefaultRulesTableFilterComposer({
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

  ColumnFilters<String> get timerId => $composableBuilder(
    column: $table.timerId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get repeat => $composableBuilder(
    column: $table.repeat,
    builder: (column) => ColumnFilters(column),
  );
}

class $$DefaultRulesTableOrderingComposer
    extends Composer<_$PlannerDb, $DefaultRulesTable> {
  $$DefaultRulesTableOrderingComposer({
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

  ColumnOrderings<String> get timerId => $composableBuilder(
    column: $table.timerId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get repeat => $composableBuilder(
    column: $table.repeat,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$DefaultRulesTableAnnotationComposer
    extends Composer<_$PlannerDb, $DefaultRulesTable> {
  $$DefaultRulesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get timerId =>
      $composableBuilder(column: $table.timerId, builder: (column) => column);

  GeneratedColumn<String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<int> get value =>
      $composableBuilder(column: $table.value, builder: (column) => column);

  GeneratedColumn<bool> get repeat =>
      $composableBuilder(column: $table.repeat, builder: (column) => column);
}

class $$DefaultRulesTableTableManager
    extends
        RootTableManager<
          _$PlannerDb,
          $DefaultRulesTable,
          DefaultRuleRow,
          $$DefaultRulesTableFilterComposer,
          $$DefaultRulesTableOrderingComposer,
          $$DefaultRulesTableAnnotationComposer,
          $$DefaultRulesTableCreateCompanionBuilder,
          $$DefaultRulesTableUpdateCompanionBuilder,
          (
            DefaultRuleRow,
            BaseReferences<_$PlannerDb, $DefaultRulesTable, DefaultRuleRow>,
          ),
          DefaultRuleRow,
          PrefetchHooks Function()
        > {
  $$DefaultRulesTableTableManager(_$PlannerDb db, $DefaultRulesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$DefaultRulesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$DefaultRulesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$DefaultRulesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> timerId = const Value.absent(),
                Value<String> kind = const Value.absent(),
                Value<int?> value = const Value.absent(),
                Value<bool> repeat = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => DefaultRulesCompanion(
                id: id,
                timerId: timerId,
                kind: kind,
                value: value,
                repeat: repeat,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String timerId,
                required String kind,
                Value<int?> value = const Value.absent(),
                required bool repeat,
                Value<int> rowid = const Value.absent(),
              }) => DefaultRulesCompanion.insert(
                id: id,
                timerId: timerId,
                kind: kind,
                value: value,
                repeat: repeat,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$DefaultRulesTable, DefaultRuleRow>(table),
                  BaseReferences<
                    _$PlannerDb,
                    $DefaultRulesTable,
                    DefaultRuleRow
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$DefaultRulesTableProcessedTableManager =
    ProcessedTableManager<
      _$PlannerDb,
      $DefaultRulesTable,
      DefaultRuleRow,
      $$DefaultRulesTableFilterComposer,
      $$DefaultRulesTableOrderingComposer,
      $$DefaultRulesTableAnnotationComposer,
      $$DefaultRulesTableCreateCompanionBuilder,
      $$DefaultRulesTableUpdateCompanionBuilder,
      (
        DefaultRuleRow,
        BaseReferences<_$PlannerDb, $DefaultRulesTable, DefaultRuleRow>,
      ),
      DefaultRuleRow,
      PrefetchHooks Function()
    >;
typedef $$DaysTableCreateCompanionBuilder = DaysCompanion Function({
  Value<int> date,
  Value<String?> planTimerId,
});
typedef $$DaysTableUpdateCompanionBuilder = DaysCompanion Function({
  Value<int> date,
  Value<String?> planTimerId,
});

class $$DaysTableFilterComposer extends Composer<_$PlannerDb, $DaysTable> {
  $$DaysTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get date => $composableBuilder(
    column: $table.date,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get planTimerId => $composableBuilder(
    column: $table.planTimerId,
    builder: (column) => ColumnFilters(column),
  );
}

class $$DaysTableOrderingComposer extends Composer<_$PlannerDb, $DaysTable> {
  $$DaysTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get date => $composableBuilder(
    column: $table.date,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get planTimerId => $composableBuilder(
    column: $table.planTimerId,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$DaysTableAnnotationComposer extends Composer<_$PlannerDb, $DaysTable> {
  $$DaysTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get date =>
      $composableBuilder(column: $table.date, builder: (column) => column);

  GeneratedColumn<String> get planTimerId => $composableBuilder(
    column: $table.planTimerId,
    builder: (column) => column,
  );
}

class $$DaysTableTableManager
    extends
        RootTableManager<
          _$PlannerDb,
          $DaysTable,
          DayRow,
          $$DaysTableFilterComposer,
          $$DaysTableOrderingComposer,
          $$DaysTableAnnotationComposer,
          $$DaysTableCreateCompanionBuilder,
          $$DaysTableUpdateCompanionBuilder,
          (DayRow, BaseReferences<_$PlannerDb, $DaysTable, DayRow>),
          DayRow,
          PrefetchHooks Function()
        > {
  $$DaysTableTableManager(_$PlannerDb db, $DaysTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$DaysTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$DaysTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$DaysTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> date = const Value.absent(),
            Value<String?> planTimerId = const Value.absent(),
          }) => DaysCompanion(date: date, planTimerId: planTimerId),
          createCompanionCallback: ({
            Value<int> date = const Value.absent(),
            Value<String?> planTimerId = const Value.absent(),
          }) => DaysCompanion.insert(date: date, planTimerId: planTimerId),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$DaysTable, DayRow>(table),
                  BaseReferences<_$PlannerDb, $DaysTable, DayRow>(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$DaysTableProcessedTableManager =
    ProcessedTableManager<
      _$PlannerDb,
      $DaysTable,
      DayRow,
      $$DaysTableFilterComposer,
      $$DaysTableOrderingComposer,
      $$DaysTableAnnotationComposer,
      $$DaysTableCreateCompanionBuilder,
      $$DaysTableUpdateCompanionBuilder,
      (DayRow, BaseReferences<_$PlannerDb, $DaysTable, DayRow>),
      DayRow,
      PrefetchHooks Function()
    >;

class $PlannerDbManager {
  final _$PlannerDb _db;
  $PlannerDbManager(this._db);
  $$BoardsTableTableManager get boards =>
      $$BoardsTableTableManager(_db, _db.boards);
  $$TimersTableTableManager get timers =>
      $$TimersTableTableManager(_db, _db.timers);
  $$IntervalDefsTableTableManager get intervalDefs =>
      $$IntervalDefsTableTableManager(_db, _db.intervalDefs);
  $$GroupDefsTableTableManager get groupDefs =>
      $$GroupDefsTableTableManager(_db, _db.groupDefs);
  $$EventLogTableTableManager get eventLog =>
      $$EventLogTableTableManager(_db, _db.eventLog);
  $$FoldersTableTableManager get folders =>
      $$FoldersTableTableManager(_db, _db.folders);
  $$DefaultRulesTableTableManager get defaultRules =>
      $$DefaultRulesTableTableManager(_db, _db.defaultRules);
  $$DaysTableTableManager get days => $$DaysTableTableManager(_db, _db.days);
}

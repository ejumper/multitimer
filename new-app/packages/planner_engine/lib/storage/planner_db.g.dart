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
  @override
  List<GeneratedColumn> get $columns => [id, boardId, name, color];
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
  const TimerRow({
    required this.id,
    required this.boardId,
    required this.name,
    required this.color,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['board_id'] = Variable<String>(boardId);
    map['name'] = Variable<String>(name);
    map['color'] = Variable<String>(color);
    return map;
  }

  TimersCompanion toCompanion(bool nullToAbsent) {
    return TimersCompanion(
      id: Value(id),
      boardId: Value(boardId),
      name: Value(name),
      color: Value(color),
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
    };
  }

  TimerRow copyWith({
    String? id,
    String? boardId,
    String? name,
    String? color,
  }) => TimerRow(
    id: id ?? this.id,
    boardId: boardId ?? this.boardId,
    name: name ?? this.name,
    color: color ?? this.color,
  );
  TimerRow copyWithCompanion(TimersCompanion data) {
    return TimerRow(
      id: data.id.present ? data.id.value : this.id,
      boardId: data.boardId.present ? data.boardId.value : this.boardId,
      name: data.name.present ? data.name.value : this.name,
      color: data.color.present ? data.color.value : this.color,
    );
  }

  @override
  String toString() {
    return (StringBuffer('TimerRow(')
          ..write('id: $id, ')
          ..write('boardId: $boardId, ')
          ..write('name: $name, ')
          ..write('color: $color')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, boardId, name, color);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TimerRow &&
          other.id == this.id &&
          other.boardId == this.boardId &&
          other.name == this.name &&
          other.color == this.color);
}

class TimersCompanion extends UpdateCompanion<TimerRow> {
  final Value<String> id;
  final Value<String> boardId;
  final Value<String> name;
  final Value<String> color;
  final Value<int> rowid;
  const TimersCompanion({
    this.id = const Value.absent(),
    this.boardId = const Value.absent(),
    this.name = const Value.absent(),
    this.color = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  TimersCompanion.insert({
    required String id,
    required String boardId,
    required String name,
    required String color,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       boardId = Value(boardId),
       name = Value(name),
       color = Value(color);
  static Insertable<TimerRow> custom({
    Expression<String>? id,
    Expression<String>? boardId,
    Expression<String>? name,
    Expression<String>? color,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (boardId != null) 'board_id': boardId,
      if (name != null) 'name': name,
      if (color != null) 'color': color,
      if (rowid != null) 'rowid': rowid,
    });
  }

  TimersCompanion copyWith({
    Value<String>? id,
    Value<String>? boardId,
    Value<String>? name,
    Value<String>? color,
    Value<int>? rowid,
  }) {
    return TimersCompanion(
      id: id ?? this.id,
      boardId: boardId ?? this.boardId,
      name: name ?? this.name,
      color: color ?? this.color,
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
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
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
  static const VerificationMeta _completionDefaultMeta = const VerificationMeta(
    'completionDefault',
  );
  @override
  late final GeneratedColumn<String> completionDefault =
      GeneratedColumn<String>(
        'completion_default',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
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
    completionDefault,
    trigger,
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
    } else if (isInserting) {
      context.missing(_durationSecondsMeta);
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
    if (data.containsKey('completion_default')) {
      context.handle(
        _completionDefaultMeta,
        completionDefault.isAcceptableOrUnknown(
          data['completion_default']!,
          _completionDefaultMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_completionDefaultMeta);
    }
    if (data.containsKey('trigger')) {
      context.handle(
        _triggerMeta,
        trigger.isAcceptableOrUnknown(data['trigger']!, _triggerMeta),
      );
    } else if (isInserting) {
      context.missing(_triggerMeta);
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
      )!,
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
      completionDefault: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}completion_default'],
      )!,
      trigger: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}trigger'],
      )!,
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
  final int durationSeconds;
  final bool autoFinish;
  final String? endAlertSoundFile;
  final String? parentGroupId;
  final int sortIndex;
  final String completionDefault;
  final String trigger;
  const IntervalDefRow({
    required this.id,
    required this.timerId,
    this.name,
    required this.color,
    required this.durationSeconds,
    required this.autoFinish,
    this.endAlertSoundFile,
    this.parentGroupId,
    required this.sortIndex,
    required this.completionDefault,
    required this.trigger,
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
    map['duration_seconds'] = Variable<int>(durationSeconds);
    map['auto_finish'] = Variable<bool>(autoFinish);
    if (!nullToAbsent || endAlertSoundFile != null) {
      map['end_alert_sound_file'] = Variable<String>(endAlertSoundFile);
    }
    if (!nullToAbsent || parentGroupId != null) {
      map['parent_group_id'] = Variable<String>(parentGroupId);
    }
    map['sort_index'] = Variable<int>(sortIndex);
    map['completion_default'] = Variable<String>(completionDefault);
    map['trigger'] = Variable<String>(trigger);
    return map;
  }

  IntervalDefsCompanion toCompanion(bool nullToAbsent) {
    return IntervalDefsCompanion(
      id: Value(id),
      timerId: Value(timerId),
      name: name == null && nullToAbsent ? const Value.absent() : Value(name),
      color: Value(color),
      durationSeconds: Value(durationSeconds),
      autoFinish: Value(autoFinish),
      endAlertSoundFile: endAlertSoundFile == null && nullToAbsent
          ? const Value.absent()
          : Value(endAlertSoundFile),
      parentGroupId: parentGroupId == null && nullToAbsent
          ? const Value.absent()
          : Value(parentGroupId),
      sortIndex: Value(sortIndex),
      completionDefault: Value(completionDefault),
      trigger: Value(trigger),
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
      durationSeconds: serializer.fromJson<int>(json['durationSeconds']),
      autoFinish: serializer.fromJson<bool>(json['autoFinish']),
      endAlertSoundFile: serializer.fromJson<String?>(
        json['endAlertSoundFile'],
      ),
      parentGroupId: serializer.fromJson<String?>(json['parentGroupId']),
      sortIndex: serializer.fromJson<int>(json['sortIndex']),
      completionDefault: serializer.fromJson<String>(json['completionDefault']),
      trigger: serializer.fromJson<String>(json['trigger']),
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
      'durationSeconds': serializer.toJson<int>(durationSeconds),
      'autoFinish': serializer.toJson<bool>(autoFinish),
      'endAlertSoundFile': serializer.toJson<String?>(endAlertSoundFile),
      'parentGroupId': serializer.toJson<String?>(parentGroupId),
      'sortIndex': serializer.toJson<int>(sortIndex),
      'completionDefault': serializer.toJson<String>(completionDefault),
      'trigger': serializer.toJson<String>(trigger),
    };
  }

  IntervalDefRow copyWith({
    String? id,
    String? timerId,
    Value<String?> name = const Value.absent(),
    String? color,
    int? durationSeconds,
    bool? autoFinish,
    Value<String?> endAlertSoundFile = const Value.absent(),
    Value<String?> parentGroupId = const Value.absent(),
    int? sortIndex,
    String? completionDefault,
    String? trigger,
  }) => IntervalDefRow(
    id: id ?? this.id,
    timerId: timerId ?? this.timerId,
    name: name.present ? name.value : this.name,
    color: color ?? this.color,
    durationSeconds: durationSeconds ?? this.durationSeconds,
    autoFinish: autoFinish ?? this.autoFinish,
    endAlertSoundFile: endAlertSoundFile.present
        ? endAlertSoundFile.value
        : this.endAlertSoundFile,
    parentGroupId: parentGroupId.present
        ? parentGroupId.value
        : this.parentGroupId,
    sortIndex: sortIndex ?? this.sortIndex,
    completionDefault: completionDefault ?? this.completionDefault,
    trigger: trigger ?? this.trigger,
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
      completionDefault: data.completionDefault.present
          ? data.completionDefault.value
          : this.completionDefault,
      trigger: data.trigger.present ? data.trigger.value : this.trigger,
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
          ..write('completionDefault: $completionDefault, ')
          ..write('trigger: $trigger')
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
    completionDefault,
    trigger,
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
          other.completionDefault == this.completionDefault &&
          other.trigger == this.trigger);
}

class IntervalDefsCompanion extends UpdateCompanion<IntervalDefRow> {
  final Value<String> id;
  final Value<String> timerId;
  final Value<String?> name;
  final Value<String> color;
  final Value<int> durationSeconds;
  final Value<bool> autoFinish;
  final Value<String?> endAlertSoundFile;
  final Value<String?> parentGroupId;
  final Value<int> sortIndex;
  final Value<String> completionDefault;
  final Value<String> trigger;
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
    this.completionDefault = const Value.absent(),
    this.trigger = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  IntervalDefsCompanion.insert({
    required String id,
    required String timerId,
    this.name = const Value.absent(),
    required String color,
    required int durationSeconds,
    required bool autoFinish,
    this.endAlertSoundFile = const Value.absent(),
    this.parentGroupId = const Value.absent(),
    required int sortIndex,
    required String completionDefault,
    required String trigger,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       timerId = Value(timerId),
       color = Value(color),
       durationSeconds = Value(durationSeconds),
       autoFinish = Value(autoFinish),
       sortIndex = Value(sortIndex),
       completionDefault = Value(completionDefault),
       trigger = Value(trigger);
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
    Expression<String>? completionDefault,
    Expression<String>? trigger,
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
      if (completionDefault != null) 'completion_default': completionDefault,
      if (trigger != null) 'trigger': trigger,
      if (rowid != null) 'rowid': rowid,
    });
  }

  IntervalDefsCompanion copyWith({
    Value<String>? id,
    Value<String>? timerId,
    Value<String?>? name,
    Value<String>? color,
    Value<int>? durationSeconds,
    Value<bool>? autoFinish,
    Value<String?>? endAlertSoundFile,
    Value<String?>? parentGroupId,
    Value<int>? sortIndex,
    Value<String>? completionDefault,
    Value<String>? trigger,
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
      completionDefault: completionDefault ?? this.completionDefault,
      trigger: trigger ?? this.trigger,
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
    if (completionDefault.present) {
      map['completion_default'] = Variable<String>(completionDefault.value);
    }
    if (trigger.present) {
      map['trigger'] = Variable<String>(trigger.value);
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
          ..write('completionDefault: $completionDefault, ')
          ..write('trigger: $trigger, ')
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

abstract class _$PlannerDb extends GeneratedDatabase {
  _$PlannerDb(QueryExecutor e) : super(e);
  $PlannerDbManager get managers => $PlannerDbManager(this);
  late final $BoardsTable boards = $BoardsTable(this);
  late final $TimersTable timers = $TimersTable(this);
  late final $IntervalDefsTable intervalDefs = $IntervalDefsTable(this);
  late final $GroupDefsTable groupDefs = $GroupDefsTable(this);
  late final $EventLogTable eventLog = $EventLogTable(this);
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
  Value<int> rowid,
});
typedef $$TimersTableUpdateCompanionBuilder = TimersCompanion Function({
  Value<String> id,
  Value<String> boardId,
  Value<String> name,
  Value<String> color,
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
                Value<int> rowid = const Value.absent(),
              }) => TimersCompanion(
                id: id,
                boardId: boardId,
                name: name,
                color: color,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String boardId,
                required String name,
                required String color,
                Value<int> rowid = const Value.absent(),
              }) => TimersCompanion.insert(
                id: id,
                boardId: boardId,
                name: name,
                color: color,
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
      required int durationSeconds,
      required bool autoFinish,
      Value<String?> endAlertSoundFile,
      Value<String?> parentGroupId,
      required int sortIndex,
      required String completionDefault,
      required String trigger,
      Value<int> rowid,
    });
typedef $$IntervalDefsTableUpdateCompanionBuilder =
    IntervalDefsCompanion Function({
      Value<String> id,
      Value<String> timerId,
      Value<String?> name,
      Value<String> color,
      Value<int> durationSeconds,
      Value<bool> autoFinish,
      Value<String?> endAlertSoundFile,
      Value<String?> parentGroupId,
      Value<int> sortIndex,
      Value<String> completionDefault,
      Value<String> trigger,
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

  ColumnFilters<String> get completionDefault => $composableBuilder(
    column: $table.completionDefault,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get trigger => $composableBuilder(
    column: $table.trigger,
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

  ColumnOrderings<String> get completionDefault => $composableBuilder(
    column: $table.completionDefault,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get trigger => $composableBuilder(
    column: $table.trigger,
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

  GeneratedColumn<String> get completionDefault => $composableBuilder(
    column: $table.completionDefault,
    builder: (column) => column,
  );

  GeneratedColumn<String> get trigger =>
      $composableBuilder(column: $table.trigger, builder: (column) => column);
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
                Value<int> durationSeconds = const Value.absent(),
                Value<bool> autoFinish = const Value.absent(),
                Value<String?> endAlertSoundFile = const Value.absent(),
                Value<String?> parentGroupId = const Value.absent(),
                Value<int> sortIndex = const Value.absent(),
                Value<String> completionDefault = const Value.absent(),
                Value<String> trigger = const Value.absent(),
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
                completionDefault: completionDefault,
                trigger: trigger,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String timerId,
                Value<String?> name = const Value.absent(),
                required String color,
                required int durationSeconds,
                required bool autoFinish,
                Value<String?> endAlertSoundFile = const Value.absent(),
                Value<String?> parentGroupId = const Value.absent(),
                required int sortIndex,
                required String completionDefault,
                required String trigger,
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
                completionDefault: completionDefault,
                trigger: trigger,
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
}

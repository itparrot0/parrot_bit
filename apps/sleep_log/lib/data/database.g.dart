// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'database.dart';

// ignore_for_file: type=lint
class $DiaryEntriesTable extends DiaryEntries
    with TableInfo<$DiaryEntriesTable, DiaryEntryRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DiaryEntriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _dateMeta = const VerificationMeta('date');
  @override
  late final GeneratedColumn<String> date = GeneratedColumn<String>(
    'date',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _bedMinuteMeta = const VerificationMeta(
    'bedMinute',
  );
  @override
  late final GeneratedColumn<int> bedMinute = GeneratedColumn<int>(
    'bed_minute',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _wakeMinuteMeta = const VerificationMeta(
    'wakeMinute',
  );
  @override
  late final GeneratedColumn<int> wakeMinute = GeneratedColumn<int>(
    'wake_minute',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _restedMeta = const VerificationMeta('rested');
  @override
  late final GeneratedColumn<String> rested = GeneratedColumn<String>(
    'rested',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [date, bedMinute, wakeMinute, rested];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'diary_entries';
  @override
  VerificationContext validateIntegrity(
    Insertable<DiaryEntryRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('date')) {
      context.handle(
        _dateMeta,
        date.isAcceptableOrUnknown(data['date']!, _dateMeta),
      );
    } else if (isInserting) {
      context.missing(_dateMeta);
    }
    if (data.containsKey('bed_minute')) {
      context.handle(
        _bedMinuteMeta,
        bedMinute.isAcceptableOrUnknown(data['bed_minute']!, _bedMinuteMeta),
      );
    }
    if (data.containsKey('wake_minute')) {
      context.handle(
        _wakeMinuteMeta,
        wakeMinute.isAcceptableOrUnknown(data['wake_minute']!, _wakeMinuteMeta),
      );
    }
    if (data.containsKey('rested')) {
      context.handle(
        _restedMeta,
        rested.isAcceptableOrUnknown(data['rested']!, _restedMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {date};
  @override
  DiaryEntryRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DiaryEntryRow(
      date: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}date'],
      )!,
      bedMinute: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}bed_minute'],
      ),
      wakeMinute: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}wake_minute'],
      ),
      rested: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}rested'],
      ),
    );
  }

  @override
  $DiaryEntriesTable createAlias(String alias) {
    return $DiaryEntriesTable(attachedDatabase, alias);
  }
}

class DiaryEntryRow extends DataClass implements Insertable<DiaryEntryRow> {
  final String date;

  /// 취침·기상 시각 (자정부터 분). 둘 다 있거나 둘 다 없다 — 수면 없이 태그만
  /// 남긴 날이 있기 때문이다 (docs/screen-flow/sleep_log.md §5).
  final int? bedMinute;
  final int? wakeMinute;

  /// `RestFeeling.name`. 답하지 않았으면 null. (schema 3)
  final String? rested;
  const DiaryEntryRow({
    required this.date,
    this.bedMinute,
    this.wakeMinute,
    this.rested,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['date'] = Variable<String>(date);
    if (!nullToAbsent || bedMinute != null) {
      map['bed_minute'] = Variable<int>(bedMinute);
    }
    if (!nullToAbsent || wakeMinute != null) {
      map['wake_minute'] = Variable<int>(wakeMinute);
    }
    if (!nullToAbsent || rested != null) {
      map['rested'] = Variable<String>(rested);
    }
    return map;
  }

  DiaryEntriesCompanion toCompanion(bool nullToAbsent) {
    return DiaryEntriesCompanion(
      date: Value(date),
      bedMinute: bedMinute == null && nullToAbsent
          ? const Value.absent()
          : Value(bedMinute),
      wakeMinute: wakeMinute == null && nullToAbsent
          ? const Value.absent()
          : Value(wakeMinute),
      rested: rested == null && nullToAbsent
          ? const Value.absent()
          : Value(rested),
    );
  }

  factory DiaryEntryRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DiaryEntryRow(
      date: serializer.fromJson<String>(json['date']),
      bedMinute: serializer.fromJson<int?>(json['bedMinute']),
      wakeMinute: serializer.fromJson<int?>(json['wakeMinute']),
      rested: serializer.fromJson<String?>(json['rested']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'date': serializer.toJson<String>(date),
      'bedMinute': serializer.toJson<int?>(bedMinute),
      'wakeMinute': serializer.toJson<int?>(wakeMinute),
      'rested': serializer.toJson<String?>(rested),
    };
  }

  DiaryEntryRow copyWith({
    String? date,
    Value<int?> bedMinute = const Value.absent(),
    Value<int?> wakeMinute = const Value.absent(),
    Value<String?> rested = const Value.absent(),
  }) => DiaryEntryRow(
    date: date ?? this.date,
    bedMinute: bedMinute.present ? bedMinute.value : this.bedMinute,
    wakeMinute: wakeMinute.present ? wakeMinute.value : this.wakeMinute,
    rested: rested.present ? rested.value : this.rested,
  );
  DiaryEntryRow copyWithCompanion(DiaryEntriesCompanion data) {
    return DiaryEntryRow(
      date: data.date.present ? data.date.value : this.date,
      bedMinute: data.bedMinute.present ? data.bedMinute.value : this.bedMinute,
      wakeMinute: data.wakeMinute.present
          ? data.wakeMinute.value
          : this.wakeMinute,
      rested: data.rested.present ? data.rested.value : this.rested,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DiaryEntryRow(')
          ..write('date: $date, ')
          ..write('bedMinute: $bedMinute, ')
          ..write('wakeMinute: $wakeMinute, ')
          ..write('rested: $rested')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(date, bedMinute, wakeMinute, rested);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DiaryEntryRow &&
          other.date == this.date &&
          other.bedMinute == this.bedMinute &&
          other.wakeMinute == this.wakeMinute &&
          other.rested == this.rested);
}

class DiaryEntriesCompanion extends UpdateCompanion<DiaryEntryRow> {
  final Value<String> date;
  final Value<int?> bedMinute;
  final Value<int?> wakeMinute;
  final Value<String?> rested;
  final Value<int> rowid;
  const DiaryEntriesCompanion({
    this.date = const Value.absent(),
    this.bedMinute = const Value.absent(),
    this.wakeMinute = const Value.absent(),
    this.rested = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  DiaryEntriesCompanion.insert({
    required String date,
    this.bedMinute = const Value.absent(),
    this.wakeMinute = const Value.absent(),
    this.rested = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : date = Value(date);
  static Insertable<DiaryEntryRow> custom({
    Expression<String>? date,
    Expression<int>? bedMinute,
    Expression<int>? wakeMinute,
    Expression<String>? rested,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (date != null) 'date': date,
      if (bedMinute != null) 'bed_minute': bedMinute,
      if (wakeMinute != null) 'wake_minute': wakeMinute,
      if (rested != null) 'rested': rested,
      if (rowid != null) 'rowid': rowid,
    });
  }

  DiaryEntriesCompanion copyWith({
    Value<String>? date,
    Value<int?>? bedMinute,
    Value<int?>? wakeMinute,
    Value<String?>? rested,
    Value<int>? rowid,
  }) {
    return DiaryEntriesCompanion(
      date: date ?? this.date,
      bedMinute: bedMinute ?? this.bedMinute,
      wakeMinute: wakeMinute ?? this.wakeMinute,
      rested: rested ?? this.rested,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (date.present) {
      map['date'] = Variable<String>(date.value);
    }
    if (bedMinute.present) {
      map['bed_minute'] = Variable<int>(bedMinute.value);
    }
    if (wakeMinute.present) {
      map['wake_minute'] = Variable<int>(wakeMinute.value);
    }
    if (rested.present) {
      map['rested'] = Variable<String>(rested.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DiaryEntriesCompanion(')
          ..write('date: $date, ')
          ..write('bedMinute: $bedMinute, ')
          ..write('wakeMinute: $wakeMinute, ')
          ..write('rested: $rested, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $EntryTagsTable extends EntryTags
    with TableInfo<$EntryTagsTable, EntryTagRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $EntryTagsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _dateMeta = const VerificationMeta('date');
  @override
  late final GeneratedColumn<String> date = GeneratedColumn<String>(
    'date',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES diary_entries (date) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _tagIdMeta = const VerificationMeta('tagId');
  @override
  late final GeneratedColumn<String> tagId = GeneratedColumn<String>(
    'tag_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [date, tagId];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'entry_tags';
  @override
  VerificationContext validateIntegrity(
    Insertable<EntryTagRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('date')) {
      context.handle(
        _dateMeta,
        date.isAcceptableOrUnknown(data['date']!, _dateMeta),
      );
    } else if (isInserting) {
      context.missing(_dateMeta);
    }
    if (data.containsKey('tag_id')) {
      context.handle(
        _tagIdMeta,
        tagId.isAcceptableOrUnknown(data['tag_id']!, _tagIdMeta),
      );
    } else if (isInserting) {
      context.missing(_tagIdMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {date, tagId};
  @override
  EntryTagRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return EntryTagRow(
      date: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}date'],
      )!,
      tagId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}tag_id'],
      )!,
    );
  }

  @override
  $EntryTagsTable createAlias(String alias) {
    return $EntryTagsTable(attachedDatabase, alias);
  }
}

class EntryTagRow extends DataClass implements Insertable<EntryTagRow> {
  final String date;

  /// [MoodTag.id]. 표시 문구가 아니라 id를 저장해, 문구를 고쳐도 기록이
  /// 고아가 되지 않는다.
  final String tagId;
  const EntryTagRow({required this.date, required this.tagId});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['date'] = Variable<String>(date);
    map['tag_id'] = Variable<String>(tagId);
    return map;
  }

  EntryTagsCompanion toCompanion(bool nullToAbsent) {
    return EntryTagsCompanion(date: Value(date), tagId: Value(tagId));
  }

  factory EntryTagRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return EntryTagRow(
      date: serializer.fromJson<String>(json['date']),
      tagId: serializer.fromJson<String>(json['tagId']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'date': serializer.toJson<String>(date),
      'tagId': serializer.toJson<String>(tagId),
    };
  }

  EntryTagRow copyWith({String? date, String? tagId}) =>
      EntryTagRow(date: date ?? this.date, tagId: tagId ?? this.tagId);
  EntryTagRow copyWithCompanion(EntryTagsCompanion data) {
    return EntryTagRow(
      date: data.date.present ? data.date.value : this.date,
      tagId: data.tagId.present ? data.tagId.value : this.tagId,
    );
  }

  @override
  String toString() {
    return (StringBuffer('EntryTagRow(')
          ..write('date: $date, ')
          ..write('tagId: $tagId')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(date, tagId);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is EntryTagRow &&
          other.date == this.date &&
          other.tagId == this.tagId);
}

class EntryTagsCompanion extends UpdateCompanion<EntryTagRow> {
  final Value<String> date;
  final Value<String> tagId;
  final Value<int> rowid;
  const EntryTagsCompanion({
    this.date = const Value.absent(),
    this.tagId = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  EntryTagsCompanion.insert({
    required String date,
    required String tagId,
    this.rowid = const Value.absent(),
  }) : date = Value(date),
       tagId = Value(tagId);
  static Insertable<EntryTagRow> custom({
    Expression<String>? date,
    Expression<String>? tagId,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (date != null) 'date': date,
      if (tagId != null) 'tag_id': tagId,
      if (rowid != null) 'rowid': rowid,
    });
  }

  EntryTagsCompanion copyWith({
    Value<String>? date,
    Value<String>? tagId,
    Value<int>? rowid,
  }) {
    return EntryTagsCompanion(
      date: date ?? this.date,
      tagId: tagId ?? this.tagId,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (date.present) {
      map['date'] = Variable<String>(date.value);
    }
    if (tagId.present) {
      map['tag_id'] = Variable<String>(tagId.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('EntryTagsCompanion(')
          ..write('date: $date, ')
          ..write('tagId: $tagId, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ThoughtCheckInsTable extends ThoughtCheckIns
    with TableInfo<$ThoughtCheckInsTable, CheckInRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ThoughtCheckInsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _dateMeta = const VerificationMeta('date');
  @override
  late final GeneratedColumn<String> date = GeneratedColumn<String>(
    'date',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _slotMeta = const VerificationMeta('slot');
  @override
  late final GeneratedColumn<String> slot = GeneratedColumn<String>(
    'slot',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _paceMeta = const VerificationMeta('pace');
  @override
  late final GeneratedColumn<String> pace = GeneratedColumn<String>(
    'pace',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _sensesMeta = const VerificationMeta('senses');
  @override
  late final GeneratedColumn<String> senses = GeneratedColumn<String>(
    'senses',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _thoughtMeta = const VerificationMeta(
    'thought',
  );
  @override
  late final GeneratedColumn<String> thought = GeneratedColumn<String>(
    'thought',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _reframeMeta = const VerificationMeta(
    'reframe',
  );
  @override
  late final GeneratedColumn<String> reframe = GeneratedColumn<String>(
    'reframe',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    date,
    slot,
    pace,
    senses,
    thought,
    reframe,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'thought_check_ins';
  @override
  VerificationContext validateIntegrity(
    Insertable<CheckInRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('date')) {
      context.handle(
        _dateMeta,
        date.isAcceptableOrUnknown(data['date']!, _dateMeta),
      );
    } else if (isInserting) {
      context.missing(_dateMeta);
    }
    if (data.containsKey('slot')) {
      context.handle(
        _slotMeta,
        slot.isAcceptableOrUnknown(data['slot']!, _slotMeta),
      );
    } else if (isInserting) {
      context.missing(_slotMeta);
    }
    if (data.containsKey('pace')) {
      context.handle(
        _paceMeta,
        pace.isAcceptableOrUnknown(data['pace']!, _paceMeta),
      );
    }
    if (data.containsKey('senses')) {
      context.handle(
        _sensesMeta,
        senses.isAcceptableOrUnknown(data['senses']!, _sensesMeta),
      );
    }
    if (data.containsKey('thought')) {
      context.handle(
        _thoughtMeta,
        thought.isAcceptableOrUnknown(data['thought']!, _thoughtMeta),
      );
    }
    if (data.containsKey('reframe')) {
      context.handle(
        _reframeMeta,
        reframe.isAcceptableOrUnknown(data['reframe']!, _reframeMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {date, slot};
  @override
  CheckInRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CheckInRow(
      date: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}date'],
      )!,
      slot: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}slot'],
      )!,
      pace: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}pace'],
      ),
      senses: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}senses'],
      ),
      thought: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}thought'],
      ),
      reframe: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}reframe'],
      ),
    );
  }

  @override
  $ThoughtCheckInsTable createAlias(String alias) {
    return $ThoughtCheckInsTable(attachedDatabase, alias);
  }
}

class CheckInRow extends DataClass implements Insertable<CheckInRow> {
  final String date;

  /// `CheckInSlot.name` (`morning` / `afternoon`).
  final String slot;

  /// `MindPace.name`. 답하지 않았으면 null.
  final String? pace;

  /// `SenseShift.name`. 답하지 않았으면 null.
  final String? senses;
  final String? thought;
  final String? reframe;
  const CheckInRow({
    required this.date,
    required this.slot,
    this.pace,
    this.senses,
    this.thought,
    this.reframe,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['date'] = Variable<String>(date);
    map['slot'] = Variable<String>(slot);
    if (!nullToAbsent || pace != null) {
      map['pace'] = Variable<String>(pace);
    }
    if (!nullToAbsent || senses != null) {
      map['senses'] = Variable<String>(senses);
    }
    if (!nullToAbsent || thought != null) {
      map['thought'] = Variable<String>(thought);
    }
    if (!nullToAbsent || reframe != null) {
      map['reframe'] = Variable<String>(reframe);
    }
    return map;
  }

  ThoughtCheckInsCompanion toCompanion(bool nullToAbsent) {
    return ThoughtCheckInsCompanion(
      date: Value(date),
      slot: Value(slot),
      pace: pace == null && nullToAbsent ? const Value.absent() : Value(pace),
      senses: senses == null && nullToAbsent
          ? const Value.absent()
          : Value(senses),
      thought: thought == null && nullToAbsent
          ? const Value.absent()
          : Value(thought),
      reframe: reframe == null && nullToAbsent
          ? const Value.absent()
          : Value(reframe),
    );
  }

  factory CheckInRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CheckInRow(
      date: serializer.fromJson<String>(json['date']),
      slot: serializer.fromJson<String>(json['slot']),
      pace: serializer.fromJson<String?>(json['pace']),
      senses: serializer.fromJson<String?>(json['senses']),
      thought: serializer.fromJson<String?>(json['thought']),
      reframe: serializer.fromJson<String?>(json['reframe']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'date': serializer.toJson<String>(date),
      'slot': serializer.toJson<String>(slot),
      'pace': serializer.toJson<String?>(pace),
      'senses': serializer.toJson<String?>(senses),
      'thought': serializer.toJson<String?>(thought),
      'reframe': serializer.toJson<String?>(reframe),
    };
  }

  CheckInRow copyWith({
    String? date,
    String? slot,
    Value<String?> pace = const Value.absent(),
    Value<String?> senses = const Value.absent(),
    Value<String?> thought = const Value.absent(),
    Value<String?> reframe = const Value.absent(),
  }) => CheckInRow(
    date: date ?? this.date,
    slot: slot ?? this.slot,
    pace: pace.present ? pace.value : this.pace,
    senses: senses.present ? senses.value : this.senses,
    thought: thought.present ? thought.value : this.thought,
    reframe: reframe.present ? reframe.value : this.reframe,
  );
  CheckInRow copyWithCompanion(ThoughtCheckInsCompanion data) {
    return CheckInRow(
      date: data.date.present ? data.date.value : this.date,
      slot: data.slot.present ? data.slot.value : this.slot,
      pace: data.pace.present ? data.pace.value : this.pace,
      senses: data.senses.present ? data.senses.value : this.senses,
      thought: data.thought.present ? data.thought.value : this.thought,
      reframe: data.reframe.present ? data.reframe.value : this.reframe,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CheckInRow(')
          ..write('date: $date, ')
          ..write('slot: $slot, ')
          ..write('pace: $pace, ')
          ..write('senses: $senses, ')
          ..write('thought: $thought, ')
          ..write('reframe: $reframe')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(date, slot, pace, senses, thought, reframe);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CheckInRow &&
          other.date == this.date &&
          other.slot == this.slot &&
          other.pace == this.pace &&
          other.senses == this.senses &&
          other.thought == this.thought &&
          other.reframe == this.reframe);
}

class ThoughtCheckInsCompanion extends UpdateCompanion<CheckInRow> {
  final Value<String> date;
  final Value<String> slot;
  final Value<String?> pace;
  final Value<String?> senses;
  final Value<String?> thought;
  final Value<String?> reframe;
  final Value<int> rowid;
  const ThoughtCheckInsCompanion({
    this.date = const Value.absent(),
    this.slot = const Value.absent(),
    this.pace = const Value.absent(),
    this.senses = const Value.absent(),
    this.thought = const Value.absent(),
    this.reframe = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ThoughtCheckInsCompanion.insert({
    required String date,
    required String slot,
    this.pace = const Value.absent(),
    this.senses = const Value.absent(),
    this.thought = const Value.absent(),
    this.reframe = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : date = Value(date),
       slot = Value(slot);
  static Insertable<CheckInRow> custom({
    Expression<String>? date,
    Expression<String>? slot,
    Expression<String>? pace,
    Expression<String>? senses,
    Expression<String>? thought,
    Expression<String>? reframe,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (date != null) 'date': date,
      if (slot != null) 'slot': slot,
      if (pace != null) 'pace': pace,
      if (senses != null) 'senses': senses,
      if (thought != null) 'thought': thought,
      if (reframe != null) 'reframe': reframe,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ThoughtCheckInsCompanion copyWith({
    Value<String>? date,
    Value<String>? slot,
    Value<String?>? pace,
    Value<String?>? senses,
    Value<String?>? thought,
    Value<String?>? reframe,
    Value<int>? rowid,
  }) {
    return ThoughtCheckInsCompanion(
      date: date ?? this.date,
      slot: slot ?? this.slot,
      pace: pace ?? this.pace,
      senses: senses ?? this.senses,
      thought: thought ?? this.thought,
      reframe: reframe ?? this.reframe,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (date.present) {
      map['date'] = Variable<String>(date.value);
    }
    if (slot.present) {
      map['slot'] = Variable<String>(slot.value);
    }
    if (pace.present) {
      map['pace'] = Variable<String>(pace.value);
    }
    if (senses.present) {
      map['senses'] = Variable<String>(senses.value);
    }
    if (thought.present) {
      map['thought'] = Variable<String>(thought.value);
    }
    if (reframe.present) {
      map['reframe'] = Variable<String>(reframe.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ThoughtCheckInsCompanion(')
          ..write('date: $date, ')
          ..write('slot: $slot, ')
          ..write('pace: $pace, ')
          ..write('senses: $senses, ')
          ..write('thought: $thought, ')
          ..write('reframe: $reframe, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $DiaryEntriesTable diaryEntries = $DiaryEntriesTable(this);
  late final $EntryTagsTable entryTags = $EntryTagsTable(this);
  late final $ThoughtCheckInsTable thoughtCheckIns = $ThoughtCheckInsTable(
    this,
  );
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    diaryEntries,
    entryTags,
    thoughtCheckIns,
  ];
  @override
  StreamQueryUpdateRules get streamUpdateRules => const StreamQueryUpdateRules([
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'diary_entries',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('entry_tags', kind: UpdateKind.delete)],
    ),
  ]);
}

typedef $$DiaryEntriesTableCreateCompanionBuilder =
    DiaryEntriesCompanion Function({
      required String date,
      Value<int?> bedMinute,
      Value<int?> wakeMinute,
      Value<String?> rested,
      Value<int> rowid,
    });
typedef $$DiaryEntriesTableUpdateCompanionBuilder =
    DiaryEntriesCompanion Function({
      Value<String> date,
      Value<int?> bedMinute,
      Value<int?> wakeMinute,
      Value<String?> rested,
      Value<int> rowid,
    });

final class $$DiaryEntriesTableReferences
    extends BaseReferences<_$AppDatabase, $DiaryEntriesTable, DiaryEntryRow> {
  $$DiaryEntriesTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$EntryTagsTable, List<EntryTagRow>>
  _entryTagsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.entryTags,
    aliasName: 'diary_entries__date__entry_tags__date',
  );

  $$EntryTagsTableProcessedTableManager get entryTagsRefs {
    final manager = $$EntryTagsTableTableManager(
      $_db,
      $_db.entryTags,
    ).filter((f) => f.date.date.sqlEquals($_itemColumn<String>('date')!));

    final cache = $_typedResult.readTableOrNull(_entryTagsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$DiaryEntriesTableFilterComposer
    extends Composer<_$AppDatabase, $DiaryEntriesTable> {
  $$DiaryEntriesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get date => $composableBuilder(
    column: $table.date,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get bedMinute => $composableBuilder(
    column: $table.bedMinute,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get wakeMinute => $composableBuilder(
    column: $table.wakeMinute,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get rested => $composableBuilder(
    column: $table.rested,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> entryTagsRefs(
    Expression<bool> Function($$EntryTagsTableFilterComposer f) f,
  ) {
    final $$EntryTagsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.date,
      referencedTable: $db.entryTags,
      getReferencedColumn: (t) => t.date,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$EntryTagsTableFilterComposer(
            $db: $db,
            $table: $db.entryTags,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$DiaryEntriesTableOrderingComposer
    extends Composer<_$AppDatabase, $DiaryEntriesTable> {
  $$DiaryEntriesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get date => $composableBuilder(
    column: $table.date,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get bedMinute => $composableBuilder(
    column: $table.bedMinute,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get wakeMinute => $composableBuilder(
    column: $table.wakeMinute,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get rested => $composableBuilder(
    column: $table.rested,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$DiaryEntriesTableAnnotationComposer
    extends Composer<_$AppDatabase, $DiaryEntriesTable> {
  $$DiaryEntriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get date =>
      $composableBuilder(column: $table.date, builder: (column) => column);

  GeneratedColumn<int> get bedMinute =>
      $composableBuilder(column: $table.bedMinute, builder: (column) => column);

  GeneratedColumn<int> get wakeMinute => $composableBuilder(
    column: $table.wakeMinute,
    builder: (column) => column,
  );

  GeneratedColumn<String> get rested =>
      $composableBuilder(column: $table.rested, builder: (column) => column);

  Expression<T> entryTagsRefs<T extends Object>(
    Expression<T> Function($$EntryTagsTableAnnotationComposer a) f,
  ) {
    final $$EntryTagsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.date,
      referencedTable: $db.entryTags,
      getReferencedColumn: (t) => t.date,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$EntryTagsTableAnnotationComposer(
            $db: $db,
            $table: $db.entryTags,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$DiaryEntriesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $DiaryEntriesTable,
          DiaryEntryRow,
          $$DiaryEntriesTableFilterComposer,
          $$DiaryEntriesTableOrderingComposer,
          $$DiaryEntriesTableAnnotationComposer,
          $$DiaryEntriesTableCreateCompanionBuilder,
          $$DiaryEntriesTableUpdateCompanionBuilder,
          (DiaryEntryRow, $$DiaryEntriesTableReferences),
          DiaryEntryRow,
          PrefetchHooks Function({bool entryTagsRefs})
        > {
  $$DiaryEntriesTableTableManager(_$AppDatabase db, $DiaryEntriesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$DiaryEntriesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$DiaryEntriesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$DiaryEntriesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> date = const Value.absent(),
                Value<int?> bedMinute = const Value.absent(),
                Value<int?> wakeMinute = const Value.absent(),
                Value<String?> rested = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => DiaryEntriesCompanion(
                date: date,
                bedMinute: bedMinute,
                wakeMinute: wakeMinute,
                rested: rested,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String date,
                Value<int?> bedMinute = const Value.absent(),
                Value<int?> wakeMinute = const Value.absent(),
                Value<String?> rested = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => DiaryEntriesCompanion.insert(
                date: date,
                bedMinute: bedMinute,
                wakeMinute: wakeMinute,
                rested: rested,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$DiaryEntriesTable, DiaryEntryRow>(table),
                  $$DiaryEntriesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({entryTagsRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [if (entryTagsRefs) db.entryTags],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (entryTagsRefs)
                    await $_getPrefetchedDataByColumns<
                      DiaryEntryRow,
                      $DiaryEntriesTable,
                      EntryTagRow,
                      $EntryTagsTable
                    >(
                      currentTable: table,
                      referencedTable: $$DiaryEntriesTableReferences
                          ._entryTagsRefsTable(db),
                      managerFromTypedResult: (p0) =>
                          $$DiaryEntriesTableReferences(
                            db,
                            table,
                            p0,
                          ).entryTagsRefs,
                      currentColumn: 'date',
                      referencedColumn: 'date',
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$DiaryEntriesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $DiaryEntriesTable,
      DiaryEntryRow,
      $$DiaryEntriesTableFilterComposer,
      $$DiaryEntriesTableOrderingComposer,
      $$DiaryEntriesTableAnnotationComposer,
      $$DiaryEntriesTableCreateCompanionBuilder,
      $$DiaryEntriesTableUpdateCompanionBuilder,
      (DiaryEntryRow, $$DiaryEntriesTableReferences),
      DiaryEntryRow,
      PrefetchHooks Function({bool entryTagsRefs})
    >;
typedef $$EntryTagsTableCreateCompanionBuilder =
    EntryTagsCompanion Function({
      required String date,
      required String tagId,
      Value<int> rowid,
    });
typedef $$EntryTagsTableUpdateCompanionBuilder =
    EntryTagsCompanion Function({
      Value<String> date,
      Value<String> tagId,
      Value<int> rowid,
    });

final class $$EntryTagsTableReferences
    extends BaseReferences<_$AppDatabase, $EntryTagsTable, EntryTagRow> {
  $$EntryTagsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $DiaryEntriesTable _dateTable(_$AppDatabase db) =>
      db.diaryEntries.createAlias('entry_tags__date__diary_entries__date');

  $$DiaryEntriesTableProcessedTableManager get date {
    final $_column = $_itemColumn<String>('date')!;

    final manager = $$DiaryEntriesTableTableManager(
      $_db,
      $_db.diaryEntries,
    ).filter((f) => f.date.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_dateTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$EntryTagsTableFilterComposer
    extends Composer<_$AppDatabase, $EntryTagsTable> {
  $$EntryTagsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get tagId => $composableBuilder(
    column: $table.tagId,
    builder: (column) => ColumnFilters(column),
  );

  $$DiaryEntriesTableFilterComposer get date {
    final $$DiaryEntriesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.date,
      referencedTable: $db.diaryEntries,
      getReferencedColumn: (t) => t.date,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DiaryEntriesTableFilterComposer(
            $db: $db,
            $table: $db.diaryEntries,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$EntryTagsTableOrderingComposer
    extends Composer<_$AppDatabase, $EntryTagsTable> {
  $$EntryTagsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get tagId => $composableBuilder(
    column: $table.tagId,
    builder: (column) => ColumnOrderings(column),
  );

  $$DiaryEntriesTableOrderingComposer get date {
    final $$DiaryEntriesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.date,
      referencedTable: $db.diaryEntries,
      getReferencedColumn: (t) => t.date,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DiaryEntriesTableOrderingComposer(
            $db: $db,
            $table: $db.diaryEntries,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$EntryTagsTableAnnotationComposer
    extends Composer<_$AppDatabase, $EntryTagsTable> {
  $$EntryTagsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get tagId =>
      $composableBuilder(column: $table.tagId, builder: (column) => column);

  $$DiaryEntriesTableAnnotationComposer get date {
    final $$DiaryEntriesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.date,
      referencedTable: $db.diaryEntries,
      getReferencedColumn: (t) => t.date,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DiaryEntriesTableAnnotationComposer(
            $db: $db,
            $table: $db.diaryEntries,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$EntryTagsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $EntryTagsTable,
          EntryTagRow,
          $$EntryTagsTableFilterComposer,
          $$EntryTagsTableOrderingComposer,
          $$EntryTagsTableAnnotationComposer,
          $$EntryTagsTableCreateCompanionBuilder,
          $$EntryTagsTableUpdateCompanionBuilder,
          (EntryTagRow, $$EntryTagsTableReferences),
          EntryTagRow,
          PrefetchHooks Function({bool date})
        > {
  $$EntryTagsTableTableManager(_$AppDatabase db, $EntryTagsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$EntryTagsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$EntryTagsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$EntryTagsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> date = const Value.absent(),
                Value<String> tagId = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => EntryTagsCompanion(date: date, tagId: tagId, rowid: rowid),
          createCompanionCallback:
              ({
                required String date,
                required String tagId,
                Value<int> rowid = const Value.absent(),
              }) => EntryTagsCompanion.insert(
                date: date,
                tagId: tagId,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$EntryTagsTable, EntryTagRow>(table),
                  $$EntryTagsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({date = false}) {
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
                    if (date) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.date,
                                referencedTable: $$EntryTagsTableReferences
                                    ._dateTable(db),
                                referencedColumn: $$EntryTagsTableReferences
                                    ._dateTable(db)
                                    .date,
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

typedef $$EntryTagsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $EntryTagsTable,
      EntryTagRow,
      $$EntryTagsTableFilterComposer,
      $$EntryTagsTableOrderingComposer,
      $$EntryTagsTableAnnotationComposer,
      $$EntryTagsTableCreateCompanionBuilder,
      $$EntryTagsTableUpdateCompanionBuilder,
      (EntryTagRow, $$EntryTagsTableReferences),
      EntryTagRow,
      PrefetchHooks Function({bool date})
    >;
typedef $$ThoughtCheckInsTableCreateCompanionBuilder =
    ThoughtCheckInsCompanion Function({
      required String date,
      required String slot,
      Value<String?> pace,
      Value<String?> senses,
      Value<String?> thought,
      Value<String?> reframe,
      Value<int> rowid,
    });
typedef $$ThoughtCheckInsTableUpdateCompanionBuilder =
    ThoughtCheckInsCompanion Function({
      Value<String> date,
      Value<String> slot,
      Value<String?> pace,
      Value<String?> senses,
      Value<String?> thought,
      Value<String?> reframe,
      Value<int> rowid,
    });

class $$ThoughtCheckInsTableFilterComposer
    extends Composer<_$AppDatabase, $ThoughtCheckInsTable> {
  $$ThoughtCheckInsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get date => $composableBuilder(
    column: $table.date,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get slot => $composableBuilder(
    column: $table.slot,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get pace => $composableBuilder(
    column: $table.pace,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get senses => $composableBuilder(
    column: $table.senses,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get thought => $composableBuilder(
    column: $table.thought,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get reframe => $composableBuilder(
    column: $table.reframe,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ThoughtCheckInsTableOrderingComposer
    extends Composer<_$AppDatabase, $ThoughtCheckInsTable> {
  $$ThoughtCheckInsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get date => $composableBuilder(
    column: $table.date,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get slot => $composableBuilder(
    column: $table.slot,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get pace => $composableBuilder(
    column: $table.pace,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get senses => $composableBuilder(
    column: $table.senses,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get thought => $composableBuilder(
    column: $table.thought,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get reframe => $composableBuilder(
    column: $table.reframe,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ThoughtCheckInsTableAnnotationComposer
    extends Composer<_$AppDatabase, $ThoughtCheckInsTable> {
  $$ThoughtCheckInsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get date =>
      $composableBuilder(column: $table.date, builder: (column) => column);

  GeneratedColumn<String> get slot =>
      $composableBuilder(column: $table.slot, builder: (column) => column);

  GeneratedColumn<String> get pace =>
      $composableBuilder(column: $table.pace, builder: (column) => column);

  GeneratedColumn<String> get senses =>
      $composableBuilder(column: $table.senses, builder: (column) => column);

  GeneratedColumn<String> get thought =>
      $composableBuilder(column: $table.thought, builder: (column) => column);

  GeneratedColumn<String> get reframe =>
      $composableBuilder(column: $table.reframe, builder: (column) => column);
}

class $$ThoughtCheckInsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ThoughtCheckInsTable,
          CheckInRow,
          $$ThoughtCheckInsTableFilterComposer,
          $$ThoughtCheckInsTableOrderingComposer,
          $$ThoughtCheckInsTableAnnotationComposer,
          $$ThoughtCheckInsTableCreateCompanionBuilder,
          $$ThoughtCheckInsTableUpdateCompanionBuilder,
          (
            CheckInRow,
            BaseReferences<_$AppDatabase, $ThoughtCheckInsTable, CheckInRow>,
          ),
          CheckInRow,
          PrefetchHooks Function()
        > {
  $$ThoughtCheckInsTableTableManager(
    _$AppDatabase db,
    $ThoughtCheckInsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ThoughtCheckInsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ThoughtCheckInsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ThoughtCheckInsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> date = const Value.absent(),
                Value<String> slot = const Value.absent(),
                Value<String?> pace = const Value.absent(),
                Value<String?> senses = const Value.absent(),
                Value<String?> thought = const Value.absent(),
                Value<String?> reframe = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ThoughtCheckInsCompanion(
                date: date,
                slot: slot,
                pace: pace,
                senses: senses,
                thought: thought,
                reframe: reframe,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String date,
                required String slot,
                Value<String?> pace = const Value.absent(),
                Value<String?> senses = const Value.absent(),
                Value<String?> thought = const Value.absent(),
                Value<String?> reframe = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ThoughtCheckInsCompanion.insert(
                date: date,
                slot: slot,
                pace: pace,
                senses: senses,
                thought: thought,
                reframe: reframe,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$ThoughtCheckInsTable, CheckInRow>(table),
                  BaseReferences<
                    _$AppDatabase,
                    $ThoughtCheckInsTable,
                    CheckInRow
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ThoughtCheckInsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ThoughtCheckInsTable,
      CheckInRow,
      $$ThoughtCheckInsTableFilterComposer,
      $$ThoughtCheckInsTableOrderingComposer,
      $$ThoughtCheckInsTableAnnotationComposer,
      $$ThoughtCheckInsTableCreateCompanionBuilder,
      $$ThoughtCheckInsTableUpdateCompanionBuilder,
      (
        CheckInRow,
        BaseReferences<_$AppDatabase, $ThoughtCheckInsTable, CheckInRow>,
      ),
      CheckInRow,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$DiaryEntriesTableTableManager get diaryEntries =>
      $$DiaryEntriesTableTableManager(_db, _db.diaryEntries);
  $$EntryTagsTableTableManager get entryTags =>
      $$EntryTagsTableTableManager(_db, _db.entryTags);
  $$ThoughtCheckInsTableTableManager get thoughtCheckIns =>
      $$ThoughtCheckInsTableTableManager(_db, _db.thoughtCheckIns);
}

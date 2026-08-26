// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $PoemsTable extends Poems with TableInfo<$PoemsTable, PoemRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PoemsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _authorMeta = const VerificationMeta('author');
  @override
  late final GeneratedColumn<String> author = GeneratedColumn<String>(
    'author',
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
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _dynastyMeta = const VerificationMeta(
    'dynasty',
  );
  @override
  late final GeneratedColumn<String> dynasty = GeneratedColumn<String>(
    'dynasty',
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
  static const VerificationMeta _paragraphsJsonMeta = const VerificationMeta(
    'paragraphsJson',
  );
  @override
  late final GeneratedColumn<String> paragraphsJson = GeneratedColumn<String>(
    'paragraphs_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _prefaceMeta = const VerificationMeta(
    'preface',
  );
  @override
  late final GeneratedColumn<String> preface = GeneratedColumn<String>(
    'preface',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _rhythmicMeta = const VerificationMeta(
    'rhythmic',
  );
  @override
  late final GeneratedColumn<String> rhythmic = GeneratedColumn<String>(
    'rhythmic',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _popularityMeta = const VerificationMeta(
    'popularity',
  );
  @override
  late final GeneratedColumn<double> popularity = GeneratedColumn<double>(
    'popularity',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _rawTextJsonMeta = const VerificationMeta(
    'rawTextJson',
  );
  @override
  late final GeneratedColumn<String> rawTextJson = GeneratedColumn<String>(
    'raw_text_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _tagsJsonMeta = const VerificationMeta(
    'tagsJson',
  );
  @override
  late final GeneratedColumn<String> tagsJson = GeneratedColumn<String>(
    'tags_json',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _sourceCollectionMeta = const VerificationMeta(
    'sourceCollection',
  );
  @override
  late final GeneratedColumn<String> sourceCollection = GeneratedColumn<String>(
    'source_collection',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    author,
    title,
    dynasty,
    type,
    paragraphsJson,
    preface,
    rhythmic,
    popularity,
    rawTextJson,
    tagsJson,
    sourceCollection,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'poems';
  @override
  VerificationContext validateIntegrity(
    Insertable<PoemRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('author')) {
      context.handle(
        _authorMeta,
        author.isAcceptableOrUnknown(data['author']!, _authorMeta),
      );
    } else if (isInserting) {
      context.missing(_authorMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    }
    if (data.containsKey('dynasty')) {
      context.handle(
        _dynastyMeta,
        dynasty.isAcceptableOrUnknown(data['dynasty']!, _dynastyMeta),
      );
    } else if (isInserting) {
      context.missing(_dynastyMeta);
    }
    if (data.containsKey('type')) {
      context.handle(
        _typeMeta,
        type.isAcceptableOrUnknown(data['type']!, _typeMeta),
      );
    } else if (isInserting) {
      context.missing(_typeMeta);
    }
    if (data.containsKey('paragraphs_json')) {
      context.handle(
        _paragraphsJsonMeta,
        paragraphsJson.isAcceptableOrUnknown(
          data['paragraphs_json']!,
          _paragraphsJsonMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_paragraphsJsonMeta);
    }
    if (data.containsKey('preface')) {
      context.handle(
        _prefaceMeta,
        preface.isAcceptableOrUnknown(data['preface']!, _prefaceMeta),
      );
    }
    if (data.containsKey('rhythmic')) {
      context.handle(
        _rhythmicMeta,
        rhythmic.isAcceptableOrUnknown(data['rhythmic']!, _rhythmicMeta),
      );
    }
    if (data.containsKey('popularity')) {
      context.handle(
        _popularityMeta,
        popularity.isAcceptableOrUnknown(data['popularity']!, _popularityMeta),
      );
    }
    if (data.containsKey('raw_text_json')) {
      context.handle(
        _rawTextJsonMeta,
        rawTextJson.isAcceptableOrUnknown(
          data['raw_text_json']!,
          _rawTextJsonMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_rawTextJsonMeta);
    }
    if (data.containsKey('tags_json')) {
      context.handle(
        _tagsJsonMeta,
        tagsJson.isAcceptableOrUnknown(data['tags_json']!, _tagsJsonMeta),
      );
    }
    if (data.containsKey('source_collection')) {
      context.handle(
        _sourceCollectionMeta,
        sourceCollection.isAcceptableOrUnknown(
          data['source_collection']!,
          _sourceCollectionMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_sourceCollectionMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  PoemRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PoemRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      author: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}author'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      ),
      dynasty: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}dynasty'],
      )!,
      type: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}type'],
      )!,
      paragraphsJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}paragraphs_json'],
      )!,
      preface: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}preface'],
      ),
      rhythmic: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}rhythmic'],
      ),
      popularity: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}popularity'],
      ),
      rawTextJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}raw_text_json'],
      )!,
      tagsJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}tags_json'],
      ),
      sourceCollection: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source_collection'],
      )!,
    );
  }

  @override
  $PoemsTable createAlias(String alias) {
    return $PoemsTable(attachedDatabase, alias);
  }
}

class PoemRow extends DataClass implements Insertable<PoemRow> {
  /// 内容寻址 ID(32 位小写 hex),由数据包下发
  final String id;
  final String author;

  /// 词类记录无题 → 显式 null(UI 层用词牌呈现)
  final String? title;
  final String dynasty;

  /// 大类: shi / ci(v1 只到这两级)
  final String type;

  /// 简体正文段落数组(JSON 数组序列化)
  final String paragraphsJson;

  /// 上游实测无小序数据,v1 恒为 null;字段保留作契约
  final String? preface;

  /// 词牌(仅词有)
  final String? rhythmic;

  /// 归一热度 log10 和,3 位小数;无 rank 数据 → null
  final double? popularity;

  /// 转换前原文留档(JSON 数组序列化,与 paragraphs_json 平行等长)
  final String rawTextJson;

  /// 上游稀疏题材标签(JSON 数组序列化,无则 null)
  final String? tagsJson;
  final String sourceCollection;
  const PoemRow({
    required this.id,
    required this.author,
    this.title,
    required this.dynasty,
    required this.type,
    required this.paragraphsJson,
    this.preface,
    this.rhythmic,
    this.popularity,
    required this.rawTextJson,
    this.tagsJson,
    required this.sourceCollection,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['author'] = Variable<String>(author);
    if (!nullToAbsent || title != null) {
      map['title'] = Variable<String>(title);
    }
    map['dynasty'] = Variable<String>(dynasty);
    map['type'] = Variable<String>(type);
    map['paragraphs_json'] = Variable<String>(paragraphsJson);
    if (!nullToAbsent || preface != null) {
      map['preface'] = Variable<String>(preface);
    }
    if (!nullToAbsent || rhythmic != null) {
      map['rhythmic'] = Variable<String>(rhythmic);
    }
    if (!nullToAbsent || popularity != null) {
      map['popularity'] = Variable<double>(popularity);
    }
    map['raw_text_json'] = Variable<String>(rawTextJson);
    if (!nullToAbsent || tagsJson != null) {
      map['tags_json'] = Variable<String>(tagsJson);
    }
    map['source_collection'] = Variable<String>(sourceCollection);
    return map;
  }

  PoemsCompanion toCompanion(bool nullToAbsent) {
    return PoemsCompanion(
      id: Value(id),
      author: Value(author),
      title: title == null && nullToAbsent
          ? const Value.absent()
          : Value(title),
      dynasty: Value(dynasty),
      type: Value(type),
      paragraphsJson: Value(paragraphsJson),
      preface: preface == null && nullToAbsent
          ? const Value.absent()
          : Value(preface),
      rhythmic: rhythmic == null && nullToAbsent
          ? const Value.absent()
          : Value(rhythmic),
      popularity: popularity == null && nullToAbsent
          ? const Value.absent()
          : Value(popularity),
      rawTextJson: Value(rawTextJson),
      tagsJson: tagsJson == null && nullToAbsent
          ? const Value.absent()
          : Value(tagsJson),
      sourceCollection: Value(sourceCollection),
    );
  }

  factory PoemRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PoemRow(
      id: serializer.fromJson<String>(json['id']),
      author: serializer.fromJson<String>(json['author']),
      title: serializer.fromJson<String?>(json['title']),
      dynasty: serializer.fromJson<String>(json['dynasty']),
      type: serializer.fromJson<String>(json['type']),
      paragraphsJson: serializer.fromJson<String>(json['paragraphsJson']),
      preface: serializer.fromJson<String?>(json['preface']),
      rhythmic: serializer.fromJson<String?>(json['rhythmic']),
      popularity: serializer.fromJson<double?>(json['popularity']),
      rawTextJson: serializer.fromJson<String>(json['rawTextJson']),
      tagsJson: serializer.fromJson<String?>(json['tagsJson']),
      sourceCollection: serializer.fromJson<String>(json['sourceCollection']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'author': serializer.toJson<String>(author),
      'title': serializer.toJson<String?>(title),
      'dynasty': serializer.toJson<String>(dynasty),
      'type': serializer.toJson<String>(type),
      'paragraphsJson': serializer.toJson<String>(paragraphsJson),
      'preface': serializer.toJson<String?>(preface),
      'rhythmic': serializer.toJson<String?>(rhythmic),
      'popularity': serializer.toJson<double?>(popularity),
      'rawTextJson': serializer.toJson<String>(rawTextJson),
      'tagsJson': serializer.toJson<String?>(tagsJson),
      'sourceCollection': serializer.toJson<String>(sourceCollection),
    };
  }

  PoemRow copyWith({
    String? id,
    String? author,
    Value<String?> title = const Value.absent(),
    String? dynasty,
    String? type,
    String? paragraphsJson,
    Value<String?> preface = const Value.absent(),
    Value<String?> rhythmic = const Value.absent(),
    Value<double?> popularity = const Value.absent(),
    String? rawTextJson,
    Value<String?> tagsJson = const Value.absent(),
    String? sourceCollection,
  }) => PoemRow(
    id: id ?? this.id,
    author: author ?? this.author,
    title: title.present ? title.value : this.title,
    dynasty: dynasty ?? this.dynasty,
    type: type ?? this.type,
    paragraphsJson: paragraphsJson ?? this.paragraphsJson,
    preface: preface.present ? preface.value : this.preface,
    rhythmic: rhythmic.present ? rhythmic.value : this.rhythmic,
    popularity: popularity.present ? popularity.value : this.popularity,
    rawTextJson: rawTextJson ?? this.rawTextJson,
    tagsJson: tagsJson.present ? tagsJson.value : this.tagsJson,
    sourceCollection: sourceCollection ?? this.sourceCollection,
  );
  PoemRow copyWithCompanion(PoemsCompanion data) {
    return PoemRow(
      id: data.id.present ? data.id.value : this.id,
      author: data.author.present ? data.author.value : this.author,
      title: data.title.present ? data.title.value : this.title,
      dynasty: data.dynasty.present ? data.dynasty.value : this.dynasty,
      type: data.type.present ? data.type.value : this.type,
      paragraphsJson: data.paragraphsJson.present
          ? data.paragraphsJson.value
          : this.paragraphsJson,
      preface: data.preface.present ? data.preface.value : this.preface,
      rhythmic: data.rhythmic.present ? data.rhythmic.value : this.rhythmic,
      popularity: data.popularity.present
          ? data.popularity.value
          : this.popularity,
      rawTextJson: data.rawTextJson.present
          ? data.rawTextJson.value
          : this.rawTextJson,
      tagsJson: data.tagsJson.present ? data.tagsJson.value : this.tagsJson,
      sourceCollection: data.sourceCollection.present
          ? data.sourceCollection.value
          : this.sourceCollection,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PoemRow(')
          ..write('id: $id, ')
          ..write('author: $author, ')
          ..write('title: $title, ')
          ..write('dynasty: $dynasty, ')
          ..write('type: $type, ')
          ..write('paragraphsJson: $paragraphsJson, ')
          ..write('preface: $preface, ')
          ..write('rhythmic: $rhythmic, ')
          ..write('popularity: $popularity, ')
          ..write('rawTextJson: $rawTextJson, ')
          ..write('tagsJson: $tagsJson, ')
          ..write('sourceCollection: $sourceCollection')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    author,
    title,
    dynasty,
    type,
    paragraphsJson,
    preface,
    rhythmic,
    popularity,
    rawTextJson,
    tagsJson,
    sourceCollection,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PoemRow &&
          other.id == this.id &&
          other.author == this.author &&
          other.title == this.title &&
          other.dynasty == this.dynasty &&
          other.type == this.type &&
          other.paragraphsJson == this.paragraphsJson &&
          other.preface == this.preface &&
          other.rhythmic == this.rhythmic &&
          other.popularity == this.popularity &&
          other.rawTextJson == this.rawTextJson &&
          other.tagsJson == this.tagsJson &&
          other.sourceCollection == this.sourceCollection);
}

class PoemsCompanion extends UpdateCompanion<PoemRow> {
  final Value<String> id;
  final Value<String> author;
  final Value<String?> title;
  final Value<String> dynasty;
  final Value<String> type;
  final Value<String> paragraphsJson;
  final Value<String?> preface;
  final Value<String?> rhythmic;
  final Value<double?> popularity;
  final Value<String> rawTextJson;
  final Value<String?> tagsJson;
  final Value<String> sourceCollection;
  final Value<int> rowid;
  const PoemsCompanion({
    this.id = const Value.absent(),
    this.author = const Value.absent(),
    this.title = const Value.absent(),
    this.dynasty = const Value.absent(),
    this.type = const Value.absent(),
    this.paragraphsJson = const Value.absent(),
    this.preface = const Value.absent(),
    this.rhythmic = const Value.absent(),
    this.popularity = const Value.absent(),
    this.rawTextJson = const Value.absent(),
    this.tagsJson = const Value.absent(),
    this.sourceCollection = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  PoemsCompanion.insert({
    required String id,
    required String author,
    this.title = const Value.absent(),
    required String dynasty,
    required String type,
    required String paragraphsJson,
    this.preface = const Value.absent(),
    this.rhythmic = const Value.absent(),
    this.popularity = const Value.absent(),
    required String rawTextJson,
    this.tagsJson = const Value.absent(),
    required String sourceCollection,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       author = Value(author),
       dynasty = Value(dynasty),
       type = Value(type),
       paragraphsJson = Value(paragraphsJson),
       rawTextJson = Value(rawTextJson),
       sourceCollection = Value(sourceCollection);
  static Insertable<PoemRow> custom({
    Expression<String>? id,
    Expression<String>? author,
    Expression<String>? title,
    Expression<String>? dynasty,
    Expression<String>? type,
    Expression<String>? paragraphsJson,
    Expression<String>? preface,
    Expression<String>? rhythmic,
    Expression<double>? popularity,
    Expression<String>? rawTextJson,
    Expression<String>? tagsJson,
    Expression<String>? sourceCollection,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (author != null) 'author': author,
      if (title != null) 'title': title,
      if (dynasty != null) 'dynasty': dynasty,
      if (type != null) 'type': type,
      if (paragraphsJson != null) 'paragraphs_json': paragraphsJson,
      if (preface != null) 'preface': preface,
      if (rhythmic != null) 'rhythmic': rhythmic,
      if (popularity != null) 'popularity': popularity,
      if (rawTextJson != null) 'raw_text_json': rawTextJson,
      if (tagsJson != null) 'tags_json': tagsJson,
      if (sourceCollection != null) 'source_collection': sourceCollection,
      if (rowid != null) 'rowid': rowid,
    });
  }

  PoemsCompanion copyWith({
    Value<String>? id,
    Value<String>? author,
    Value<String?>? title,
    Value<String>? dynasty,
    Value<String>? type,
    Value<String>? paragraphsJson,
    Value<String?>? preface,
    Value<String?>? rhythmic,
    Value<double?>? popularity,
    Value<String>? rawTextJson,
    Value<String?>? tagsJson,
    Value<String>? sourceCollection,
    Value<int>? rowid,
  }) {
    return PoemsCompanion(
      id: id ?? this.id,
      author: author ?? this.author,
      title: title ?? this.title,
      dynasty: dynasty ?? this.dynasty,
      type: type ?? this.type,
      paragraphsJson: paragraphsJson ?? this.paragraphsJson,
      preface: preface ?? this.preface,
      rhythmic: rhythmic ?? this.rhythmic,
      popularity: popularity ?? this.popularity,
      rawTextJson: rawTextJson ?? this.rawTextJson,
      tagsJson: tagsJson ?? this.tagsJson,
      sourceCollection: sourceCollection ?? this.sourceCollection,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (author.present) {
      map['author'] = Variable<String>(author.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (dynasty.present) {
      map['dynasty'] = Variable<String>(dynasty.value);
    }
    if (type.present) {
      map['type'] = Variable<String>(type.value);
    }
    if (paragraphsJson.present) {
      map['paragraphs_json'] = Variable<String>(paragraphsJson.value);
    }
    if (preface.present) {
      map['preface'] = Variable<String>(preface.value);
    }
    if (rhythmic.present) {
      map['rhythmic'] = Variable<String>(rhythmic.value);
    }
    if (popularity.present) {
      map['popularity'] = Variable<double>(popularity.value);
    }
    if (rawTextJson.present) {
      map['raw_text_json'] = Variable<String>(rawTextJson.value);
    }
    if (tagsJson.present) {
      map['tags_json'] = Variable<String>(tagsJson.value);
    }
    if (sourceCollection.present) {
      map['source_collection'] = Variable<String>(sourceCollection.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PoemsCompanion(')
          ..write('id: $id, ')
          ..write('author: $author, ')
          ..write('title: $title, ')
          ..write('dynasty: $dynasty, ')
          ..write('type: $type, ')
          ..write('paragraphsJson: $paragraphsJson, ')
          ..write('preface: $preface, ')
          ..write('rhythmic: $rhythmic, ')
          ..write('popularity: $popularity, ')
          ..write('rawTextJson: $rawTextJson, ')
          ..write('tagsJson: $tagsJson, ')
          ..write('sourceCollection: $sourceCollection, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $PoemsTable poems = $PoemsTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [poems];
}

typedef $$PoemsTableCreateCompanionBuilder =
    PoemsCompanion Function({
      required String id,
      required String author,
      Value<String?> title,
      required String dynasty,
      required String type,
      required String paragraphsJson,
      Value<String?> preface,
      Value<String?> rhythmic,
      Value<double?> popularity,
      required String rawTextJson,
      Value<String?> tagsJson,
      required String sourceCollection,
      Value<int> rowid,
    });
typedef $$PoemsTableUpdateCompanionBuilder =
    PoemsCompanion Function({
      Value<String> id,
      Value<String> author,
      Value<String?> title,
      Value<String> dynasty,
      Value<String> type,
      Value<String> paragraphsJson,
      Value<String?> preface,
      Value<String?> rhythmic,
      Value<double?> popularity,
      Value<String> rawTextJson,
      Value<String?> tagsJson,
      Value<String> sourceCollection,
      Value<int> rowid,
    });

class $$PoemsTableFilterComposer extends Composer<_$AppDatabase, $PoemsTable> {
  $$PoemsTableFilterComposer({
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

  ColumnFilters<String> get author => $composableBuilder(
    column: $table.author,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get dynasty => $composableBuilder(
    column: $table.dynasty,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get paragraphsJson => $composableBuilder(
    column: $table.paragraphsJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get preface => $composableBuilder(
    column: $table.preface,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get rhythmic => $composableBuilder(
    column: $table.rhythmic,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get popularity => $composableBuilder(
    column: $table.popularity,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get rawTextJson => $composableBuilder(
    column: $table.rawTextJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get tagsJson => $composableBuilder(
    column: $table.tagsJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sourceCollection => $composableBuilder(
    column: $table.sourceCollection,
    builder: (column) => ColumnFilters(column),
  );
}

class $$PoemsTableOrderingComposer
    extends Composer<_$AppDatabase, $PoemsTable> {
  $$PoemsTableOrderingComposer({
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

  ColumnOrderings<String> get author => $composableBuilder(
    column: $table.author,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get dynasty => $composableBuilder(
    column: $table.dynasty,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get paragraphsJson => $composableBuilder(
    column: $table.paragraphsJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get preface => $composableBuilder(
    column: $table.preface,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get rhythmic => $composableBuilder(
    column: $table.rhythmic,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get popularity => $composableBuilder(
    column: $table.popularity,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get rawTextJson => $composableBuilder(
    column: $table.rawTextJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get tagsJson => $composableBuilder(
    column: $table.tagsJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sourceCollection => $composableBuilder(
    column: $table.sourceCollection,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$PoemsTableAnnotationComposer
    extends Composer<_$AppDatabase, $PoemsTable> {
  $$PoemsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get author =>
      $composableBuilder(column: $table.author, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get dynasty =>
      $composableBuilder(column: $table.dynasty, builder: (column) => column);

  GeneratedColumn<String> get type =>
      $composableBuilder(column: $table.type, builder: (column) => column);

  GeneratedColumn<String> get paragraphsJson => $composableBuilder(
    column: $table.paragraphsJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get preface =>
      $composableBuilder(column: $table.preface, builder: (column) => column);

  GeneratedColumn<String> get rhythmic =>
      $composableBuilder(column: $table.rhythmic, builder: (column) => column);

  GeneratedColumn<double> get popularity => $composableBuilder(
    column: $table.popularity,
    builder: (column) => column,
  );

  GeneratedColumn<String> get rawTextJson => $composableBuilder(
    column: $table.rawTextJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get tagsJson =>
      $composableBuilder(column: $table.tagsJson, builder: (column) => column);

  GeneratedColumn<String> get sourceCollection => $composableBuilder(
    column: $table.sourceCollection,
    builder: (column) => column,
  );
}

class $$PoemsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $PoemsTable,
          PoemRow,
          $$PoemsTableFilterComposer,
          $$PoemsTableOrderingComposer,
          $$PoemsTableAnnotationComposer,
          $$PoemsTableCreateCompanionBuilder,
          $$PoemsTableUpdateCompanionBuilder,
          (PoemRow, BaseReferences<_$AppDatabase, $PoemsTable, PoemRow>),
          PoemRow,
          PrefetchHooks Function()
        > {
  $$PoemsTableTableManager(_$AppDatabase db, $PoemsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PoemsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PoemsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PoemsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> author = const Value.absent(),
                Value<String?> title = const Value.absent(),
                Value<String> dynasty = const Value.absent(),
                Value<String> type = const Value.absent(),
                Value<String> paragraphsJson = const Value.absent(),
                Value<String?> preface = const Value.absent(),
                Value<String?> rhythmic = const Value.absent(),
                Value<double?> popularity = const Value.absent(),
                Value<String> rawTextJson = const Value.absent(),
                Value<String?> tagsJson = const Value.absent(),
                Value<String> sourceCollection = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PoemsCompanion(
                id: id,
                author: author,
                title: title,
                dynasty: dynasty,
                type: type,
                paragraphsJson: paragraphsJson,
                preface: preface,
                rhythmic: rhythmic,
                popularity: popularity,
                rawTextJson: rawTextJson,
                tagsJson: tagsJson,
                sourceCollection: sourceCollection,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String author,
                Value<String?> title = const Value.absent(),
                required String dynasty,
                required String type,
                required String paragraphsJson,
                Value<String?> preface = const Value.absent(),
                Value<String?> rhythmic = const Value.absent(),
                Value<double?> popularity = const Value.absent(),
                required String rawTextJson,
                Value<String?> tagsJson = const Value.absent(),
                required String sourceCollection,
                Value<int> rowid = const Value.absent(),
              }) => PoemsCompanion.insert(
                id: id,
                author: author,
                title: title,
                dynasty: dynasty,
                type: type,
                paragraphsJson: paragraphsJson,
                preface: preface,
                rhythmic: rhythmic,
                popularity: popularity,
                rawTextJson: rawTextJson,
                tagsJson: tagsJson,
                sourceCollection: sourceCollection,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$PoemsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $PoemsTable,
      PoemRow,
      $$PoemsTableFilterComposer,
      $$PoemsTableOrderingComposer,
      $$PoemsTableAnnotationComposer,
      $$PoemsTableCreateCompanionBuilder,
      $$PoemsTableUpdateCompanionBuilder,
      (PoemRow, BaseReferences<_$AppDatabase, $PoemsTable, PoemRow>),
      PoemRow,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$PoemsTableTableManager get poems =>
      $$PoemsTableTableManager(_db, _db.poems);
}

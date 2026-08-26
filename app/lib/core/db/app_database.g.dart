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

class $NotebookEntriesTable extends NotebookEntries
    with TableInfo<$NotebookEntriesTable, NotebookEntryRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $NotebookEntriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _poemIdMeta = const VerificationMeta('poemId');
  @override
  late final GeneratedColumn<String> poemId = GeneratedColumn<String>(
    'poem_id',
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
  static const VerificationMeta _targetMeta = const VerificationMeta('target');
  @override
  late final GeneratedColumn<String> target = GeneratedColumn<String>(
    'target',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _contentJsonMeta = const VerificationMeta(
    'contentJson',
  );
  @override
  late final GeneratedColumn<String> contentJson = GeneratedColumn<String>(
    'content_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _personaMeta = const VerificationMeta(
    'persona',
  );
  @override
  late final GeneratedColumn<String> persona = GeneratedColumn<String>(
    'persona',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
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
    poemId,
    kind,
    target,
    contentJson,
    persona,
    userEdited,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'notebook_entries';
  @override
  VerificationContext validateIntegrity(
    Insertable<NotebookEntryRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('poem_id')) {
      context.handle(
        _poemIdMeta,
        poemId.isAcceptableOrUnknown(data['poem_id']!, _poemIdMeta),
      );
    } else if (isInserting) {
      context.missing(_poemIdMeta);
    }
    if (data.containsKey('kind')) {
      context.handle(
        _kindMeta,
        kind.isAcceptableOrUnknown(data['kind']!, _kindMeta),
      );
    } else if (isInserting) {
      context.missing(_kindMeta);
    }
    if (data.containsKey('target')) {
      context.handle(
        _targetMeta,
        target.isAcceptableOrUnknown(data['target']!, _targetMeta),
      );
    }
    if (data.containsKey('content_json')) {
      context.handle(
        _contentJsonMeta,
        contentJson.isAcceptableOrUnknown(
          data['content_json']!,
          _contentJsonMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_contentJsonMeta);
    }
    if (data.containsKey('persona')) {
      context.handle(
        _personaMeta,
        persona.isAcceptableOrUnknown(data['persona']!, _personaMeta),
      );
    } else if (isInserting) {
      context.missing(_personaMeta);
    }
    if (data.containsKey('user_edited')) {
      context.handle(
        _userEditedMeta,
        userEdited.isAcceptableOrUnknown(data['user_edited']!, _userEditedMeta),
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
  NotebookEntryRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return NotebookEntryRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      poemId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}poem_id'],
      )!,
      kind: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}kind'],
      )!,
      target: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}target'],
      ),
      contentJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}content_json'],
      )!,
      persona: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}persona'],
      )!,
      userEdited: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}user_edited'],
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
  $NotebookEntriesTable createAlias(String alias) {
    return $NotebookEntriesTable(attachedDatabase, alias);
  }
}

class NotebookEntryRow extends DataClass
    implements Insertable<NotebookEntryRow> {
  /// sha256("$poemId|$kind|$target") —— 由 NotebookIds.entryId 计算
  final String id;
  final String poemId;

  /// line_note / essay / chat_turn
  final String kind;

  /// line_note=行索引字符串; chat_turn=问题摘要; essay=null
  final String? target;

  /// 结构化内容 JSON(形态随 kind 而异)
  final String contentJson;

  /// 生成时的人格(条目不随后续切换人格而变)
  final String persona;
  final bool userEdited;

  /// 毫秒时间戳(epoch)
  final int createdAt;
  final int updatedAt;
  const NotebookEntryRow({
    required this.id,
    required this.poemId,
    required this.kind,
    this.target,
    required this.contentJson,
    required this.persona,
    required this.userEdited,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['poem_id'] = Variable<String>(poemId);
    map['kind'] = Variable<String>(kind);
    if (!nullToAbsent || target != null) {
      map['target'] = Variable<String>(target);
    }
    map['content_json'] = Variable<String>(contentJson);
    map['persona'] = Variable<String>(persona);
    map['user_edited'] = Variable<bool>(userEdited);
    map['created_at'] = Variable<int>(createdAt);
    map['updated_at'] = Variable<int>(updatedAt);
    return map;
  }

  NotebookEntriesCompanion toCompanion(bool nullToAbsent) {
    return NotebookEntriesCompanion(
      id: Value(id),
      poemId: Value(poemId),
      kind: Value(kind),
      target: target == null && nullToAbsent
          ? const Value.absent()
          : Value(target),
      contentJson: Value(contentJson),
      persona: Value(persona),
      userEdited: Value(userEdited),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory NotebookEntryRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return NotebookEntryRow(
      id: serializer.fromJson<String>(json['id']),
      poemId: serializer.fromJson<String>(json['poemId']),
      kind: serializer.fromJson<String>(json['kind']),
      target: serializer.fromJson<String?>(json['target']),
      contentJson: serializer.fromJson<String>(json['contentJson']),
      persona: serializer.fromJson<String>(json['persona']),
      userEdited: serializer.fromJson<bool>(json['userEdited']),
      createdAt: serializer.fromJson<int>(json['createdAt']),
      updatedAt: serializer.fromJson<int>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'poemId': serializer.toJson<String>(poemId),
      'kind': serializer.toJson<String>(kind),
      'target': serializer.toJson<String?>(target),
      'contentJson': serializer.toJson<String>(contentJson),
      'persona': serializer.toJson<String>(persona),
      'userEdited': serializer.toJson<bool>(userEdited),
      'createdAt': serializer.toJson<int>(createdAt),
      'updatedAt': serializer.toJson<int>(updatedAt),
    };
  }

  NotebookEntryRow copyWith({
    String? id,
    String? poemId,
    String? kind,
    Value<String?> target = const Value.absent(),
    String? contentJson,
    String? persona,
    bool? userEdited,
    int? createdAt,
    int? updatedAt,
  }) => NotebookEntryRow(
    id: id ?? this.id,
    poemId: poemId ?? this.poemId,
    kind: kind ?? this.kind,
    target: target.present ? target.value : this.target,
    contentJson: contentJson ?? this.contentJson,
    persona: persona ?? this.persona,
    userEdited: userEdited ?? this.userEdited,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  NotebookEntryRow copyWithCompanion(NotebookEntriesCompanion data) {
    return NotebookEntryRow(
      id: data.id.present ? data.id.value : this.id,
      poemId: data.poemId.present ? data.poemId.value : this.poemId,
      kind: data.kind.present ? data.kind.value : this.kind,
      target: data.target.present ? data.target.value : this.target,
      contentJson: data.contentJson.present
          ? data.contentJson.value
          : this.contentJson,
      persona: data.persona.present ? data.persona.value : this.persona,
      userEdited: data.userEdited.present
          ? data.userEdited.value
          : this.userEdited,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('NotebookEntryRow(')
          ..write('id: $id, ')
          ..write('poemId: $poemId, ')
          ..write('kind: $kind, ')
          ..write('target: $target, ')
          ..write('contentJson: $contentJson, ')
          ..write('persona: $persona, ')
          ..write('userEdited: $userEdited, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    poemId,
    kind,
    target,
    contentJson,
    persona,
    userEdited,
    createdAt,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is NotebookEntryRow &&
          other.id == this.id &&
          other.poemId == this.poemId &&
          other.kind == this.kind &&
          other.target == this.target &&
          other.contentJson == this.contentJson &&
          other.persona == this.persona &&
          other.userEdited == this.userEdited &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class NotebookEntriesCompanion extends UpdateCompanion<NotebookEntryRow> {
  final Value<String> id;
  final Value<String> poemId;
  final Value<String> kind;
  final Value<String?> target;
  final Value<String> contentJson;
  final Value<String> persona;
  final Value<bool> userEdited;
  final Value<int> createdAt;
  final Value<int> updatedAt;
  final Value<int> rowid;
  const NotebookEntriesCompanion({
    this.id = const Value.absent(),
    this.poemId = const Value.absent(),
    this.kind = const Value.absent(),
    this.target = const Value.absent(),
    this.contentJson = const Value.absent(),
    this.persona = const Value.absent(),
    this.userEdited = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  NotebookEntriesCompanion.insert({
    required String id,
    required String poemId,
    required String kind,
    this.target = const Value.absent(),
    required String contentJson,
    required String persona,
    this.userEdited = const Value.absent(),
    required int createdAt,
    required int updatedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       poemId = Value(poemId),
       kind = Value(kind),
       contentJson = Value(contentJson),
       persona = Value(persona),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<NotebookEntryRow> custom({
    Expression<String>? id,
    Expression<String>? poemId,
    Expression<String>? kind,
    Expression<String>? target,
    Expression<String>? contentJson,
    Expression<String>? persona,
    Expression<bool>? userEdited,
    Expression<int>? createdAt,
    Expression<int>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (poemId != null) 'poem_id': poemId,
      if (kind != null) 'kind': kind,
      if (target != null) 'target': target,
      if (contentJson != null) 'content_json': contentJson,
      if (persona != null) 'persona': persona,
      if (userEdited != null) 'user_edited': userEdited,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  NotebookEntriesCompanion copyWith({
    Value<String>? id,
    Value<String>? poemId,
    Value<String>? kind,
    Value<String?>? target,
    Value<String>? contentJson,
    Value<String>? persona,
    Value<bool>? userEdited,
    Value<int>? createdAt,
    Value<int>? updatedAt,
    Value<int>? rowid,
  }) {
    return NotebookEntriesCompanion(
      id: id ?? this.id,
      poemId: poemId ?? this.poemId,
      kind: kind ?? this.kind,
      target: target ?? this.target,
      contentJson: contentJson ?? this.contentJson,
      persona: persona ?? this.persona,
      userEdited: userEdited ?? this.userEdited,
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
    if (poemId.present) {
      map['poem_id'] = Variable<String>(poemId.value);
    }
    if (kind.present) {
      map['kind'] = Variable<String>(kind.value);
    }
    if (target.present) {
      map['target'] = Variable<String>(target.value);
    }
    if (contentJson.present) {
      map['content_json'] = Variable<String>(contentJson.value);
    }
    if (persona.present) {
      map['persona'] = Variable<String>(persona.value);
    }
    if (userEdited.present) {
      map['user_edited'] = Variable<bool>(userEdited.value);
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
    return (StringBuffer('NotebookEntriesCompanion(')
          ..write('id: $id, ')
          ..write('poemId: $poemId, ')
          ..write('kind: $kind, ')
          ..write('target: $target, ')
          ..write('contentJson: $contentJson, ')
          ..write('persona: $persona, ')
          ..write('userEdited: $userEdited, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $FavoritesTable extends Favorites
    with TableInfo<$FavoritesTable, FavoriteRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $FavoritesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _poemIdMeta = const VerificationMeta('poemId');
  @override
  late final GeneratedColumn<String> poemId = GeneratedColumn<String>(
    'poem_id',
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
  List<GeneratedColumn> get $columns => [poemId, createdAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'favorites';
  @override
  VerificationContext validateIntegrity(
    Insertable<FavoriteRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('poem_id')) {
      context.handle(
        _poemIdMeta,
        poemId.isAcceptableOrUnknown(data['poem_id']!, _poemIdMeta),
      );
    } else if (isInserting) {
      context.missing(_poemIdMeta);
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
  Set<GeneratedColumn> get $primaryKey => {poemId};
  @override
  FavoriteRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return FavoriteRow(
      poemId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}poem_id'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $FavoritesTable createAlias(String alias) {
    return $FavoritesTable(attachedDatabase, alias);
  }
}

class FavoriteRow extends DataClass implements Insertable<FavoriteRow> {
  final String poemId;
  final int createdAt;
  const FavoriteRow({required this.poemId, required this.createdAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['poem_id'] = Variable<String>(poemId);
    map['created_at'] = Variable<int>(createdAt);
    return map;
  }

  FavoritesCompanion toCompanion(bool nullToAbsent) {
    return FavoritesCompanion(
      poemId: Value(poemId),
      createdAt: Value(createdAt),
    );
  }

  factory FavoriteRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return FavoriteRow(
      poemId: serializer.fromJson<String>(json['poemId']),
      createdAt: serializer.fromJson<int>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'poemId': serializer.toJson<String>(poemId),
      'createdAt': serializer.toJson<int>(createdAt),
    };
  }

  FavoriteRow copyWith({String? poemId, int? createdAt}) => FavoriteRow(
    poemId: poemId ?? this.poemId,
    createdAt: createdAt ?? this.createdAt,
  );
  FavoriteRow copyWithCompanion(FavoritesCompanion data) {
    return FavoriteRow(
      poemId: data.poemId.present ? data.poemId.value : this.poemId,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('FavoriteRow(')
          ..write('poemId: $poemId, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(poemId, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is FavoriteRow &&
          other.poemId == this.poemId &&
          other.createdAt == this.createdAt);
}

class FavoritesCompanion extends UpdateCompanion<FavoriteRow> {
  final Value<String> poemId;
  final Value<int> createdAt;
  final Value<int> rowid;
  const FavoritesCompanion({
    this.poemId = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  FavoritesCompanion.insert({
    required String poemId,
    required int createdAt,
    this.rowid = const Value.absent(),
  }) : poemId = Value(poemId),
       createdAt = Value(createdAt);
  static Insertable<FavoriteRow> custom({
    Expression<String>? poemId,
    Expression<int>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (poemId != null) 'poem_id': poemId,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  FavoritesCompanion copyWith({
    Value<String>? poemId,
    Value<int>? createdAt,
    Value<int>? rowid,
  }) {
    return FavoritesCompanion(
      poemId: poemId ?? this.poemId,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (poemId.present) {
      map['poem_id'] = Variable<String>(poemId.value);
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
    return (StringBuffer('FavoritesCompanion(')
          ..write('poemId: $poemId, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $PoemsTable poems = $PoemsTable(this);
  late final $NotebookEntriesTable notebookEntries = $NotebookEntriesTable(
    this,
  );
  late final $FavoritesTable favorites = $FavoritesTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    poems,
    notebookEntries,
    favorites,
  ];
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
typedef $$NotebookEntriesTableCreateCompanionBuilder =
    NotebookEntriesCompanion Function({
      required String id,
      required String poemId,
      required String kind,
      Value<String?> target,
      required String contentJson,
      required String persona,
      Value<bool> userEdited,
      required int createdAt,
      required int updatedAt,
      Value<int> rowid,
    });
typedef $$NotebookEntriesTableUpdateCompanionBuilder =
    NotebookEntriesCompanion Function({
      Value<String> id,
      Value<String> poemId,
      Value<String> kind,
      Value<String?> target,
      Value<String> contentJson,
      Value<String> persona,
      Value<bool> userEdited,
      Value<int> createdAt,
      Value<int> updatedAt,
      Value<int> rowid,
    });

class $$NotebookEntriesTableFilterComposer
    extends Composer<_$AppDatabase, $NotebookEntriesTable> {
  $$NotebookEntriesTableFilterComposer({
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

  ColumnFilters<String> get poemId => $composableBuilder(
    column: $table.poemId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get target => $composableBuilder(
    column: $table.target,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get contentJson => $composableBuilder(
    column: $table.contentJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get persona => $composableBuilder(
    column: $table.persona,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get userEdited => $composableBuilder(
    column: $table.userEdited,
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
}

class $$NotebookEntriesTableOrderingComposer
    extends Composer<_$AppDatabase, $NotebookEntriesTable> {
  $$NotebookEntriesTableOrderingComposer({
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

  ColumnOrderings<String> get poemId => $composableBuilder(
    column: $table.poemId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get target => $composableBuilder(
    column: $table.target,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get contentJson => $composableBuilder(
    column: $table.contentJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get persona => $composableBuilder(
    column: $table.persona,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get userEdited => $composableBuilder(
    column: $table.userEdited,
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

class $$NotebookEntriesTableAnnotationComposer
    extends Composer<_$AppDatabase, $NotebookEntriesTable> {
  $$NotebookEntriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get poemId =>
      $composableBuilder(column: $table.poemId, builder: (column) => column);

  GeneratedColumn<String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<String> get target =>
      $composableBuilder(column: $table.target, builder: (column) => column);

  GeneratedColumn<String> get contentJson => $composableBuilder(
    column: $table.contentJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get persona =>
      $composableBuilder(column: $table.persona, builder: (column) => column);

  GeneratedColumn<bool> get userEdited => $composableBuilder(
    column: $table.userEdited,
    builder: (column) => column,
  );

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$NotebookEntriesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $NotebookEntriesTable,
          NotebookEntryRow,
          $$NotebookEntriesTableFilterComposer,
          $$NotebookEntriesTableOrderingComposer,
          $$NotebookEntriesTableAnnotationComposer,
          $$NotebookEntriesTableCreateCompanionBuilder,
          $$NotebookEntriesTableUpdateCompanionBuilder,
          (
            NotebookEntryRow,
            BaseReferences<
              _$AppDatabase,
              $NotebookEntriesTable,
              NotebookEntryRow
            >,
          ),
          NotebookEntryRow,
          PrefetchHooks Function()
        > {
  $$NotebookEntriesTableTableManager(
    _$AppDatabase db,
    $NotebookEntriesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$NotebookEntriesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$NotebookEntriesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$NotebookEntriesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> poemId = const Value.absent(),
                Value<String> kind = const Value.absent(),
                Value<String?> target = const Value.absent(),
                Value<String> contentJson = const Value.absent(),
                Value<String> persona = const Value.absent(),
                Value<bool> userEdited = const Value.absent(),
                Value<int> createdAt = const Value.absent(),
                Value<int> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => NotebookEntriesCompanion(
                id: id,
                poemId: poemId,
                kind: kind,
                target: target,
                contentJson: contentJson,
                persona: persona,
                userEdited: userEdited,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String poemId,
                required String kind,
                Value<String?> target = const Value.absent(),
                required String contentJson,
                required String persona,
                Value<bool> userEdited = const Value.absent(),
                required int createdAt,
                required int updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => NotebookEntriesCompanion.insert(
                id: id,
                poemId: poemId,
                kind: kind,
                target: target,
                contentJson: contentJson,
                persona: persona,
                userEdited: userEdited,
                createdAt: createdAt,
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

typedef $$NotebookEntriesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $NotebookEntriesTable,
      NotebookEntryRow,
      $$NotebookEntriesTableFilterComposer,
      $$NotebookEntriesTableOrderingComposer,
      $$NotebookEntriesTableAnnotationComposer,
      $$NotebookEntriesTableCreateCompanionBuilder,
      $$NotebookEntriesTableUpdateCompanionBuilder,
      (
        NotebookEntryRow,
        BaseReferences<_$AppDatabase, $NotebookEntriesTable, NotebookEntryRow>,
      ),
      NotebookEntryRow,
      PrefetchHooks Function()
    >;
typedef $$FavoritesTableCreateCompanionBuilder =
    FavoritesCompanion Function({
      required String poemId,
      required int createdAt,
      Value<int> rowid,
    });
typedef $$FavoritesTableUpdateCompanionBuilder =
    FavoritesCompanion Function({
      Value<String> poemId,
      Value<int> createdAt,
      Value<int> rowid,
    });

class $$FavoritesTableFilterComposer
    extends Composer<_$AppDatabase, $FavoritesTable> {
  $$FavoritesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get poemId => $composableBuilder(
    column: $table.poemId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$FavoritesTableOrderingComposer
    extends Composer<_$AppDatabase, $FavoritesTable> {
  $$FavoritesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get poemId => $composableBuilder(
    column: $table.poemId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$FavoritesTableAnnotationComposer
    extends Composer<_$AppDatabase, $FavoritesTable> {
  $$FavoritesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get poemId =>
      $composableBuilder(column: $table.poemId, builder: (column) => column);

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$FavoritesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $FavoritesTable,
          FavoriteRow,
          $$FavoritesTableFilterComposer,
          $$FavoritesTableOrderingComposer,
          $$FavoritesTableAnnotationComposer,
          $$FavoritesTableCreateCompanionBuilder,
          $$FavoritesTableUpdateCompanionBuilder,
          (
            FavoriteRow,
            BaseReferences<_$AppDatabase, $FavoritesTable, FavoriteRow>,
          ),
          FavoriteRow,
          PrefetchHooks Function()
        > {
  $$FavoritesTableTableManager(_$AppDatabase db, $FavoritesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$FavoritesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$FavoritesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$FavoritesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> poemId = const Value.absent(),
                Value<int> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => FavoritesCompanion(
                poemId: poemId,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String poemId,
                required int createdAt,
                Value<int> rowid = const Value.absent(),
              }) => FavoritesCompanion.insert(
                poemId: poemId,
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

typedef $$FavoritesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $FavoritesTable,
      FavoriteRow,
      $$FavoritesTableFilterComposer,
      $$FavoritesTableOrderingComposer,
      $$FavoritesTableAnnotationComposer,
      $$FavoritesTableCreateCompanionBuilder,
      $$FavoritesTableUpdateCompanionBuilder,
      (
        FavoriteRow,
        BaseReferences<_$AppDatabase, $FavoritesTable, FavoriteRow>,
      ),
      FavoriteRow,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$PoemsTableTableManager get poems =>
      $$PoemsTableTableManager(_db, _db.poems);
  $$NotebookEntriesTableTableManager get notebookEntries =>
      $$NotebookEntriesTableTableManager(_db, _db.notebookEntries);
  $$FavoritesTableTableManager get favorites =>
      $$FavoritesTableTableManager(_db, _db.favorites);
}

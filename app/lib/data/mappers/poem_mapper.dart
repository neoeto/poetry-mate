/// PoemRow(drift 行) ↔ Poem(领域实体) 映射。

library;
import 'package:drift/drift.dart';

import '../../core/db/app_database.dart';
import '../../domain/entities/poem.dart';

class PoemMapper {
  const PoemMapper._();

  static Poem fromRow(PoemRow row) => Poem(
        id: row.id,
        author: row.author,
        title: row.title,
        dynasty: row.dynasty,
        type: row.type,
        paragraphs: JsonListCodec.decode(row.paragraphsJson),
        preface: row.preface,
        rhythmic: row.rhythmic,
        popularity: row.popularity,
        rawText: JsonListCodec.decode(row.rawTextJson),
        tags: JsonListCodec.decodeOrNull(row.tagsJson),
        sourceCollection: row.sourceCollection,
      );

  static PoemsCompanion toCompanion(Poem poem) => PoemsCompanion.insert(
        id: poem.id,
        author: poem.author,
        title: Value(poem.title),
        dynasty: poem.dynasty,
        type: poem.type,
        paragraphsJson: JsonListCodec.encode(poem.paragraphs),
        preface: Value(poem.preface),
        rhythmic: Value(poem.rhythmic),
        popularity: Value(poem.popularity),
        rawTextJson: JsonListCodec.encode(poem.rawText),
        tagsJson: Value(poem.tags == null ? null : JsonListCodec.encode(poem.tags!)),
        sourceCollection: poem.sourceCollection,
      );
}

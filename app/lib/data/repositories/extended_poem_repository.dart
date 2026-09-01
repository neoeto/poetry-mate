/// 扩展诗词库仓库 —— 只读写 APP 本地保存的外部作品。
library;

import 'dart:convert';

import 'package:drift/drift.dart';

import '../../core/db/app_database.dart';
import '../../domain/entities/extended_poem.dart';

abstract class ExtendedPoemRepository {
  Future<ExtendedPoem?> byId(String id);

  Future<ExtendedPoem?> byFingerprint(String fingerprint);

  Future<void> save(ExtendedPoem poem);

  Future<List<ExtendedPoem>> listByRecent();

  Future<void> delete(String id);
}

class DriftExtendedPoemRepository implements ExtendedPoemRepository {
  DriftExtendedPoemRepository(this._db);

  final AppDatabase _db;

  ExtendedPoem _fromRow(ExtendedPoemRow row) {
    final paragraphs = (jsonDecode(row.paragraphsJson) as List).cast<String>();
    final uncertain = (jsonDecode(row.uncertainFieldsJson) as List)
        .whereType<String>()
        .toSet();
    return ExtendedPoem(
      id: row.id,
      fingerprint: row.fingerprint,
      title: row.title,
      author: row.author,
      period: row.period,
      genre: row.genre,
      paragraphs: paragraphs,
      preface: row.preface,
      rhythmic: row.rhythmic,
      source: row.source,
      sourceConfidence: row.sourceConfidence,
      uncertainFields: Set.unmodifiable(uncertain),
      recommendation: row.recommendation,
      createdAt: DateTime.fromMillisecondsSinceEpoch(row.createdAt),
    );
  }

  @override
  Future<ExtendedPoem?> byId(String id) async {
    final query = _db.select(_db.extendedPoems)
      ..where((table) => table.id.equals(id));
    final row = await query.getSingleOrNull();
    return row == null ? null : _fromRow(row);
  }

  @override
  Future<ExtendedPoem?> byFingerprint(String fingerprint) async {
    final query = _db.select(_db.extendedPoems)
      ..where((table) => table.fingerprint.equals(fingerprint));
    final row = await query.getSingleOrNull();
    return row == null ? null : _fromRow(row);
  }

  @override
  Future<void> save(ExtendedPoem poem) async {
    await _db
        .into(_db.extendedPoems)
        .insertOnConflictUpdate(
          ExtendedPoemsCompanion.insert(
            id: poem.id,
            fingerprint: poem.fingerprint,
            title: poem.title,
            author: Value(poem.author),
            period: Value(poem.period),
            genre: poem.genre,
            paragraphsJson: jsonEncode(poem.paragraphs),
            preface: Value(poem.preface),
            rhythmic: Value(poem.rhythmic),
            source: Value(poem.source),
            sourceConfidence: poem.sourceConfidence,
            uncertainFieldsJson: jsonEncode(
              poem.uncertainFields.toList()..sort(),
            ),
            recommendation: Value(poem.recommendation),
            createdAt: poem.createdAt.millisecondsSinceEpoch,
          ),
        );
  }

  @override
  Future<List<ExtendedPoem>> listByRecent() async {
    final query = _db.select(_db.extendedPoems)
      ..orderBy([(table) => OrderingTerm.desc(table.createdAt)]);
    final rows = await query.get();
    return rows.map(_fromRow).toList();
  }

  @override
  Future<void> delete(String id) => _db.transaction(() async {
    // 收藏表同时承载公共和扩展作品 ID；删除扩展作品时清理孤立收藏。
    await (_db.delete(
      _db.favorites,
    )..where((table) => table.poemId.equals(id))).go();
    await (_db.delete(
      _db.extendedPoems,
    )..where((table) => table.id.equals(id))).go();
  });
}

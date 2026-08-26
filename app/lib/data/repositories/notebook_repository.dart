/// 注本仓库 —— 生成缓存与用户批注的唯一读写入口。
library;

import 'dart:convert';

import 'package:drift/drift.dart';

import '../../core/db/app_database.dart';
import '../../domain/entities/notebook_entry.dart';

abstract class NotebookRepository {
  /// 写入/覆盖一条(生成缓存路径;不触碰 user_edited)
  Future<void> upsert(NotebookEntry entry);

  /// 按目标定位单条(缓存命中判断)
  Future<NotebookEntry?> byTarget({
    required String poemId,
    required String kind,
    String? target,
  });

  /// 某诗全部条目(按 updated_at 倒序)
  Future<List<NotebookEntry>> byPoem(String poemId);

  /// 全部条目(注本列表视图,按 updated_at 倒序)
  Future<List<NotebookEntry>> listAll();

  /// 用户编辑: 覆盖内容并标记 user_edited(保护语义)
  Future<void> updateUserContent({
    required String id,
    required Map<String, dynamic> content,
    required int updatedAtMs,
  });

  Future<void> delete(String id);
}

class DriftNotebookRepository implements NotebookRepository {
  DriftNotebookRepository(this._db);

  final AppDatabase _db;

  NotebookEntry _fromRow(NotebookEntryRow row) => NotebookEntry(
        id: row.id,
        poemId: row.poemId,
        kind: row.kind,
        target: row.target,
        content: jsonDecode(row.contentJson) as Map<String, dynamic>,
        persona: row.persona,
        userEdited: row.userEdited,
        createdAt: DateTime.fromMillisecondsSinceEpoch(row.createdAt),
        updatedAt: DateTime.fromMillisecondsSinceEpoch(row.updatedAt),
      );

  @override
  Future<void> upsert(NotebookEntry entry) async {
    await _db.into(_db.notebookEntries).insertOnConflictUpdate(
          NotebookEntriesCompanion.insert(
            id: entry.id,
            poemId: entry.poemId,
            kind: entry.kind,
            target: Value(entry.target),
            contentJson: jsonEncode(entry.content),
            persona: entry.persona,
            userEdited: Value(entry.userEdited),
            createdAt: entry.createdAt.millisecondsSinceEpoch,
            updatedAt: entry.updatedAt.millisecondsSinceEpoch,
          ),
        );
  }

  @override
  Future<NotebookEntry?> byTarget({
    required String poemId,
    required String kind,
    String? target,
  }) async {
    final query = _db.select(_db.notebookEntries)
      ..where((t) =>
          t.poemId.equals(poemId) &
          t.kind.equals(kind) &
          (target == null ? t.target.isNull() : t.target.equals(target)));
    final row = await query.getSingleOrNull();
    return row == null ? null : _fromRow(row);
  }

  @override
  Future<List<NotebookEntry>> byPoem(String poemId) async {
    final query = _db.select(_db.notebookEntries)
      ..where((t) => t.poemId.equals(poemId))
      ..orderBy([(t) => OrderingTerm.desc(t.updatedAt)]);
    final rows = await query.get();
    return rows.map(_fromRow).toList();
  }

  @override
  Future<List<NotebookEntry>> listAll() {
    final query = _db.select(_db.notebookEntries)
      ..orderBy([(t) => OrderingTerm.desc(t.updatedAt)]);
    return query.map(_fromRow).get();
  }

  @override
  Future<void> updateUserContent({
    required String id,
    required Map<String, dynamic> content,
    required int updatedAtMs,
  }) {
    return (_db.update(_db.notebookEntries)..where((t) => t.id.equals(id)))
        .write(NotebookEntriesCompanion(
      contentJson: Value(jsonEncode(content)),
      userEdited: const Value(true),
      updatedAt: Value(updatedAtMs),
    ));
  }

  @override
  Future<void> delete(String id) =>
      (_db.delete(_db.notebookEntries)..where((t) => t.id.equals(id))).go();
}

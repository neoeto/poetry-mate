/// 收藏仓库 —— 标记/取消/最近列表(联表带诗实体)。
library;

import 'package:drift/drift.dart';

import '../../core/db/app_database.dart';
import '../../domain/entities/favorite_item.dart';
import '../mappers/poem_mapper.dart';

abstract class FavoritesRepository {
  Future<bool> isFavorite(String poemId);

  Future<void> add(String poemId);

  Future<void> remove(String poemId);

  /// 按收藏时间倒序,联表返回完整诗实体
  Future<List<FavoriteItem>> listByRecent();

  Future<int> count();
}

class DriftFavoritesRepository implements FavoritesRepository {
  DriftFavoritesRepository(this._db);

  final AppDatabase _db;

  @override
  Future<bool> isFavorite(String poemId) async {
    final query = _db.select(_db.favorites)
      ..where((t) => t.poemId.equals(poemId));
    return await query.getSingleOrNull() != null;
  }

  @override
  Future<void> add(String poemId) async {
    await _db.into(_db.favorites).insertOnConflictUpdate(
          FavoritesCompanion.insert(
            poemId: poemId,
            createdAt: DateTime.now().millisecondsSinceEpoch,
          ),
        );
  }

  @override
  Future<void> remove(String poemId) async {
    await (_db.delete(_db.favorites)..where((t) => t.poemId.equals(poemId)))
        .go();
  }

  @override
  Future<List<FavoriteItem>> listByRecent() async {
    final query = _db.select(_db.favorites).join([
      innerJoin(_db.poems, _db.poems.id.equalsExp(_db.favorites.poemId)),
    ])
      ..orderBy([OrderingTerm.desc(_db.favorites.createdAt)]);

    final rows = await query.get();
    return rows.map((row) {
      return FavoriteItem(
        poem: row.readTable(_db.poems).toEntity(),
        createdAt: DateTime.fromMillisecondsSinceEpoch(
            row.readTable(_db.favorites).createdAt),
      );
    }).toList();
  }

  @override
  Future<int> count() async {
    final counted = _db.favorites.poemId.count();
    final query = _db.selectOnly(_db.favorites)..addColumns([counted]);
    final row = await query.getSingle();
    return row.read(counted) ?? 0;
  }
}

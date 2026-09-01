/// 收藏仓库 —— 标记/取消/最近列表(联表带诗实体)。
library;

import 'package:drift/drift.dart';

import '../../core/db/app_database.dart';
import '../../domain/entities/favorite_item.dart';
import '../mappers/poem_mapper.dart';
import 'extended_poem_repository.dart';

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
    await _db
        .into(_db.favorites)
        .insertOnConflictUpdate(
          FavoritesCompanion.insert(
            poemId: poemId,
            createdAt: DateTime.now().millisecondsSinceEpoch,
          ),
        );
  }

  @override
  Future<void> remove(String poemId) async {
    await (_db.delete(
      _db.favorites,
    )..where((t) => t.poemId.equals(poemId))).go();
  }

  @override
  Future<List<FavoriteItem>> listByRecent() async {
    // favorites.poemId 兼容公共诗库 ID 和 ext_ 开头的扩展作品 ID；
    // 因此不能只用 poems 内联表，否则扩展作品会被收藏页过滤掉。
    final rows = await (_db.select(
      _db.favorites,
    )..orderBy([(table) => OrderingTerm.desc(table.createdAt)])).get();
    final extendedRepository = DriftExtendedPoemRepository(_db);
    final items = <FavoriteItem>[];

    for (final favorite in rows) {
      final publicQuery = _db.select(_db.poems)
        ..where((table) => table.id.equals(favorite.poemId));
      final publicRow = await publicQuery.getSingleOrNull();
      final poem =
          publicRow?.toEntity() ??
          (await extendedRepository.byId(favorite.poemId))?.toPoem();
      if (poem == null) continue;
      items.add(
        FavoriteItem(
          poem: poem,
          createdAt: DateTime.fromMillisecondsSinceEpoch(favorite.createdAt),
        ),
      );
    }
    return items;
  }

  @override
  Future<int> count() async {
    final counted = _db.favorites.poemId.count();
    final query = _db.selectOnly(_db.favorites)..addColumns([counted]);
    final row = await query.getSingle();
    return row.read(counted) ?? 0;
  }
}

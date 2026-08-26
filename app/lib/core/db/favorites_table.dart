/// 收藏表 —— schema v2 新增。
library;

import 'package:drift/drift.dart';

@DataClassName('FavoriteRow')
class Favorites extends Table {
  TextColumn get poemId => text()();

  IntColumn get createdAt => integer()();

  @override
  Set<Column> get primaryKey => {poemId};
}

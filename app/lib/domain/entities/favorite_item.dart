/// 收藏列表项 —— 收藏记录 + 关联的诗实体。
library;

import '../../domain/entities/poem.dart';

class FavoriteItem {
  const FavoriteItem({required this.poem, required this.createdAt});

  final Poem poem;
  final DateTime createdAt;
}

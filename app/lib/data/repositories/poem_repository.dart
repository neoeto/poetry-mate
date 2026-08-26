/// 诗仓库 —— 数据访问唯一入口(UI 层不得直接执行 SQL)。
///
/// v1 查询面刻意最小(spec: seed-library「诗实体经仓库访问」):
/// 按 id 获取 / 按朝代类型列出 / 全量计数。
/// **不提供关键词检索** —— FTS 属 search 变更,防止接口面提前扩张。

library;
import 'package:drift/drift.dart';

import '../../core/db/app_database.dart';
import '../../domain/entities/poem.dart';
import '../mappers/poem_mapper.dart';

abstract class PoemRepository {
  /// 按 id 获取单首;不存在返回 null
  Future<Poem?> byId(String id);

  /// 按朝代/类型列出(自然稳定序: 热度降序,id 升序兜底);
  /// 参数为 null 表示不过滤该维度
  Future<List<Poem>> listByDynastyAndType({
    String? dynasty,
    String? type,
    int limit = 50,
    int offset = 0,
  });

  /// 全量计数(导入向导与设置页展示用)
  Future<int> countAll();
}

class DriftPoemRepository implements PoemRepository {
  DriftPoemRepository(this._db);

  final AppDatabase _db;

  @override
  Future<Poem?> byId(String id) async {
    final query = _db.select(_db.poems)..where((t) => t.id.equals(id));
    final row = await query.getSingleOrNull();
    return row == null ? null : PoemMapper.fromRow(row);
  }

  @override
  Future<List<Poem>> listByDynastyAndType({
    String? dynasty,
    String? type,
    int limit = 50,
    int offset = 0,
  }) async {
    final query = _db.select(_db.poems)
      ..where((t) {
        final conditions = <Expression<bool>>[];
        if (dynasty != null) conditions.add(t.dynasty.equals(dynasty));
        if (type != null) conditions.add(t.type.equals(type));
        return conditions.isEmpty ? const Constant(true) : Expression.and(conditions);
      })
      ..orderBy([
        (t) => OrderingTerm.desc(t.popularity),
        (t) => OrderingTerm.asc(t.id),
      ])
      ..limit(limit, offset: offset);
    final rows = await query.get();
    return rows.map(PoemMapper.fromRow).toList();
  }

  @override
  Future<int> countAll() async {
    final count = _db.poems.id.count();
    final query = _db.selectOnly(_db.poems)..addColumns([count]);
    final row = await query.getSingle();
    return row.read(count) ?? 0;
  }
}

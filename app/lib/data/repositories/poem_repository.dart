/// 诗仓库 —— 数据访问唯一入口(UI 层不得直接执行 SQL)。
///
/// 查询面: 按 id 获取 / 按朝代类型列出 / 关键词搜索 / 全量计数。
/// 所有查询都只访问本地 SQLite，不依赖网络。

library;

import 'package:drift/drift.dart';

import '../../core/db/app_database.dart';
import '../../domain/entities/poem.dart';
import '../mappers/poem_mapper.dart';

String _escapeLike(String value) => value
    .replaceAll('\\', '\\\\')
    .replaceAll('%', '\\%')
    .replaceAll('_', '\\_');

abstract class PoemRepository {
  /// 按 id 获取单首;不存在返回 null
  Future<Poem?> byId(String id);

  /// 从本地公共诗库删除一首诗，并移除对应的收藏关系。
  Future<void> delete(String id);

  /// 随机一首(“今日占位”用);空库返回 null
  Future<Poem?> randomOne();

  /// 按朝代/类型列出(自然稳定序: 热度降序,id 升序兜底);
  /// 参数为 null 表示不过滤该维度
  Future<List<Poem>> listByDynastyAndType({
    String? dynasty,
    String? type,
    int limit = 50,
    int offset = 0,
  });

  /// 按诗名、作者、词牌、正文或标签做本地关键词搜索。
  Future<List<Poem>> search(String query, {int limit = 50, int offset = 0});

  /// 全量计数(导入向导与设置页展示用)
  Future<int> countAll();
}

class DriftPoemRepository implements PoemRepository {
  DriftPoemRepository(this._db);

  final AppDatabase _db;

  @override
  Future<void> delete(String id) {
    return _db.transaction(() async {
      await (_db.delete(_db.favorites)..where((t) => t.poemId.equals(id)))
          .go();
      await (_db.delete(_db.poems)..where((t) => t.id.equals(id))).go();
    });
  }

  @override
  Future<Poem?> byId(String id) async {
    final query = _db.select(_db.poems)..where((t) => t.id.equals(id));
    final row = await query.getSingleOrNull();
    return row == null ? null : PoemMapper.fromRow(row);
  }

  @override
  Future<Poem?> randomOne() async {
    final query = _db.select(_db.poems)
      ..orderBy([(t) => OrderingTerm.random()])
      ..limit(1);
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
        return conditions.isEmpty
            ? const Constant(true)
            : Expression.and(conditions);
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
  Future<List<Poem>> search(
    String query, {
    int limit = 50,
    int offset = 0,
  }) async {
    final keyword = query.trim();
    if (keyword.isEmpty || limit <= 0) return [];

    final pattern = '%${_escapeLike(keyword)}%';
    final statement = _db.select(_db.poems)
      ..where(
        (t) => Expression.or([
          t.title.like(pattern, escapeChar: '\\'),
          t.author.like(pattern, escapeChar: '\\'),
          t.rhythmic.like(pattern, escapeChar: '\\'),
          t.paragraphsJson.like(pattern, escapeChar: '\\'),
          t.tagsJson.like(pattern, escapeChar: '\\'),
        ]),
      )
      ..orderBy([
        (t) => OrderingTerm.desc(t.popularity),
        (t) => OrderingTerm.asc(t.id),
      ])
      ..limit(limit, offset: offset < 0 ? 0 : offset);
    final rows = await statement.get();
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

// FavoritesRepository 测试(任务 2.3): add/remove/isFavorite/listByRecent 联表/count。
import 'package:drift/drift.dart' show InsertMode;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:poetry_mate/core/db/app_database.dart';
import 'package:poetry_mate/data/mappers/poem_mapper.dart';
import 'package:poetry_mate/data/repositories/favorites_repository.dart';
import 'package:poetry_mate/domain/entities/poem.dart';

void main() {
  late AppDatabase db;
  late DriftFavoritesRepository repo;

  Poem poem(String id, {String title = '诗', String dynasty = '唐'}) {
    return Poem(
      id: id,
      author: '作者$id',
      title: title,
      dynasty: dynasty,
      type: 'shi',
      paragraphs: ['句。'],
      preface: null,
      rhythmic: null,
      popularity: null,
      rawText: ['句。'],
      tags: null,
      sourceCollection: 'seed',
    );
  }

  Future<void> insertPoems() async {
    for (final p in [poem('p1'), poem('p2', title: '春望', dynasty: '唐')]) {
      await db.into(db.poems).insert(
            PoemMapper.toCompanion(p),
            mode: InsertMode.insertOrIgnore,
          );
    }
  }

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = DriftFavoritesRepository(db);
  });
  tearDown(() => db.close());

  test('add/isFavorite/remove 往返', () async {
    await insertPoems();
    expect(await repo.isFavorite('p1'), isFalse);

    await repo.add('p1');
    expect(await repo.isFavorite('p1'), isTrue);

    await repo.remove('p1');
    expect(await repo.isFavorite('p1'), isFalse);
  });

  test('listByRecent 按收藏时间倒序并带出诗实体', () async {
    await insertPoems();

    final t0 = DateTime(2026, 1, 1).millisecondsSinceEpoch;
    final t1 = DateTime(2026, 2, 1).millisecondsSinceEpoch;
    // 先收藏 p2(较早), 再收藏 p1(较晚)
    await db.customStatement(
        'INSERT INTO favorites (poem_id, created_at) VALUES (?, ?)', ['p2', t0]);
    await db.customStatement(
        'INSERT INTO favorites (poem_id, created_at) VALUES (?, ?)', ['p1', t1]);

    final list = await repo.listByRecent();
    expect(list.map((f) => f.poem.id).toList(), ['p1', 'p2']);
    expect(list.first.poem.author, '作者p1');
    expect(list.first.createdAt, DateTime(2026, 2, 1));
  });

  test('重复 add 同一首不产生重复行(upsert)', () async {
    await insertPoems();
    await repo.add('p1');
    await repo.add('p1');
    expect(await repo.count(), 1);
  });

  test('count 空表为 0', () async {
    expect(await repo.count(), 0);
  });
}

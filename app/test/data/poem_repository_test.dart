// PoemRepository 单元测试 —— 内存数据库,不依赖平台通道。
// 对应 specs/seed-library「诗实体经仓库访问」全部场景。
import 'package:drift/drift.dart' show InsertMode;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:poetry_mate/core/db/app_database.dart';
import 'package:poetry_mate/data/mappers/poem_mapper.dart';
import 'package:poetry_mate/data/repositories/poem_repository.dart';
import 'package:poetry_mate/domain/entities/poem.dart';

void main() {
  late AppDatabase db;
  late DriftPoemRepository repo;

  Poem fixture({
    required String id,
    String author = '李白',
    String? title = '静夜思',
    String dynasty = '唐',
    String type = 'shi',
    double? popularity = 10.0,
    List<String>? tags,
    List<String> paragraphs = const ['床前看月光。'],
    String? rhythmic,
  }) {
    return Poem(
      id: id,
      author: author,
      title: title,
      dynasty: dynasty,
      type: type,
      paragraphs: paragraphs,
      preface: null,
      rhythmic: rhythmic,
      popularity: popularity,
      rawText: paragraphs,
      tags: tags,
      sourceCollection: 'seed',
    );
  }

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = DriftPoemRepository(db);
  });
  tearDown(() => db.close());

  test('byId: 存在则返回实体,不存在返回 null', () async {
    await db.into(db.poems).insert(PoemMapper.toCompanion(fixture(id: 'x1')));

    final found = await repo.byId('x1');
    expect(found?.id, 'x1');
    expect(found?.author, '李白');

    expect(await repo.byId('missing'), isNull);
  });

  test('listByDynastyAndType: 双维过滤 + 热度降序', () async {
    Future<void> seed(Poem p) async => db
        .into(db.poems)
        .insert(PoemMapper.toCompanion(p), mode: InsertMode.insertOrIgnore);

    await seed(fixture(id: 'a', dynasty: '唐', popularity: 5));
    await seed(fixture(id: 'b', dynasty: '唐', popularity: 9));
    await seed(fixture(id: 'c', dynasty: '宋', type: 'ci', popularity: 99));
    await seed(fixture(id: 'd', dynasty: '唐', popularity: null));

    final tang = await repo.listByDynastyAndType(dynasty: '唐');
    expect(tang.map((p) => p.id).toList(), ['b', 'a', 'd']); // 热度降序,null 最后

    final songCi = await repo.listByDynastyAndType(dynasty: '宋', type: 'ci');
    expect(songCi.map((p) => p.id), ['c']);

    final limited = await repo.listByDynastyAndType(limit: 2, offset: 1);
    expect(limited, hasLength(2));
  });

  test('search: 按标题、作者、词牌、正文和标签命中', () async {
    await db
        .into(db.poems)
        .insert(
          PoemMapper.toCompanion(
            fixture(
              id: 'title',
              title: '静夜思',
              paragraphs: ['床前明月光。'],
              tags: const ['思乡'],
            ),
          ),
        );
    await db
        .into(db.poems)
        .insert(
          PoemMapper.toCompanion(
            fixture(
              id: 'author',
              author: '苏轼',
              title: '水调歌头',
              paragraphs: ['明月几时有。'],
              rhythmic: '水调歌头',
            ),
          ),
        );

    expect((await repo.search('静夜思')).single.id, 'title');
    expect((await repo.search('苏轼')).single.id, 'author');
    expect((await repo.search('水调')).single.id, 'author');
    expect((await repo.search('明月几时')).single.id, 'author');
    expect((await repo.search('思乡')).single.id, 'title');
    expect(await repo.search('   '), isEmpty);
  });

  test('search: 特殊 LIKE 字符按字面匹配且结果受 limit 限制', () async {
    for (final id in ['a', 'b', 'c']) {
      await db
          .into(db.poems)
          .insert(PoemMapper.toCompanion(fixture(id: id, paragraphs: ['春风。'])));
    }

    expect(await repo.search('%'), isEmpty);
    expect((await repo.search('春', limit: 2)), hasLength(2));
    expect((await repo.search('春', limit: 2)).map((poem) => poem.id), [
      'a',
      'b',
    ]);
  });

  test('countAll: 全量计数', () async {
    expect(await repo.countAll(), 0);
    for (final id in ['a', 'b', 'c']) {
      await db
          .into(db.poems)
          .insert(
            PoemMapper.toCompanion(fixture(id: id)),
            mode: InsertMode.insertOrIgnore,
          );
    }
    expect(await repo.countAll(), 3);
  });

  test('词类字段往返: title null / rhythmic 有值 / tags 数组', () async {
    final ci = fixture(
      id: 'ci1',
      author: '和岘',
      title: null,
      dynasty: '宋',
      type: 'ci',
      tags: const ['宋词三百首'],
    );
    // 词牌手动注入(fixture 不含 rhythmic 参数)
    final withRhythmic = Poem(
      id: ci.id,
      author: ci.author,
      title: ci.title,
      dynasty: ci.dynasty,
      type: ci.type,
      paragraphs: ci.paragraphs,
      preface: ci.preface,
      rhythmic: '导引',
      popularity: ci.popularity,
      rawText: ci.rawText,
      tags: ci.tags,
      sourceCollection: ci.sourceCollection,
    );
    await db.into(db.poems).insert(PoemMapper.toCompanion(withRhythmic));

    final poem = (await repo.byId('ci1'))!;
    expect(poem.title, isNull);
    expect(poem.rhythmic, '导引');
    expect(poem.tags, ['宋词三百首']);
    expect(poem.displayTitle, '导引');
  });
}

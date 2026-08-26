// schema v1 基线测试: 表结构/主键/空值语义/映射往返。
// 对应 specs/seed-library:「字段完整入库可查」「迁移基线确立」。
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:poetry_mate/core/db/app_database.dart';
import 'package:poetry_mate/data/mappers/poem_mapper.dart';
import 'package:poetry_mate/domain/entities/poem.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
  });
  tearDown(() async {
    await db.close();
  });

  final fixture = Poem(
    id: 'a' * 32,
    author: '李白',
    title: null, // 词类无题场景同构;此处模拟显式 null
    dynasty: '唐',
    type: 'shi',
    paragraphs: ['床前明月光，', '疑是地上霜。'],
    preface: null,
    rhythmic: null,
    popularity: 22.251,
    rawText: ['床前明月光，', '疑是地上霜。'],
    tags: null,
    sourceCollection: 'seed',
  );

  test('schemaVersion 固定为 1(迁移基线)', () {
    expect(db.schemaVersion, 1);
  });

  test('插入并回读: 字段完整、null 显式、JSON 数组解码正确', () async {
    await db.into(db.poems).insert(PoemMapper.toCompanion(fixture));

    final row = await db.select(db.poems).getSingle();
    expect(row.id, fixture.id);
    expect(row.author, '李白');
    expect(row.title, isNull); // 显式 null 而非缺失
    expect(row.preface, isNull);
    expect(row.popularity, 22.251);
    expect(row.tagsJson, isNull);

    final poem = PoemMapper.fromRow(row);
    expect(poem.paragraphs, ['床前明月光，', '疑是地上霜。']);
    expect(poem.rawText, fixture.rawText);
    expect(poem.tags, isNull);
  });

  test('主键冲突: 同 id 二次插入抛错', () async {
    await db.into(db.poems).insert(PoemMapper.toCompanion(fixture));
    expect(
      () => db.into(db.poems).insert(PoemMapper.toCompanion(fixture)),
      throwsException,
    );
  });

  test('upsert 模式可用于种子重灌(冲突时更新)', () async {
    await db.into(db.poems).insertOnConflictUpdate(
          PoemMapper.toCompanion(fixture),
        );
    final updated = fixture.popularity == null ? fixture : fixture;
    await db.into(db.poems).insertOnConflictUpdate(
          PoemMapper.toCompanion(updated),
        );
    expect(await db.select(db.poems).get(), hasLength(1));
  });

  test('词类记录: title/rhythmic 的 null 与值并存', () async {
    final ci = Poem(
      id: 'b' * 32,
      author: '和岘',
      title: null,
      dynasty: '宋',
      type: 'ci',
      paragraphs: ['气和玉烛。'],
      preface: null,
      rhythmic: '导引',
      popularity: null,
      rawText: ['气和玉烛。'],
      tags: const ['宋词三百首'],
      sourceCollection: 'songci',
    );
    await db.into(db.poems).insert(PoemMapper.toCompanion(ci));
    final row = await db.select(db.poems).getSingle();
    final poem = PoemMapper.fromRow(row);

    expect(poem.title, isNull);
    expect(poem.rhythmic, '导引');
    expect(poem.tags, ['宋词三百首']);
    expect(poem.isCi, isTrue);
    expect(poem.displayTitle, '导引');
  });

  test('Companion 显式 absent 与 null 等价存储(null 列)', () async {
    // 直接用 companion 构造验证 Value.absent 行为
    final companion = PoemsCompanion.insert(
      id: 'c' * 32,
      author: '佚名',
      dynasty: '唐',
      type: 'shi',
      paragraphsJson: '["诗。"]',
      rawTextJson: '["诗。"]',
      sourceCollection: 'tangshi',
    );
    await db.into(db.poems).insert(companion);
    final row = await db.select(db.poems).getSingle();
    expect(row.title, isNull);
    expect(row.rhythmic, isNull);
    expect(row.tagsJson, isNull);
  });
}

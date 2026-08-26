// 种子装载器测试 —— 恒等解压 + 内存资产/标记,覆盖三条路径:
// 首装 / 同版本跳过 / 版本升级重灌(upsert 不重复)。
// 对应 specs/seed-library:「内置种子集随安装包分发」「装载幂等与版本标记」。
import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:poetry_mate/core/db/app_database.dart';
import 'package:poetry_mate/data/seed/seed_loader.dart';
import 'package:poetry_mate/data/seed/seed_version_store.dart';

class FakeAssetBundle implements AssetBundle {
  final Map<String, String> strings;
  final Map<String, Uint8List> binaries;

  FakeAssetBundle({this.strings = const {}, this.binaries = const {}});

  @override
  Future<String> loadString(String key, {bool cache = true}) async {
    final value = strings[key];
    if (value == null) throw FlutterError('asset missing: $key');
    return value;
  }

  @override
  Future<ByteData> load(String key) async {
    final value = binaries[key];
    if (value == null) throw FlutterError('asset missing: $key');
    return ByteData.sublistView(value);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late AppDatabase db;
  late InMemorySeedVersionStore versionStore;
  late SeedLoader loader;
  int decompressCalls = 0;

  const version = 'v20260825.b8594f81';
  final seedRecords = [
    {
      'id': 'a' * 32,
      'author': '李白',
      'title': '静夜思',
      'dynasty': '唐',
      'type': 'shi',
      'paragraphs': ['床前明月光，'],
      'preface': null,
      'rhythmic': null,
      'popularity': 10.0,
      'raw_text': ['床前明月光，'],
      'tags': null,
      'source_collection': 'seed',
    },
    {
      'id': 'b' * 32,
      'author': '张先',
      'title': null,
      'dynasty': '宋',
      'type': 'ci',
      'paragraphs': ['水调数声持酒听。'],
      'preface': null,
      'rhythmic': '天仙子',
      'popularity': 5.5,
      'raw_text': ['水调数声持酒听。'],
      'tags': null,
      'source_collection': 'seed',
    },
  ];

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    versionStore = InMemorySeedVersionStore();
    decompressCalls = 0;
    loader = SeedLoader(
      assets: FakeAssetBundle(
        strings: {SeedLoader.versionAsset: version},
        binaries: {
          SeedLoader.dataAsset:
              Uint8List.fromList(utf8.encode(jsonEncode(seedRecords))),
        },
      ),
      db: db,
      versionStore: versionStore,
      // 恒等"解压": 资产直接存明文 JSON;真实 es_zstd 由任务 2.3 真机验证
      decompress: (data) {
        decompressCalls++;
        return data;
      },
    );
  });
  tearDown(() => db.close());

  test('首次启动: installed,记录入库且计数正确', () async {
    final result = await loader.loadIfNeeded();

    expect(result.action, SeedLoadAction.installed);
    expect(result.recordCount, 2);
    expect(result.version, version);
    expect(await db.select(db.poems).get(), hasLength(2));
    expect(await versionStore.read(), version);
  });

  test('二次启动: skipped,零写入零解压', () async {
    await loader.loadIfNeeded();
    decompressCalls = 0;

    final result = await loader.loadIfNeeded();

    expect(result.action, SeedLoadAction.skipped);
    expect(decompressCalls, 0); // 未发生解压
    expect(await db.select(db.poems).get(), hasLength(2));
  });

  test('版本升级: upgraded,upsert 无重复', () async {
    await loader.loadIfNeeded();

    // 构造更高版本的资产: 一条更新 + 一条新增
    final v2Records = [
      {...seedRecords[0], 'popularity': 99.0}, // 内容变更 → upsert 更新
      {...seedRecords[1]},
      {
        'id': 'c' * 32,
        'author': '王维',
        'title': '相思',
        'dynasty': '唐',
        'type': 'shi',
        'paragraphs': ['红豆生南国。'],
        'preface': null,
        'rhythmic': null,
        'popularity': 7.0,
        'raw_text': ['红豆生南国。'],
        'tags': null,
        'source_collection': 'seed',
      },
    ];
    final loaderV2 = SeedLoader(
      assets: FakeAssetBundle(
        strings: {SeedLoader.versionAsset: 'v20260901.cccccccc'},
        binaries: {
          SeedLoader.dataAsset:
              Uint8List.fromList(utf8.encode(jsonEncode(v2Records))),
        },
      ),
      db: db,
      versionStore: versionStore,
      decompress: (data) => data,
    );

    final result = await loaderV2.loadIfNeeded();

    expect(result.action, SeedLoadAction.upgraded);
    expect(await db.select(db.poems).get(), hasLength(3)); // 无重复
    final updated = await (db.select(db.poems)
          ..where((t) => t.id.equals('a' * 32)))
        .getSingle();
    expect(updated.popularity, 99.0); // 确实被更新
  });

  test('事务性: 中途失败不残留半截数据,版本标记未写', () async {
    // 注入会在解码阶段失败的资产(非法 JSON)
    final badLoader = SeedLoader(
      assets: FakeAssetBundle(
        strings: {SeedLoader.versionAsset: 'v1'},
        binaries: {
          SeedLoader.dataAsset: Uint8List.fromList('not-json'.codeUnits),
        },
      ),
      db: db,
      versionStore: versionStore,
      decompress: (data) => data,
    );

    await expectLater(badLoader.loadIfNeeded(), throwsException);

    expect(await db.select(db.poems).get(), isEmpty);
    expect(await versionStore.read(), isNull);
  });

  test('无种子资产(开发环境): 静默跳过', () async {
    final emptyLoader = SeedLoader(
      assets: FakeAssetBundle(),
      db: db,
      versionStore: versionStore,
      decompress: (data) => data,
    );
    final result = await emptyLoader.loadIfNeeded();
    expect(result.action, SeedLoadAction.skipped);
  });

  test('真实规模冒烟: 1000 条批量 upsert 性能合理', () async {
    final big = List.generate(
      1000,
      (i) => {
        ...seedRecords[0],
        'id': i.toRadixString(16).padLeft(32, '0'),
        'title': '诗$i',
      },
    );
    final bigLoader = SeedLoader(
      assets: FakeAssetBundle(
        strings: {SeedLoader.versionAsset: 'v-big'},
        binaries: {
          SeedLoader.dataAsset: Uint8List.fromList(
            utf8.encode(jsonEncode(big)),
          ),
        },
      ),
      db: db,
      versionStore: versionStore,
      decompress: (data) => data,
    );

    final sw = Stopwatch()..start();
    final result = await bigLoader.loadIfNeeded();
    sw.stop();

    expect(result.recordCount, 1000);
    expect(sw.elapsedMilliseconds < 5000, isTrue,
        reason: '1000 条装载耗时 ${sw.elapsedMilliseconds}ms,超出预期');
  });
}


// 全应用集成测试(内存库 + 预置数据): 分类浏览 → 点击 → 阅读页呈现正文。
// 对应 specs/app-foundation「分类页可浏览种子集」与 specs/seed-library 场景。
import 'package:drift/drift.dart' show InsertMode;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:poetry_mate/core/db/app_database.dart';
import 'package:poetry_mate/data/mappers/poem_mapper.dart';
import 'package:poetry_mate/data/preferences/reading_prefs.dart';
import 'package:poetry_mate/data/providers.dart';
import 'package:poetry_mate/main.dart';

import '../data/fixtures.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
  });
  tearDown(() => db.close());

  testWidgets('分类列出种子诗 → 点击进入阅读页', (tester) async {
    // 预置两首(不同朝代),并让静夜思热度更高以稳定排序
    final poems = [
      testPoem(id: 'p' * 31 + '1', popularity: 20.0),
      testPoem(
        id: 'p' * 31 + '2',
        author: '张先',
        title: null,
        dynasty: '宋',
        type: 'ci',
        rhythmic: '天仙子',
        paragraphs: ['水调数声持酒听。'],
        popularity: 5.0,
      ),
    ];
    for (final poem in poems) {
      await db
          .into(db.poems)
          .insert(
            PoemMapper.toCompanion(poem),
            mode: InsertMode.insertOrIgnore,
          );
    }

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          readingPrefsProvider.overrideWithValue(InMemoryReadingPrefs()),
        ],
        child: const PoetryMateApp(),
      ),
    );
    await tester.pumpAndSettle();

    // 进入分类 Tab
    await tester.tap(find.text('分类'));
    await tester.pumpAndSettle();

    // 默认"全部"过滤下两首都在
    expect(find.text('静夜思'), findsOneWidget);
    expect(find.text('天仙子'), findsOneWidget);

    // 过滤到宋词 → 只剩词
    await tester.tap(find.text('宋词'));
    await tester.pumpAndSettle();
    expect(find.text('静夜思'), findsNothing);
    expect(find.text('天仙子'), findsOneWidget);

    // 点进阅读页,正文呈现
    await tester.tap(find.text('天仙子'));
    await tester.pumpAndSettle();
    expect(find.textContaining('水调数声持酒听'), findsOneWidget);
    expect(find.text('张先 · 宋'), findsOneWidget);
  });

  testWidgets('分类页搜索诗名并进入阅读页', (tester) async {
    final poem = testPoem(
      id: 'search-poem',
      title: '静夜思',
      paragraphs: ['床前明月光。'],
    );
    await db
        .into(db.poems)
        .insert(PoemMapper.toCompanion(poem), mode: InsertMode.insertOrIgnore);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          readingPrefsProvider.overrideWithValue(InMemoryReadingPrefs()),
        ],
        child: const PoetryMateApp(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('分类'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('搜索诗词'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '静夜思');
    await tester.pumpAndSettle();

    expect(find.text('静夜思'), findsNWidgets(2));
    expect(find.textContaining('李白 · 唐'), findsOneWidget);
    await tester.tap(find.text('静夜思').first);
    await tester.pumpAndSettle();

    expect(find.text('床前明月光。'), findsOneWidget);
  });

  testWidgets('空库启动: 分类页显示空态而非崩溃', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          readingPrefsProvider.overrideWithValue(InMemoryReadingPrefs()),
        ],
        child: const PoetryMateApp(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('分类'));
    await tester.pumpAndSettle();
    expect(find.text('该分类下暂无诗篇'), findsOneWidget);
  });
}

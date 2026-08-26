// 收藏页真实列表 widget 测试：空态、排序、标题回退、点击进入阅读路由。
import 'package:drift/drift.dart' show InsertMode;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:poetry_mate/core/db/app_database.dart';
import 'package:poetry_mate/data/mappers/poem_mapper.dart';
import 'package:poetry_mate/data/providers.dart';
import 'package:poetry_mate/features/favorites/favorites_page.dart';

import '../data/fixtures.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() => db.close());

  Future<void> pumpFavorites(
    WidgetTester tester, {
    GoRouter? router,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
        child: router == null
            ? const MaterialApp(home: FavoritesPage())
            : MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('空收藏显示引导态', (tester) async {
    await pumpFavorites(tester);

    expect(find.text('收藏夹还空着'), findsOneWidget);
    expect(find.textContaining('点一颗心'), findsOneWidget);
  });

  testWidgets('列出收藏诗词、标题回退词牌并按时间倒序', (tester) async {
    final older = testPoem(
      id: 'favorite-older-poem',
      title: null,
      rhythmic: '水调歌头',
      author: '苏轼',
      dynasty: '宋',
    );
    final newer = testPoem(
      id: 'favorite-newer-poem',
      title: '静夜思',
      author: '李白',
      dynasty: '唐',
    );
    for (final poem in [older, newer]) {
      await db.into(db.poems).insert(
            PoemMapper.toCompanion(poem),
            mode: InsertMode.insertOrIgnore,
          );
    }
    await db.into(db.favorites).insert(
          FavoritesCompanion.insert(poemId: older.id, createdAt: 10),
        );
    await db.into(db.favorites).insert(
          FavoritesCompanion.insert(poemId: newer.id, createdAt: 20),
        );

    await pumpFavorites(tester);

    expect(find.text('静夜思'), findsOneWidget);
    expect(find.text('水调歌头'), findsOneWidget);
    expect(find.text('苏轼 · 宋'), findsOneWidget);
    expect(find.text('李白 · 唐'), findsOneWidget);
    final titles = tester
        .widgetList<Text>(find.byType(Text))
        .map((text) => text.data)
        .whereType<String>()
        .toList();
    expect(titles.indexOf('静夜思'), lessThan(titles.indexOf('水调歌头')));
  });

  testWidgets('点击收藏条目进入对应阅读路由', (tester) async {
    final poem = testPoem(id: 'favorite-route-poem', title: '路线测试');
    await db.into(db.poems).insert(
          PoemMapper.toCompanion(poem),
          mode: InsertMode.insertOrIgnore,
        );
    await db.into(db.favorites).insert(
          FavoritesCompanion.insert(poemId: poem.id, createdAt: 20),
        );

    final router = GoRouter(
      initialLocation: '/favorites',
      routes: [
        GoRoute(
          path: '/favorites',
          builder: (_, _) => const FavoritesPage(),
        ),
        GoRoute(
          path: '/poem/:id',
          builder: (_, state) => Scaffold(
            body: Text('阅读 ${state.pathParameters['id']}'),
          ),
        ),
      ],
    );
    await pumpFavorites(tester, router: router);

    await tester.tap(find.text('路线测试'));
    await tester.pumpAndSettle();
    expect(find.text('阅读 ${poem.id}'), findsOneWidget);
  });
}

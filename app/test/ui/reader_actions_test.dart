// 阅读页 AppBar 动作测试(任务 3.1):
// 收藏心形切换 / 白文模式开关 / 字号偏好生效。
import 'package:flutter/material.dart';
import 'package:drift/drift.dart' show InsertMode;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:poetry_mate/core/db/app_database.dart';
import 'package:poetry_mate/data/mappers/poem_mapper.dart';
import 'package:poetry_mate/data/preferences/reading_prefs.dart';
import 'package:poetry_mate/data/providers.dart';
import 'package:poetry_mate/data/repositories/favorites_repository.dart';
import 'package:poetry_mate/features/reader/poem_route_page.dart';

import '../data/fixtures.dart';

void main() {
  late AppDatabase db;
  late InMemoryReadingPrefs prefs;
  late PoemRoutePage page;

  const poemId = 'reader-actions-test-id';

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    prefs = InMemoryReadingPrefs();
    page = PoemRoutePage(poemId: poemId);
  });

  Future<void> seedAndPump(
    WidgetTester tester, {
    double fontSize = 24,
  }) async {
    await db.into(db.poems).insert(
          PoemMapper.toCompanion(testPoem(id: poemId)),
          mode: InsertMode.insertOrIgnore,
        );
    await prefs.setContentFontSize(fontSize);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          readingPrefsProvider.overrideWithValue(prefs),
        ],
        child: MaterialApp(home: page),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('收藏心形: 点击入收藏并变实心', (tester) async {
    await seedAndPump(tester);

    // 初始为空心
    final outline = find.byIcon(Icons.favorite_border);
    expect(outline, findsOneWidget);

    await tester.tap(outline);
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.favorite), findsOneWidget);
    final repo =
        DriftFavoritesRepository(db);
    expect(await repo.isFavorite(poemId), isTrue);
  });

  testWidgets('再次点击取消收藏', (tester) async {
    await seedAndPump(tester);

    await tester.tap(find.byIcon(Icons.favorite_border));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.favorite));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.favorite_border), findsOneWidget);
  });

  testWidgets('白文开关: 正文标点消失再恢复', (tester) async {
    await seedAndPump(tester);

    // 默认带标点
    expect(find.text('床前明月光，'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.text_format_outlined));
    await tester.pumpAndSettle();
    expect(find.text('床前明月光'), findsOneWidget); // 无逗号

    await tester.tap(find.byIcon(Icons.text_format_outlined));
    await tester.pumpAndSettle();
    expect(find.text('床前明月光，'), findsOneWidget);
  });

  testWidgets('字号偏好生效: 预设28 → 正文28sp', (tester) async {
    await seedAndPump(tester, fontSize: 28);

    final style = tester
        .widget<Text>(find.text('床前明月光，'))
        .style!;
    expect(style.fontSize, 28);
  });
}

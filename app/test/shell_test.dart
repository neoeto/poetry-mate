// 导航壳冒烟测试: 四 Tab 在位、切换生效、阅读页深链可达。
// (对应 specs/app-foundation「底部四 Tab 导航壳」场景的骨架版)
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:drift/native.dart';
import 'package:poetry_mate/core/db/app_database.dart';
import 'package:poetry_mate/data/preferences/reading_prefs.dart';
import 'package:poetry_mate/data/providers.dart';
import 'package:poetry_mate/main.dart';

Future<void> _pumpApp(WidgetTester tester) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        // 空内存库: 验证真实页面在无数据时的语义
        appDatabaseProvider.overrideWithValue(
          AppDatabase(NativeDatabase.memory()),
        ),
        readingPrefsProvider
            .overrideWithValue(InMemoryReadingPrefs()),
      ],
      child: const PoetryMateApp(),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('底部四 Tab 全部在位', (tester) async {
    await _pumpApp(tester);
    for (final label in ['今日', '分类', '收藏', '我的']) {
      expect(find.text(label), findsWidgets, reason: '$label Tab 缺失');
    }
  });

  testWidgets('切到分类 Tab 显示占位文案', (tester) async {
    await _pumpApp(tester);
    await tester.tap(find.text('分类'));
    await tester.pumpAndSettle();
    expect(find.text('该分类下暂无诗篇'), findsOneWidget);
  });

  testWidgets('阅读页深链占位可达', (tester) async {
    await _pumpApp(tester);
    final context = tester.element(find.byType(NavigationBar));
    context.go('/poem/abc123');
    await tester.pumpAndSettle();
    expect(find.text('未找到该诗篇'), findsOneWidget);
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';
import 'package:poetry_mate/core/db/app_database.dart';
import 'package:poetry_mate/data/providers.dart';
import 'package:poetry_mate/data/repositories/extended_poem_repository.dart';
import 'package:poetry_mate/domain/entities/extended_poem.dart';
import 'package:poetry_mate/features/extended/extended_library_page.dart';

void main() {
  final poem = ExtendedPoem(
    id: 'ext-demo',
    fingerprint: 'a' * 32,
    title: '春日',
    author: '作者不详',
    period: '近现代',
    genre: 'modern_poem',
    paragraphs: const ['春风从窗前经过。'],
    source: '作品集',
    sourceConfidence: ExtendedPoemConfidence.uncertain,
    uncertainFields: const {'source'},
    createdAt: DateTime(2026),
  );

  testWidgets('扩展诗词库展示保存作品及来源状态', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          visibleExtendedPoemsProvider.overrideWith((ref) async => [poem]),
        ],
        child: MaterialApp(home: const ExtendedLibraryPage()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('扩展诗词库'), findsOneWidget);
    expect(find.text('春日'), findsOneWidget);
    expect(find.textContaining('信息待核'), findsOneWidget);
  });

  testWidgets('扩展诗词库为空时展示 AI 寻诗入口', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          visibleExtendedPoemsProvider.overrideWith((ref) async => []),
        ],
        child: MaterialApp(home: const ExtendedLibraryPage()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('扩展诗词库还空着'), findsOneWidget);
    expect(find.text('开始 AI 寻诗'), findsOneWidget);
  });

  testWidgets('扩展诗词库删除作品后显示空态', (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    await DriftExtendedPoemRepository(db).save(poem);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
        child: const MaterialApp(home: ExtendedLibraryPage()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('delete-extended-poem-ext-demo')));
    await tester.pumpAndSettle();
    expect(find.text('删除诗词？'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('confirm-poem-deletion')));
    await tester.pumpAndSettle();

    expect(find.text('扩展诗词库还空着'), findsOneWidget);
    expect(await DriftExtendedPoemRepository(db).byId(poem.id), isNull);
  });
}

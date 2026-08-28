// 我的注本列表与编辑入口 widget 测试。
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:poetry_mate/data/providers.dart';
import 'package:poetry_mate/data/repositories/notebook_repository.dart';
import 'package:poetry_mate/data/repositories/poem_repository.dart';
import 'package:poetry_mate/domain/entities/annotations.dart';
import 'package:poetry_mate/domain/entities/notebook_entry.dart';
import 'package:poetry_mate/domain/entities/poem.dart';
import 'package:poetry_mate/features/settings/notebook_page.dart';

import '../data/fixtures.dart';

void main() {
  final poem = testPoem();
  late _FakeNotebookRepository notebookRepository;
  late _FakePoemRepository poemRepository;

  setUp(() {
    notebookRepository = _FakeNotebookRepository([
      NotebookEntry(
        id: 'essay-entry',
        poemId: poem.id,
        kind: NotebookKind.essay,
        target: null,
        content: {'summary': '月光下的思乡之情'},
        persona: 'zhiyin',
        userEdited: false,
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 2),
      ),
      NotebookEntry(
        id: 'line-entry',
        poemId: poem.id,
        kind: NotebookKind.lineNote,
        target: '0',
        content: {
          'translation': '明亮的月光照在床前',
          'notes': <Map<String, dynamic>>[],
        },
        persona: 'zhiyin',
        userEdited: true,
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
      ),
      NotebookEntry(
        id: 'selected-word-entry',
        poemId: poem.id,
        kind: NotebookKind.wordNote,
        target: '0:0:2:床前',
        content: WordNote(
          term: '床前',
          explain: '床的前面。',
          lineIndex: 0,
          start: 0,
          end: 2,
          source: WordNoteSource.selected,
        ).toJson(),
        persona: 'zhiyin',
        userEdited: false,
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 3),
      ),
    ]);
    poemRepository = _FakePoemRepository(poem);
  });

  Future<void> pumpPage(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          notebookRepositoryProvider.overrideWithValue(notebookRepository),
          poemRepositoryProvider.overrideWithValue(poemRepository),
        ],
        child: const MaterialApp(home: NotebookPage()),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('按诗聚合展示注本条目，并提供编辑入口', (tester) async {
    await pumpPage(tester);

    expect(find.text('静夜思'), findsOneWidget);
    expect(find.text('整篇赏析'), findsOneWidget);
    expect(find.text('逐句注 · 第 1 句'), findsOneWidget);
    expect(find.text('用户选词解释 · 床前'), findsOneWidget);
    expect(find.text('月光下的思乡之情'), findsOneWidget);
    expect(find.text('床的前面。'), findsOneWidget);
    expect(find.text('即将'), findsNothing);

    await tester.tap(find.text('整篇赏析'));
    await tester.pumpAndSettle();
    expect(find.text('编辑个人注本'), findsOneWidget);
  });

  testWidgets('没有注本时显示引导空态', (tester) async {
    notebookRepository = _FakeNotebookRepository([]);
    await pumpPage(tester);

    expect(find.text('注本还空着'), findsOneWidget);
    expect(find.textContaining('在诗句、赏析或追问中留下你的理解'), findsOneWidget);
  });
}

class _FakeNotebookRepository implements NotebookRepository {
  _FakeNotebookRepository(this.entries);

  final List<NotebookEntry> entries;

  @override
  Future<void> upsert(NotebookEntry entry) async {}

  @override
  Future<NotebookEntry?> byTarget({
    required String poemId,
    required String kind,
    String? target,
  }) async {
    for (final entry in entries) {
      if (entry.poemId == poemId &&
          entry.kind == kind &&
          entry.target == target) {
        return entry;
      }
    }
    return null;
  }

  @override
  Future<List<NotebookEntry>> byPoem(String poemId) async =>
      entries.where((entry) => entry.poemId == poemId).toList();

  @override
  Future<List<NotebookEntry>> listAll() async => entries;

  @override
  Future<void> updateUserContent({
    required String id,
    required Map<String, dynamic> content,
    required int updatedAtMs,
  }) async {}

  @override
  Future<void> delete(String id) async {}
}

class _FakePoemRepository implements PoemRepository {
  _FakePoemRepository(this.poem);

  final Poem poem;

  @override
  Future<Poem?> byId(String id) async => id == poem.id ? poem : null;

  @override
  Future<Poem?> randomOne() async => poem;

  @override
  Future<List<Poem>> listByDynastyAndType({
    String? dynasty,
    String? type,
    int limit = 50,
    int offset = 0,
  }) async => [poem];

  @override
  Future<List<Poem>> search(
    String query, {
    int limit = 50,
    int offset = 0,
  }) async => query.trim().isEmpty ? [] : [poem];

  @override
  Future<int> countAll() async => 1;
}

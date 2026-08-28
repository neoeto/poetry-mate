// 个人注本编辑与危险操作 widget 测试。
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:poetry_mate/data/providers.dart';
import 'package:poetry_mate/data/repositories/notebook_repository.dart';
import 'package:poetry_mate/domain/entities/notebook_entry.dart';
import 'package:poetry_mate/features/reader/notebook_editor.dart';

void main() {
  final entry = NotebookEntry(
    id: 'entry-editor-test',
    poemId: 'poem-editor-test',
    kind: NotebookKind.lineNote,
    target: '1',
    content: {'translation': '原来的理解', 'notes': <Map<String, dynamic>>[]},
    persona: 'zhiyin',
    userEdited: false,
    createdAt: DateTime(2026, 1, 1),
    updatedAt: DateTime(2026, 1, 1),
  );

  late _FakeNotebookRepository repository;

  setUp(() {
    repository = _FakeNotebookRepository(entry);
  });

  Future<void> pumpEditor(
    WidgetTester tester, {
    NotebookEntry? value,
    _FakeNotebookRepository? valueRepository,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          notebookRepositoryProvider.overrideWithValue(
            valueRepository ?? repository,
          ),
        ],
        child: MaterialApp(
          home: Scaffold(body: NotebookEntryEditor(entry: value ?? entry)),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('保存编辑内容通过仓库置 user_edited', (tester) async {
    await pumpEditor(tester);

    await tester.enterText(find.byType(TextField), '这是我的新理解');
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();

    expect(repository.updatedEntry?.userEdited, isTrue);
    expect(repository.updatedEntry?.content['translation'], '这是我的新理解');
  });

  testWidgets('用户选词注本编辑修改解释并保留原词', (tester) async {
    final selected = NotebookEntry(
      id: 'selected-word-entry',
      poemId: 'poem-editor-test',
      kind: NotebookKind.wordNote,
      target: '0:0:1:孤',
      content: {
        'term': '孤',
        'explain': '原来的解释',
        'line_index': 0,
        'start': 0,
        'end': 1,
        'source': 'selected',
      },
      persona: 'zhiyin',
      userEdited: false,
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
    );
    final selectedRepository = _FakeNotebookRepository(selected);
    await pumpEditor(
      tester,
      value: selected,
      valueRepository: selectedRepository,
    );

    await tester.enterText(find.byType(TextField), '这是我的解释');
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();

    expect(selectedRepository.updatedEntry?.userEdited, isTrue);
    expect(selectedRepository.updatedEntry?.content['term'], '孤');
    expect(selectedRepository.updatedEntry?.content['explain'], '这是我的解释');
  });

  testWidgets('删除注本需要两次确认', (tester) async {
    await pumpEditor(tester);

    await tester.tap(find.text('删除'));
    await tester.pumpAndSettle();
    expect(find.text('删除这条注本？'), findsOneWidget);

    await tester.tap(find.text('继续删除'));
    await tester.pumpAndSettle();
    expect(find.text('再次确认删除'), findsOneWidget);

    await tester.tap(find.text('永久删除'));
    await tester.pumpAndSettle();
    expect(repository.deletedId, entry.id);
  });

  testWidgets('手写条目重生成先警告覆盖，再二次确认', (tester) async {
    bool? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: FilledButton(
              onPressed: () async {
                result = await confirmRegeneration(context, userEdited: true);
              },
              child: const Text('重新生成'),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('重新生成'));
    await tester.pumpAndSettle();
    expect(find.text('这条注本包含你的手写内容，继续会覆盖它。'), findsOneWidget);

    await tester.tap(find.text('继续'));
    await tester.pumpAndSettle();
    expect(find.text('最后确认覆盖手写内容'), findsOneWidget);

    await tester.tap(find.text('保留手写内容'));
    await tester.pumpAndSettle();
    expect(result, isFalse);
  });
}

class _FakeNotebookRepository implements NotebookRepository {
  _FakeNotebookRepository(this.entry);

  final NotebookEntry entry;
  NotebookEntry? updatedEntry;
  String? deletedId;

  @override
  Future<void> upsert(NotebookEntry value) async {}

  @override
  Future<NotebookEntry?> byTarget({
    required String poemId,
    required String kind,
    String? target,
  }) async => entry;

  @override
  Future<List<NotebookEntry>> byPoem(String poemId) async => [entry];

  @override
  Future<List<NotebookEntry>> listAll() async => [entry];

  @override
  Future<void> updateUserContent({
    required String id,
    required Map<String, dynamic> content,
    required int updatedAtMs,
  }) async {
    updatedEntry = NotebookEntry(
      id: entry.id,
      poemId: entry.poemId,
      kind: entry.kind,
      target: entry.target,
      content: content,
      persona: entry.persona,
      userEdited: true,
      createdAt: entry.createdAt,
      updatedAt: DateTime.fromMillisecondsSinceEpoch(updatedAtMs),
    );
  }

  @override
  Future<void> delete(String id) async => deletedId = id;
}

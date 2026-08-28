// 本地诗词搜索页 Widget 测试。
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:poetry_mate/data/repositories/poem_repository.dart';
import 'package:poetry_mate/domain/entities/poem.dart';
import 'package:poetry_mate/features/browse/poem_search_delegate.dart';

void main() {
  final poems = [
    _poem(
      id: 'p1',
      title: '静夜思',
      author: '李白',
      paragraphs: const ['床前明月光。', '疑是地上霜。'],
    ),
    _poem(id: 'p2', title: '水调歌头', author: '苏轼', paragraphs: const ['明月几时有。']),
  ];

  late _FakePoemRepository repository;

  setUp(() {
    repository = _FakePoemRepository(poems);
  });

  Future<void> openSearch(
    WidgetTester tester, {
    void Function(Poem?)? onResult,
  }) async {
    await tester.pumpWidget(
      _SearchHost(repository: repository, onResult: onResult),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('open-search')));
    await tester.pumpAndSettle();
  }

  testWidgets('输入关键词显示结果并返回选中的诗', (tester) async {
    Poem? selected;
    await openSearch(tester, onResult: (poem) => selected = poem);

    expect(find.text('输入诗名、作者、词牌或诗句'), findsOneWidget);
    await tester.enterText(find.byType(TextField), '静夜思');
    await tester.pumpAndSettle();

    expect(find.text('静夜思'), findsNWidgets(2));
    expect(find.textContaining('李白 · 唐'), findsOneWidget);
    expect(repository.queries, contains('静夜思'));

    await tester.tap(find.text('静夜思').first);
    await tester.pumpAndSettle();

    expect(selected?.id, 'p1');
  });

  testWidgets('没有匹配项时显示空态', (tester) async {
    await openSearch(tester);

    await tester.enterText(find.byType(TextField), '不存在的诗');
    await tester.pumpAndSettle();

    expect(find.text('未找到相关诗篇'), findsOneWidget);
    expect(find.text('换个诗名、作者或诗句试试'), findsOneWidget);
  });
}

class _SearchHost extends StatefulWidget {
  const _SearchHost({required this.repository, this.onResult});

  final PoemRepository repository;
  final void Function(Poem?)? onResult;

  @override
  State<_SearchHost> createState() => _SearchHostState();
}

class _SearchHostState extends State<_SearchHost> {
  Poem? _selected;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(_selected?.displayTitle ?? '尚未选择'),
                FilledButton(
                  key: const ValueKey('open-search'),
                  onPressed: () async {
                    final result = await showSearch<Poem>(
                      context: context,
                      delegate: PoemSearchDelegate(widget.repository),
                    );
                    if (!mounted) return;
                    setState(() => _selected = result);
                    widget.onResult?.call(result);
                  },
                  child: const Text('搜索'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FakePoemRepository implements PoemRepository {
  _FakePoemRepository(this.poems);

  final List<Poem> poems;
  final List<String> queries = [];

  @override
  Future<Poem?> byId(String id) async =>
      poems.where((poem) => poem.id == id).firstOrNull;

  @override
  Future<Poem?> randomOne() async => poems.firstOrNull;

  @override
  Future<List<Poem>> listByDynastyAndType({
    String? dynasty,
    String? type,
    int limit = 50,
    int offset = 0,
  }) async => poems;

  @override
  Future<List<Poem>> search(
    String query, {
    int limit = 50,
    int offset = 0,
  }) async {
    queries.add(query);
    final keyword = query.trim();
    if (keyword.isEmpty) return [];
    return poems
        .where(
          (poem) =>
              poem.displayTitle.contains(keyword) ||
              poem.author.contains(keyword) ||
              poem.bodyText.contains(keyword),
        )
        .skip(offset)
        .take(limit)
        .toList();
  }

  @override
  Future<int> countAll() async => poems.length;
}

Poem _poem({
  required String id,
  required String title,
  required String author,
  required List<String> paragraphs,
}) {
  return Poem(
    id: id,
    author: author,
    title: title,
    dynasty: '唐',
    type: 'shi',
    paragraphs: paragraphs,
    preface: null,
    rhythmic: null,
    popularity: 10,
    rawText: paragraphs,
    tags: null,
    sourceCollection: 'test',
  );
}

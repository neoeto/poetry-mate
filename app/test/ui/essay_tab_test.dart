// L2 赏析页签 widget 测试：延迟请求、骨架、结构化内容与缓存态。
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:poetry_mate/core/llm/annotation_service.dart';
import 'package:poetry_mate/core/llm/llm_client.dart';
import 'package:poetry_mate/core/llm/llm_config.dart';
import 'package:poetry_mate/core/llm/llm_transport.dart';
import 'package:poetry_mate/core/llm/persona.dart';
import 'package:poetry_mate/data/preferences/reading_prefs.dart';
import 'package:poetry_mate/data/providers.dart';
import 'package:poetry_mate/data/repositories/notebook_repository.dart';
import 'package:poetry_mate/domain/entities/annotations.dart';
import 'package:poetry_mate/domain/entities/notebook_entry.dart';
import 'package:poetry_mate/domain/entities/poem.dart';
import 'package:poetry_mate/features/reader/reader_page.dart';

import '../data/fixtures.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late InMemoryReadingPrefs readingPrefs;

  setUp(() {
    readingPrefs = InMemoryReadingPrefs();
  });

  Future<void> pumpReader(
    WidgetTester tester,
    Poem poem,
    _FakeAnnotationService annotationService,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          readingPrefsProvider.overrideWithValue(readingPrefs),
          annotationServiceProvider.overrideWithValue(annotationService),
        ],
        child: MaterialApp(
          home: Scaffold(body: ReaderPage(poem: poem)),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('首次切换赏析才请求，骨架完成后渲染结构化内容', (tester) async {
    final completer = Completer<EssayContent>();
    final service = _FakeAnnotationService(completer.future);
    final poem = testPoem(paragraphs: ['床前明月光，']);
    await pumpReader(tester, poem, service);

    expect(service.essayCalls, 0);
    expect(find.text('大意'), findsNothing);

    await tester.tap(find.text('赏析'));
    await tester.pumpAndSettle();
    expect(service.essayCalls, 1);
    expect(find.byKey(const ValueKey('essay-skeleton')), findsOneWidget);
    expect(find.text('正在生成赏析…'), findsOneWidget);

    completer.complete(
      const EssayContent(
        summary: '游子思乡',
        craft: [EssayCraftItem(point: '疑字', detail: '以幻写真')],
        mood: '静夜意境',
        emotion: '思乡清愁',
        background: EssayBackground(text: '背景无定论', uncertain: true),
        wordNotes: [
          WordNote(
            term: '床前',
            pinyin: 'chuáng qián',
            explain: '床的前面，点出月光所照的位置。',
            lineIndex: 0,
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('大意'), findsOneWidget);
    expect(find.text('游子思乡'), findsOneWidget);
    expect(find.text('炼字与手法'), findsOneWidget);
    expect(find.text('疑字'), findsOneWidget);
    expect(find.text('以幻写真'), findsOneWidget);
    expect(find.text('词语解释'), findsOneWidget);
    expect(find.textContaining('床前（chuáng qián）：床的前面'), findsOneWidget);
    expect(find.text('意境'), findsOneWidget);
    expect(find.text('静夜意境'), findsOneWidget);
    expect(find.text('情感'), findsOneWidget);
    expect(find.text('思乡清愁'), findsOneWidget);
    expect(find.text('创作背景'), findsOneWidget);
    expect(find.text('背景无定论'), findsOneWidget);
    expect(find.text('史料不详，仅供参考'), findsOneWidget);

    await tester.tap(find.text('原文'));
    await tester.pumpAndSettle();
    expect(find.text('带下划线的词语可点击查看释义'), findsNothing);

    final lineRect = tester.getRect(find.byKey(const ValueKey('poem-line-0')));
    await tester.tapAt(Offset(lineRect.left + 18, lineRect.center.dy));
    await tester.pumpAndSettle();
    expect(find.text('词语释义'), findsOneWidget);
    expect(find.text('床前'), findsOneWidget);
    expect(find.text('拼音：chuáng qián'), findsOneWidget);
    expect(find.text('床的前面，点出月光所照的位置。'), findsOneWidget);
  });

  testWidgets('结构化解析失败时在赏析页降级展示模型原文', (tester) async {
    final completer = Completer<EssayContent>();
    final service = _FakeAnnotationService(completer.future);
    final poem = testPoem(paragraphs: ['床前明月光，']);
    await pumpReader(tester, poem, service);

    await tester.tap(find.text('赏析'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('essay-skeleton')), findsOneWidget);

    completer.completeError(const AnnotationParseException('模型给出的普通文字'));
    await tester.pumpAndSettle();

    expect(find.text('结构化解析失败，先展示模型原文'), findsOneWidget);
    expect(find.text('模型给出的普通文字'), findsOneWidget);
  });

  testWidgets('切回原文再回赏析: 同一页签实例不重复请求', (tester) async {
    final service = _FakeAnnotationService(
      Future.value(
        const EssayContent(
          summary: '大意',
          craft: [],
          mood: '意境',
          background: EssayBackground(text: '', uncertain: true),
        ),
      ),
    );
    final poem = testPoem(paragraphs: ['床前明月光，']);
    await pumpReader(tester, poem, service);

    await tester.tap(find.text('赏析'));
    await tester.pumpAndSettle();
    expect(service.essayCalls, 1);

    await tester.tap(find.text('原文'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('赏析'));
    await tester.pumpAndSettle();

    expect(find.text('意境'), findsNWidgets(2));
    expect(service.essayCalls, 1);
  });
}

class _FakeAnnotationService extends AnnotationService {
  _FakeAnnotationService(this.essayFuture)
    : super(
        notebookRepository: _NoopNotebookRepository(),
        llmClient: LlmClient(
          configStore: _NoopConfigStore(),
          transport: _NoopTransport(),
        ),
        personaService: PersonaService(
          assets: rootBundle,
          prefs: InMemoryPrefsStore(),
        ),
      );

  final Future<EssayContent> essayFuture;
  int essayCalls = 0;

  @override
  Future<EssayContent> getOrCreateEssay(
    Poem poem, {
    bool forceRegenerate = false,
    String? personaId,
  }) {
    essayCalls++;
    return essayFuture;
  }
}

class _NoopConfigStore implements LlmConfigStore {
  @override
  Future<LlmConfig?> read() async => null;

  @override
  Future<void> write(LlmConfig config) async {}

  @override
  Future<void> clear() async {}
}

class _NoopTransport implements LlmTransport {
  @override
  Future<Map<String, dynamic>> postJson(
    Uri url,
    Map<String, String> headers,
    Map<String, dynamic> body,
  ) async => {};

  @override
  Stream<List<int>> postStream(
    Uri url,
    Map<String, String> headers,
    Map<String, dynamic> body,
  ) async* {}
}

class _NoopNotebookRepository implements NotebookRepository {
  @override
  Future<void> upsert(NotebookEntry entry) async {}

  @override
  Future<NotebookEntry?> byTarget({
    required String poemId,
    required String kind,
    String? target,
  }) async => null;

  @override
  Future<List<NotebookEntry>> byPoem(String poemId) async => [];

  @override
  Future<List<NotebookEntry>> listAll() async => [];

  @override
  Future<void> updateUserContent({
    required String id,
    required Map<String, dynamic> content,
    required int updatedAtMs,
  }) async {}

  @override
  Future<void> delete(String id) async {}
}

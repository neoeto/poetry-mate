import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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

void main() {
  final poem = const Poem(
    id: 'temporary-external-poem',
    author: '作者不详',
    title: '临时作品',
    dynasty: '近现代',
    type: 'modern_poem',
    paragraphs: ['月光落在窗前。'],
    preface: null,
    rhythmic: null,
    popularity: null,
    rawText: ['月光落在窗前。'],
    tags: null,
    sourceCollection: 'ai_extended',
  );

  testWidgets('外部作品复用阅读页并展示来源提示', (tester) async {
    final service = _FakeAnnotationService();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          annotationServiceProvider.overrideWithValue(service),
          readingPrefsProvider.overrideWithValue(InMemoryReadingPrefs()),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: ReaderPage(
              poem: poem,
              annotationContext: AnnotationContext.transient(),
              sourceInfo: const PoemSourceInfo(
                label: 'AI 补充作品',
                source: '来源待核',
                confidence: 'uncertain',
                uncertainFields: {'source'},
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('AI 补充作品 · 出处：来源待核 · 部分信息待核，仅供参考'), findsOneWidget);

    await tester.tap(find.text('月光落在窗前。'));
    await tester.pumpAndSettle();
    expect(find.text('白话'), findsOneWidget);
    expect(find.text('编辑注本'), findsNothing);
    expect(service.lineCalls, 1);

    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();
    await tester.tap(find.text('赏析'));
    await tester.pumpAndSettle();
    expect(find.text('临时赏析'), findsOneWidget);
    expect(find.text('编辑注本'), findsNothing);
    expect(service.essayCalls, 1);
  });
}

class _FakeAnnotationService extends AnnotationService {
  _FakeAnnotationService()
    : super(
        notebookRepository: _NoopNotebookRepository(),
        llmClient: LlmClient(
          configStore: _NoopConfigStore(),
          transport: _NoopTransport(),
        ),
        personaService: PersonaService(
          assets: _NoopAssetBundle(),
          prefs: InMemoryPrefsStore(),
        ),
      );

  var lineCalls = 0;
  var essayCalls = 0;

  @override
  Future<List<WordNote>> cachedWordNotes(
    Poem poem, {
    AnnotationContext context = const AnnotationContext.persistent(),
  }) async => [];

  @override
  Stream<AnnotationEvent<LineNoteContent>> streamLineNote(
    Poem poem,
    int lineIndex, {
    bool forceRegenerate = false,
    String? personaId,
    AnnotationContext context = const AnnotationContext.persistent(),
  }) async* {
    lineCalls++;
    yield const AnnotationDone(
      LineNoteContent(translation: '月光照在窗前。', notes: []),
    );
  }

  @override
  Stream<AnnotationEvent<EssayContent>> streamEssay(
    Poem poem, {
    bool forceRegenerate = false,
    String? personaId,
    AnnotationContext context = const AnnotationContext.persistent(),
  }) async* {
    essayCalls++;
    yield const AnnotationDone(
      EssayContent(
        summary: '临时赏析',
        craft: [],
        mood: '清冷',
        background: EssayBackground(text: '', uncertain: true),
      ),
    );
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

class _NoopAssetBundle extends AssetBundle {
  @override
  Future<ByteData> load(String key) async => ByteData(0);
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

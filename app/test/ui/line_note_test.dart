// L1 点句即释 widget 测试：点击生成、缓存命中、无 Key 引导。
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:poetry_mate/core/llm/annotation_service.dart';
import 'package:poetry_mate/core/llm/llm_client.dart';
import 'package:poetry_mate/core/llm/llm_config.dart';
import 'package:poetry_mate/core/llm/persona.dart';
import 'package:poetry_mate/core/llm/secure_key_store.dart';
import 'package:poetry_mate/data/preferences/reading_prefs.dart';
import 'package:poetry_mate/data/providers.dart';
import 'package:poetry_mate/data/repositories/notebook_repository.dart';
import 'package:poetry_mate/domain/entities/notebook_entry.dart';
import 'package:poetry_mate/domain/entities/poem.dart';
import 'package:poetry_mate/features/reader/reader_page.dart';

import '../data/fixtures.dart';
import '../fakes/scripted_transport.dart';

const _lineNoteResponse = {
  'choices': [
    {
      'message': {
        'content':
            '{"translation":"月光洒在床前","notes":[{"term":"疑","explain":"好像"}]}'
      }
    }
  ]
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late InMemoryReadingPrefs readingPrefs;
  late ScriptedTransport transport;
  late _MemoryNotebookRepository notebook;
  late AnnotationService service;

  setUp(() async {
    readingPrefs = InMemoryReadingPrefs();
    transport = ScriptedTransport(jsonResult: _lineNoteResponse);
    notebook = _MemoryNotebookRepository();

    final prefs = InMemoryPrefsStore()
      ..values['llm_base_url'] = 'https://api.test.com/v1'
      ..values['llm_model'] = 'test-model';
    final secure = InMemorySecureKeyStore();
    await secure.write('llm_api_key', 'sk-test');
    final configStore = LlmConfigStoreImpl(
      secureKeyStore: secure,
      prefs: prefs,
    );
    service = AnnotationService(
      notebookRepository: notebook,
      llmClient: LlmClient(
        configStore: configStore,
        transport: transport,
      ),
      personaService: PersonaService(
        assets: _TestAssetBundle(),
        prefs: prefs,
      ),
    );
  });

  Future<void> pumpReader(WidgetTester tester, Poem poem,
      {AnnotationService? annotationService}) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          readingPrefsProvider.overrideWithValue(readingPrefs),
          annotationServiceProvider
              .overrideWithValue(annotationService ?? service),
        ],
        child: MaterialApp(
          home: Scaffold(body: ReaderPage(poem: poem)),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('点击诗句生成直译与关键词注', (tester) async {
    final poem = testPoem(paragraphs: ['床前明月光，']);
    await pumpReader(tester, poem);

    await tester.tap(find.text('床前明月光，'));
    await tester.pumpAndSettle();

    expect(find.text('逐句即释 · 第 1 句'), findsOneWidget);
    expect(find.text('白话'), findsOneWidget);
    expect(find.text('月光洒在床前'), findsOneWidget);
    expect(find.textContaining('疑：好像'), findsOneWidget);
    expect(transport.callCount, 1);

    await tester.tap(find.byTooltip('关闭'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('关闭'), findsNothing);
  });

  testWidgets('关闭后再次点击同一句命中缓存，不重复请求', (tester) async {
    final poem = testPoem(paragraphs: ['床前明月光，']);
    await pumpReader(tester, poem);

    await tester.tap(find.text('床前明月光，'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('关闭'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('床前明月光，'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('月光洒在床前'), findsOneWidget);
    expect(transport.callCount, 1);
    await tester.tap(find.byTooltip('关闭'));
    await tester.pumpAndSettle();
  });

  testWidgets('结构化解析失败后展示模型原文降级态', (tester) async {
    transport.jsonQueue.addAll([
      {'choices': [{'message': {'content': '第一份非 JSON'}}]},
      {'choices': [{'message': {'content': '第二份非 JSON'}}]},
    ]);
    final poem = testPoem(paragraphs: ['床前明月光，']);
    await pumpReader(tester, poem);

    await tester.tap(find.text('床前明月光，'));
    await tester.pumpAndSettle();

    expect(find.text('结构化解析失败，先展示模型原文'), findsOneWidget);
    expect(find.text('第二份非 JSON'), findsOneWidget);
    expect(transport.callCount, 2);
    await tester.tap(find.byTooltip('关闭'));
    await tester.pumpAndSettle();
  });

  testWidgets('HTTP 鉴权失败展示具体原因', (tester) async {
    transport.statusError = 401;
    final poem = testPoem(paragraphs: ['床前明月光，']);
    await pumpReader(tester, poem);

    await tester.tap(find.text('床前明月光，'));
    await tester.pumpAndSettle();

    expect(find.text('密钥无效'), findsOneWidget);
    expect(find.textContaining('boom'), findsOneWidget);
    await tester.tap(find.byTooltip('关闭'));
    await tester.pumpAndSettle();
  });

  testWidgets('无 Key 时展示引导态而非错误堆栈', (tester) async {
    final emptyPrefs = InMemoryPrefsStore();
    final noKeyService = AnnotationService(
      notebookRepository: _MemoryNotebookRepository(),
      llmClient: LlmClient(
        configStore: LlmConfigStoreImpl(
          secureKeyStore: InMemorySecureKeyStore(),
          prefs: emptyPrefs,
        ),
        transport: ScriptedTransport(jsonResult: _lineNoteResponse),
      ),
      personaService: PersonaService(
        assets: _TestAssetBundle(),
        prefs: emptyPrefs,
      ),
    );
    final poem = testPoem(paragraphs: ['床前明月光，']);
    await pumpReader(tester, poem, annotationService: noKeyService);

    await tester.tap(find.text('床前明月光，'));
    await tester.pumpAndSettle();

    expect(find.text('还没有配置 AI'), findsOneWidget);
    expect(find.text('去「我的」配置'), findsOneWidget);
    expect(find.textContaining('LlmException'), findsNothing);
    await tester.tap(find.byTooltip('关闭'));
    await tester.pumpAndSettle();
  });
}

class _TestAssetBundle extends AssetBundle {
  @override
  Future<ByteData> load(String key) async {
    return ByteData.sublistView(
      Uint8List.fromList(utf8.encode('test persona prompt')),
    );
  }
}

class _MemoryNotebookRepository implements NotebookRepository {
  final Map<String, NotebookEntry> _entries = {};

  @override
  Future<void> upsert(NotebookEntry entry) async => _entries[entry.id] = entry;

  @override
  Future<NotebookEntry?> byTarget({
    required String poemId,
    required String kind,
    String? target,
  }) async {
    for (final entry in _entries.values) {
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
      _entries.values.where((entry) => entry.poemId == poemId).toList();

  @override
  Future<List<NotebookEntry>> listAll() async => _entries.values.toList();

  @override
  Future<void> updateUserContent({
    required String id,
    required Map<String, dynamic> content,
    required int updatedAtMs,
  }) async {
    final entry = _entries[id];
    if (entry == null) return;
    _entries[id] = NotebookEntry(
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
  Future<void> delete(String id) async => _entries.remove(id);
}

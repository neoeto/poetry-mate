// L1 点句即释 widget 测试：点击生成、缓存命中、无 Key 引导。
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:poetry_mate/core/llm/annotation_service.dart';
import 'package:poetry_mate/core/llm/llm_client.dart';
import 'package:poetry_mate/core/llm/llm_config.dart';
import 'package:poetry_mate/core/llm/llm_transport.dart';
import 'package:poetry_mate/core/llm/persona.dart';
import 'package:poetry_mate/core/llm/secure_key_store.dart';
import 'package:poetry_mate/data/preferences/reading_prefs.dart';
import 'package:poetry_mate/data/providers.dart';
import 'package:poetry_mate/data/repositories/notebook_repository.dart';
import 'package:poetry_mate/domain/entities/annotations.dart';
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
            '{"translation":"月光洒在床前","notes":[{"term":"疑","pinyin":"yí","explain":"好像"}]}',
      },
    },
  ],
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
      llmClient: LlmClient(configStore: configStore, transport: transport),
      personaService: PersonaService(assets: _TestAssetBundle(), prefs: prefs),
    );
  });

  Future<void> pumpReader(
    WidgetTester tester,
    Poem poem, {
    AnnotationService? annotationService,
    bool settle = true,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          readingPrefsProvider.overrideWithValue(readingPrefs),
          notebookRepositoryProvider.overrideWithValue(notebook),
          annotationServiceProvider.overrideWithValue(
            annotationService ?? service,
          ),
        ],
        child: MaterialApp(
          home: Scaffold(body: ReaderPage(poem: poem)),
        ),
      ),
    );
    if (settle) await tester.pumpAndSettle();
  }

  testWidgets('点击诗句生成直译与关键词注', (tester) async {
    final poem = testPoem(paragraphs: ['床前明月光，']);
    await pumpReader(tester, poem);

    await tester.tap(find.text('床前明月光，'));
    await tester.pumpAndSettle();

    expect(find.text('逐句即释 · 第 1 句'), findsOneWidget);
    expect(find.text('白话'), findsOneWidget);
    expect(find.text('月光洒在床前'), findsOneWidget);
    expect(find.textContaining('疑（yí）：好像'), findsOneWidget);
    expect(transport.callCount, 1);

    await tester.tap(find.byTooltip('关闭'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('关闭'), findsNothing);
  });

  testWidgets('逐句关键词显示拼音并在原文中可点击', (tester) async {
    final poem = testPoem(paragraphs: ['疑是地上霜。']);
    await pumpReader(tester, poem);

    await tester.tap(find.text('疑是地上霜。'));
    await tester.pumpAndSettle();
    expect(find.textContaining('疑（yí）：好像'), findsOneWidget);

    await tester.tap(find.byTooltip('关闭'));
    await tester.pumpAndSettle();
    final paragraph = tester.renderObject<RenderParagraph>(
      find.descendant(
        of: find.byKey(const ValueKey('poem-line-0')),
        matching: find.byType(RichText),
      ),
    );
    final box = paragraph
        .getBoxesForSelection(
          const TextSelection(baseOffset: 0, extentOffset: 1),
        )
        .single
        .toRect();
    await tester.tapAt(paragraph.localToGlobal(box.center));
    await tester.pumpAndSettle();

    expect(find.text('词语释义'), findsOneWidget);
    expect(find.text('拼音：yí'), findsOneWidget);
    expect(find.text('好像'), findsOneWidget);
  });

  testWidgets('已有逐句注缓存恢复关键词标记', (tester) async {
    final poem = testPoem(paragraphs: ['疑是地上霜。']);
    final entry = NotebookEntry(
      id: notebookEntryId(
        poemId: poem.id,
        kind: NotebookKind.lineNote,
        target: '0',
      ),
      poemId: poem.id,
      kind: NotebookKind.lineNote,
      target: '0',
      content: {
        'translation': '好像是地上的霜',
        'notes': [
          {'term': '疑', 'pinyin': 'yí', 'explain': '好像'},
        ],
      },
      persona: 'zhiyin',
      userEdited: false,
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );
    await notebook.upsert(entry);
    await pumpReader(tester, poem);

    final paragraph = tester.renderObject<RenderParagraph>(
      find.descendant(
        of: find.byKey(const ValueKey('poem-line-0')),
        matching: find.byType(RichText),
      ),
    );
    final box = paragraph
        .getBoxesForSelection(
          const TextSelection(baseOffset: 0, extentOffset: 1),
        )
        .single
        .toRect();
    await tester.tapAt(paragraph.localToGlobal(box.center));
    await tester.pumpAndSettle();

    expect(find.text('词语释义'), findsOneWidget);
    expect(find.text('拼音：yí'), findsOneWidget);
    expect(transport.callCount, 0);
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

  testWidgets('长按正文选择词语显示 AI 解释菜单', (tester) async {
    transport.jsonResult = {
      'choices': [
        {
          'message': {
            'content': '{"term":"灯","pinyin":"dēng","explain":"照明用的器具。"}',
          },
        },
      ],
    };
    final poem = testPoem(paragraphs: ['孤灯不明思欲绝。']);
    await pumpReader(tester, poem);

    final paragraph = tester.renderObject<RenderParagraph>(
      find.descendant(
        of: find.byKey(const ValueKey('poem-line-0')),
        matching: find.byType(RichText),
      ),
    );
    final localPosition = paragraph.getOffsetForCaret(
      const TextPosition(offset: 1),
      Rect.zero,
    );
    await tester.longPressAt(paragraph.localToGlobal(localPosition));
    await tester.pumpAndSettle();

    expect(paragraph.selections, isNotEmpty);
    expect(find.text('AI 解释'), findsOneWidget);

    await tester.tap(find.text('AI 解释'));
    await tester.pumpAndSettle();
    expect(find.text('已选择「灯」'), findsOneWidget);
    expect(find.text('拼音：dēng'), findsOneWidget);
    expect(find.text('照明用的器具。'), findsOneWidget);
    expect(transport.callCount, 1);

    await tester.tap(find.byTooltip('关闭'));
    await tester.pumpAndSettle();
    final markedParagraph = tester.renderObject<RenderParagraph>(
      find.descendant(
        of: find.byKey(const ValueKey('poem-line-0')),
        matching: find.byType(RichText),
      ),
    );
    final markedBox = markedParagraph
        .getBoxesForSelection(
          const TextSelection(baseOffset: 1, extentOffset: 2),
        )
        .single
        .toRect();
    await tester.tapAt(markedParagraph.localToGlobal(markedBox.center));
    await tester.pumpAndSettle();
    expect(find.text('我选的词'), findsOneWidget);
    expect(find.text('照明用的器具。'), findsOneWidget);
    expect(find.text('编辑注本'), findsOneWidget);
    expect(find.text('重新生成'), findsOneWidget);
  });

  testWidgets('结构化解析失败后展示模型原文降级态', (tester) async {
    transport.sseQueue.addAll([
      _sseForPieces(['第一份非 JSON']),
      _sseForPieces(['第二份非 JSON']),
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

  testWidgets('流式生成时直译先出,关键词注逐条出现', (tester) async {
    final controller = StreamController<AnnotationEvent<LineNoteContent>>();
    final service = _FakeLineStreamingService(controller.stream);
    final poem = testPoem(paragraphs: ['床前明月光，']);
    await pumpReader(tester, poem, annotationService: service, settle: false);

    await tester.tap(find.text('床前明月光，'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('正在为这一句寻找合适的说法…'), findsOneWidget);

    controller.add(
      const AnnotationPartial<LineNoteContent>(
        LineNoteContent(translation: '先到的直译', notes: []),
        closedKeys: {'translation'},
        pendingKeys: {'notes'},
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('白话'), findsOneWidget);
    expect(find.text('先到的直译'), findsOneWidget);
    expect(find.text('关键词注'), findsOneWidget);
    expect(find.text('生成中…'), findsOneWidget);
    expect(find.text('编辑注本'), findsNothing);

    controller.add(
      const AnnotationPartial<LineNoteContent>(
        LineNoteContent(
          translation: '先到的直译',
          notes: [KeywordNote(term: '疑', explain: '好像', pinyin: 'yí')],
        ),
        closedKeys: {'translation'},
        pendingKeys: {'notes'},
      ),
    );
    await tester.pump();
    await tester.pump();
    expect(find.textContaining('疑（yí）：好像'), findsOneWidget);

    controller.add(
      const AnnotationDone<LineNoteContent>(
        LineNoteContent(
          translation: '最终直译',
          notes: [KeywordNote(term: '疑', explain: '好像', pinyin: 'yí')],
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    expect(find.text('最终直译'), findsOneWidget);
    expect(find.text('重新生成'), findsOneWidget);

    await controller.close();
    await tester.tap(find.byTooltip('关闭'));
    await tester.pumpAndSettle();
  });

  testWidgets('关闭逐句注浮层时取消流式订阅', (tester) async {
    var cancelled = false;
    final controller = StreamController<AnnotationEvent<LineNoteContent>>(
      onCancel: () {
        cancelled = true;
      },
    );
    final service = _FakeLineStreamingService(controller.stream);
    final poem = testPoem(paragraphs: ['床前明月光，']);
    await pumpReader(tester, poem, annotationService: service, settle: false);

    await tester.tap(find.text('床前明月光，'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();

    expect(cancelled, isTrue);
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

String _sseForPieces(List<String> pieces) {
  final frames = [
    for (final piece in pieces)
      'data: ${jsonEncode({
        'choices': [
          {
            'delta': {'content': piece},
          },
        ],
      })}',
    'data: [DONE]',
  ];
  return '${frames.join('\n')}\n';
}

class _FakeLineStreamingService extends AnnotationService {
  _FakeLineStreamingService(this.lineStream)
    : super(
        notebookRepository: _MemoryNotebookRepository(),
        llmClient: LlmClient(
          configStore: _NoopConfigStore(),
          transport: _NoopTransport(),
        ),
        personaService: PersonaService(
          assets: _TestAssetBundle(),
          prefs: InMemoryPrefsStore(),
        ),
      );

  final Stream<AnnotationEvent<LineNoteContent>> lineStream;
  var lineCalls = 0;

  @override
  Stream<AnnotationEvent<LineNoteContent>> streamLineNote(
    Poem poem,
    int lineIndex, {
    bool forceRegenerate = false,
    String? personaId,
    AnnotationContext context = const AnnotationContext.persistent(),
  }) {
    lineCalls++;
    return lineStream;
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

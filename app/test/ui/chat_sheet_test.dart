// L3 追问对话 widget 测试：SSE 拼接、fallback 替换、无 Key 引导。
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:poetry_mate/core/llm/annotation_service.dart';
import 'package:poetry_mate/core/llm/llm_client.dart';
import 'package:poetry_mate/core/llm/llm_config.dart';
import 'package:poetry_mate/core/llm/llm_exception.dart';
import 'package:poetry_mate/core/llm/llm_transport.dart';
import 'package:poetry_mate/core/llm/persona.dart';
import 'package:poetry_mate/data/providers.dart';
import 'package:poetry_mate/data/repositories/notebook_repository.dart';
import 'package:poetry_mate/domain/entities/annotations.dart';
import 'package:poetry_mate/domain/entities/notebook_entry.dart';
import 'package:poetry_mate/domain/entities/poem.dart';
import 'package:poetry_mate/features/reader/chat_sheet.dart';

import '../data/fixtures.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final poem = testPoem(paragraphs: ['床前明月光，']);

  Future<void> pumpChat(
    WidgetTester tester,
    _FakeChatService service,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [annotationServiceProvider.overrideWithValue(service)],
        child: MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: FilledButton(
                  onPressed: () => showChatSheet(context, poem: poem),
                  child: const Text('打开对话'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('打开对话'));
    await tester.pumpAndSettle();
  }

  testWidgets('提问后按 SSE 增量拼接回答，并携带问题上下文', (tester) async {
    final service = _FakeChatService([
      const ChatDelta('先看'),
      const ChatDelta('这一句'),
    ]);
    await pumpChat(tester, service);

    await tester.enterText(find.byType(TextField), '为什么写月光？');
    await tester.tap(find.byIcon(Icons.send));
    await tester.pumpAndSettle();

    expect(find.text('为什么写月光？'), findsOneWidget);
    expect(find.text('先看这一句'), findsOneWidget);
    expect(service.calls, 1);
    expect(service.lastPoem?.bodyText, poem.bodyText);
    expect(service.lastQuestion, '为什么写月光？');
  });

  testWidgets('助手回答按 Markdown 格式渲染', (tester) async {
    final service = _FakeChatService([
      const ChatDelta('# 意境\n\n**月光**映在窗前。\n\n- 清冷\n- 宁静'),
    ]);
    await pumpChat(tester, service);

    await tester.enterText(find.byType(TextField), '请分析意境');
    await tester.tap(find.byIcon(Icons.send));
    await tester.pumpAndSettle();

    expect(find.byType(MarkdownBody), findsOneWidget);
    final markdown = tester.widget<MarkdownBody>(find.byType(MarkdownBody));
    expect(markdown.softLineBreak, isTrue);
    expect(markdown.data, contains('**月光**'));

    final renderedText = tester
        .widgetList<RichText>(find.byType(RichText))
        .map((widget) => widget.text.toPlainText())
        .join('\\n');
    expect(renderedText, contains('月光映在窗前。'));
    expect(renderedText, contains('清冷'));
    expect(renderedText, isNot(contains('**')));
  });

  testWidgets('fallback replace=true 会替换半截流而非重复追加', (tester) async {
    final service = _FakeChatService([
      const ChatDelta('半截'),
      const ChatDelta('完整答案', replace: true),
    ]);
    await pumpChat(tester, service);

    await tester.enterText(find.byType(TextField), '请再说一遍');
    await tester.tap(find.byIcon(Icons.send));
    await tester.pumpAndSettle();

    expect(find.text('完整答案'), findsOneWidget);
    expect(find.text('半截'), findsNothing);
  });

  testWidgets('无 Key 时显示配置引导而不是原始异常', (tester) async {
    final service = _FakeChatService(
      const [],
      error: const LlmException(LlmErrorKind.noKey, '不要把这段展示给用户'),
    );
    await pumpChat(tester, service);

    await tester.enterText(find.byType(TextField), '可以问吗');
    await tester.tap(find.byIcon(Icons.send));
    await tester.pumpAndSettle();

    expect(find.text('还没有配置 AI'), findsOneWidget);
    expect(find.text('去配置'), findsOneWidget);
    expect(find.textContaining('不要把这段展示给用户'), findsNothing);
  });
}

class _FakeChatService extends AnnotationService {
  _FakeChatService(
    this.deltas, {
    this.error,
  }) : super(
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

  final List<ChatDelta> deltas;
  final Object? error;
  int calls = 0;
  Poem? lastPoem;
  String? lastQuestion;

  @override
  Stream<ChatDelta> streamQuestion(
    Poem poem,
    String question, {
    String? personaId,
    EssayContent? essay,
  }) async* {
    calls++;
    lastPoem = poem;
    lastQuestion = question;
    if (error != null) throw error!;
    for (final delta in deltas) {
      yield delta;
    }
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

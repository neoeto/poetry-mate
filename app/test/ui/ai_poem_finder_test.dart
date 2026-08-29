import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:poetry_mate/core/llm/llm_client.dart';
import 'package:poetry_mate/core/llm/llm_config.dart';
import 'package:poetry_mate/core/llm/llm_exception.dart';
import 'package:poetry_mate/core/llm/llm_transport.dart';
import 'package:poetry_mate/core/llm/persona.dart';
import 'package:poetry_mate/core/llm/poem_finder_service.dart';
import 'package:poetry_mate/data/providers.dart';
import 'package:poetry_mate/domain/entities/extended_poem.dart';
import 'package:poetry_mate/features/extended/ai_poem_finder_page.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('多轮寻诗结果展示结构化作品和两种查看动作', (tester) async {
    final service = _FakeFinderService(const [
      PoemFinderPartial('我找到一首。'),
      PoemFinderDone(
        AiPoemSearchResponse(
          status: AiPoemSearchResponse.found,
          reply: '我找到一首。',
          poem: ExtendedPoemDraft(
            title: '静夜思',
            author: '李白',
            period: '唐',
            genre: 'shi',
            paragraphs: ['床前明月光，', '疑是地上霜。'],
            source: '《全唐诗》',
            sourceConfidence: ExtendedPoemConfidence.known,
          ),
        ),
      ),
    ]);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [poemFinderServiceProvider.overrideWithValue(service)],
        child: MaterialApp(home: const AiPoemFinderPage()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), '想找一首写月夜的诗');
    await tester.tap(find.byIcon(Icons.send));
    await tester.pumpAndSettle();

    expect(find.text('静夜思'), findsOneWidget);
    expect(find.text('仅本次查看'), findsOneWidget);
    expect(find.text('加入扩展库'), findsOneWidget);
    expect(find.text('AI 补充作品'), findsNothing);
    expect(service.lastMessage, '想找一首写月夜的诗');
  });

  testWidgets('寻诗无 Key 时显示设置引导', (tester) async {
    final service = _FakeFinderService(
      const [],
      error: const LlmException(LlmErrorKind.noKey, 'test'),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [poemFinderServiceProvider.overrideWithValue(service)],
        child: MaterialApp(home: const AiPoemFinderPage()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), '找一首诗');
    await tester.tap(find.byIcon(Icons.send));
    await tester.pumpAndSettle();

    expect(find.text('还没有配置 AI'), findsOneWidget);
    expect(find.text('去配置'), findsOneWidget);
  });
}

class _FakeFinderService extends PoemFinderService {
  _FakeFinderService(this.events, {this.error})
    : super(
        llmClient: LlmClient(
          configStore: _NoopConfigStore(),
          transport: _NoopTransport(),
        ),
        personaService: PersonaService(
          assets: _NoopAssetBundle(),
          prefs: InMemoryPrefsStore(),
        ),
      );

  final List<PoemFinderEvent> events;
  final Object? error;
  String? lastMessage;

  @override
  Stream<PoemFinderEvent> streamTurn(
    PoemFinderSession session,
    String userMessage,
  ) async* {
    lastMessage = userMessage;
    if (error != null) throw error!;
    for (final event in events) {
      yield event;
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

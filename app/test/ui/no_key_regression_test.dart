// 无 Key 全流程回归：阅读、收藏、白文、字号可用；L1/L2/L3 均为引导态。
import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:poetry_mate/core/db/app_database.dart';
import 'package:poetry_mate/core/llm/annotation_service.dart';
import 'package:poetry_mate/core/llm/llm_client.dart';
import 'package:poetry_mate/core/llm/llm_config.dart';
import 'package:poetry_mate/core/llm/llm_transport.dart';
import 'package:poetry_mate/core/llm/persona.dart';
import 'package:poetry_mate/core/llm/secure_key_store.dart';
import 'package:poetry_mate/data/mappers/poem_mapper.dart';
import 'package:poetry_mate/data/preferences/reading_prefs.dart';
import 'package:poetry_mate/data/preferences/reading_settings_controller.dart';
import 'package:poetry_mate/data/providers.dart';
import 'package:poetry_mate/data/repositories/favorites_repository.dart';
import 'package:poetry_mate/data/repositories/notebook_repository.dart';
import 'package:poetry_mate/features/reader/chat_sheet.dart';
import 'package:poetry_mate/features/reader/poem_route_page.dart';

import '../data/fixtures.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late InMemoryReadingPrefs readingPrefs;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    readingPrefs = InMemoryReadingPrefs();
    final poem = testPoem(
      id: 'no-key-regression-poem',
      paragraphs: ['床前明月光，', '疑是地上霜。'],
    );
    await db.into(db.poems).insert(PoemMapper.toCompanion(poem));
  });

  tearDown(() => db.close());

  Future<void> pumpPage(WidgetTester tester) async {
    final prefs = InMemoryPrefsStore();
    final noKeyService = AnnotationService(
      notebookRepository: DriftNotebookRepository(db),
      llmClient: LlmClient(
        configStore: LlmConfigStoreImpl(
          secureKeyStore: InMemorySecureKeyStore(),
          prefs: prefs,
        ),
        transport: _NoopTransport(),
      ),
      personaService: PersonaService(
        assets: _TestAssetBundle(),
        prefs: prefs,
      ),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          readingPrefsProvider.overrideWithValue(readingPrefs),
          annotationServiceProvider.overrideWithValue(noKeyService),
        ],
        child: const MaterialApp(
          home: PoemRoutePage(poemId: 'no-key-regression-poem'),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('无 Key 仍可阅读、收藏、白文和字号调整', (tester) async {
    await pumpPage(tester);

    expect(find.text('　床前明月光，'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.favorite_border));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.favorite), findsOneWidget);
    expect(await DriftFavoritesRepository(db).isFavorite('no-key-regression-poem'),
        isTrue);

    await tester.tap(find.byIcon(Icons.text_format_outlined));
    await tester.pumpAndSettle();
    expect(find.text('　床前明月光'), findsOneWidget);
    expect(find.text('　床前明月光，'), findsNothing);

    final container = ProviderScope.containerOf(
      tester.element(find.byType(PoemRoutePage)),
    );
    await container.read(readingSettingsProvider.notifier).setFontSize(28);
    await tester.pumpAndSettle();
    expect(
      tester.widget<Text>(find.text('　床前明月光')).style?.fontSize,
      28,
    );
  });

  testWidgets('L1/L2/L3 无 Key 均为配置引导态', (tester) async {
    await pumpPage(tester);

    await tester.tap(find.text('　床前明月光，'));
    await tester.pumpAndSettle();
    expect(find.text('还没有配置 AI'), findsOneWidget);
    await tester.tap(find.byTooltip('关闭'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('赏析'));
    await tester.pumpAndSettle();
    expect(find.text('还没有配置 AI'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.chat_bubble_outline));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '这首诗在写什么？');
    await tester.tap(find.byIcon(Icons.send));
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: find.byType(ChatSheet),
        matching: find.text('还没有配置 AI'),
      ),
      findsOneWidget,
    );
  });
}

class _TestAssetBundle extends AssetBundle {
  @override
  Future<ByteData> load(String key) async => ByteData.sublistView(
        Uint8List.fromList('test persona'.codeUnits),
      );
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

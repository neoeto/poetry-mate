// AI 人格选择器 widget 测试。
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:poetry_mate/core/llm/persona.dart';
import 'package:poetry_mate/core/llm/prefs_store.dart';
import 'package:poetry_mate/data/preferences/reading_prefs.dart';
import 'package:poetry_mate/data/providers.dart';
import 'package:poetry_mate/features/settings/mine_page.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late InMemoryPrefsStore personaPrefs;
  late PersonaService personaService;

  setUp(() {
    personaPrefs = InMemoryPrefsStore();
    personaService = PersonaService(assets: rootBundle, prefs: personaPrefs);
  });

  Future<void> pumpMine(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          personaServiceProvider.overrideWithValue(personaService),
          readingPrefsProvider.overrideWithValue(InMemoryReadingPrefs()),
        ],
        child: const MaterialApp(home: MinePage()),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('默认知音，打开后可选择先生/知音/词客', (tester) async {
    await pumpMine(tester);

    expect(find.textContaining('知音 ·'), findsOneWidget);
    await tester.tap(find.text('AI 人格'));
    await tester.pumpAndSettle();

    expect(find.text('选择 AI 人格'), findsOneWidget);
    expect(find.text('先生'), findsOneWidget);
    expect(find.text('知音'), findsOneWidget);
    expect(find.text('词客'), findsOneWidget);

    await tester.tap(find.text('先生'));
    await tester.pumpAndSettle();

    expect(await personaService.selectedId(), 'xiansheng');
    expect(find.textContaining('先生 ·'), findsOneWidget);
  });
}

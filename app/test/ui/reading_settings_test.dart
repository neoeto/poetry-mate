// 「我的」页阅读字号滑杆 widget 测试。
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
  late InMemoryReadingPrefs prefs;

  setUp(() {
    prefs = InMemoryReadingPrefs();
  });

  Future<void> pumpMine(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          readingPrefsProvider.overrideWithValue(prefs),
          personaServiceProvider.overrideWithValue(
            PersonaService(
              assets: rootBundle,
              prefs: InMemoryPrefsStore(),
            ),
          ),
        ],
        child: const MaterialApp(home: MinePage()),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('字号滑杆读取已保存值并显示范围', (tester) async {
    await prefs.setContentFontSize(28);
    await pumpMine(tester);

    final slider = tester.widget<Slider>(find.byType(Slider));
    expect(slider.value, 28);
    expect(slider.min, 20);
    expect(slider.max, 32);
    expect(find.text('28sp'), findsOneWidget);
  });

  testWidgets('书架与注本入口已启用', (tester) async {
    await pumpMine(tester);

    expect(find.text('导入书架'), findsOneWidget);
    expect(find.text('我的注本'), findsOneWidget);
    expect(find.text('即将'), findsNothing);
  });

  testWidgets('拖动滑杆即时更新内存偏好', (tester) async {
    await pumpMine(tester);

    await tester.drag(find.byType(Slider), const Offset(120, 0));
    await tester.pumpAndSettle();

    expect(await prefs.contentFontSize(), greaterThan(24));
  });
}

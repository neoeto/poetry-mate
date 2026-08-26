// 简读页基线版式测试(任务 3.3)。
// 对应 specs/app-foundation「简读页排版基线」两个 Scenario + 样式契约。
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:poetry_mate/core/ui/app_theme.dart';
import 'package:poetry_mate/features/reader/reader_page.dart';

import '../data/fixtures.dart';

void main() {
  Future<void> pumpReader(WidgetTester tester, dynamic poem) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(body: ReaderPage(poem: poem)),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('五言绝句: 恰好四行,一句一行左对齐', (tester) async {
    final poem = testPoem(
      title: '静夜思',
      paragraphs: ['床前看月光，', '疑是地上霜。', '举头望山月，', '低头思故乡。'],
    );
    await pumpReader(tester, poem);

    for (final line in poem.paragraphs) {
      expect(find.text(line), findsOneWidget, reason: '缺行: $line');
    }
    // 左对齐
    final firstLine = tester.widget<Text>(find.text(poem.paragraphs.first));
    expect(firstLine.textAlign, TextAlign.left);
  });

  testWidgets('词的长短句逐行完整呈现', (tester) async {
    final poem = testPoem(
      type: 'ci',
      rhythmic: '水调歌头',
      title: null,
      paragraphs: [
        '明月几时有？把酒问青天。',
        '不知天上宫阙，今夕是何年。',
        '但愿人长久，千里共婵娟。',
      ],
    );
    await pumpReader(tester, poem);

    for (final line in poem.paragraphs) {
      expect(find.text(line), findsOneWidget);
    }
    // 词无题 → 词牌作为展示标题
    expect(find.text('水调歌头'), findsOneWidget);
  });

  testWidgets('正文样式契约: 文楷族 ≥22sp 行距≥1.9', (tester) async {
    final poem = testPoem(paragraphs: ['床前明月光。']);
    await pumpReader(tester, poem);

    final style = tester.widget<Text>(find.text('床前明月光。')).style!;
    expect(style.fontFamily, PoetryFonts.content);
    expect(style.fontSize, greaterThanOrEqualTo(22));
    expect(style.height, greaterThanOrEqualTo(1.9));
  });

  testWidgets('标题居中、落款偏右弱色', (tester) async {
    final poem = testPoem(title: '静夜思');
    await pumpReader(tester, poem);

    expect(
      tester.widget<Text>(find.text('静夜思')).textAlign,
      TextAlign.center,
    );
    final signature = tester.widget<Text>(find.text('李白 · 唐'));
    expect(signature.textAlign, TextAlign.right);
  });
}

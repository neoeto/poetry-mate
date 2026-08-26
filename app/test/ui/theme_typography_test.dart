// 双轨排版测试(任务 3.2): 内容族=文楷 / 界面族=系统,契约由样式对象钉死。
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:poetry_mate/core/ui/app_theme.dart';

void main() {
  // 用 MediaQuery 强制平台亮度,绕过测试环境默认 light 的干扰
  Future<(ThemeData, TextStyle)> _pumpAndGet(
    WidgetTester tester,
    TextStyle Function(BuildContext) styleOf,
    Brightness brightness,
  ) async {
    late ThemeData theme;
    late TextStyle style;
    final themeData =
        brightness == Brightness.light ? AppTheme.light() : AppTheme.dark();
    await tester.pumpWidget(
      MaterialApp(
        home: Theme(
          data: themeData,
          child: Builder(
            builder: (inner) {
              theme = Theme.of(inner);
              style = styleOf(inner);
              return const SizedBox.shrink();
            },
          ),
        ),
      ),
    );
    return (theme, style);
  }

  testWidgets('内容样式: 文楷族 + 大字号 + 宽行距', (tester) async {
    final (_, style) = await _pumpAndGet(
      tester,
      (c) => AppTheme.contentTextStyle(c),
      Brightness.light,
    );
    expect(style.fontFamily, PoetryFonts.content);
    expect(style.fontSize, 24);
    expect(style.height, greaterThanOrEqualTo(1.9));
  });

  testWidgets('内容样式允许覆写尺寸但不得换字体族', (tester) async {
    final (_, style) = await _pumpAndGet(
      tester,
      (c) => AppTheme.contentTextStyle(c, fontSize: 28),
      Brightness.light,
    );
    expect(style.fontFamily, PoetryFonts.content);
    expect(style.fontSize, 28);
  });

  testWidgets('界面样式: 字体族不得是文楷(双轨契约)', (tester) async {
    final (theme, style) = await _pumpAndGet(
      tester,
      (c) => AppTheme.uiTextStyle(c),
      Brightness.light,
    );
    // 测试环境系统族为 Roboto;契约点是"不是文楷"而非"必须为 null"
    expect(style.fontFamily, isNot(PoetryFonts.content));
    expect(theme.useMaterial3, isTrue);
  });

  testWidgets('亮暗双色板均可用且表面色符合纸墨设定', (tester) async {
    final (light, _) =
        await _pumpAndGet(tester, (c) => AppTheme.uiTextStyle(c), Brightness.light);
    final (dark, _) =
        await _pumpAndGet(tester, (c) => AppTheme.uiTextStyle(c), Brightness.dark);
    expect(light.scaffoldBackgroundColor, const Color(0xFFFAF7EF));
    expect(dark.scaffoldBackgroundColor, const Color(0xFF151412));
  });
}

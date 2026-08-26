// 阅读偏好测试(任务 2.4): 默认值/白文开关/字号边界收敛。
import 'package:flutter_test/flutter_test.dart';
import 'package:poetry_mate/data/preferences/reading_prefs.dart';

void main() {
  late InMemoryReadingPrefs prefs;

  setUp(() {
    prefs = InMemoryReadingPrefs();
  });

  test('默认值: 白文关闭 + 字号 24(基线)', () async {
    expect(await prefs.plainTextMode(), isFalse);
    expect(await prefs.contentFontSize(), 24);
  });

  test('白文开关往返', () async {
    await prefs.setPlainTextMode(true);
    expect(await prefs.plainTextMode(), isTrue);
    await prefs.setPlainTextMode(false);
    expect(await prefs.plainTextMode(), isFalse);
  });

  test('字号设置与读取', () async {
    await prefs.setContentFontSize(28);
    expect(await prefs.contentFontSize(), 28);
  });

  test('字号越界收敛到 20–32', () async {
    await prefs.setContentFontSize(12);
    expect(await prefs.contentFontSize(), kMinContentFontSize);
    await prefs.setContentFontSize(48);
    expect(await prefs.contentFontSize(), kMaxContentFontSize);
  });
}

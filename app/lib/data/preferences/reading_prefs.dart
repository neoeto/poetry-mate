/// 阅读偏好存取(任务 2.4) —— 白文模式 + 正文字号。
///
/// 抽象与实现分离: 测试注入内存实现,生产走 shared_preferences。
library;

import 'package:shared_preferences/shared_preferences.dart';

/// 排版契约常量(基线默认 24sp;用户可调范围 20–32)
const double kDefaultContentFontSize = 24;
const double kMinContentFontSize = 20;
const double kMaxContentFontSize = 32;

abstract class ReadingPrefs {
  /// 白文模式(去标点展示);默认 false
  Future<bool> plainTextMode();
  Future<void> setPlainTextMode(bool value);

  /// 正文字号 sp;默认 [kDefaultContentFontSize]
  Future<double> contentFontSize();
  Future<void> setContentFontSize(double size);
}

class SharedReadingPrefs implements ReadingPrefs {
  SharedReadingPrefs(this._prefs);

  static const _plainKey = 'reading_plain_text';
  static const _fontSizeKey = 'reading_font_size';

  final SharedPreferencesAsync _prefs;

  @override
  Future<bool> plainTextMode() async => await _prefs.getBool(_plainKey) ?? false;

  @override
  Future<void> setPlainTextMode(bool value) => _prefs.setBool(_plainKey, value);

  @override
  Future<double> contentFontSize() async {
    final stored = await _prefs.getDouble(_fontSizeKey);
    if (stored == null) return kDefaultContentFontSize;
    return stored
        .clamp(kMinContentFontSize, kMaxContentFontSize)
        .toDouble();
  }

  @override
  Future<void> setContentFontSize(double size) => _prefs.setDouble(
        _fontSizeKey,
        size.clamp(kMinContentFontSize, kMaxContentFontSize),
      );
}

/// 内存实现(测试)
class InMemoryReadingPrefs implements ReadingPrefs {
  bool _plain = false;
  double _fontSize = kDefaultContentFontSize;

  @override
  Future<bool> plainTextMode() async => _plain;

  @override
  Future<void> setPlainTextMode(bool value) async => _plain = value;

  @override
  Future<double> contentFontSize() async => _fontSize;

  @override
  Future<void> setContentFontSize(double size) async =>
      _fontSize = size.clamp(kMinContentFontSize, kMaxContentFontSize).toDouble();
}

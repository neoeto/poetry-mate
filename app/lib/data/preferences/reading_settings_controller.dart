// 阅读偏好响应式控制器 —— 白文模式与字号的内存状态 + 异步持久化。
//
// 初始为基线默认值;build 时异步从存储加载并覆盖状态。
// UI(ref.watch)获得即时响应;写操作同步更新内存再落盘。
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers.dart';
import 'reading_prefs.dart';

class ReadingSettingsState {
  const ReadingSettingsState({
    required this.plainText,
    required this.fontSize,
    this.loaded = false,
  });

  final bool plainText;
  final double fontSize;
  final bool loaded;

  ReadingSettingsState copyWith({bool? plainText, double? fontSize}) =>
      ReadingSettingsState(
        plainText: plainText ?? this.plainText,
        fontSize: fontSize ?? this.fontSize,
        loaded: loaded,
      );
}

class ReadingSettingsController extends Notifier<ReadingSettingsState> {
  @override
  ReadingSettingsState build() {
    _load();
    return const ReadingSettingsState(
      plainText: false,
      fontSize: kDefaultContentFontSize,
    );
  }

  Future<void> _load() async {
    final prefs = ref.read(readingPrefsProvider);
    final plain = await prefs.plainTextMode();
    final size = await prefs.contentFontSize();
    state = state.copyWith(plainText: plain, fontSize: size);
  }

  Future<void> togglePlainText() async {
    final next = !state.plainText;
    state = state.copyWith(plainText: next);
    await ref.read(readingPrefsProvider).setPlainTextMode(next);
  }

  Future<void> setFontSize(double size) async {
    final clamped =
        size.clamp(kMinContentFontSize, kMaxContentFontSize).toDouble();
    state = state.copyWith(fontSize: clamped);
    await ref.read(readingPrefsProvider).setContentFontSize(clamped);
  }
}

final readingSettingsProvider =
    NotifierProvider<ReadingSettingsController, ReadingSettingsState>(
        ReadingSettingsController.new);

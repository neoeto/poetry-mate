/// 主题桥 —— Material 3 亮/暗双色板 + 字体双轨制常量。
///
/// 字体双轨(config.yaml 排版工艺): 内容层用霞鹜文楷(任务 3.1 打包后生效,
/// 缺字回退系统字体栈), 界面层保持系统黑体 —— 反差即设计语言。

library;
import 'package:flutter/material.dart';

/// 字体族常量。UI 层不指定家族(null = 系统默认黑体)。
class PoetryFonts {
  const PoetryFonts._();

  /// 霞鹜文楷 GB 子集版 —— 诗词正文/序/注释专用
  static const String content = 'LXGW WenKai GB';
}

/// 纸墨色系: 亮色宣纸底 / 暗色墨底,种子色取黛绿。
class AppTheme {
  const AppTheme._();

  static const Color _seed = Color(0xFF33534D);

  static ThemeData light() => _base(Brightness.light);

  static ThemeData dark() => _base(Brightness.dark);

  static ThemeData _base(Brightness brightness) {
    final isLight = brightness == Brightness.light;
    final scheme = ColorScheme.fromSeed(seedColor: _seed, brightness: brightness)
        .copyWith(
          // 宣纸白 / 墨黑: 微暖的中性底,避免纯白的刺眼与纯黑的死板
          surface: isLight ? const Color(0xFFFAF7EF) : const Color(0xFF151412),
        );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: scheme.surface,
    );
  }
}

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

  /// 内容层文字样式 —— 诗词正文/序文/注释专用(任务 3.2 双轨制)。
  ///
  /// 排版契约(config.yaml):
  /// - 文楷字体族;缺字由引擎回退系统 CJK 字体;
  /// - 默认 24sp(诗行极短,可承载大字),行高 ≥1.9;
  /// - 调用方只覆写尺寸/颜色,不得替换 fontFamily。
  static TextStyle contentTextStyle(
    BuildContext context, {
    double fontSize = 24,
    double height = 2.0,
    Color? color,
    FontWeight fontWeight = FontWeight.w400,
  }) {
    return Theme.of(context).textTheme.bodyLarge!.copyWith(
          fontFamily: PoetryFonts.content,
          fontSize: fontSize,
          height: height,
          color: color,
          fontWeight: fontWeight,
        );
  }

  /// 界面层文字样式 —— 显式声明走系统黑体(与内容层形成双轨)。
  static TextStyle uiTextStyle(
    BuildContext context, {
    double? fontSize,
    Color? color,
    FontWeight fontWeight = FontWeight.w500,
  }) {
    return Theme.of(context).textTheme.labelLarge!.copyWith(
          // 不设 fontFamily → 系统默认
          fontSize: fontSize,
          color: color,
          fontWeight: fontWeight,
        );
  }
}

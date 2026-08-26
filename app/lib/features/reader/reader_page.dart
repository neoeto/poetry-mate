/// 简读页 —— 排版基线版式 + 阅读偏好接入(任务 3.1/3.3)。
///
/// 版式契约:
/// - 标题居中;作者·朝代落款偏右、小一号、弱色;
/// - 正文一句一行、左对齐、字号来自用户偏好(默认 ≥22sp)、行距 ≥1.9;
/// - 文楷内容族;分隔只靠留白与一根细线,零图片装饰;
/// - 白文模式下正文去除标点展示(存储不动)。
///
/// 收藏心形与白文开关位于 PoemRoutePage 的 AppBar。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/ui/app_theme.dart';
import '../../data/preferences/reading_settings_controller.dart';
import '../../domain/entities/poem.dart';
import 'line_note_sheet.dart';

final _punctuationPattern =
    RegExp(r'[\p{P}\u3000]', unicode: true);

class ReaderPage extends ConsumerWidget {
  const ReaderPage({super.key, required this.poem});

  final Poem poem;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(readingSettingsProvider);
    final scheme = Theme.of(context).colorScheme;

    String renderLine(String line) =>
        settings.plainText ? line.replaceAll(_punctuationPattern, '') : line;

    TextStyle bodyStyle() => AppTheme.contentTextStyle(
          context,
          fontSize: settings.fontSize,
          color: scheme.onSurface,
        );

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 36),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── 标题: 居中 ──
          Text(
            poem.displayTitle,
            textAlign: TextAlign.center,
            style: Theme.of(context)
                .textTheme
                .titleLarge
                ?.copyWith(fontFamily: PoetryFonts.content),
          ),
          const SizedBox(height: 8),

          // ── 落款: 偏右,小一号,弱墨色 ──
          Text(
            '${poem.author} · ${poem.dynasty}',
            textAlign: TextAlign.right,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
          ),

          // ── 细线分隔(留白之外的唯一装饰) ──
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: Divider(
              height: 1,
              thickness: 0.5,
              color: scheme.outlineVariant,
            ),
          ),

          // ── 序文(v1 按正文样式呈现;降级设计归 reading-page 变更) ──
          if (poem.preface != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(renderLine(poem.preface!), style: bodyStyle()),
            ),

          // ── 正文: 一句一行,整行可点击 ──
          for (var index = 0; index < poem.paragraphs.length; index++)
            _PoemLine(
              key: ValueKey('poem-line-$index'),
              text: renderLine(poem.paragraphs[index]),
              originalText: poem.paragraphs[index],
              style: bodyStyle(),
              onTap: () => showLineNoteSheet(
                context,
                poem: poem,
                lineIndex: index,
                line: poem.paragraphs[index],
                onOpenSettings: () {
                  Navigator.of(context).pop();
                  context.push('/settings/llm');
                },
              ),
            ),
        ],
      ),
    );
  }
}

class _PoemLine extends StatelessWidget {
  const _PoemLine({
    super.key,
    required this.text,
    required this.originalText,
    required this.style,
    required this.onTap,
  });

  final String text;
  final String originalText;
  final TextStyle style;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: originalText,
      button: true,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: SizedBox(
              width: double.infinity,
              child: Text(
                text,
                style: style,
                textAlign: TextAlign.left,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

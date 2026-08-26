/// 简读页 —— 排版基线版式(任务 3.3 / specs/app-foundation)。
///
/// 版式契约:
/// - 标题居中;作者·朝代落款偏右、小一号、弱色;
/// - 正文一句一行、左对齐(词的长短句天然错落,忌居中)、≥22sp、行距 ≥1.9;
/// - 文楷内容族;分隔只靠留白与一根细线,零图片装饰。
///
/// 完整阅读体验(收藏/白文模式/序文降级/点句即释)归 reading-page 变更。
library;

import 'package:flutter/material.dart';

import '../../domain/entities/poem.dart';
import '../../core/ui/app_theme.dart';

class ReaderPage extends StatelessWidget {
  const ReaderPage({super.key, required this.poem});

  final Poem poem;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    TextStyle bodyStyle() => AppTheme.contentTextStyle(
          context,
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
              child: Text(poem.preface!, style: bodyStyle()),
            ),

          // ── 正文: 一句一行,左对齐 ──
          for (final line in poem.paragraphs)
            Text(line, key: ValueKey(line), style: bodyStyle(), textAlign: TextAlign.left),
        ],
      ),
    );
  }
}

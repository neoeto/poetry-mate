/// 简读页 —— 原文/赏析双页签 + 阅读偏好接入。
///
/// 原文页保留排版基线：标题居中、落款偏右、正文一句一行、文楷大字；
/// 每一行是完整触达区，点击后打开 L1 逐句即释底部抽屉。
/// 赏析页签延迟到首次切换后才创建，避免无意消耗用户的模型额度。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/ui/app_theme.dart';
import '../../data/preferences/reading_settings_controller.dart';
import '../../domain/entities/poem.dart';
import 'essay_tab.dart';
import 'line_note_sheet.dart';

final _punctuationPattern = RegExp(r'[\p{P}\u3000]', unicode: true);

class ReaderPage extends ConsumerStatefulWidget {
  const ReaderPage({super.key, required this.poem});

  final Poem poem;

  @override
  ConsumerState<ReaderPage> createState() => _ReaderPageState();
}

class _ReaderPageState extends ConsumerState<ReaderPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  var _essayRequested = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(_onTabChanged);
  }

  void _onTabChanged() {
    if (_tabController.index == 1 && !_essayRequested) {
      setState(() => _essayRequested = true);
    }
  }

  @override
  void dispose() {
    _tabController
      ..removeListener(_onTabChanged)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(readingSettingsProvider);
    final scheme = Theme.of(context).colorScheme;

    String renderLine(String line) =>
        settings.plainText ? line.replaceAll(_punctuationPattern, '') : line;

    final bodyStyle = AppTheme.contentTextStyle(
      context,
      fontSize: settings.fontSize,
      color: scheme.onSurface,
    );

    return Column(
      children: [
        TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: '原文'),
            Tab(text: '赏析'),
          ],
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _OriginalPoemView(
                poem: widget.poem,
                renderLine: renderLine,
                bodyStyle: bodyStyle,
                onLineTap: (index) => showLineNoteSheet(
                  context,
                  poem: widget.poem,
                  lineIndex: index,
                  line: widget.poem.paragraphs[index],
                  onOpenSettings: () {
                    Navigator.of(context).pop();
                    context.push('/settings/llm');
                  },
                ),
              ),
              _essayRequested
                  ? EssayTab(
                      poem: widget.poem,
                      onOpenSettings: () => context.push('/settings/llm'),
                    )
                  : const _EssayNotSelected(),
            ],
          ),
        ),
      ],
    );
  }
}

class _OriginalPoemView extends StatelessWidget {
  const _OriginalPoemView({
    required this.poem,
    required this.renderLine,
    required this.bodyStyle,
    required this.onLineTap,
  });

  final Poem poem;
  final String Function(String line) renderLine;
  final TextStyle bodyStyle;
  final ValueChanged<int> onLineTap;

  @override
  Widget build(BuildContext context) {
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
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),

          // ── 细线分隔(留白之外的唯一装饰) ──
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: Divider(
              height: 1,
              thickness: 0.5,
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
          ),

          // ── 序文(v1 按正文样式呈现) ──
          if (poem.preface != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(renderLine(poem.preface!), style: bodyStyle),
            ),

          // ── 正文: 一句一行,整行可点击 ──
          for (var index = 0; index < poem.paragraphs.length; index++)
            _PoemLine(
              key: ValueKey('poem-line-$index'),
              text: renderLine(poem.paragraphs[index]),
              originalText: poem.paragraphs[index],
              style: bodyStyle,
              onTap: () => onLineTap(index),
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

class _EssayNotSelected extends StatelessWidget {
  const _EssayNotSelected();

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

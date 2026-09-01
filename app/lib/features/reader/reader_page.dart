/// 简读页 —— 原文/赏析双页签 + 阅读偏好接入。
///
/// 原文页保留排版基线：标题居中、落款偏右、正文一句一行、文楷大字；
/// 每一行是完整触达区，点击后打开 L1 逐句即释底部抽屉。
/// 赏析页签延迟到首次切换后才创建，避免无意消耗用户的模型额度。
library;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart'
    show SelectedContent, SelectedContentRange;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/llm/annotation_service.dart';
import '../../core/ui/app_theme.dart';
import '../../data/preferences/reading_settings_controller.dart';
import '../../data/providers.dart';
import '../../domain/entities/annotations.dart';
import '../../domain/entities/poem.dart';
import 'essay_tab.dart';
import 'line_note_sheet.dart';
import 'word_explanation_sheet.dart';

final _punctuationPattern = RegExp(r'[\p{P}\u3000]', unicode: true);

class ReaderPage extends ConsumerStatefulWidget {
  const ReaderPage({
    super.key,
    required this.poem,
    this.annotationContext,
    this.sourceInfo,
  });

  final Poem poem;
  final AnnotationContext? annotationContext;
  final PoemSourceInfo? sourceInfo;

  @override
  ConsumerState<ReaderPage> createState() => _ReaderPageState();
}

class _ReaderPageState extends ConsumerState<ReaderPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  late final AnnotationContext _annotationContext;
  var _essayRequested = false;
  List<WordNote> _automaticWordNotes = const [];
  List<WordNote> _cachedWordNotes = const [];

  List<WordNote> get _wordNotes => [
    ..._automaticWordNotes,
    ..._cachedWordNotes,
  ];

  void _onEssayReady(EssayContent essay) {
    if (!mounted) return;
    setState(() => _automaticWordNotes = essay.wordNotes);
  }

  @override
  void initState() {
    super.initState();
    _annotationContext =
        widget.annotationContext ?? const AnnotationContext.persistent();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(_onTabChanged);
    // 已有的 L1 关键词和用户选词注不应要求用户再次触发生成才出现。
    _loadCachedWordNotes();
  }

  void _onLineNoteReady(int lineIndex, LineNoteContent lineNote) {
    if (!mounted ||
        lineIndex < 0 ||
        lineIndex >= widget.poem.paragraphs.length) {
      return;
    }
    final line = widget.poem.paragraphs[lineIndex];
    final converted = <WordNote>[];
    for (final keyword in lineNote.notes) {
      final term = keyword.term.trim();
      final explain = keyword.explain.trim();
      if (term.isEmpty || explain.isEmpty || !line.contains(term)) continue;
      converted.add(
        WordNote(
          term: term,
          explain: explain,
          pinyin: keyword.pinyin,
          lineIndex: lineIndex,
        ),
      );
    }
    setState(() {
      _cachedWordNotes = [
        ..._cachedWordNotes.where(
          (note) => note.isUserSelected || note.lineIndex != lineIndex,
        ),
        ...converted,
      ];
    });
  }

  Future<void> _loadCachedWordNotes() async {
    try {
      final notes = await ref
          .read(annotationServiceProvider)
          .cachedWordNotes(widget.poem, context: _annotationContext);
      if (mounted) setState(() => _cachedWordNotes = notes);
    } catch (_) {
      // 测试/降级环境可能没有数据库注入；不影响正文阅读。
    }
  }

  Future<void> _explainSelectedWord(SelectedWordPosition position) async {
    await showSelectedWordExplanationSheet(
      context,
      poem: widget.poem,
      position: position,
      annotationContext: _annotationContext,
      onChanged: _loadCachedWordNotes,
      onOpenSettings: () {
        Navigator.of(context).pop();
        context.push('/settings/llm');
      },
    );
    await _loadCachedWordNotes();
  }

  Future<void> _showWordNote(WordNote note) async {
    final lineIndex = note.lineIndex;
    final start = note.start;
    final end = note.end;
    if (!note.isUserSelected ||
        lineIndex == null ||
        start == null ||
        end == null) {
      await showWordExplanationSheet(context, note);
      return;
    }

    await showSelectedWordExplanationSheet(
      context,
      poem: widget.poem,
      position: SelectedWordPosition(
        lineIndex: lineIndex,
        start: start,
        end: end,
        term: note.term,
      ),
      annotationContext: _annotationContext,
      onChanged: _loadCachedWordNotes,
      onOpenSettings: () {
        Navigator.of(context).pop();
        context.push('/settings/llm');
      },
    );
    await _loadCachedWordNotes();
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
                sourceInfo: widget.sourceInfo,
                wordNotes: _wordNotes,
                onWordTap: _showWordNote,
                onWordSelected: _explainSelectedWord,
                onLineTap: (index) => showLineNoteSheet(
                  context,
                  poem: widget.poem,
                  lineIndex: index,
                  line: widget.poem.paragraphs[index],
                  annotationContext: _annotationContext,
                  onNoteReady: (note) => _onLineNoteReady(index, note),
                  onOpenSettings: () {
                    Navigator.of(context).pop();
                    context.push('/settings/llm');
                  },
                ),
              ),
              _essayRequested
                  ? EssayTab(
                      poem: widget.poem,
                      annotationContext: _annotationContext,
                      onContentReady: _onEssayReady,
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

class _OriginalPoemView extends StatefulWidget {
  const _OriginalPoemView({
    required this.poem,
    required this.renderLine,
    required this.bodyStyle,
    this.sourceInfo,
    required this.wordNotes,
    required this.onWordTap,
    required this.onWordSelected,
    required this.onLineTap,
  });

  final Poem poem;
  final String Function(String line) renderLine;
  final TextStyle bodyStyle;
  final PoemSourceInfo? sourceInfo;
  final List<WordNote> wordNotes;
  final ValueChanged<WordNote> onWordTap;
  final Future<void> Function(SelectedWordPosition position) onWordSelected;
  final ValueChanged<int> onLineTap;

  @override
  State<_OriginalPoemView> createState() => _OriginalPoemViewState();
}

class _OriginalPoemViewState extends State<_OriginalPoemView> {
  final _selectionNotifier = SelectionListenerNotifier();
  SelectedContent? _selectedContent;

  @override
  void dispose() {
    _selectionNotifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 36),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── 标题: 居中 ──
          Text(
            widget.poem.displayTitle,
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontFamily: PoetryFonts.content),
          ),
          const SizedBox(height: 8),

          // ── 落款: 偏右,小一号,弱墨色 ──
          Text(
            '${widget.poem.author} · ${widget.poem.dynasty}',
            textAlign: TextAlign.right,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          if (widget.sourceInfo != null) ...[
            const SizedBox(height: 12),
            _PoemSourceBanner(info: widget.sourceInfo!),
          ],

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
          if (widget.poem.preface != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                widget.renderLine(widget.poem.preface!),
                style: widget.bodyStyle,
              ),
            ),

          // ── 正文: 保留每句独立布局，同时交给系统处理长按选词 ──
          SelectionArea(
            key: const ValueKey('poem-selection-area'),
            onSelectionChanged: (content) => _selectedContent = content,
            contextMenuBuilder: _buildSelectionMenu,
            child: SelectionListener(
              selectionNotifier: _selectionNotifier,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (
                    var index = 0;
                    index < widget.poem.paragraphs.length;
                    index++
                  )
                    _PoemLine(
                      key: ValueKey('poem-line-$index'),
                      originalText: widget.poem.paragraphs[index],
                      renderLine: widget.renderLine,
                      lineIndex: index,
                      style: widget.bodyStyle,
                      wordNotes: widget.wordNotes,
                      onWordTap: widget.onWordTap,
                      onTap: () => widget.onLineTap(index),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSelectionMenu(
    BuildContext context,
    SelectableRegionState state,
  ) {
    final selected = _selectedContent;
    final range = _selectionNotifier.selection.range;
    final items = <ContextMenuButtonItem>[];
    if (selected != null &&
        range != null &&
        selected.plainText.trim().isNotEmpty) {
      items.add(
        ContextMenuButtonItem(
          type: ContextMenuButtonType.custom,
          label: 'AI 解释',
          onPressed: () {
            final resolution = _resolveSelection(selected, range);
            state.hideToolbar();
            if (resolution.position != null) {
              widget.onWordSelected(resolution.position!);
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    resolution.crossesLines ? '请在同一句中选择一个词语' : '请重新选择诗句中的字词',
                  ),
                ),
              );
            }
          },
        ),
      );
    }
    items.addAll(state.contextMenuButtonItems);
    return AdaptiveTextSelectionToolbar.buttonItems(
      buttonItems: items,
      anchors: state.contextMenuAnchors,
    );
  }

  _SelectionResolution _resolveSelection(
    SelectedContent selected,
    SelectedContentRange range,
  ) {
    final start = range.startOffset <= range.endOffset
        ? range.startOffset
        : range.endOffset;
    final end = range.startOffset <= range.endOffset
        ? range.endOffset
        : range.startOffset;
    if (start < 0 || end <= start) {
      return const _SelectionResolution.invalid();
    }

    final displayedLines = [
      for (final line in widget.poem.paragraphs)
        poemLineWithIndent(widget.renderLine(line)),
    ];
    var offset = 0;
    int? startLine;
    int? endLine;
    var startLineOffset = 0;
    for (var index = 0; index < displayedLines.length; index++) {
      final lineEnd = offset + displayedLines[index].length;
      if (startLine == null && start < lineEnd) {
        startLine = index;
        startLineOffset = offset;
      }
      if (endLine == null && end - 1 < lineEnd) {
        endLine = index;
      }
      offset = lineEnd;
    }

    if (startLine == null || endLine == null) {
      return const _SelectionResolution.invalid();
    }
    if (startLine != endLine) {
      return const _SelectionResolution.crossesLines();
    }

    final displayedLine = displayedLines[startLine];
    final localStart = start - startLineOffset;
    final localEnd = end - startLineOffset;
    if (localStart < 0 ||
        localEnd > displayedLine.length ||
        localEnd <= localStart) {
      return const _SelectionResolution.invalid();
    }

    final selectedDisplayText = displayedLine.substring(localStart, localEnd);
    if (selectedDisplayText != selected.plainText) {
      return const _SelectionResolution.invalid();
    }

    final original = widget.poem.paragraphs[startLine];
    final originalRange = _mapToOriginalRange(
      original: original,
      displayed: displayedLine,
      start: localStart,
      end: localEnd,
    );
    if (originalRange == null) {
      return const _SelectionResolution.invalid();
    }
    return _SelectionResolution(
      SelectedWordPosition(
        lineIndex: startLine,
        start: originalRange.start,
        end: originalRange.end,
        term: original.substring(originalRange.start, originalRange.end),
      ),
    );
  }

  _OriginalRange? _mapToOriginalRange({
    required String original,
    required String displayed,
    required int start,
    required int end,
  }) {
    final displayedToOriginal = List<int>.filled(
      kPoemLineIndent.length,
      -1,
      growable: true,
    );
    for (var index = 0; index < original.length; index++) {
      final rendered = widget.renderLine(original.substring(index, index + 1));
      for (var count = 0; count < rendered.length; count++) {
        displayedToOriginal.add(index);
      }
    }
    if (start >= displayedToOriginal.length ||
        end > displayedToOriginal.length ||
        end <= start) {
      return null;
    }
    final originalStart = displayedToOriginal[start];
    final originalEnd = displayedToOriginal[end - 1] + 1;
    if (originalStart < 0 || originalEnd <= 0) return null;
    if (originalEnd > original.length ||
        widget.renderLine(original.substring(originalStart, originalEnd)) !=
            displayed.substring(start, end)) {
      return null;
    }
    return _OriginalRange(originalStart, originalEnd);
  }
}

class _SelectionResolution {
  const _SelectionResolution(this.position) : crossesLines = false;
  const _SelectionResolution.invalid() : position = null, crossesLines = false;
  const _SelectionResolution.crossesLines()
    : position = null,
      crossesLines = true;

  final SelectedWordPosition? position;
  final bool crossesLines;
}

class _OriginalRange {
  const _OriginalRange(this.start, this.end);

  final int start;
  final int end;
}

class _PoemLine extends StatefulWidget {
  const _PoemLine({
    super.key,
    required this.originalText,
    required this.renderLine,
    required this.lineIndex,
    required this.style,
    required this.wordNotes,
    required this.onWordTap,
    required this.onTap,
  });

  final String originalText;
  final String Function(String line) renderLine;
  final int lineIndex;
  final TextStyle style;
  final List<WordNote> wordNotes;
  final ValueChanged<WordNote> onWordTap;
  final VoidCallback onTap;

  @override
  State<_PoemLine> createState() => _PoemLineState();
}

class _PoemLineState extends State<_PoemLine> {
  final _recognizers = <TapGestureRecognizer>[];

  @override
  void didUpdateWidget(covariant _PoemLine oldWidget) {
    super.didUpdateWidget(oldWidget);
    _disposeRecognizers();
  }

  @override
  void dispose() {
    _disposeRecognizers();
    super.dispose();
  }

  void _disposeRecognizers() {
    for (final recognizer in _recognizers) {
      recognizer.dispose();
    }
    _recognizers.clear();
  }

  TapGestureRecognizer _recognizer(VoidCallback callback) {
    final recognizer = TapGestureRecognizer()..onTap = callback;
    _recognizers.add(recognizer);
    return recognizer;
  }

  @override
  Widget build(BuildContext context) {
    final matches = _findWordMatches(
      widget.originalText,
      widget.lineIndex,
      widget.wordNotes,
    );
    if (matches.isEmpty) {
      return _plainLine();
    }

    _disposeRecognizers();
    final markedStyle = widget.style.copyWith(
      decoration: TextDecoration.underline,
      decorationStyle: TextDecorationStyle.dotted,
      decorationThickness: 1.5,
      decorationColor: Theme.of(context).colorScheme.primary,
    );
    final spans = <InlineSpan>[];
    var cursor = 0;
    for (final match in matches) {
      if (match.start > cursor) {
        spans.add(
          TextSpan(
            text: widget.renderLine(
              widget.originalText.substring(cursor, match.start),
            ),
            recognizer: _recognizer(widget.onTap),
          ),
        );
      }
      spans.add(
        TextSpan(
          text: widget.renderLine(
            widget.originalText.substring(match.start, match.end),
          ),
          semanticsLabel: '${match.note.term}，点击查看释义',
          style: markedStyle,
          recognizer: _recognizer(() => widget.onWordTap(match.note)),
        ),
      );
      cursor = match.end;
    }
    if (cursor < widget.originalText.length) {
      spans.add(
        TextSpan(
          text: widget.renderLine(widget.originalText.substring(cursor)),
          recognizer: _recognizer(widget.onTap),
        ),
      );
    }

    return Semantics(
      label: widget.originalText,
      button: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: SizedBox(
          width: double.infinity,
          child: Text.rich(
            TextSpan(
              style: widget.style,
              children: [
                const TextSpan(text: kPoemLineIndent),
                ...spans,
              ],
            ),
            textAlign: TextAlign.left,
          ),
        ),
      ),
    );
  }

  Widget _plainLine() {
    return Semantics(
      label: widget.originalText,
      button: true,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: widget.onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: SizedBox(
              width: double.infinity,
              child: Text(
                poemLineWithIndent(widget.renderLine(widget.originalText)),
                style: widget.style,
                textAlign: TextAlign.left,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _WordMatch {
  const _WordMatch({
    required this.start,
    required this.end,
    required this.note,
  });

  final int start;
  final int end;
  final WordNote note;
}

List<_WordMatch> _findWordMatches(
  String line,
  int lineIndex,
  List<WordNote> notes,
) {
  final candidates = <_WordMatch>[];
  for (final note in notes) {
    if (note.term.isEmpty || note.explain.isEmpty) continue;
    if (note.lineIndex != null && note.lineIndex != lineIndex) continue;

    if (note.isUserSelected) {
      final start = note.start;
      final end = note.end;
      if (start == null ||
          end == null ||
          start < 0 ||
          end <= start ||
          end > line.length ||
          line.substring(start, end) != note.term) {
        continue;
      }
      candidates.add(_WordMatch(start: start, end: end, note: note));
      continue;
    }

    var start = line.indexOf(note.term);
    while (start != -1) {
      candidates.add(
        _WordMatch(start: start, end: start + note.term.length, note: note),
      );
      start = line.indexOf(note.term, start + note.term.length);
    }
  }

  // 先取靠前的命中；同一位置重叠时优先较长词语，避免下划线互相覆盖。
  candidates.sort((a, b) {
    final byStart = a.start.compareTo(b.start);
    if (byStart != 0) return byStart;
    final byLength = b.end.compareTo(a.end);
    if (byLength != 0) return byLength;
    // 用户主动解释优先于 L2 自动解释，避免同一位置点击时打开错误来源。
    if (a.note.isUserSelected != b.note.isUserSelected) {
      return a.note.isUserSelected ? -1 : 1;
    }
    return 0;
  });
  final accepted = <_WordMatch>[];
  var occupiedUntil = 0;
  for (final candidate in candidates) {
    if (candidate.start < occupiedUntil) continue;
    accepted.add(candidate);
    occupiedUntil = candidate.end;
  }
  return accepted;
}

class _PoemSourceBanner extends StatelessWidget {
  const _PoemSourceBanner({required this.info});

  final PoemSourceInfo info;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final source = info.source?.trim();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: scheme.secondaryContainer,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.auto_awesome_outlined,
            size: 18,
            color: scheme.onSecondaryContainer,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              [
                info.label,
                if (source != null && source.isNotEmpty) '出处：$source',
                if (info.isUncertain) '部分信息待核，仅供参考',
              ].join(' · '),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: scheme.onSecondaryContainer,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EssayNotSelected extends StatelessWidget {
  const _EssayNotSelected();

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

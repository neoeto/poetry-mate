/// L2 整篇赏析页签。
///
/// 只在用户首次切换到「赏析」时创建并请求，避免阅读原文时提前消耗额度；
/// 具体缓存与重试由 AnnotationService 负责。
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/llm/annotation_service.dart';
import '../../core/llm/llm_exception.dart';
import '../../data/providers.dart';
import '../../domain/entities/annotations.dart';
import '../../domain/entities/notebook_entry.dart';
import '../../domain/entities/poem.dart';
import 'notebook_editor.dart';

class EssayTab extends ConsumerStatefulWidget {
  const EssayTab({
    super.key,
    required this.poem,
    this.annotationContext,
    this.onContentReady,
    this.onOpenSettings,
  });

  final Poem poem;
  final AnnotationContext? annotationContext;
  final ValueChanged<EssayContent>? onContentReady;
  final VoidCallback? onOpenSettings;

  @override
  ConsumerState<EssayTab> createState() => _EssayTabState();
}

enum _EssayPhase { loading, streaming, done, error }

class _EssayTabState extends ConsumerState<EssayTab>
    with AutomaticKeepAliveClientMixin<EssayTab> {
  StreamSubscription<AnnotationEvent<EssayContent>>? _subscription;
  _EssayPhase _phase = _EssayPhase.loading;
  EssayContent? _content;
  Object? _error;
  Set<String> _closedKeys = const {};
  Set<String> _pendingKeys = const {};
  var _generation = 0;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _startStream();
  }

  void _startStream({bool forceRegenerate = false}) {
    final generation = ++_generation;
    final oldSubscription = _subscription;
    _subscription = null;
    oldSubscription?.cancel();

    void reset() {
      _phase = _EssayPhase.loading;
      _content = null;
      _error = null;
      _closedKeys = const {};
      _pendingKeys = const {};
    }

    if (mounted) {
      setState(reset);
    } else {
      reset();
    }

    final stream = ref
        .read(annotationServiceProvider)
        .streamEssay(
          widget.poem,
          forceRegenerate: forceRegenerate,
          context:
              widget.annotationContext ?? const AnnotationContext.persistent(),
        );
    _subscription = stream.listen(
      (event) {
        if (!mounted || generation != _generation) return;
        _handleEvent(event);
      },
      onError: (Object error, StackTrace stackTrace) {
        if (!mounted || generation != _generation) return;
        setState(() {
          _phase = _EssayPhase.error;
          _error = error;
        });
      },
      onDone: () {
        if (!mounted || generation != _generation) return;
        // 正常实现总会在 onDone 前发 AnnotationDone；这里仅防御异常实现。
        if (_phase != _EssayPhase.done && _phase != _EssayPhase.error) {
          setState(() {
            _phase = _EssayPhase.error;
            _error = const LlmException(LlmErrorKind.badResponse, '赏析返回格式异常');
          });
        }
      },
    );
  }

  void _handleEvent(AnnotationEvent<EssayContent> event) {
    if (event is AnnotationReset) {
      setState(() {
        _phase = _EssayPhase.loading;
        _content = null;
        _closedKeys = const {};
        _pendingKeys = const {};
      });
      return;
    }
    if (event is AnnotationPartial) {
      final partialEvent = event as AnnotationPartial<dynamic>;
      final partial = partialEvent.content as EssayContent;
      setState(() {
        _phase = _EssayPhase.streaming;
        _content = partial;
        _closedKeys = Set<String>.from(partialEvent.closedKeys);
        _pendingKeys = Set<String>.from(partialEvent.pendingKeys);
      });
      return;
    }
    if (event is AnnotationDone) {
      final doneEvent = event as AnnotationDone<dynamic>;
      final content = doneEvent.content as EssayContent;
      setState(() {
        _phase = _EssayPhase.done;
        _content = content;
        _closedKeys = const {};
        _pendingKeys = const {};
      });
      widget.onContentReady?.call(content);
    }
  }

  void _retry() => _startStream();

  Future<NotebookEntry?> _entry() {
    if (widget.annotationContext?.isTransient == true) {
      return Future.value(null);
    }
    return ref
        .read(notebookRepositoryProvider)
        .byTarget(poemId: widget.poem.id, kind: NotebookKind.essay);
  }

  Future<void> _edit() async {
    final entry = await _entry();
    if (entry == null || !mounted) return;
    final saved = await showNotebookEntryEditor(context, entry);
    if (saved == true && mounted) _retry();
  }

  Future<void> _regenerate() async {
    final entry = await _entry();
    if (!mounted) return;
    final confirmed = await confirmRegeneration(
      context,
      userEdited: entry?.userEdited ?? false,
    );
    if (!confirmed || !mounted) return;
    _startStream(forceRegenerate: true);
  }

  @override
  void dispose() {
    _generation++;
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return switch (_phase) {
      _EssayPhase.loading => const _EssaySkeleton(),
      _EssayPhase.streaming =>
        _content == null
            ? const _EssaySkeleton()
            : _EssayStreamingView(
                content: _content!,
                closedKeys: _closedKeys,
                pendingKeys: _pendingKeys,
              ),
      _EssayPhase.done =>
        _content == null
            ? _EssayError(onRetry: _retry)
            : EssayContentView(
                content: _content!,
                onEdit: widget.annotationContext?.isTransient == true
                    ? null
                    : _edit,
                onRegenerate: widget.annotationContext?.isTransient == true
                    ? null
                    : _regenerate,
              ),
      _EssayPhase.error => _EssayError(
        error: _error,
        onRetry: _retry,
        onOpenSettings: widget.onOpenSettings,
      ),
    };
  }
}

/// 赏析生成中的静态骨架，避免用无限旋转动画占满整个页面。
class _EssaySkeleton extends StatelessWidget {
  const _EssaySkeleton();

  @override
  Widget build(BuildContext context) {
    final outline = Theme.of(context).colorScheme.outlineVariant;
    return Semantics(
      label: '正在生成赏析',
      child: ListView(
        key: const ValueKey('essay-skeleton'),
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 36),
        children: [
          const Text('正在生成赏析…'),
          const SizedBox(height: 20),
          for (var i = 0; i < 5; i++) ...[
            Container(
              height: 18,
              width: i == 0 ? 92 : 116,
              decoration: BoxDecoration(
                color: outline.withValues(alpha: 0.35),
                borderRadius: BorderRadius.circular(5),
              ),
            ),
            const SizedBox(height: 12),
            Container(
              height: i == 1 ? 72 : 54,
              decoration: BoxDecoration(
                color: outline.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ],
      ),
    );
  }
}

/// 赏析流式生成中的渐进视图：只渲染已闭合字段，未完成字段显示占位。
class _EssayStreamingView extends StatelessWidget {
  const _EssayStreamingView({
    required this.content,
    required this.closedKeys,
    required this.pendingKeys,
  });

  final EssayContent content;
  final Set<String> closedKeys;
  final Set<String> pendingKeys;

  bool _visible(String key) =>
      closedKeys.contains(key) || pendingKeys.contains(key);

  Widget _text(String key, String value) => closedKeys.contains(key)
      ? _EssayText(value)
      : const _GeneratingEssayText();

  Widget _craft() {
    final items = [
      for (final item in content.craft)
        Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (item.point.isNotEmpty) Text(item.point),
              if (item.detail.isNotEmpty) ...[
                if (item.point.isNotEmpty) const SizedBox(height: 4),
                Text(item.detail),
              ],
            ],
          ),
        ),
    ];
    if (closedKeys.contains('craft')) {
      return items.isEmpty ? const _EmptyEssayText() : Column(children: items);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [if (items.isNotEmpty) ...items, const _GeneratingEssayText()],
    );
  }

  Widget _wordNotes() {
    final items = [
      for (final note in content.wordNotes)
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Text(
            '${note.term}${note.pinyin.trim().isEmpty ? '' : '（${note.pinyin.trim()}）'}：${note.explain}',
          ),
        ),
    ];
    if (closedKeys.contains('word_notes')) {
      return items.isEmpty
          ? const SizedBox.shrink()
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: items,
            );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [if (items.isNotEmpty) ...items, const _GeneratingEssayText()],
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 36),
      children: [
        Row(
          children: [
            const Expanded(child: Text('正在生成赏析…')),
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        if (_visible('summary'))
          _EssaySection(title: '大意', child: _text('summary', content.summary)),
        if (_visible('craft')) _EssaySection(title: '炼字与手法', child: _craft()),
        if (_visible('word_notes') || content.wordNotes.isNotEmpty)
          _EssaySection(title: '词语解释', child: _wordNotes()),
        if (_visible('mood'))
          _EssaySection(title: '意境', child: _text('mood', content.mood)),
        if (_visible('emotion'))
          _EssaySection(title: '情感', child: _text('emotion', content.emotion)),
        if (_visible('background'))
          _EssaySection(
            title: '创作背景',
            child: closedKeys.contains('background')
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (content.background.uncertain)
                        const Padding(
                          padding: EdgeInsets.only(bottom: 8),
                          child: Chip(
                            avatar: Icon(Icons.info_outline, size: 16),
                            label: Text('史料不详，仅供参考'),
                          ),
                        ),
                      _EssayText(content.background.text),
                    ],
                  )
                : const _GeneratingEssayText(),
          ),
      ],
    );
  }
}

class _GeneratingEssayText extends StatelessWidget {
  const _GeneratingEssayText();

  @override
  Widget build(BuildContext context) =>
      Text('生成中…', style: Theme.of(context).textTheme.bodySmall);
}

class EssayContentView extends StatelessWidget {
  const EssayContentView({
    super.key,
    required this.content,
    this.onEdit,
    this.onRegenerate,
  });

  final EssayContent content;
  final VoidCallback? onEdit;
  final VoidCallback? onRegenerate;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 36),
      children: [
        if (onEdit != null || onRegenerate != null)
          Align(
            alignment: Alignment.centerRight,
            child: Wrap(
              spacing: 4,
              children: [
                if (onEdit != null)
                  TextButton.icon(
                    onPressed: onEdit,
                    icon: const Icon(Icons.edit_outlined),
                    label: const Text('编辑注本'),
                  ),
                if (onRegenerate != null)
                  TextButton.icon(
                    onPressed: onRegenerate,
                    icon: const Icon(Icons.refresh),
                    label: const Text('重新生成'),
                  ),
              ],
            ),
          ),
        _EssaySection(title: '大意', child: _EssayText(content.summary)),
        _EssaySection(
          title: '炼字与手法',
          child: content.craft.isEmpty
              ? const _EmptyEssayText()
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final item in content.craft)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (item.point.isNotEmpty)
                              Text(
                                item.point,
                                style: Theme.of(context).textTheme.titleSmall,
                              ),
                            if (item.detail.isNotEmpty) ...[
                              if (item.point.isNotEmpty)
                                const SizedBox(height: 4),
                              Text(item.detail),
                            ],
                          ],
                        ),
                      ),
                  ],
                ),
        ),
        if (content.wordNotes.isNotEmpty)
          _EssaySection(
            title: '词语解释',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final note in content.wordNotes)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Text(
                      '${note.term}${note.pinyin.trim().isEmpty ? '' : '（${note.pinyin.trim()}）'}：${note.explain}',
                    ),
                  ),
              ],
            ),
          ),
        _EssaySection(title: '意境', child: _EssayText(content.mood)),
        _EssaySection(title: '情感', child: _EssayText(content.emotion)),
        _EssaySection(
          title: '创作背景',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (content.background.uncertain)
                const Padding(
                  padding: EdgeInsets.only(bottom: 8),
                  child: Chip(
                    avatar: Icon(Icons.info_outline, size: 16),
                    label: Text('史料不详，仅供参考'),
                  ),
                ),
              _EssayText(content.background.text),
            ],
          ),
        ),
      ],
    );
  }
}

class _EssaySection extends StatelessWidget {
  const _EssaySection({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }
}

class _EssayText extends StatelessWidget {
  const _EssayText(this.value);

  final String value;

  @override
  Widget build(BuildContext context) {
    return Text(value.isEmpty ? '模型未提供此部分内容。' : value);
  }
}

class _EmptyEssayText extends StatelessWidget {
  const _EmptyEssayText();

  @override
  Widget build(BuildContext context) => const Text('模型未提供手法条目。');
}

class _EssayError extends StatelessWidget {
  const _EssayError({this.error, required this.onRetry, this.onOpenSettings});

  final Object? error;
  final VoidCallback onRetry;
  final VoidCallback? onOpenSettings;

  @override
  Widget build(BuildContext context) {
    final parseError = error;
    if (parseError is AnnotationParseException &&
        parseError.rawText.trim().isNotEmpty) {
      return _EssayPlainFallback(rawText: parseError.rawText);
    }
    final noKey =
        error is LlmException &&
        (error! as LlmException).kind == LlmErrorKind.noKey;
    if (noKey) {
      return _EssayNoKeyGuide(onOpenSettings: onOpenSettings);
    }

    final llmError = error;
    final title = llmError is LlmException ? llmError.title : '这次没能生成赏析';
    final detail = llmError is LlmException
        ? llmError.message
        : '请检查网络连接与 Base URL，或稍后再试。';
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_outlined),
            const SizedBox(height: 10),
            Text(title),
            const SizedBox(height: 5),
            Text(
              detail,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 14),
            OutlinedButton(onPressed: onRetry, child: const Text('再试一次')),
          ],
        ),
      ),
    );
  }
}

class _EssayPlainFallback extends StatelessWidget {
  const _EssayPlainFallback({required this.rawText});

  final String rawText;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text('结构化解析失败，先展示模型原文', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 10),
        SelectableText(rawText),
      ],
    );
  }
}

class _EssayNoKeyGuide extends StatelessWidget {
  const _EssayNoKeyGuide({this.onOpenSettings});

  final VoidCallback? onOpenSettings;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.auto_awesome_outlined),
            const SizedBox(height: 10),
            const Text('还没有配置 AI'),
            const SizedBox(height: 5),
            Text(
              '配置自己的模型后，赏析会留在这首诗的注本里。',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 14),
            FilledButton(
              onPressed: onOpenSettings,
              child: const Text('去「我的」配置'),
            ),
          ],
        ),
      ),
    );
  }
}

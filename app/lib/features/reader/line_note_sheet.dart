/// L1 逐句注底部抽屉。
///
/// Future 由 [AnnotationService] 负责缓存优先、LLM 调用与结构解析；
/// 这里仅负责渐进式反馈，不把供应商原始错误或堆栈展示给用户。
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

class LineNoteSheet extends ConsumerStatefulWidget {
  const LineNoteSheet({
    super.key,
    required this.poem,
    required this.lineIndex,
    required this.line,
    this.onNoteReady,
    this.onOpenSettings,
  });

  final Poem poem;
  final int lineIndex;
  final String line;
  final ValueChanged<LineNoteContent>? onNoteReady;
  final VoidCallback? onOpenSettings;

  @override
  ConsumerState<LineNoteSheet> createState() => _LineNoteSheetState();
}

enum _LineNotePhase { loading, streaming, done, error }

class _LineNoteSheetState extends ConsumerState<LineNoteSheet> {
  StreamSubscription<AnnotationEvent<LineNoteContent>>? _subscription;
  _LineNotePhase _phase = _LineNotePhase.loading;
  LineNoteContent? _note;
  Object? _error;
  Set<String> _closedKeys = const {};
  Set<String> _pendingKeys = const {};
  var _generation = 0;

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
      _phase = _LineNotePhase.loading;
      _note = null;
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
        .streamLineNote(
          widget.poem,
          widget.lineIndex,
          forceRegenerate: forceRegenerate,
        );
    _subscription = stream.listen(
      (event) {
        if (!mounted || generation != _generation) return;
        _handleEvent(event);
      },
      onError: (Object error, StackTrace stackTrace) {
        if (!mounted || generation != _generation) return;
        setState(() {
          _phase = _LineNotePhase.error;
          _error = error;
        });
      },
      onDone: () {
        if (!mounted || generation != _generation) return;
        if (_phase != _LineNotePhase.done && _phase != _LineNotePhase.error) {
          setState(() {
            _phase = _LineNotePhase.error;
            _error = const LlmException(LlmErrorKind.badResponse, '赏析返回格式异常');
          });
        }
      },
    );
  }

  void _handleEvent(AnnotationEvent<LineNoteContent> event) {
    if (event is AnnotationReset) {
      setState(() {
        _phase = _LineNotePhase.loading;
        _note = null;
        _closedKeys = const {};
        _pendingKeys = const {};
      });
      return;
    }
    if (event is AnnotationPartial) {
      final partialEvent = event as AnnotationPartial<dynamic>;
      final partial = partialEvent.content as LineNoteContent;
      setState(() {
        _phase = _LineNotePhase.streaming;
        _note = partial;
        _closedKeys = Set<String>.from(partialEvent.closedKeys);
        _pendingKeys = Set<String>.from(partialEvent.pendingKeys);
      });
      return;
    }
    if (event is AnnotationDone) {
      final doneEvent = event as AnnotationDone<dynamic>;
      final note = doneEvent.content as LineNoteContent;
      setState(() {
        _phase = _LineNotePhase.done;
        _note = note;
        _closedKeys = const {};
        _pendingKeys = const {};
      });
      widget.onNoteReady?.call(note);
    }
  }

  void _retry() => _startStream();

  Future<NotebookEntry?> _entry() {
    return ref
        .read(notebookRepositoryProvider)
        .byTarget(
          poemId: widget.poem.id,
          kind: NotebookKind.lineNote,
          target: widget.lineIndex.toString(),
        );
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
    final scheme = Theme.of(context).colorScheme;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 460),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '逐句即释 · 第 ${widget.lineIndex + 1} 句',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  IconButton(
                    tooltip: '关闭',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              Text(
                widget.line,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 16),
              Flexible(
                child: switch (_phase) {
                  _LineNotePhase.loading => const _LineNoteLoading(),
                  _LineNotePhase.streaming =>
                    _note == null
                        ? const _LineNoteLoading()
                        : _LineNoteStreaming(
                            note: _note!,
                            closedKeys: _closedKeys,
                            pendingKeys: _pendingKeys,
                          ),
                  _LineNotePhase.done =>
                    _note == null
                        ? _LineNoteError(onRetry: _retry)
                        : _LineNoteResult(
                            note: _note!,
                            onEdit: _edit,
                            onRegenerate: _regenerate,
                          ),
                  _LineNotePhase.error => _LineNoteError(
                    error: _error,
                    onRetry: _retry,
                    onOpenSettings: widget.onOpenSettings,
                  ),
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LineNoteStreaming extends StatelessWidget {
  const _LineNoteStreaming({
    required this.note,
    required this.closedKeys,
    required this.pendingKeys,
  });

  final LineNoteContent note;
  final Set<String> closedKeys;
  final Set<String> pendingKeys;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final translationReady = closedKeys.contains('translation');
    final notesStarted =
        closedKeys.contains('notes') || pendingKeys.contains('notes');
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('白话', style: textTheme.labelLarge),
          const SizedBox(height: 6),
          Text(
            translationReady
                ? (note.translation.isEmpty ? '模型未提供直译。' : note.translation)
                : '生成中…',
            style: textTheme.bodyLarge,
          ),
          if (notesStarted) ...[
            const SizedBox(height: 18),
            Text('关键词注', style: textTheme.labelLarge),
            const SizedBox(height: 6),
            for (final item in note.notes)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  '${item.term}${item.pinyin.trim().isEmpty ? '' : '（${item.pinyin.trim()}）'}：${item.explain.isEmpty ? '未提供释义。' : item.explain}',
                  style: textTheme.bodyMedium,
                ),
              ),
            if (!closedKeys.contains('notes')) const Text('生成中…'),
          ],
        ],
      ),
    );
  }
}

class _LineNoteLoading extends StatelessWidget {
  const _LineNoteLoading();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 14),
            Text('正在为这一句寻找合适的说法…'),
          ],
        ),
      ),
    );
  }
}

class _LineNoteResult extends StatelessWidget {
  const _LineNoteResult({
    required this.note,
    required this.onEdit,
    required this.onRegenerate,
  });

  final LineNoteContent note;
  final VoidCallback onEdit;
  final VoidCallback onRegenerate;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('白话', style: textTheme.labelLarge),
          const SizedBox(height: 6),
          Text(
            note.translation.isEmpty ? '模型未提供直译。' : note.translation,
            style: textTheme.bodyLarge,
          ),
          if (note.notes.isNotEmpty) ...[
            const SizedBox(height: 18),
            Text('关键词注', style: textTheme.labelLarge),
            const SizedBox(height: 6),
            for (final item in note.notes)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  '${item.term}${item.pinyin.trim().isEmpty ? '' : '（${item.pinyin.trim()}）'}：${item.explain.isEmpty ? '未提供释义。' : item.explain}',
                  style: textTheme.bodyMedium,
                ),
              ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              TextButton.icon(
                onPressed: onEdit,
                icon: const Icon(Icons.edit_outlined),
                label: const Text('编辑注本'),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: onRegenerate,
                icon: const Icon(Icons.refresh),
                label: const Text('重新生成'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _LineNoteError extends StatelessWidget {
  const _LineNoteError({
    this.error,
    required this.onRetry,
    this.onOpenSettings,
  });

  final Object? error;
  final VoidCallback onRetry;
  final VoidCallback? onOpenSettings;

  @override
  Widget build(BuildContext context) {
    final parseError = error;
    if (parseError is AnnotationParseException &&
        parseError.rawText.trim().isNotEmpty) {
      return _LineNotePlainFallback(rawText: parseError.rawText);
    }
    final noKey =
        error is LlmException &&
        (error! as LlmException).kind == LlmErrorKind.noKey;
    if (noKey) {
      return _NoKeyGuide(onOpenSettings: onOpenSettings);
    }

    final llmError = error;
    final title = llmError is LlmException ? llmError.title : '这次没能生成注解';
    final detail = llmError is LlmException
        ? llmError.message
        : '请检查网络连接与 Base URL，或稍后再试。';
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_outlined),
            const SizedBox(height: 8),
            Text(title),
            const SizedBox(height: 4),
            Text(
              detail,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            OutlinedButton(onPressed: onRetry, child: const Text('再试一次')),
          ],
        ),
      ),
    );
  }
}

class _LineNotePlainFallback extends StatelessWidget {
  const _LineNotePlainFallback({required this.rawText});

  final String rawText;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '结构化解析失败，先展示模型原文',
            style: Theme.of(context).textTheme.labelLarge,
          ),
          const SizedBox(height: 8),
          SelectableText(rawText),
        ],
      ),
    );
  }
}

class _NoKeyGuide extends StatelessWidget {
  const _NoKeyGuide({this.onOpenSettings});

  final VoidCallback? onOpenSettings;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.auto_awesome_outlined),
            const SizedBox(height: 8),
            const Text('还没有配置 AI'),
            const SizedBox(height: 4),
            Text(
              '配置自己的模型后，点句即可生成直译与注解。',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
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

/// 便于 ReaderPage 调用的底部抽屉入口。
Future<void> showLineNoteSheet(
  BuildContext context, {
  required Poem poem,
  required int lineIndex,
  required String line,
  ValueChanged<LineNoteContent>? onNoteReady,
  VoidCallback? onOpenSettings,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => LineNoteSheet(
      poem: poem,
      lineIndex: lineIndex,
      line: line,
      onNoteReady: onNoteReady,
      onOpenSettings: onOpenSettings,
    ),
  );
}

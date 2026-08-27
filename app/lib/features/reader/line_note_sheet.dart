/// L1 逐句注底部抽屉。
///
/// Future 由 [AnnotationService] 负责缓存优先、LLM 调用与结构解析；
/// 这里仅负责渐进式反馈，不把供应商原始错误或堆栈展示给用户。
library;

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
    this.onOpenSettings,
  });

  final Poem poem;
  final int lineIndex;
  final String line;
  final VoidCallback? onOpenSettings;

  @override
  ConsumerState<LineNoteSheet> createState() => _LineNoteSheetState();
}

class _LineNoteSheetState extends ConsumerState<LineNoteSheet> {
  late Future<LineNoteContent> _noteFuture;

  @override
  void initState() {
    super.initState();
    _noteFuture = _load();
  }

  Future<LineNoteContent> _load() {
    return ref.read(annotationServiceProvider).getOrCreateLineNote(
          widget.poem,
          widget.lineIndex,
        );
  }

  void _retry() {
    setState(() {
      _noteFuture = _load();
    });
  }

  Future<NotebookEntry?> _entry() {
    return ref.read(notebookRepositoryProvider).byTarget(
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
    setState(() {
      _noteFuture = ref.read(annotationServiceProvider).getOrCreateLineNote(
            widget.poem,
            widget.lineIndex,
            forceRegenerate: true,
          );
    });
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
                child: FutureBuilder<LineNoteContent>(
                  future: _noteFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState != ConnectionState.done) {
                      return const _LineNoteLoading();
                    }
                    if (snapshot.hasError) {
                      return _LineNoteError(
                        error: snapshot.error,
                        onRetry: _retry,
                        onOpenSettings: widget.onOpenSettings,
                      );
                    }
                    final note = snapshot.data;
                    if (note == null) return _LineNoteError(onRetry: _retry);
                    return _LineNoteResult(
                      note: note,
                      onEdit: _edit,
                      onRegenerate: _regenerate,
                    );
                  },
                ),
              ),
            ],
          ),
        ),
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
                  '${item.term}：${item.explain.isEmpty ? '未提供释义。' : item.explain}',
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
    final noKey = error is LlmException &&
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
          Text('结构化解析失败，先展示模型原文',
              style: Theme.of(context).textTheme.labelLarge),
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
      onOpenSettings: onOpenSettings,
    ),
  );
}

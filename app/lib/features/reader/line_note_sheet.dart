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
import '../../domain/entities/poem.dart';

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
                    return _LineNoteResult(note: note);
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
  const _LineNoteResult({required this.note});

  final LineNoteContent note;

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
    final noKey = error is LlmException &&
        (error! as LlmException).kind == LlmErrorKind.noKey;
    if (noKey) {
      return _NoKeyGuide(onOpenSettings: onOpenSettings);
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_outlined),
            const SizedBox(height: 8),
            const Text('这次没能生成注解'),
            const SizedBox(height: 4),
            Text(
              '请检查网络或稍后再试。',
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

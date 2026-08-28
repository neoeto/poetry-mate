/// 诗词正文中被 AI 赏析标记的词语解释。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/llm/llm_exception.dart';
import '../../core/ui/app_theme.dart';
import '../../data/providers.dart';
import '../../domain/entities/annotations.dart';
import '../../domain/entities/notebook_entry.dart';
import '../../domain/entities/poem.dart';
import 'notebook_editor.dart';

class WordExplanationSheet extends StatelessWidget {
  const WordExplanationSheet({super.key, required this.note});

  final WordNote note;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 28),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 360),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _SheetHeader(
                  title: '词语释义',
                  onClose: () => Navigator.of(context).pop(),
                ),
                _WordExplanationContent(note: note),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SheetHeader extends StatelessWidget {
  const _SheetHeader({required this.title, required this.onClose});

  final String title;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(title, style: Theme.of(context).textTheme.titleMedium),
        ),
        IconButton(
          tooltip: '关闭',
          onPressed: onClose,
          icon: const Icon(Icons.close),
        ),
      ],
    );
  }
}

class _WordExplanationContent extends StatelessWidget {
  const _WordExplanationContent({required this.note});

  final WordNote note;

  @override
  Widget build(BuildContext context) {
    final pinyin = note.pinyin.trim();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (note.isUserSelected)
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Chip(
              avatar: Icon(Icons.touch_app_outlined, size: 16),
              label: Text('我选的词'),
            ),
          ),
        if (note.uncertain)
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Chip(
              avatar: Icon(Icons.info_outline, size: 16),
              label: Text('仅供参考'),
            ),
          ),
        const SizedBox(height: 8),
        Text(
          note.term,
          style: AppTheme.contentTextStyle(
            context,
            fontSize: 26,
            fontWeight: FontWeight.w600,
          ),
        ),
        if (pinyin.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            '拼音：$pinyin',
            style: AppTheme.contentTextStyle(
              context,
              fontSize: 18,
              height: 1.5,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
        ],
        const SizedBox(height: 12),
        Text(
          note.explain,
          style: AppTheme.contentTextStyle(context, fontSize: 20, height: 1.9),
        ),
      ],
    );
  }
}

/// 用户选词后的解释面板：负责请求、缓存命中以及用户注本操作。
class SelectedWordExplanationSheet extends ConsumerStatefulWidget {
  const SelectedWordExplanationSheet({
    super.key,
    required this.poem,
    required this.position,
    this.onChanged,
    this.onOpenSettings,
  });

  final Poem poem;
  final SelectedWordPosition position;
  final VoidCallback? onChanged;
  final VoidCallback? onOpenSettings;

  @override
  ConsumerState<SelectedWordExplanationSheet> createState() =>
      _SelectedWordExplanationSheetState();
}

class _SelectedWordExplanationSheetState
    extends ConsumerState<SelectedWordExplanationSheet> {
  late Future<WordNote> _noteFuture;

  @override
  void initState() {
    super.initState();
    _noteFuture = _load();
  }

  Future<WordNote> _load({bool forceRegenerate = false}) async {
    final note = await ref
        .read(annotationServiceProvider)
        .getOrCreateSelectedWordNote(
          widget.poem,
          widget.position,
          forceRegenerate: forceRegenerate,
        );
    widget.onChanged?.call();
    return note;
  }

  void _retry() {
    setState(() => _noteFuture = _load());
  }

  Future<NotebookEntry?> _entry() {
    return ref
        .read(notebookRepositoryProvider)
        .byTarget(
          poemId: widget.poem.id,
          kind: NotebookKind.wordNote,
          target: widget.position.target,
        );
  }

  Future<void> _edit() async {
    final entry = await _entry();
    if (entry == null || !mounted) return;
    final saved = await showNotebookEntryEditor(context, entry);
    if (saved != true || !mounted) return;
    widget.onChanged?.call();
    // 编辑器的“删除”也会返回 true；删除后关闭当前解释面板，
    // 不要立刻把它当成缓存未命中而重新请求 AI。
    if (await _entry() == null) {
      if (mounted) Navigator.of(context).pop();
      return;
    }
    if (mounted) _retry();
  }

  Future<void> _regenerate() async {
    final entry = await _entry();
    if (!mounted) return;
    final confirmed = await confirmRegeneration(
      context,
      userEdited: entry?.userEdited ?? false,
    );
    if (!confirmed || !mounted) return;
    setState(() => _noteFuture = _load(forceRegenerate: true));
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 28),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 520),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _SheetHeader(
                title: 'AI 解释',
                onClose: () => Navigator.of(context).pop(),
              ),
              Text(
                '已选择「${widget.position.term}」',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 12),
              Flexible(
                child: FutureBuilder<WordNote>(
                  future: _noteFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState != ConnectionState.done) {
                      return const _SelectedWordLoading();
                    }
                    if (snapshot.hasError) {
                      return _SelectedWordError(
                        error: snapshot.error,
                        onRetry: _retry,
                        onOpenSettings: widget.onOpenSettings,
                      );
                    }
                    final note = snapshot.data;
                    if (note == null) {
                      return _SelectedWordError(onRetry: _retry);
                    }
                    return SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _WordExplanationContent(note: note),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              TextButton.icon(
                                onPressed: _edit,
                                icon: const Icon(Icons.edit_outlined),
                                label: const Text('编辑注本'),
                              ),
                              const Spacer(),
                              TextButton.icon(
                                onPressed: _regenerate,
                                icon: const Icon(Icons.refresh),
                                label: const Text('重新生成'),
                              ),
                            ],
                          ),
                        ],
                      ),
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

class _SelectedWordLoading extends StatelessWidget {
  const _SelectedWordLoading();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 36),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 14),
            Text('正在解释你选中的词语…'),
          ],
        ),
      ),
    );
  }
}

class _SelectedWordError extends StatelessWidget {
  const _SelectedWordError({
    this.error,
    required this.onRetry,
    this.onOpenSettings,
  });

  final Object? error;
  final VoidCallback onRetry;
  final VoidCallback? onOpenSettings;

  @override
  Widget build(BuildContext context) {
    final noKey =
        error is LlmException &&
        (error! as LlmException).kind == LlmErrorKind.noKey;
    if (noKey) {
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
                '配置自己的模型后，就能解释你选中的词语。',
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

    final llmError = error;
    final title = llmError is LlmException ? llmError.title : '这次没能解释这个词';
    final detail = llmError is LlmException
        ? llmError.message
        : '请检查网络连接与模型配置，或稍后再试。';
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

Future<void> showWordExplanationSheet(BuildContext context, WordNote note) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => WordExplanationSheet(note: note),
  );
}

Future<void> showSelectedWordExplanationSheet(
  BuildContext context, {
  required Poem poem,
  required SelectedWordPosition position,
  VoidCallback? onChanged,
  VoidCallback? onOpenSettings,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => SelectedWordExplanationSheet(
      poem: poem,
      position: position,
      onChanged: onChanged,
      onOpenSettings: onOpenSettings,
    ),
  );
}

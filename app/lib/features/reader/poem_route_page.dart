/// 阅读页路由壳 —— AppBar 承载收藏心形与白文开关。

library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/llm/annotation_service.dart';
import '../../data/preferences/reading_settings_controller.dart';
import '../../data/providers.dart';
import '../../domain/entities/poem.dart';
import '../poem_deletion_dialog.dart';
import 'chat_sheet.dart';
import 'reader_page.dart';

class PoemRoutePage extends ConsumerWidget {
  const PoemRoutePage({super.key, required this.poemId});

  final String poemId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final poemAsync = ref.watch(poemByIdProvider(poemId));
    return poemAsync.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(body: Center(child: Text('加载失败: $e'))),
      data: (poem) => poem == null
          ? const Scaffold(body: Center(child: Text('未找到该诗篇')))
          : PoemReaderScaffold(
              poem: poem,
              onDelete: () async {
                await ref.read(poemRepositoryProvider).delete(poem.id);
                ref.invalidate(poemByIdProvider(poem.id));
                ref.invalidate(isFavoriteProvider(poem.id));
                ref.invalidate(favoriteItemsProvider);
                if (context.mounted) {
                  await Navigator.of(context).maybePop();
                }
              },
            ),
    );
  }
}

/// 公共库、扩展库和临时作品共用的阅读外壳。
class PoemReaderScaffold extends ConsumerWidget {
  const PoemReaderScaffold({
    super.key,
    required this.poem,
    this.annotationContext,
    this.sourceInfo,
    this.showFavorite = true,
    this.onDelete,
  });

  final Poem poem;
  final AnnotationContext? annotationContext;
  final PoemSourceInfo? sourceInfo;
  final bool showFavorite;
  final Future<void> Function()? onDelete;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final plainText = ref.watch(readingSettingsProvider).plainText;
    final favoriteAsync = showFavorite
        ? ref.watch(isFavoriteProvider(poem.id))
        : null;
    final isFavorite = favoriteAsync?.value == true;

    return Scaffold(
      appBar: AppBar(
        actions: [
          IconButton(
            tooltip: '问 AI',
            onPressed: () => showChatSheet(
              context,
              poem: poem,
              annotationContext: annotationContext,
              onOpenSettings: () {
                Navigator.of(context).pop();
                context.push('/settings/llm');
              },
            ),
            icon: const Icon(Icons.chat_bubble_outline),
          ),
          IconButton(
            tooltip: plainText ? '显示标点' : '白文模式',
            onPressed: () =>
                ref.read(readingSettingsProvider.notifier).togglePlainText(),
            icon: Icon(
              Icons.text_format_outlined,
              color: plainText ? Theme.of(context).colorScheme.primary : null,
            ),
          ),
          if (showFavorite)
            IconButton(
              tooltip: isFavorite ? '取消收藏' : '收藏',
              onPressed: () async {
                final repo = ref.read(favoritesRepositoryProvider);
                if (isFavorite) {
                  await repo.remove(poem.id);
                } else {
                  await repo.add(poem.id);
                }
                ref.invalidate(isFavoriteProvider(poem.id));
                ref.invalidate(favoriteItemsProvider);
              },
              icon: Icon(
                isFavorite ? Icons.favorite : Icons.favorite_border,
                color: isFavorite ? Theme.of(context).colorScheme.error : null,
              ),
            ),
          if (onDelete != null)
            IconButton(
              tooltip: '删除诗词',
              icon: const Icon(Icons.delete_outline),
              onPressed: () => _confirmAndDelete(context, poem, onDelete!),
            ),
        ],
      ),
      body: ReaderPage(
        poem: poem,
        annotationContext: annotationContext,
        sourceInfo: sourceInfo,
      ),
    );
  }

  Future<void> _confirmAndDelete(
    BuildContext context,
    Poem poem,
    Future<void> Function() delete,
  ) async {
    final confirmed = await confirmPoemDeletion(
      context,
      title: poem.displayTitle,
    );
    if (!confirmed || !context.mounted) return;

    try {
      await delete();
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('删除失败：$error')));
    }
  }
}

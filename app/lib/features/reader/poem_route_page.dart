/// 阅读页路由壳 —— AppBar 承载收藏心形与白文开关。

library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/llm/annotation_service.dart';
import '../../data/preferences/reading_settings_controller.dart';
import '../../data/providers.dart';
import '../../domain/entities/poem.dart';
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
          : PoemReaderScaffold(poem: poem),
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
  });

  final Poem poem;
  final AnnotationContext? annotationContext;
  final PoemSourceInfo? sourceInfo;
  final bool showFavorite;

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
        ],
      ),
      body: ReaderPage(
        poem: poem,
        annotationContext: annotationContext,
        sourceInfo: sourceInfo,
      ),
    );
  }
}

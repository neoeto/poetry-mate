/// 阅读页路由壳 —— AppBar 承载收藏心形与白文开关(任务 3.1)。

library;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/preferences/reading_settings_controller.dart';
import '../../data/providers.dart';
import 'reader_page.dart';

class PoemRoutePage extends ConsumerWidget {
  const PoemRoutePage({super.key, required this.poemId});

  final String poemId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final poemAsync = ref.watch(poemByIdProvider(poemId));
    final favoriteAsync = ref.watch(isFavoriteProvider(poemId));
    final plainText = ref.watch(readingSettingsProvider).plainText;

    return Scaffold(
      appBar: AppBar(
        actions: [
          // ── 白文模式开关 ──
          IconButton(
            tooltip: plainText ? '显示标点' : '白文模式',
            onPressed: () => ref
                .read(readingSettingsProvider.notifier)
                .togglePlainText(),
            icon: Icon(
              Icons.text_format_outlined,
              color: plainText ? Theme.of(context).colorScheme.primary : null,
            ),
          ),
          // ── 收藏心形 ──
          IconButton(
            tooltip: favoriteAsync.value == true ? '取消收藏' : '收藏',
            onPressed: () async {
              final repo = ref.read(favoritesRepositoryProvider);
              if (favoriteAsync.value == true) {
                await repo.remove(poemId);
              } else {
                await repo.add(poemId);
              }
              ref.invalidate(isFavoriteProvider(poemId));
            },
            icon: Icon(
              favoriteAsync.value == true
                  ? Icons.favorite
                  : Icons.favorite_border,
              color: favoriteAsync.value == true
                  ? Theme.of(context).colorScheme.error
                  : null,
            ),
          ),
        ],
      ),
      body: poemAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('加载失败: $e')),
        data: (poem) => poem == null
            ? const Center(child: Text('未找到该诗篇'))
            : ReaderPage(poem: poem),
      ),
    );
  }
}

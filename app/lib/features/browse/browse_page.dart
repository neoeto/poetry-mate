/// 分类页 —— 朝代 × 类型过滤浏览种子集(任务 4.2)。
///
/// 列表项: 展示标题(词类回退词牌) + 作者·朝代;
/// 点击进入阅读页深链 /poem/:id。

library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/providers.dart';
import '../../domain/entities/poem.dart';
import '../poem_deletion_dialog.dart';
import 'browse_filters.dart';
import 'poem_search_delegate.dart';

class BrowsePage extends ConsumerWidget {
  const BrowsePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(browseFilterProvider);
    final poemsAsync = ref.watch(filteredPoemsProvider(selected));

    return Scaffold(
      appBar: AppBar(
        title: const Text('分类'),
        actions: [
          IconButton(
            tooltip: '搜索诗词',
            icon: const Icon(Icons.search),
            onPressed: () async {
              final poem = await showSearch<Poem>(
                context: context,
                delegate: PoemSearchDelegate(ref.read(poemRepositoryProvider)),
              );
              if (context.mounted && poem != null) {
                context.push('/poem/${poem.id}');
              }
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // ── 过滤 chips ──
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Wrap(
              spacing: 8,
              children: [
                for (final f in BrowseFilters.all)
                  FilterChip(
                    label: Text(f.label),
                    selected: selected == f.key,
                    onSelected: (_) =>
                        ref.read(browseFilterProvider.notifier).state = f.key,
                  ),
              ],
            ),
          ),
          // ── 诗列表 ──
          Expanded(
            child: poemsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('加载失败: $e')),
              data: (poems) {
                if (poems.isEmpty) {
                  return const Center(child: Text('该分类下暂无诗篇'));
                }
                return ListView.builder(
                  itemCount: poems.length,
                  itemBuilder: (_, index) {
                    final poem = poems[index];
                    return ListTile(
                      key: ValueKey('poem-${poem.id}'),
                      title: Text(
                        poem.displayTitle.isEmpty
                            ? poem.paragraphs.first
                            : poem.displayTitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text('${poem.author} · ${poem.dynasty}'),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (poem.popularity != null)
                            Text(
                              poem.popularity!.toStringAsFixed(1),
                              style: Theme.of(context).textTheme.labelSmall,
                            ),
                          IconButton(
                            key: ValueKey('delete-poem-${poem.id}'),
                            tooltip: '删除诗词',
                            icon: const Icon(Icons.delete_outline),
                            onPressed: () => _deletePoem(
                              context,
                              ref,
                              poem,
                              selected,
                            ),
                          ),
                        ],
                      ),
                      onTap: () => context.push('/poem/${poem.id}'),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _deletePoem(
    BuildContext context,
    WidgetRef ref,
    Poem poem,
    String filterKey,
  ) async {
    final confirmed = await confirmPoemDeletion(
      context,
      title: poem.displayTitle,
    );
    if (!confirmed || !context.mounted) return;

    try {
      await ref.read(poemRepositoryProvider).delete(poem.id);
      ref.invalidate(filteredPoemsProvider(filterKey));
      ref.invalidate(poemByIdProvider(poem.id));
      ref.invalidate(favoriteItemsProvider);
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('已从本地诗库删除')));
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('删除失败：$error')));
    }
  }
}

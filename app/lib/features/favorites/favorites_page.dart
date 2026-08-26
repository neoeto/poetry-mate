/// 收藏页 —— 真实读取 favorites + poems 联表结果。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/providers.dart';
import '../../domain/entities/favorite_item.dart';

class FavoritesPage extends ConsumerWidget {
  const FavoritesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final favorites = ref.watch(favoriteItemsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('收藏')),
      body: favorites.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('收藏加载失败，请稍后再试：$error')),
        data: (items) => items.isEmpty
            ? const _EmptyFavorites()
            : _FavoriteList(items: items),
      ),
    );
  }
}

class _FavoriteList extends StatelessWidget {
  const _FavoriteList({required this.items});

  final List<FavoriteItem> items;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: items.length,
      separatorBuilder: (_, _) => const Divider(height: 1, indent: 72),
      itemBuilder: (context, index) {
        final item = items[index];
        return ListTile(
          key: ValueKey('favorite-${item.poem.id}'),
          leading: const Icon(Icons.favorite),
          title: Text(item.poem.displayTitle),
          subtitle: Text('${item.poem.author} · ${item.poem.dynasty}'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => context.push('/poem/${item.poem.id}'),
        );
      },
    );
  }
}

class _EmptyFavorites extends StatelessWidget {
  const _EmptyFavorites();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.favorite_border_outlined,
            size: 56,
            color: Theme.of(context).colorScheme.outline,
          ),
          const SizedBox(height: 16),
          Text('收藏夹还空着', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Text(
            '读到心动处，点一颗心，\n它会在这里等你。',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
        ],
      ),
    );
  }
}

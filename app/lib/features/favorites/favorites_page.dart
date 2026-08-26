/// 收藏页占位(任务 4.3) —— 友好空状态。
/// 真实收藏功能归 reading-page 变更(阅读页点心后此处列出)。
library;

import 'package:flutter/material.dart';

class FavoritesPage extends StatelessWidget {
  const FavoritesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('收藏')),
      body: Center(
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
              '读到心动处,点一颗心,\n它会在这里等你。',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 本地诗词搜索页。
///
/// 只通过 PoemRepository 读取 SQLite，不访问网络，也不触发 LLM。
library;

import 'package:flutter/material.dart';

import '../../data/repositories/poem_repository.dart';
import '../../domain/entities/poem.dart';

class PoemSearchDelegate extends SearchDelegate<Poem> {
  PoemSearchDelegate(PoemRepository repository)
    : _repository = repository,
      super(
        searchFieldLabel: '搜索诗名、作者或诗句',
        keyboardType: TextInputType.text,
        textInputAction: TextInputAction.search,
      );

  final PoemRepository _repository;

  @override
  List<Widget> buildActions(BuildContext context) {
    if (query.isEmpty) return const [];
    return [
      IconButton(
        tooltip: '清除搜索',
        onPressed: () => query = '',
        icon: const Icon(Icons.clear),
      ),
    ];
  }

  @override
  Widget buildLeading(BuildContext context) {
    return IconButton(
      tooltip: '返回',
      onPressed: () => Navigator.of(context).pop(),
      icon: const Icon(Icons.arrow_back),
    );
  }

  @override
  Widget buildSuggestions(BuildContext context) => _buildBody(context);

  @override
  Widget buildResults(BuildContext context) => _buildBody(context);

  Widget _buildBody(BuildContext context) {
    final keyword = query.trim();
    if (keyword.isEmpty) {
      return const _SearchHint();
    }

    return FutureBuilder<List<Poem>>(
      future: _repository.search(keyword),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return const Center(child: Text('搜索失败，请稍后再试'));
        }
        final poems = snapshot.data ?? const <Poem>[];
        if (poems.isEmpty) {
          return const _NoSearchResult();
        }
        return ListView.builder(
          padding: const EdgeInsets.only(top: 8, bottom: 24),
          itemCount: poems.length,
          itemBuilder: (context, index) {
            final poem = poems[index];
            final title = poem.displayTitle.isEmpty
                ? (poem.paragraphs.isEmpty ? '未命名诗篇' : poem.paragraphs.first)
                : poem.displayTitle;
            final excerpt = poem.paragraphs.isEmpty
                ? ''
                : poem.paragraphs.take(2).join(' ');
            return ListTile(
              title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
              subtitle: Text(
                excerpt.isEmpty
                    ? '${poem.author} · ${poem.dynasty}'
                    : '${poem.author} · ${poem.dynasty}\n$excerpt',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              onTap: () => close(context, poem),
            );
          },
        );
      },
    );
  }
}

class _SearchHint extends StatelessWidget {
  const _SearchHint();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.manage_search_outlined,
              size: 52,
              color: Theme.of(context).colorScheme.outline,
            ),
            const SizedBox(height: 14),
            const Text('输入诗名、作者、词牌或诗句'),
          ],
        ),
      ),
    );
  }
}

class _NoSearchResult extends StatelessWidget {
  const _NoSearchResult();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.search_off_outlined,
              size: 52,
              color: Theme.of(context).colorScheme.outline,
            ),
            const SizedBox(height: 14),
            const Text('未找到相关诗篇'),
            const SizedBox(height: 6),
            Text('换个诗名、作者或诗句试试', style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}

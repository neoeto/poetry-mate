/// 我的注本 —— 按诗聚合展示本机保存的逐句注、赏析与追问。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/providers.dart';
import '../../data/repositories/poem_catalog_repository.dart';
import '../../domain/entities/notebook_entry.dart';
import '../../domain/entities/poem.dart';
import '../reader/notebook_editor.dart';

class NotebookEntryWithPoem {
  const NotebookEntryWithPoem({
    required this.entry,
    required this.poem,
    this.isExtended = false,
  });

  final NotebookEntry entry;
  final Poem poem;
  final bool isExtended;
}

final notebookEntriesWithPoemProvider =
    FutureProvider.autoDispose<List<NotebookEntryWithPoem>>((ref) async {
      final entries = await ref.watch(notebookRepositoryProvider).listAll();
      final catalog = ref.watch(poemCatalogRepositoryProvider);
      final poemIds = entries.map((entry) => entry.poemId).toSet();
      final resolved = await Future.wait(
        poemIds.map((id) async => MapEntry(id, await catalog.byId(id))),
      );
      final matchById = {for (final item in resolved) item.key: item.value};
      return [
        for (final entry in entries)
          if (matchById[entry.poemId] case final match?)
            NotebookEntryWithPoem(
              entry: entry,
              poem: match.poem,
              isExtended: match.kind == PoemCatalogKind.extended,
            ),
      ];
    });

class NotebookPage extends ConsumerWidget {
  const NotebookPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entries = ref.watch(notebookEntriesWithPoemProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('我的注本')),
      body: entries.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => const Center(child: Text('注本加载失败，请稍后再试')),
        data: (items) => items.isEmpty
            ? const _EmptyNotebook()
            : _NotebookList(items: items),
      ),
    );
  }
}

class _NotebookList extends ConsumerWidget {
  const _NotebookList({required this.items});

  final List<NotebookEntryWithPoem> items;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final groups = <String, _NotebookGroupData>{};
    for (final item in items) {
      final group = groups.putIfAbsent(
        item.poem.id,
        () => _NotebookGroupData(poem: item.poem, isExtended: item.isExtended),
      );
      group.entries.add(item);
    }

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(notebookEntriesWithPoemProvider);
        await ref.read(notebookEntriesWithPoemProvider.future);
      },
      child: ListView(
        padding: const EdgeInsets.only(top: 8, bottom: 28),
        children: [
          for (final group in groups.values)
            _NotebookGroup(
              key: ValueKey('notebook-group-${group.poem.id}'),
              group: group,
              onChanged: () => ref.invalidate(notebookEntriesWithPoemProvider),
            ),
        ],
      ),
    );
  }
}

class _NotebookGroupData {
  _NotebookGroupData({required this.poem, required this.isExtended});

  final Poem poem;
  final bool isExtended;
  final List<NotebookEntryWithPoem> entries = [];
}

class _NotebookGroup extends StatelessWidget {
  const _NotebookGroup({
    super.key,
    required this.group,
    required this.onChanged,
  });

  final _NotebookGroupData group;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final poem = group.poem;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ListTile(
          leading: const Icon(Icons.menu_book_outlined),
          title: Text(poem.displayTitle.isEmpty ? '未命名诗篇' : poem.displayTitle),
          subtitle: Text('${poem.author} · ${poem.dynasty}'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => context.push(
            group.isExtended ? '/extended-poem/${poem.id}' : '/poem/${poem.id}',
          ),
        ),
        for (final item in group.entries)
          _NotebookEntryTile(item: item, onChanged: onChanged),
        const Divider(height: 20),
      ],
    );
  }
}

class _NotebookEntryTile extends StatelessWidget {
  const _NotebookEntryTile({required this.item, required this.onChanged});

  final NotebookEntryWithPoem item;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final entry = item.entry;
    return ListTile(
      key: ValueKey('notebook-entry-${entry.id}'),
      contentPadding: const EdgeInsets.only(left: 72, right: 16),
      leading: Icon(_entryIcon(entry.kind)),
      title: Text(_entryTitle(entry)),
      subtitle: Text(
        _entryPreview(entry),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: const Icon(Icons.edit_outlined, size: 20),
      onTap: () async {
        final saved = await showNotebookEntryEditor(context, entry);
        if (saved == true) onChanged();
      },
    );
  }
}

class _EmptyNotebook extends StatelessWidget {
  const _EmptyNotebook();

  @override
  Widget build(BuildContext context) {
    final outline = Theme.of(context).colorScheme.outline;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.book_outlined, size: 56, color: outline),
            const SizedBox(height: 16),
            Text('注本还空着', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            const Text(
              '在诗句、赏析或追问中留下你的理解，\n它们会一直留在这里。',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

IconData _entryIcon(String kind) {
  switch (kind) {
    case NotebookKind.lineNote:
      return Icons.format_quote_outlined;
    case NotebookKind.essay:
      return Icons.article_outlined;
    case NotebookKind.chatTurn:
      return Icons.chat_bubble_outline;
    case NotebookKind.wordNote:
      return Icons.touch_app_outlined;
    default:
      return Icons.edit_note_outlined;
  }
}

String _entryTitle(NotebookEntry entry) {
  switch (entry.kind) {
    case NotebookKind.lineNote:
      final line = (int.tryParse(entry.target ?? '') ?? 0) + 1;
      return '逐句注 · 第 $line 句';
    case NotebookKind.essay:
      return '整篇赏析';
    case NotebookKind.chatTurn:
      return '追问 · ${entry.target ?? '未命名问题'}';
    case NotebookKind.wordNote:
      return '用户选词解释 · ${(entry.content['term'] ?? '未命名词语').toString()}';
    default:
      return '个人批注';
  }
}

String _entryPreview(NotebookEntry entry) {
  dynamic value;
  switch (entry.kind) {
    case NotebookKind.lineNote:
      value = entry.content['translation'];
    case NotebookKind.essay:
      value = entry.content['summary'];
    case NotebookKind.chatTurn:
      value = entry.content['answer'];
    case NotebookKind.wordNote:
      value = entry.content['explain'];
    default:
      value = entry.content['note'];
  }
  final preview = (value ?? '')
      .toString()
      .replaceAll(RegExp(r'[`*_#>~]'), '')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  return preview.isEmpty ? '尚未填写内容' : preview;
}

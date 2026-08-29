/// 扩展诗词库列表、持久化作品阅读页和一次性作品阅读页。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/llm/annotation_service.dart';
import '../../data/extended/poem_fingerprint.dart';
import '../../data/providers.dart';
import '../../domain/entities/extended_poem.dart';
import '../poem_deletion_dialog.dart';
import '../reader/poem_route_page.dart';

class ExtendedLibraryPage extends ConsumerWidget {
  const ExtendedLibraryPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final poems = ref.watch(visibleExtendedPoemsProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('扩展诗词库'),
        actions: [
          IconButton(
            tooltip: 'AI 寻诗',
            icon: const Icon(Icons.auto_awesome_outlined),
            onPressed: () => context.push('/ai-find'),
          ),
        ],
      ),
      body: poems.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('扩展诗词库加载失败：$error')),
        data: (items) => items.isEmpty
            ? const _EmptyExtendedLibrary()
            : RefreshIndicator(
                onRefresh: () async {
                  ref.invalidate(visibleExtendedPoemsProvider);
                  await ref.read(visibleExtendedPoemsProvider.future);
                },
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: items.length,
                  separatorBuilder: (_, _) =>
                      const Divider(height: 1, indent: 72),
                  itemBuilder: (context, index) {
                    final poem = items[index];
                    return ListTile(
                      key: ValueKey('extended-poem-${poem.id}'),
                      leading: const Icon(Icons.auto_awesome_outlined),
                      title: Text(poem.displayTitle),
                      subtitle: Text(
                        '${poem.authorLabel} · ${poem.periodLabel}${poem.sourceInfo.isUncertain ? ' · 信息待核' : ''}',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            key: ValueKey('delete-extended-poem-${poem.id}'),
                            tooltip: '删除诗词',
                            icon: const Icon(Icons.delete_outline),
                            onPressed: () => _deletePoem(context, ref, poem),
                          ),
                          const Icon(Icons.chevron_right),
                        ],
                      ),
                      onTap: () => context.push('/extended-poem/${poem.id}'),
                    );
                  },
                ),
              ),
      ),
    );
  }

  Future<void> _deletePoem(
    BuildContext context,
    WidgetRef ref,
    ExtendedPoem poem,
  ) async {
    final confirmed = await confirmPoemDeletion(context, title: poem.title);
    if (!confirmed || !context.mounted) return;

    try {
      await ref.read(extendedPoemRepositoryProvider).delete(poem.id);
      ref.invalidate(visibleExtendedPoemsProvider);
      ref.invalidate(extendedPoemByIdProvider(poem.id));
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

class _EmptyExtendedLibrary extends StatelessWidget {
  const _EmptyExtendedLibrary();

  @override
  Widget build(BuildContext context) {
    final outline = Theme.of(context).colorScheme.outline;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.auto_awesome_outlined, size: 56, color: outline),
            const SizedBox(height: 16),
            Text('扩展诗词库还空着', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            const Text(
              '让 AI 帮你从更广的中文文学中寻一首，\n喜欢的作品可以收进这里。',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () => context.push('/ai-find'),
              icon: const Icon(Icons.search),
              label: const Text('开始 AI 寻诗'),
            ),
          ],
        ),
      ),
    );
  }
}

class ExtendedPoemRoutePage extends ConsumerWidget {
  const ExtendedPoemRoutePage({super.key, required this.poemId});

  final String poemId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final poem = ref.watch(extendedPoemByIdProvider(poemId));
    return poem.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (error, _) => Scaffold(body: Center(child: Text('加载失败：$error'))),
      data: (value) => value == null
          ? const Scaffold(body: Center(child: Text('未找到该扩展作品')))
          : PoemReaderScaffold(
              poem: value.toPoem(),
              sourceInfo: value.sourceInfo,
              showFavorite: false,
              onDelete: () async {
                await ref
                    .read(extendedPoemRepositoryProvider)
                    .delete(value.id);
                ref.invalidate(visibleExtendedPoemsProvider);
                ref.invalidate(extendedPoemByIdProvider(value.id));
                if (context.mounted) {
                  await Navigator.of(context).maybePop();
                }
              },
            ),
    );
  }
}

/// AI 结果页选择“仅本次查看”后使用的内存阅读页面。
class TransientPoemPage extends ConsumerStatefulWidget {
  const TransientPoemPage({super.key, required this.draft});

  final ExtendedPoemDraft draft;

  @override
  ConsumerState<TransientPoemPage> createState() => _TransientPoemPageState();
}

class _TransientPoemPageState extends ConsumerState<TransientPoemPage> {
  late final ExtendedPoem _poem;
  late final AnnotationContext _annotationContext;

  @override
  void initState() {
    super.initState();
    final fingerprint = poemContentFingerprint(
      widget.draft.paragraphs,
      preface: widget.draft.preface,
    );
    _poem = ExtendedPoem.fromDraft(
      draft: widget.draft,
      id: 'temp_$fingerprint',
      fingerprint: fingerprint,
    );
    _annotationContext = AnnotationContext.transient();
  }

  @override
  Widget build(BuildContext context) {
    return PoemReaderScaffold(
      poem: _poem.toPoem(),
      sourceInfo: _poem.sourceInfo,
      annotationContext: _annotationContext,
      showFavorite: false,
    );
  }
}

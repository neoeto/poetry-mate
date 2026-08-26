/// 今日页占位(任务 4.3): 本地随机一首 + 策展预告。
///
/// LLM 每日策展归 today-feed 变更;当前用纯本地随机维持"开箱有惊喜"的活感。

library;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/ui/app_theme.dart';
import '../../data/providers.dart';

class TodayPage extends ConsumerStatefulWidget {
  const TodayPage({super.key});

  @override
  ConsumerState<TodayPage> createState() => _TodayPageState();
}

class _TodayPageState extends ConsumerState<TodayPage> {
  late Future<dynamic> _randomFuture;

  @override
  void initState() {
    super.initState();
    _randomFuture = ref.read(poemRepositoryProvider).randomOne();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('今日')),
      body: FutureBuilder(
        future: _randomFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final poem = snapshot.data;
          if (poem == null) {
            return const Center(child: Text('诗库还是空的,先去导入一些诗吧'));
          }

          return RefreshIndicator(
            onRefresh: () async {
              setState(() {
                _randomFuture = ref.read(poemRepositoryProvider).randomOne();
              });
              await _randomFuture;
            },
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                // ── 策展预告横幅 ──
                Card(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    child: Row(
                      children: [
                        Icon(Icons.auto_awesome,
                            size: 14,
                            color: Theme.of(context).colorScheme.primary),
                        const SizedBox(width: 6),
                        Text(
                          'AI 每日策展即将到来,现在先随机偶遇一首',
                          style: Theme.of(context).textTheme.labelSmall,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // ── 随机诗卡 ──
                Card(
                  margin: EdgeInsets.zero,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => context.push('/poem/${poem.id}'),
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            poem.displayTitle.isEmpty
                                ? poem.paragraphs.first
                                : poem.displayTitle,
                            style: Theme.of(context)
                                .textTheme
                                .titleLarge
                                ?.copyWith(fontFamily: PoetryFonts.content),
                          ),
                          const SizedBox(height: 4),
                          Align(
                            alignment: Alignment.centerRight,
                            child: Text('${poem.author} · ${poem.dynasty}',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onSurfaceVariant)),
                          ),
                          const SizedBox(height: 16),
                          Text(poem.paragraphs.first,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: AppTheme.contentTextStyle(context,
                                  fontSize: 18)),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Center(
                  child: Text('下拉换一首',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: Theme.of(context).colorScheme.outline)),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

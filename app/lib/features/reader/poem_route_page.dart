/// 阅读页路由壳 —— 按 id 从仓库取诗,渲染 ReaderPage。

library;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers.dart';
import 'reader_page.dart';

class PoemRoutePage extends ConsumerWidget {
  const PoemRoutePage({super.key, required this.poemId});

  final String poemId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final poemAsync = ref.watch(poemByIdProvider(poemId));

    return Scaffold(
      appBar: AppBar(),
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

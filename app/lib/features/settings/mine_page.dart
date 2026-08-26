/// 「我的」页占位(任务 4.3) —— 功能预告清单。
/// 各项落地顺序: 导入书架(import-wizard) → LLM 配置+人格(ai-annotation) → 注本导出(v2)。
library;

import 'package:flutter/material.dart';

class MinePage extends StatelessWidget {
  const MinePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('我的')),
      body: ListView(
        children: [
          const SizedBox(height: 8),
          _coming(context, Icons.auto_stories, '导入书架', '从数据源搬回整座图书馆'),
          _coming(context, Icons.psychology_outlined, 'LLM 配置', '接入你自己的 AI 模型'),
          _coming(context, Icons.face_retouching_natural, '人格选择', '先生 · 知音 · 词客'),
          _coming(context, Icons.book_outlined, '我的注本', '你的批注与足迹'),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('关于 Poetry Mate'),
            onTap: () => showAboutDialog(
              context: context,
              applicationName: 'Poetry Mate',
              applicationLegalese: '诗词数据: chinese-poetry (MIT)',
            ),
          ),
        ],
      ),
    );
  }

  Widget _coming(BuildContext context, IconData icon, String title, String subtitle) {
    final outline = Theme.of(context).colorScheme.outline;
    final comingStyle =
        Theme.of(context).textTheme.labelSmall?.copyWith(color: outline);
    return ListTile(
      enabled: false,
      leading: Icon(icon, color: outline),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: Text('即将', style: comingStyle),
    );
  }
}

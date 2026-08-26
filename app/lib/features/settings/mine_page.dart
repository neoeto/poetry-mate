/// 「我的」页 —— LLM 配置与阅读偏好。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/llm/persona.dart';
import '../../data/preferences/reading_prefs.dart';
import '../../data/preferences/reading_settings_controller.dart';
import '../../data/providers.dart';

class MinePage extends ConsumerWidget {
  const MinePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final readingSettings = ref.watch(readingSettingsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('我的')),
      body: ListView(
        children: [
          const SizedBox(height: 8),
          _coming(context, Icons.auto_stories, '导入书架', '从数据源搬回整座图书馆'),
          ListTile(
            leading: const Icon(Icons.psychology_outlined),
            title: const Text('LLM 配置'),
            subtitle: const Text('接入你自己的 AI 模型'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/settings/llm'),
          ),
          _personaTile(context, ref),
          const Divider(height: 28),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
            child: Text(
              '阅读偏好',
              style: Theme.of(context).textTheme.titleSmall,
            ),
          ),
          ListTile(
            title: const Text('正文字号'),
            trailing: Text('${readingSettings.fontSize.round()}sp'),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Slider(
              min: kMinContentFontSize,
              max: kMaxContentFontSize,
              divisions: (kMaxContentFontSize - kMinContentFontSize).round(),
              value: readingSettings.fontSize.clamp(
                kMinContentFontSize,
                kMaxContentFontSize,
              ),
              label: '${readingSettings.fontSize.round()}sp',
              onChanged: (value) => ref
                  .read(readingSettingsProvider.notifier)
                  .setFontSize(value),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('${kMinContentFontSize.round()}sp'),
                Text('${kMaxContentFontSize.round()}sp'),
              ],
            ),
          ),
          _coming(context, Icons.book_outlined, '我的注本', '你的批注与足迹'),
          const Divider(height: 28),
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

  Widget _personaTile(
    BuildContext context,
    WidgetRef ref,
  ) {
    final selected = ref.watch(personaSelectionProvider);
    final selectedPersona = personaById(selected.value ?? defaultPersonaId);
    return ListTile(
      leading: const Icon(Icons.face_retouching_natural),
      title: const Text('AI 人格'),
      subtitle: selected.when(
        loading: () => const Text('读取中…'),
        error: (_, _) => Text('${selectedPersona.name} · ${selectedPersona.description}'),
        data: (id) {
          final persona = personaById(id);
          return Text('${persona.name} · ${persona.description}');
        },
      ),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => _pickPersona(context, ref, selectedPersona.id),
    );
  }

  Future<void> _pickPersona(
    BuildContext context,
    WidgetRef ref,
    String selectedId,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.only(bottom: 16),
          children: [
            const ListTile(title: Text('选择 AI 人格')),
            for (final persona in personas)
              ListTile(
                leading: const Icon(Icons.face_retouching_natural),
                title: Text(persona.name),
                subtitle: Text(persona.description),
                trailing: persona.id == selectedId
                    ? const Icon(Icons.check)
                    : null,
                onTap: () async {
                  await ref.read(personaServiceProvider).select(persona.id);
                  ref.invalidate(personaSelectionProvider);
                  if (sheetContext.mounted) Navigator.pop(sheetContext);
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _coming(
    BuildContext context,
    IconData icon,
    String title,
    String subtitle,
  ) {
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

// PersonaService 测试：默认人格、选择持久化、三份模板资产与护栏。
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_test/flutter_test.dart';
import 'package:poetry_mate/core/llm/persona.dart';
import 'package:poetry_mate/core/llm/prefs_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late InMemoryPrefsStore prefs;
  late PersonaService service;

  setUp(() {
    prefs = InMemoryPrefsStore();
    service = PersonaService(assets: rootBundle, prefs: prefs);
  });

  test('未选择时默认知音', () async {
    expect(await service.selectedId(), defaultPersonaId);
    expect(personaById('not-a-persona').id, defaultPersonaId);
  });

  test('选择人格后持久化，并只接受已选模板', () async {
    await service.select('xiansheng');
    expect(await service.selectedId(), 'xiansheng');

    await service.select('cike');
    expect(await service.selectedId(), 'cike');
  });

  test('三份模板均可加载并包含幻觉护栏', () async {
    for (final persona in personas) {
      final prompt = await service.loadPrompt(persona.id);
      expect(prompt, isNotEmpty, reason: '${persona.id} 资产为空');
      expect(prompt, contains('只基于给出的诗文本做艺术分析'),
          reason: '${persona.id} 缺少文本边界护栏');
      expect(prompt, contains('无把握'), reason: '${persona.id} 缺少不确定性护栏');
    }
  });

  test('system prompt 包含人格模板与当前诗事实', () async {
    final prompt = await service.buildSystemPrompt(
      'zhiyin',
      poemBody: '床前明月光，疑是地上霜。',
      metaLine: '李白 · 唐',
    );

    expect(prompt, contains('你是「知音」'));
    expect(prompt, contains('李白 · 唐'));
    expect(prompt, contains('床前明月光，疑是地上霜。'));
  });
}

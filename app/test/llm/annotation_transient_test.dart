import 'package:drift/native.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_test/flutter_test.dart';
import 'package:poetry_mate/core/db/app_database.dart';
import 'package:poetry_mate/core/llm/annotation_service.dart';
import 'package:poetry_mate/core/llm/llm_client.dart';
import 'package:poetry_mate/core/llm/llm_config.dart';
import 'package:poetry_mate/core/llm/persona.dart';
import 'package:poetry_mate/core/llm/secure_key_store.dart';
import 'package:poetry_mate/data/repositories/notebook_repository.dart';
import 'package:poetry_mate/domain/entities/poem.dart';

import '../fakes/scripted_transport.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late ScriptedTransport transport;
  late AnnotationService service;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    transport = ScriptedTransport();
    final prefs = InMemoryPrefsStore()
      ..values['llm_base_url'] = 'https://api.test.com/v1'
      ..values['llm_model'] = 'test-model';
    service = AnnotationService(
      notebookRepository: DriftNotebookRepository(db),
      llmClient: LlmClient(
        configStore: LlmConfigStoreImpl(
          secureKeyStore: const _StaticSecure('sk'),
          prefs: prefs,
        ),
        transport: transport,
      ),
      personaService: PersonaService(
        assets: rootBundle,
        prefs: InMemoryPrefsStore(),
      ),
    );
  });

  tearDown(() => db.close());

  final poem = const Poem(
    id: 'transient-poem',
    author: '作者不详',
    title: '临时作品',
    dynasty: '近现代',
    type: 'modern_poem',
    paragraphs: ['月光落在窗前。'],
    preface: null,
    rhythmic: null,
    popularity: null,
    rawText: ['月光落在窗前。'],
    tags: null,
    sourceCollection: 'ai_extended',
  );

  test('临时 L1 只写入会话缓存，不写注本', () async {
    transport.sseQueue.add(
      _sse('''
      {"translation":"月光照到窗前。","notes":[]}
    '''),
    );
    final context = AnnotationContext.transient();

    final first = await service.getOrCreateLineNote(poem, 0, context: context);
    final second = await service.getOrCreateLineNote(poem, 0, context: context);

    expect(first.translation, second.translation);
    expect(transport.callCount, 1);
    expect(await DriftNotebookRepository(db).listAll(), isEmpty);
  });

  test('临时追问完成后不创建 chat_turn', () async {
    transport.sseQueue.add(_sse('回答在这里'));
    final context = AnnotationContext.transient();

    final deltas = await service
        .streamQuestion(poem, '这句写了什么？', context: context)
        .toList();

    expect(deltas.map((delta) => delta.text).join(), '回答在这里');
    expect(await DriftNotebookRepository(db).listAll(), isEmpty);
  });
}

String _sse(String content) =>
    'data: {"choices":[{"delta":{"content":${_quote(content)}}}]}\n'
    'data: [DONE]\n';

String _quote(String value) =>
    '"${value.replaceAll('"', '\\"').replaceAll('\n', '\\n')}"';

class _StaticSecure implements SecureKeyStore {
  const _StaticSecure(this.value);

  final String value;

  @override
  Future<String?> read(String key) async => value;

  @override
  Future<void> write(String key, String value) async {}

  @override
  Future<void> delete(String key) async {}
}

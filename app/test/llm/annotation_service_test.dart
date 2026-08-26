// AnnotationService 测试(任务 3.2/3.3 引擎层):
// 缓存命中 / userEdited 保护 / 强制重生成 / 围栏剥离 / 重试 / 失败不落库。
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:poetry_mate/core/db/app_database.dart';
import 'package:poetry_mate/core/llm/annotation_service.dart';
import 'package:poetry_mate/core/llm/llm_client.dart';
import 'package:poetry_mate/core/llm/llm_config.dart';
import 'package:poetry_mate/core/llm/llm_exception.dart';
import 'package:poetry_mate/core/llm/persona.dart';
import 'package:poetry_mate/core/llm/secure_key_store.dart';
import 'package:poetry_mate/data/repositories/notebook_repository.dart';
import 'package:poetry_mate/domain/entities/notebook_entry.dart';
import '../data/fixtures.dart';
import '../fakes/scripted_transport.dart';

const lineNoteJson =
    '{"translation":"月光洒在床前","notes":[{"term":"疑","explain":"好像"}]}';
const essayJson = '{"summary":"游子思乡",'
    '"craft":[{"point":"疑字","detail":"以幻写真"}],'
    '"mood":"静夜清愁",'
    '"background":{"text":"相传作于出蜀途中","uncertain":true}}';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late ScriptedTransport transport;
  late DriftNotebookRepository notebookRepo;
  late AnnotationService service;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    transport = ScriptedTransport();
    notebookRepo = DriftNotebookRepository(db);
    final personaService = PersonaService(
      assets: rootBundle,
      prefs: InMemoryPrefsStore(),
    );
    final prefs = InMemoryPrefsStore();
    prefs.values['llm_base_url'] = 'https://api.test.com/v1';
    prefs.values['llm_model'] = 'test-model';
    final configStore = LlmConfigStoreImpl(
      secureKeyStore: const _StaticSecure('sk'),
      prefs: prefs,
    );
    service = AnnotationService(
      notebookRepository: notebookRepo,
      llmClient: LlmClient(configStore: configStore, transport: transport),
      personaService: personaService,
    );
  });
  tearDown(() => db.close());

  group('L1 点句即释', () {
    test('未缓存: 请求 LLM → 解析 → 写入注本', () async {
      transport.jsonResult = {
        'choices': [
          {'message': {'content': lineNoteJson}}
        ],
      };
      final poem = testPoem(paragraphs: ['床前看月光，', '疑是地上霜。']);

      final note = await service.getOrCreateLineNote(poem, 1);

      expect(note.translation, '月光洒在床前');
      expect(note.notes.first.term, '疑');

      // 已写入注本(按目标可命中)
      final cached = await notebookRepo.byTarget(
        poemId: poem.id,
        kind: NotebookKind.lineNote,
        target: '1',
      );
      expect(cached, isNotNull);
    });

    test('请求携带全文上下文与 json_object 模式', () async {
      final poem = testPoem(paragraphs: ['床前看月光，', '疑是地上霜。']);
      transport.jsonResult = {
        'choices': [
          {'message': {'content': lineNoteJson}}
        ],
      };

      await service.getOrCreateLineNote(poem, 0);

      final body = transport.lastBody;
      expect(body['response_format']['type'], 'json_object');
      final messages = body['messages'] as List;
      final userText =
          (messages.last as Map)['content'] as String;
      // 全文与目标行号都在提示中
      expect(userText.contains('床前看月光'), isTrue);
      expect(userText.contains('第 1 行'), isTrue);
    });

    test('缓存命中: 不再发起网络调用', () async {
      final poem = testPoem(paragraphs: ['床前看月光。']);
      transport.jsonResult = {
        'choices': [
          {'message': {'content': lineNoteJson}}
        ],
      };
      await service.getOrCreateLineNote(poem, 0);
      expect(transport.callCount, 1);

      await service.getOrCreateLineNote(poem, 0);
      expect(transport.callCount, 1); // 缓存命中
    });

    test('user_edited 条目受保护(force=false 不覆盖)', () async {
      final poem = testPoem(paragraphs: ['床前看月光。']);
      transport.jsonResult = {
        'choices': [
          {'message': {'content': '{"translation":"AI 版本","notes":[]}'}}
        ],
      };
      await service.getOrCreateLineNote(poem, 0);

      // 用户编辑
      await notebookRepo.updateUserContent(
        id: notebookEntryId(
            poemId: poem.id, kind: NotebookKind.lineNote, target: '0'),
        content: {'translation': '我的理解'},
        updatedAtMs: DateTime.now().millisecondsSinceEpoch,
      );

      final result = await service.getOrCreateLineNote(poem, 0);
      expect(result.translation, '我的理解'); // 未被 AI 覆盖
      expect(transport.callCount, 1); // 没有新的网络调用
    });

    test('force=true 覆盖重生成', () async {
      final poem = testPoem(paragraphs: ['床前看月光。']);
      transport.jsonResult = {
        'choices': [
          {'message': {'content': lineNoteJson}}
        ],
      };
      await service.getOrCreateLineNote(poem, 0);

      transport.jsonResult = {
        'choices': [
          {'message': {'content': '{"translation":"重新生成的版本","notes":[]}'}}
        ],
      };
      final result = await service.getOrCreateLineNote(poem, 0,
          forceRegenerate: true);

      expect(result.translation, '重新生成的版本');
    });
  });

  group('L2 整篇赏析', () {
    test('解析五节结构含 uncertain 背景', () async {
      final poem = testPoem(title: '静夜思');
      transport.jsonResult = {
        'choices': [
          {'message': {'content': essayJson}}
        ],
      };

      final essay = await service.getOrCreateEssay(poem);

      expect(essay.summary, '游子思乡');
      expect(essay.craft.single.point, '疑字');
      expect(essay.mood, '静夜清愁');
      expect(essay.background.text, contains('出蜀途中'));
      expect(essay.background.uncertain, isTrue);
    });

    test('markdown 围栏自动剥离', () async {
      final poem = testPoem(title: '围栏诗');
      final fenced = '```json\n$essayJson\n```';
      transport.jsonQueue.add({
        'choices': [
          {'message': {'content': fenced}}
        ],
      });

      final essay = await service.getOrCreateEssay(poem);
      expect(essay.mood, '静夜清愁');
    });

    test('连续两次坏 JSON → badResponse 且注本无残留', () async {
      final poem = testPoem(title: '坏JSON诗');
      transport.jsonQueue.addAll([
        {'choices': [{'message': {'content': '不是json'}}]},
        {'choices': [{'message': {'content': '还不是json'}}]},
      ]);

      await expectLater(
        service.getOrCreateEssay(poem),
        throwsA(isA<LlmException>()
            .having((e) => e.kind, 'kind', LlmErrorKind.badResponse)),
      );

      expect(transport.callCount, 2);
      expect(await notebookRepo.byPoem(poem.id), isEmpty);
    });
  });
}

class _StaticSecure implements SecureKeyStore {
  const _StaticSecure(this.value);

  final String? value;

  @override
  Future<String?> read(String key) async => value;

  @override
  Future<void> write(String key, String value) async {}

  @override
  Future<void> delete(String key) async {}
}

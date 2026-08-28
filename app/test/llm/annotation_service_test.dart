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
import 'package:poetry_mate/domain/entities/annotations.dart';
import 'package:poetry_mate/domain/entities/notebook_entry.dart';
import '../data/fixtures.dart';
import '../fakes/scripted_transport.dart';

const lineNoteJson =
    '{"translation":"月光洒在床前","notes":[{"term":"疑","pinyin":"yí","explain":"好像"}]}';
const essayJson =
    '{"summary":"游子思乡",'
    '"craft":[{"point":"疑字","detail":"以幻写真"}],'
    '"mood":"静夜意境",'
    '"emotion":"思乡清愁",'
    '"background":{"text":"相传作于出蜀途中","uncertain":true},'
    '"word_notes":[{"term":"疑","pinyin":"yí","explain":"好像","line_index":1},'
    '{"term":"不存在","explain":"不应显示","line_index":0}]}';

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
          {
            'message': {'content': lineNoteJson},
          },
        ],
      };
      final poem = testPoem(paragraphs: ['床前看月光，', '疑是地上霜。']);

      final note = await service.getOrCreateLineNote(poem, 1);

      expect(note.translation, '月光洒在床前');
      expect(note.notes.first.term, '疑');
      expect(note.notes.first.pinyin, 'yí');

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
          {
            'message': {'content': lineNoteJson},
          },
        ],
      };

      await service.getOrCreateLineNote(poem, 0);

      final body = transport.lastBody;
      expect(body['response_format']['type'], 'json_object');
      final messages = body['messages'] as List;
      final userText = (messages.last as Map)['content'] as String;
      // 全文与目标行号都在提示中
      expect(userText.contains('床前看月光'), isTrue);
      expect(userText.contains('第 1 行'), isTrue);
    });

    test('JSON mode 不被兼容服务支持时，第二次改用普通请求', () async {
      final poem = testPoem(paragraphs: ['床前看月光。']);
      transport.jsonStatusQueue.add(400);
      transport.jsonQueue.add({
        'choices': [
          {
            'message': {'content': lineNoteJson},
          },
        ],
      });

      final note = await service.getOrCreateLineNote(poem, 0);

      expect(note.translation, '月光洒在床前');
      expect(transport.callCount, 2);
      expect(transport.lastBody.containsKey('response_format'), isFalse);
    });

    test('缓存命中: 不再发起网络调用', () async {
      final poem = testPoem(paragraphs: ['床前看月光。']);
      transport.jsonResult = {
        'choices': [
          {
            'message': {'content': lineNoteJson},
          },
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
          {
            'message': {'content': '{"translation":"AI 版本","notes":[]}'},
          },
        ],
      };
      await service.getOrCreateLineNote(poem, 0);

      // 用户编辑
      await notebookRepo.updateUserContent(
        id: notebookEntryId(
          poemId: poem.id,
          kind: NotebookKind.lineNote,
          target: '0',
        ),
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
          {
            'message': {'content': lineNoteJson},
          },
        ],
      };
      await service.getOrCreateLineNote(poem, 0);

      transport.jsonResult = {
        'choices': [
          {
            'message': {'content': '{"translation":"重新生成的版本","notes":[]}'},
          },
        ],
      };
      final result = await service.getOrCreateLineNote(
        poem,
        0,
        forceRegenerate: true,
      );

      expect(result.translation, '重新生成的版本');
    });
  });

  group('用户选词解释', () {
    test('携带选词上下文并写入独立 word_note', () async {
      final poem = testPoem(paragraphs: ['孤灯不明思欲绝。']);
      transport.jsonResult = {
        'choices': [
          {
            'message': {
              'content':
                  '{"term":"孤","pinyin":"gū",'
                  '"explain":"独自一盏，写出寂寥之感。","uncertain":true}',
            },
          },
        ],
      };
      const position = SelectedWordPosition(
        lineIndex: 0,
        start: 0,
        end: 1,
        term: '孤',
      );

      final note = await service.getOrCreateSelectedWordNote(poem, position);

      expect(note.term, '孤');
      expect(note.pinyin, 'gū');
      expect(note.source, WordNoteSource.selected);
      expect(note.uncertain, isTrue);
      expect(transport.lastBody['response_format']['type'], 'json_object');
      final userPrompt =
          ((transport.lastBody['messages'] as List).last as Map)['content']
              as String;
      expect(userPrompt, contains('孤灯不明思欲绝'));
      expect(userPrompt, contains('【用户选词】孤'));
      final entry = await notebookRepo.byTarget(
        poemId: poem.id,
        kind: NotebookKind.wordNote,
        target: position.target,
      );
      expect(entry?.content['source'], WordNoteSource.selected);
      expect(entry?.content['pinyin'], 'gū');
      expect(entry?.content['start'], 0);
    });

    test('再次解释同一位置命中缓存，不重复请求', () async {
      final poem = testPoem(paragraphs: ['孤灯不明思欲绝。']);
      transport.jsonResult = {
        'choices': [
          {
            'message': {'content': '{"term":"孤","explain":"独自一盏"}'},
          },
        ],
      };
      const position = SelectedWordPosition(
        lineIndex: 0,
        start: 0,
        end: 1,
        term: '孤',
      );
      await service.getOrCreateSelectedWordNote(poem, position);
      await service.getOrCreateSelectedWordNote(poem, position);

      expect(transport.callCount, 1);
    });

    test('模型返回其他词语时不写入注本', () async {
      final poem = testPoem(paragraphs: ['孤灯不明思欲绝。']);
      transport.jsonResult = {
        'choices': [
          {
            'message': {'content': '{"term":"明","explain":"明亮"}'},
          },
        ],
      };
      const position = SelectedWordPosition(
        lineIndex: 0,
        start: 0,
        end: 1,
        term: '孤',
      );

      await expectLater(
        service.getOrCreateSelectedWordNote(poem, position),
        throwsA(isA<SelectedWordValidationException>()),
      );
      expect(await notebookRepo.byPoem(poem.id), isEmpty);
    });

    test('选区与诗文不一致时不请求模型', () async {
      final poem = testPoem(paragraphs: ['孤灯不明思欲绝。']);
      const position = SelectedWordPosition(
        lineIndex: 0,
        start: 2,
        end: 3,
        term: '孤',
      );

      await expectLater(
        service.getOrCreateSelectedWordNote(poem, position),
        throwsA(isA<SelectedWordValidationException>()),
      );
      expect(transport.callCount, 0);
    });

    test('没有 API Key 时展示为 noKey 且不写入', () async {
      final poem = testPoem(paragraphs: ['孤灯不明思欲绝。']);
      final emptyPrefs = InMemoryPrefsStore();
      final noKeyService = AnnotationService(
        notebookRepository: notebookRepo,
        llmClient: LlmClient(
          configStore: LlmConfigStoreImpl(
            secureKeyStore: const _StaticSecure(null),
            prefs: emptyPrefs,
          ),
          transport: transport,
        ),
        personaService: PersonaService(assets: rootBundle, prefs: emptyPrefs),
      );
      const position = SelectedWordPosition(
        lineIndex: 0,
        start: 0,
        end: 1,
        term: '孤',
      );

      await expectLater(
        noKeyService.getOrCreateSelectedWordNote(poem, position),
        throwsA(
          isA<LlmException>().having(
            (error) => error.kind,
            'kind',
            LlmErrorKind.noKey,
          ),
        ),
      );
      expect(transport.callCount, 0);
      expect(await notebookRepo.byPoem(poem.id), isEmpty);
    });

    test('连续两次格式错误时不写入半成品', () async {
      final poem = testPoem(paragraphs: ['孤灯不明思欲绝。']);
      transport.jsonQueue.addAll([
        {
          'choices': [
            {
              'message': {'content': '不是 JSON'},
            },
          ],
        },
        {
          'choices': [
            {
              'message': {'content': '仍然不是 JSON'},
            },
          ],
        },
      ]);
      const position = SelectedWordPosition(
        lineIndex: 0,
        start: 0,
        end: 1,
        term: '孤',
      );

      await expectLater(
        service.getOrCreateSelectedWordNote(poem, position),
        throwsA(isA<AnnotationParseException>()),
      );
      expect(transport.callCount, 2);
      expect(await notebookRepo.byPoem(poem.id), isEmpty);
    });
  });

  group('L2 整篇赏析', () {
    test('旧赏析缓存缺少 word_notes 时仍可解析', () {
      final content = EssayContent.fromJson({
        'summary': '旧缓存',
        'craft': <dynamic>[],
        'mood': '旧意境',
        'background': {'text': '', 'uncertain': true},
        'word_notes': [
          {'term': '疑', 'explain': '好像'},
        ],
      });

      expect(content.summary, '旧缓存');
      expect(content.wordNotes.single.pinyin, isEmpty);
    });

    test('解析五节结构含 uncertain 背景', () async {
      final poem = testPoem(title: '静夜思');
      transport.jsonResult = {
        'choices': [
          {
            'message': {'content': essayJson},
          },
        ],
      };

      final essay = await service.getOrCreateEssay(poem);

      expect(essay.summary, '游子思乡');
      expect(essay.craft.single.point, '疑字');
      expect(essay.mood, '静夜意境');
      expect(essay.background.text, contains('出蜀途中'));
      expect(essay.background.uncertain, isTrue);
      expect(essay.emotion, '思乡清愁');
      expect(essay.wordNotes, hasLength(1));
      expect(essay.wordNotes.single.term, '疑');
      expect(essay.wordNotes.single.pinyin, 'yí');
      expect(essay.wordNotes.single.lineIndex, 1);
    });

    test('markdown 围栏自动剥离', () async {
      final poem = testPoem(title: '围栏诗');
      final fenced = '```json\n$essayJson\n```';
      transport.jsonQueue.add({
        'choices': [
          {
            'message': {'content': fenced},
          },
        ],
      });

      final essay = await service.getOrCreateEssay(poem);
      expect(essay.mood, '静夜意境');
      expect(essay.emotion, '思乡清愁');
    });

    test('连续两次坏 JSON → badResponse 且注本无残留', () async {
      final poem = testPoem(title: '坏JSON诗');
      transport.jsonQueue.addAll([
        {
          'choices': [
            {
              'message': {'content': '不是json'},
            },
          ],
        },
        {
          'choices': [
            {
              'message': {'content': '还不是json'},
            },
          ],
        },
      ]);

      await expectLater(
        service.getOrCreateEssay(poem),
        throwsA(
          isA<AnnotationParseException>()
              .having((e) => e.kind, 'kind', LlmErrorKind.badResponse)
              .having((e) => e.rawText, 'rawText', '还不是json'),
        ),
      );

      expect(transport.callCount, 2);
      expect(await notebookRepo.byPoem(poem.id), isEmpty);
    });
  });

  group('L3 追问对话', () {
    test('SSE 按增量返回并携带诗全文上下文，完成后写入 chat_turn', () async {
      final poem = testPoem(paragraphs: ['床前明月光，']);
      transport.sseText =
          'data: {"choices":[{"delta":{"content":"先看"} }]}\n'
          'data: {"choices":[{"delta":{"content":"这一句"} }]}\n'
          'data: [DONE]\n';

      final deltas = await service.streamQuestion(poem, '这个字有什么意味？').toList();

      expect(deltas.map((delta) => delta.text), ['先看', '这一句']);
      expect(deltas.every((delta) => !delta.replace), isTrue);
      final messages = transport.lastBody['messages'] as List;
      final userPrompt = (messages.last as Map)['content'] as String;
      expect(userPrompt, contains(poem.bodyText));
      expect(userPrompt, contains('这个字有什么意味？'));
      final entries = await notebookRepo.byPoem(poem.id);
      expect(entries.single.kind, NotebookKind.chatTurn);
      expect(entries.single.content['answer'], '先看这一句');
    });

    test('SSE 失败降级一次性回答，并用 replace 增量替换标记', () async {
      final poem = testPoem(paragraphs: ['床前明月光，']);
      transport.streamStatusError = 503;
      transport.jsonResult = {
        'choices': [
          {
            'message': {'content': '这是一次性回答'},
          },
        ],
      };

      final deltas = await service.streamQuestion(poem, '请换一种说法').toList();

      expect(deltas.single.text, '这是一次性回答');
      expect(deltas.single.replace, isTrue);
      expect(transport.callCount, 2); // stream + complete
      final entries = await notebookRepo.byPoem(poem.id);
      expect(entries.single.content['answer'], '这是一次性回答');
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

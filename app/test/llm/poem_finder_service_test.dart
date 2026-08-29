import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_test/flutter_test.dart';
import 'package:poetry_mate/core/llm/llm_client.dart';
import 'package:poetry_mate/core/llm/llm_config.dart';
import 'package:poetry_mate/core/llm/persona.dart';
import 'package:poetry_mate/core/llm/poem_finder_service.dart';
import 'package:poetry_mate/core/llm/secure_key_store.dart';

import '../fakes/scripted_transport.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ScriptedTransport transport;
  late PoemFinderService service;

  setUp(() {
    transport = ScriptedTransport();
    final prefs = InMemoryPrefsStore()
      ..values['llm_base_url'] = 'https://api.test.com/v1'
      ..values['llm_model'] = 'test-model';
    service = PoemFinderService(
      llmClient: LlmClient(
        configStore: LlmConfigStoreImpl(
          secureKeyStore: const _StaticSecure('sk-test'),
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

  test('流式寻诗返回结构化作品且不写入注本', () async {
    transport.sseQueue.add(
      _sse(
        jsonEncode({
          'status': 'found',
          'reply': '我想到一首。',
          'title': '静夜思',
          'author': '李白',
          'period': '唐',
          'genre': 'shi',
          'paragraphs': ['床前明月光，', '疑是地上霜。'],
          'source': '《全唐诗》',
          'source_confidence': 'known',
        }),
      ),
    );

    final session = PoemFinderSession();
    final events = await service.streamTurn(session, '想找一首写月夜思乡的诗').toList();
    final done = events.whereType<PoemFinderDone>().single;

    expect(done.response.isFound, isTrue);
    expect(done.response.poem?.title, '静夜思');
    expect(events.whereType<PoemFinderPartial>().single.text, '我想到一首。');
    expect(transport.lastBody['response_format']['type'], 'json_object');
    expect(session.messages, hasLength(2));
  });

  test('多轮会话会携带此前成功问答', () async {
    final response = jsonEncode({
      'status': 'not_found',
      'reply': '我还需要更多线索。',
      'message': 'not enough',
    });
    transport.sseQueue.add(_sse(response));
    transport.sseQueue.add(_sse(response));
    final session = PoemFinderSession();

    await service.streamTurn(session, '想找春天的诗').toList();
    await service.streamTurn(session, '最好是近现代作品').toList();

    final messages = transport.lastBody['messages'] as List;
    expect(
      messages.whereType<Map>().any((item) {
        final content = item['content'];
        return content is String && content.contains('春天的诗');
      }),
      isTrue,
    );
  });

  test('首轮坏 JSON 会重试并取消第二轮 json mode', () async {
    transport.sseQueue.add(_sse('这不是 JSON'));
    transport.sseQueue.add(
      _sse(jsonEncode({'status': 'not_found', 'reply': '没有找到足够可靠的作品。'})),
    );

    final events = await service
        .streamTurn(PoemFinderSession(), '随便找一首')
        .toList();

    expect(events.whereType<PoemFinderReset>(), hasLength(1));
    expect(
      events.whereType<PoemFinderDone>().single.response.isNotFound,
      isTrue,
    );
    expect(transport.callCount, 2);
    expect(transport.lastBody.containsKey('response_format'), isFalse);
  });

  test('原创标记不会被当作寻诗结果', () async {
    transport.sseQueue.add(
      _sse(
        jsonEncode({
          'status': 'found',
          'is_original': true,
          'title': '新作',
          'genre': 'shi',
          'paragraphs': ['这是新写的文本。'],
        }),
      ),
    );

    final done =
        (await service.streamTurn(PoemFinderSession(), '请找一首诗').toList())
            .whereType<PoemFinderDone>()
            .single;
    expect(done.response.isRejected, isTrue);
    expect(done.response.poem, isNull);
  });
}

String _sse(String content) {
  final frame = jsonEncode({
    'choices': [
      {
        'delta': {'content': content},
      },
    ],
  });
  return 'data: $frame\n\ndata: [DONE]\n';
}

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

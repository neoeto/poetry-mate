/// OpenAI 兼容客户端测试 —— 脚本化传输替身,无真实网络。

library;

import 'package:flutter_test/flutter_test.dart';
import 'package:poetry_mate/core/llm/llm_client.dart';
import 'package:poetry_mate/core/llm/llm_config.dart';
import 'package:poetry_mate/core/llm/llm_exception.dart';
import 'package:poetry_mate/core/llm/llm_transport.dart';
import 'package:poetry_mate/core/llm/secure_key_store.dart';
import '../fakes/scripted_transport.dart';


LlmClient _client(ScriptedTransport transport) {
  final prefs = InMemoryPrefsStore();
  prefs.values['llm_base_url'] = 'https://api.example.com/v1';
  prefs.values['llm_model'] = 'test-model';
  return LlmClient(
    configStore: LlmConfigStoreImpl(
      secureKeyStore: const _StaticSecure('sk-live'),
      prefs: prefs,
    ),
    transport: transport,
  );
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

void main() {
  test('complete: 组装端点/鉴权头/模型与消息', () async {
    final transport = ScriptedTransport(
      jsonResult: {
        'choices': [
          {'message': {'content': '你好，诗友。'}}
        ],
      },
    );

    final out = await _client(transport).complete([
      const LlmMessage('system', '你是图书馆员'),
      const LlmMessage('user', '解释这句诗'),
    ]);

    expect(out, '你好，诗友。');
    expect(transport.lastUrl.toString(),
        'https://api.example.com/v1/chat/completions');
    expect(transport.lastHeaders['authorization'], 'Bearer sk-live');
    expect(transport.lastBody['model'], 'test-model');
    expect((transport.lastBody['messages'] as List).length, 2);
  });

  test('complete: jsonMode 附带 response_format', () async {
    final transport = ScriptedTransport(
      jsonResult: {
        'choices': [
          {'message': {'content': '{}'}}
        ],
      },
    );
    await _client(transport).complete(
      [const LlmMessage('user', 'x')],
      jsonMode: true,
    );
    expect(
        (transport.lastBody['response_format'] as Map)['type'], 'json_object');
  });

  test('未配置三元组 → noKey', () async {

    final client = LlmClient(
      configStore: LlmConfigStoreImpl(
        secureKeyStore: const _StaticSecure(null),
        prefs: InMemoryPrefsStore(),
      ),
      transport: ScriptedTransport(jsonResult: {}),
    );

    await expectLater(
      client.complete([const LlmMessage('user', 'hi')]),
      throwsA(isA<LlmException>()
          .having((e) => e.kind, 'kind', LlmErrorKind.noKey)),
    );
  });

  test('401 → auth;429 → rateLimit;500 → server', () {
    expect(
      statusToError(401, 'bad key').kind,
      LlmErrorKind.auth,
    );
    expect(
      statusToError(429, 'slow down').kind,
      LlmErrorKind.rateLimit,
    );
    expect(
      statusToError(502, 'upstream').kind,
      LlmErrorKind.server,
    );
  });

  test('choices 为空 → badResponse', () async {
    final transport = ScriptedTransport(jsonResult: {
      'choices': [],
    });
    await expectLater(
      _client(transport).complete([const LlmMessage('user', 'x')]),
      throwsA(isA<LlmException>()
          .having((e) => e.kind, 'kind', LlmErrorKind.badResponse)),
    );
  });

  test('SSE 解析: 增量按序产出,[DONE] 终止,噪声行跳过', () async {
    final transport = ScriptedTransport(
      sseText: [
        ': heartbeat comment',
        'data: {"choices":[{"delta":{"content":"床前"}}]}',
        '',
        'data: {"choices":[{"delta":{"content":"明月光"}}]}',
        'data: [DONE]',
        'data: {"choices":[{"delta":{"content":"不应出现"}}]}',
      ].join('\n'),
    );

    final deltas = await _client(transport)
        .streamChat([const LlmMessage('user', '继续')])
        .toList();

    expect(deltas.join(), '床前明月光');
  });
}

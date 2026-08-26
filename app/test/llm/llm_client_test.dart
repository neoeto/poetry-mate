/// OpenAI 兼容客户端测试 —— 脚本化传输替身,无真实网络。

library;
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:poetry_mate/core/llm/llm_client.dart';
import 'package:poetry_mate/core/llm/llm_config.dart';
import 'package:poetry_mate/core/llm/llm_exception.dart';
import 'package:poetry_mate/core/llm/llm_transport.dart';
import 'package:poetry_mate/core/llm/secure_key_store.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

class ScriptedTransport implements LlmTransport {
  ScriptedTransport({this.jsonResult, this.statusError, this.sseText});

  /// postJson 返回的响应体
  Map<String, dynamic>? jsonResult;

  /// 非 null 时 postJson/postStream 抛此状态错误
  int? statusError;
  String errorBody = '{"error":{"message":"boom"}}';

  /// postStream 吐出的 SSE 文本(按行)
  String? sseText;

  Uri? lastUrl;
  Map<String, String> lastHeaders = {};
  Map<String, dynamic> lastBody = {};

  @override
  Future<Map<String, dynamic>> postJson(
    Uri url,
    Map<String, String> headers,
    Map<String, dynamic> body,
  ) async {
    lastUrl = url;
    lastHeaders = headers;
    lastBody = body;
    final status = statusError;
    if (status != null) {
      throw statusToError(status, errorBody);
    }
    return jsonResult!;
  }

  @override
  Stream<List<int>> postStream(
    Uri url,
    Map<String, String> headers,
    Map<String, dynamic> body,
  ) async* {
    lastUrl = url;
    lastHeaders = headers;
    lastBody = body;
    final status = statusError;
    if (status != null) {
      throw statusToError(status, errorBody);
    }
    yield Uint8List.fromList(utf8.encode(sseText ?? ''));
  }
}

LlmClient _client(ScriptedTransport transport) {
  SharedPreferencesAsyncPlatform.instance =
      InMemorySharedPreferencesAsync.withData({
    'llm_base_url': 'https://api.example.com/v1',
    'llm_model': 'test-model',
  });
  return LlmClient(
    configStore: LlmConfigStoreImpl(
      secureKeyStore: _StaticSecure('sk-live'),
      prefs: SharedPreferencesAsync(),
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
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.withData({});
    final client = LlmClient(
      configStore: LlmConfigStoreImpl(
        secureKeyStore: const _StaticSecure(null),
        prefs: SharedPreferencesAsync(),
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

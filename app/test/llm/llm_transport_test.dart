// 真实 dart:io transport 回归：请求体必须支持中文 UTF-8。
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:poetry_mate/core/llm/llm_client.dart';
import 'package:poetry_mate/core/llm/llm_config.dart';
import 'package:poetry_mate/core/llm/llm_transport.dart';
import 'package:poetry_mate/core/llm/secure_key_store.dart';

void main() {
  test('POST JSON 使用 UTF-8 编码传输中文内容', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    String? receivedBody;
    String? receivedContentType;
    server.listen((request) async {
      receivedContentType = request.headers.value(HttpHeaders.contentTypeHeader);
      final bytes = <int>[];
      await for (final chunk in request) {
        bytes.addAll(chunk);
      }
      receivedBody = utf8.decode(bytes);
      request.response.headers.contentType = ContentType.json;
      request.response.write(jsonEncode({
        'choices': [
          {'message': {'content': '连通'}}
        ],
      }));
      await request.response.close();
    });

    final prefs = InMemoryPrefsStore()
      ..values['llm_base_url'] = 'http://127.0.0.1:${server.port}/v1'
      ..values['llm_model'] = 'test-model';
    final transport = HttpLlmTransport(
      connectTimeout: const Duration(seconds: 3),
      receiveTimeout: const Duration(seconds: 3),
    );

    try {
      final client = LlmClient(
        configStore: LlmConfigStoreImpl(
          secureKeyStore: const _StaticSecure('sk-test'),
          prefs: prefs,
        ),
        transport: transport,
      );
      final reply = await client.complete([
        const LlmMessage('user', '请只回复两个字：连通'),
      ]);

      expect(reply, '连通');
      expect(receivedBody, contains('请只回复两个字'));
      expect(receivedContentType, contains('charset=utf-8'));
    } finally {
      transport.close();
      await server.close(force: true);
    }
  });
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

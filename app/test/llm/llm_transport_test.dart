// 真实 dart:io transport 回归：请求体必须支持中文 UTF-8；流式超时保护。
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:poetry_mate/core/llm/llm_client.dart';
import 'package:poetry_mate/core/llm/llm_config.dart';
import 'package:poetry_mate/core/llm/llm_exception.dart';
import 'package:poetry_mate/core/llm/llm_transport.dart';
import 'package:poetry_mate/core/llm/secure_key_store.dart';

void main() {
  test('POST JSON 使用 UTF-8 编码传输中文内容', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    String? receivedBody;
    String? receivedContentType;
    server.listen((request) async {
      receivedContentType = request.headers.value(
        HttpHeaders.contentTypeHeader,
      );
      final bytes = <int>[];
      await for (final chunk in request) {
        bytes.addAll(chunk);
      }
      receivedBody = utf8.decode(bytes);
      request.response.headers.contentType = ContentType.json;
      request.response.write(
        jsonEncode({
          'choices': [
            {
              'message': {'content': '连通'},
            },
          ],
        }),
      );
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

  test('流式: 正常分帧不受超时影响', () async {
    final server = await _streamingServer((request) async {
      request.response.write('data: 1\n\n');
      await request.response.flush();
      await Future<void>.delayed(const Duration(milliseconds: 30));
      request.response.write('data: 2\n\n');
      await request.response.flush();
      await request.response.close();
    });
    final transport = _shortTimeoutTransport(
      idle: const Duration(milliseconds: 800),
    );

    try {
      final chunks = await transport
          .postStream(
            Uri.parse('http://127.0.0.1:${server.port}/v1/chat/completions'),
            {},
            {},
          )
          .toList();
      expect(chunks, hasLength(2));
    } finally {
      transport.close();
      await server.close(force: true);
    }
  });

  test('流式: 首字节停滞超时 → 网络错误', () async {
    final server = await _streamingServer((request) async {
      // 只发响应头,永不写 body
      await request.response.flush();
      await Future<void>.delayed(const Duration(seconds: 5));
      await request.response.close();
    });
    final transport = _shortTimeoutTransport(
      receive: const Duration(milliseconds: 200),
      idle: const Duration(seconds: 5),
    );

    try {
      await expectLater(
        transport
            .postStream(
              Uri.parse('http://127.0.0.1:${server.port}/v1/chat/completions'),
              {},
              {},
            )
            .toList(),
        throwsA(
          isA<LlmException>()
              .having((e) => e.kind, 'kind', LlmErrorKind.network)
              .having((e) => e.message, 'message', contains('超时')),
        ),
      );
    } finally {
      transport.close();
      await server.close(force: true);
    }
  });

  test('流式: 帧间停滞超时 → 网络错误', () async {
    final server = await _streamingServer((request) async {
      request.response.write('data: 1\n\n');
      await request.response.flush();
      await Future<void>.delayed(const Duration(seconds: 5));
      await request.response.close();
    });
    final transport = _shortTimeoutTransport(
      idle: const Duration(milliseconds: 200),
    );

    try {
      await expectLater(
        transport
            .postStream(
              Uri.parse('http://127.0.0.1:${server.port}/v1/chat/completions'),
              {},
              {},
            )
            .toList(),
        throwsA(
          isA<LlmException>()
              .having((e) => e.kind, 'kind', LlmErrorKind.network)
              .having((e) => e.message, 'message', contains('超时')),
        ),
      );
    } finally {
      transport.close();
      await server.close(force: true);
    }
  });
}

/// 建一个只负责流式响应的 loopback server,[onRequest] 决定吐什么。
Future<HttpServer> _streamingServer(
  Future<void> Function(HttpRequest request) onRequest,
) async {
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  server.listen((request) async {
    await onRequest(request);
  });
  return server;
}

HttpLlmTransport _shortTimeoutTransport({
  Duration receive = const Duration(milliseconds: 800),
  required Duration idle,
}) => HttpLlmTransport(
  connectTimeout: const Duration(seconds: 3),
  receiveTimeout: receive,
  idleTimeout: idle,
);

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

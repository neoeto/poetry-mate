/// LLM 传输抽象 —— 把"发请求收响应"与"业务逻辑"解耦。
///
/// 生产实现 [HttpLlmTransport](dart:io);测试注入脚本化替身,
/// 无需真实网络即可覆盖 成功/401/429/超时/坏JSON 全部分支。
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'llm_exception.dart';

abstract class LlmTransport {
  /// 非流式 POST,返回已解析的响应 JSON(失败抛 LlmException)
  Future<Map<String, dynamic>> postJson(
    Uri url,
    Map<String, String> headers,
    Map<String, dynamic> body,
  );

  /// 流式 POST,返回原始字节流(SSE 由上层解析)
  Stream<List<int>> postStream(
    Uri url,
    Map<String, String> headers,
    Map<String, dynamic> body,
  );
}

class HttpLlmTransport implements LlmTransport {
  HttpLlmTransport({
    this.connectTimeout = const Duration(seconds: 15),
    this.receiveTimeout = const Duration(seconds: 120),
    HttpClient? client,
  })  : _client = client ?? HttpClient(),
        _externalClient = client != null;

  final Duration connectTimeout;
  final Duration receiveTimeout;
  final HttpClient _client;
  final bool _externalClient;

  void close() {
    if (!_externalClient) _client.close(force: true);
  }

  @override
  Future<Map<String, dynamic>> postJson(
    Uri url,
    Map<String, String> headers,
    Map<String, dynamic> body,
  ) async {
    final response = await _send(url, headers, body);
    final String text;
    try {
      text = await response
          .transform(utf8.decoder)
          .join()
          .timeout(receiveTimeout);
    } on TimeoutException {
      throw const LlmException(
        LlmErrorKind.network,
        '响应超时，请检查网络或稍后再试',
      );
    } on LlmException {
      rethrow;
    } on Object catch (error) {
      throw _networkError(error);
    }
    if (response.statusCode >= 400) {
      throw _statusError(response.statusCode, text);
    }
    try {
      final decoded = jsonDecode(text);
      return decoded as Map<String, dynamic>;
    } on FormatException catch (e) {
      throw LlmException(LlmErrorKind.badResponse, '返回格式异常: ${e.message}');
    }
  }

  @override
  Stream<List<int>> postStream(
    Uri url,
    Map<String, String> headers,
    Map<String, dynamic> body,
  ) async* {
    final response = await _send(url, headers, body);
    if (response.statusCode >= 400) {
      final String text;
      try {
        text = await response.transform(utf8.decoder).join();
      } on TimeoutException {
        throw const LlmException(
          LlmErrorKind.network,
          '响应超时，请检查网络或稍后再试',
        );
      } on LlmException {
        rethrow;
      } on Object catch (error) {
        throw _networkError(error);
      }
      throw _statusError(response.statusCode, text);
    }
    try {
      yield* response;
    } on LlmException {
      rethrow;
    } on Object catch (error) {
      throw _networkError(error);
    }
  }

  Future<HttpClientResponse> _send(
    Uri url,
    Map<String, String> headers,
    Map<String, dynamic> body,
  ) async {
    final HttpClientRequest request;
    try {
      request = await _client.postUrl(url).timeout(connectTimeout);
    } on TimeoutException {
      throw const LlmException(LlmErrorKind.network, '连接超时，请检查网络');
    } on LlmException {
      rethrow;
    } on Object catch (error) {
      throw _networkError(error);
    }

    try {
      request.headers.set(
        HttpHeaders.contentTypeHeader,
        'application/json; charset=utf-8',
      );
      // content-type 的 charset 会让 HttpClientRequest.write 使用 UTF-8；
      // 不能再设置 request.encoding（请求创建后该 setter 不可变）。
      for (final entry in headers.entries) {
        request.headers.set(entry.key, entry.value);
      }
      request.write(jsonEncode(body));
      return await request.close().timeout(connectTimeout);
    } on TimeoutException {
      throw const LlmException(LlmErrorKind.network, '连接超时，请检查网络');
    } on LlmException {
      rethrow;
    } on Object catch (error) {
      throw _networkError(error);
    }
  }

  LlmException _networkError(Object error) {
    if (error is TlsException) {
      final detail = error.message.trim();
      return LlmException(
        LlmErrorKind.network,
        detail.isEmpty
            ? 'TLS 握手失败，请确认 Base URL 使用 HTTPS 且证书有效'
            : 'TLS 握手失败：$detail',
      );
    }
    if (error is SocketException && error.message.trim().isNotEmpty) {
      return LlmException(LlmErrorKind.network, '网络不通：${error.message}');
    }
    if (error is HttpException && error.message.trim().isNotEmpty) {
      return LlmException(LlmErrorKind.network, '网络请求失败：${error.message}');
    }
    if (error is ArgumentError) {
      final detail = _safeErrorDetail(error.message);
      return LlmException(
        LlmErrorKind.network,
        detail.isEmpty
            ? '网络请求参数无效，请检查 Base URL'
            : '网络请求参数无效：$detail',
      );
    }
    if (error is FormatException) {
      final detail = _safeErrorDetail(error.message);
      return LlmException(
        LlmErrorKind.network,
        detail.isEmpty ? '请求格式无效，请检查配置' : '请求格式无效：$detail',
      );
    }
    return LlmException(
      LlmErrorKind.network,
      '网络请求失败（${error.runtimeType}），请检查网络连接与 Base URL',
    );
  }

  String _safeErrorDetail(Object? value) {
    var text = value?.toString().trim() ?? '';
    // 错误摘要可能包含 header 值；界面与日志均不得暴露 API Key。
    text = text.replaceAll(
      RegExp(r'Bearer\s+[^ )]+', caseSensitive: false),
      'Bearer ***',
    );
    text = text.replaceAll(
      RegExp(r'\bsk-[A-Za-z0-9._-]+\b'),
      '***',
    );
    return text.length > 180 ? '${text.substring(0, 180)}…' : text;
  }

  LlmException _statusError(int statusCode, String bodySnippet) =>
      statusToError(statusCode, bodySnippet);
}

/// 状态码 → 产品化异常(公开纯函数,便于测试)
LlmException statusToError(int statusCode, String bodySnippet) {
  final excerpt =
      bodySnippet.length > 200 ? '${bodySnippet.substring(0, 200)}…' : bodySnippet;
  switch (statusCode) {
    case 401 || 403:
      return LlmException(LlmErrorKind.auth, '密钥无效（$statusCode）：$excerpt');
    case 429:
      return LlmException(LlmErrorKind.rateLimit, '触发限流（429）：$excerpt');
    default:
      if (statusCode >= 500) {
        return LlmException(LlmErrorKind.server, '服务异常（$statusCode）：$excerpt');
      }
      return LlmException(LlmErrorKind.badResponse, '请求被拒绝（$statusCode）：$excerpt');
  }
}

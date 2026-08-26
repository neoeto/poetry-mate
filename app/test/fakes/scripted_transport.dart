/// 脚本化传输替身 —— 按预设脚本响应,捕获最近一次请求。
/// (client 测试与设置页 widget 测试共用)

library;
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:poetry_mate/core/llm/llm_transport.dart';

class ScriptedTransport implements LlmTransport {
  ScriptedTransport({this.jsonResult, this.statusError, this.sseText});

  /// postJson 返回的响应体
  Map<String, dynamic>? jsonResult;

  /// 非 null 时 postJson/postStream 抛此状态码错误
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

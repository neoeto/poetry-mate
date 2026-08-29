/// 脚本化传输替身 —— 按预设脚本响应,捕获最近一次请求。
/// (client 测试与设置页 widget 测试共用)

library;

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:poetry_mate/core/llm/llm_transport.dart';

class ScriptedTransport implements LlmTransport {
  ScriptedTransport({this.jsonResult, this.statusError, this.sseText});

  int callCount = 0;

  /// 按序消耗的响应队列(非空时优先于 jsonResult)
  final List<Map<String, dynamic>> jsonQueue = [];

  /// postJson 返回的响应体
  Map<String, dynamic>? jsonResult;

  /// 按序让 postJson 抛出状态码错误(用于模拟 JSON mode 不被支持等情况)
  final List<int> jsonStatusQueue = [];

  /// 非 null 时 postJson 抛此状态码错误
  int? statusError;

  /// 非 null 时 postStream 抛此状态码错误(用于测试一次性降级)
  int? streamStatusError;

  /// 按调用顺序让 postStream 抛出的状态码错误。
  final List<int> streamStatusQueue = [];
  String errorBody = '{"error":{"message":"boom"}}';

  /// 按调用顺序提供完整 SSE 文本(每次 postStream 消耗一项)。
  final List<String> sseQueue = [];

  /// postStream 吐出的 SSE 文本(按行)。未显式设置 SSE 时,若有 jsonResult
  /// 会自动把其 message.content 包装成一个完整 SSE 响应,方便旧测试复用。
  String? sseText;

  /// 将一次 SSE 响应拆成多个原始字节块吐出,用于测试跨块/跨帧场景。
  List<String>? sseChunks;

  /// 吐完流式块后抛出的错误,用于模拟中途断流。
  Object? streamTailError;

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
    callCount++;
    final status = jsonStatusQueue.isNotEmpty
        ? jsonStatusQueue.removeAt(0)
        : statusError;
    if (status != null) {
      throw statusToError(status, errorBody);
    }
    if (jsonQueue.isNotEmpty) {
      return jsonQueue.removeAt(0);
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
    callCount++;
    final status = streamStatusQueue.isNotEmpty
        ? streamStatusQueue.removeAt(0)
        : streamStatusError ?? statusError;
    if (status != null) {
      throw statusToError(status, errorBody);
    }

    final scriptedText = sseQueue.isNotEmpty
        ? sseQueue.removeAt(0)
        : sseText ?? _sseFromJsonResult();
    final chunks = sseChunks ?? [scriptedText];
    for (final chunk in chunks) {
      yield Uint8List.fromList(utf8.encode(chunk));
    }
    final error = streamTailError;
    if (error != null) throw error;
  }

  String _sseFromJsonResult() {
    final response = jsonResult;
    if (response == null) return '';
    final choices = response['choices'];
    if (choices is! List || choices.isEmpty || choices.first is! Map) {
      return '';
    }
    final message = (choices.first as Map)['message'];
    final content = message is Map ? message['content'] : null;
    if (content is! String) return '';
    final frame = jsonEncode({
      'choices': [
        {
          'delta': {'content': content},
        },
      ],
    });
    return 'data: $frame\n\ndata: [DONE]\n';
  }
}

/// OpenAI 兼容客户端 —— 业务层(design D2)。
///
/// 两种消费模式:
///   complete()   非流式,可选 json_object 模式(赏析/逐句注)
///   streamChat() SSE 流式(追问对话)
///
/// 契约: 无三元组时抛 noKey;错误统一 LlmException 六类;
/// SSE 解析为独立纯函数 [extractSseContent],可单独测试。
library;

import 'dart:async';
import 'dart:convert';

import 'llm_config.dart';
import 'llm_exception.dart';
import 'llm_transport.dart';

class LlmMessage {
  const LlmMessage(this.role, this.content);

  final String role; // system / user / assistant
  final String content;

  Map<String, dynamic> toJson() => {'role': role, 'content': content};
}

class LlmClient {
  LlmClient({
    required LlmConfigStore configStore,
    required LlmTransport transport,
  })  : _configStore = configStore,
        _transport = transport;

  final LlmConfigStore _configStore;
  final LlmTransport _transport;

  /// 非流式补全。jsonMode=true 时请求供应商返回 JSON 对象。
  Future<String> complete(
    List<LlmMessage> messages, {
    bool jsonMode = false,
    double temperature = 0.7,
    int? maxTokens,
  }) async {
    final config = await _requireConfig();
    final response = await _transport.postJson(_endpoint(config),
        _headers(config), {
      'model': config.model,
      'messages': [for (final m in messages) m.toJson()],
      'temperature': temperature,
      'max_tokens': ?maxTokens,
      if (jsonMode) 'response_format': {'type': 'json_object'},
    });

    try {
      final choices = response['choices'] as List<dynamic>;
      final message = choices.first as Map<String, dynamic>;
      final content = (message['message'] as Map<String, dynamic>)['content']
          as String?;
      if (content == null || content.isEmpty) {
        throw const LlmException(LlmErrorKind.badResponse, '返回内容为空');
      }
      return content;
    } on LlmException {
      rethrow;
    } catch (e) {
      throw LlmException(LlmErrorKind.badResponse, '返回结构异常: $e');
    }
  }

  /// 流式对话: 逐段产出增量文本。
  Stream<String> streamChat(
    List<LlmMessage> messages, {
    double temperature = 0.7,
  }) async* {
    final config = await _requireConfig();
    final byteStream = _transport.postStream(
      _endpoint(config),
      _headers(config),
      {
        'model': config.model,
        'messages': [for (final m in messages) m.toJson()],
        'temperature': temperature,
        'stream': true,
      },
    );
    yield* extractSseContent(byteStream);
  }

  Uri _endpoint(LlmConfig config) {
    var base = config.baseUrl.trim();
    if (base.endsWith('/')) base = base.substring(0, base.length - 1);
    return Uri.parse('$base/chat/completions');
  }

  Map<String, String> _headers(LlmConfig config) => {
        'authorization': 'Bearer ${config.apiKey}',
      };

  Future<LlmConfig> _requireConfig() async {
    final config = await _configStore.read();
    if (config == null) {
      throw const LlmException(
          LlmErrorKind.noKey, '尚未配置 AI 模型，去「我的 → LLM 配置」看看');
    }
    return config;
  }
}

/// 从 SSE 字节流解析增量文本。
///
/// 协议: 以行为单位,`data: <json>` 为一帧,`data: [DONE]` 结束;
/// 每帧取 choices[0].delta.content。无法解析的行静默跳过(容忍心跳行等噪声)。
Stream<String> extractSseContent(Stream<List<int>> byteStream) async* {
  final lines = byteStream
      .transform(const Utf8Decoder(allowMalformed: true))
      .transform(const LineSplitter());
  await for (final line in lines) {
    if (!line.startsWith('data:')) continue;
    final payload = line.substring(5).trim();
    if (payload.isEmpty) continue;
    if (payload == '[DONE]') break;
    try {
      final frame = jsonDecode(payload);
      final choices = frame is Map ? frame['choices'] as List<dynamic>? : null;
      if (choices == null || choices.isEmpty) continue;
      final delta =
          (choices.first as Map<dynamic, dynamic>)['delta'] as Map<dynamic, dynamic>?;
      final content = delta?['content'];
      if (content is String && content.isNotEmpty) yield content;
    } on FormatException {
      continue; // 心跳/注释行
    }
  }
}

/// LLM 错误类型与产品化异常。
///
/// 六类映射(design D2): UI 层只看 kind 与 message,
/// 原始堆栈/供应商报文仅保留摘要进 message。
library;

enum LlmErrorKind {
  noKey, // 未配置三元组
  network, // 网络不通/超时
  auth, // 密钥无效(401/403)
  rateLimit, // 触发限流(429)
  server, // 服务端异常(5xx)
  badResponse, // 返回格式异常(无法解析)
}

class LlmException implements Exception {
  const LlmException(this.kind, this.message);

  final LlmErrorKind kind;
  final String message;

  /// 面向用户的短标题；[message] 保留可行动的具体原因。
  String get title => switch (kind) {
        LlmErrorKind.noKey => '还没有配置 AI',
        LlmErrorKind.network => '网络连接失败',
        LlmErrorKind.auth => '密钥无效',
        LlmErrorKind.rateLimit => '请求太频繁',
        LlmErrorKind.server => '模型服务异常',
        LlmErrorKind.badResponse => '模型返回异常',
      };

  @override
  String toString() => 'LlmException($kind): $message';
}

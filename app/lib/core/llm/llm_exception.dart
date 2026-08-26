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

  @override
  String toString() => 'LlmException($kind): $message';
}

/// API Key 安全存储抽象。
///
/// 红线(config.yaml 数据归属): Key 永不进日志、永不进数据库、
/// 永不经由非 LLM 请求头之外的方式外发。
/// 测试注入 [InMemorySecureKeyStore];生产用 [FlutterSecureKeyStore]。
library;

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

abstract class SecureKeyStore {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);
}

class FlutterSecureKeyStore implements SecureKeyStore {
  const FlutterSecureKeyStore();

  static const _storage = FlutterSecureStorage();

  @override
  Future<String?> read(String key) => _storage.read(key: key);

  @override
  Future<void> write(String key, String value) =>
      _storage.write(key: key, value: value);

  @override
  Future<void> delete(String key) => _storage.delete(key: key);
}

class InMemorySecureKeyStore implements SecureKeyStore {
  final Map<String, String> _values = {};

  @override
  Future<String?> read(String key) async => _values[key];

  @override
  Future<void> write(String key, String value) async => _values[key] = value;

  @override
  Future<void> delete(String key) async => _values.remove(key);
}

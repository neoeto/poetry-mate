/// LLM 三元组配置(BYOK): baseUrl / API Key / model。
///
/// 存储分离(design D1):
///   API Key → SecureKeyStore(钥匙串/Keystore)
///   baseUrl / model → shared_preferences(非机密)

library;
import 'package:shared_preferences/shared_preferences.dart';

import 'secure_key_store.dart';

/// 普通键值存储抽象(与 SecureKeyStore 同构,测试注入内存实现)。
abstract class PrefsStore {
  Future<String?> getString(String key);
  Future<void> setString(String key, String value);
  Future<void> remove(String key);
}

class SharedPrefsStore implements PrefsStore {
  SharedPrefsStore(this._prefs);

  final SharedPreferencesAsync _prefs;

  @override
  Future<String?> getString(String key) => _prefs.getString(key);

  @override
  Future<void> setString(String key, String value) =>
      _prefs.setString(key, value);

  @override
  Future<void> remove(String key) => _prefs.remove(key);
}

/// 内存实现(测试)
class InMemoryPrefsStore implements PrefsStore {
  final Map<String, String> values = {};

  @override
  Future<String?> getString(String key) async => values[key];

  @override
  Future<void> setString(String key, String value) async => values[key] = value;

  @override
  Future<void> remove(String key) async => values.remove(key);
}

class LlmConfig {
  const LlmConfig({
    required this.baseUrl,
    required this.apiKey,
    required this.model,
  });

  final String baseUrl;
  final String apiKey;
  final String model;

  bool get isComplete =>
      baseUrl.trim().isNotEmpty &&
      apiKey.trim().isNotEmpty &&
      model.trim().isNotEmpty;
}

abstract class LlmConfigStore {
  /// 三元组任一缺失时返回 null(而非残缺对象)
  Future<LlmConfig?> read();

  Future<void> write(LlmConfig config);

  /// 清空全部三元组(含 Key 删除)
  Future<void> clear();
}

class LlmConfigStoreImpl implements LlmConfigStore {
  LlmConfigStoreImpl({
    required SecureKeyStore secureKeyStore,
    required PrefsStore prefs,
  })  : _secure = secureKeyStore,
        _prefs = prefs;

  static const _keyApiKey = 'llm_api_key';
  static const _keyBaseUrl = 'llm_base_url';
  static const _keyModel = 'llm_model';

  final SecureKeyStore _secure;
  final PrefsStore _prefs;

  @override
  Future<LlmConfig?> read() async {
    final apiKey = await _secure.read(_keyApiKey);
    final baseUrl = await _prefs.getString(_keyBaseUrl);
    final model = await _prefs.getString(_keyModel);
    if (apiKey == null || baseUrl == null || model == null) return null;
    if (apiKey.isEmpty || baseUrl.isEmpty || model.isEmpty) return null;
    return LlmConfig(baseUrl: baseUrl, apiKey: apiKey, model: model);
  }

  @override
  Future<void> write(LlmConfig config) async {
    await _secure.write(_keyApiKey, config.apiKey);
    await _prefs.setString(_keyBaseUrl, config.baseUrl);
    await _prefs.setString(_keyModel, config.model);
  }

  @override
  Future<void> clear() async {
    await _secure.delete(_keyApiKey);
    await _prefs.remove(_keyBaseUrl);
    await _prefs.remove(_keyModel);
  }
}

/// LLM 三元组配置(BYOK): baseUrl / API Key / model。
///
/// 存储分离(design D1):
///   API Key → SecureKeyStore(钥匙串/Keystore)
///   baseUrl / model → shared_preferences(非机密)

library;
import 'prefs_store.dart';
import 'secure_key_store.dart';

export 'prefs_store.dart';

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

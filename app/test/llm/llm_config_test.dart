// LlmConfigStore 测试: 三元组读写/残缺返回 null/clear 全清。
// Key 走 InMemorySecureKeyStore 替身(真实 Keychain 行为归设备冒烟)。
import 'package:flutter_test/flutter_test.dart';
import 'package:poetry_mate/core/llm/llm_config.dart';
import 'package:poetry_mate/core/llm/secure_key_store.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

void main() {
  late LlmConfigStore store;
  late InMemorySecureKeyStore secure;

  const config = LlmConfig(
    baseUrl: 'https://api.example.com/v1',
    apiKey: 'sk-test-123',
    model: 'deepseek-chat',
  );

  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.withData({});
    secure = InMemorySecureKeyStore();
    store = LlmConfigStoreImpl(
      secureKeyStore: secure,
      prefs: SharedPreferencesAsync(),
    );
  });

  test('未配置时 read 返回 null', () async {
    expect(await store.read(), isNull);
  });

  test('写入后读回三元组完整一致', () async {
    await store.write(config);
    final read = await store.read();
    expect(read?.baseUrl, config.baseUrl);
    expect(read?.apiKey, config.apiKey);
    expect(read?.model, config.model);
  });

  test('Key 存于安全存储而非偏好', () async {
    await store.write(config);
    final prefs = await SharedPreferencesAsync().getAll();
    expect(prefs.values.any((v) => v.toString().contains('sk-test')), isFalse,
        reason: 'Key 不得进入 shared_preferences');
    expect(await secure.read('llm_api_key'), config.apiKey);
  });

  test('任一字段缺失 → read 返回 null(残缺对象不可用)', () async {
    await store.write(config);
    await secure.delete('llm_api_key');
    expect(await store.read(), isNull);
  });

  test('clear 清空全部三元组', () async {
    await store.write(config);
    await store.clear();
    expect(await store.read(), isNull);
    expect(await secure.read('llm_api_key'), isNull);
  });
}

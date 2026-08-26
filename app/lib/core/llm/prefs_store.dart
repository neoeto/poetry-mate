/// 普通键值存储抽象 —— 与 SecureKeyStore 同构。
///
/// 抽象的目的: 让配置/偏好类逻辑在宿主单元测试中无需平台通道即可注入。
library;

import 'package:shared_preferences/shared_preferences.dart';

abstract class PrefsStore {
  Future<String?> getString(String key);
  Future<void> setString(String key, String value);
  Future<void> remove(String key);
}

/// 生产实现: shared_preferences
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

/// 测试实现
class InMemoryPrefsStore implements PrefsStore {
  final Map<String, String> values = {};

  @override
  Future<String?> getString(String key) async => values[key];

  @override
  Future<void> setString(String key, String value) async =>
      values[key] = value;

  @override
  Future<void> remove(String key) async => values.remove(key);
}

/// 种子版本标记的存储抽象。
///
/// 生产实现走 shared_preferences;测试用内存替身。
/// (版本标记刻意不进数据库 —— 它描述的是"资产 vs 库"的对账状态,
/// 与业务数据生命周期不同;也避免先有鸡还是先有蛋的表结构问题。)

library;
import 'package:shared_preferences/shared_preferences.dart';

abstract class SeedVersionStore {
  Future<String?> read();
  Future<void> write(String version);
}

class SharedPrefsSeedVersionStore implements SeedVersionStore {
  SharedPrefsSeedVersionStore();

  static const _key = 'seed_version';
  final SharedPreferencesAsync _prefs = SharedPreferencesAsync();

  @override
  Future<String?> read() => _prefs.getString(_key);

  @override
  Future<void> write(String version) => _prefs.setString(_key, version);
}

/// 内存替身(单元测试专用)
class InMemorySeedVersionStore implements SeedVersionStore {
  String? _version;

  @override
  Future<String?> read() async => _version;

  @override
  Future<void> write(String version) async => _version = version;
}

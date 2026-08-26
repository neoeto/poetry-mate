/// 种子装载器(任务 1.4 / specs/seed-library)。
///
/// 流程:
///   读 assets/seed/version.txt → 与已装载标记比对
///   ├─ 相同        → 跳过(零 IO 成本,二次启动路径)
///   ├─ 资产更新/首装 → 解压 seed.json.zst → 单事务 upsert 全量 → 写新标记
///
/// 设计要点:
/// - upsert(insertOnConflictUpdate): 种子升级重灌不产生主键冲突;
/// - 单事务: 中途失败不留半截库,重试即自愈;
/// - 解压函数可注入: 真实 es_compression 依赖原生库,宿主单测注入恒等函数。

library;
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/services.dart' show AssetBundle;

import '../../core/db/app_database.dart';
import '../../domain/entities/poem.dart';
import '../mappers/poem_mapper.dart';
import 'seed_version_store.dart';

enum SeedLoadAction { skipped, installed, upgraded }

class SeedLoadResult {
  const SeedLoadResult({
    required this.action,
    required this.version,
    this.recordCount = 0,
  });

  final SeedLoadAction action;
  final String version;
  final int recordCount;
}

class SeedLoader {
  static const versionAsset = 'assets/seed/version.txt';
  static const dataAsset = 'assets/seed/seed.json.zst';

  SeedLoader({
    required AssetBundle assets,
    required AppDatabase db,
    required SeedVersionStore versionStore,
    required Uint8List Function(Uint8List) decompress,
  })  : _assets = assets,
        _db = db,
        _versionStore = versionStore,
        _decompress = decompress;

  final AssetBundle _assets;
  final AppDatabase _db;
  final SeedVersionStore _versionStore;
  final Uint8List Function(Uint8List) _decompress;

  Future<SeedLoadResult> loadIfNeeded() async {
    // 1) 读资产版本号
    String assetVersion;
    try {
      assetVersion = (await _assets.loadString(versionAsset)).trim();
    } catch (_) {
      // 资产缺失(FlutterError/Exception 均可): 开发环境无种子包属合法状态
      return const SeedLoadResult(
          action: SeedLoadAction.skipped, version: 'no_asset');
    }
    if (assetVersion.isEmpty) {
      return const SeedLoadResult(
          action: SeedLoadAction.skipped, version: 'no_asset');
    }

    // 2) 与已装载标记比对
    final installed = await _versionStore.read();
    if (installed == assetVersion) {
      return SeedLoadResult(
        action: SeedLoadAction.skipped,
        version: assetVersion,
      );
    }

    // 3) 解压 + 解析 + 单事务 upsert
    final compressed = (await _assets.load(dataAsset)).buffer.asUint8List();
    final jsonText = utf8.decode(_decompress(compressed));
    final rawList = jsonDecode(jsonText) as List<dynamic>;
    final poems = [
      for (final raw in rawList.cast<Map<String, dynamic>>())
        Poem.fromPackageJson(raw),
    ];

    await _db.transaction(() async {
      for (final poem in poems) {
        await _db
            .into(_db.poems)
            .insertOnConflictUpdate(PoemMapper.toCompanion(poem));
      }
    });

    // 4) 写标记(成功后才写 —— 失败重试路径天然成立)
    await _versionStore.write(assetVersion);

    return SeedLoadResult(
      action:
          installed == null ? SeedLoadAction.installed : SeedLoadAction.upgraded,
      version: assetVersion,
      recordCount: poems.length,
    );
  }
}

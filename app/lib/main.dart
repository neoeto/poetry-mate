import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:drift/native.dart';
import 'package:flutter/services.dart';

import 'core/compression/zstd_codec.dart';
import 'core/db/app_database.dart';
import 'core/ui/app_router.dart';
import 'core/ui/app_theme.dart';
import 'data/providers.dart';
import 'data/seed/seed_loader.dart';
import 'data/seed/seed_version_store.dart';

/// 主题模式(亮/暗/跟随系统);后续接入设置页持久化。
final themeModeProvider = StateProvider<ThemeMode>((_) => ThemeMode.system);

final appRouterProvider = Provider<GoRouter>((ref) => buildAppRouter());

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ── 数据层装配: 文件库 + 种子装载 ──
  // 失败兜底: 装载失败不阻断应用启动(空库可用,重装即自愈)。
  AppDatabase? database;
  try {
    final dir = await getApplicationDocumentsDirectory();
    final dbFile = File(p.join(dir.path, 'poetry.db'));
    database = AppDatabase(openNativeConnection(dbFile));

    final loader = SeedLoader(
      assets: rootBundle,
      db: database,
      versionStore: SharedPrefsSeedVersionStore(),
      decompress: esZstdDecompress,
    );
    final result = await loader.loadIfNeeded();
    debugPrint('[seed] ${result.action} ${result.recordCount} 条 (${result.version})');
  } catch (e) {
    debugPrint('[seed] 装载失败(以空库继续): $e');
    database ??= AppDatabase(NativeDatabase.memory());
  }

  runApp(
    ProviderScope(
      overrides: [appDatabaseProvider.overrideWithValue(database)],
      child: const PoetryMateApp(),
    ),
  );
}

class PoetryMateApp extends ConsumerWidget {
  const PoetryMateApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: 'Poetry Mate',
      routerConfig: ref.watch(appRouterProvider),
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: ref.watch(themeModeProvider),
      debugShowCheckedModeBanner: false,
    );
  }
}

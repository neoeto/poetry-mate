import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'core/ui/app_router.dart';
import 'core/ui/app_theme.dart';

/// 主题模式(亮/暗/跟随系统);后续接入设置页持久化。
final themeModeProvider =
    StateProvider<ThemeMode>((ref) => ThemeMode.system);

final appRouterProvider = Provider<GoRouter>((ref) => buildAppRouter());

void main() {
  runApp(const ProviderScope(child: PoetryMateApp()));
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

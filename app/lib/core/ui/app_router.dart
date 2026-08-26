/// 应用路由 —— 底部四 Tab 导航壳。
///
/// StatefulShellRoute.indexedStack 保证各 Tab 自持导航栈与状态
/// (spec 场景: Tab 切换状态保持)。阅读页为顶层深链路由,便于后续分享直达。

library;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/browse/browse_page.dart';
import '../../features/favorites/favorites_page.dart';
import '../../features/settings/llm_settings_page.dart';
import '../../features/settings/mine_page.dart';
import '../../features/today/today_page.dart';
import '../../features/reader/poem_route_page.dart';

final rootNavigatorKey = GlobalKey<NavigatorState>();

class TabSpec {
  const TabSpec(this.path, this.label, this.icon, this.selectedIcon);

  final String path;
  final String label;
  final IconData icon;
  final IconData selectedIcon;
}

const _tabs = <TabSpec>[
  TabSpec('/today', '今日', Icons.auto_stories_outlined, Icons.auto_stories),
  TabSpec('/browse', '分类', Icons.category_outlined, Icons.category),
  TabSpec(
      '/favorites', '收藏', Icons.favorite_border_outlined, Icons.favorite),
  TabSpec('/settings', '我的', Icons.person_outline_outlined, Icons.person),
];

GoRouter buildAppRouter() {
  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: '/today',
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) =>
            HomeShell(navigationShell: shell),
        branches: [
          for (final tab in _tabs)
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: tab.path,
                  builder: (_, _) => _branchPage(tab.path),
                ),
              ],
            ),
        ],
      ),
      // LLM 配置子页
      GoRoute(
        path: '/settings/llm',
        builder: (_, _) => const LlmSettingsPage(),
      ),

      // 阅读页顶层深链
      GoRoute(
        path: '/poem/:id',
        builder: (context, state) => PoemRoutePage(
          poemId: state.pathParameters['id'] ?? '',
        ),
      ),
    ],
  );
}

/// 各分支页面装配(全部真实化;今日策展/收藏功能后续版本增强)
Widget _branchPage(String path) {
  switch (path) {
    case '/today':
      return const TodayPage();
    case '/browse':
      return const BrowsePage();
    case '/favorites':
      return const FavoritesPage();
    case '/settings':
      return const MinePage();
    default:
      return const SizedBox.shrink();
  }
}

/// 底部导航壳:M3 NavigationBar,点击回首次位置(再点回顶语义留给页面内处理)。
class HomeShell extends StatelessWidget {
  const HomeShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: navigationShell.currentIndex,
        onDestinationSelected: (index) => navigationShell.goBranch(
          index,
          initialLocation: index == navigationShell.currentIndex,
        ),
        destinations: [
          for (final tab in _tabs)
            NavigationDestination(
              icon: Icon(tab.icon),
              selectedIcon: Icon(tab.selectedIcon),
              label: tab.label,
            ),
        ],
      ),
    );
  }
}

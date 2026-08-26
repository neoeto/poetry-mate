/// 应用路由 —— 底部四 Tab 导航壳。
///
/// StatefulShellRoute.indexedStack 保证各 Tab 自持导航栈与状态
/// (spec 场景: Tab 切换状态保持)。阅读页为顶层深链路由,便于后续分享直达。

library;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

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
                  builder: (_, _) => _TabPlaceholder(spec: tab),
                ),
              ],
            ),
        ],
      ),
      // 阅读页顶层深链(内容由任务 reading-page 变更实现,当前占位)
      GoRoute(
        path: '/poem/:id',
        builder: (context, state) => _ReaderPlaceholder(
          id: state.pathParameters['id'] ?? '',
        ),
      ),
    ],
  );
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

class _TabPlaceholder extends StatelessWidget {
  const _TabPlaceholder({required this.spec});

  final TabSpec spec;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(spec.icon, size: 48, color: Theme.of(context).colorScheme.outline),
          const SizedBox(height: 12),
          Text('${spec.label} · 功能将在后续版本到来',
              style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    );
  }
}

class _ReaderPlaceholder extends StatelessWidget {
  const _ReaderPlaceholder({required this.id});

  final String id;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('诗')),
      body: Center(child: Text('阅读页占位 · id=$id')),
    );
  }
}

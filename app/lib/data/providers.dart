/// 数据层依赖装配 —— main() 启动时以 override 注入真实实现。
///
/// 测试中用 `appDatabaseProvider.overrideWithValue(memoryDb)` 替换,
/// 从而整棵 widget 树(Full App)可在无平台通道下测试。

library;
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/db/app_database.dart';
import '../features/browse/browse_filters.dart';
import '../domain/entities/poem.dart';
import '../core/llm/annotation_service.dart';
import '../core/llm/llm_providers.dart';
import '../core/llm/persona.dart';
import 'preferences/reading_prefs.dart';
import 'repositories/favorites_repository.dart';
import 'repositories/notebook_repository.dart';
import 'repositories/poem_repository.dart';

/// 由 main() overrideWithValue 注入;未注入即用 = 编程错误
final appDatabaseProvider = Provider<AppDatabase>((ref) {
  throw UnimplementedError('appDatabaseProvider 必须在 main() 中 override');
});

final poemRepositoryProvider = Provider<PoemRepository>(
  (ref) => DriftPoemRepository(ref.watch(appDatabaseProvider)),
);

/// 分类页过滤键 → 实体查询参数
typedef PoemFilter = (String? dynasty, String? type);

PoemFilter filterOf(String key) =>
    BrowseFilters.all.firstWhere((f) => f.key == key, orElse: () => const BrowseFilters(BrowseFilters.allKey, '全部', null, null))
        .toQuery();

/// 当前选中过滤键(UI 状态)
final browseFilterProvider = StateProvider<String>((_) => BrowseFilters.allKey);

/// 按过滤键拉取诗列表(autoDispose: 离开页面释放查询缓存)
final filteredPoemsProvider =
    FutureProvider.autoDispose.family<List<Poem>, String>((ref, key) async {
  final repo = ref.watch(poemRepositoryProvider);
  final (dynasty, type) = filterOf(key);
  return repo.listByDynastyAndType(dynasty: dynasty, type: type, limit: 500);
});

/// 按 id 取单首(阅读页深链)
final poemByIdProvider =
    FutureProvider.autoDispose.family<Poem?, String>((ref, id) {
  return ref.watch(poemRepositoryProvider).byId(id);
});


final notebookRepositoryProvider = Provider<NotebookRepository>(
    (ref) => DriftNotebookRepository(ref.watch(appDatabaseProvider)));

final favoritesRepositoryProvider = Provider<FavoritesRepository>(
    (ref) => DriftFavoritesRepository(ref.watch(appDatabaseProvider)));

final readingPrefsProvider =
    Provider<ReadingPrefs>((ref) => SharedReadingPrefs(ref.watch(sharedPreferencesAsyncProvider)));

/// 收藏状态(阅读页心形);切换后 invalidate 刷新
final isFavoriteProvider =
    FutureProvider.autoDispose.family<bool, String>((ref, poemId) {
  return ref.watch(favoritesRepositoryProvider).isFavorite(poemId);
});

/// 收藏页按最近收藏时间返回已关联的诗实体
final favoriteItemsProvider = FutureProvider.autoDispose((ref) {
  return ref.watch(favoritesRepositoryProvider).listByRecent();
});

/// 人格模板服务(生产使用随包 rootBundle,测试可 override)
final personaServiceProvider = Provider<PersonaService>((ref) {
  return PersonaService(
    assets: rootBundle,
    prefs: ref.watch(prefsStoreProvider),
  );
});

/// 三层赏析服务(仓库、LLM 客户端和人格模板统一装配)
final annotationServiceProvider = Provider<AnnotationService>((ref) {
  return AnnotationService(
    notebookRepository: ref.watch(notebookRepositoryProvider),
    llmClient: ref.watch(llmClientProvider),
    personaService: ref.watch(personaServiceProvider),
  );
});

/// 当前 AI 人格选择(只读响应式状态)
final personaSelectionProvider = FutureProvider.autoDispose<String>((ref) {
  return ref.watch(personaServiceProvider).selectedId();
});

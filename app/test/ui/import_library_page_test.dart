// 导入书架页面的目录读取与导入入口 widget 测试。
import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:poetry_mate/core/db/app_database.dart';
import 'package:poetry_mate/core/llm/prefs_store.dart';
import 'package:poetry_mate/data/library/library_data_source.dart';
import 'package:poetry_mate/data/library/library_import_service.dart';
import 'package:poetry_mate/data/library/library_models.dart';
import 'package:poetry_mate/data/providers.dart';
import 'package:poetry_mate/features/settings/import_library_page.dart';

void main() {
  final collection = LibraryCollectionSummary(
    id: 'tangshi',
    title: '全唐诗',
    dynasty: '唐',
    type: 'shi',
    recordCount: 2,
    volumeCount: 1,
    totalBytes: 1024,
    builtin: false,
  );
  final catalog = LibraryCatalog(version: 'v1', collections: [collection]);

  testWidgets('读取数据源目录后展示作品集并可开始导入', (tester) async {
    final prefs = InMemoryPrefsStore();
    final service = _FakeImportService(catalog);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          libraryImportVersionStoreProvider.overrideWithValue(
            PrefsLibraryImportVersionStore(prefs),
          ),
          libraryImportServiceProvider(
            'https://data.example.com',
          ).overrideWithValue(service),
        ],
        child: const MaterialApp(home: ImportLibraryPage()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('library-source-url')),
      'https://data.example.com',
    );
    await tester.tap(find.text('读取数据源目录'));
    await tester.pumpAndSettle();

    expect(find.text('全唐诗'), findsOneWidget);
    expect(find.text('导入已选作品集（1）'), findsOneWidget);
    expect(
      await prefs.getString('library_data_source_url'),
      'https://data.example.com',
    );

    await tester.tap(find.text('导入已选作品集（1）'));
    await tester.pumpAndSettle();
    expect(find.text('导入完成，共新增或更新 2 首诗'), findsOneWidget);
    expect(service.importCalls, 1);
  });

  testWidgets('没有数据源地址时给出可行动提示', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          libraryImportVersionStoreProvider.overrideWithValue(
            PrefsLibraryImportVersionStore(InMemoryPrefsStore()),
          ),
        ],
        child: const MaterialApp(home: ImportLibraryPage()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('读取数据源目录'));
    await tester.pumpAndSettle();
    expect(find.text('请先填写数据源地址'), findsOneWidget);
  });
}

class _FakeImportService extends LibraryImportService {
  _FakeImportService(this.catalog)
    : super(
        source: _NoopLibraryDataSource(),
        db: AppDatabase(NativeDatabase.memory()),
        versions: _NoopVersionStore(),
        decompress: _identity,
      );

  final LibraryCatalog catalog;
  var importCalls = 0;

  @override
  Future<LibraryCatalog> fetchCatalog() async => catalog;

  @override
  Future<LibraryImportResult> importCollections(
    List<LibraryCollectionSummary> collections, {
    void Function(LibraryImportProgress progress)? onProgress,
  }) async {
    importCalls++;
    for (final item in collections) {
      onProgress?.call(
        LibraryImportProgress(
          collection: item,
          stage: LibraryImportStage.completed,
          volumeIndex: item.volumeCount,
          volumeCount: item.volumeCount,
          recordsImported: item.recordCount,
        ),
      );
    }
    return LibraryImportResult(
      collectionCount: collections.length,
      importedRecords: collections.fold(
        0,
        (sum, item) => sum + item.recordCount,
      ),
      skippedCollections: 0,
    );
  }
}

Uint8List _identity(Uint8List value) => value;

class _NoopLibraryDataSource implements LibraryDataSource {
  @override
  Future<LibraryCatalog> fetchCatalog() => throw UnimplementedError();

  @override
  Future<LibraryCollectionManifest> fetchManifest(String collectionId) =>
      throw UnimplementedError();

  @override
  Future<Uint8List> downloadVolume(String collectionId, LibraryVolume volume) =>
      throw UnimplementedError();

  @override
  void close() {}
}

class _NoopVersionStore implements LibraryImportVersionStore {
  @override
  Future<String?> versionFor(String collectionId) async => null;

  @override
  Future<void> markVersion(String collectionId, String version) async {}
}

// 书库目录解析与分卷导入测试。
import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:poetry_mate/core/db/app_database.dart';
import 'package:poetry_mate/core/llm/prefs_store.dart';
import 'package:poetry_mate/data/library/library_data_source.dart';
import 'package:poetry_mate/data/library/library_import_service.dart';
import 'package:poetry_mate/data/library/library_models.dart';
import 'package:poetry_mate/data/repositories/poem_repository.dart';

void main() {
  test('解析 Worker catalog 与 collection manifest', () {
    final catalog = LibraryCatalog.fromJson({
      'version': 'v20260825.b8594f81',
      'collections': [
        {
          'id': 'seed',
          'title': '种子集',
          'dynasty': null,
          'type': 'mixed',
          'record_count': 300,
          'volume_count': 1,
          'total_bytes': 123,
          'builtin': true,
        },
      ],
    });
    expect(catalog.version, 'v20260825.b8594f81');
    expect(catalog.collections.single.builtin, isTrue);

    final manifest = LibraryCollectionManifest.fromJson({
      'version': catalog.version,
      'collection': {
        'id': 'tangshi',
        'title': '全唐诗',
        'dynasty': '唐',
        'type': 'shi',
        'record_count': 1,
        'volume_count': 1,
        'volumes': [
          {
            'file': 'volumes/tangshi/tangshi.0001.json.zst',
            'sha256': 'a' * 64,
            'bytes': 123,
            'records': 1,
          },
        ],
      },
    });
    expect(manifest.collection.id, 'tangshi');
    expect(manifest.collection.totalBytes, 123);
    expect(manifest.volumes.single.records, 1);
  });

  test('完整性校验通过后导入本地库，并按版本跳过重复导入', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);

    final compressed = Uint8List.fromList(
      utf8.encode(
        jsonEncode([
          {
            'id': 'imported-poem',
            'author': '李白',
            'title': '静夜思',
            'dynasty': '唐',
            'type': 'shi',
            'paragraphs': ['床前明月光，'],
            'preface': null,
            'rhythmic': null,
            'popularity': 10,
            'raw_text': ['床前明月光，'],
            'tags': null,
            'source_collection': 'tangshi',
          },
        ]),
      ),
    );
    final collection = LibraryCollectionSummary(
      id: 'tangshi',
      title: '全唐诗',
      dynasty: '唐',
      type: 'shi',
      recordCount: 1,
      volumeCount: 1,
      totalBytes: compressed.length,
      builtin: false,
    );
    final volume = LibraryVolume(
      file: 'volumes/tangshi/tangshi.0001.json.zst',
      sha256: sha256.convert(compressed).toString(),
      bytes: compressed.length,
      records: 1,
    );
    final source = _FakeLibraryDataSource(
      manifest: LibraryCollectionManifest(
        version: 'v1',
        collection: collection,
        volumes: [volume],
      ),
      volumeBytes: compressed,
    );
    final versions = _FakeVersionStore();
    final service = LibraryImportService(
      source: source,
      db: db,
      versions: versions,
      decompress: (value) => value,
    );
    final progress = <LibraryImportStage>[];

    final first = await service.importCollections([
      collection,
    ], onProgress: (value) => progress.add(value.stage));
    expect(first.importedRecords, 1);
    expect(first.skippedCollections, 0);
    expect(await DriftPoemRepository(db).byId('imported-poem'), isNotNull);
    expect(versions.values['tangshi'], 'v1');
    expect(progress, contains(LibraryImportStage.completed));
    expect(source.downloadCount, 1);

    final second = await service.importCollections([collection]);
    expect(second.skippedCollections, 1);
    expect(second.importedRecords, 0);
    expect(source.downloadCount, 1);
  });

  test('分卷校验失败时不写入版本标记', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final bytes = Uint8List.fromList(utf8.encode('[]'));
    final collection = _collection(bytes.length);
    final volume = LibraryVolume(
      file: 'volumes/tangshi/tangshi.0001.json.zst',
      sha256: '0' * 64,
      bytes: bytes.length,
      records: 0,
    );
    final versions = _FakeVersionStore();
    final service = LibraryImportService(
      source: _FakeLibraryDataSource(
        manifest: LibraryCollectionManifest(
          version: 'v2',
          collection: collection,
          volumes: [volume],
        ),
        volumeBytes: bytes,
      ),
      db: db,
      versions: versions,
      decompress: (value) => value,
    );

    await expectLater(
      service.importCollections([collection]),
      throwsA(isA<LibraryImportException>()),
    );
    expect(versions.values, isEmpty);
  });

  test('普通偏好存储只保存数据源地址和导入版本', () async {
    final prefs = InMemoryPrefsStore();
    final store = PrefsLibraryImportVersionStore(prefs);

    await store.saveDataSourceUrl('https://data.example.com');
    await store.markVersion('tangshi', 'v1');

    expect(await store.dataSourceUrl(), 'https://data.example.com');
    expect(await store.versionFor('tangshi'), 'v1');
  });
}

LibraryCollectionSummary _collection(int bytes) => LibraryCollectionSummary(
  id: 'tangshi',
  title: '全唐诗',
  dynasty: '唐',
  type: 'shi',
  recordCount: 0,
  volumeCount: 1,
  totalBytes: bytes,
  builtin: false,
);

class _FakeLibraryDataSource implements LibraryDataSource {
  _FakeLibraryDataSource({required this.manifest, required this.volumeBytes});

  final LibraryCollectionManifest manifest;
  final Uint8List volumeBytes;
  var downloadCount = 0;

  @override
  Future<LibraryCatalog> fetchCatalog() async => LibraryCatalog(
    version: manifest.version,
    collections: [manifest.collection],
  );

  @override
  Future<LibraryCollectionManifest> fetchManifest(String collectionId) async =>
      manifest;

  @override
  Future<Uint8List> downloadVolume(
    String collectionId,
    LibraryVolume volume,
  ) async {
    downloadCount++;
    return volumeBytes;
  }

  @override
  void close() {}
}

class _FakeVersionStore implements LibraryImportVersionStore {
  final values = <String, String>{};

  @override
  Future<String?> versionFor(String collectionId) async => values[collectionId];

  @override
  Future<void> markVersion(String collectionId, String version) async {
    values[collectionId] = version;
  }
}

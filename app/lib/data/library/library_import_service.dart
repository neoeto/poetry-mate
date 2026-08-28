/// 诗库导入编排 —— 校验分卷后写入本地 SQLite，不上传任何用户数据。
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

import '../../core/db/app_database.dart';
import '../../core/llm/prefs_store.dart';
import '../../domain/entities/poem.dart';
import '../mappers/poem_mapper.dart';
import 'library_data_source.dart';
import 'library_models.dart';

const kDefaultLibraryDataSourceUrl = String.fromEnvironment(
  'POETRY_MATE_DATA_URL',
  defaultValue: '',
);

abstract class LibraryImportVersionStore {
  Future<String?> versionFor(String collectionId);

  Future<void> markVersion(String collectionId, String version);
}

class PrefsLibraryImportVersionStore implements LibraryImportVersionStore {
  PrefsLibraryImportVersionStore(this._prefs);

  static const _urlKey = 'library_data_source_url';
  final PrefsStore _prefs;

  static String versionKey(String collectionId) =>
      'library_import_version_$collectionId';

  Future<String?> dataSourceUrl() => _prefs.getString(_urlKey);

  Future<void> saveDataSourceUrl(String url) => _prefs.setString(_urlKey, url);

  @override
  Future<String?> versionFor(String collectionId) =>
      _prefs.getString(versionKey(collectionId));

  @override
  Future<void> markVersion(String collectionId, String version) =>
      _prefs.setString(versionKey(collectionId), version);
}

enum LibraryImportStage {
  fetchingManifest,
  downloading,
  importing,
  skipped,
  completed,
}

class LibraryImportProgress {
  const LibraryImportProgress({
    required this.collection,
    required this.stage,
    required this.volumeIndex,
    required this.volumeCount,
    required this.recordsImported,
    this.skipped = false,
  });

  final LibraryCollectionSummary collection;
  final LibraryImportStage stage;
  final int volumeIndex;
  final int volumeCount;
  final int recordsImported;
  final bool skipped;

  double get fraction {
    if (skipped || stage == LibraryImportStage.completed) return 1;
    if (volumeCount <= 0) return 0;
    return (volumeIndex / volumeCount).clamp(0, 1).toDouble();
  }
}

class LibraryImportResult {
  const LibraryImportResult({
    required this.collectionCount,
    required this.importedRecords,
    required this.skippedCollections,
  });

  final int collectionCount;
  final int importedRecords;
  final int skippedCollections;
}

class LibraryImportException implements Exception {
  const LibraryImportException(this.message);

  final String message;

  @override
  String toString() => message;
}

class LibraryImportService {
  LibraryImportService({
    required LibraryDataSource source,
    required AppDatabase db,
    required LibraryImportVersionStore versions,
    required Uint8List Function(Uint8List) decompress,
  }) : _source = source,
       _db = db,
       _versions = versions,
       _decompress = decompress;

  final LibraryDataSource _source;
  final AppDatabase _db;
  final LibraryImportVersionStore _versions;
  final Uint8List Function(Uint8List) _decompress;

  Future<LibraryCatalog> fetchCatalog() => _source.fetchCatalog();

  Future<LibraryImportResult> importCollections(
    List<LibraryCollectionSummary> collections, {
    void Function(LibraryImportProgress progress)? onProgress,
  }) async {
    if (collections.isEmpty) {
      throw const LibraryImportException('请至少选择一个作品集');
    }

    var importedRecords = 0;
    var skippedCollections = 0;
    for (final collection in collections) {
      onProgress?.call(
        LibraryImportProgress(
          collection: collection,
          stage: LibraryImportStage.fetchingManifest,
          volumeIndex: 0,
          volumeCount: collection.volumeCount,
          recordsImported: importedRecords,
        ),
      );
      final manifest = await _source.fetchManifest(collection.id);
      if (manifest.collection.id != collection.id) {
        throw LibraryImportException(
          '作品集标识不一致：${collection.id} / ${manifest.collection.id}',
        );
      }
      if (manifest.volumes.length != manifest.collection.volumeCount ||
          manifest.collection.volumeCount != collection.volumeCount ||
          manifest.collection.recordCount != collection.recordCount) {
        throw LibraryImportException('「${collection.title}」分卷清单与目录不一致');
      }

      final importedVersion = await _versions.versionFor(collection.id);
      if (importedVersion == manifest.version) {
        skippedCollections++;
        onProgress?.call(
          LibraryImportProgress(
            collection: collection,
            stage: LibraryImportStage.skipped,
            volumeIndex: manifest.volumes.length,
            volumeCount: manifest.volumes.length,
            recordsImported: importedRecords,
            skipped: true,
          ),
        );
        continue;
      }

      var collectionRecords = 0;
      for (var index = 0; index < manifest.volumes.length; index++) {
        final volume = manifest.volumes[index];
        final volumeNumber = index + 1;
        onProgress?.call(
          LibraryImportProgress(
            collection: collection,
            stage: LibraryImportStage.downloading,
            volumeIndex: index,
            volumeCount: manifest.volumes.length,
            recordsImported: importedRecords,
          ),
        );
        final compressed = await _source.downloadVolume(collection.id, volume);
        _verifyVolume(compressed, volume, collection.title, volumeNumber);

        final poems = _decodeVolume(
          compressed,
          volume,
          collection.title,
          volumeNumber,
        );
        onProgress?.call(
          LibraryImportProgress(
            collection: collection,
            stage: LibraryImportStage.importing,
            volumeIndex: index,
            volumeCount: manifest.volumes.length,
            recordsImported: importedRecords,
          ),
        );
        await _upsertPoems(poems);
        collectionRecords += poems.length;
        importedRecords += poems.length;
        onProgress?.call(
          LibraryImportProgress(
            collection: collection,
            stage: LibraryImportStage.downloading,
            volumeIndex: volumeNumber,
            volumeCount: manifest.volumes.length,
            recordsImported: importedRecords,
          ),
        );
      }

      if (collectionRecords != manifest.collection.recordCount) {
        throw LibraryImportException('「${collection.title}」记录数量校验失败');
      }
      // 只有全部分卷成功后才写版本标记；中途失败时下次会幂等重试。
      await _versions.markVersion(collection.id, manifest.version);
      onProgress?.call(
        LibraryImportProgress(
          collection: collection,
          stage: LibraryImportStage.completed,
          volumeIndex: manifest.volumes.length,
          volumeCount: manifest.volumes.length,
          recordsImported: importedRecords,
        ),
      );
    }

    return LibraryImportResult(
      collectionCount: collections.length,
      importedRecords: importedRecords,
      skippedCollections: skippedCollections,
    );
  }

  void close() => _source.close();

  Future<void> _upsertPoems(List<Poem> poems) {
    return _db.transaction(() async {
      for (final poem in poems) {
        await _db
            .into(_db.poems)
            .insertOnConflictUpdate(PoemMapper.toCompanion(poem));
      }
    });
  }

  List<Poem> _decodeVolume(
    Uint8List compressed,
    LibraryVolume volume,
    String collectionTitle,
    int volumeNumber,
  ) {
    try {
      final jsonText = utf8.decode(_decompress(compressed));
      final raw = jsonDecode(jsonText);
      if (raw is! List || raw.length != volume.records) {
        throw const FormatException('记录数量与清单不一致');
      }
      return [
        for (final item in raw) Poem.fromPackageJson(_asJsonObject(item)),
      ];
    } on LibraryImportException {
      rethrow;
    } on Object catch (error) {
      throw LibraryImportException(
        '「$collectionTitle」第 $volumeNumber 卷数据异常：${_detail(error)}',
      );
    }
  }

  void _verifyVolume(
    Uint8List compressed,
    LibraryVolume volume,
    String collectionTitle,
    int volumeNumber,
  ) {
    if (compressed.length != volume.bytes) {
      throw LibraryImportException('「$collectionTitle」第 $volumeNumber 卷大小校验失败');
    }
    final actual = sha256.convert(compressed).toString();
    if (actual != volume.sha256) {
      throw LibraryImportException(
        '「$collectionTitle」第 $volumeNumber 卷完整性校验失败',
      );
    }
  }

  static Map<String, dynamic> _asJsonObject(Object? value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    throw const FormatException('记录不是 JSON 对象');
  }

  static String _detail(Object error) {
    final text = error.toString().trim();
    return text.length > 160 ? '${text.substring(0, 160)}…' : text;
  }
}

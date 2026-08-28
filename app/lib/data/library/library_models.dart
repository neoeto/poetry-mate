/// 数据源目录与分卷模型 —— 与 Cloudflare Worker 的公开契约对齐。
library;

class LibraryCollectionSummary {
  const LibraryCollectionSummary({
    required this.id,
    required this.title,
    required this.dynasty,
    required this.type,
    required this.recordCount,
    required this.volumeCount,
    required this.totalBytes,
    required this.builtin,
  });

  final String id;
  final String title;
  final String? dynasty;
  final String type;
  final int recordCount;
  final int volumeCount;
  final int totalBytes;
  final bool builtin;

  factory LibraryCollectionSummary.fromJson(Map<String, dynamic> json) {
    return LibraryCollectionSummary(
      id: _requiredString(json, 'id'),
      title: _requiredString(json, 'title'),
      dynasty: _optionalString(json, 'dynasty'),
      type: _requiredString(json, 'type'),
      recordCount: _requiredInt(json, 'record_count'),
      volumeCount: _requiredInt(json, 'volume_count'),
      totalBytes: _requiredInt(json, 'total_bytes'),
      builtin: json['builtin'] == true,
    );
  }
}

class LibraryCatalog {
  const LibraryCatalog({required this.version, required this.collections});

  final String version;
  final List<LibraryCollectionSummary> collections;

  factory LibraryCatalog.fromJson(Object? raw) {
    final json = _asJsonObject(raw);
    final rawCollections = json['collections'];
    if (rawCollections is! List) {
      throw const FormatException('数据源目录缺少 collections');
    }

    return LibraryCatalog(
      version: _requiredString(json, 'version'),
      collections: [
        for (final item in rawCollections)
          LibraryCollectionSummary.fromJson(_asJsonObject(item)),
      ],
    );
  }
}

class LibraryVolume {
  const LibraryVolume({
    required this.file,
    required this.sha256,
    required this.bytes,
    required this.records,
  });

  final String file;
  final String sha256;
  final int bytes;
  final int records;

  factory LibraryVolume.fromJson(Map<String, dynamic> json) {
    return LibraryVolume(
      file: _requiredString(json, 'file'),
      sha256: _requiredString(json, 'sha256'),
      bytes: _requiredInt(json, 'bytes'),
      records: _requiredInt(json, 'records'),
    );
  }
}

class LibraryCollectionManifest {
  const LibraryCollectionManifest({
    required this.version,
    required this.collection,
    required this.volumes,
  });

  final String version;
  final LibraryCollectionSummary collection;
  final List<LibraryVolume> volumes;

  factory LibraryCollectionManifest.fromJson(Object? raw) {
    final json = _asJsonObject(raw);
    final collectionJson = _asJsonObject(json['collection']);
    final rawVolumes = collectionJson['volumes'];
    if (rawVolumes is! List || rawVolumes.isEmpty) {
      throw const FormatException('数据源分卷清单为空');
    }

    return LibraryCollectionManifest(
      version: _requiredString(json, 'version'),
      collection: LibraryCollectionSummary(
        id: _requiredString(collectionJson, 'id'),
        title: _requiredString(collectionJson, 'title'),
        dynasty: _optionalString(collectionJson, 'dynasty'),
        type: _requiredString(collectionJson, 'type'),
        recordCount: _requiredInt(collectionJson, 'record_count'),
        volumeCount: _requiredInt(collectionJson, 'volume_count'),
        totalBytes: rawVolumes
            .map((item) => _requiredInt(_asJsonObject(item), 'bytes'))
            .fold<int>(0, (sum, bytes) => sum + bytes),
        builtin: collectionJson['builtin'] == true,
      ),
      volumes: [
        for (final item in rawVolumes)
          LibraryVolume.fromJson(_asJsonObject(item)),
      ],
    );
  }
}

Map<String, dynamic> _asJsonObject(Object? value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return Map<String, dynamic>.from(value);
  throw const FormatException('数据源返回的对象格式异常');
}

String _requiredString(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is String && value.trim().isNotEmpty) return value.trim();
  throw FormatException('数据源字段 $key 缺失');
}

String? _optionalString(Map<String, dynamic> json, String key) {
  final value = json[key];
  return value is String && value.trim().isNotEmpty ? value.trim() : null;
}

int _requiredInt(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is num && value >= 0) return value.toInt();
  throw FormatException('数据源字段 $key 格式异常');
}

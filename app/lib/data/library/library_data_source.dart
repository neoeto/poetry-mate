/// 诗库数据源客户端 —— 只访问 Worker 的公开 GET 接口，不携带用户信息。
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'library_models.dart';

abstract class LibraryDataSource {
  Future<LibraryCatalog> fetchCatalog();

  Future<LibraryCollectionManifest> fetchManifest(String collectionId);

  Future<Uint8List> downloadVolume(String collectionId, LibraryVolume volume);

  void close();
}

class LibraryDataSourceException implements Exception {
  const LibraryDataSourceException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// HTTP 实现。baseUrl 只需填写 Worker 根地址，例如
/// `https://data.example.com`，不要填写 `/api/v1/catalog`。
class HttpLibraryDataSource implements LibraryDataSource {
  HttpLibraryDataSource({
    required String baseUrl,
    this.connectTimeout = const Duration(seconds: 15),
    this.receiveTimeout = const Duration(seconds: 120),
    HttpClient? client,
  }) : _baseUri = _parseBaseUri(baseUrl),
       _client = client ?? HttpClient(),
       _ownsClient = client == null;

  final Uri _baseUri;
  final HttpClient _client;
  final bool _ownsClient;
  final Duration connectTimeout;
  final Duration receiveTimeout;

  @override
  Future<LibraryCatalog> fetchCatalog() async {
    final body = await _get(_endpoint('/api/v1/catalog'));
    try {
      return LibraryCatalog.fromJson(jsonDecode(utf8.decode(body)));
    } on LibraryDataSourceException {
      rethrow;
    } on Object catch (error) {
      throw LibraryDataSourceException('目录格式异常：${_detail(error)}');
    }
  }

  @override
  Future<LibraryCollectionManifest> fetchManifest(String collectionId) async {
    _validateCollectionId(collectionId);
    final body = await _get(
      _endpoint('/api/v1/collections/$collectionId/manifest'),
    );
    try {
      return LibraryCollectionManifest.fromJson(jsonDecode(utf8.decode(body)));
    } on LibraryDataSourceException {
      rethrow;
    } on Object catch (error) {
      throw LibraryDataSourceException('分卷清单格式异常：${_detail(error)}');
    }
  }

  @override
  Future<Uint8List> downloadVolume(
    String collectionId,
    LibraryVolume volume,
  ) async {
    _validateCollectionId(collectionId);
    final fileName = volume.file.split('/').last;
    if (!RegExp(r'^[a-z0-9.\-]+\.json\.zst$').hasMatch(fileName)) {
      throw const LibraryDataSourceException('分卷文件名格式异常');
    }
    return _get(
      _endpoint('/volumes/$collectionId/$fileName'),
    ).then(Uint8List.fromList);
  }

  @override
  void close() {
    if (_ownsClient) _client.close(force: true);
  }

  Uri _endpoint(String path) {
    final base = _baseUri.toString().replaceFirst(RegExp(r'/$'), '');
    return Uri.parse('$base$path');
  }

  Future<Uint8List> _get(Uri uri) async {
    try {
      final request = await _client.getUrl(uri).timeout(connectTimeout);
      final response = await request.close().timeout(connectTimeout);
      final bytes = await response
          .fold<List<int>>(<int>[], (buffer, chunk) {
            buffer.addAll(chunk);
            return buffer;
          })
          .timeout(receiveTimeout);

      if (response.statusCode < 200 || response.statusCode >= 300) {
        final body = utf8.decode(bytes, allowMalformed: true).trim();
        final detail = body.isEmpty ? '' : '：${_safeSnippet(body)}';
        throw LibraryDataSourceException(
          '数据源请求失败（${response.statusCode}）$detail',
        );
      }
      return Uint8List.fromList(bytes);
    } on LibraryDataSourceException {
      rethrow;
    } on TimeoutException {
      throw const LibraryDataSourceException('数据源响应超时，请检查网络后重试');
    } on TlsException catch (error) {
      final detail = error.message.trim();
      throw LibraryDataSourceException(
        detail.isEmpty ? '数据源 TLS 连接失败' : '数据源 TLS 连接失败：$detail',
      );
    } on SocketException catch (error) {
      final detail = error.message.trim();
      throw LibraryDataSourceException(
        detail.isEmpty ? '数据源网络不通，请检查地址与网络' : '数据源网络不通：$detail',
      );
    } on HttpException catch (error) {
      throw LibraryDataSourceException('数据源请求失败：${error.message}');
    } on Object catch (error) {
      throw LibraryDataSourceException('数据源请求失败（${error.runtimeType}）');
    }
  }

  static Uri _parseBaseUri(String raw) {
    final value = raw.trim();
    final uri = Uri.tryParse(value);
    if (uri == null ||
        uri.host.isEmpty ||
        !{'http', 'https'}.contains(uri.scheme)) {
      throw const LibraryDataSourceException('数据源地址必须是有效的 http(s) URL');
    }
    if (uri.query.isNotEmpty || uri.fragment.isNotEmpty) {
      throw const LibraryDataSourceException('数据源地址不能包含查询参数或片段');
    }
    return uri;
  }

  static void _validateCollectionId(String id) {
    if (!RegExp(r'^[a-z0-9]+$').hasMatch(id)) {
      throw const LibraryDataSourceException('作品集标识格式异常');
    }
  }

  static String _safeSnippet(String value) {
    final text = value.replaceAll(RegExp(r'\s+'), ' ');
    return text.length > 160 ? '${text.substring(0, 160)}…' : text;
  }

  static String _detail(Object error) {
    final text = error.toString().trim();
    return text.length > 160 ? '${text.substring(0, 160)}…' : text;
  }
}

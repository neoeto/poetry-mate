/// 导入书架 —— 从公开数据源下载分卷并合并到本地诗库。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/library/library_data_source.dart';
import '../../data/library/library_import_service.dart';
import '../../data/library/library_models.dart';
import '../../data/providers.dart';

class ImportLibraryPage extends ConsumerStatefulWidget {
  const ImportLibraryPage({super.key});

  @override
  ConsumerState<ImportLibraryPage> createState() => _ImportLibraryPageState();
}

class _ImportLibraryPageState extends ConsumerState<ImportLibraryPage> {
  late final TextEditingController _urlController;

  LibraryCatalog? _catalog;
  String? _catalogUrl;
  LibraryImportProgress? _progress;
  Map<String, String?> _importedVersions = {};
  Set<String> _selected = {};
  String? _error;
  bool _loadingCatalog = false;
  bool _importing = false;

  @override
  void initState() {
    super.initState();
    _urlController = TextEditingController(text: kDefaultLibraryDataSourceUrl);
    _restoreDataSource();
  }

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  Future<void> _restoreDataSource() async {
    final saved = await ref
        .read(libraryImportVersionStoreProvider)
        .dataSourceUrl();
    if (!mounted) return;
    final url = saved?.trim().isNotEmpty == true
        ? saved!.trim()
        : kDefaultLibraryDataSourceUrl;
    if (url.isEmpty) return;
    _urlController.text = url;
    await _fetchCatalog(url: url, saveUrl: false);
  }

  Future<void> _fetchCatalog({String? url, bool saveUrl = true}) async {
    if (_loadingCatalog || _importing) return;
    final value = (url ?? _urlController.text).trim();
    if (value.isEmpty) {
      setState(() => _error = '请先填写数据源地址');
      return;
    }

    setState(() {
      _loadingCatalog = true;
      _error = null;
    });
    try {
      final service = ref.read(libraryImportServiceProvider(value));
      final catalog = await service.fetchCatalog();
      if (saveUrl) {
        await ref
            .read(libraryImportVersionStoreProvider)
            .saveDataSourceUrl(value);
      }
      final versions = await Future.wait(
        catalog.collections.map(
          (collection) => ref
              .read(libraryImportVersionStoreProvider)
              .versionFor(collection.id),
        ),
      );
      if (!mounted) return;
      final nextSelected = _selected
          .where(
            (id) => catalog.collections.any(
              (item) => item.id == id && !item.builtin,
            ),
          )
          .toSet();
      if (nextSelected.isEmpty) {
        nextSelected.addAll(
          catalog.collections
              .where((collection) => !collection.builtin)
              .map((collection) => collection.id),
        );
      }
      setState(() {
        _catalog = catalog;
        _catalogUrl = value;
        _selected = nextSelected;
        _importedVersions = {
          for (var i = 0; i < catalog.collections.length; i++)
            catalog.collections[i].id: versions[i],
        };
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = _friendlyError(error));
    } finally {
      if (mounted) setState(() => _loadingCatalog = false);
    }
  }

  Future<void> _importSelected() async {
    final catalog = _catalog;
    if (catalog == null || _selected.isEmpty || _importing) return;
    final sourceUrl = _urlController.text.trim();
    if (_catalogUrl != sourceUrl) {
      setState(() => _error = '数据源地址已修改，请先重新读取目录');
      return;
    }
    final collections = [
      for (final collection in catalog.collections)
        if (_selected.contains(collection.id) && !collection.builtin)
          collection,
    ];
    if (collections.isEmpty) return;

    setState(() {
      _importing = true;
      _error = null;
      _progress = null;
    });
    try {
      final service = ref.read(libraryImportServiceProvider(sourceUrl));
      final result = await service.importCollections(
        collections,
        onProgress: (progress) {
          if (mounted) setState(() => _progress = progress);
        },
      );
      final versions = await Future.wait(
        catalog.collections.map(
          (collection) => ref
              .read(libraryImportVersionStoreProvider)
              .versionFor(collection.id),
        ),
      );
      if (!mounted) return;
      setState(() {
        _importing = false;
        _progress = null;
        _importedVersions = {
          for (var i = 0; i < catalog.collections.length; i++)
            catalog.collections[i].id: versions[i],
        };
      });
      ref.invalidate(filteredPoemsProvider);
      ref.invalidate(poemByIdProvider);
      final skipped = result.skippedCollections;
      final message = skipped == collections.length
          ? '所选作品集已经是最新版本'
          : '导入完成，共新增或更新 ${result.importedRecords} 首诗';
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(message)));
      }
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _importing = false;
        _progress = null;
        _error = _friendlyError(error);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final catalog = _catalog;
    final selectedCount = _selected.length;
    return Scaffold(
      appBar: AppBar(title: const Text('导入书架')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
        children: [
          Text('从数据源搬回整座图书馆', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 6),
          Text(
            '数据会直接下载并保存到本机，不会上传你的收藏、注本或 LLM 配置。',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 16),
          TextField(
            key: const ValueKey('library-source-url'),
            controller: _urlController,
            enabled: !_importing,
            keyboardType: TextInputType.url,
            textInputAction: TextInputAction.go,
            onSubmitted: (_) => _fetchCatalog(),
            decoration: const InputDecoration(
              labelText: '数据源地址',
              hintText: 'https://data.example.com',
              helperText: '填写 Poetry Mate 数据服务的根地址',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              onPressed: _loadingCatalog || _importing ? null : _fetchCatalog,
              icon: _loadingCatalog
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.sync),
              label: Text(_loadingCatalog ? '读取目录中…' : '读取数据源目录'),
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            _ImportError(message: _error!),
          ],
          if (catalog == null && !_loadingCatalog) ...[
            const SizedBox(height: 48),
            Icon(
              Icons.cloud_download_outlined,
              size: 56,
              color: Theme.of(context).colorScheme.outline,
            ),
            const SizedBox(height: 14),
            Text(
              '输入数据源地址后读取可用作品集',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
          if (catalog != null) ...[
            const SizedBox(height: 20),
            _CatalogHeader(catalog: catalog),
            const SizedBox(height: 8),
            for (final collection in catalog.collections)
              _CollectionTile(
                collection: collection,
                selected: _selected.contains(collection.id),
                imported: _importedVersions[collection.id] == catalog.version,
                enabled: !_importing && !collection.builtin,
                onChanged: (value) {
                  setState(() {
                    if (value) {
                      _selected.add(collection.id);
                    } else {
                      _selected.remove(collection.id);
                    }
                  });
                },
              ),
            if (_progress != null) ...[
              const SizedBox(height: 16),
              _ImportProgressView(progress: _progress!),
            ],
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _importing || selectedCount == 0
                  ? null
                  : _importSelected,
              icon: _importing
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.download),
              label: Text(_importing ? '正在导入…' : '导入已选作品集（$selectedCount）'),
            ),
          ],
        ],
      ),
    );
  }
}

class _CatalogHeader extends StatelessWidget {
  const _CatalogHeader({required this.catalog});

  final LibraryCatalog catalog;

  @override
  Widget build(BuildContext context) {
    final recordCount = catalog.collections.fold<int>(
      0,
      (sum, collection) => sum + collection.recordCount,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '数据版本 ${catalog.version}',
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: 4),
        Text(
          '${catalog.collections.length} 个作品集 · ${_formatCount(recordCount)} 首可用',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}

class _CollectionTile extends StatelessWidget {
  const _CollectionTile({
    required this.collection,
    required this.selected,
    required this.imported,
    required this.enabled,
    required this.onChanged,
  });

  final LibraryCollectionSummary collection;
  final bool selected;
  final bool imported;
  final bool enabled;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final status = collection.builtin
        ? '已内置'
        : imported
        ? '已是最新'
        : '未导入';
    return CheckboxListTile(
      value: collection.builtin ? false : selected,
      onChanged: enabled ? (value) => onChanged(value == true) : null,
      contentPadding: EdgeInsets.zero,
      title: Text(collection.title),
      subtitle: Text(
        '${_formatCount(collection.recordCount)} 首 · ${_formatBytes(collection.totalBytes)} · $status',
      ),
      secondary: Icon(
        collection.builtin
            ? Icons.check_circle_outline
            : Icons.library_books_outlined,
      ),
    );
  }
}

class _ImportProgressView extends StatelessWidget {
  const _ImportProgressView({required this.progress});

  final LibraryImportProgress progress;

  @override
  Widget build(BuildContext context) {
    final collection = progress.collection;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LinearProgressIndicator(value: progress.fraction),
        const SizedBox(height: 8),
        Text(
          '${_stageText(progress.stage)}：${collection.title} '
          '${progress.volumeCount == 0 ? '' : '${progress.volumeIndex}/${progress.volumeCount}'}',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}

class _ImportError extends StatelessWidget {
  const _ImportError({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.errorContainer,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.error_outline, color: scheme.onErrorContainer),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: scheme.onErrorContainer),
            ),
          ),
        ],
      ),
    );
  }
}

String _stageText(LibraryImportStage stage) {
  switch (stage) {
    case LibraryImportStage.fetchingManifest:
      return '读取分卷清单';
    case LibraryImportStage.downloading:
      return '下载分卷';
    case LibraryImportStage.importing:
      return '写入本地';
    case LibraryImportStage.skipped:
      return '已是最新';
    case LibraryImportStage.completed:
      return '完成';
  }
}

String _friendlyError(Object error) {
  if (error is LibraryDataSourceException) return error.message;
  if (error is LibraryImportException) return error.message;
  return '操作失败，请检查数据源地址与网络后重试';
}

String _formatCount(int value) {
  if (value < 10000) return '$value';
  final wan = value / 10000;
  return '${wan.toStringAsFixed(wan >= 100 ? 0 : 1)}万';
}

String _formatBytes(int bytes) {
  if (bytes < 1024 * 1024) return '${(bytes / 1024).ceil()} KB';
  return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
}

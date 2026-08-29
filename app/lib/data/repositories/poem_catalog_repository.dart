/// 公共诗库与扩展诗词库的统一解析和去重入口。
library;

import '../../domain/entities/extended_poem.dart';
import '../../domain/entities/poem.dart';
import 'extended_poem_repository.dart';
import 'poem_repository.dart';
import '../extended/poem_fingerprint.dart';

enum PoemCatalogKind { public, extended }

class PoemCatalogMatch {
  const PoemCatalogMatch({
    required this.poem,
    required this.kind,
    this.extended,
  });

  final Poem poem;
  final PoemCatalogKind kind;
  final ExtendedPoem? extended;

  PoemSourceInfo? get sourceInfo => extended?.sourceInfo;
}

enum ExtendedPoemSaveStatus { saved, alreadyPublic, alreadyExtended }

class ExtendedPoemSaveResult {
  const ExtendedPoemSaveResult({required this.status, required this.match});

  final ExtendedPoemSaveStatus status;
  final PoemCatalogMatch match;

  bool get saved => status == ExtendedPoemSaveStatus.saved;
}

class PoemCatalogRepository {
  PoemCatalogRepository({
    required PoemRepository publicRepository,
    required ExtendedPoemRepository extendedRepository,
  }) : _public = publicRepository,
       _extended = extendedRepository;

  final PoemRepository _public;
  final ExtendedPoemRepository _extended;

  /// 公共库优先：公共诗词 ID 就是正文内容寻址指纹。
  Future<PoemCatalogMatch?> byId(String id) async {
    final poem = await _public.byId(id);
    if (poem != null) {
      return PoemCatalogMatch(poem: poem, kind: PoemCatalogKind.public);
    }
    final extended = await _extended.byId(id);
    if (extended == null) return null;
    return PoemCatalogMatch(
      poem: extended.toPoem(),
      kind: PoemCatalogKind.extended,
      extended: extended,
    );
  }

  /// 先查公共库，再查扩展库，保证公共版本优先。
  Future<PoemCatalogMatch?> byFingerprint(String fingerprint) async {
    final publicPoem = await _public.byId(fingerprint);
    if (publicPoem != null) {
      return PoemCatalogMatch(poem: publicPoem, kind: PoemCatalogKind.public);
    }
    final extended = await _extended.byFingerprint(fingerprint);
    if (extended == null) return null;
    return PoemCatalogMatch(
      poem: extended.toPoem(),
      kind: PoemCatalogKind.extended,
      extended: extended,
    );
  }

  Future<ExtendedPoemSaveResult> saveDraft(ExtendedPoemDraft draft) async {
    final fingerprint = poemContentFingerprint(
      draft.paragraphs,
      preface: draft.preface,
    );
    final existing = await byFingerprint(fingerprint);
    if (existing != null) {
      return ExtendedPoemSaveResult(
        status: existing.kind == PoemCatalogKind.public
            ? ExtendedPoemSaveStatus.alreadyPublic
            : ExtendedPoemSaveStatus.alreadyExtended,
        match: existing,
      );
    }

    final extended = ExtendedPoem.fromDraft(
      draft: draft,
      id: extendedPoemId(fingerprint),
      fingerprint: fingerprint,
    );
    await _extended.save(extended);
    return ExtendedPoemSaveResult(
      status: ExtendedPoemSaveStatus.saved,
      match: PoemCatalogMatch(
        poem: extended.toPoem(),
        kind: PoemCatalogKind.extended,
        extended: extended,
      ),
    );
  }

  /// 返回扩展库中仍未被公共库覆盖的记录。
  Future<List<ExtendedPoem>> visibleExtendedPoems() async {
    final items = await _extended.listByRecent();
    final visible = <ExtendedPoem>[];
    for (final item in items) {
      if (await _public.byId(item.fingerprint) == null) {
        visible.add(item);
      }
    }
    return visible;
  }
}

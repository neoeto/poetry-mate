import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:poetry_mate/core/db/app_database.dart';
import 'package:poetry_mate/data/extended/poem_fingerprint.dart';
import 'package:poetry_mate/data/mappers/poem_mapper.dart';
import 'package:poetry_mate/data/repositories/extended_poem_repository.dart';
import 'package:poetry_mate/data/repositories/poem_catalog_repository.dart';
import 'package:poetry_mate/data/repositories/poem_repository.dart';
import 'package:poetry_mate/domain/entities/extended_poem.dart';

import 'fixtures.dart';

void main() {
  test('指纹兼容繁简、标点和空白，但保留段落边界', () {
    final traditional = poemContentFingerprint(['靜夜思，', '床前 明月光。']);
    final simplified = poemContentFingerprint(['静夜思', '床前明月光']);
    expect(traditional, simplified);

    expect(poemContentFingerprint(['静夜', '思床前明月光']), isNot(simplified));
  });

  test('结构化寻诗结果只接受既有作品字段', () {
    final result = AiPoemSearchResponse.tryParse('''
      {"status":"found","reply":"找到一首","title":"再别康桥",
      "author":"徐志摩","period":"近现代","genre":"modern_poem",
      "paragraphs":["轻轻的我走了，","正如我轻轻的来。"],
      "source":"《猛虎集》","source_confidence":"uncertain",
      "uncertain_fields":["source"]}
    ''');

    expect(result?.isFound, isTrue);
    expect(result?.poem?.genre, 'modern_poem');
    expect(result?.poem?.sourceUncertain, isTrue);
    expect(
      AiPoemSearchResponse.tryParse(
        '{"status":"found","title":"","genre":"shi","paragraphs":[]}',
      ),
      isNull,
    );
    expect(
      AiPoemSearchResponse.tryParse(
        '{"status":"found","is_original":true,"title":"新作",'
        '"genre":"shi","paragraphs":["文本"]}',
      )?.isRejected,
      isTrue,
    );
    expect(
      AiPoemSearchResponse.tryParse(
        '{"status":"not_found","reply":"暂无"}',
      )?.isNotFound,
      isTrue,
    );
  });

  group('扩展作品仓库与跨库去重', () {
    late AppDatabase db;
    late DriftExtendedPoemRepository extended;

    setUp(() {
      db = AppDatabase(NativeDatabase.memory());
      extended = DriftExtendedPoemRepository(db);
    });

    tearDown(() => db.close());

    ExtendedPoemDraft draft({String title = '临江仙'}) => ExtendedPoemDraft(
      title: title,
      author: '某作者',
      period: '近现代',
      genre: 'modern_poem',
      paragraphs: const ['一行文本。', '另一行文本。'],
      source: '作品集',
      sourceConfidence: ExtendedPoemConfidence.uncertain,
      uncertainFields: const {'source'},
    );

    test('保存、按 ID/指纹读取并按时间倒序列出', () async {
      final firstDraft = draft();
      final fingerprint = poemContentFingerprint(firstDraft.paragraphs);
      final poem = ExtendedPoem.fromDraft(
        draft: firstDraft,
        id: extendedPoemId(fingerprint),
        fingerprint: fingerprint,
        createdAt: DateTime(2026),
      );
      await extended.save(poem);

      expect((await extended.byId(poem.id))?.title, '临江仙');
      expect((await extended.byFingerprint(fingerprint))?.id, poem.id);
      expect((await extended.listByRecent()), hasLength(1));
    });

    test('公共库已有同正文时不创建扩展副本', () async {
      final candidate = draft();
      final fingerprint = poemContentFingerprint(candidate.paragraphs);
      final publicPoem = testPoem(
        id: fingerprint,
        title: candidate.title,
        paragraphs: candidate.paragraphs,
      );
      await db.into(db.poems).insert(PoemMapper.toCompanion(publicPoem));

      final catalog = PoemCatalogRepository(
        publicRepository: DriftPoemRepository(db),
        extendedRepository: extended,
      );
      final result = await catalog.saveDraft(candidate);

      expect(result.status, ExtendedPoemSaveStatus.alreadyPublic);
      expect(await extended.listByRecent(), isEmpty);
      expect(result.match.poem.id, fingerprint);
    });

    test('公共库后来出现同正文时不再展示扩展副本', () async {
      final candidate = draft();
      final fingerprint = poemContentFingerprint(candidate.paragraphs);
      await extended.save(
        ExtendedPoem.fromDraft(
          draft: candidate,
          id: extendedPoemId(fingerprint),
          fingerprint: fingerprint,
        ),
      );
      await db.into(db.poems).insert(
            PoemMapper.toCompanion(
              testPoem(id: fingerprint, paragraphs: candidate.paragraphs),
            ),
          );

      final catalog = PoemCatalogRepository(
        publicRepository: DriftPoemRepository(db),
        extendedRepository: extended,
      );
      expect(await catalog.visibleExtendedPoems(), isEmpty);
    });

    test('扩展库已有同正文时不重复保存', () async {
      final candidate = draft();
      final fingerprint = poemContentFingerprint(candidate.paragraphs);
      await extended.save(
        ExtendedPoem.fromDraft(
          draft: candidate,
          id: extendedPoemId(fingerprint),
          fingerprint: fingerprint,
        ),
      );

      final catalog = PoemCatalogRepository(
        publicRepository: DriftPoemRepository(db),
        extendedRepository: extended,
      );
      final result = await catalog.saveDraft(draft(title: '同正文异标题'));

      expect(result.status, ExtendedPoemSaveStatus.alreadyExtended);
      expect(await extended.listByRecent(), hasLength(1));
    });
  });
}

/// AI 寻诗返回的外部作品与扩展诗词库实体。
///
/// 外部作品不是 AI 原创内容；其作者、时期、出处和文本版本可能需要核验，
/// 因此模型保留字段级不确定性，阅读层用安全的展示值兜底。
library;

import 'annotations.dart' as annotation;
import 'poem.dart';

class ExtendedPoemConfidence {
  const ExtendedPoemConfidence._();

  static const known = 'known';
  static const uncertain = 'uncertain';
  static const unknown = 'unknown';

  static bool isValid(String value) => switch (value) {
    known || uncertain || unknown => true,
    _ => false,
  };

  static String label(String value) => switch (value) {
    known => '来源信息来自 AI 记忆',
    uncertain => '信息待核，仅供参考',
    _ => '来源不详，仅供参考',
  };
}

/// AI 寻诗的结构化候选，不含本地 ID 和创建时间。
class ExtendedPoemDraft {
  const ExtendedPoemDraft({
    required this.title,
    required this.genre,
    required this.paragraphs,
    this.author,
    this.period,
    this.preface,
    this.rhythmic,
    this.source,
    this.sourceConfidence = ExtendedPoemConfidence.unknown,
    this.uncertainFields = const {},
    this.recommendation = '',
  });

  final String title;
  final String? author;
  final String? period;
  final String genre;
  final List<String> paragraphs;
  final String? preface;
  final String? rhythmic;
  final String? source;
  final String sourceConfidence;
  final Set<String> uncertainFields;
  final String recommendation;

  bool get authorUncertain =>
      author == null || uncertainFields.contains('author');
  bool get periodUncertain =>
      period == null || uncertainFields.contains('period');
  bool get sourceUncertain =>
      source == null ||
      uncertainFields.contains('source') ||
      sourceConfidence != ExtendedPoemConfidence.known;
  bool get textUncertain => uncertainFields.contains('text');

  Map<String, dynamic> toJson() => {
    'status': 'found',
    'title': title,
    'author': author,
    'period': period,
    'genre': genre,
    'paragraphs': paragraphs,
    'preface': preface,
    'rhythmic': rhythmic,
    'source': source,
    'source_confidence': sourceConfidence,
    'uncertain_fields': uncertainFields.toList()..sort(),
    'recommendation': recommendation,
  };

  /// 从 AI 的 JSON 结果读取候选。格式、状态或正文不合法时返回 null。
  static ExtendedPoemDraft? fromJson(Map<String, dynamic> json) {
    final status = json['status'];
    if (status != 'found') return null;

    final title = _stringOrNull(json['title'] ?? json['name']);
    final genre = _stringOrNull(json['genre'] ?? json['type']);
    final rawParagraphs = json['paragraphs'] ?? json['lines'] ?? json['body'];
    if (title == null || genre == null) return null;

    final paragraphs = _parseParagraphs(rawParagraphs);
    if (paragraphs == null || paragraphs.isEmpty) return null;

    final rawConfidence = _stringOrNull(json['source_confidence']);
    final sourceConfidence =
        rawConfidence != null && ExtendedPoemConfidence.isValid(rawConfidence)
        ? rawConfidence
        : ExtendedPoemConfidence.unknown;
    final uncertainFields = <String>{
      if (json['author_uncertain'] == true) 'author',
      if (json['period_uncertain'] == true) 'period',
      if (json['source_uncertain'] == true) 'source',
      if (json['text_uncertain'] == true) 'text',
    };
    final rawUncertain = json['uncertain_fields'];
    if (rawUncertain is List) {
      for (final item in rawUncertain) {
        if (item is String && item.trim().isNotEmpty) {
          uncertainFields.add(item.trim());
        }
      }
    }
    if (sourceConfidence != ExtendedPoemConfidence.known) {
      uncertainFields.add('source');
    }

    final original =
        json['is_original'] == true ||
        json['original'] == true ||
        json['status'] == 'original';
    if (original) return null;

    return ExtendedPoemDraft(
      title: title,
      author: _stringOrNull(json['author']),
      period: _stringOrNull(json['period'] ?? json['dynasty']),
      genre: genre,
      paragraphs: paragraphs,
      preface: _stringOrNull(json['preface']),
      rhythmic: _stringOrNull(json['rhythmic']),
      source: _stringOrNull(json['source'] ?? json['origin']),
      sourceConfidence: sourceConfidence,
      uncertainFields: Set.unmodifiable(uncertainFields),
      recommendation:
          _stringOrNull(json['recommendation'] ?? json['reason']) ?? '',
    );
  }

  static String? _stringOrNull(dynamic value) {
    if (value is! String) return null;
    final text = value.trim();
    return text.isEmpty ? null : text;
  }

  /// 将模型可能返回的整段正文规范化为“一句一项”。
  ///
  /// 优先按换行拆分；如果模型把多句合并到同一个数组项（甚至直接返回
  /// 一个字符串），再按常见中英文句末标点拆分，并保留标点。
  static List<String>? _parseParagraphs(dynamic raw) {
    final items = <String>[];
    if (raw is String) {
      items.add(raw);
    } else if (raw is List) {
      for (final item in raw) {
        if (item is! String || item.trim().isEmpty) return null;
        items.add(item);
      }
    } else {
      return null;
    }

    final paragraphs = <String>[];
    for (final item in items) {
      paragraphs.addAll(_splitSentences(item));
    }
    return paragraphs.isEmpty ? null : paragraphs;
  }

  static List<String> _splitSentences(String value) {
    final result = <String>[];
    final lines = value.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
    for (final line in lines.split('\n')) {
      final runes = line.trim().runes.toList();
      if (runes.isEmpty) continue;

      var current = StringBuffer();
      for (var index = 0; index < runes.length; index++) {
        final character = String.fromCharCode(runes[index]);
        current.write(character);
        if (!'，。！？；,!?;'.contains(character)) continue;

        // 标点后的引号/括号属于当前句，不单独形成一行。
        while (index + 1 < runes.length &&
            '”’）》】〕)]}'.contains(String.fromCharCode(runes[index + 1]))) {
          index++;
          current.write(String.fromCharCode(runes[index]));
        }
        result.add(current.toString().trim());
        current = StringBuffer();
      }
      final tail = current.toString().trim();
      if (tail.isNotEmpty) result.add(tail);
    }
    return result;
  }
}

/// 一轮 AI 寻诗结果。
class AiPoemSearchResponse {
  const AiPoemSearchResponse({
    required this.status,
    this.reply = '',
    this.poem,
    this.message = '',
  });

  static const found = 'found';
  static const notFound = 'not_found';
  static const rejected = 'rejected';

  final String status;
  final String reply;
  final ExtendedPoemDraft? poem;
  final String message;

  bool get isFound => status == found && poem != null;
  bool get isNotFound => status == notFound;
  bool get isRejected => status == rejected;

  Map<String, dynamic> toJson() => {
    'status': status,
    'reply': reply,
    if (poem != null) ...poem!.toJson(),
    'message': message,
  };

  static AiPoemSearchResponse? tryParse(String raw) {
    final decoded = annotation.tryDecodeJsonObject(raw);
    if (decoded == null) return null;
    final status = decoded['status'];
    if (status is! String || !{found, notFound, rejected}.contains(status)) {
      return null;
    }
    final reply = decoded['reply'] is String
        ? (decoded['reply'] as String).trim()
        : '';
    final message = decoded['message'] is String
        ? (decoded['message'] as String).trim()
        : '';
    if (status == found) {
      if (decoded['is_original'] == true || decoded['original'] == true) {
        return AiPoemSearchResponse(
          status: rejected,
          reply: reply,
          message: '模型返回的内容无法确认是既有作品',
        );
      }
      final poem = ExtendedPoemDraft.fromJson(decoded);
      if (poem == null) return null;
      return AiPoemSearchResponse(
        status: found,
        reply: reply,
        poem: poem,
        message: message,
      );
    }
    return AiPoemSearchResponse(status: status, reply: reply, message: message);
  }
}

/// 已保存的扩展作品。
class ExtendedPoem {
  const ExtendedPoem({
    required this.id,
    required this.fingerprint,
    required this.title,
    required this.genre,
    required this.paragraphs,
    required this.createdAt,
    this.author,
    this.period,
    this.preface,
    this.rhythmic,
    this.source,
    this.sourceConfidence = ExtendedPoemConfidence.unknown,
    this.uncertainFields = const {},
    this.recommendation = '',
  });

  final String id;
  final String fingerprint;
  final String title;
  final String? author;
  final String? period;
  final String genre;
  final List<String> paragraphs;
  final String? preface;
  final String? rhythmic;
  final String? source;
  final String sourceConfidence;
  final Set<String> uncertainFields;
  final String recommendation;
  final DateTime createdAt;

  String get authorLabel => author ?? '作者不详';
  String get periodLabel => period ?? '时期不详';
  String get displayTitle => title.isEmpty ? '未命名作品' : title;

  ExtendedPoemDraft get draft => ExtendedPoemDraft(
    title: title,
    author: author,
    period: period,
    genre: genre,
    paragraphs: paragraphs,
    preface: preface,
    rhythmic: rhythmic,
    source: source,
    sourceConfidence: sourceConfidence,
    uncertainFields: uncertainFields,
    recommendation: recommendation,
  );

  /// 映射为现有阅读器使用的 Poem；外部来源元数据通过 [sourceInfo] 保留。
  Poem toPoem() => Poem(
    id: id,
    author: authorLabel,
    title: title,
    dynasty: periodLabel,
    type: genre,
    paragraphs: paragraphs,
    preface: preface,
    rhythmic: rhythmic,
    popularity: null,
    rawText: paragraphs,
    tags: null,
    sourceCollection: 'ai_extended',
  );

  PoemSourceInfo get sourceInfo {
    final fields = {...uncertainFields};
    if (author == null) fields.add('author');
    if (period == null) fields.add('period');
    if (source == null) fields.add('source');
    return PoemSourceInfo(
      label: 'AI 补充作品',
      source: source,
      confidence: sourceConfidence,
      uncertainFields: Set.unmodifiable(fields),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'fingerprint': fingerprint,
    'title': title,
    'author': author,
    'period': period,
    'genre': genre,
    'paragraphs': paragraphs,
    'preface': preface,
    'rhythmic': rhythmic,
    'source': source,
    'source_confidence': sourceConfidence,
    'uncertain_fields': uncertainFields.toList()..sort(),
    'recommendation': recommendation,
    'created_at': createdAt.millisecondsSinceEpoch,
  };

  static ExtendedPoem fromDraft({
    required ExtendedPoemDraft draft,
    required String id,
    required String fingerprint,
    DateTime? createdAt,
  }) => ExtendedPoem(
    id: id,
    fingerprint: fingerprint,
    title: draft.title,
    author: draft.author,
    period: draft.period,
    genre: draft.genre,
    paragraphs: List.unmodifiable(draft.paragraphs),
    preface: draft.preface,
    rhythmic: draft.rhythmic,
    source: draft.source,
    sourceConfidence: draft.sourceConfidence,
    uncertainFields: draft.uncertainFields,
    recommendation: draft.recommendation,
    createdAt: createdAt ?? DateTime.now(),
  );

  static ExtendedPoem fromJson(Map<String, dynamic> json) {
    final draft = ExtendedPoemDraft.fromJson({...json, 'status': 'found'});
    if (draft == null) {
      throw const FormatException('扩展作品内容格式异常');
    }
    final id = json['id'];
    final fingerprint = json['fingerprint'];
    final createdAt = json['created_at'];
    if (id is! String || fingerprint is! String || createdAt is! num) {
      throw const FormatException('扩展作品身份字段缺失');
    }
    return fromDraft(
      draft: draft,
      id: id,
      fingerprint: fingerprint,
      createdAt: DateTime.fromMillisecondsSinceEpoch(createdAt.toInt()),
    );
  }
}

String extendedPoemId(String fingerprint) => 'ext_$fingerprint';

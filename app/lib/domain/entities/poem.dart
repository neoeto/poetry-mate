/// 诗词实体(领域层) —— 纯净值对象,不依赖任何框架。
///
/// 字段语义与 ETL 统一 schema 对齐(见 openspec build-data-pipeline/specs/data-etl-pipeline):
/// - [paragraphs] 永远是简体阅读文本;[rawText] 是转换前原文留档,两者平行等长;
/// - [id] 由数据包下发(内容寻址),APP 侧从不计算。

library;

import 'dart:convert';

class Poem {
  final String id;
  final String author;
  final String? title;
  final String dynasty;
  final String type;
  final List<String> paragraphs;
  final String? preface;
  final String? rhythmic;
  final double? popularity;
  final List<String> rawText;
  final List<String>? tags;
  final String sourceCollection;

  const Poem({
    required this.id,
    required this.author,
    required this.title,
    required this.dynasty,
    required this.type,
    required this.paragraphs,
    required this.preface,
    required this.rhythmic,
    required this.popularity,
    required this.rawText,
    required this.tags,
    required this.sourceCollection,
  });

  /// 展示用标题: 词类无题时回退到「词牌·作者」形态的词牌部分。
  String get displayTitle => title ?? rhythmic ?? '';

  /// 是否为词(影响排版细节)
  bool get isCi => type == 'ci';

  /// 是否为 AI 补充的扩展作品。
  bool get isExtended => sourceCollection == 'ai_extended';

  Map<String, dynamic> toJson() => {
    'id': id,
    'author': author,
    'title': title,
    'dynasty': dynasty,
    'type': type,
    'paragraphs': paragraphs,
    'preface': preface,
    'rhythmic': rhythmic,
    'popularity': popularity,
    'raw_text': rawText,
    'tags': tags,
    'source_collection': sourceCollection,
  };

  /// 从 ETL 统一 schema 的 JSON 记录构造(种子集装载路径)。
  factory Poem.fromPackageJson(Map<String, dynamic> json) {
    List<String>? optList(dynamic v) =>
        v == null ? null : (v as List).cast<String>();
    return Poem(
      id: json['id'] as String,
      author: json['author'] as String,
      title: json['title'] as String?,
      dynasty: json['dynasty'] as String,
      type: json['type'] as String,
      paragraphs: (json['paragraphs'] as List).cast<String>(),
      preface: json['preface'] as String?,
      rhythmic: json['rhythmic'] as String?,
      popularity: (json['popularity'] as num?)?.toDouble(),
      rawText: (json['raw_text'] as List).cast<String>(),
      tags: optList(json['tags']),
      sourceCollection: json['source_collection'] as String,
    );
  }

  /// 正文拼接(供全文检索与展示兜底)
  String get bodyText => paragraphs.join();

  @override
  String toString() => 'Poem($id, $author《$displayTitle》)';
}

/// JSON 数组列的编解码工具(与 mapper 共用)。
/// 阅读页显示的作品来源信息。
///
/// 公共诗库不需要传入此对象；扩展作品用它展示来源和待核字段，避免把
/// AI 返回的元数据当成已经核验的历史事实。
class PoemSourceInfo {
  const PoemSourceInfo({
    required this.label,
    this.source,
    this.confidence = 'unknown',
    this.uncertainFields = const {},
  });

  final String label;
  final String? source;
  final String confidence;
  final Set<String> uncertainFields;

  bool get isUncertain => confidence != 'known' || uncertainFields.isNotEmpty;

  bool isFieldUncertain(String field) =>
      uncertainFields.contains(field) || confidence != 'known';
}

class JsonListCodec {
  const JsonListCodec._();

  static String encode(List<String> list) => jsonEncode(list);

  static List<String> decode(String? text) =>
      text == null ? [] : (jsonDecode(text) as List).cast<String>();

  static List<String>? decodeOrNull(String? text) =>
      text == null ? null : decode(text);
}

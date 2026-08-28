/// 赏析领域模型 —— LLM 结构化输出的强类型封装。
///
/// 解析原则(design D6): 宽容读取(缺字段给空默认),但绝不编造;
/// 代码围栏(```json … ```)自动剥离 —— 部分供应商无视 json_object 指令。
library;

import 'dart:convert';

/// 剥离 markdown 代码围栏,提取首个 JSON 对象文本。
String stripJsonFences(String raw) {
  var text = raw.trim();
  final fenceStart = text.indexOf('```');
  if (fenceStart != -1) {
    // 去掉起始行 ```json / ```
    var body = text.substring(fenceStart);
    if (body.startsWith('```')) {
      final firstNewline = body.indexOf('\n');
      body = firstNewline == -1 ? '' : body.substring(firstNewline + 1);
    }
    final fenceEnd = body.lastIndexOf('```');
    if (fenceEnd != -1) body = body.substring(0, fenceEnd);
    text = body.trim();
    return text;
  }
  // 无围栏: 若首尾不是对象,截取第一个 { 到最后一个 }
  final first = text.indexOf('{');
  final last = text.lastIndexOf('}');
  if (first != -1 && last > first) {
    return text.substring(first, last + 1);
  }
  return text;
}

Map<String, dynamic>? tryDecodeJsonObject(String raw) {
  final candidate = stripJsonFences(raw);
  try {
    final decoded = jsonDecode(candidate);
    return decoded is Map<String, dynamic> ? decoded : null;
  } on FormatException {
    return null;
  }
}

// ---------------------------------------------------------------------------
// L1 逐句注
// ---------------------------------------------------------------------------

class KeywordNote {
  const KeywordNote({
    required this.term,
    required this.explain,
    this.pinyin = '',
  });

  final String term;
  final String explain;
  final String pinyin;

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{'term': term, 'explain': explain};
    if (pinyin.trim().isNotEmpty) json['pinyin'] = pinyin.trim();
    return json;
  }
}

/// 词语解释来源。
class WordNoteSource {
  const WordNoteSource._();

  /// L2 整篇赏析主动挑出的词语。
  static const automatic = 'automatic';

  /// 用户在原文中选择后生成的词语解释。
  static const selected = 'selected';
}

/// 诗词中的词语解释。
///
/// 自动赏析只需要 [term] / [explain] / [lineIndex]；用户选词解释还会
/// 保存精确的 UTF-16 选区 [start] / [end]，避免同一个词在同一句出现
/// 多次时无法区分。所有位置都以 APP 当前保存的原文为准。
class WordNote {
  const WordNote({
    required this.term,
    required this.explain,
    this.pinyin = '',
    this.lineIndex,
    this.start,
    this.end,
    this.source = WordNoteSource.automatic,
    this.uncertain = false,
  });

  final String term;
  final String explain;
  final String pinyin;
  final int? lineIndex;
  final int? start;
  final int? end;
  final String source;
  final bool uncertain;

  bool get isUserSelected => source == WordNoteSource.selected;

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{'term': term, 'explain': explain};
    if (pinyin.trim().isNotEmpty) json['pinyin'] = pinyin.trim();
    if (lineIndex != null) json['line_index'] = lineIndex;
    if (start != null) json['start'] = start;
    if (end != null) json['end'] = end;
    if (source != WordNoteSource.automatic) json['source'] = source;
    if (uncertain) json['uncertain'] = true;
    return json;
  }

  static WordNote? tryParse(String raw) {
    final decoded = tryDecodeJsonObject(raw);
    return decoded == null ? null : fromJson(decoded);
  }

  WordNote copyWith({
    String? term,
    String? explain,
    String? pinyin,
    int? lineIndex,
    int? start,
    int? end,
    String? source,
    bool? uncertain,
  }) => WordNote(
    term: term ?? this.term,
    explain: explain ?? this.explain,
    pinyin: pinyin ?? this.pinyin,
    lineIndex: lineIndex ?? this.lineIndex,
    start: start ?? this.start,
    end: end ?? this.end,
    source: source ?? this.source,
    uncertain: uncertain ?? this.uncertain,
  );

  static WordNote? fromJson(dynamic value) {
    if (value is! Map) return null;
    final rawTerm = value['term'];
    final rawExplain = value['explain'];
    if (rawTerm is! String || rawExplain is! String) return null;
    final term = rawTerm.trim();
    final explain = rawExplain.trim();
    if (term.isEmpty || explain.isEmpty) return null;
    final rawPinyin = value['pinyin'] ?? value['pronunciation'];
    final pinyin = rawPinyin is String ? rawPinyin.trim() : '';

    int? nonNegativeInt(dynamic raw) {
      return switch (raw) {
        int value when value >= 0 => value,
        num value when value >= 0 && value == value.truncateToDouble() =>
          value.toInt(),
        String value => switch (int.tryParse(value)) {
          final parsed? when parsed >= 0 => parsed,
          _ => null,
        },
        _ => null,
      };
    }

    final lineIndex = nonNegativeInt(value['line_index'] ?? value['lineIndex']);
    final start = nonNegativeInt(value['start']);
    final end = nonNegativeInt(value['end']);
    final rawSource = value['source'] ?? value['origin'];
    final source = rawSource is String && rawSource == WordNoteSource.selected
        ? WordNoteSource.selected
        : WordNoteSource.automatic;
    return WordNote(
      term: term,
      explain: explain,
      pinyin: pinyin,
      lineIndex: lineIndex,
      start: start,
      end: end,
      source: source,
      uncertain: value['uncertain'] == true,
    );
  }
}

/// 用户选择的一段正文位置，用于生成稳定的本地注本条目。
class SelectedWordPosition {
  const SelectedWordPosition({
    required this.lineIndex,
    required this.start,
    required this.end,
    required this.term,
  });

  final int lineIndex;
  final int start;
  final int end;
  final String term;

  String get target => selectedWordNoteTarget(
    lineIndex: lineIndex,
    start: start,
    end: end,
    term: term,
  );
}

String selectedWordNoteTarget({
  required int lineIndex,
  required int start,
  required int end,
  required String term,
}) => '$lineIndex:$start:$end:${term.trim()}';

class LineNoteContent {
  const LineNoteContent({required this.translation, required this.notes});

  /// 白话直译
  final String translation;

  /// 关键词注(可为空数组)
  final List<KeywordNote> notes;

  Map<String, dynamic> toJson() => {
    'translation': translation,
    'notes': [for (final n in notes) n.toJson()],
  };

  static LineNoteContent fromJson(Map<String, dynamic> json) {
    String translationOf(dynamic v) => v is String ? v.trim() : '';
    final rawNotes = json['notes'];
    final notes = <KeywordNote>[];
    if (rawNotes is List) {
      for (final item in rawNotes) {
        if (item is! Map) continue;
        final term = item['term'];
        final explain = item['explain'];
        final rawPinyin = item['pinyin'] ?? item['pronunciation'];
        final pinyin = rawPinyin is String ? rawPinyin.trim() : '';
        if (term is String && explain is String && explain.isNotEmpty) {
          notes.add(
            KeywordNote(
              term: term.trim(),
              explain: explain.trim(),
              pinyin: pinyin,
            ),
          );
        } else if (term is String && term.isNotEmpty) {
          notes.add(
            KeywordNote(term: term.trim(), explain: '', pinyin: pinyin),
          );
        }
      }
    }
    return LineNoteContent(
      translation: translationOf(json['translation']),
      notes: notes,
    );
  }

  /// 从模型原始输出解析;失败返回 null(调用方决定重试/降级)
  static LineNoteContent? tryParse(String raw) {
    final decoded = tryDecodeJsonObject(raw);
    if (decoded == null) return null;
    return LineNoteContent.fromJson(decoded);
  }

  LineNoteContent copyWith({String? translation, List<KeywordNote>? notes}) =>
      LineNoteContent(
        translation: translation ?? this.translation,
        notes: notes ?? this.notes,
      );
}

// ---------------------------------------------------------------------------
// L2 整篇赏析
// ---------------------------------------------------------------------------

class EssayCraftItem {
  const EssayCraftItem({required this.point, required this.detail});

  final String point;
  final String detail;

  Map<String, dynamic> toJson() => {'point': point, 'detail': detail};
}

class EssayBackground {
  const EssayBackground({required this.text, required this.uncertain});

  final String text;
  final bool uncertain;

  Map<String, dynamic> toJson() => {'text': text, 'uncertain': uncertain};
}

class EssayContent {
  const EssayContent({
    required this.summary,
    required this.craft,
    required this.mood,
    this.emotion = '',
    required this.background,
    this.wordNotes = const [],
  });

  final String summary;
  final List<EssayCraftItem> craft;

  /// 意境描述(兼容旧缓存中的 mood 字段)
  final String mood;

  /// 情感判断;旧版本缓存缺失时为空
  final String emotion;
  final EssayBackground background;

  /// 赏析中挑出的词语解释，用于在原文页生成可点击的下划线提示。
  final List<WordNote> wordNotes;

  Map<String, dynamic> toJson() => {
    'summary': summary,
    'craft': [for (final c in craft) c.toJson()],
    'mood': mood,
    'emotion': emotion,
    'background': background.toJson(),
    'word_notes': [for (final note in wordNotes) note.toJson()],
  };

  static EssayContent fromJson(Map<String, dynamic> json) {
    List<EssayCraftItem> parseCraft(dynamic v) {
      final items = <EssayCraftItem>[];
      if (v is List) {
        for (final item in v) {
          if (item is! Map) continue;
          items.add(
            EssayCraftItem(
              point: (item['point'] ?? '').toString(),
              detail: (item['detail'] ?? '').toString(),
            ),
          );
        }
      }
      return items;
    }

    EssayBackground parseBackground(dynamic v) {
      if (v is Map) {
        return EssayBackground(
          text: (v['text'] ?? '').toString(),
          uncertain: v['uncertain'] == true,
        );
      }
      if (v is String) {
        // 兼容: 模型直接给了字符串背景 → 视为不确定
        return EssayBackground(text: v, uncertain: true);
      }
      return const EssayBackground(text: '', uncertain: true);
    }

    List<WordNote> parseWordNotes(dynamic v) {
      if (v is! List) return [];
      return [for (final item in v) ?WordNote.fromJson(item)];
    }

    return EssayContent(
      summary: (json['summary'] ?? '').toString(),
      craft: parseCraft(json['craft']),
      mood: (json['mood'] ?? '').toString(),
      emotion: (json['emotion'] ?? '').toString(),
      background: parseBackground(json['background']),
      wordNotes: parseWordNotes(json['word_notes'] ?? json['wordNotes']),
    );
  }

  static EssayContent? tryParse(String raw) {
    final decoded = tryDecodeJsonObject(raw);
    if (decoded == null) return null;
    return EssayContent.fromJson(decoded);
  }

  EssayContent copyWith({
    String? summary,
    List<EssayCraftItem>? craft,
    String? mood,
    String? emotion,
    EssayBackground? background,
    List<WordNote>? wordNotes,
  }) => EssayContent(
    summary: summary ?? this.summary,
    craft: craft ?? this.craft,
    mood: mood ?? this.mood,
    emotion: emotion ?? this.emotion,
    background: background ?? this.background,
    wordNotes: wordNotes ?? this.wordNotes,
  );
}

// ---------------------------------------------------------------------------
// L3 追问对话
// ---------------------------------------------------------------------------

/// 一次对话增量。fallback 需要替换已经显示的半截流，而不是重复追加。
class ChatDelta {
  const ChatDelta(this.text, {this.replace = false});

  final String text;
  final bool replace;
}

class ChatTurnContent {
  const ChatTurnContent({required this.question, required this.answer});

  final String question;
  final String answer;

  Map<String, dynamic> toJson() => {'question': question, 'answer': answer};

  static ChatTurnContent fromJson(Map<String, dynamic> json) => ChatTurnContent(
    question: (json['question'] ?? '').toString(),
    answer: (json['answer'] ?? '').toString(),
  );

  static ChatTurnContent? tryParse(String raw) {
    final decoded = tryDecodeJsonObject(raw);
    return decoded == null ? null : fromJson(decoded);
  }
}

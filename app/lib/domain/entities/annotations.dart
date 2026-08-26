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
  const KeywordNote({required this.term, required this.explain});

  final String term;
  final String explain;

  Map<String, dynamic> toJson() => {'term': term, 'explain': explain};
}

class LineNoteContent {
  const LineNoteContent({
    required this.translation,
    required this.notes,
  });

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
        if (term is String && explain is String && explain.isNotEmpty) {
          notes.add(KeywordNote(term: term.trim(), explain: explain.trim()));
        } else if (term is String && term.isNotEmpty) {
          notes.add(KeywordNote(term: term.trim(), explain: ''));
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
  });

  final String summary;
  final List<EssayCraftItem> craft;
  /// 意境描述(兼容旧缓存中的 mood 字段)
  final String mood;

  /// 情感判断;旧版本缓存缺失时为空
  final String emotion;
  final EssayBackground background;

  Map<String, dynamic> toJson() => {
        'summary': summary,
        'craft': [for (final c in craft) c.toJson()],
        'mood': mood,
        'emotion': emotion,
        'background': background.toJson(),
      };

  static EssayContent fromJson(Map<String, dynamic> json) {
    List<EssayCraftItem> parseCraft(dynamic v) {
      final items = <EssayCraftItem>[];
      if (v is List) {
        for (final item in v) {
          if (item is! Map) continue;
          items.add(EssayCraftItem(
            point: (item['point'] ?? '').toString(),
            detail: (item['detail'] ?? '').toString(),
          ));
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

    return EssayContent(
      summary: (json['summary'] ?? '').toString(),
      craft: parseCraft(json['craft']),
      mood: (json['mood'] ?? '').toString(),
      emotion: (json['emotion'] ?? '').toString(),
      background: parseBackground(json['background']),
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
  }) =>
      EssayContent(
        summary: summary ?? this.summary,
        craft: craft ?? this.craft,
        mood: mood ?? this.mood,
        emotion: emotion ?? this.emotion,
        background: background ?? this.background,
      );
}

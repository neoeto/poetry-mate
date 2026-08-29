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
// 流式部分 JSON 解析
// ---------------------------------------------------------------------------

/// 不完整 JSON 的字段级快照 —— 流式生成期间渐进渲染的依据。
class PartialJsonSnapshot {
  const PartialJsonSnapshot({
    required this.closedValues,
    required this.openArrayItems,
    required this.openKeys,
  });

  /// 已完整闭合的顶层字段值
  final Map<String, dynamic> closedValues;

  /// 仍在生成中的数组: 已闭合元素的按序快照(未闭合的尾元素舍弃)
  final Map<String, List<dynamic>> openArrayItems;

  /// 已出现但尚未闭合的顶层字段
  final Set<String> openKeys;

  bool get isEmpty =>
      closedValues.isEmpty && openArrayItems.isEmpty && openKeys.isEmpty;
}

/// 把不完整的 JSON 前缀修复为可解析快照 —— 流式渐进渲染专用。
///
/// 原则: 只产出**已完整闭合**的字段与数组元素，绝不产出半截字符串值
/// (否则 UI 会闪现残缺文本)。自动容忍 ``` 围栏或说明文字前导。
/// 输入连一个对象起始都没有时返回 null。
PartialJsonSnapshot? tryDecodePartialJsonObject(String raw) {
  final start = raw.indexOf('{');
  if (start == -1) return null;
  final scanner = _PartialJsonScanner(raw, start);
  final value = scanner.parseValue();
  if (value.value is! Map) return null;
  return PartialJsonSnapshot(
    closedValues: scanner.closedValues,
    openArrayItems: scanner.openArrayItems,
    openKeys: scanner.openKeys,
  );
}

class _ScanValue {
  const _ScanValue(this.value, this.complete);

  final dynamic value;
  final bool complete;

  static const _ScanValue truncated = _ScanValue(null, false);
}

/// 单遍字符扫描器: 跟踪字符串/转义/括号深度，记录顶层字段的闭合状态。
class _PartialJsonScanner {
  _PartialJsonScanner(this.text, int start) : i = start;

  final String text;
  int i;

  /// 嵌套深度: 1 = 根对象的直接字段(只有这一层才记录到顶层快照)
  int _depth = 0;

  final Map<String, dynamic> closedValues = {};
  final Map<String, List<dynamic>> openArrayItems = {};
  final Set<String> openKeys = {};

  void _skipWs() {
    while (i < text.length && _isWs(text.codeUnitAt(i))) {
      i++;
    }
  }

  static bool _isWs(int codeUnit) =>
      codeUnit == 0x20 ||
      codeUnit == 0x09 ||
      codeUnit == 0x0a ||
      codeUnit == 0x0d;

  bool _peekChar(String char) => i < text.length && text[i] == char;

  /// 解析一个值;对象/数组即便未闭合也返回已收集的内容(complete=false)。
  _ScanValue parseValue() {
    _skipWs();
    if (i >= text.length) return _ScanValue.truncated;
    final ch = text[i];
    if (ch == '"') return _parseString();
    if (ch == '{') return _parseObject();
    if (ch == '[') return _parseArray();
    return _parsePrimitive();
  }

  /// 字符串。截断时返回 complete=false 与已积累的部分(调用方丢弃)。
  _ScanValue _parseString() {
    i++; // 开引号
    final buffer = StringBuffer();
    while (i < text.length) {
      final ch = text[i];
      if (ch == '"') {
        i++;
        return _ScanValue(buffer.toString(), true);
      }
      if (ch == r'\') {
        i++;
        if (i >= text.length) return _ScanValue(buffer.toString(), false);
        final esc = text[i];
        switch (esc) {
          case '"' || r'\' || '/':
            buffer.write(esc);
            i++;
          case 'b':
            buffer.write('\b');
            i++;
          case 'f':
            buffer.write('\f');
            i++;
          case 'n':
            buffer.write('\n');
            i++;
          case 'r':
            buffer.write('\r');
            i++;
          case 't':
            buffer.write('\t');
            i++;
          case 'u':
            if (i + 5 > text.length) {
              return _ScanValue(buffer.toString(), false);
            }
            final hex = text.substring(i + 1, i + 5);
            final code = int.tryParse(hex, radix: 16);
            if (code == null) return _ScanValue(buffer.toString(), false);
            buffer.writeCharCode(code);
            i += 5;
          default:
            // 非法转义 → 视为截断,等待下一帧重试
            return _ScanValue(buffer.toString(), false);
        }
      } else {
        buffer.write(ch);
        i++;
      }
    }
    return _ScanValue(buffer.toString(), false);
  }

  _ScanValue _parseObject() {
    _depth++;
    final local = <String, dynamic>{};
    i++; // '{'
    while (true) {
      _skipWs();
      if (i >= text.length) {
        _depth--;
        return _ScanValue(local, false);
      }
      if (_peekChar('}')) {
        i++;
        _depth--;
        return _ScanValue(local, true);
      }
      if (_peekChar(',')) {
        i++;
        continue;
      }
      final key = _parseString();
      if (!key.complete) {
        _depth--;
        return _ScanValue(local, false);
      }
      _skipWs();
      final k = key.value as String;
      if (!_peekChar(':')) {
        if (_depth == 1) openKeys.add(k);
        _depth--;
        return _ScanValue(local, false);
      }
      i++;
      final value = parseValue();
      if (value.complete) {
        local[k] = value.value;
        if (_depth == 1) closedValues[k] = value.value;
      } else {
        // 数组截断时,已闭合元素仍有展示价值(仅根层字段)
        if (_depth == 1) {
          openKeys.add(k);
          if (value.value is List) {
            final items = value.value as List;
            if (items.isNotEmpty) openArrayItems[k] = items;
          }
        }
        _depth--;
        return _ScanValue(local, false);
      }
    }
  }

  _ScanValue _parseArray() {
    _depth++;
    final items = <dynamic>[];
    i++; // '['
    while (true) {
      _skipWs();
      if (i >= text.length) {
        _depth--;
        return _ScanValue(items, false);
      }
      if (_peekChar(']')) {
        i++;
        _depth--;
        return _ScanValue(items, true);
      }
      if (_peekChar(',')) {
        i++;
        continue;
      }
      final element = parseValue();
      if (!element.complete) {
        _depth--;
        return _ScanValue(items, false);
      }
      items.add(element.value);
    }
  }

  /// true/false/null/数字。只有遇到终止符(而不是 EOF)才算闭合——
  /// 例如 `12` 可能是 `123` 的前缀。
  _ScanValue _parsePrimitive() {
    final start = i;
    while (i < text.length) {
      final cu = text.codeUnitAt(i);
      if (_isWs(cu) || text[i] == ',' || text[i] == '}' || text[i] == ']') {
        break;
      }
      i++;
    }
    if (i >= text.length) return _ScanValue.truncated; // EOF,可能是前缀
    final literal = text.substring(start, i);
    if (literal == 'true') return const _ScanValue(true, true);
    if (literal == 'false') return const _ScanValue(false, true);
    if (literal == 'null') return const _ScanValue(null, true);
    final number = num.tryParse(literal);
    if (number != null) return _ScanValue(number, true);
    return _ScanValue.truncated;
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

  /// 流式部分快照 → 可渲染内容(未闭合字段留空,notes 仅取已闭合条目)
  factory LineNoteContent.fromPartialSnapshot(PartialJsonSnapshot snapshot) {
    return LineNoteContent.fromJson({
      'translation': snapshot.closedValues['translation'] ?? '',
      'notes': snapshot.closedValues['notes'] is List
          ? snapshot.closedValues['notes']
          : (snapshot.openArrayItems['notes'] ?? const <dynamic>[]),
    });
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

  /// 流式部分快照 → 可渲染内容: 未闭合字段留空默认值,
  /// 生成中的数组仅取已闭合元素。配合 [PartialJsonSnapshot.closedKeys]
  /// 可区分"还没生成到"与"模型未提供"。
  factory EssayContent.fromPartialSnapshot(PartialJsonSnapshot snapshot) {
    dynamic listFor(String key) {
      final closed = snapshot.closedValues[key];
      if (closed is List) return closed;
      return snapshot.openArrayItems[key] ?? const <dynamic>[];
    }

    final merged = <String, dynamic>{
      'summary': snapshot.closedValues['summary'] ?? '',
      'mood': snapshot.closedValues['mood'] ?? '',
      'emotion': snapshot.closedValues['emotion'] ?? '',
      'craft': listFor('craft'),
      'word_notes': listFor('word_notes'),
    };
    final background = snapshot.closedValues['background'];
    if (background is Map) merged['background'] = background;
    return EssayContent.fromJson(merged);
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

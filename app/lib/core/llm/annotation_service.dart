library;

import 'dart:convert';

/// 赏析服务 —— 三层披露的引擎(任务 3.2/3.3 的逻辑层)。
///
/// 职责:
///   缓存优先(byTarget 命中即返回) → 未命中走 LLM(json_object) →
///   解析(围栏剥离+宽容读取) → 失败重试一次(附纠正提示) → upsert 注本。
///
/// 保护语义: user_edited 条目在 force=false 时直接返回缓存;
/// force=true 由 UI 层负责先取得用户确认。

import '../../data/repositories/notebook_repository.dart';
import '../llm/llm_client.dart';
import '../llm/llm_exception.dart';
import '../llm/persona.dart';
import '../../domain/entities/annotations.dart';
import '../../domain/entities/notebook_entry.dart';
import '../../domain/entities/poem.dart';

/// 两次结构化解析均失败时携带最后一份模型原文，供 UI 纯文本降级展示。
class AnnotationParseException extends LlmException {
  const AnnotationParseException(this.rawText)
    : super(LlmErrorKind.badResponse, '赏析返回格式异常，已切换为纯文本');

  final String rawText;
}

/// 用户选区与当前诗文无法对应时抛出，避免把错误词语写成原文标记。
class SelectedWordValidationException extends LlmException {
  const SelectedWordValidationException(String message)
    : super(LlmErrorKind.badResponse, message);
}

/// 解析结果的保存策略。
enum AnnotationPersistence { persistent, transient }

/// 一次临时阅读会话的内存缓存，不包含任何数据库访问。
class TransientAnnotationSession {
  final Map<String, LineNoteContent> lineNotes = {};
  final Map<String, EssayContent> essays = {};
  final Map<String, WordNote> wordNotes = {};
  final Map<String, ChatTurnContent> chatTurns = {};
}

/// 传给阅读页和注解服务的生命周期上下文。
class AnnotationContext {
  const AnnotationContext.persistent()
    : persistence = AnnotationPersistence.persistent,
      session = null;

  AnnotationContext.transient({TransientAnnotationSession? session})
    : persistence = AnnotationPersistence.transient,
      session = session ?? TransientAnnotationSession();

  final AnnotationPersistence persistence;
  final TransientAnnotationSession? session;

  bool get isTransient => persistence == AnnotationPersistence.transient;
}

/// 结构化赏析的流式事件。
sealed class AnnotationEvent<T> {
  const AnnotationEvent();
}

/// 新一轮解析重试开始,UI 应清空上一轮的 partial 快照。
final class AnnotationReset<T> extends AnnotationEvent<T> {
  const AnnotationReset();
}

/// 已闭合字段的类型化快照。
final class AnnotationPartial<T> extends AnnotationEvent<T> {
  const AnnotationPartial(
    this.content, {
    required this.closedKeys,
    this.pendingKeys = const {},
  });

  final T content;

  /// 已完整闭合、可按最终语义展示的顶层字段。
  final Set<String> closedKeys;

  /// 已开始但尚未闭合的顶层字段,用于显示"生成中"占位。
  final Set<String> pendingKeys;
}

/// 完整解析、护栏校验并写入注本后的终态事件。
final class AnnotationDone<T> extends AnnotationEvent<T> {
  const AnnotationDone(this.content);

  final T content;
}

class AnnotationService {
  AnnotationService({
    required NotebookRepository notebookRepository,
    required LlmClient llmClient,
    required PersonaService personaService,
  }) : _notebook = notebookRepository,
       _llm = llmClient,
       _persona = personaService;

  final NotebookRepository _notebook;
  final LlmClient _llm;
  final PersonaService _persona;

  /// L1 点句即释的流式入口。
  ///
  /// 缓存命中时只发出一个 [AnnotationDone]；首次生成时先发 partial 快照，
  /// 完整结果经校验并写入注本后再发 [AnnotationDone]。
  Stream<AnnotationEvent<LineNoteContent>> streamLineNote(
    Poem poem,
    int lineIndex, {
    bool forceRegenerate = false,
    String? personaId,
    AnnotationContext context = const AnnotationContext.persistent(),
  }) async* {
    final target = lineIndex.toString();
    final cacheKey = _lineCacheKey(poem, target);
    if (context.isTransient) {
      final cached = context.session?.lineNotes[cacheKey];
      if (cached != null && !forceRegenerate) {
        yield AnnotationDone(cached);
        return;
      }
    } else {
      final existing = await _notebook.byTarget(
        poemId: poem.id,
        kind: NotebookKind.lineNote,
        target: target,
      );
      if (existing != null && !forceRegenerate) {
        final cached =
            LineNoteContent.tryParse(jsonEncode(existing.content)) ??
            LineNoteContent.fromJson(existing.content);
        yield AnnotationDone(cached);
        return;
      }
    }

    final personaIdResolved = personaId ?? await _persona.selectedId();
    final systemPrompt = await _buildPoemSystemPrompt(poem, personaIdResolved);
    final line = poem.paragraphs[lineIndex];
    final id = notebookEntryId(
      poemId: poem.id,
      kind: NotebookKind.lineNote,
      target: target,
    );

    yield* _streamStructured<LineNoteContent>(
      systemPrompt: systemPrompt,
      userPrompt:
          '【诗】${poem.bodyText}\n\n请针对第 ${lineIndex + 1} 行「$line」：\n'
          '给出整句白话直译(translation)，以及关键词注(notes 数组，'
          '每项 {term, pinyin, explain})。pinyin 使用结合语境的标准汉语拼音并带声调符号，'
          '词语内部用空格分隔。term 必须逐字出现在该句原文中。只输出 JSON 对象。',
      parse: LineNoteContent.tryParse,
      buildPartial: LineNoteContent.fromPartialSnapshot,
      finalize: (content) => content,
      persist: (content) async {
        if (context.isTransient) {
          context.session?.lineNotes[cacheKey] = content;
          return;
        }
        final now = DateTime.now();
        await _notebook.upsert(
          NotebookEntry(
            id: id,
            poemId: poem.id,
            kind: NotebookKind.lineNote,
            target: target,
            content: content.toJson(),
            persona: personaIdResolved,
            userEdited: false,
            createdAt: now,
            updatedAt: now,
          ),
        );
      },
    );
  }

  /// L1 非流式兼容包装：收集流直到终态事件。
  Future<LineNoteContent> getOrCreateLineNote(
    Poem poem,
    int lineIndex, {
    bool forceRegenerate = false,
    String? personaId,
    AnnotationContext context = const AnnotationContext.persistent(),
  }) => _collectAnnotation(
    streamLineNote(
      poem,
      lineIndex,
      forceRegenerate: forceRegenerate,
      personaId: personaId,
      context: context,
    ),
  );

  /// L2 整篇结构化赏析的流式入口。
  Stream<AnnotationEvent<EssayContent>> streamEssay(
    Poem poem, {
    bool forceRegenerate = false,
    String? personaId,
    AnnotationContext context = const AnnotationContext.persistent(),
  }) async* {
    if (context.isTransient) {
      final cached = context.session?.essays[poem.id];
      if (cached != null && !forceRegenerate) {
        yield AnnotationDone(
          cached.copyWith(wordNotes: _validWordNotes(poem, cached.wordNotes)),
        );
        return;
      }
    } else {
      final existing = await _notebook.byTarget(
        poemId: poem.id,
        kind: NotebookKind.essay,
      );

      if (existing != null && !forceRegenerate) {
        final cached =
            EssayContent.tryParse(jsonEncode(existing.content)) ??
            EssayContent.fromJson(existing.content);
        yield AnnotationDone(
          cached.copyWith(wordNotes: _validWordNotes(poem, cached.wordNotes)),
        );
        return;
      }
    }

    final personaIdResolved = personaId ?? await _persona.selectedId();
    final systemPrompt = await _buildPoemSystemPrompt(poem, personaIdResolved);
    final id = notebookEntryId(poemId: poem.id, kind: NotebookKind.essay);

    yield* _streamStructured<EssayContent>(
      systemPrompt: systemPrompt,
      userPrompt:
          '【诗】${poem.author}《${poem.displayTitle}》\n'
          '${poem.bodyText}\n\n请输出整篇赏析 JSON：\n'
          '{\n'
          ' "summary": "白话大意",\n'
          ' "craft": [{"point": "手法要点", "detail": "结合诗句的具体分析"}],\n'
          ' "mood": "意境",\n'
          ' "emotion": "情感",\n'
          ' "background": {"text": "创作背景", "uncertain": true|false},\n'
          ' "word_notes": [{"term": "诗中原词或短语", "pinyin": "带声调拼音", "explain": "结合本诗的释义", "line_index": 0}]\n'
          '}\n'
          'word_notes 最多列出 8 个值得解释的词语；term 必须逐字出现在诗文中，'
          'pinyin 使用结合语境的标准汉语拼音并带声调符号，词语内部用空格分隔；'
          'line_index 为从 0 开始的正文行号，无法定位时可省略。没有可靠词语时返回空数组。\n'
          '背景与典故无把握时 text 留空且 uncertain=true。',
      parse: EssayContent.tryParse,
      buildPartial: (snapshot) {
        final partial = EssayContent.fromPartialSnapshot(snapshot);
        return partial.copyWith(
          wordNotes: _validWordNotes(poem, partial.wordNotes),
        );
      },
      finalize: (content) =>
          content.copyWith(wordNotes: _validWordNotes(poem, content.wordNotes)),
      persist: (content) async {
        if (context.isTransient) {
          context.session?.essays[poem.id] = content;
          return;
        }
        final now = DateTime.now();
        await _notebook.upsert(
          NotebookEntry(
            id: id,
            poemId: poem.id,
            kind: NotebookKind.essay,
            target: null,
            content: content.toJson(),
            persona: personaIdResolved,
            userEdited: false,
            createdAt: now,
            updatedAt: now,
          ),
        );
      },
    );
  }

  /// L2 非流式兼容包装：收集流直到终态事件。
  Future<EssayContent> getOrCreateEssay(
    Poem poem, {
    bool forceRegenerate = false,
    String? personaId,
    AnnotationContext context = const AnnotationContext.persistent(),
  }) => _collectAnnotation(
    streamEssay(
      poem,
      forceRegenerate: forceRegenerate,
      personaId: personaId,
      context: context,
    ),
  );

  /// 用户在正文中选择词语后的解释。
  ///
  /// [position] 的偏移量使用 Dart/Flutter 的 UTF-16 code unit 坐标，
  /// 与 Text/RenderParagraph 的选区坐标一致。成功后写入独立的 word_note
  /// 条目，不会改写整篇 essay 缓存。
  Future<WordNote> getOrCreateSelectedWordNote(
    Poem poem,
    SelectedWordPosition position, {
    bool forceRegenerate = false,
    String? personaId,
    AnnotationContext context = const AnnotationContext.persistent(),
  }) async {
    if (!_isValidPosition(poem, position)) {
      throw const SelectedWordValidationException('所选词语无法对应当前诗文，请重新选择');
    }

    final cacheKey = _wordCacheKey(poem, position);
    if (context.isTransient) {
      final cached = context.session?.wordNotes[cacheKey];
      if (cached != null && !forceRegenerate) return cached;
    } else {
      final existing = await _notebook.byTarget(
        poemId: poem.id,
        kind: NotebookKind.wordNote,
        target: position.target,
      );
      if (existing != null && !forceRegenerate) {
        final cached = WordNote.fromJson(existing.content);
        if (cached != null &&
            cached.isUserSelected &&
            _matchesPosition(poem, position, cached)) {
          return cached;
        }
      }
    }

    final personaIdResolved = personaId ?? await _persona.selectedId();
    final systemPrompt = await _buildPoemSystemPrompt(poem, personaIdResolved);
    final line = poem.paragraphs[position.lineIndex];
    final raw = await _completeAndParse<WordNote>(
      systemPrompt: systemPrompt,
      userPrompt:
          '【诗】${poem.author}《${poem.displayTitle}》\n'
          '【全文】${poem.bodyText}\n'
          '【所在行】第 ${position.lineIndex + 1} 行：$line\n'
          '【用户选词】${position.term}\n'
          '【选区】start=${position.start}, end=${position.end}\n\n'
          '请只解释用户选中的原文词语，输出 JSON：\n'
          '{"term":"${position.term}","pinyin":"带声调拼音",'
          '"explain":"结合本诗语境的简短解释","uncertain":false}\n'
          'term 必须与用户选词完全一致；pinyin 使用标准汉语拼音并带声调符号；'
          '不得编造词源、出处或诗文外事实。没有把握时保留解释但将 uncertain 设为 true。',
      parse: WordNote.tryParse,
    );

    if (raw.term != position.term ||
        (raw.lineIndex != null && raw.lineIndex != position.lineIndex) ||
        (raw.start != null && raw.start != position.start) ||
        (raw.end != null && raw.end != position.end)) {
      throw const SelectedWordValidationException('模型返回的词语与原文选区不一致，请重试');
    }

    final parsed = WordNote(
      term: position.term,
      explain: raw.explain,
      pinyin: raw.pinyin,
      lineIndex: position.lineIndex,
      start: position.start,
      end: position.end,
      source: WordNoteSource.selected,
      uncertain: raw.uncertain,
    );
    if (context.isTransient) {
      context.session?.wordNotes[cacheKey] = parsed;
      return parsed;
    }
    final now = DateTime.now();
    await _notebook.upsert(
      NotebookEntry(
        id: notebookEntryId(
          poemId: poem.id,
          kind: NotebookKind.wordNote,
          target: position.target,
        ),
        poemId: poem.id,
        kind: NotebookKind.wordNote,
        target: position.target,
        content: parsed.toJson(),
        persona: personaIdResolved,
        userEdited: false,
        createdAt: now,
        updatedAt: now,
      ),
    );
    return parsed;
  }

  /// 返回当前诗中仍能精确对应原文的缓存标记：L1 关键词和用户选词。
  /// L2 词语由打开赏析页时单独回传，避免把整篇赏析解析两次。
  Future<List<WordNote>> cachedWordNotes(
    Poem poem, {
    AnnotationContext context = const AnnotationContext.persistent(),
  }) async {
    if (context.isTransient) {
      final notes = <WordNote>[];
      final session = context.session;
      if (session == null) return notes;
      for (final entry in session.wordNotes.entries) {
        if (!entry.key.startsWith('${poem.id}|')) continue;
        final note = entry.value;
        if (_matchesPosition(
          poem,
          SelectedWordPosition(
            lineIndex: note.lineIndex ?? -1,
            start: note.start ?? -1,
            end: note.end ?? -1,
            term: note.term,
          ),
          note,
        )) {
          notes.add(note);
        }
      }
      for (final entry in session.lineNotes.entries) {
        if (!entry.key.startsWith('${poem.id}|')) continue;
        final lineIndex = int.tryParse(entry.key.split('|').last);
        if (lineIndex == null) continue;
        _appendLineNoteWords(poem, lineIndex, entry.value, notes);
      }
      return notes;
    }

    final entries = await _notebook.byPoem(poem.id);
    final notes = <WordNote>[];
    for (final entry in entries) {
      if (entry.kind == NotebookKind.wordNote) {
        final note = WordNote.fromJson(entry.content);
        if (note != null &&
            note.isUserSelected &&
            _matchesPosition(
              poem,
              SelectedWordPosition(
                lineIndex: note.lineIndex ?? -1,
                start: note.start ?? -1,
                end: note.end ?? -1,
                term: note.term,
              ),
              note,
            )) {
          notes.add(note);
        }
        continue;
      }

      if (entry.kind != NotebookKind.lineNote) continue;
      final lineIndex = int.tryParse(entry.target ?? '');
      if (lineIndex == null) continue;
      _appendLineNoteWords(
        poem,
        lineIndex,
        LineNoteContent.fromJson(entry.content),
        notes,
      );
    }
    return notes;
  }

  void _appendLineNoteWords(
    Poem poem,
    int lineIndex,
    LineNoteContent lineNote,
    List<WordNote> notes,
  ) {
    if (lineIndex < 0 || lineIndex >= poem.paragraphs.length) return;
    final line = poem.paragraphs[lineIndex];
    for (final keyword in lineNote.notes) {
      final term = keyword.term.trim();
      final explain = keyword.explain.trim();
      if (term.isEmpty || explain.isEmpty || !line.contains(term)) continue;
      notes.add(
        WordNote(
          term: term,
          explain: explain,
          pinyin: keyword.pinyin,
          lineIndex: lineIndex,
        ),
      );
    }
  }

  /// 返回当前诗中仍能精确对应原文的用户选词注。
  Future<List<WordNote>> userWordNotes(
    Poem poem, {
    AnnotationContext context = const AnnotationContext.persistent(),
  }) async {
    final notes = await cachedWordNotes(poem, context: context);
    return notes.where((note) => note.isUserSelected).toList();
  }

  bool _isValidPosition(Poem poem, SelectedWordPosition position) {
    if (position.term.trim().isEmpty ||
        position.lineIndex < 0 ||
        position.lineIndex >= poem.paragraphs.length ||
        position.start < 0 ||
        position.end <= position.start) {
      return false;
    }
    final line = poem.paragraphs[position.lineIndex];
    return position.end <= line.length &&
        line.substring(position.start, position.end) == position.term;
  }

  bool _matchesPosition(
    Poem poem,
    SelectedWordPosition position,
    WordNote note,
  ) {
    return note.term == position.term &&
        note.lineIndex == position.lineIndex &&
        note.start == position.start &&
        note.end == position.end &&
        _isValidPosition(poem, position);
  }

  /// L3 追问对话。
  ///
  /// 正常路径逐段 yield；流式连接失败或返回空内容时改用一次性补全。
  /// fallback 通过 [ChatDelta.replace] 告诉 UI 替换半截答案，避免重复文本。
  /// 每次完成的问答都以 chat_turn 形式写入注本。
  Stream<ChatDelta> streamQuestion(
    Poem poem,
    String question, {
    String? personaId,
    EssayContent? essay,
    AnnotationContext context = const AnnotationContext.persistent(),
  }) async* {
    final cleanQuestion = question.trim();
    if (cleanQuestion.isEmpty) {
      throw const LlmException(LlmErrorKind.badResponse, '问题不能为空');
    }

    final cacheKey = '${poem.id}|$cleanQuestion';
    if (context.isTransient) {
      final cached = context.session?.chatTurns[cacheKey];
      if (cached != null) {
        yield ChatDelta(cached.answer);
        return;
      }
    }

    final personaIdResolved = personaId ?? await _persona.selectedId();
    final systemPrompt = await _buildPoemSystemPrompt(poem, personaIdResolved);

    final promptContext = StringBuffer()
      ..writeln('【本诗全文】')
      ..writeln(poem.bodyText);
    final cachedEssay =
        essay ??
        (context.isTransient
            ? context.session?.essays[poem.id]
            : await _cachedEssay(poem.id));
    if (cachedEssay != null) {
      promptContext
        ..writeln()
        ..writeln('【已有结构化赏析】')
        ..writeln(jsonEncode(cachedEssay.toJson()));
    }
    promptContext
      ..writeln()
      ..writeln('【用户问题】')
      ..write(cleanQuestion);

    final messages = <LlmMessage>[
      LlmMessage('system', systemPrompt),
      LlmMessage('user', promptContext.toString()),
    ];
    final answer = StringBuffer();

    try {
      await for (final chunk in _llm.streamChat(messages)) {
        if (chunk.isEmpty) continue;
        answer.write(chunk);
        yield ChatDelta(chunk);
      }
      if (answer.isEmpty) {
        throw const LlmException(LlmErrorKind.badResponse, '流式返回为空');
      }
    } on LlmException catch (error) {
      if (error.kind == LlmErrorKind.noKey) rethrow;
      final fallback = await _llm.complete(messages);
      if (fallback.trim().isEmpty) {
        throw const LlmException(LlmErrorKind.badResponse, '返回内容为空');
      }
      answer
        ..clear()
        ..write(fallback);
      yield ChatDelta(fallback, replace: true);
    } catch (_) {
      // 兼容少数 transport 抛出的非 LlmException 网络错误。
      final fallback = await _llm.complete(messages);
      if (fallback.trim().isEmpty) {
        throw const LlmException(LlmErrorKind.badResponse, '返回内容为空');
      }
      answer
        ..clear()
        ..write(fallback);
      yield ChatDelta(fallback, replace: true);
    }

    final chatTurn = ChatTurnContent(
      question: cleanQuestion,
      answer: answer.toString(),
    );
    if (context.isTransient) {
      context.session?.chatTurns[cacheKey] = chatTurn;
      return;
    }

    final now = DateTime.now();
    final target = cleanQuestion.length > 160
        ? cleanQuestion.substring(0, 160)
        : cleanQuestion;
    await _notebook.upsert(
      NotebookEntry(
        id: notebookEntryId(
          poemId: poem.id,
          kind: NotebookKind.chatTurn,
          target: '${now.microsecondsSinceEpoch}|$target',
        ),
        poemId: poem.id,
        kind: NotebookKind.chatTurn,
        target: target,
        content: chatTurn.toJson(),
        persona: personaIdResolved,
        userEdited: false,
        createdAt: now,
        updatedAt: now,
      ),
    );
  }

  String _lineCacheKey(Poem poem, String target) => '${poem.id}|$target';

  String _wordCacheKey(Poem poem, SelectedWordPosition position) =>
      '${poem.id}|${position.target}';

  List<WordNote> _validWordNotes(Poem poem, List<WordNote> notes) {
    final seen = <String>{};
    final valid = <WordNote>[];
    for (final note in notes) {
      final lineMatches = note.lineIndex == null
          ? poem.paragraphs.any((line) => line.contains(note.term))
          : note.lineIndex! >= 0 &&
                note.lineIndex! < poem.paragraphs.length &&
                poem.paragraphs[note.lineIndex!].contains(note.term);
      if (!lineMatches) continue;
      final key = '${note.lineIndex ?? '*'}|${note.term}';
      if (seen.add(key)) valid.add(note);
      if (valid.length == 8) break;
    }
    return valid;
  }

  Future<String> _buildPoemSystemPrompt(Poem poem, String personaId) async {
    final prompt = await _persona.buildSystemPrompt(
      personaId,
      poemBody: poem.bodyText,
      metaLine: '${poem.author} · ${poem.dynasty}',
    );
    if (!poem.isExtended) return prompt;
    return '''$prompt

【外部作品事实边界】
这是一份由 AI 寻诗补充的外部作品。作者、时期、出处、推荐理由和原文版本均可能未经核验；只能把给出的正文作为艺术分析事实。不要根据元数据编造确定的历史背景或典故，无把握时将背景留空并标记为不确定。''';
  }

  Future<EssayContent?> _cachedEssay(String poemId) async {
    final entry = await _notebook.byTarget(
      poemId: poemId,
      kind: NotebookKind.essay,
    );
    if (entry == null) return null;
    return EssayContent.tryParse(jsonEncode(entry.content));
  }

  /// 结构化结果的流式生成器: 两轮流式优先,每轮传输失败时回退一次性补全。
  Stream<AnnotationEvent<T>> _streamStructured<T>({
    required String systemPrompt,
    required String userPrompt,
    required T? Function(String raw) parse,
    required T Function(PartialJsonSnapshot snapshot) buildPartial,
    required T Function(T content) finalize,
    required Future<void> Function(T content) persist,
  }) async* {
    String? lastRaw;

    for (var attempt = 0; attempt < 2; attempt++) {
      if (attempt > 0) yield AnnotationReset<T>();

      final messages = <LlmMessage>[
        LlmMessage('system', systemPrompt),
        LlmMessage('user', userPrompt),
      ];
      if (attempt == 1) {
        messages.addAll([
          const LlmMessage('assistant', '(上次输出无法解析为 JSON)'),
          const LlmMessage(
            'user',
            '上一次输出不是合法 JSON。请重新回答，只输出一个合法 JSON 对象，不要任何其他文字。',
          ),
        ]);
      }

      final buffer = StringBuffer();
      var streamFailed = false;
      var lastSignature = '';

      try {
        await for (final chunk in _llm.streamChat(
          messages,
          jsonMode: attempt == 0,
        )) {
          if (chunk.isEmpty) continue;
          buffer.write(chunk);
          final snapshot = tryDecodePartialJsonObject(buffer.toString());
          if (snapshot == null || snapshot.isEmpty) continue;

          final signature = _partialSignature(snapshot);
          if (signature == lastSignature) continue;
          lastSignature = signature;
          yield AnnotationPartial<T>(
            buildPartial(snapshot),
            closedKeys: Set.unmodifiable(snapshot.closedValues.keys.toSet()),
            pendingKeys: Set.unmodifiable(snapshot.openKeys.toSet()),
          );
        }
      } on LlmException catch (error) {
        if (error.kind == LlmErrorKind.noKey) rethrow;
        streamFailed = true;
      } catch (_) {
        // 兼容少数 transport 抛出的非 LlmException 网络错误。
        streamFailed = true;
      }

      String raw;
      if (streamFailed || buffer.isEmpty) {
        try {
          raw = await _llm.complete(messages, jsonMode: attempt == 0);
        } on LlmException catch (error) {
          if (error.kind != LlmErrorKind.badResponse) rethrow;
          if (attempt == 1 && lastRaw != null) {
            throw AnnotationParseException(lastRaw);
          }
          if (attempt == 1) rethrow;
          continue;
        }
      } else {
        raw = buffer.toString();
      }

      lastRaw = raw;
      final parsed = parse(raw);
      if (parsed != null) {
        final content = finalize(parsed);
        await persist(content);
        yield AnnotationDone<T>(content);
        return;
      }

      if (attempt == 1) {
        if (raw.trim().isNotEmpty) {
          throw AnnotationParseException(raw);
        }
        throw const LlmException(LlmErrorKind.badResponse, '赏析返回格式异常');
      }
    }

    final raw = lastRaw;
    if (raw != null && raw.trim().isNotEmpty) {
      throw AnnotationParseException(raw);
    }
    throw const LlmException(LlmErrorKind.badResponse, '赏析返回格式异常');
  }

  /// 只有完整字段/数组元素出现时才重新通知 UI,避免每个 token 都重建页面。
  String _partialSignature(PartialJsonSnapshot snapshot) {
    final closed = snapshot.closedValues.keys.toList()..sort();
    final pending = snapshot.openKeys.toList()..sort();
    final arrays =
        snapshot.openArrayItems.entries
            .map((entry) => '${entry.key}:${entry.value.length}')
            .toList()
          ..sort();
    return '${closed.join(',')}|${pending.join(',')}|${arrays.join(',')}';
  }

  Future<T> _collectAnnotation<T>(Stream<AnnotationEvent<T>> events) async {
    late T content;
    var completed = false;
    await for (final event in events) {
      if (event is AnnotationDone<T>) {
        content = event.content;
        completed = true;
      }
    }
    if (!completed) {
      throw const LlmException(LlmErrorKind.badResponse, '赏析返回格式异常');
    }
    return content;
  }

  /// 解析失败自动重试一次(附格式纠正提示)。
  ///
  /// LLM 客户端自身的响应结构错误和业务 JSON 解析错误都走同一重试
  /// 路径，避免供应商虽返回 2xx、但内容带说明文字时提前放弃。
  Future<T> _completeAndParse<T>({
    required String systemPrompt,
    required String userPrompt,
    required T? Function(String raw) parse,
  }) async {
    String? lastRaw;
    for (var attempt = 0; attempt < 2; attempt++) {
      final messages = <LlmMessage>[
        LlmMessage('system', systemPrompt),
        LlmMessage('user', userPrompt),
      ];
      if (attempt == 1) {
        messages.addAll([
          const LlmMessage('assistant', '(上次输出无法解析为 JSON)'),
          const LlmMessage(
            'user',
            '上一次输出不是合法 JSON。请重新回答，只输出一个合法 JSON 对象，不要任何其他文字。',
          ),
        ]);
      }

      String raw;
      try {
        // 首次请求使用 JSON mode；部分 OpenAI 兼容服务不支持
        // response_format，第二次改用普通请求并由提示词约束 JSON。
        raw = await _llm.complete(messages, jsonMode: attempt == 0);
        lastRaw = raw;
      } on LlmException catch (e) {
        if (e.kind != LlmErrorKind.badResponse) rethrow;
        if (attempt == 1 && lastRaw != null) {
          throw AnnotationParseException(lastRaw);
        }
        if (attempt == 1) rethrow;
        continue;
      }

      final parsed = parse(raw);
      if (parsed != null) return parsed;
    }

    final raw = lastRaw;
    if (raw != null && raw.trim().isNotEmpty) {
      throw AnnotationParseException(raw);
    }
    throw const LlmException(LlmErrorKind.badResponse, '赏析返回格式异常');
  }
}

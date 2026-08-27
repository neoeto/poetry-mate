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

class AnnotationService {
  AnnotationService({
    required NotebookRepository notebookRepository,
    required LlmClient llmClient,
    required PersonaService personaService,
  })  : _notebook = notebookRepository,
        _llm = llmClient,
        _persona = personaService;

  final NotebookRepository _notebook;
  final LlmClient _llm;
  final PersonaService _persona;

  /// L1 点句即释
  Future<LineNoteContent> getOrCreateLineNote(
    Poem poem,
    int lineIndex, {
    bool forceRegenerate = false,
    String? personaId,
  }) async {
    final target = lineIndex.toString();
    final existing = await _notebook.byTarget(
      poemId: poem.id,
      kind: NotebookKind.lineNote,
      target: target,
    );
    if (existing != null && !forceRegenerate) {
      return LineNoteContent.tryParse(
              jsonEncode(existing.content)) ??
          LineNoteContent.fromJson(existing.content);
    }

    if (existing != null && existing.userEdited && !forceRegenerate) {
      return LineNoteContent.fromJson(existing.content);
    }

    final personaIdResolved =
        personaId ?? await _persona.selectedId();
    final systemPrompt = await _persona.buildSystemPrompt(
      personaIdResolved,
      poemBody: poem.bodyText,
      metaLine: '${poem.author} · ${poem.dynasty}',
    );
    final line = poem.paragraphs[lineIndex];
    final parsed = await _completeAndParse<LineNoteContent>(
      systemPrompt: systemPrompt,
      userPrompt:
          '【诗】${poem.bodyText}\n\n请针对第 ${lineIndex + 1} 行「$line」：\n'
          '给出整句白话直译(translation)，以及关键词注(notes 数组，'
          '每项 {term, explain})。只输出 JSON 对象。',
      parse: LineNoteContent.tryParse,
    );

    final id = notebookEntryId(
      poemId: poem.id,
      kind: NotebookKind.lineNote,
      target: target,
    );
    final now = DateTime.now();
    await _notebook.upsert(NotebookEntry(
      id: id,
      poemId: poem.id,
      kind: NotebookKind.lineNote,
      target: target,
      content: parsed.toJson(),
      persona: personaIdResolved,
      userEdited: false,
      createdAt: now,
      updatedAt: now,
    ));
    return parsed;
  }

  /// L2 整篇结构化赏析
  Future<EssayContent> getOrCreateEssay(
    Poem poem, {
    bool forceRegenerate = false,
    String? personaId,
  }) async {
    final existing = await _notebook.byTarget(
      poemId: poem.id,
      kind: NotebookKind.essay,
    );

    if (existing != null && !forceRegenerate) {
      return EssayContent.tryParse(
              jsonEncode(existing.content)) ??
          EssayContent.fromJson(existing.content);
    }

    if (existing != null && existing.userEdited && !forceRegenerate) {
      return EssayContent.fromJson(existing.content);
    }

    final personaIdResolved =
        personaId ?? await _persona.selectedId();
    final systemPrompt = await _persona.buildSystemPrompt(
      personaIdResolved,
      poemBody: poem.bodyText,
      metaLine: '${poem.author} · ${poem.dynasty}',
    );

    final parsed = await _completeAndParse<EssayContent>(
      systemPrompt: systemPrompt,
      userPrompt: '【诗】${poem.author}《${poem.displayTitle}》\n'
          '${poem.bodyText}\n\n请输出整篇赏析 JSON：\n'
          '{\n'
          ' "summary": "白话大意",\n'
          ' "craft": [{"point": "手法要点", "detail": "结合诗句的具体分析"}],\n'
          ' "mood": "意境",\n'
          ' "emotion": "情感",\n'
          ' "background": {"text": "创作背景", "uncertain": true|false}\n'
          '}\n背景与典故无把握时 text 留空且 uncertain=true。',
      parse: EssayContent.tryParse,
    );

    final id = notebookEntryId(poemId: poem.id, kind: NotebookKind.essay);
    final now = DateTime.now();
    await _notebook.upsert(NotebookEntry(
      id: id,
      poemId: poem.id,
      kind: NotebookKind.essay,
      target: null,
      content: parsed.toJson(),
      persona: personaIdResolved,
      userEdited: false,
      createdAt: now,
      updatedAt: now,
    ));
    return parsed;
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
  }) async* {
    final cleanQuestion = question.trim();
    if (cleanQuestion.isEmpty) {
      throw const LlmException(LlmErrorKind.badResponse, '问题不能为空');
    }

    final personaIdResolved = personaId ?? await _persona.selectedId();
    final systemPrompt = await _persona.buildSystemPrompt(
      personaIdResolved,
      poemBody: poem.bodyText,
      metaLine: '${poem.author} · ${poem.dynasty}',
    );

    final context = StringBuffer()
      ..writeln('【本诗全文】')
      ..writeln(poem.bodyText);
    final cachedEssay = essay ?? await _cachedEssay(poem.id);
    if (cachedEssay != null) {
      context
        ..writeln()
        ..writeln('【已有结构化赏析】')
        ..writeln(jsonEncode(cachedEssay.toJson()));
    }
    context
      ..writeln()
      ..writeln('【用户问题】')
      ..write(cleanQuestion);

    final messages = <LlmMessage>[
      LlmMessage('system', systemPrompt),
      LlmMessage('user', context.toString()),
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

    final now = DateTime.now();
    final target = cleanQuestion.length > 160
        ? cleanQuestion.substring(0, 160)
        : cleanQuestion;
    await _notebook.upsert(NotebookEntry(
      id: notebookEntryId(
        poemId: poem.id,
        kind: NotebookKind.chatTurn,
        target: '${now.microsecondsSinceEpoch}|$target',
      ),
      poemId: poem.id,
      kind: NotebookKind.chatTurn,
      target: target,
      content: ChatTurnContent(
        question: cleanQuestion,
        answer: answer.toString(),
      ).toJson(),
      persona: personaIdResolved,
      userEdited: false,
      createdAt: now,
      updatedAt: now,
    ));
  }

  Future<EssayContent?> _cachedEssay(String poemId) async {
    final entry = await _notebook.byTarget(
      poemId: poemId,
      kind: NotebookKind.essay,
    );
    if (entry == null) return null;
    return EssayContent.tryParse(jsonEncode(entry.content));
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
              'user', '上一次输出不是合法 JSON。请重新回答，只输出一个合法 JSON 对象，不要任何其他文字。'),
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



/// AI 寻诗服务 —— 从用户自配模型中寻找本地库之外的既有作品。
///
/// 会话和候选结果只存在内存中；是否保存作品由结果页明确交给扩展诗词库。
library;

import 'dart:convert';

import '../../domain/entities/annotations.dart' as annotation;
import '../../domain/entities/extended_poem.dart';
import 'llm_client.dart';
import 'llm_exception.dart';
import 'persona.dart';

class PoemFinderParseException extends LlmException {
  const PoemFinderParseException(this.rawText)
    : super(LlmErrorKind.badResponse, '寻诗结果格式异常，请重试');

  final String rawText;
}

/// 当前寻诗会话。只保存内存中的成功问答，不写入注本。
class PoemFinderSession {
  PoemFinderSession();

  final List<LlmMessage> messages = [];
  String? systemPrompt;
}

sealed class PoemFinderEvent {
  const PoemFinderEvent();
}

final class PoemFinderReset extends PoemFinderEvent {
  const PoemFinderReset();
}

final class PoemFinderPartial extends PoemFinderEvent {
  const PoemFinderPartial(this.text, {this.replace = false});

  final String text;
  final bool replace;
}

final class PoemFinderDone extends PoemFinderEvent {
  const PoemFinderDone(this.response);

  final AiPoemSearchResponse response;
}

class PoemFinderService {
  PoemFinderService({
    required LlmClient llmClient,
    required PersonaService personaService,
  }) : _llm = llmClient,
       _persona = personaService;

  final LlmClient _llm;
  final PersonaService _persona;

  Stream<PoemFinderEvent> streamTurn(
    PoemFinderSession session,
    String userMessage,
  ) async* {
    final message = userMessage.trim();
    if (message.isEmpty) {
      throw const LlmException(LlmErrorKind.badResponse, '想找什么诗，可以先告诉我');
    }

    final systemPrompt = session.systemPrompt ??= await _buildSystemPrompt();
    String? lastRaw;

    for (var attempt = 0; attempt < 2; attempt++) {
      if (attempt > 0) yield const PoemFinderReset();

      final messages = <LlmMessage>[
        LlmMessage('system', systemPrompt),
        ...session.messages,
        LlmMessage('user', message),
      ];
      if (attempt == 1) {
        messages.addAll([
          const LlmMessage('assistant', '(上次寻诗结果无法解析)'),
          const LlmMessage(
            'user',
            '上一次结果不是合法的寻诗 JSON。请重新回答，只输出一个合法 JSON 对象，不能输出原创或仿写文本；'
                'paragraphs 必须按原文逐句拆分，每个数组元素只放一句，不能把整首正文合并成一个元素。',
          ),
        ]);
      }
      final buffer = StringBuffer();
      var streamFailed = false;
      var lastReply = '';

      try {
        await for (final chunk in _llm.streamChat(
          messages,
          jsonMode: attempt == 0,
        )) {
          if (chunk.isEmpty) continue;
          buffer.write(chunk);
          final snapshot = annotation.tryDecodePartialJsonObject(
            buffer.toString(),
          );
          final reply = snapshot?.closedValues['reply'];
          if (reply is String && reply != lastReply) {
            lastReply = reply;
            yield PoemFinderPartial(reply);
          }
        }
      } on LlmException catch (error) {
        if (error.kind == LlmErrorKind.noKey) rethrow;
        streamFailed = true;
      } catch (_) {
        streamFailed = true;
      }

      String raw;
      if (streamFailed || buffer.isEmpty) {
        try {
          raw = await _complete(messages, jsonMode: attempt == 0);
        } on LlmException catch (error) {
          if (error.kind != LlmErrorKind.badResponse) rethrow;
          if (attempt == 1 && lastRaw != null) {
            throw PoemFinderParseException(lastRaw);
          }
          continue;
        }
        if (raw.trim().isEmpty) {
          if (attempt == 1) {
            throw const LlmException(LlmErrorKind.badResponse, '寻诗返回内容为空');
          }
          continue;
        }
        // 降级结果只把可读的 reply 交给 UI，不把 JSON 原文显示出来。
        final fallback = AiPoemSearchResponse.tryParse(raw);
        if (fallback != null && fallback.reply.trim().isNotEmpty) {
          yield PoemFinderPartial(fallback.reply, replace: true);
        }
      } else {
        raw = buffer.toString();
      }

      lastRaw = raw;
      final parsed = AiPoemSearchResponse.tryParse(raw);
      if (parsed != null) {
        session.messages
          ..add(LlmMessage('user', message))
          ..add(LlmMessage('assistant', jsonEncode(parsed.toJson())));
        yield PoemFinderDone(parsed);
        return;
      }

      if (attempt == 1) {
        throw PoemFinderParseException(lastRaw);
      }
    }

    throw PoemFinderParseException(lastRaw ?? '');
  }

  Future<String> _complete(
    List<LlmMessage> messages, {
    required bool jsonMode,
  }) => _llm.complete(messages, jsonMode: jsonMode);

  Future<String> _buildSystemPrompt() async {
    final personaId = await _persona.selectedId();
    final template = await _persona.loadPrompt(personaId);
    return '''$template

【AI 寻诗任务】
你是一个严谨的寻诗助手，不是诗歌创作助手。请根据用户的描述，从你已知的真实中文文学作品中寻找一首合适的作品；范围可以是古诗、词、《诗经》、古文、近现代诗歌等，不要局限于某个诗库。

禁止原创、仿写、续写、改写，也不要把无法确认出处的临时文本冒充名作。无法确认符合条件的既有作品时，返回 status="not_found"。找到时只返回一首作品。

始终只输出一个合法 JSON 对象，不要 Markdown 围栏或其他说明。格式如下：
{
  "status": "found" | "not_found",
  "reply": "给用户看的简短说明",
  "title": "作品标题",
  "author": "作者，不确定时为 null",
  "period": "朝代或时期，不确定时为 null",
  "genre": "shi/ci/book_of_songs/prose/modern_poem/other 等",
  "paragraphs": ["按原文逐句填写，每个数组元素只放一句，保留原有标点和顺序"],
  "preface": null,
  "rhythmic": null,
  "source": "出处，不确定时为 null",
  "source_confidence": "known" | "uncertain" | "unknown",
  "uncertain_fields": ["author", "period", "source", "text"],
  "recommendation": "为什么适合用户，简短即可"
}
每一句必须单独作为 paragraphs 数组中的一个元素；如果原文包含换行或句末标点，请据此拆分，禁止把整首诗词正文作为一个完整字符串返回。
not_found 时保留 status、reply、message 字段即可。不得将 status=found 与原创文本同时返回。''';
  }
}

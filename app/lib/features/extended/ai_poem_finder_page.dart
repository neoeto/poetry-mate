/// AI 寻诗页面：通过多轮对话寻找本地库之外的既有中文文学作品。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/llm/llm_exception.dart';
import '../../core/llm/poem_finder_service.dart';
import '../../data/providers.dart';
import '../../domain/entities/extended_poem.dart';
import '../../domain/entities/poem.dart';
import '../../data/repositories/poem_catalog_repository.dart';

class AiPoemFinderPage extends ConsumerStatefulWidget {
  const AiPoemFinderPage({super.key});

  @override
  ConsumerState<AiPoemFinderPage> createState() => _AiPoemFinderPageState();
}

class _AiPoemFinderPageState extends ConsumerState<AiPoemFinderPage> {
  final _inputController = TextEditingController();
  final _scrollController = ScrollController();
  final _messages = <_FinderMessage>[];
  late final PoemFinderSession _session;

  Object? _error;
  String? _lastPrompt;
  ExtendedPoemDraft? _candidate;
  var _sending = false;

  @override
  void initState() {
    super.initState();
    _session = PoemFinderSession();
  }

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _send([String? override]) async {
    if (_sending) return;
    final prompt = (override ?? _inputController.text).trim();
    if (prompt.isEmpty) return;

    _inputController.clear();
    final assistantIndex = _messages.length + 1;
    setState(() {
      _error = null;
      _lastPrompt = prompt;
      _candidate = null;
      _messages.add(_FinderMessage(fromUser: true, text: prompt));
      _messages.add(_FinderMessage(fromUser: false, text: ''));
      _sending = true;
    });
    _scrollToEnd();

    try {
      final stream = ref
          .read(poemFinderServiceProvider)
          .streamTurn(_session, prompt);
      await for (final event in stream) {
        if (!mounted) return;
        if (event is PoemFinderReset) {
          setState(() => _messages[assistantIndex].text = '');
        } else if (event is PoemFinderPartial) {
          setState(() {
            final current = _messages[assistantIndex];
            current.text = event.replace ? event.text : event.text;
          });
        } else if (event is PoemFinderDone) {
          final response = event.response;
          final display = response.reply.trim().isEmpty
              ? response.isFound
                    ? '我找到了一首，可以先看看。'
                    : response.isRejected
                    ? '这段内容无法确认是已有作品，我们换个方向找找。'
                    : '这次还没有找到合适的作品。'
              : response.reply;
          setState(() {
            _messages[assistantIndex].text = display;
            _candidate = response.isFound ? response.poem : null;
          });
        }
        _scrollToEnd();
      }
    } catch (error) {
      if (!mounted) return;
      setState(() {
        if (assistantIndex < _messages.length &&
            _messages[assistantIndex].text.isEmpty) {
          _messages.removeAt(assistantIndex);
        }
        _error = error;
      });
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _saveCandidate() async {
    final candidate = _candidate;
    if (candidate == null) return;
    final result = await ref
        .read(poemCatalogRepositoryProvider)
        .saveDraft(candidate);
    if (!mounted) return;
    switch (result.status) {
      case ExtendedPoemSaveStatus.saved:
        ref.invalidate(visibleExtendedPoemsProvider);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('已加入扩展诗词库')));
        final id = result.match.extended?.id;
        if (id != null) context.push('/extended-poem/$id');
      case ExtendedPoemSaveStatus.alreadyPublic:
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('这首作品已在本地诗库中')));
        context.push('/poem/${result.match.poem.id}');
      case ExtendedPoemSaveStatus.alreadyExtended:
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('这首作品已在扩展诗词库中')));
        final id = result.match.extended?.id;
        if (id != null) context.push('/extended-poem/$id');
    }
  }

  void _viewOnce() {
    final candidate = _candidate;
    if (candidate != null) {
      context.push('/poem-preview', extra: candidate);
    }
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AI 寻诗'),
        actions: [
          IconButton(
            tooltip: '扩展诗词库',
            icon: const Icon(Icons.library_books_outlined),
            onPressed: () => context.push('/extended-library'),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(child: _messageList()),
          if (_error != null)
            _FinderError(
              error: _error!,
              onRetry: _lastPrompt == null ? null : () => _send(_lastPrompt),
              onOpenSettings: () {
                context.push('/settings/llm');
              },
            ),
          if (_candidate != null)
            _CandidateCard(
              candidate: _candidate!,
              onSave: _saveCandidate,
              onViewOnce: _viewOnce,
            ),
          _composer(),
        ],
      ),
    );
  }

  Widget _messageList() {
    if (_messages.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(
            '告诉我你想读什么。\n比如：一首写春天、轻快一点的诗。\n我会从已有作品中帮你找。',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
      );
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
      itemCount: _messages.length,
      itemBuilder: (context, index) {
        final message = _messages[index];
        return _FinderBubble(
          fromUser: message.fromUser,
          text: message.text,
          sending: _sending && !message.fromUser && message.text.isEmpty,
        );
      },
    );
  }

  Widget _composer() {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: TextField(
                controller: _inputController,
                enabled: !_sending,
                minLines: 1,
                maxLines: 3,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _send(),
                decoration: const InputDecoration(
                  hintText: '描述你想找的作品…',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filled(
              tooltip: '发送',
              onPressed: _sending ? null : _send,
              icon: const Icon(Icons.send),
            ),
          ],
        ),
      ),
    );
  }
}

class _FinderMessage {
  _FinderMessage({required this.fromUser, required this.text});

  final bool fromUser;
  String text;
}

class _FinderBubble extends StatelessWidget {
  const _FinderBubble({
    required this.fromUser,
    required this.text,
    required this.sending,
  });

  final bool fromUser;
  final String text;
  final bool sending;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Align(
      alignment: fromUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 330),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: fromUser ? scheme.primaryContainer : scheme.surfaceContainer,
          borderRadius: BorderRadius.circular(16),
        ),
        child: sending
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Text(text),
      ),
    );
  }
}

class _CandidateCard extends StatelessWidget {
  const _CandidateCard({
    required this.candidate,
    required this.onSave,
    required this.onViewOnce,
  });

  final ExtendedPoemDraft candidate;
  final VoidCallback onSave;
  final VoidCallback onViewOnce;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final author = candidate.author ?? '作者不详';
    final period = candidate.period ?? '时期不详';
    return Card(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 4),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 12, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.auto_awesome_outlined, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    candidate.title,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text('$author · $period · ${candidate.genre}'),
            if (candidate.source != null || candidate.sourceUncertain) ...[
              const SizedBox(height: 4),
              Text(
                '出处：${candidate.source ?? '不详'}${candidate.sourceUncertain ? '（信息待核）' : ''}',
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
              ),
            ],
            const SizedBox(height: 8),
            Text(
              candidate.paragraphs.map(poemLineWithIndent).join('\n'),
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            if (candidate.recommendation.trim().isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                candidate.recommendation,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            const SizedBox(height: 6),
            Row(
              children: [
                TextButton.icon(
                  onPressed: onViewOnce,
                  icon: const Icon(Icons.visibility_outlined),
                  label: const Text('仅本次查看'),
                ),
                const Spacer(),
                FilledButton.icon(
                  onPressed: onSave,
                  icon: const Icon(Icons.library_add_outlined),
                  label: const Text('加入扩展库'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _FinderError extends StatelessWidget {
  const _FinderError({
    required this.error,
    required this.onRetry,
    required this.onOpenSettings,
  });

  final Object error;
  final VoidCallback? onRetry;
  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context) {
    final noKey =
        error is LlmException &&
        (error as LlmException).kind == LlmErrorKind.noKey;
    if (noKey) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
        child: Row(
          children: [
            const Icon(Icons.auto_awesome_outlined, size: 20),
            const SizedBox(width: 8),
            const Expanded(child: Text('还没有配置 AI')),
            TextButton(onPressed: onOpenSettings, child: const Text('去配置')),
          ],
        ),
      );
    }
    final detail = error is LlmException
        ? '${(error as LlmException).title}：${(error as LlmException).message}'
        : '暂时没能找到作品，请检查网络连接或稍后再试。';
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
      child: Row(
        children: [
          Expanded(child: Text(detail)),
          if (onRetry != null)
            TextButton(onPressed: onRetry, child: const Text('重试')),
        ],
      ),
    );
  }
}

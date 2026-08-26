/// L3 追问对话底部抽屉。
///
/// UI 只消费 ChatDelta，不直接感知供应商协议；当 service 发生一次性降级时，
/// replace=true 会替换已经显示的半截流，避免「流式残片 + 完整答案」重复。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/llm/llm_exception.dart';
import '../../data/providers.dart';
import '../../domain/entities/poem.dart';

class ChatSheet extends ConsumerStatefulWidget {
  const ChatSheet({
    super.key,
    required this.poem,
    this.onOpenSettings,
  });

  final Poem poem;
  final VoidCallback? onOpenSettings;

  @override
  ConsumerState<ChatSheet> createState() => _ChatSheetState();
}

class _ChatSheetState extends ConsumerState<ChatSheet> {
  final _questionController = TextEditingController();
  final _scrollController = ScrollController();
  final _messages = <_ChatMessage>[];

  Object? _error;
  String? _lastQuestion;
  var _sending = false;

  @override
  void dispose() {
    _questionController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _send([String? questionOverride]) async {
    if (_sending) return;
    final question = (questionOverride ?? _questionController.text).trim();
    if (question.isEmpty) return;

    _questionController.clear();
    _messages.add(_ChatMessage(fromUser: true, text: question));
    final assistantIndex = _messages.length;
    _messages.add(_ChatMessage(fromUser: false, text: ''));
    setState(() {
      _error = null;
      _lastQuestion = question;
      _sending = true;
    });
    _scrollToEnd();

    try {
      final stream = ref.read(annotationServiceProvider).streamQuestion(
            widget.poem,
            question,
          );
      await for (final delta in stream) {
        if (!mounted) return;
        setState(() {
          final message = _messages[assistantIndex];
          message.text = delta.replace ? delta.text : message.text + delta.text;
        });
        _scrollToEnd();
      }
    } catch (error) {
      if (!mounted) return;
      setState(() {
        // 保留用户问题,移除没有内容的 assistant 占位。
        if (assistantIndex < _messages.length &&
            _messages[assistantIndex].text.isEmpty) {
          _messages.removeAt(assistantIndex);
        }
        _error = error;
      });
    } finally {
      if (mounted) {
        setState(() => _sending = false);
      }
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
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(bottom: bottomInset),
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * 0.72,
          child: Column(
            children: [
              _ChatHeader(onClose: () => Navigator.of(context).pop()),
              Expanded(child: _messageList(context)),
              if (_error != null)
                _ChatError(
                  error: _error,
                  onRetry: _lastQuestion == null ? null : () => _send(_lastQuestion),
                  onOpenSettings: widget.onOpenSettings,
                ),
              _composer(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _messageList(BuildContext context) {
    if (_messages.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Text(
            '关于这首诗，你可以随便问。\n比如：为什么这一句最动人？',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
      );
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
      itemCount: _messages.length,
      itemBuilder: (context, index) {
        final message = _messages[index];
        return _ChatBubble(
          fromUser: message.fromUser,
          text: message.text,
          sending: _sending && !message.fromUser && message.text.isEmpty,
        );
      },
    );
  }

  Widget _composer(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: TextField(
              controller: _questionController,
              enabled: !_sending,
              minLines: 1,
              maxLines: 3,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _send(),
              decoration: const InputDecoration(
                hintText: '问问这首诗…',
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
    );
  }
}

class _ChatHeader extends StatelessWidget {
  const _ChatHeader({required this.onClose});

  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 12, 4),
      child: Row(
        children: [
          Expanded(
            child: Text('问问这首诗', style: Theme.of(context).textTheme.titleMedium),
          ),
          IconButton(
            tooltip: '关闭',
            onPressed: onClose,
            icon: const Icon(Icons.close),
          ),
        ],
      ),
    );
  }
}

class _ChatMessage {
  _ChatMessage({required this.fromUser, required this.text});

  final bool fromUser;
  String text;
}

class _ChatBubble extends StatelessWidget {
  const _ChatBubble({
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
    final background = fromUser ? scheme.primaryContainer : scheme.surfaceContainer;
    final foreground = fromUser
        ? scheme.onPrimaryContainer
        : scheme.onSurface;
    return Align(
      alignment: fromUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 320),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(16),
        ),
        child: sending
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Text(text, style: TextStyle(color: foreground)),
      ),
    );
  }
}

class _ChatError extends StatelessWidget {
  const _ChatError({
    required this.error,
    required this.onRetry,
    this.onOpenSettings,
  });

  final Object? error;
  final VoidCallback? onRetry;
  final VoidCallback? onOpenSettings;

  @override
  Widget build(BuildContext context) {
    final noKey = error is LlmException &&
        (error! as LlmException).kind == LlmErrorKind.noKey;
    if (noKey) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
        child: Row(
          children: [
            const Icon(Icons.auto_awesome_outlined, size: 20),
            const SizedBox(width: 8),
            const Expanded(child: Text('还没有配置 AI')),
            TextButton(
              onPressed: onOpenSettings,
              child: const Text('去配置'),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
      child: Row(
        children: [
          const Expanded(child: Text('暂时没能回答，请稍后再试。')),
          if (onRetry != null)
            TextButton(onPressed: onRetry, child: const Text('重试')),
        ],
      ),
    );
  }
}

Future<void> showChatSheet(
  BuildContext context, {
  required Poem poem,
  VoidCallback? onOpenSettings,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => ChatSheet(
      poem: poem,
      onOpenSettings: onOpenSettings,
    ),
  );
}

/// 个人注本条目编辑器与危险操作确认。
///
/// 编辑器不直接操作数据库表，统一通过 NotebookRepository；保存后由仓库
/// 标记 user_edited，生成服务后续可据此阻止静默覆盖。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers.dart';
import '../../domain/entities/notebook_entry.dart';

class NotebookEntryEditor extends ConsumerStatefulWidget {
  const NotebookEntryEditor({super.key, required this.entry});

  final NotebookEntry entry;

  @override
  ConsumerState<NotebookEntryEditor> createState() =>
      _NotebookEntryEditorState();
}

class _NotebookEntryEditorState extends ConsumerState<NotebookEntryEditor> {
  late final TextEditingController _controller;
  var _saving = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: _editableText(widget.entry));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String get _fieldName {
    switch (widget.entry.kind) {
      case NotebookKind.lineNote:
        return '直译 / 我的理解';
      case NotebookKind.essay:
        return '赏析大意 / 我的批注';
      case NotebookKind.chatTurn:
        return '回答 / 我的补充';
      case NotebookKind.wordNote:
        return '词语解释 / 我的理解';
      default:
        return '我的批注';
    }
  }

  Map<String, dynamic> _updatedContent() {
    final content = Map<String, dynamic>.from(widget.entry.content);
    switch (widget.entry.kind) {
      case NotebookKind.lineNote:
        content['translation'] = _controller.text;
      case NotebookKind.essay:
        content['summary'] = _controller.text;
      case NotebookKind.chatTurn:
        content['answer'] = _controller.text;
      case NotebookKind.wordNote:
        content['explain'] = _controller.text;
      default:
        content['note'] = _controller.text;
    }
    return content;
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    await ref
        .read(notebookRepositoryProvider)
        .updateUserContent(
          id: widget.entry.id,
          content: _updatedContent(),
          updatedAtMs: DateTime.now().millisecondsSinceEpoch,
        );
    if (!mounted) return;
    Navigator.of(context).pop(true);
  }

  Future<void> _delete() async {
    final first = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除这条注本？'),
        content: const Text('删除后将不再显示这条个人记录。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton.tonal(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('继续删除'),
          ),
        ],
      ),
    );
    if (first != true || !mounted) return;

    final second = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('再次确认删除'),
        content: const Text('这条注本会被永久删除，确定继续吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('保留'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('永久删除'),
          ),
        ],
      ),
    );
    if (second != true || !mounted) return;

    await ref.read(notebookRepositoryProvider).delete(widget.entry.id);
    if (mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.sizeOf(context).height * 0.68;
    return SafeArea(
      child: SizedBox(
        height: height,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '编辑个人注本',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  IconButton(
                    tooltip: '关闭',
                    onPressed: _saving ? null : () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              Text(
                _entryDescription(widget.entry),
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 16),
              Expanded(
                child: TextField(
                  controller: _controller,
                  enabled: !_saving,
                  autofocus: true,
                  expands: true,
                  maxLines: null,
                  textAlignVertical: TextAlignVertical.top,
                  decoration: InputDecoration(
                    labelText: _fieldName,
                    alignLabelWithHint: true,
                    border: const OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  TextButton.icon(
                    onPressed: _saving ? null : _delete,
                    icon: const Icon(Icons.delete_outline),
                    label: const Text('删除'),
                  ),
                  const Spacer(),
                  OutlinedButton(
                    onPressed: _saving ? null : () => Navigator.pop(context),
                    child: const Text('取消'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: _saving ? null : _save,
                    child: Text(_saving ? '保存中…' : '保存'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _editableText(NotebookEntry entry) {
  switch (entry.kind) {
    case NotebookKind.lineNote:
      return (entry.content['translation'] ?? '').toString();
    case NotebookKind.essay:
      return (entry.content['summary'] ?? '').toString();
    case NotebookKind.chatTurn:
      return (entry.content['answer'] ?? '').toString();
    case NotebookKind.wordNote:
      return (entry.content['explain'] ?? '').toString();
    default:
      return (entry.content['note'] ?? '').toString();
  }
}

String _entryDescription(NotebookEntry entry) {
  switch (entry.kind) {
    case NotebookKind.lineNote:
      return '逐句注 · 第 ${(int.tryParse(entry.target ?? '') ?? 0) + 1} 句';
    case NotebookKind.essay:
      return '整篇赏析';
    case NotebookKind.chatTurn:
      return '追问：${entry.target ?? ''}';
    case NotebookKind.wordNote:
      return '用户选词解释 · ${(entry.content['term'] ?? entry.target ?? '').toString()}';
    default:
      return entry.kind;
  }
}

Future<bool?> showNotebookEntryEditor(
  BuildContext context,
  NotebookEntry entry,
) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => NotebookEntryEditor(entry: entry),
  );
}

/// 再生成确认：普通缓存一次确认；手写条目先确认将覆盖，再二次确认。
Future<bool> confirmRegeneration(
  BuildContext context, {
  required bool userEdited,
}) async {
  final first = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('重新生成赏析？'),
      content: Text(userEdited ? '这条注本包含你的手写内容，继续会覆盖它。' : '将使用当前人格重新请求 AI。'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('继续'),
        ),
      ],
    ),
  );
  if (first != true || !userEdited || !context.mounted) return first == true;

  final second = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('最后确认覆盖手写内容'),
      content: const Text('确认后，当前个人修改将被 AI 新结果替换。'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('保留手写内容'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('确认覆盖'),
        ),
      ],
    ),
  );
  return second == true;
}

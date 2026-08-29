import 'package:flutter/material.dart';

/// 显示删除本地诗词的确认对话框。
Future<bool> confirmPoemDeletion(
  BuildContext context, {
  required String title,
}) async {
  final displayTitle = title.trim().isEmpty ? '未命名诗篇' : title.trim();
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('删除诗词？'),
      content: Text('确定要将“$displayTitle”从本地诗库删除吗？\n删除后可重新导入。'),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: const Text('取消'),
        ),
        FilledButton(
          key: const ValueKey('confirm-poem-deletion'),
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: const Text('删除'),
        ),
      ],
    ),
  );
  return confirmed == true;
}

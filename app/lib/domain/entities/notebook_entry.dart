/// 注本条目实体 + id 计算工具。
library;

import 'dart:convert';

import 'package:crypto/crypto.dart';

class NotebookKind {
  const NotebookKind._();

  static const lineNote = 'line_note';
  static const essay = 'essay';
  static const chatTurn = 'chat_turn';
  static const wordNote = 'word_note';
}

class NotebookEntry {
  const NotebookEntry({
    required this.id,
    required this.poemId,
    required this.kind,
    required this.target,
    required this.content,
    required this.persona,
    required this.userEdited,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String poemId;
  final String kind;

  /// line_note=行索引(如 "2"); essay=null; chat_turn=问题摘要
  final String? target;
  final Map<String, dynamic> content;
  final String persona;
  final bool userEdited;
  final DateTime createdAt;
  final DateTime updatedAt;

  Map<String, dynamic> toJson() => {
    'id': id,
    'poem_id': poemId,
    'kind': kind,
    'target': target,
    'content': content,
    'persona': persona,
    'user_edited': userEdited,
    'created_at': createdAt.millisecondsSinceEpoch,
    'updated_at': updatedAt.millisecondsSinceEpoch,
  };
}

/// 稳定条目 ID: sha256("$poemId|$kind|$target")
String notebookEntryId({
  required String poemId,
  required String kind,
  String? target,
}) {
  final payload = '$poemId|$kind|${target ?? ''}';
  return sha256.convert(utf8.encode(payload)).toString();
}

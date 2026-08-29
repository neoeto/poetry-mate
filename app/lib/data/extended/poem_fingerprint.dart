/// 外部作品去重指纹。
///
/// 规范与 ETL 的 poem-id 一致：先做单字繁转简，再 NFC 等价的文本清理，
/// 去掉标点和空白但保留段落边界，最后取 SHA-256 前 32 位。这里的结果
/// 只用于判断候选是否已存在，不会生成或改写公共诗库 ID。
library;

import 'dart:convert';

import 'package:crypto/crypto.dart';

import 'traditional_simplified_map.dart';

final _punctuationAndWhitespace = RegExp(
  r'[\p{P}\s\u0000-\u001F\u007F-\u009F\u200B\u200E\u200F\uFEFF]',
  unicode: true,
);

String simplifyForFingerprint(String text) {
  final buffer = StringBuffer();
  for (final rune in text.runes) {
    final char = String.fromCharCode(rune);
    buffer.write(traditionalToSimplified[char] ?? char);
  }
  return buffer.toString();
}

/// 纯文本规范化：不合并段落，不把标题或作者纳入指纹。
String stripCanonicalForFingerprint(String text) =>
    simplifyForFingerprint(text).replaceAll(_punctuationAndWhitespace, '');

String canonicalFingerprintPayload(List<String> paragraphs, {String? preface}) {
  final parts = <String>[];
  if (preface != null && preface.trim().isNotEmpty) {
    parts.add(stripCanonicalForFingerprint(preface));
  }
  parts.addAll(paragraphs.map(stripCanonicalForFingerprint));
  return parts.join('|');
}

String poemContentFingerprint(List<String> paragraphs, {String? preface}) {
  final payload = canonicalFingerprintPayload(paragraphs, preface: preface);
  return sha256.convert(utf8.encode(payload)).toString().substring(0, 32);
}

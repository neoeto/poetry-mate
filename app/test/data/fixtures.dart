/// 测试夹具: 构造领域实体(避免各测试文件重复拼字段)。
library;

import 'package:poetry_mate/domain/entities/poem.dart';

Poem testPoem({
  String id = 'test0000000000000000000000000aa',
  String author = '李白',
  String? title = '静夜思',
  String dynasty = '唐',
  String type = 'shi',
  List<String> paragraphs = const ['床前明月光，', '疑是地上霜。'],
  String? preface,
  String? rhythmic,
  double? popularity = 10.0,
}) {
  return Poem(
    id: id,
    author: author,
    title: title,
    dynasty: dynasty,
    type: type,
    paragraphs: paragraphs,
    preface: preface,
    rhythmic: rhythmic,
    popularity: popularity,
    rawText: paragraphs,
    tags: null,
    sourceCollection: 'seed',
  );
}

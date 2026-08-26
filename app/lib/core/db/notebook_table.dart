/// 注本条目表 —— schema v2 新增。
///
/// 一切 AI 生成物(逐句注/赏析/对话轮)与用户编辑的沉淀都在这里;
/// user_edited=1 的条目受保护,再生成前必须经用户确认(design D4)。
library;

import 'package:drift/drift.dart';

@DataClassName('NotebookEntryRow')
class NotebookEntries extends Table {
  /// sha256("$poemId|$kind|$target") —— 由 NotebookIds.entryId 计算
  TextColumn get id => text()();

  TextColumn get poemId => text()();

  /// line_note / essay / chat_turn
  TextColumn get kind => text()();

  /// line_note=行索引字符串; chat_turn=问题摘要; essay=null
  TextColumn get target => text().nullable()();

  /// 结构化内容 JSON(形态随 kind 而异)
  TextColumn get contentJson => text()();

  /// 生成时的人格(条目不随后续切换人格而变)
  TextColumn get persona => text()();

  BoolColumn get userEdited => boolean().withDefault(const Constant(false))();

  /// 毫秒时间戳(epoch)
  IntColumn get createdAt => integer()();

  IntColumn get updatedAt => integer()();

  @override
  Set<Column> get primaryKey => {id};
}

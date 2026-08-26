/// poems 表 —— schema v1 迁移基线。
///
/// 字段契约: openspec/changes/app-shell-and-seed/specs/seed-library/
/// 数据来源: ETL 产物(种子集/分卷),APP 侧只消费、从不计算 id。
///
/// JSON 数组字段(paragraphs/raw_text/tags)以文本列存储,
/// 实体层负责编解码; 允许 null 的字段显式 null 而非缺失(spec 硬性要求)。

library;
import 'package:drift/drift.dart';

@DataClassName('PoemRow')
class Poems extends Table {
  /// 内容寻址 ID(32 位小写 hex),由数据包下发
  TextColumn get id => text()();

  TextColumn get author => text()();

  /// 词类记录无题 → 显式 null(UI 层用词牌呈现)
  TextColumn get title => text().nullable()();

  TextColumn get dynasty => text()();

  /// 大类: shi / ci(v1 只到这两级)
  TextColumn get type => text()();

  /// 简体正文段落数组(JSON 数组序列化)
  TextColumn get paragraphsJson => text()();

  /// 上游实测无小序数据,v1 恒为 null;字段保留作契约
  TextColumn get preface => text().nullable()();

  /// 词牌(仅词有)
  TextColumn get rhythmic => text().nullable()();

  /// 归一热度 log10 和,3 位小数;无 rank 数据 → null
  RealColumn get popularity => real().nullable()();

  /// 转换前原文留档(JSON 数组序列化,与 paragraphs_json 平行等长)
  TextColumn get rawTextJson => text()();

  /// 上游稀疏题材标签(JSON 数组序列化,无则 null)
  TextColumn get tagsJson => text().nullable()();

  TextColumn get sourceCollection => text()();

  @override
  Set<Column> get primaryKey => {id};
}

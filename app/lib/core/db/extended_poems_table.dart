/// 用户明确保存的 AI 外部作品。
///
/// 与 poems 公共数据表分离：扩展作品是本机用户资产，不参与 ETL 重灌。
library;

import 'package:drift/drift.dart';

@DataClassName('ExtendedPoemRow')
class ExtendedPoems extends Table {
  /// ext-fingerprint，与公共诗库 ID 使用独立命名空间。
  TextColumn get id => text()();

  /// 正文/序文规范化后的去重指纹。
  TextColumn get fingerprint => text().unique()();

  TextColumn get title => text()();
  TextColumn get author => text().nullable()();
  TextColumn get period => text().nullable()();
  TextColumn get genre => text()();
  TextColumn get paragraphsJson => text()();
  TextColumn get preface => text().nullable()();
  TextColumn get rhythmic => text().nullable()();
  TextColumn get source => text().nullable()();
  TextColumn get sourceConfidence => text()();
  TextColumn get uncertainFieldsJson => text()();
  TextColumn get recommendation => text().withDefault(const Constant(''))();
  IntColumn get createdAt => integer()();

  @override
  Set<Column> get primaryKey => {id};
}

/// 应用数据库 —— schema v1 迁移基线。
///
/// 后续版本只允许在 [migration] 中追加 step,禁止修改历史。
/// 构造器接受任意 QueryExecutor,便于测试注入内存数据库。

library;
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';

import 'poems_table.dart';

part 'app_database.g.dart';

@DriftDatabase(tables: [Poems])
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.e);

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) => m.createAll(),
        onUpgrade: (m, from, to) async {
          // schema v1 基线;后续变更在此按版本追加 step
        },
      );
}

/// 生产环境连接器: 文件库 + 后台线程执行。
/// (真实路径解析依赖 path_provider,由 data 层组装;此处保持纯函数可测。)
QueryExecutor openNativeConnection(File dbFile) =>
    NativeDatabase.createInBackground(dbFile);

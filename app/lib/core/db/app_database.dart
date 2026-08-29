/// 应用数据库 —— schema v1 迁移基线。
///
/// 后续版本只允许在 [migration] 中追加 step,禁止修改历史。
/// 构造器接受任意 QueryExecutor,便于测试注入内存数据库。

library;

import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';

import 'extended_poems_table.dart';
import 'favorites_table.dart';
import 'notebook_table.dart';
import 'poems_table.dart';

part 'app_database.g.dart';

@DriftDatabase(tables: [Poems, NotebookEntries, Favorites, ExtendedPoems])
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.e);

  @override
  int get schemaVersion => 3;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) => m.createAll(),
    onUpgrade: (m, from, to) async {
      // v1 → v2: 新增注本与收藏两表(reader-ai-annotation 变更)
      if (from < 2) {
        await m.createTable(notebookEntries);
        await m.createTable(favorites);
      }
      // v2 → v3: 用户保存的 AI 外部作品独立存储。
      if (from < 3) {
        await m.createTable(extendedPoems);
      }
    },
  );
}

/// 生产环境连接器: 文件库 + 后台线程执行。
/// (真实路径解析依赖 path_provider,由 data 层组装;此处保持纯函数可测。)
QueryExecutor openNativeConnection(File dbFile) =>
    NativeDatabase.createInBackground(dbFile);

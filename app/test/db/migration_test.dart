// 迁移测试: v1 库文件 → 打开后升级到 v3,旧数据保留+新表就位。
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:poetry_mate/core/db/app_database.dart';
import 'package:sqlite3/sqlite3.dart' as sql;

void main() {
  late Directory tempDir;
  late File dbFile;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('poetry_migration');
    dbFile = File('${tempDir.path}/poetry.db');
  });
  tearDown(() async {
    await tempDir.delete(recursive: true);
  });

  /// 手工构造一个"schema v1"数据库(仅 poems 表 + user_version=1)
  void createRawV1() {
    final db = sql.sqlite3.open(dbFile.path);
    db.execute('''
      CREATE TABLE "poems" (
        "id" TEXT NOT NULL PRIMARY KEY,
        "author" TEXT NOT NULL,
        "title" TEXT NULL,
        "dynasty" TEXT NOT NULL,
        "type" TEXT NOT NULL,
        "paragraphs_json" TEXT NOT NULL,
        "preface" TEXT NULL,
        "rhythmic" TEXT NULL,
        "popularity" REAL NULL,
        "raw_text_json" TEXT NOT NULL,
        "tags_json" TEXT NULL,
        "source_collection" TEXT NOT NULL
      )
    ''');
    db.execute('INSERT INTO poems VALUES (?,?,?,?,?,?,?,?,?,?,?,?)', [
      'legacy001',
      '李白',
      '靜夜思',
      '唐',
      'shi',
      '["床前明月光"]',
      null,
      null,
      null,
      '["床前明月光"]',
      null,
      'seed',
    ]);
    db.execute('PRAGMA user_version = 1');
    db.close();
  }

  test('v1 → v3: 新表建立且旧诗行保留', () async {
    createRawV1();

    final db = AppDatabase(NativeDatabase(dbFile));
    addTearDown(db.close);

    // 触发打开与迁移
    await db.customSelect('SELECT 1').get();

    expect(db.schemaVersion, 3);

    // 旧诗行保留
    final oldRows = await db.select(db.poems).get();
    expect(oldRows, hasLength(1));
    expect(oldRows.first.id, 'legacy001');

    // 既有注本/收藏表与 v3 扩展作品表均可查询
    expect(await db.select(db.notebookEntries).get(), isEmpty);
    expect(await db.select(db.favorites).get(), isEmpty);
    expect(await db.select(db.extendedPoems).get(), isEmpty);
  });

  test('全新安装直接建出 v3 全部表', () async {
    final db = AppDatabase(NativeDatabase(dbFile));
    addTearDown(db.close);

    await db.select(db.notebookEntries).get();
    await db.select(db.favorites).get();
    await db.select(db.extendedPoems).get();
    expect(db.schemaVersion, 3);
  });
}

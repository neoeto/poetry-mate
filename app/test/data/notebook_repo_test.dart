// NotebookRepository 测试(任务 2.2):
// upsert / byTarget 缓存命中 / byPoem 与 listAll 排序 / updateUserContent 保护语义 / delete。
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:poetry_mate/core/db/app_database.dart';
import 'package:poetry_mate/data/repositories/notebook_repository.dart';
import 'package:poetry_mate/domain/entities/notebook_entry.dart';

void main() {
  late AppDatabase db;
  late DriftNotebookRepository repo;

  NotebookEntry entry({
    required String id,
    String poemId = 'poem1',
    String kind = NotebookKind.lineNote,
    String? target = '0',
    Map<String, dynamic>? content,
    bool userEdited = false,
  }) {
    final now = DateTime.fromMillisecondsSinceEpoch(1700000000000);
    return NotebookEntry(
      id: id,
      poemId: poemId,
      kind: kind,
      target: target,
      content: content ??
          {'translation': '直译内容', 'notes': [
            {'term': '锁', 'explain': '凝滞感'}
          ]},
      persona: 'zhiyin',
      userEdited: userEdited,
      createdAt: now,
      updatedAt: now,
    );
  }

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = DriftNotebookRepository(db);
  });
  tearDown(() => db.close());

  test('upsert + byTarget: 写入后按目标命中', () async {
    final e = entry(
      id: notebookEntryId(poemId: 'poem1', kind: NotebookKind.lineNote, target: '0'),
    );
    await repo.upsert(e);

    final hit = await repo.byTarget(
        poemId: 'poem1', kind: NotebookKind.lineNote, target: '0');
    expect(hit?.id, e.id);
    expect(hit?.content['translation'], '直译内容');

    final miss = await repo.byTarget(
        poemId: 'poem1', kind: NotebookKind.lineNote, target: '9');
    expect(miss, isNull);
  });

  test('同目标重复生成 → upsert 覆盖不重复', () async {
    final id = notebookEntryId(
        poemId: 'poem1',
        kind: NotebookKind.lineNote,
        target: '0',
      );
    await repo.upsert(entry(id: id));
    await repo.upsert(entry(id: id, content: {'translation': '新版'}));

    final all = await repo.byPoem('poem1');
    expect(all, hasLength(1));
    expect(all.first.content['translation'], '新版');
  });

  test('listAll 按 updated_at 倒序', () async {
    final old = NotebookEntry(
      id: 'old',
      poemId: 'p',
      kind: NotebookKind.lineNote,
      target: '0',
      content: {},
      persona: 'zhiyin',
      userEdited: false,
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );
    final newer = NotebookEntry(
      id: 'newer',
      poemId: 'p',
      kind: NotebookKind.essay,
      target: null,
      content: {'summary': 'x'},
      persona: 'zhiyin',
      userEdited: false,
      createdAt: DateTime(2027),
      updatedAt: DateTime(2027),
    );
    await repo.upsert(old);
    await repo.upsert(newer);

    final all = await repo.listAll();
    expect(all.first.id, 'newer');
  });

  test('updateUserContent 标记 user_edited 并更新时间', () async {
    final e = entry(id: 'e1', target: '0');
    await repo.upsert(e);
    final later = DateTime(2028);

    await repo.updateUserContent(
      id: 'e1',
      content: {'translation': '用户自己的理解'},
      updatedAtMs: later.millisecondsSinceEpoch,
    );

    final updated = await repo.byIdTarget();
    expect(updated!.userEdited, isTrue);
    expect(updated.content['translation'], '用户自己的理解');
  });

  test('delete 移除条目', () async {
    await repo.upsert(entry(id: 'd1'));
    await repo.delete('d1');
    expect(await repo.listAll(), isEmpty);
  });
}

extension on DriftNotebookRepository {
  Future<NotebookEntry?> byIdTarget() async {
    // 测试辅助: 通过 listAll 找到唯一条目(避免暴露内部接口)
    final all = await listAll();
    return all.isEmpty ? null : all.first;
  }
}

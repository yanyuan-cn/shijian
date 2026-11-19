/// 数据层真机替代测试：在 Windows 上用 sqlite3 的 ffi 实现跑同一份 schema。
/// 目的不是覆盖率，而是确认「建表 → 写入 → 查询 → 搜索 → 软删」这条链在同构的
/// SQLite 上成立 —— 这是手机上最容易在启动瞬间炸掉的一段代码。
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shijian/data/blob_store.dart';
import 'package:shijian/data/db.dart';
import 'package:shijian/data/repo.dart';
import 'package:shijian/data/seed.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  late Directory dir;
  late Repo repo;

  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('shijian_test');
    final db = await Db.open(dir.path);
    final blobs = await BlobStore.open(dir);
    repo = Repo(db, blobs);
  });

  tearDown(() async {
    await Db.close();
    if (dir.existsSync()) dir.deleteSync(recursive: true);
  });

  test('建表 + 种子写入 + 列表', () async {
    final items = seedItems();
    for (final it in items) {
      await repo.upsert(it, kind: 'create');
    }
    final all = await repo.listAll();
    expect(all.length, items.length);
    expect(all.map((e) => e.title), contains('三体'));
    final book = all.firstWhere((e) => e.title == '三体');
    expect(book.meta['c1'], isNotNull);
  });

  test('搜索命中标题与作者', () async {
    for (final it in seedItems()) {
      await repo.upsert(it, kind: 'create');
    }
    expect((await repo.search('三体')).isNotEmpty, true);
    expect((await repo.search('刘慈欣')).isNotEmpty, true);
    expect((await repo.search('不存在的东西zzz')).isEmpty, true);
  });

  test('软删除后默认查不到', () async {
    final items = seedItems();
    for (final it in items) {
      await repo.upsert(it, kind: 'create');
    }
    final first = (await repo.listAll()).first;
    await repo.remove(first.id);
    final after = await repo.listAll();
    expect(after.length, items.length - 1);
    expect(after.any((e) => e.id == first.id), false);
    final withDeleted = await repo.listAll(includeDeleted: true);
    expect(withDeleted.any((e) => e.id == first.id), true);
  });

  test('标签进关系表', () async {
    for (final it in seedItems()) {
      await repo.upsert(it, kind: 'create');
    }
    final tags = await repo.allTags();
    expect(tags.isNotEmpty, true);
  });
}

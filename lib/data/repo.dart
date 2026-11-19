/// 数据访问层。所有 SQL 都在这里，UI 不许直接碰 Database。
library;

import 'package:sqflite/sqflite.dart';

import '../core/ids.dart';
import '../core/model.dart';
import 'blob_store.dart';

class Repo {
  Repo(this.db, this.blobs);

  final Database db;
  final BlobStore blobs;

  static const _cols = 'id,type,title,creator,year,cover,rating,status,note,'
      'source_url,meta,added_at,updated_at,deleted,device_id,rev';

  Future<List<Item>> listAll({bool includeDeleted = false}) async {
    final rows = await db.query('item',
        columns: _cols.split(','),
        where: includeDeleted ? null : 'deleted = 0',
        orderBy: 'added_at DESC');
    return rows.map(Item.fromRow).toList();
  }

  Future<Item?> byId(String id) async {
    final rows = await db.query('item',
        columns: _cols.split(','), where: 'id = ?', whereArgs: [id], limit: 1);
    if (rows.isEmpty) return null;
    return Item.fromRow(rows.first);
  }

  /// 写入或更新。同时追加 oplog —— 同步靠它，不靠猜。
  Future<void> upsert(Item it, {String kind = 'update'}) async {
    await db.transaction((tx) async {
      await tx.insert('item', it.toRow(),
          conflictAlgorithm: ConflictAlgorithm.replace);
      await tx.insert('oplog', {
        'item_id': it.id,
        'kind': kind,
        'at': it.updatedAt,
        'device': it.deviceId,
      });
      await _syncTags(tx, it);
    });
  }

  /// 标签以 item.meta['tags'] 的逗号串为准（UI 简单），额外写进
  /// tag / item_tag 两张关系表，供以后按标签跨板块筛选。
  Future<void> _syncTags(DatabaseExecutor tx, Item it) async {
    await tx.delete('item_tag', where: 'item_id = ?', whereArgs: [it.id]);
    final raw = it.metaStr('tags') ?? '';
    final names = raw
        .split(RegExp(r'[,，;；、\s]+'))
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toSet();
    for (final name in names) {
      final found = await tx.query('tag',
          columns: ['id'], where: 'name = ?', whereArgs: [name], limit: 1);
      final tagId =
          found.isEmpty ? Ids.ulid() : (found.first['id'] as String);
      if (found.isEmpty) {
        await tx.insert('tag', {'id': tagId, 'name': name, 'color': null});
      }
      await tx.insert('item_tag', {'item_id': it.id, 'tag_id': tagId},
          conflictAlgorithm: ConflictAlgorithm.ignore);
    }
  }

  /// 软删除：留墓碑，别真删 —— 以后同步要靠它知道「这条被删了」。
  Future<void> remove(String id, {String device = ''}) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await db.transaction((tx) async {
      await tx.update('item', {'deleted': 1, 'updated_at': now},
          where: 'id = ?', whereArgs: [id]);
      await tx.insert('oplog',
          {'item_id': id, 'kind': 'delete', 'at': now, 'device': device});
    });
  }

  Future<List<Item>> search(String q) async {
    final k = '%${q.trim()}%';
    if (q.trim().isEmpty) return const [];
    final rows = await db.query('item',
        columns: _cols.split(','),
        where: 'deleted = 0 AND (title LIKE ? OR creator LIKE ? OR note LIKE ? '
            'OR meta LIKE ? OR source_url LIKE ?)',
        whereArgs: [k, k, k, k, k],
        orderBy: 'added_at DESC',
        limit: 300);
    return rows.map(Item.fromRow).toList();
  }

  Future<List<String>> allTags() async {
    final rows = await db.rawQuery(
        'SELECT t.name AS n, COUNT(it.item_id) AS c FROM tag t '
        'JOIN item_tag it ON it.tag_id = t.id ORDER BY c DESC, n LIMIT 60');
    return rows.map((e) => e['n'] as String).toList();
  }

  Future<int> countOf(String type) async {
    final r = await db.rawQuery(
        'SELECT COUNT(*) AS c FROM item WHERE type = ? AND deleted = 0',
        [type]);
    return (r.first['c'] as num?)?.toInt() ?? 0;
  }

  // ---------- 附件 ----------
  Future<List<Asset>> assetsOf(String itemId) async {
    final rows = await db.query('asset',
        where: 'item_id = ?', whereArgs: [itemId], orderBy: 'is_primary DESC');
    return rows.map(Asset.fromRow).toList();
  }

  Future<Asset> addAsset({
    required String? itemId,
    required String role,
    required String hash,
    String? mime,
    String? name,
    int size = 0,
    bool primary = false,
  }) async {
    final a = Asset(
      id: Ids.ulid(),
      itemId: itemId,
      role: role,
      hash: hash,
      path: blobs.relPath(hash),
      size: size,
      mime: mime,
      name: name,
      isPrimary: primary,
    );
    await db.insert('asset', a.toRow(),
        conflictAlgorithm: ConflictAlgorithm.replace);
    return a;
  }

  /// 导入时原样恢复一条 asset（id/hash/path 都不变），重复覆盖。
  Future<void> restoreAsset(Asset a) async {
    await db.insert('asset', a.toRow(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  /// 所有还在用的哈希，用于 gc。
  Future<Set<String>> liveHashes() async {
    final s = <String>{};
    final c = await db.rawQuery(
        'SELECT DISTINCT cover FROM item WHERE cover IS NOT NULL');
    for (final r in c) {
      final v = r['cover'] as String?;
      if (v != null && v.isNotEmpty) s.add(v);
    }
    final a = await db.rawQuery('SELECT DISTINCT hash FROM asset');
    for (final r in a) {
      final v = r['hash'] as String?;
      if (v != null && v.isNotEmpty) s.add(v);
    }
    return s;
  }

  // ---------- 数据源匹配记录 ----------
  Future<void> saveExternal({
    required String itemId,
    required String provider,
    required String externalId,
    String? title,
    String? payload,
  }) async {
    await db.insert(
      'item_external',
      {
        'item_id': itemId,
        'provider': provider,
        'external_id': externalId,
        'title': title,
        'payload': payload,
        'matched_at': DateTime.now().millisecondsSinceEpoch,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<Map<String, Object?>?> externalOf(String itemId) async {
    final r = await db.query('item_external',
        where: 'item_id = ?', whereArgs: [itemId], limit: 1);
    return r.isEmpty ? null : r.first;
  }

  Future<void> exportSnapshot() async {}
}

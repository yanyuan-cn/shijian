/// SQLite 表结构与迁移。
///
/// 铁律：schema_version 一旦发版就只能往上加，不能改历史建表语句。
/// 每加一个版本，就在 [_migrateStep] 里补一个 case；否则老用户升级即崩。
library;

import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

const int kSchemaVersion = 1;

const String _createItem = '''
CREATE TABLE item(
  id         TEXT PRIMARY KEY,
  type       TEXT NOT NULL,
  title      TEXT NOT NULL,
  creator    TEXT,
  year       TEXT,
  cover      TEXT,
  rating     TEXT,
  status     TEXT,
  note       TEXT,
  source_url TEXT,
  meta       TEXT NOT NULL DEFAULT '{}',
  added_at   INTEGER NOT NULL,
  updated_at INTEGER NOT NULL,
  deleted    INTEGER NOT NULL DEFAULT 0,
  device_id  TEXT NOT NULL DEFAULT '',
  rev        INTEGER NOT NULL DEFAULT 0
)''';

const String _createAsset = '''
CREATE TABLE asset(
  id         TEXT PRIMARY KEY,
  item_id    TEXT,
  role       TEXT NOT NULL,
  hash       TEXT NOT NULL,
  path       TEXT NOT NULL,
  size       INTEGER NOT NULL DEFAULT 0,
  mime       TEXT,
  name       TEXT,
  is_primary INTEGER NOT NULL DEFAULT 0
)''';

const String _createTag = '''
CREATE TABLE tag(
  id    TEXT PRIMARY KEY,
  name  TEXT NOT NULL UNIQUE,
  color TEXT
)''';

const String _createItemTag = '''
CREATE TABLE item_tag(
  item_id TEXT NOT NULL,
  tag_id  TEXT NOT NULL,
  PRIMARY KEY(item_id, tag_id)
)''';

const String _createExternal = '''
CREATE TABLE item_external(
  item_id     TEXT NOT NULL,
  provider    TEXT NOT NULL,
  external_id TEXT NOT NULL,
  title       TEXT,
  payload     TEXT,
  matched_at  INTEGER NOT NULL,
  PRIMARY KEY(item_id, provider)
)''';

const String _createOpLog = '''
CREATE TABLE oplog(
  id      INTEGER PRIMARY KEY AUTOINCREMENT,
  item_id TEXT NOT NULL,
  kind    TEXT NOT NULL,
  at      INTEGER NOT NULL,
  device  TEXT NOT NULL
)''';

class Db {
  Db._();

  static Database? _db;

  static Future<Database> open(String dir) async {
    final existing = _db;
    if (existing != null) return existing;
    final path = p.join(dir, 'shijian.db');
    final db = await openDatabase(
      path,
      version: kSchemaVersion,
      onConfigure: (d) async {
        await d.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: _create,
      onUpgrade: _upgrade,
    );
    _db = db;
    return db;
  }

  static Future<Database> get instance async {
    final db = _db;
    if (db == null) throw StateError('Db.open() 还没调用');
    return db;
  }

  static Future<void> close() async {
    await _db?.close();
    _db = null;
  }

  static Future<void> _create(Database db, int version) async {
    await db.execute(_createItem);
    await db.execute(_createAsset);
    await db.execute(_createTag);
    await db.execute(_createItemTag);
    await db.execute(_createExternal);
    await db.execute(_createOpLog);
    await db.execute(
        'CREATE INDEX ix_item_type ON item(type, deleted, added_at DESC)');
    await db.execute('CREATE INDEX ix_item_updated ON item(updated_at)');
    await db.execute('CREATE INDEX ix_item_title ON item(title)');
    await db.execute('CREATE INDEX ix_asset_item ON asset(item_id)');
    await db.execute('CREATE INDEX ix_asset_hash ON asset(hash)');
  }

  static Future<void> _upgrade(Database db, int from, int to) async {
    for (var v = from + 1; v <= to; v++) {
      await _migrateStep(db, v);
    }
  }

  /// 每个版本一个 case。第一次正式发版之后，任何表结构改动都必须在这里
  /// 补一段 ALTER，否则升级的用户会直接崩在启动。
  static Future<void> _migrateStep(Database db, int v) async {
    switch (v) {
      // case 2:
      //   await db.execute('ALTER TABLE item ADD COLUMN xyz TEXT');
      //   break;
      default:
        break;
    }
  }
}

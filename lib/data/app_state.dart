/// 全局状态。一个 ChangeNotifier 单例，够用就行 —— 这个量级的应用
/// 引 provider / riverpod 只会增加一层看不懂的东西。
library;

import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../core/ids.dart';
import '../core/model.dart';
import 'blob_store.dart';
import 'db.dart';
import 'repo.dart';
import 'seed.dart';
import 'settings.dart';

class App extends ChangeNotifier {
  App._();
  static final App I = App._();

  late final Repo repo;
  late final BlobStore blobs;
  late final Directory supportDir;

  bool ready = false;
  String? error;
  List<Item> all = const [];

  Future<void> init() async {
    try {
      await Settings.init();
      supportDir = await getApplicationSupportDirectory();
      blobs = await BlobStore.open(supportDir);
      final db = await Db.open(supportDir.path);
      repo = Repo(db, blobs);
      await _maybeSeed();
      await reload();
    } catch (e, st) {
      error = '$e\n$st';
      debugPrint('初始化失败: $error');
    }
    ready = true;
    notifyListeners();
  }

  Future<void> _maybeSeed() async {
    // getBool 在键不存在时返回 null，不能写成 !getBool(...)! —— 那会首启崩溃。
    if (Settings.getBool('seeded') != true) {
      try {
        final existing = await repo.listAll();
        if (existing.isEmpty) {
          for (final it in seedItems()) {
            await repo.upsert(it.copyWith(), kind: 'create');
          }
        }
      } catch (e) {
        debugPrint('种子数据失败（不影响使用）: $e');
      }
      await Settings.setBool('seeded', true);
    }
  }

  Future<void> reload() async {
    all = await repo.listAll();
    notifyListeners();
  }

  List<Item> of(String type) =>
      all.where((e) => e.type == type).toList(growable: false);

  Item? byId(String id) {
    for (final e in all) {
      if (e.id == id) return e;
    }
    return null;
  }

  /// 新建条目：自动补 id / 时间戳 / 设备标识。
  Future<Item> create({
    required String type,
    required Map<String, dynamic> values,
    String? coverHash,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final it = Item(
      id: Ids.ulid(),
      type: type,
      title: (values['title'] as String?)?.trim() ?? '',
      creator: _s(values['creator']),
      year: _s(values['year']),
      cover: coverHash,
      rating: _s(values['rating']),
      status: _s(values['status']),
      note: _s(values['note']),
      sourceUrl: _s(values['source_url']),
      meta: Map<String, dynamic>.from(values['meta'] as Map? ?? const {}),
      addedAt: now,
      updatedAt: now,
      deviceId: Settings.deviceId,
      rev: 1,
    );
    await repo.upsert(it, kind: 'create');
    await reload();
    return it;
  }

  Future<Item> save(Item it, Map<String, dynamic> values,
      {String? coverHash, bool clearCover = false}) async {
    final next = it.copyWith(
      title: (values['title'] as String?)?.trim() ?? it.title,
      creator: _s(values['creator']),
      year: _s(values['year']),
      rating: _s(values['rating']),
      status: _s(values['status']),
      note: _s(values['note']),
      sourceUrl: _s(values['source_url']),
      meta: Map<String, dynamic>.from(values['meta'] as Map? ?? const {}),
      cover: coverHash,
      clearCover: clearCover,
      updatedAt: DateTime.now().millisecondsSinceEpoch,
      rev: it.rev + 1,
    );
    await repo.upsert(next);
    await reload();
    return next;
  }

  Future<void> delete(String id) async {
    await repo.remove(id, device: Settings.deviceId);
    await reload();
  }

  Future<String?> putCover(List<int> bytes) async {
    if (bytes.isEmpty) return null;
    return blobs.put(Uint8List.fromList(bytes));
  }

  static String? _s(Object? v) {
    if (v == null) return null;
    final s = v.toString().trim();
    return s.isEmpty ? null : s;
  }
}

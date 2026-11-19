/// 内容寻址的二进制仓库。
///
/// 文件名就是 sha256（不带扩展名），所以：
///  · 同一个文件重复上传只占一份空间；
///  · 哈希 → 路径是一一对应，不需要查表；
///  · 导出/同步时 blob 名天然稳定，两台设备拿到同一个文件就是同一个名字。
///
/// mime 与原始文件名不进文件名，存在 asset 表里；分享时才把文件名补回去。
library;

import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;

class BlobStore {
  BlobStore(this.root);

  /// 形如 <appSupport>/blobs
  final Directory root;

  static Future<BlobStore> open(Directory base) async {
    final d = Directory(p.join(base.path, 'blobs'));
    if (!await d.exists()) await d.create(recursive: true);
    return BlobStore(d);
  }

  String relPath(String hash) =>
      p.join(hash.substring(0, 2), hash.substring(2, 4), hash);

  File fileOf(String hash) => File(p.join(root.path, relPath(hash)));

  bool exists(String? hash) {
    if (hash == null || hash.isEmpty) return false;
    return fileOf(hash).existsSync();
  }

  /// 写入字节，返回 sha256。已经存在则直接返回哈希，不重复写盘。
  Future<String> put(Uint8List bytes) async {
    final hash = sha256.convert(bytes).toString();
    final f = fileOf(hash);
    if (await f.exists()) return hash;
    await f.parent.create(recursive: true);
    // 先写临时文件再改名：避免写到一半被杀进程留下半截文件
    final tmp = File('${f.path}.tmp');
    await tmp.writeAsBytes(bytes, flush: true);
    await tmp.rename(f.path);
    return hash;
  }

  /// 从已有文件导入（电子书、大图），不把整个文件读进内存以外的额外副本。
  Future<String> putFile(File src) async {
    final bytes = await src.readAsBytes();
    return put(bytes);
  }

  /// 导出成带真实文件名和扩展名的临时文件，用于分享 / 存相册 / 设壁纸。
  /// 返回的文件放在 cacheDir 下，调用方不需要（也不应该）长期持有。
  Future<File> exportTemp(
    String hash, {
    required String name,
    Directory? cache,
  }) async {
    final src = fileOf(hash);
    if (!await src.exists()) {
      throw StateError('blob 不存在: $hash');
    }
    final dir = Directory(p.join((cache ?? Directory.systemTemp).path,
        'export'));
    if (!await dir.exists()) await dir.create(recursive: true);
    final safe = _safeName(name);
    final dst = File(p.join(dir.path, safe));
    await src.copy(dst.path);
    return dst;
  }

  Future<void> delete(String? hash) async {
    if (hash == null || hash.isEmpty) return;
    final f = fileOf(hash);
    if (await f.exists()) await f.delete();
  }

  /// 已用字节数（「我的」页显示）。
  Future<int> usage() async {
    var total = 0;
    if (!await root.exists()) return 0;
    await for (final e in root.list(recursive: true, followLinks: false)) {
      if (e is File) {
        total += await e.length();
      }
    }
    return total;
  }

  /// 清理没有任何数据库记录引用的孤儿文件。
  /// 传入所有在用的哈希（item.cover + asset.hash）。
  Future<int> gc(Set<String> live) async {
    var removed = 0;
    if (!await root.exists()) return 0;
    await for (final e in root.list(recursive: true, followLinks: false)) {
      if (e is! File) continue;
      final name = p.basename(e.path);
      if (name.endsWith('.tmp')) {
        await e.delete();
        removed++;
        continue;
      }
      if (!live.contains(name)) {
        await e.delete();
        removed++;
      }
    }
    return removed;
  }

  static String _safeName(String name) {
    var n = name.replaceAll(RegExp(r'[\\/:*?"<>|\x00-\x1F]'), '_').trim();
    if (n.isEmpty) n = 'file';
    if (n.length > 80) {
      final dot = n.lastIndexOf('.');
      final ext = dot > 0 ? n.substring(dot) : '';
      n = n.substring(0, 80 - ext.length) + ext;
    }
    return n;
  }
}

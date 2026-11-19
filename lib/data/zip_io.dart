/// 备份与迁移：一个 zip 就是整个库。
///
/// 布局（和将来桌面端/同步共用同一套，不要改）：
///   library.json           元数据 + schema_version + 每条 blob 的 hash
///   blobs/<sha256>         内容寻址的二进制，文件名就是哈希
///
/// 为什么不做增量：个人库几万个文件也就几百 MB，全量最简单也最不会出错。
library;

import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../core/model.dart';
import '../platform/image_out.dart';
import '../ui/kit.dart';
import '../ui/theme.dart';
import 'app_state.dart';
import 'db.dart';
import 'settings.dart';

Future<void> showIoSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (c) => Container(
      decoration: const BoxDecoration(
        color: C.panel,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('导入 / 导出', style: T.sectionTitle),
          const SizedBox(height: 6),
          Text(
            '导出会打包成 zip（含图片与电子书），可以存网盘、换手机。\n'
            '导入按 id 合并，同一条以较新的为准，不会覆盖你后来改过的东西。',
            style: T.small.copyWith(height: 1.7),
          ),
          const SizedBox(height: 18),
          _btn(Icons.upload_file_outlined, '导出全部（zip）', () {
            Navigator.pop(c);
            exportLibrary(context);
          }),
          const SizedBox(height: 10),
          _btn(Icons.download_outlined, '从 zip 导入', () {
            Navigator.pop(c);
            importLibrary(context);
          }),
          if (Settings.lastBackupAt > 0) ...[
            const SizedBox(height: 14),
            Text('上次导出：${fmtDateFull(Settings.lastBackupAt)}', style: T.small),
          ],
        ],
      ),
    ),
  );
}

Widget _btn(IconData ic, String label, VoidCallback onTap) => InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        decoration: BoxDecoration(
          color: C.panel2,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: C.line),
        ),
        child: Row(
          children: [
            Icon(ic, size: 19, color: C.accent2),
            const SizedBox(width: 12),
            Text(label, style: const TextStyle(fontSize: 14, color: C.text)),
            const Spacer(),
            const Icon(Icons.chevron_right, size: 18, color: C.text3),
          ],
        ),
      ),
    );

Future<void> exportLibrary(BuildContext context) async {
  final messenger = ScaffoldMessenger.maybeOf(context);
  messenger?.showSnackBar(const SnackBar(
    content: Text('正在打包…'),
    duration: Duration(seconds: 60),
  ));
  try {
    final items = App.I.all;
    final assets = <Asset>[];
    for (final it in items) {
      assets.addAll(await App.I.repo.assetsOf(it.id));
    }
    final hashes = <String>{
      for (final it in items)
        if (it.cover != null && it.cover!.isNotEmpty) it.cover!,
      for (final a in assets) a.hash,
    };

    final archive = Archive();
    final manifest = jsonEncode({
      'app': 'shijian',
      'schema_version': kSchemaVersion,
      'exported_at': DateTime.now().toIso8601String(),
      'items': [for (final it in items) it.toRow()],
      'assets': [for (final a in assets) a.toRow()],
      'blobs': hashes.toList(),
    });
    final mBytes = utf8.encode(manifest);
    archive.addFile(ArchiveFile('library.json', mBytes.length, mBytes));

    for (final h in hashes) {
      final f = App.I.blobs.fileOf(h);
      if (!await f.exists()) continue;
      final bytes = await f.readAsBytes();
      archive.addFile(ArchiveFile('blobs/$h', bytes.length, bytes));
    }

    final zip = ZipEncoder().encodeBytes(archive);
    final dir = await getTemporaryDirectory();
    final d = DateTime.now();
    final name = 'shijian-${d.year}'
        '${d.month.toString().padLeft(2, '0')}'
        '${d.day.toString().padLeft(2, '0')}-'
        '${d.hour.toString().padLeft(2, '0')}'
        '${d.minute.toString().padLeft(2, '0')}.zip';
    final out = File(p.join(dir.path, name));
    await out.writeAsBytes(zip, flush: true);

    Settings.lastBackupAt = DateTime.now().millisecondsSinceEpoch;
    messenger?.hideCurrentSnackBar();
    final ok = await shareFile(out.path,
        mime: 'application/zip', title: '拾间备份');
    messenger?.showSnackBar(SnackBar(
      content: Text(ok
          ? '已生成 ${items.length} 条 · ${fmtBytes(zip.length)}'
          : '已存到 ${out.path}'),
      duration: const Duration(seconds: 4),
    ));
  } catch (e) {
    messenger?.hideCurrentSnackBar();
    messenger?.showSnackBar(SnackBar(content: Text('导出失败：$e')));
  }
}

Future<void> importLibrary(BuildContext context) async {
  final res = await FilePicker.pickFiles(
    type: FileType.custom,
    allowedExtensions: ['zip'],
  );
  final path = res.isEmpty ? null : res.single.path;
  if (path == null) return;
  if (!context.mounted) return;

  final messenger = ScaffoldMessenger.maybeOf(context);
  messenger?.showSnackBar(const SnackBar(
    content: Text('正在导入…'),
    duration: Duration(seconds: 60),
  ));
  try {
    final bytes = await File(path).readAsBytes();
    final archive = ZipDecoder().decodeBytes(bytes);
    ArchiveFile? manifestFile;
    for (final f in archive.files) {
      if (f.name == 'library.json') manifestFile = f;
    }
    if (manifestFile == null) {
      throw StateError('这个 zip 里没有 library.json，可能不是拾间的备份');
    }
    final manifest = jsonDecode(
            utf8.decode(manifestFile.readBytes()!, allowMalformed: true))
        as Map<String, dynamic>;
    final ver = (manifest['schema_version'] as num?)?.toInt() ?? 1;
    if (ver > kSchemaVersion) {
      throw StateError('备份来自更新的版本（schema $ver），先升级 App');
    }

    var added = 0, updated = 0, skipped = 0;
    final items = (manifest['items'] as List?) ?? const [];
    for (final raw in items) {
      final row = Map<String, dynamic>.from(raw as Map);
      final it = Item.fromRow(row);
      final old = await App.I.repo.byId(it.id);
      if (old == null) {
        await App.I.repo.upsert(it, kind: 'import');
        added++;
      } else if (it.updatedAt > old.updatedAt) {
        await App.I.repo.upsert(it, kind: 'import');
        updated++;
      } else {
        skipped++;
      }
    }

    // blob 只写不存在的，天然去重
    var blobs = 0;
    for (final f in archive.files) {
      if (!f.name.startsWith('blobs/')) continue;
      final hash = f.name.substring(6);
      if (hash.isEmpty) continue;
      if (await App.I.blobs.fileOf(hash).exists()) continue;
      final data = f.readBytes();
      if (data == null) continue;
      await App.I.blobs.put(data);
      blobs++;
    }

    // 资产表（电子书、多图）按原样补回去
    for (final raw in (manifest['assets'] as List?) ?? const []) {
      final a = Asset.fromRow(Map<String, Object?>.from(raw as Map));
      await App.I.repo.restoreAsset(a);
    }

    await App.I.reload();
    messenger?.hideCurrentSnackBar();
    messenger?.showSnackBar(SnackBar(
      content: Text('导入完成：新增 $added，更新 $updated，跳过 $skipped，'
          '文件 $blobs'),
      duration: const Duration(seconds: 4),
    ));
  } catch (e) {
    messenger?.hideCurrentSnackBar();
    messenger?.showSnackBar(SnackBar(content: Text('导入失败：$e')));
  }
}

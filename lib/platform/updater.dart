/// 应用内更新：查 GitHub Release → 下载 APK → 交给系统安装器。
///
/// 为什么不用 in_app_update 插件：那个只对「从 Google Play 装的包」有效，
/// 我们自签的 APK 它什么都不做。这里走 PackageInstaller.Session（原生侧实现）。
library;

import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../data/settings.dart';
import '../ui/kit.dart';
import '../ui/theme.dart';
import 'image_out.dart';

class _Release {
  _Release(this.tag, this.notes, this.apkUrl, this.apkSize, this.pageUrl);
  final String tag;
  final String notes;
  final String? apkUrl;
  final int apkSize;
  final String pageUrl;
}

class Updater {
  /// [manual] 为 true 时，即使没有新版本也会给个反馈；静默检查则完全闭嘴。
  static Future<void> check(BuildContext context, {bool manual = false}) async {
    final pkg = await PackageInfo.fromPlatform();
    final current = pkg.version;
    try {
      final r = await Dio(BaseOptions(
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 20),
        headers: {
          'Accept': 'application/vnd.github+json',
          'User-Agent': 'shijian/$current',
        },
      )).get('https://api.github.com/repos/${Settings.updateRepo}/releases/latest');

      final data = r.data as Map;
      final tag = (data['tag_name'] ?? '').toString();
      final ver = _clean(tag);
      if (ver.isEmpty) throw StateError('发布里没有版本号');
      if (_cmp(ver, current) <= 0) {
        if (manual && context.mounted) toast(context, '已经是最新版 $current');
        return;
      }
      if (Settings.skippedVersion == ver && !manual) return;

      String? apk;
      var size = 0;
      for (final a in (data['assets'] as List?) ?? const []) {
        final name = (a['name'] ?? '').toString();
        if (name.endsWith('.apk')) {
          apk = (a['browser_download_url'] ?? '').toString();
          size = ((a['size'] as num?) ?? 0).toInt();
          break;
        }
      }
      final rel = _Release(
        ver,
        (data['body'] ?? '').toString(),
        apk,
        size,
        (data['html_url'] ?? '').toString(),
      );
      if (!context.mounted) return;
      await _showUpdate(context, rel, current);
    } catch (e) {
      if (manual && context.mounted) {
        toast(context, '检查更新失败（网络或仓库地址没配好）');
      }
    }
  }

  static Future<void> _showUpdate(
      BuildContext context, _Release rel, String current) {
    return showDialog<void>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text('发现新版本 v${rel.tag}'),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 260),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('当前 v$current → v${rel.tag}',
                    style: T.small.copyWith(fontSize: 12.5)),
                if (rel.notes.trim().isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(rel.notes,
                      style: T.bodyDim.copyWith(fontSize: 12.5, height: 1.6)),
                ],
                if (rel.apkUrl == null) ...[
                  const SizedBox(height: 12),
                  Text('这个版本没有 APK 附件，去发布页手动下载。',
                      style: T.small.copyWith(color: C.danger)),
                ],
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Settings.skippedVersion = rel.tag;
              Navigator.pop(c);
            },
            child: const Text('跳过', style: TextStyle(color: C.text3)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(c),
            child: const Text('以后', style: TextStyle(color: C.text2)),
          ),
          if (rel.apkUrl != null)
            FilledButton(
              onPressed: () {
                Navigator.pop(c);
                _download(context, rel);
              },
              child: Text('下载 ${rel.apkSize > 0 ? '(${fmtBytes(rel.apkSize)})' : ''}'),
            ),
        ],
      ),
    );
  }

  static Future<void> _download(BuildContext context, _Release rel) async {
    final progress = ValueNotifier<double>(0);
    final dlg = showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (c) => AlertDialog(
        title: const Text('正在下载更新'),
        content: ValueListenableBuilder<double>(
          valueListenable: progress,
          builder: (_, v, __) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              LinearProgressIndicator(
                value: v <= 0 ? null : v,
                backgroundColor: C.panel2,
              ),
              const SizedBox(height: 10),
              Text(v <= 0 ? '连接中…' : '${(v * 100).toStringAsFixed(0)}%',
                  style: T.small),
            ],
          ),
        ),
      ),
    );
    try {
      final dir = await getTemporaryDirectory();
      final file = File(p.join(dir.path, 'shijian-${rel.tag}.apk'));
      await Dio().download(
        rel.apkUrl!,
        file.path,
        onReceiveProgress: (got, total) {
          if (total > 0) progress.value = got / total;
        },
      );
      if (context.mounted) Navigator.pop(context);
      await dlg;

      if (!await canInstallApk()) {
        if (!context.mounted) return;
        final ok = await confirm(context,
            title: '需要允许安装应用',
            message: '系统拦住了安装。请在接下来的设置页里允许「拾间」安装未知应用，然后点重试。',
            ok: '去设置');
        if (ok) {
          await openInstallSettings();
        }
        return;
      }
      final ok = await installApk(file.path);
      if (!ok && context.mounted) toast(context, '拉起安装器失败');
    } catch (e) {
      if (context.mounted) Navigator.pop(context);
      await dlg;
      if (context.mounted) toast(context, '下载失败：$e');
    } finally {
      progress.dispose();
    }
  }

  static String _clean(String tag) {
    var v = tag.trim();
    if (v.startsWith('v') || v.startsWith('V')) v = v.substring(1);
    return v.split('+').first.split('-').first;
  }

  static int _cmp(String a, String b) {
    List<int> parts(String s) => s
        .split('.')
        .map((e) => int.tryParse(e.replaceAll(RegExp(r'\D'), '')) ?? 0)
        .toList();
    final x = parts(a), y = parts(b);
    for (var i = 0; i < 3; i++) {
      final xi = i < x.length ? x[i] : 0;
      final yi = i < y.length ? y[i] : 0;
      if (xi != yi) return xi.compareTo(yi);
    }
    return 0;
  }
}

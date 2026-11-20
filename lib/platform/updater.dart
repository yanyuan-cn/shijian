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
import 'package:url_launcher/url_launcher.dart';

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
      final assets = ((data['assets'] as List?) ?? const [])
          .whereType<Map>()
          .where((a) => (a['name'] ?? '').toString().endsWith('.apk'))
          .toList();
      // 按设备 ABI 挑分包：arm64-v8a / armeabi-v7a / x86_64 / x86。
      // 装错架构的包 PackageInstaller 会静默失败，这是最容易踩的坑。
      final abi = (await deviceAbi()).toLowerCase();
      String want() {
        if (abi.contains('arm64')) return 'arm64';
        if (abi.contains('armeabi')) return 'armeabi';
        if (abi.contains('x86_64')) return 'x86_64';
        if (abi.contains('x86')) return 'x86_';
        return 'universal';
      }

      final wanted = want();
      int weight(Map m) {
        final n = (m['name'] ?? '').toString().toLowerCase();
        if (n.contains(wanted)) return 0;
        if (n.contains('universal')) return 1;
        return 2;
      }

      assets.sort((a, b) => weight(a).compareTo(weight(b)));
      if (assets.isNotEmpty) {
        apk = (assets.first['browser_download_url'] ?? '').toString();
        size = ((assets.first['size'] as num?) ?? 0).toInt();
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

  /// GitHub 的 Release 资源会 302 到 objects.githubusercontent.com，
  /// 国内经常被 reset（错误长这样：`Connection reset by peer`）。
  /// 所以直连失败后依次换公共反代重试——只是把整个 URL 拼在镜像前缀后面。
  static const _mirrors = <String>[
    '',
    'https://ghfast.top/',
    'https://gh-proxy.com/',
    'https://ghproxy.net/',
    'https://hub.gitmirror.com/',
    'https://ghp.ci/',
  ];

  static Future<void> _download(BuildContext context, _Release rel) async {
    final progress = ValueNotifier<double>(0);
    final label = ValueNotifier<String>('连接中…');
    final dlg = showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (c) => AlertDialog(
        title: const Text('正在下载更新'),
        content: ValueListenableBuilder<double>(
          valueListenable: progress,
          builder: (_, v, __) => Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              LinearProgressIndicator(
                value: v <= 0 ? null : v,
                backgroundColor: C.panel2,
              ),
              const SizedBox(height: 10),
              Text(v <= 0 ? label.value : '${(v * 100).toStringAsFixed(0)}%',
                  style: T.small),
            ],
          ),
        ),
      ),
    );
    Object? lastError;
    File? apk;
    try {
      final dir = await getTemporaryDirectory();
      final file = File(p.join(dir.path, 'shijian-${rel.tag}.apk'));
      for (var i = 0; i < _mirrors.length; i++) {
        final url = '${_mirrors[i]}${rel.apkUrl!}';
        try {
          if (i > 0) label.value = '换线路重试（第 ${i + 1} 个）…';
          if (await file.exists()) await file.delete();
          await _fetchTo(url, file, rel.apkSize, progress, label);
          apk = file;
          break;
        } catch (e) {
          lastError = e;
          progress.value = 0;
        }
      }
      if (context.mounted) Navigator.pop(context);
      await dlg;
      if (apk == null) {
        if (!context.mounted) return;
        final open = await confirm(
          context,
          title: '下载失败',
          message: '直连和几个镜像都没成功（${_short(lastError)}）。'
              '可以用浏览器打开发布页手动下载安装。',
          ok: '打开发布页',
        );
        if (open) {
          await launchUrl(Uri.parse(rel.pageUrl),
              mode: LaunchMode.externalApplication);
        }
        return;
      }

      if (!await canInstallApk()) {
        if (!context.mounted) return;
        await openInstallSettings();
        if (!context.mounted) return;
        final go = await confirm(
          context,
          title: '在设置里允许后回来',
          message: '找到「拾间」→ 打开「允许安装未知应用」，然后回到这里点「继续安装」。',
          ok: '继续安装',
        );
        if (!go) return;
        if (!await canInstallApk()) {
          if (context.mounted) toast(context, '系统还没放开安装权限');
          return;
        }
      }
      final ok = await installApk(apk.path);
      if (!ok && context.mounted) {
        toast(context,
            '拉起安装器失败${nativeLastError.isEmpty ? '' : '：$nativeLastError'}');
      }
    } catch (e) {
      if (context.mounted) Navigator.pop(context);
      await dlg;
      if (context.mounted) toast(context, '下载失败：${_short(e)}');
    } finally {
      progress.dispose();
      label.dispose();
    }
  }

  /// 断点续传式下载：中途被重置就带着已下载的字节重发（Range 请求），
  /// 同一条线路最多重试 5 次；15 秒内几乎没进度就判定线路不可用，抛错换下一个。
  static Future<void> _fetchTo(
    String url,
    File file,
    int expect,
    ValueNotifier<double> progress,
    ValueNotifier<String> label,
  ) async {
    var rounds = 0;
    while (true) {
      final have = await file.exists() ? await file.length() : 0;
      if (expect > 0 && have >= expect) {
        if (expect > 0 && await file.length() != expect) {
          throw StateError('包大小不对');
        }
        return;
      }
      if (rounds >= 5) throw StateError('线路反复中断');
      rounds++;
      if (rounds > 1) {
        label.value = '断线续传（第 $rounds 次）…';
        progress.value = expect > 0 ? have / expect : 0;
      }

      final dio = Dio(BaseOptions(
        connectTimeout: const Duration(seconds: 12),
        receiveTimeout: const Duration(seconds: 30),
        followRedirects: true,
        maxRedirects: 6,
        validateStatus: (s) => s != null && (s == 200 || s == 206),
      ));
      final resp = await dio.get<ResponseBody>(
        url,
        options: Options(
          responseType: ResponseType.stream,
          headers: have > 0 ? {'Range': 'bytes=$have-'} : null,
        ),
      );
      final append = resp.statusCode == 206 && have > 0;
      final sink = file.openWrite(mode: append ? FileMode.append : FileMode.write);
      var got = append ? have : 0;
      final sw = Stopwatch()..start();
      final startAt = got;
      var checked = false;
      var broke = false;
      try {
        await for (final chunk in resp.data!.stream) {
          sink.add(chunk);
          got += chunk.length;
          if (expect > 0) progress.value = got / expect;
          if (!checked && sw.elapsed > const Duration(seconds: 15)) {
            checked = true;
            final moved = got - startAt;
            if (expect > 0 && moved / expect < 0.02) {
              throw StateError('线路太慢');
            }
          }
        }
      } on StateError {
        rethrow;
      } catch (_) {
        broke = true;
      } finally {
        await sink.close();
      }
      if (!broke) return;
    }
  }

  static String _short(Object? e) {
    if (e == null) return '未知错误';
    final s = e.toString().replaceAll('\n', ' ');
    return s.length > 60 ? '${s.substring(0, 60)}…' : s;
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

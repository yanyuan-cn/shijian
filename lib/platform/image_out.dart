/// 平台出口：图片必须能「变成真实文件/URI」交出去，不能只在 App 里渲染。
///
/// saveImage / shareImage / setWallpaper / installApk 全部走一个 MethodChannel，
/// 由 MainActivity.kt 实现。放在 platform/ 下，core/ 与 data/ 永远不 import 它。
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/model.dart';
import '../data/app_state.dart';
import '../ui/detail_sheet.dart';
import '../ui/kit.dart';

const _ch = MethodChannel('shijian/native');

Future<bool> _call(String method, Map<String, dynamic> args) async {
  try {
    final r = await _ch.invokeMethod<bool>(method, args);
    return r ?? false;
  } on MissingPluginException {
    return false;
  } on PlatformException {
    return false;
  }
}

/// 把 blob 落到缓存目录，拿到系统能识别的真实路径（原生侧再转 content:// URI）。
Future<String?> _exportFile(Item it) async {
  final h = it.cover;
  if (h == null || h.isEmpty) return null;
  final name = _fileName(it, h);
  if (!await App.I.blobs.fileOf(h).exists()) return null;
  final f = await App.I.blobs.exportTemp(h, name: name);
  return f.path;
}

String _fileName(Item it, String hash) {
  final safe = it.title.replaceAll(RegExp(r'[\\/:*?"<>|\s]+'), '_');
  final ext = _extOf(it);
  return '${safe.isEmpty ? hash : safe}_${hash.substring(0, 8)}.$ext';
}

String _extOf(Item it) {
  final m = it.metaStr('mime') ?? '';
  if (m.contains('png')) return 'png';
  if (m.contains('webp')) return 'webp';
  if (m.contains('gif')) return 'gif';
  if (m.contains('heic')) return 'heic';
  return 'jpg';
}

Future<void> saveImageToGallery(BuildContext context, Item it) async {
  final path = await _exportFile(it);
  if (path == null) {
    if (context.mounted) toast(context, '原图不见了');
    return;
  }
  final ok = await _call('saveImage', {'path': path, 'mime': _mime(it)});
  if (context.mounted) toast(context, ok ? '已存入相册' : '保存失败（没拿到存储权限？）');
}

Future<void> shareImage(BuildContext context, Item it) async {
  final path = await _exportFile(it);
  if (path == null) {
    if (context.mounted) toast(context, '原图不见了');
    return;
  }
  final ok = await _call('shareImage', {
    'path': path,
    'mime': _mime(it),
    'title': it.title,
  });
  if (!ok && context.mounted) toast(context, '分享失败');
}

Future<void> setAsWallpaper(BuildContext context, Item it) async {
  final path = await _exportFile(it);
  if (path == null) {
    if (context.mounted) toast(context, '原图不见了');
    return;
  }
  final ok = await _call('setWallpaper', {'path': path});
  if (context.mounted) toast(context, ok ? '已设为壁纸' : '设置失败');
}

String _mime(Item it) {
  final m = it.metaStr('mime');
  if (m != null && m.isNotEmpty) return m;
  final e = _extOf(it);
  return 'image/${e == 'jpg' ? 'jpeg' : e}';
}

/// 安装 APK（应用内更新用）。Android 必须走 PackageInstaller.Session。
Future<bool> installApk(String path) =>
    _call('installApk', {'path': path});

/// 把任意文件交给系统分享面板（导出 zip 用）。
Future<bool> shareFile(String path,
        {String mime = 'application/octet-stream', String? title}) =>
    _call('shareImage', {'path': path, 'mime': mime, 'title': title ?? ''});

/// 是否允许「安装未知应用」。
Future<bool> canInstallApk() => _call('canInstall', {});

/// 设备主 ABI（arm64-v8a / armeabi-v7a / x86_64 …）。挑 Update 分包时要用：
/// 装错 ABI 的包，PackageInstaller 会直接失败。
Future<String> deviceAbi() async {
  try {
    final r = await _ch.invokeMethod<String>('abi');
    return (r ?? '').trim();
  } catch (_) {
    return '';
  }
}

Future<void> openInstallSettings() =>
    _call('installSettings', {}).then((_) {});

/// 全屏看原图：左右翻页 + 双指缩放，点按退出。
Future<void> showImageViewer(
    BuildContext context, List<Item> items, int index) {
  return Navigator.of(context).push(PageRouteBuilder<void>(
    opaque: true,
    transitionDuration: const Duration(milliseconds: 220),
    pageBuilder: (_, a, __) =>
        FadeTransition(opacity: a, child: _Viewer(items: items, index: index)),
  ));
}

class _Viewer extends StatefulWidget {
  const _Viewer({required this.items, required this.index});
  final List<Item> items;
  final int index;

  @override
  State<_Viewer> createState() => _ViewerState();
}

class _ViewerState extends State<_Viewer> {
  late final PageController _pc = PageController(initialPage: widget.index);
  late int _i = widget.index;
  bool _chrome = true;

  @override
  void dispose() {
    _pc.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final it = widget.items[_i];
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          PageView.builder(
            controller: _pc,
            itemCount: widget.items.length,
            onPageChanged: (v) => setState(() => _i = v),
            itemBuilder: (_, i) {
              final item = widget.items[i];
              final file = item.cover == null
                  ? null
                  : App.I.blobs.fileOf(item.cover!);
              if (file == null || !file.existsSync()) {
                return const Center(
                    child: Text('原图不见了',
                        style: TextStyle(color: Colors.white54, fontSize: 13)));
              }
              return GestureDetector(
                onTap: () => setState(() => _chrome = !_chrome),
                child: InteractiveViewer(
                  minScale: 1,
                  maxScale: 5,
                  child: Center(child: Image.file(file, fit: BoxFit.contain)),
                ),
              );
            },
          ),
          if (_chrome)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: EdgeInsets.only(
                    top: MediaQuery.of(context).padding.top),
                color: Colors.black.withValues(alpha: 0.45),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close,
                          color: Colors.white, size: 22),
                    ),
                    Expanded(
                      child: Text(
                        it.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: Colors.white, fontSize: 13),
                      ),
                    ),
                    if (widget.items.length > 1)
                      Padding(
                        padding: const EdgeInsets.only(right: 10),
                        child: Text('${_i + 1}/${widget.items.length}',
                            style: const TextStyle(
                                color: Colors.white54, fontSize: 12)),
                      ),
                  ],
                ),
              ),
            ),
          if (_chrome)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                padding: EdgeInsets.fromLTRB(
                    8, 8, 8, 8 + MediaQuery.of(context).padding.bottom),
                color: Colors.black.withValues(alpha: 0.45),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _act(Icons.download_outlined, '保存',
                        () => saveImageToGallery(context, it)),
                    _act(Icons.ios_share, '分享',
                        () => shareImage(context, it)),
                    _act(Icons.wallpaper_outlined, '壁纸',
                        () => setAsWallpaper(context, it)),
                    _act(Icons.edit_outlined, '编辑', () {
                      Navigator.pop(context);
                      showItemSheet(context, it);
                    }),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _act(IconData ic, String label, VoidCallback onTap) =>
      InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(ic, color: Colors.white, size: 21),
              const SizedBox(height: 4),
              Text(label,
                  style: const TextStyle(color: Colors.white70, fontSize: 10.5)),
            ],
          ),
        ),
      );
}

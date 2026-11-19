/// 小工具：提示、确认框、格式化、blob 图片。
library;

import 'dart:io';

import 'package:flutter/material.dart';

import '../data/app_state.dart';
import 'theme.dart';

void toast(BuildContext ctx, String msg) {
  final m = ScaffoldMessenger.maybeOf(ctx);
  if (m == null) return;
  m
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Text(msg),
      duration: const Duration(milliseconds: 1800),
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 84),
    ));
}

Future<bool> confirm(
  BuildContext ctx, {
  required String title,
  String? message,
  String ok = '确定',
  bool danger = false,
}) async {
  final r = await showDialog<bool>(
    context: ctx,
    builder: (c) => AlertDialog(
      title: Text(title, style: const TextStyle(fontSize: 16)),
      content: message == null
          ? null
          : Text(message, style: const TextStyle(fontSize: 13.5, height: 1.6)),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(c, false),
          child: const Text('取消', style: TextStyle(color: C.text2)),
        ),
        TextButton(
          onPressed: () => Navigator.pop(c, true),
          child: Text(ok,
              style: TextStyle(color: danger ? C.danger : C.accent)),
        ),
      ],
    ),
  );
  return r ?? false;
}

String fmtBytes(int n) {
  if (n < 1024) return '$n B';
  if (n < 1024 * 1024) return '${(n / 1024).toStringAsFixed(1)} KB';
  if (n < 1024 * 1024 * 1024) {
    return '${(n / 1024 / 1024).toStringAsFixed(1)} MB';
  }
  return '${(n / 1024 / 1024 / 1024).toStringAsFixed(2)} GB';
}

/// 2024.11 这种短格式，和原型的链接/条目日期一致。
String fmtDate(int ms) {
  if (ms <= 0) return '';
  final d = DateTime.fromMillisecondsSinceEpoch(ms);
  final m = d.month.toString().padLeft(2, '0');
  return '${d.year}.$m';
}

String fmtDateFull(int ms) {
  if (ms <= 0) return '';
  final d = DateTime.fromMillisecondsSinceEpoch(ms);
  final m = d.month.toString().padLeft(2, '0');
  final day = d.day.toString().padLeft(2, '0');
  final h = d.hour.toString().padLeft(2, '0');
  final mi = d.minute.toString().padLeft(2, '0');
  return '${d.year}.$m.$day $h:$mi';
}

/// 从内容寻址仓库直接读图。文件路径就是缓存键，Flutter 的图片缓存天然复用。
class BlobImage extends StatelessWidget {
  const BlobImage(
    this.hash, {
    super.key,
    this.fit = BoxFit.cover,
    this.cacheWidth,
    this.width,
    this.height,
    this.placeholderColor,
  });

  final String? hash;
  final BoxFit fit;
  final int? cacheWidth;
  final double? width;
  final double? height;
  final Color? placeholderColor;

  @override
  Widget build(BuildContext context) {
    final h = hash;
    if (h == null || h.isEmpty) {
      return _empty();
    }
    final f = App.I.blobs.fileOf(h);
    if (!f.existsSync()) return _empty();
    return Image.file(
      f,
      fit: fit,
      width: width,
      height: height,
      cacheWidth: cacheWidth,
      gaplessPlayback: true,
      filterQuality: FilterQuality.medium,
      errorBuilder: (_, __, ___) => _empty(),
    );
  }

  Widget _empty() => Container(
        width: width,
        height: height,
        color: placeholderColor ?? C.panel2,
        alignment: Alignment.center,
        child: const Icon(Icons.image_outlined, size: 20, color: C.text3),
      );
}

/// 板块空态。六个板块共用一套文案位，避免每个页面自己写一遍。
class EmptyHint extends StatelessWidget {
  const EmptyHint({
    super.key,
    required this.icon,
    required this.title,
    this.sub,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String? sub;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 34, color: C.text3.withValues(alpha: 0.7)),
              const SizedBox(height: 14),
              Text(title, style: T.bodyDim),
              if (sub != null) ...[
                const SizedBox(height: 6),
                Text(sub!, style: T.small, textAlign: TextAlign.center),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// 只在文件真的存在时返回 File，给平台层（分享/壁纸）用。
File? blobFile(String? hash) {
  if (hash == null || hash.isEmpty) return null;
  final f = App.I.blobs.fileOf(hash);
  return f.existsSync() ? f : null;
}

/// 小工具：提示、确认框、格式化、blob 图片。
library;

import 'dart:io';

import 'package:flutter/material.dart';

import '../core/model.dart';
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

/// 封面：有图就用图，没图用「文字封面」兜底。
///
/// 原来的空态是灰底加一个图片图标，一屏三张全是灰方块，很难看。
/// 这里用条目自己的 id 派生一组双色渐变 + 竖排书名，看起来像是设计过的封面，
/// 也顺便让「还没配封面的收藏」一眼能认出是哪一本。
class CoverArt extends StatelessWidget {
  const CoverArt({
    super.key,
    required this.item,
    this.fit = BoxFit.cover,
    this.cacheWidth,
    this.fontSize,
    this.showYear = true,
    this.showTitle = true,
  });

  final Item item;
  final BoxFit fit;
  final int? cacheWidth;
  final double? fontSize;
  final bool showYear;
  final bool showTitle;

  static const List<List<Color>> _duo = [
    [Color(0xFF2A3B58), Color(0xFF121A28)],
    [Color(0xFF1F4B41), Color(0xFF0C211C)],
    [Color(0xFF7A4A22), Color(0xFF301B0C)],
    [Color(0xFF5B2540), Color(0xFF250D18)],
    [Color(0xFF3D4A66), Color(0xFF171E2B)],
    [Color(0xFF2F4A44), Color(0xFF111E1B)],
    [Color(0xFF4A3D66), Color(0xFF1B1526)],
  ];

  @override
  Widget build(BuildContext context) {
    final h = item.cover;
    if (h != null && h.isNotEmpty && App.I.blobs.fileOf(h).existsSync()) {
      return BlobImage(h, fit: fit, cacheWidth: cacheWidth);
    }
    final seed = (item.id.hashCode & 0x7fffffff) % _duo.length;
    final pair = _duo[seed];
    final title = item.title.trim();
    if (!showTitle) {
      return DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: pair,
          ),
        ),
      );
    }
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: pair,
        ),
      ),
      padding: const EdgeInsets.fromLTRB(10, 12, 10, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Center(
              child: Text(
                title,
                textAlign: TextAlign.center,
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: T.serif,
                  fontSize: fontSize ?? 15,
                  height: 1.35,
                  color: Colors.white.withValues(alpha: 0.92),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          if (showYear && (item.year ?? '').isNotEmpty)
            Text(
              item.year!,
              style: T.small.copyWith(
                fontSize: 10,
                letterSpacing: 1.2,
                color: Colors.white.withValues(alpha: 0.45),
              ),
            ),
        ],
      ),
    );
  }
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

/// 影视卡片的观看状态文案。
String watchStatus({
  required int progress,
  required bool done,
  required bool started,
}) {
  if (done) return '看完';
  if (started) return '在看';
  return '想看';
}

/// 卡片右下角的小状态胶囊（想看 / 在看 / 看完）。
class StatusPill extends StatelessWidget {
  const StatusPill({super.key, required this.label, this.onDark = false});

  final String label;
  final bool onDark;

  @override
  Widget build(BuildContext context) {
    final Color fg;
    if (label == '看完') {
      fg = const Color(0xFF8FD6A6);
    } else if (label == '在看') {
      fg = const Color(0xFFA7C4FF);
    } else {
      fg = onDark ? const Color(0xFFD6DCE8) : C.text2;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: fg.withValues(alpha: 0.35)),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 9, height: 1.2, color: fg, letterSpacing: 0.3),
      ),
    );
  }
}

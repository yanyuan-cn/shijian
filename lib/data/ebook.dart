/// 电子书解析：txt 猜编码，epub 拆 spine 成纯文本。
///
/// 只做「能读」需要的部分：不解析样式、不下载图片、不做目录跳转之外的排版。
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:fast_gbk/fast_gbk.dart';

class EbookChapter {
  const EbookChapter(this.title, this.offset);
  final String title;
  final int offset;
}

class EbookDoc {
  EbookDoc({
    required this.title,
    required this.text,
    required this.chapters,
    required this.format,
  });

  final String title;
  final String text;
  final List<EbookChapter> chapters;
  final String format;
}

Future<EbookDoc> parseEbook(Uint8List bytes, {String name = ''}) async {
  final isZip = bytes.length > 4 && bytes[0] == 0x50 && bytes[1] == 0x4B;
  final looksEpub = name.toLowerCase().endsWith('.epub');
  if (isZip || looksEpub) {
    try {
      return _parseEpub(bytes, name);
    } catch (_) {
      // epub 解析失败再退回当纯文本试一次
    }
  }
  return _parseTxt(bytes, name);
}

EbookDoc _parseTxt(Uint8List bytes, String name) {
  var text = _decodeText(bytes);
  text = text.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
  final title = _titleFromName(name);
  final chapters = <EbookChapter>[];
  // 用「第X章 / 序 / 后记」这种行切目录，够用了。
  final re = RegExp(
      r'^\s*(第[零一二三四五六七八九十百千万\d]+[章节回卷][^\n]{0,40}|序[章言]?|前言|后记|尾声|楔子)\s*$',
      multiLine: true);
  for (final m in re.allMatches(text)) {
    final t = m.group(0)!.trim();
    if (t.isEmpty) continue;
    chapters.add(EbookChapter(t, m.start));
  }
  return EbookDoc(
    title: title,
    text: text,
    chapters: chapters,
    format: 'txt',
  );
}

String _decodeText(Uint8List bytes) {
  if (bytes.length >= 2) {
    if (bytes[0] == 0xFE && bytes[1] == 0xFF) {
      return _utf16(bytes.sublist(2), bigEndian: true);
    }
    if (bytes[0] == 0xFF && bytes[1] == 0xFE) {
      return _utf16(bytes.sublist(2), bigEndian: false);
    }
  }
  try {
    var s = utf8.decode(bytes);
    if (s.startsWith('\uFEFF')) s = s.substring(1);
    return s;
  } on FormatException {
    // 不是合法 UTF-8，按 GBK 再来一次（国内 txt 绝大多数是 GBK）
  }
  try {
    return gbk.decode(bytes);
  } catch (_) {
    return utf8.decode(bytes, allowMalformed: true);
  }
}

String _utf16(List<int> b, {required bool bigEndian}) {
  final units = <int>[];
  for (var i = 0; i + 1 < b.length; i += 2) {
    units.add(bigEndian ? (b[i] << 8) | b[i + 1] : (b[i + 1] << 8) | b[i]);
  }
  return String.fromCharCodes(units);
}

EbookDoc _parseEpub(Uint8List bytes, String name) {
  final archive = ZipDecoder().decodeBytes(bytes);
  String? opfPath;
  final container = _find(archive, 'META-INF/container.xml');
  if (container != null) {
    final s = utf8.decode(container, allowMalformed: true);
    final m = RegExp(r'full-path="([^"]+)"').firstMatch(s);
    opfPath = m?.group(1);
  }
  opfPath ??= archive.files
      .map((f) => f.name)
      .firstWhere((n) => n.toLowerCase().endsWith('.opf'), orElse: () => '');

  String title = _titleFromName(name);
  final spine = <String>[];
  final idToHref = <String, String>{};

  if (opfPath.isNotEmpty) {
    final opfFile = _find(archive, opfPath);
    if (opfFile != null) {
      final opf = utf8.decode(opfFile, allowMalformed: true);
      final t = RegExp(r'<dc:title[^>]*>([\s\S]*?)</dc:title>').firstMatch(opf);
      if (t != null) {
        final v = _unescape(_stripTags(t.group(1)!)).trim();
        if (v.isNotEmpty) title = v;
      }
      for (final m in RegExp(r'<item\b[^>]*>').allMatches(opf)) {
        final tag = m.group(0)!;
        final id = _attr(tag, 'id');
        final href = _attr(tag, 'href');
        if (id != null && href != null) idToHref[id] = href;
      }
      for (final m in RegExp(r'<itemref\b[^>]*>').allMatches(opf)) {
        final idref = _attr(m.group(0)!, 'idref');
        if (idref != null && idToHref[idref] != null) {
          spine.add(idToHref[idref]!);
        }
      }
    }
  }

  final baseDir = opfPath.contains('/')
      ? opfPath.substring(0, opfPath.lastIndexOf('/') + 1)
      : '';

  final buf = StringBuffer();
  final chapters = <EbookChapter>[];
  final names = spine.isNotEmpty
      ? spine
      : archive.files
          .map((f) => f.name)
          .where((n) =>
              n.toLowerCase().endsWith('.xhtml') ||
              n.toLowerCase().endsWith('.html') ||
              n.toLowerCase().endsWith('.htm'))
          .toList()
        ..sort();

  for (final rel in names) {
    final full = _resolve(baseDir, rel);
    final data = _find(archive, full) ?? _find(archive, rel);
    if (data == null) continue;
    final html = utf8.decode(data, allowMalformed: true);
    var text = _htmlToText(html);
    if (text.trim().isEmpty) continue;
    // 章节名优先取第一行的短标题
    final firstLine = text.trim().split('\n').first.trim();
    final chapTitle = firstLine.length <= 30 ? firstLine : '第 ${chapters.length + 1} 节';
    chapters.add(EbookChapter(chapTitle, buf.length));
    buf
      ..write(text.trim())
      ..write('\n\n');
  }

  return EbookDoc(
    title: title,
    text: buf.toString(),
    chapters: chapters,
    format: 'epub',
  );
}

Uint8List? _find(Archive a, String path) {
  final key = path.toLowerCase();
  for (final f in a.files) {
    if (f.name.toLowerCase() == key) return f.readBytes();
  }
  // 有些 epub 用相对路径 + 大小写混排，再按后缀试一次
  for (final f in a.files) {
    if (key.endsWith(f.name.toLowerCase())) return f.readBytes();
  }
  return null;
}

String _resolve(String base, String rel) {
  if (rel.startsWith('/')) return rel.substring(1);
  final parts = <String>[...base.split('/').where((e) => e.isNotEmpty)];
  for (final seg in rel.split('/')) {
    if (seg == '.' || seg.isEmpty) continue;
    if (seg == '..') {
      if (parts.isNotEmpty) parts.removeLast();
    } else {
      parts.add(seg);
    }
  }
  return parts.join('/');
}

String? _attr(String tag, String name) {
  final m = RegExp('$name\\s*=\\s*"([^"]*)"').firstMatch(tag);
  return m?.group(1);
}

String _htmlToText(String html) {
  var s = html
      .replaceAll(RegExp(r'<script[\s\S]*?</script>', caseSensitive: false), '')
      .replaceAll(RegExp(r'<style[\s\S]*?</style>', caseSensitive: false), '')
      .replaceAll(RegExp(r'<!--[\s\S]*?-->'), '');
  s = s.replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n');
  s = s.replaceAll(RegExp(r'</(p|div|h[1-6]|li|tr|section|article)>',
      caseSensitive: false), '\n');
  s = _stripTags(s);
  s = _unescape(s);
  s = s.replaceAll(RegExp(r'[ \t\u00A0]+'), ' ');
  s = s.replaceAll(RegExp(r'\n{3,}'), '\n\n');
  return s;
}

String _stripTags(String s) => s.replaceAll(RegExp(r'<[^>]+>'), '');

String _unescape(String s) => s
    .replaceAll('&nbsp;', ' ')
    .replaceAll('&lt;', '<')
    .replaceAll('&gt;', '>')
    .replaceAll('&quot;', '"')
    .replaceAll('&#39;', "'")
    .replaceAll('&amp;', '&');

String _titleFromName(String name) {
  var n = name.replaceAll('\\', '/');
  final slash = n.lastIndexOf('/');
  if (slash >= 0) n = n.substring(slash + 1);
  final dot = n.lastIndexOf('.');
  if (dot > 0) n = n.substring(0, dot);
  return n.isEmpty ? '未命名' : n;
}

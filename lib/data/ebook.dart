/// 电子书解析：把 txt / epub 重排成「块」——标题、正文段、图注、引用。
///
/// 与旧版最大的区别：
///  · 不再把原始硬换行原样保留，而是 reflow 成真正的段落；
///  · 能识别「目录页」（原书自带的目录往往混在正文里）并把它从正文剔除，
///    反过来用它生成章节列表；
///  · 章标题支持多种写法（第X章 / 30. 夜歌 / 一、xxx / 序言 后记 …）；
///  · epub 优先用 nav/NCX 的真实目录，并按 spine 顺序分章。
///
/// 文本偏移（EbookBlock.offset / EbookChapter.offset）都指向 `EbookDoc.text`，
/// 阅读器的分页与进度都基于它，所以这里必须严格保持 text 与块顺序一致。
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:fast_gbk/fast_gbk.dart';

enum BlockKind { heading, para, caption, quote }

class EbookBlock {
  const EbookBlock(this.kind, this.offset, this.end, {this.level = 0});
  final BlockKind kind;
  final int offset;
  final int end;
  final int level; // 标题层级：1 大标题（章），2 小节
}

class EbookChapter {
  const EbookChapter(this.title, this.offset);
  final String title;
  final int offset;
}

class EbookDoc {
  EbookDoc({
    required this.title,
    required this.text,
    required this.blocks,
    required this.chapters,
    required this.format,
  });

  final String title;

  /// 供排版与进度使用的扁平正文：段落之间是 "\n\n"，正文段前面带全角缩进。
  final String text;
  final List<EbookBlock> blocks;
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

// ───────────────────────────── txt ─────────────────────────────

/// 行尾就是句子结束（这种行不该和下一行合并）。
bool _endsSentence(String s) {
  if (s.isEmpty) return true;
  return RegExp(r'[。！？…．\.\!\?”’"』」】》]\)）]$').hasMatch(s);
}

/// 行首是列表/编号/引号，通常意味着新段落的开始。
bool _startsNewBlock(String s) {
  final t = s.trimLeft();
  if (t.isEmpty) return true;
  return RegExp(
          r'^(第[零一二三四五六七八九十百千万\d]+[章节卷回节部篇]|[0-9]{1,3}[.、]\s|[一二三四五六七八九十]{1,3}[、.]\s?|[(（][0-9一二三四五六七八九十]{1,3}[)）]|[“"『「]|※|◇|◆|★|[－—\-]{3,})')
      .hasMatch(t);
}

EbookDoc _parseTxt(Uint8List bytes, String name) {
  var raw = _decodeText(bytes);
  raw = raw.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
  final title = _titleFromName(name);

  final lines = raw.split('\n');
  final paras = _reflow(lines);

  // 原书自带的目录页：连续多行「编号 + 短标题」，中间有/无空行都算。
  final toc = _detectTocPage(paras);
  final body = toc == null ? paras : paras.sublist(toc.bodyStart);

  final blocks = <EbookBlock>[];
  final buf = StringBuffer();
  final chapters = <EbookChapter>[];

  void add(BlockKind kind, String text, {int level = 0, bool indent = true}) {
    if (buf.isNotEmpty) buf.write('\n\n');
    // 块间的空行算到上一块的末尾：渲染时按 [offset,end) 切片，
    // 否则分隔符不属于任何块，段落就会全部黏成一行。
    if (blocks.isNotEmpty) {
      final last = blocks.removeLast();
      blocks.add(EbookBlock(last.kind, last.offset, buf.length,
          level: last.level));
    }
    final start = buf.length; // 缩进也算进块里，否则排版时会被丢掉
    if (indent && kind == BlockKind.para) buf.write('\u3000\u3000');
    buf.write(text);
    blocks.add(EbookBlock(kind, start, buf.length, level: level));
    if (kind == BlockKind.heading) {
      chapters.add(EbookChapter(text, start));
    }
  }

  for (final p in body) {
    if (p.trim().isEmpty) continue;
    final t = p.trim();
    final h = _headingLevel(t, body);
    if (h > 0) {
      add(BlockKind.heading, t, level: h, indent: false);
    } else if (_looksCaption(t)) {
      add(BlockKind.caption, t, indent: false);
    } else if (RegExp(r'^[“"『「]').hasMatch(t) && t.length < 200) {
      add(BlockKind.quote, t);
    } else {
      add(BlockKind.para, t);
    }
  }

  // 没有识别到任何标题时，至少给一个「正文」入口。
  if (chapters.isEmpty) chapters.add(const EbookChapter('正文', 0));

  // 目录页里的条目如果有正文中对应的标题，用它的写法美化一下章节名。
  if (toc != null && toc.titles.isNotEmpty) {
    _prettyChapterNames(chapters, toc.titles);
  }

  return EbookDoc(
    title: title,
    text: buf.toString(),
    blocks: blocks,
    chapters: chapters,
    format: 'txt',
  );
}

/// 把「硬换行」重排成段落：行尾没在句末标点上，就与下一行接起来。
List<String> _reflow(List<String> lines) {
  final out = <String>[];
  final cur = StringBuffer();
  for (var i = 0; i < lines.length; i++) {
    final line = lines[i].replaceAll(RegExp(r'[ \t\u00A0]+$'), '');
    final t = line.trim();
    if (t.isEmpty) {
      if (cur.isNotEmpty) {
        out.add(cur.toString());
        cur.clear();
      }
      continue;
    }
    if (cur.isEmpty) {
      cur.write(t);
      continue;
    }
    final prev = cur.toString();
    if (_endsSentence(prev) || _startsNewBlock(t)) {
      out.add(prev);
      cur.clear();
      cur.write(t);
    } else {
      // 中文接行不需要空格；西文单词之间补一个空格
      final needSpace =
          RegExp(r'[A-Za-z0-9,;:]$').hasMatch(prev) && RegExp(r'^[A-Za-z0-9]').hasMatch(t);
      if (needSpace) cur.write(' ');
      cur.write(t);
    }
  }
  if (cur.isNotEmpty) out.add(cur.toString());
  return out;
}

/// 目录页探测：一段连续的「短行、无句末标点、多为编号开头」的列表。
({int bodyStart, List<String> titles})? _detectTocPage(List<String> paras) {
  final limit = paras.length < 400 ? paras.length : 400;
  var bestRunStart = -1;
  var bestRunLen = 0;
  var runStart = -1;
  var runLen = 0;
  int? _lastTocNum;

  bool isTocLine(String s) {
    final t = s.trim();
    if (t.isEmpty || t.length > 30) return false;
    if (RegExp(r'[。！？…]$').hasMatch(t)) return false;
    return RegExp(
            r'^((第[零一二三四五六七八九十百千万\d]+[章节卷回节部篇])|[0-9]{1,3}[.、]|[一二三四五六七八九十]{1,3}[、.]|[（(][0-9一二三四五六七八九十]{1,3}[)）])')
        .hasMatch(t);
  }

  for (var i = 0; i < limit; i++) {
    if (isTocLine(paras[i])) {
      final n = _leadingNumber(paras[i]);
      // 编号突然变小，说明目录页结束、正文从头开始了。
      final restarted = runStart >= 0 && n != null && _lastTocNum != null &&
          n <= _lastTocNum!;
      if (restarted) {
        runStart = -1;
        runLen = 0;
      }
      if (runStart < 0) runStart = i;
      runLen++;
      if (n != null) _lastTocNum = n;
      if (runLen > bestRunLen) {
        bestRunLen = runLen;
        bestRunStart = runStart;
      }
    } else {
      runStart = -1;
      runLen = 0;
      _lastTocNum = null;
    }
  }
  if (bestRunLen < 6) return null;
  final titles = <String>[];
  for (var i = bestRunStart; i < bestRunStart + bestRunLen; i++) {
    titles.add(paras[i].trim());
  }
  return (bodyStart: bestRunStart + bestRunLen, titles: titles);
}

/// 取出行首的编号（「30. 夜歌」→ 30），没有就返回 null。
int? _leadingNumber(String s) {
  final m = RegExp(r'^\s*(?:第([零一二三四五六七八九十百千\d]+)|([0-9]{1,3})[.、])')
      .firstMatch(s);
  if (m == null) return null;
  final arabic = m.group(2);
  if (arabic != null) return int.tryParse(arabic);
  return _cnToInt(m.group(1) ?? '');
}

int? _cnToInt(String s) {
  if (s.isEmpty) return null;
  final n = int.tryParse(s);
  if (n != null) return n;
  const digits = {
    '零': 0, '一': 1, '二': 2, '两': 2, '三': 3, '四': 4,
    '五': 5, '六': 6, '七': 7, '八': 8, '九': 9,
  };
  var total = 0;
  var section = 0;
  var number = 0;
  for (final ch in s.split('')) {
    if (digits.containsKey(ch)) {
      number = digits[ch]!;
    } else if (ch == '十') {
      section += (number == 0 ? 1 : number) * 10;
      number = 0;
    } else if (ch == '百') {
      section += (number == 0 ? 1 : number) * 100;
      number = 0;
    } else if (ch == '千') {
      section += (number == 0 ? 1 : number) * 1000;
      number = 0;
    } else if (ch == '万') {
      total += (section + number) * 10000;
      section = 0;
      number = 0;
    }
  }
  return total + section + number;
}

bool _looksCaption(String t) {
  if (t.length > 48) return false;
  if (RegExp(r'[。！？]$').hasMatch(t)) return false;
  final hasYear = RegExp(r'(1[5-9]\d{2}|20\d{2})\s*年?').hasMatch(t);
  final hasMeta =
      RegExp(r'(摄影|摄|绘|作|著|译|馆藏|收藏|尺寸|cm|素描|油画|壁画|版画|水彩|手稿)')
          .hasMatch(t);
  return hasYear && hasMeta;
}

int _headingLevel(String t, List<String> all) {
  final s = t.trim();
  if (s.length > 28) return 0;
  if (RegExp(r'[。！？；，]$').hasMatch(s)) return 0;
  if (RegExp(r'^第[零一二三四五六七八九十百千万\d]+[章卷回篇]').hasMatch(s)) return 1;
  if (RegExp(r'^第[零一二三四五六七八九十百千万\d]+[节]').hasMatch(s)) return 2;
  if (RegExp(r'^(序[章言]?|自序|前言|后记|尾声|楔子|引子|附录|译后记|跋)$').hasMatch(s)) {
    return 1;
  }
  if (RegExp(r'^[0-9]{1,3}[.、]\s*\S').hasMatch(s)) return 1;
  if (RegExp(r'^[一二三四五六七八九十]{1,3}[、.]\s*\S').hasMatch(s)) return 2;
  return 0;
}

/// 用目录页里的写法覆盖章节名（编号更规整、更短），只按「包含关系」粗匹配。
void _prettyChapterNames(List<EbookChapter> chapters, List<String> tocTitles) {
  for (var i = 0; i < chapters.length && i < tocTitles.length; i++) {
    final toc = tocTitles[i];
    final cur = chapters[i].title;
    final a = _bareTitle(toc);
    final b = _bareTitle(cur);
    if (a.isEmpty || b.isEmpty) continue;
    if (a == b || a.contains(b) || b.contains(a)) {
      chapters[i] = EbookChapter(toc, chapters[i].offset);
    }
  }
}

String _bareTitle(String s) => s
    .replaceAll(RegExp(r'^[(（\[【]?(第[零一二三四五六七八九十百千万\d]+[章节卷回节部篇])?'),
        '')
    .replaceAll(RegExp(r'^[0-9]{1,3}[.、]\s*'), '')
    .replaceAll(RegExp(r'^[一二三四五六七八九十]{1,3}[、.]\s*'), '')
    .replaceAll(RegExp(r'[\s　]+'), '')
    .trim();

// ───────────────────────────── epub ─────────────────────────────

EbookDoc _parseEpub(Uint8List bytes, String name) {
  final archive = ZipDecoder().decodeBytes(bytes);
  String? opfPath;
  final container = _find(archive, 'META-INF/container.xml');
  if (container != null) {
    final s = utf8.decode(container, allowMalformed: true);
    opfPath = RegExp(r'full-path="([^"]+)"').firstMatch(s)?.group(1);
  }
  opfPath ??= archive.files
      .map((f) => f.name)
      .firstWhere((n) => n.toLowerCase().endsWith('.opf'), orElse: () => '');

  String title = _titleFromName(name);
  final spine = <String>[];
  final idToHref = <String, String>{};
  String? ncxHref;
  String? navHref;

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
        final props = _attr(tag, 'properties') ?? '';
        if (props.contains('nav')) navHref = href;
        if ((_attr(tag, 'media-type') ?? '').contains('dtbncx')) ncxHref = href;
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

  // 真实目录：nav.xhtml → NCX → 都没有就按每页首个短行猜。
  final tocTitles = <String, String>{}; // 文件路径 -> 标题
  final tocOrder = <String>[];
  if (navHref != null) {
    final data = _find(archive, _resolve(baseDir, navHref));
    if (data != null) {
      _parseNav(utf8.decode(data, allowMalformed: true), tocTitles, tocOrder);
    }
  }
  if (tocTitles.isEmpty && ncxHref != null) {
    final data = _find(archive, _resolve(baseDir, ncxHref));
    if (data != null) {
      _parseNcx(utf8.decode(data, allowMalformed: true), tocTitles, tocOrder);
    }
  }

  final names = spine.isNotEmpty
      ? spine
      : (archive.files
            .map((f) => f.name)
            .where((n) =>
                n.toLowerCase().endsWith('.xhtml') ||
                n.toLowerCase().endsWith('.html') ||
                n.toLowerCase().endsWith('.htm'))
            .toList()
          ..sort());

  final blocks = <EbookBlock>[];
  final buf = StringBuffer();
  final chapters = <EbookChapter>[];

  void add(BlockKind kind, String text, {int level = 0, bool indent = true}) {
    if (buf.isNotEmpty) buf.write('\n\n');
    if (indent && kind == BlockKind.para) buf.write('\u3000\u3000');
    final start = buf.length;
    buf.write(text);
    blocks.add(EbookBlock(kind, start, buf.length, level: level));
    if (kind == BlockKind.heading) {
      chapters.add(EbookChapter(text, start));
    }
  }

  for (final rel in names) {
    final full = _resolve(baseDir, rel);
    final data = _find(archive, full) ?? _find(archive, rel);
    if (data == null) continue;
    final html = utf8.decode(data, allowMalformed: true);
    final parts = _htmlBlocks(html);
    if (parts.isEmpty) continue;

    final knownTitle = tocTitles[full] ?? tocTitles[rel];
    var usedKnown = false;
    for (final part in parts) {
      final t = part.$2.trim();
      if (t.isEmpty) continue;
      if (part.$1 > 0) {
        add(BlockKind.heading, t, level: part.$1, indent: false);
        usedKnown = true;
      } else if (_looksCaption(t)) {
        add(BlockKind.caption, t, indent: false);
      } else {
        add(BlockKind.para, t);
      }
    }
    if (!usedKnown && knownTitle != null) {
      // 这一页没有任何 <h*>：用真实目录名补一个章标题，方便跳转。
      chapters.add(EbookChapter(knownTitle, buf.length));
      add(BlockKind.heading, knownTitle, level: 1, indent: false);
    }
  }

  if (chapters.isEmpty) chapters.add(const EbookChapter('正文', 0));
  chapters.sort((a, b) => a.offset.compareTo(b.offset));

  return EbookDoc(
    title: title,
    text: buf.toString(),
    blocks: blocks,
    chapters: chapters,
    format: 'epub',
  );
}

void _parseNav(String html, Map<String, String> map, List<String> order) {
  for (final m in RegExp(r'<a\b[^>]*href="([^"]+)"[^>]*>([\s\S]*?)</a>',
          caseSensitive: false)
      .allMatches(html)) {
    final href = m.group(1)!.split('#').first;
    final t = _unescape(_stripTags(m.group(2)!)).trim();
    if (href.isEmpty || t.isEmpty) continue;
    map.putIfAbsent(href, () => t);
    if (!order.contains(href)) order.add(href);
  }
}

void _parseNcx(String xml, Map<String, String> map, List<String> order) {
  for (final m
      in RegExp(r'<navPoint\b[\s\S]*?</navPoint>').allMatches(xml)) {
    final block = m.group(0)!;
    final src = RegExp(r'<content\b[^>]*src="([^"]+)"').firstMatch(block);
    final lbl = RegExp(r'<text[^>]*>([\s\S]*?)</text>').firstMatch(block);
    if (src == null || lbl == null) continue;
    final href = src.group(1)!.split('#').first;
    final t = _unescape(_stripTags(lbl.group(1)!)).trim();
    if (href.isEmpty || t.isEmpty) continue;
    map.putIfAbsent(href, () => t);
    if (!order.contains(href)) order.add(href);
  }
}

/// 把 HTML 拆成 (标题层级, 文本)：层级 0 = 正文段。
List<(int, String)> _htmlBlocks(String html) {
  var s = html
      .replaceAll(RegExp(r'<script[\s\S]*?</script>', caseSensitive: false), '')
      .replaceAll(RegExp(r'<style[\s\S]*?</style>', caseSensitive: false), '')
      .replaceAll(RegExp(r'<!--[\s\S]*?-->'), '')
      .replaceAll(RegExp(r'<head[\s\S]*?</head>', caseSensitive: false), '')
      .replaceAll(RegExp(r'<(img|image|svg|figure)\b[\s\S]*?</\1>',
          caseSensitive: false), '')
      .replaceAll(RegExp(r'<(img|hr)\b[^>]*/?>', caseSensitive: false), '');

  // 标题先单独抽出来，避免被当成普通段落。
  final out = <(int, String)>[];
  final hRe = RegExp(r'<h([1-6])\b[^>]*>([\s\S]*?)</h\1>', caseSensitive: false);
  final marks = <int, (int, int, String)>{};
  for (final m in hRe.allMatches(s)) {
    final txt = _normalizeText(_unescape(_stripTags(m.group(2)!)));
    marks[m.start] = (m.start, m.end, txt);
  }

  var cursor = 0;
  final keys = marks.keys.toList()..sort();
  for (final k in keys) {
    final mk = marks[k]!;
    if (k > cursor) {
      _pushParas(s.substring(cursor, mk.$1), out);
    }
    if (mk.$3.isNotEmpty) out.add((1, mk.$3));
    cursor = mk.$2;
  }
  if (cursor < s.length) _pushParas(s.substring(cursor), out);

  // 去重相邻重复段（有些 epub 在 <p> 里又套了一层）
  final cleaned = <(int, String)>[];
  for (final p in out) {
    if (cleaned.isNotEmpty && cleaned.last.$2 == p.$2) continue;
    cleaned.add(p);
  }
  return cleaned;
}

void _pushParas(String html, List<(int, String)> out) {
  var s = html.replaceAll(
      RegExp(r'</(p|div|li|section|article|blockquote|tr|dd|dt)>',
          caseSensitive: false),
      '\n\n');
  s = s.replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n');
  s = _unescape(_stripTags(s));
  for (final seg in s.split(RegExp(r'\n{2,}'))) {
    final t = _normalizeText(seg);
    if (t.isEmpty) continue;
    out.add((0, t));
  }
}

String _normalizeText(String s) => s
    .replaceAll(RegExp(r'[ \t\u00A0]+'), ' ')
    .replaceAll(RegExp(r'\s*\n\s*'), '')
    .trim();

// ───────────────────────────── 公共 ─────────────────────────────

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

Uint8List? _find(Archive a, String path) {
  final key = path.toLowerCase();
  for (final f in a.files) {
    if (f.name.toLowerCase() == key) return f.readBytes();
  }
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
